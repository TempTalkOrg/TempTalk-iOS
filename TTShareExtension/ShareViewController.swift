//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//
import UIKit

import TTMessaging
import PureLayout
import TTServiceKit
import CoreServices
import FTS5SimpleTokenizer

@objc
public class ShareViewController: UIViewController, ShareViewDelegate, SAEFailedViewDelegate {
    
    enum ShareViewControllerError: Error, Equatable {
        case assertionError(description: String)
        case unsupportedMedia
        case notRegistered
        case obsoleteShare
        case screenLockEnabled
        case tooManyAttachments
    }

    private var hasInitialRootViewController = false
    private var isReadyForAppExtensions = false
    //TODO: areVersionMigrationsComplete 待删除
    private var areVersionMigrationsComplete = false

    private var progressPoller: ProgressPoller?
    var loadViewController: SAELoadViewController?

    let shareViewNavigationController: OWSNavigationController = OWSNavigationController()

    override open func loadView() {
        super.loadView()

        // This should be the first thing we do.
        let appContext = ShareAppExtensionContext(rootViewController: self)
        SetCurrentAppContext(appContext,false)

        let debugLogger = DebugLogger.shared()
        debugLogger.enableTTYLoggingIfNeeded()
        debugLogger.setUpFileLoggingIfNeeded(appContext: appContext, canLaunchInBackground: false)
        
        Logger.info("")
        
        Cryptography.seedRandom()
        
        // We don't need to use DeviceSleepManager in the SAE.
        // We don't need to use applySignalAppearence in the SAE.
        
        if appContext.isRunningTests {
            // TODO: Do we need to implement isRunningTests in the SAE context?
            return
        }

        Logger.info("\(self.logTag) \(#function)")

        _ = AppVersion.shared()

        // If we haven't migrated the database file to the shared data
        // directory we can't load it, and therefore can't init TSSPrimaryStorage,
        // and therefore don't want to setup most of our machinery (Environment,
        // most of the singletons, etc.).  We just want to show an error view and
        // abort.
        isReadyForAppExtensions = OWSPreferences.isReadyForAppExtensions()
        guard isReadyForAppExtensions else {
            showNotReadyView()
            return
        }

        let loadViewController = SAELoadViewController(delegate: self)
        self.loadViewController = loadViewController

        // Don't display load screen immediately, in hopes that we can avoid it altogether.
        
        Guarantee.after(seconds: 0.5).done { [weak self] () -> Void in
            AssertIsOnMainThread()

            guard let strongSelf = self else { return }
            guard strongSelf.presentedViewController == nil else {
                Logger.debug("\(strongSelf.logTag) setup completed quickly, no need to present load view controller.")
                return
            }

            Logger.debug("\(strongSelf.logTag) setup is slow - showing loading screen")
            strongSelf.showPrimaryViewController(loadViewController)
        }

        // 注册自定义 FTS5 分词器
        FTS5SimpleTokenizer.register()
        
        // We shouldn't set up our environment until after we've consulted isReadyForAppExtensions.
        AppSetup.setupEnvironment(appSpecificSingletonBlock: {
            let noopNotificationsManager = NoopNotificationsManager()
            SSKEnvironment.shared.notificationsManagerRef = noopNotificationsManager;
            
        }, migrationCompletion: { [weak self] in
            AssertIsOnMainThread()

            guard let strongSelf = self else { return }

            // performUpdateCheck must be invoked after Environment has been initialized because
            // upgrade process may depend on Environment.
            strongSelf.versionMigrationsDidComplete()
        })

        // We don't need to use "screen protection" in the SAE.
        // Ensure OWSContactsSyncing is instantiated.
//        OWSContactsSyncing.sharedManager()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(storageIsReady),
                                               name: .StorageIsReady,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(registrationStateDidChange),
                                               name: .registrationStateDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(owsApplicationWillEnterForeground),
                                               name: .OWSApplicationWillEnterForeground,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: .OWSApplicationDidEnterBackground,
                                               object: nil)

        Logger.info("\(self.logTag) \(#function) completed.")

        OWSAnalytics.appLaunchDidBegin()
    }

    deinit {
        Logger.info("\(self.logTag) deinit")
        NotificationCenter.default.removeObserver(self)

        // Share extensions reside in a process that may be reused between usages.
        // That isn't safe; the codebase is full of statics (e.g. singletons) which
        // we can't easily clean up.
//        ExitShareExtension()
    }

    @objc
    public func applicationDidEnterBackground() {
        AssertIsOnMainThread()

        Logger.info("\(self.logTag) \(#function)")

        if ScreenLock.shared.isScreenLockEnabled() {

            Logger.info("\(self.logTag) \(#function) dismissing.")

            self.dismiss(animated: false) { [weak self] in
                AssertIsOnMainThread()
                guard let strongSelf = self else { return }
                strongSelf.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            }
        }
    }

    private func activate() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        // We don't need to use "screen protection" in the SAE.
        ensureRootViewController()

        // Always check prekeys after app launches, and sometimes check on app activation.

        // We don't need to use RTCInitializeSSL() in the SAE.
        if TSAccountManager.isRegistered() {
            // At this point, potentially lengthy DB locking migrations could be running.
            // Avoid blocking app launch by putting all further possible DB access in async block
            DispatchQueue.global().async { [weak self] in
                guard let strongSelf = self else { return }
                Logger.info("\(strongSelf.logTag) running post launch block for registered user: \(String(describing: TSAccountManager.localNumber))")

                // We don't need to use OWSDisappearingMessagesJob in the SAE.
                // We don't need to use OWSFailedMessagesJob in the SAE.
                // We don't need to use OWSFailedAttachmentDownloadsJob in the SAE.
            }
        } else {
            Logger.info("\(self.logTag) running post launch block for unregistered user.")

            // We don't need to update the app icon badge number in the SAE.
            // We don't need to prod the TSSocketManager in the SAE.
        }

        if TSAccountManager.isRegistered() {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                Logger.info("\(strongSelf.logTag) running post launch block for registered user: \(String(describing: TSAccountManager.localNumber))")

                // We don't need to use the TSSocketManager in the SAE.
                // modified: Don't fetch contacts from system contacts, use local storage instead.
                // Environment.shared.contactsManager.fetchSystemContactsOnceIfAlreadyAuthorized()
                // We don't need to fetch messages in the SAE.
                // We don't need to use OWSSyncPushTokensJob in the SAE.
            }
        }
    }

    @objc
    func versionMigrationsDidComplete() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        areVersionMigrationsComplete = true

        checkIsAppReady()
    }

    @objc
    func storageIsReady() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        checkIsAppReady()
    }

    @objc
    func checkIsAppReady() {
        AssertIsOnMainThread()

        // App isn't ready until storage is ready AND all version migrations are complete.
        guard areVersionMigrationsComplete else {
            return
        }
        guard storageCoordinator.isStorageReady else {
            return
        }
        guard !AppReadiness.isAppReady else {
            // Only mark the app as ready once.
            return
        }

        Logger.debug("\(self.logTag) \(#function)")

        // TODO: Once "app ready" logic is moved into AppSetup, move this line there.
        OWSProfileManager.shared().ensureLocalProfileCached()

        // Note that this does much more than set a flag;
        // it will also run all deferred blocks.
        AppReadiness.setAppIsReady()

        if TSAccountManager.isRegistered() {
            Logger.info("\(self.logTag) localNumber: \(String(describing: TSAccountManager.localNumber))")

            // We don't need to use messageFetcherJob in the SAE.
            // We don't need to use SyncPushTokensJob in the SAE.
        }

        // We don't need to use DeviceSleepManager in the SAE.
        AppVersion.shared().saeLaunchDidComplete()

        ensureRootViewController()

        // We don't need to use OWSMessageReceiver in the SAE.
        // We don't need to use OWSBatchMessageProcessor in the SAE.
        OWSProfileManager.shared().ensureLocalProfileCached()

        // We don't need to use OWSOrphanedDataCleaner in the SAE.
        // We don't need to fetch the local profile in the SAE
        OWSReadReceiptManager.shared().prepareCachedValues()
    }

    @objc
    func registrationStateDidChange() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        if TSAccountManager.isRegistered() {
            Logger.info("\(self.logTag) localNumber: \(String(describing: TSAccountManager.localNumber))")

            // We don't need to use OWSDisappearingMessagesJob in the SAE.
            OWSProfileManager.shared().ensureLocalProfileCached()
        }
    }

    private func ensureRootViewController() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        guard AppReadiness.isAppReady else {
            return
        }
        guard !hasInitialRootViewController else {
            return
        }
        hasInitialRootViewController = true

        Logger.info("\(logTag) Presenting initial root view controller")

        if ScreenLock.shared.isScreenLockEnabled() {
            presentScreenLock()
        } else {
            presentContentView()
        }
    }

    private func presentContentView() {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        Logger.info("\(logTag) Presenting content view")

        if !TSAccountManager.isRegistered() {
            showNotRegisteredView()
        } else if !OWSProfileManager.shared().localProfileExists() {
            // This is a rare edge case, but we want to ensure that the user
            // is has already saved their local profile key in the main app.
            showNotReadyView()
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.buildAttachmentAndPresentConversationPicker()
            }
        }

        // We don't use the AppUpdateNag in the SAE.
    }

    // MARK: Error Views
    private func showNotReadyView() {
        AssertIsOnMainThread()

        let failureTitle = Localized("SHARE_EXTENSION_NOT_YET_MIGRATED_TITLE",
                                             comment: "Title indicating that the share extension cannot be used until the main app has been launched at least once.")
        let failureMessage = Localized("SHARE_EXTENSION_NOT_YET_MIGRATED_MESSAGE",
                                               comment: "Message indicating that the share extension cannot be used until the main app has been launched at least once.")
        showErrorView(title: failureTitle, message: failureMessage)
    }

    private func showNotRegisteredView() {
        AssertIsOnMainThread()

        let failureTitle = Localized("SHARE_EXTENSION_NOT_REGISTERED_TITLE",
                                             comment: "Title indicating that the share extension cannot be used until the user has registered in the main app.")
        let failureMessage = Localized("SHARE_EXTENSION_NOT_REGISTERED_MESSAGE",
                                               comment: "Message indicating that the share extension cannot be used until the user has registered in the main app.")
        showErrorView(title: failureTitle, message: failureMessage)
    }

    private func showErrorView(title: String, message: String) {
        AssertIsOnMainThread()

        let viewController = SAEFailedViewController(delegate: self, title: title, message: message)
        self.showPrimaryViewController(viewController)
    }

    // MARK: View Lifecycle
    override open func viewDidLoad() {
        super.viewDidLoad()

        Logger.debug("\(self.logTag) \(#function)")
        
        UINavigationBar.appearance().tintColor = .ows_signalBlue

        if isReadyForAppExtensions {
            AppReadiness.runNowOrWhenAppDidBecomeReadySync({ [weak self] in
                AssertIsOnMainThread()
                guard let strongSelf = self else { return }
                strongSelf.activate()
            })
        }
    }

    @objc
    func owsApplicationWillEnterForeground() throws {
        AssertIsOnMainThread()

        Logger.debug("\(self.logTag) \(#function)")

        // If a user unregisters in the main app, the SAE should shut down
        // immediately.
        guard !TSAccountManager.isRegistered() else {
            // If user is registered, do nothing.
            return
        }
        guard let firstViewController = shareViewNavigationController.viewControllers.first else {
            // If no view has been presented yet, do nothing.
            return
        }
        if let _ = firstViewController as? SAEFailedViewController {
            // If root view is an error view, do nothing.
            return
        }
        throw ShareViewControllerError.notRegistered
    }

    // MARK: ShareViewDelegate, SAEFailedViewDelegate
    public func shareViewWasUnlocked() {
        Logger.info("\(self.logTag) \(#function)")

        presentContentView()
    }

    public func shareViewWasCompleted() {
        Logger.info("\(self.logTag) \(#function)")

        self.dismiss(animated: true) { [weak self] in
            AssertIsOnMainThread()
            guard let strongSelf = self else { return }
            strongSelf.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    public func shareViewWasCancelled() {
        Logger.info("\(self.logTag) \(#function)")

        self.dismiss(animated: true) { [weak self] in
            AssertIsOnMainThread()
            guard let strongSelf = self else { return }
            strongSelf.extensionContext!.cancelRequest(withError: NSError(domain: "user cancel error", code: NSUserCancelledError, userInfo: nil))
        }
    }

    public func shareViewFailed(error: Error) {
        Logger.info("\(self.logTag) \(#function)")

        self.dismiss(animated: true) { [weak self] in
            AssertIsOnMainThread()
            guard let strongSelf = self else { return }
            strongSelf.extensionContext!.cancelRequest(withError: error)
        }
    }
    
    // MARK: Helpers
    // This view controller is not visible to the user. It exists to intercept touches, set up the
    // extensions dependencies, and eventually present a visible view to the user.
    // For speed of presentation, we only present a single modal, and if it's already been presented
    // we swap out the contents.
    // e.g. if loading is taking a while, the user will see the load screen presented with a modal
    // animation. Next, when loading completes, the load view will be switched out for the contact
    // picker view.
    private func showPrimaryViewController(_ viewController: UIViewController) {
        AssertIsOnMainThread()

        shareViewNavigationController.presentationController?.delegate = self
        shareViewNavigationController.setViewControllers([viewController], animated: false)
        if self.presentedViewController == nil {
            Logger.debug("\(self.logTag) presenting modally: \(viewController)")
            self.present(shareViewNavigationController, animated: true)
        } else {
            Logger.debug("\(self.logTag) modal already presented. swapping modal content for: \(viewController)")
            assert(self.presentedViewController == shareViewNavigationController)
        }
    }

    private func buildAttachmentAndPresentConversationPicker() {
        AssertIsOnMainThread()
        
        guard let inputItems = self.extensionContext?.inputItems as? [NSExtensionItem] else {
            let error = ShareViewControllerError.assertionError(description: "no input item")
            self.showAlertWithError(error: error)
            return
        }
        
//        var signalAttachments = Array<SignalAttachment>()
//
//        let group = DispatchGroup()
//        let groupQueue = DispatchQueue.main
        let result_item_to_load = self.itemsToLoad(inputItems: inputItems)
        _ = result_item_to_load?.allSatisfy({ item in
            switch item.itemType {
            case .movie, .image, .webUrl, .text, .richText, .pdf:
                return true
            case .fileUrl, .contact, .pkPass, .other:
                return false
            }
        })
        guard let results = result_item_to_load else {
            return
        }
        loadItems(unloadedItems: results)
            .done { loadedItems in
                self.buildAttachments(loadedItems: loadedItems).done { signalAttachmens in
                    if signalAttachmens.count == 0 {
                        let error = ShareViewControllerError.assertionError(description: "no attachments")
                        self.showAlertWithError(error: error)
                        return
                    }
                    self.progressPoller = nil
                    self.loadViewController = nil

                    let conversationPicker = SharingThreadPickerViewController(shareViewDelegate: self)
                    Logger.debug("\(self.logTag) presentConversationPicker: \(conversationPicker)")
                    conversationPicker.attachments = signalAttachmens
                    self.showPrimaryViewController(conversationPicker)
                    Logger.info("\(self.logTag) showing picker with attachments: \(signalAttachmens)")
                }.catch { error in
                    Logger.info("buildAttachments error -> \(error.localizedDescription)")
                }
            }
            .catch { error in
                // 处理错误
                Logger.info("loadItems error -> \(error.localizedDescription)")
            }
    }
    
    private func loadItems(unloadedItems: [UnloadedItem]) -> Promise<[LoadedItem]> {
        let loadPromises: [Promise<LoadedItem>] = unloadedItems.map { unloadedItem in
            loadItem(unloadedItem: unloadedItem)
        }

        return Promise.when(fulfilled: loadPromises)
    }
    
    private func loadItem(unloadedItem: UnloadedItem) -> Promise<LoadedItem> {
        Logger.info("unloadedItem: \(unloadedItem)")

        let itemProvider = unloadedItem.itemProvider

        switch unloadedItem.itemType {
        case .movie:
            return itemProvider.loadUrl(forTypeIdentifier: kUTTypeMovie as String, options: nil).map { fileUrl in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .fileUrl(fileUrl))

            }
        case .image:
            // When multiple image formats are available, kUTTypeImage will
            // defer to jpeg when possible. On iPhone 12 Pro, when 'heic'
            // and 'jpeg' are the available options, the 'jpeg' data breaks
            // UIImage (and underlying) in some unclear way such that trying
            // to perform any kind of transformation on the image (such as
            // resizing) causes memory to balloon uncontrolled. Luckily,
            // iOS 14 provides native UIImage support for heic and iPhone
            // 12s can only be running iOS 14+, so we can request the heic
            // format directly, which behaves correctly for all our needs.
            // A radar has been opened with apple reporting this issue.
            let desiredTypeIdentifier: String
            if #available(iOS 14, *), itemProvider.registeredTypeIdentifiers.contains("public.heic") {
                desiredTypeIdentifier = "public.heic"
            } else {
                desiredTypeIdentifier = kUTTypeImage as String
            }

            return itemProvider.loadUrl(forTypeIdentifier: desiredTypeIdentifier, options: nil).map { fileUrl in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .fileUrl(fileUrl))
            }.recover(on: DispatchQueue.global()) { error -> Promise<LoadedItem> in
                let nsError = error as NSError
                assert(nsError.domain == NSItemProvider.errorDomain)
                assert(nsError.code == NSItemProvider.ErrorCode.unexpectedValueClassError.rawValue)

                // If a URL wasn't available, fall back to an in-memory image.
                // One place this happens is when sharing from the screenshot app on iOS13.
                return itemProvider.loadImage(forTypeIdentifier: kUTTypeImage as String, options: nil).map { image in
                    LoadedItem(itemProvider: unloadedItem.itemProvider,
                               payload: .inMemoryImage(image))
                }
            }
        case .webUrl:
            return itemProvider.loadUrl(forTypeIdentifier: kUTTypeURL as String, options: nil).map { url in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .webUrl(url, contentText: unloadedItem.attributedContentText?.string))
            }
        case .fileUrl:
            return itemProvider.loadUrl(forTypeIdentifier: kUTTypeFileURL as String, options: nil).map { fileUrl in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .fileUrl(fileUrl))
            }
        case .contact:
            return itemProvider.loadData(forTypeIdentifier: kUTTypeContact as String, options: nil).map { contactData in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .contact(contactData))
            }
        case .richText:
            return itemProvider.loadAttributedText(forTypeIdentifier: kUTTypeRTF as String, options: nil).map { richText in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .richText(richText))
            }
        case .text:
            return itemProvider.loadText(forTypeIdentifier: kUTTypeText as String, options: nil).map { text in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .text(text))
            }
        case .pdf:
            return itemProvider.loadData(forTypeIdentifier: kUTTypePDF as String, options: nil).map { data in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .pdf(data))
            }
        case .pkPass:
            return itemProvider.loadData(forTypeIdentifier: "com.apple.pkpass", options: nil).map { data in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .pkPass(data))
            }
        case .other:
            return itemProvider.loadUrl(forTypeIdentifier: kUTTypeFileURL as String, options: nil).map { fileUrl in
                LoadedItem(itemProvider: unloadedItem.itemProvider,
                           payload: .fileUrl(fileUrl))
            }
        }
    }
    
    private func buildAttachments(loadedItems: [LoadedItem]) -> Promise<[SignalAttachment]> {
        var attachmentPromises = [Promise<SignalAttachment>]()
        for loadedItem in loadedItems {
            attachmentPromises.append(firstly(on: DispatchQueue.sharedUserInitiated) { () -> Promise<SignalAttachment> in
                self.buildAttachment(loadedItem: loadedItem)
            })
        }
        return Promise.when(fulfilled: attachmentPromises)
    }
     
    /// Creates an attachment with from a generic "loaded item". The data source
    /// backing the returned attachment must "own" the data it provides - i.e.,
    /// it must not refer to data/files that other components refer to.
    private func buildAttachment(loadedItem: LoadedItem) -> Promise<SignalAttachment> {
        let itemProvider = loadedItem.itemProvider
        switch loadedItem.payload {
        case .webUrl(let webUrl, let contentText):
            var dataSource: AnyObject // 使用 AnyObject 类型

            if let contentText = contentText {
                dataSource = DataSourceValue.dataSource(withOversizeText: "\(contentText) \n" + "\(webUrl.absoluteString)") as AnyObject
            } else {
                dataSource = DataSourceValue.dataSource(withOversizeText: webUrl.absoluteString) as AnyObject
            }

            let attachment = SignalAttachment.attachment(dataSource: (dataSource as! DataSource), dataUTI: kUTTypeText as String)
            attachment.isConvertibleToTextMessage = true
            return Promise.value(attachment)
        case .contact(let contactData):
            let dataSource = DataSourceValue.dataSource(with: contactData, utiType: kUTTypeContact as String)
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypeContact as String)
            attachment.isConvertibleToContactShare = true
            return Promise.value(attachment)
        case .richText(let richText):
            let dataSource = DataSourceValue.dataSource(withOversizeText: richText.string)
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypeText as String)
            attachment.isConvertibleToTextMessage = true
            return Promise.value(attachment)
        case .text(let text):
            let dataSource = DataSourceValue.dataSource(withOversizeText: text)
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypeText as String)
            attachment.isConvertibleToTextMessage = true
            return Promise.value(attachment)
        case .fileUrl(let originalItemUrl):
            var itemUrl = originalItemUrl
            do {
                if isVideoNeedingRelocation(itemProvider: itemProvider, itemUrl: itemUrl) {
                    itemUrl = try SignalAttachment.copyToVideoTempDir(url: itemUrl)
                }
            } catch {
                let error = ShareViewControllerError.assertionError(description: "Could not copy video")
                return Promise(error: error)
            }

            guard let dataSource = try? DataSourcePath.dataSource(with: itemUrl, shouldDeleteOnDeallocation: false) else {
                let error = ShareViewControllerError.assertionError(description: "Attachment URL was not a file URL")
                return Promise(error: error)
            }
            dataSource.sourceFilename = itemUrl.lastPathComponent

            let utiType = MIMETypeUtil.utiType(forFileExtension: itemUrl.pathExtension) ?? kUTTypeData as String

            if SignalAttachment.isVideoThatNeedsCompression(dataSource: dataSource, dataUTI: utiType) {
                // This can happen, e.g. when sharing a quicktime-video from iCloud drive.

                let (promise, exportSession) = SignalAttachment.compressVideoAsMp4(dataSource: dataSource, dataUTI: utiType)

                // TODO: How can we move waiting for this export to the end of the share flow rather than having to do it up front?
                // Ideally we'd be able to start it here, and not block the UI on conversion unless there's still work to be done
                // when the user hits "send".
                if let exportSession = exportSession {
                    DispatchQueue.main.async {
                        let progressPoller = ProgressPoller(timeInterval: 0.1, ratioCompleteBlock: { return exportSession.progress })

                        self.progressPoller = progressPoller
                        progressPoller.startPolling()

                        self.loadViewController?.progress = progressPoller.progress
                    }
                }

                return promise
            }

            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: utiType)

            // If we already own the attachment's data - i.e. we have copied it
            // from the URL originally passed in, and therefore no one else can
            // be referencing it - we can return the attachment as-is...
            if attachment.dataUrl != originalItemUrl {
                return Promise.value(attachment)
            }

            // ...otherwise, we should clone the attachment to ensure we aren't
            // touching data someone else might be referencing.
            do {
                return Promise.value(try attachment.cloneAttachment())
            } catch {
                let error = ShareViewControllerError.assertionError(description: "Failed to clone attachment")
                return Promise(error: error)
            }
        case .inMemoryImage(let image):
            guard let pngData = image.pngData() else {
                return Promise(error: OWSAssertionError("pngData was unexpectedly nil"))
            }
            let dataSource = DataSourceValue.dataSource(with: pngData, fileExtension: "png")
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypePNG as String)
            return Promise.value(attachment)
        case .pdf(let pdf):
            let dataSource = DataSourceValue.dataSource(with: pdf, fileExtension: "pdf")
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: kUTTypePDF as String)
            return Promise.value(attachment)
        case .pkPass(let pkPass):
            let dataSource = DataSourceValue.dataSource(with: pkPass, fileExtension: "pkpass")
            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: "com.apple.pkpass")
            return Promise.value(attachment)
        }
    }
    
    private func itemsToLoad(inputItems: [NSExtensionItem]) -> [UnloadedItem]? {
        for inputItem in inputItems {
            guard let itemProviders = inputItem.attachments else {
                return nil
            }
            Logger.info("NSExtensionItem.inputItem.attributedTitle = \(String(describing: inputItem.attributedTitle))")
            Logger.info("NSExtensionItem.inputItem.attributedContentText = \(String(describing: inputItem.attributedContentText))")
            let attributedContentText = inputItem.attributedContentText
            let itemsToLoad: [UnloadedItem] = itemProviders.compactMap { itemProvider in
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .movie)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .image)
                }

                if ShareViewController.isUrlItem(itemProvider: itemProvider) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .webUrl)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .fileUrl)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeVCard as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .contact)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeRTF as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .richText)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .text)
                }

                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypePDF as String) {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .pdf)
                }

                if itemProvider.hasItemConformingToTypeIdentifier("com.apple.pkpass") {
                    return UnloadedItem(attributedContentText: attributedContentText, itemProvider: itemProvider, itemType: .pkPass)
                }

                owsFailDebug("unexpected share item: \(itemProvider)")
                return nil
            }

            if let urlItem = itemsToLoad.first(where: { $0.itemType == .webUrl }) {
                return [urlItem]
            }

            let visualMediaItems = itemsToLoad.filter { ShareViewController.isVisualMediaItem(itemProvider: $0.itemProvider) }

            if visualMediaItems.count > 0 {
                return visualMediaItems
            } else if itemsToLoad.count > 0 {
                return Array(itemsToLoad.prefix(1))
            }
        }
        return nil
    }

    private
    struct LoadedItem {
        enum LoadedItemPayload {
            case fileUrl(_ fileUrl: URL)
            case inMemoryImage(_ image: UIImage)
            case webUrl(_ webUrl: URL, contentText: String?)
            case contact(_ contactData: Data)
            case richText(_ richText: NSAttributedString)
            case text(_ text: String)
            case pdf(_ data: Data)
            case pkPass(_ data: Data)

            var debugDescription: String {
                switch self {
                case .fileUrl:
                    return "fileUrl"
                case .inMemoryImage:
                    return "inMemoryImage"
                case .webUrl:
                    return "webUrl"
                case .contact:
                    return "contact"
                case .richText:
                    return "richText"
                case .text:
                    return "text"
                case .pdf:
                    return "pdf"
                case .pkPass:
                    return "pkPass"
                }
            }
        }

        let itemProvider: NSItemProvider
        let payload: LoadedItemPayload

        var customFileName: String? {
            isContactShare ? "Contact.vcf" : nil
        }

        private var isContactShare: Bool {
            if case .contact = payload {
                return true
            } else {
                return false
            }
        }

        var debugDescription: String {
            payload.debugDescription
        }
    }
    private
    struct UnloadedItem {
        enum ItemType {
            case movie
            case image
            case webUrl
            case fileUrl
            case contact
            case richText
            case text
            case pdf
            case pkPass
            case other
        }

        let attributedContentText: NSAttributedString?
        let itemProvider: NSItemProvider
        let itemType: ItemType
    }
    
   
    
    private class func isVisualMediaItem(itemProvider: NSItemProvider) -> Bool {
        return (itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) ||
            itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String))
    }
    private func presentScreenLock() {
        AssertIsOnMainThread()

        let screenLockUI = SAEScreenLockViewController(shareViewDelegate: self)
        Logger.debug("\(self.logTag) presentScreenLock: \(screenLockUI)")
        showPrimaryViewController(screenLockUI)
        Logger.info("\(self.logTag) showing screen lock")
    }

    private class func itemMatchesSpecificUtiType(itemProvider: NSItemProvider, utiType: String) -> Bool {
        // URLs, contacts and other special items have to be detected separately.
        // Many shares (e.g. pdfs) will register many UTI types and/or conform to kUTTypeData.
        guard itemProvider.registeredTypeIdentifiers.count == 1 else {
            return false
        }
        guard let firstUtiType = itemProvider.registeredTypeIdentifiers.first else {
            return false
        }
        return firstUtiType == utiType
    }

    private class func isUrlItem(itemProvider: NSItemProvider) -> Bool {
        return itemMatchesSpecificUtiType(itemProvider: itemProvider,
                                          utiType: kUTTypeURL as String)
    }

    private class func isContactItem(itemProvider: NSItemProvider) -> Bool {
        return itemMatchesSpecificUtiType(itemProvider: itemProvider,
                                          utiType: kUTTypeContact as String)
    }

    private class func utiType(itemProvider: NSItemProvider) -> String? {
        Logger.info("\(String(describing: self.logTag)) utiTypeForItem: \(itemProvider.registeredTypeIdentifiers)")

        if isUrlItem(itemProvider: itemProvider) {
            return kUTTypeURL as String
        } else if isContactItem(itemProvider: itemProvider) {
            return kUTTypeContact as String
        }

        // Use the first UTI that conforms to "data".
        let matchingUtiType = itemProvider.registeredTypeIdentifiers.first { (utiType: String) -> Bool in
            UTTypeConformsTo(utiType as CFString, kUTTypeData)
        }
        return matchingUtiType
    }

    private class func createDataSource(utiType: String, url: URL, customFileName: String?) -> DataSource? {
        if utiType == (kUTTypeURL as String) {
            // Share URLs as oversize text messages whose text content is the URL.
            //
            // NOTE: SharingThreadPickerViewController will try to unpack them
            //       and send them as normal text messages if possible.
            let urlString = url.absoluteString
            return DataSourceValue.dataSource(withOversizeText: urlString)
        } else if UTTypeConformsTo(utiType as CFString, kUTTypeText) {
            // Share text as oversize text messages.
            //
            // NOTE: SharingThreadPickerViewController will try to unpack them
            //       and send them as normal text messages if possible.
            do {
                return try DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false)
            } catch {
                OWSLogger.error(error.localizedDescription)
                return nil
            }
        } else {
            do {
                let dataSource = try DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false)
                
                if let customFileName = customFileName {
                    dataSource.sourceFilename = customFileName
                } else {
                    // Ignore the filename for URLs.
                    dataSource.sourceFilename = url.lastPathComponent
                }
                return dataSource
            } catch {
                OWSLogger.error(error.localizedDescription)
                return nil
            }
        }
    }

//    private func buildAttachment(_ itemProvider: NSItemProvider) -> Promise<SignalAttachment> {
//
//        // We need to be very careful about which UTI type we use.
//        //
//        // * In the case of "textual" shares (e.g. web URLs and text snippets), we want to
//        //   coerce the UTI type to kUTTypeURL or kUTTypeText.
//        // * We want to treat shared files as file attachments.  Therefore we do not
//        //   want to treat file URLs like web URLs.
//        // * UTIs aren't very descriptive (there are far more MIME types than UTI types)
//        //   so in the case of file attachments we try to refine the attachment type
//        //   using the file extension.
//        guard let srcUtiType = ShareViewController.utiType(itemProvider: itemProvider) else {
//            let error = ShareViewControllerError.unsupportedMedia
//            return Promise(error: error)
//        }
//        Logger.debug("\(logTag) matched utiType: \(srcUtiType)")
//
//        let (promise, resolver) = Promise<(itemUrl: URL, utiType: String)>.pending()
//
//        var customFileName: String?
//        var isConvertibleToTextMessage = false
//        var isConvertibleToContactShare = false
//
//        itemProvider.loadItem(forTypeIdentifier: srcUtiType, options: nil) { [weak self]
//            (value, error) in
//            
//            guard let strongSelf = self else { return }
//            
//            guard error == nil else {
//                resolver.reject(error!)
//                return
//            }
//            
//            guard let value = value else {
//                let missingProviderError = ShareViewControllerError.assertionError(description: "missing item provider")
//                resolver.reject(missingProviderError)
//                return
//            }
//            
//            Logger.info("\(strongSelf.logTag) value type: \(Self.self))")
//            
//            if let data = value as? Data {
//                // Although we don't support contacts _yet_, when we do we'll want to make
//                // sure they are shared with a reasonable filename.
//                if ShareViewController.itemMatchesSpecificUtiType(itemProvider: itemProvider,
//                                                                  utiType: kUTTypeVCard as String) {
//                    customFileName = "Contact.vcf"
//                    
//                    if Contact(vCardData: data) != nil {
//                        isConvertibleToContactShare = true
//                    } else {
//                        Logger.error("\(strongSelf.logTag) could not parse vcard.")
//                        let writeError = ShareViewControllerError.assertionError(description: "Could not parse vcard data.")
//                        resolver.reject(writeError)
//                        return
//                    }
//                }
//                
//                let customFileExtension = MIMETypeUtil.fileExtension(forUTIType: srcUtiType)
//                guard let tempFilePath = OWSFileSystem.writeData(toTemporaryFile: data, fileExtension: customFileExtension) else {
//                    let writeError = ShareViewControllerError.assertionError(description: "Error writing item data: \(String(describing: error))")
//                    resolver.reject(writeError)
//                    return
//                }
//                let fileUrl = URL(fileURLWithPath: tempFilePath)
//                resolver.resolve((itemUrl: fileUrl, utiType: srcUtiType))
//            } else if let string = value as? String {
//                Logger.debug("\(strongSelf.logTag) string provider: \(string)")
//                guard let data = string.filterStringForDisplay().data(using: String.Encoding.utf8) else {
//                    let writeError = ShareViewControllerError.assertionError(description: "Error writing item data: \(String(describing: error))")
//                    resolver.reject(writeError)
//                    return
//                }
//                guard let tempFilePath = OWSFileSystem.writeData(toTemporaryFile: data, fileExtension: "txt") else {
//                    let writeError = ShareViewControllerError.assertionError(description: "Error writing item data: \(String(describing: error))")
//                    resolver.reject(writeError)
//                    return
//                }
//                
//                let fileUrl = URL(fileURLWithPath: tempFilePath)
//                
//                isConvertibleToTextMessage = !itemProvider.registeredTypeIdentifiers.contains(kUTTypeFileURL as String)
//                
//                if UTTypeConformsTo(srcUtiType as CFString, kUTTypeText) {
//                    resolver.resolve((itemUrl: fileUrl, utiType: srcUtiType))
//                } else {
//                    resolver.resolve((itemUrl: fileUrl, utiType:  kUTTypeText as String))
//                }
//            } else if let url = value as? URL {
//                // If the share itself is a URL (e.g. a link from Safari), try to send this as a text message.
//                isConvertibleToTextMessage = (itemProvider.registeredTypeIdentifiers.contains(kUTTypeURL as String) &&
//                                              !itemProvider.registeredTypeIdentifiers.contains(kUTTypeFileURL as String))
//                if isConvertibleToTextMessage {
//                    resolver.resolve((itemUrl: url, utiType: kUTTypeURL as String))
//                } else {
//                    resolver.resolve((itemUrl: url, utiType: srcUtiType))
//                }
//            } else if let image = value as? UIImage {
//                if let data = image.pngData() {
//                    let tempFilePath = OWSFileSystem.temporaryFilePath(fileExtension: "png")
//                    do {
//                        let url = NSURL.fileURL(withPath: tempFilePath)
//                        try data.write(to: url)
//                        resolver.resolve((url, srcUtiType))
//                    } catch {
//                        resolver.reject(ShareViewControllerError.assertionError(description: "couldn't write UIImage: \(String(describing: error))"))
//                    }
//                } else {
//                    resolver.reject(ShareViewControllerError.assertionError(description: "couldn't convert UIImage to PNG: \(String(describing: error))"))
//                }
//            } else {
//                // It's unavoidable that we may sometimes receives data types that we
//                // don't know how to handle.
//                let unexpectedTypeError = ShareViewControllerError.assertionError(description: "unexpected value: \(String(describing: value))")
//                resolver.reject(unexpectedTypeError)
//            }
//        }
//
//        return promise.then { [weak self] (itemUrl: URL, utiType: String) -> Promise<SignalAttachment> in
//            guard let strongSelf = self else {
//                let error = ShareViewControllerError.obsoleteShare
//                return Promise(error: error)
//            }
//
//            let url: URL = try {
//                if strongSelf.isVideoNeedingRelocation(itemProvider: itemProvider, itemUrl: itemUrl) {
//                    return try SignalAttachment.copyToVideoTempDir(url: itemUrl)
//                } else {
//                    return itemUrl
//                }
//            }()
//
//            Logger.debug("\(strongSelf.logTag) building DataSource with url: \(url), utiType: \(utiType)")
//
//            guard let dataSource = ShareViewController.createDataSource(utiType: utiType, url: url, customFileName: customFileName) else {
//                throw ShareViewControllerError.assertionError(description: "Unable to read attachment data")
//            }
//
//            // start with base utiType, but it might be something generic like "image"
//            var specificUTIType = utiType
//            if utiType == (kUTTypeURL as String) {
//                // Use kUTTypeURL for URLs.
//            } else if UTTypeConformsTo(utiType as CFString, kUTTypeText) {
//                // Use kUTTypeText for text.
//            } else if url.pathExtension.count > 0 {
//                // Determine a more specific utiType based on file extension
//                if let typeExtension = MIMETypeUtil.utiType(forFileExtension: url.pathExtension) {
//                    Logger.debug("\(strongSelf.logTag) utiType based on extension: \(typeExtension)")
//                    specificUTIType = typeExtension
//                }
//            }
//
//            guard !SignalAttachment.isInvalidVideo(dataSource: dataSource, dataUTI: specificUTIType) else {
//                // This can happen, e.g. when sharing a quicktime-video from iCloud drive.
//                let (promise, exportSession) = SignalAttachment.compressVideoAsMp4(dataSource: dataSource, dataUTI: specificUTIType)
//
//                // TODO: How can we move waiting for this export to the end of the share flow rather than having to do it up front?
//                // Ideally we'd be able to start it here, and not block the UI on conversion unless there's still work to be done
//                // when the user hits "send".
//                if let exportSession = exportSession {
//                    let progressPoller = ProgressPoller(timeInterval: 0.1, ratioCompleteBlock: { return exportSession.progress })
//                    strongSelf.progressPoller = progressPoller
//                    progressPoller.startPolling()
//
//                    guard let loadViewController = strongSelf.loadViewController else {
//                        owsFailDebug("load view controller was unexpectedly nil")
//                        return promise
//                    }
//
//                    DispatchQueue.main.async {
//                        loadViewController.progress = progressPoller.progress
//                    }
//                }
//
//                return promise
//            }
//
//            let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: specificUTIType, imageQuality: .medium)
//            if isConvertibleToContactShare {
//                Logger.info("\(strongSelf.logTag) isConvertibleToContactShare")
//                attachment.isConvertibleToContactShare = isConvertibleToContactShare
//            } else if isConvertibleToTextMessage {
//                Logger.info("\(strongSelf.logTag) isConvertibleToTextMessage")
//                attachment.isConvertibleToTextMessage = isConvertibleToTextMessage
//            }
//            return Promise.value(attachment)
//        }
//    }

    // Some host apps (e.g. iOS Photos.app) sometimes auto-converts some video formats (e.g. com.apple.quicktime-movie)
    // into mp4s as part of the NSItemProvider `loadItem` API. (Some files the Photo's app doesn't auto-convert)
    //
    // However, when using this url to the converted item, AVFoundation operations such as generating a
    // preview image and playing the url in the AVMoviePlayer fails with an unhelpful error: "The operation could not be completed"
    //
    // We can work around this by first copying the media into our container.
    //
    // I don't understand why this is, and I haven't found any relevant documentation in the NSItemProvider
    // or AVFoundation docs.
    //
    // Notes:
    //
    // These operations succeed when sending a video which initially existed on disk as an mp4.
    // (e.g. Alice sends a video to Bob through the main app, which ensures it's an mp4. Bob saves it, then re-shares it)
    //
    // I *did* verify that the size and SHA256 sum of the original url matches that of the copied url. So there
    // is no difference between the contents of the file, yet one works one doesn't.
    // Perhaps the AVFoundation APIs require some extra file system permssion we don't have in the
    // passed through URL.
    private func isVideoNeedingRelocation(itemProvider: NSItemProvider, itemUrl: URL) -> Bool {
        let pathExtension = itemUrl.pathExtension
        guard pathExtension.count > 0 else {
            Logger.verbose("\(self.logTag) in \(#function): item URL has no file extension: \(itemUrl).")
            return false
        }
        guard let utiTypeForURL = MIMETypeUtil.utiType(forFileExtension: pathExtension) else {
            Logger.verbose("\(self.logTag) in \(#function): item has unknown UTI type: \(itemUrl).")
            return false
        }
        Logger.verbose("\(self.logTag) utiTypeForURL: \(utiTypeForURL)")
        guard utiTypeForURL == kUTTypeMPEG4 as String else {
            // Either it's not a video or it was a video which was not auto-converted to mp4.
            // Not affected by the issue.
            return false
        }

        // If video file already existed on disk as an mp4, then the host app didn't need to
        // apply any conversion, so no need to relocate the app.
        return !itemProvider.registeredTypeIdentifiers.contains(kUTTypeMPEG4 as String)
    }
    
    private func showAlertWithError(error: Error) {
        
        AssertIsOnMainThread()
        let alertTitle = Localized("SHARE_EXTENSION_UNABLE_TO_BUILD_ATTACHMENT_ALERT_TITLE",
                                           comment: "Shown when trying to share content to a Signal user for the share extension. Followed by failure details.")
        OWSAlerts.showAlert(title: alertTitle,
                            message: error.localizedDescription,
                            buttonTitle: CommonStrings.cancelButton()) { _ in
                                self.shareViewWasCancelled()
        }
        owsFailDebug("\(self.logTag) building attachment failed with error: \(error)")
    }
}

extension ShareViewController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        shareViewWasCancelled()
    }
}

// Exposes a Progress object, whose progress is updated by polling the return of a given block
private class ProgressPoller {

    let TAG = "[ProgressPoller]"

    let progress: Progress
    private(set) var timer: Timer?

    // Higher number offers higher ganularity
    let progressTotalUnitCount: Int64 = 10000
    private let timeInterval: Double
    private let ratioCompleteBlock: () -> Float

    init(timeInterval: TimeInterval, ratioCompleteBlock: @escaping () -> Float) {
        self.timeInterval = timeInterval
        self.ratioCompleteBlock = ratioCompleteBlock

        self.progress = Progress()

        progress.totalUnitCount = progressTotalUnitCount
        progress.completedUnitCount = Int64(ratioCompleteBlock() * Float(progressTotalUnitCount))
    }

    func startPolling() {
        guard self.timer == nil else {
            owsFailDebug("already started timer")
            return
        }

        self.timer = WeakTimer.scheduledTimer(timeInterval: timeInterval, target: self, userInfo: nil, repeats: true) { [weak self] (timer) in
            guard let strongSelf = self else {
                return
            }

            let completedUnitCount = Int64(strongSelf.ratioCompleteBlock() * Float(strongSelf.progressTotalUnitCount))
            strongSelf.progress.completedUnitCount = completedUnitCount

            if completedUnitCount == strongSelf.progressTotalUnitCount {
                Logger.debug("\(strongSelf.TAG) progress complete")
                timer.invalidate()
            }
        }
    }
}
