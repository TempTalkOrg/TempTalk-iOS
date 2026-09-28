//
//  ConversationViewController+Attachment.swift
//  Wea
//
//  Created by Felix on 2022/5/31.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import QuickLook
import SSZipArchive
import TTServiceKit

// MARK: Public

@objc extension ConversationViewController {
    
    var genericAttachmenViewItem: ConversationViewItem? {
        get { viewState.genericAttachmenViewItem }
        set { viewState.genericAttachmenViewItem = newValue }
    }
    
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }
    
    public override var shouldAutorotate: Bool {
        false
    }
    
    /// 预览附件
    func previewAttachment(
        attachmentStream: TSAttachmentStream,
        viewItem: ConversationViewItem,
        confidentialMessage: TSMessage? = nil
    ) {
        let requestID = UUID()
        let isStoredEncrypted = attachmentStream.hasEncryptedFile
            || (attachmentStream.isUploaded && attachmentStream.hasUsableEncryptionMetadata)

        if let confidentialMessage {
            viewState.attachmentPreviewRequestID = requestID
            DTConfidentialPreviewFactory.load(
                attachmentStream: attachmentStream,
                incomingMessage: confidentialMessage as? TSIncomingMessage
            ) { [weak self] result in
                guard let self else { return }
                guard self.viewState.attachmentPreviewRequestID == requestID else { return }
                self.viewState.attachmentPreviewRequestID = nil

                switch result {
                case .success(let previewController):
                    self.presentConfidentialAttachmentPreview(
                        previewController,
                        viewItem: viewItem
                    )
                case .failure(let error):
                    DTToastHelper.show(withInfo: error.localizedDescription)
                }
            }
            return
        }

        if isStoredEncrypted {
            viewState.attachmentPreviewRequestID = requestID
            DTQuickLookPreviewFile.prepareDecryptedCopy(
                from: attachmentStream
            ) { [weak self] result in
                guard let self else {
                    if case .success(let previewURL) = result {
                        DTQuickLookPreviewFile.cleanUp(previewURL)
                    }
                    return
                }
                guard self.viewState.attachmentPreviewRequestID == requestID else {
                    if case .success(let previewURL) = result {
                        DTQuickLookPreviewFile.cleanUp(previewURL)
                    }
                    return
                }
                self.viewState.attachmentPreviewRequestID = nil

                switch result {
                case .success(let previewURL):
                    self.presentAttachmentPreview(
                        at: previewURL,
                        viewItem: viewItem
                    )
                case .failure(let error):
                    DTToastHelper.show(withInfo: error.localizedDescription)
                }
            }
            return
        }

        // Invalidate any encrypted preview still being prepared before opening a
        // plaintext attachment synchronously.
        viewState.attachmentPreviewRequestID = nil
        guard let filePath = attachmentStream.filePath(),
              FileManager.default.fileExists(atPath: filePath) else {
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        guard QLPreviewController.canPreview(fileURL as NSURL) else {
            DTToastHelper.show(withInfo: Localized("UNSUPPORTED_ATTACHMENT"))
            return
        }
        // Stage a hard link so QuickLook's "Save to Files" cannot crash if the original
        // file is removed (upload completion, disappearing message, recall) mid-preview.
        guard let previewURL = DTQuickLookPreviewFile.make(from: fileURL) else {
            DTToastHelper.show(withInfo: Localized("UNSUPPORTED_ATTACHMENT"))
            return
        }
        presentAttachmentPreview(
            at: previewURL,
            viewItem: viewItem
        )
    }
    
    /// 点击 incoming message 中下载失败的附件
    func tapDownloadFailedAttachmentForIncomingMessage(
        viewItem: ConversationViewItem,
        attachmentPointer: TSAttachmentPointer,
        autoRestart: Bool
    ) {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        if autoRestart {
            redownloadAttachment(attachmentPointer, for: message)
        } else {
            showRedownloadActionSheet(attachmentPointer: attachmentPointer, for: message)
        }
    }
    
    /// 点击引用消息中下载失败的缩略图
    func tapDownloadFailedThumbnailForQuotedReply(
        _ quotedReply: OWSQuotedReplyModel,
        viewItem: ConversationViewItem,
        attachmentPointer: TSAttachmentPointer
    ) {
        guard let message = viewItem.interaction as? TSMessage else {
            owsFailDebug("message had unexpected class: \(type(of: viewItem.interaction))")
            return
        }
        
        let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
        databaseStorage.asyncWrite { transaction in
            processor.fetchAttachments(
                for: nil,
                forceDownload: true,
                transaction: transaction
            ) { [weak self] attachmentStream in
                
                guard let self else { return }
                self.databaseStorage.asyncWrite { postSuccessTransaction in
                    message.setQuotedMessageThumbnailAttachmentStream(attachmentStream)
                    message.anyInsert(transaction: transaction)
                }
                
            } failure: { [weak self] error in
                
                guard let self else { return }
                OWSLogger.warn("\(self.logTag) Failed to redownload thumbnail with error: \(error.localizedDescription)")
                
                self.databaseStorage.asyncWrite { postFailedTransaction in
                    guard let _ = message.grdbId else {
                        return
                    }
                    self.databaseStorage.touch(
                        interaction: message,
                        shouldReindex: false,
                        transaction: postFailedTransaction
                    )
                }
                
            }
        }
    }
}

// MARK: - QLPreviewControllerDataSource & QLPreviewControllerDelegate

extension ConversationViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let item = self.currentPreviewFileURL else {
            owsFailDebug("currentPreviewFileURL was unexpectedly nil")
            controller.dismiss(animated: true)
            // Hand QuickLook a real on-disk file so it never exports an invalid URL.
            return DTQuickLookPreviewFile.placeholder()
        }
        return item
    }

    public func previewControllerWillDismiss(_ controller: QLPreviewController) {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    public func previewControllerDidDismiss(_ controller: QLPreviewController) {
        finishCurrentAttachmentPreview()
    }

    public func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }
    
}

// MARK: - Private

private extension ConversationViewController {
    func presentAttachmentPreview(
        at previewURL: URL,
        viewItem: ConversationViewItem
    ) {
        guard viewIfLoaded?.window != nil,
              !isBeingDismissed,
              !(navigationController?.isBeingDismissed ?? false),
              presentedViewController == nil,
              navigationController?.presentedViewController == nil else {
            DTQuickLookPreviewFile.cleanUp(previewURL)
            return
        }

        DTQuickLookPreviewFile.cleanUp(currentPreviewFileURL as URL?)
        genericAttachmenViewItem = viewItem

        // QLPreviewController is intentionally created per presentation. Reusing a dismissed
        // instance can leave Quick Look's private preview hierarchy blank on the next open.
        currentPreviewFileURL = previewURL as NSURL
        let previewController = QLPreviewController()
        previewController.delegate = self
        previewController.dataSource = self
        previewController.currentPreviewItemIndex = 0
        previewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissAttachmentPreview)
        )

        let previewNavigationController = UINavigationController(
            rootViewController: previewController
        )
        previewNavigationController.modalPresentationStyle = .fullScreen
        previewNavigationController.modalTransitionStyle = .coverVertical
        present(previewNavigationController, animated: true)
    }

    @objc
    func dismissAttachmentPreview() {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        dismiss(animated: true) { [weak self] in
            self?.finishCurrentAttachmentPreview()
        }
    }

    func presentConfidentialAttachmentPreview(
        _ previewController: DTConfidentialPreviewController,
        viewItem: ConversationViewItem
    ) {
        guard viewIfLoaded?.window != nil,
              !isBeingDismissed,
              !(navigationController?.isBeingDismissed ?? false),
              presentedViewController == nil,
              navigationController?.presentedViewController == nil else {
            return
        }

        genericAttachmenViewItem = viewItem
        viewState.confidentialAttachmentPreviewController = previewController
        previewController.present(from: self)
    }

    func finishCurrentAttachmentPreview() {
        let previewURL = currentPreviewFileURL as URL?
        currentPreviewFileURL = nil
        DTQuickLookPreviewFile.cleanUp(previewURL)
    }

    var currentPreviewFileURL: NSURL? {
        get {
            viewState.currentPreviewFileURL
        }
        set {
            viewState.currentPreviewFileURL = newValue
        }
    }

    /// 重新下载附件
    func redownloadAttachment(
        _ attachmentPointer: TSAttachmentPointer,
        forceDownload: Bool = false,
        for message: TSMessage
    ) {
        let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
        processor.fetchAttachments(for: message, forceDownload: forceDownload) { _ in
            OWSLogger.info("Successfully redownloaded attachment in message timestamp: \(String(describing: message.timestampForSorting)), uniqueThreadId: \(message.uniqueThreadId)")
        } failure: { error in
            OWSLogger.warn("\(self.logTag) Failed to redownload message with error: \(error.localizedDescription)")
        }
    }
    
    /// 展示是否重新下载弹窗
    func showRedownloadActionSheet(attachmentPointer: TSAttachmentPointer, for message: TSMessage) {
        let actionSheet = ActionSheetController()
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let retryTitle = attachmentPointer.state == .enqueued ? Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTION") : Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_RETRY_ACTION")
        let retryAction = ActionSheetAction(title: retryTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            self.redownloadAttachment(attachmentPointer, forceDownload: true, for: message)
        }
        actionSheet.addAction(retryAction)

        dismissKeyBoard(byUserAction: true)  // 用户点击重试下载，标记为用户操作
        presentActionSheet(actionSheet)
    }
}

extension ConversationViewController {
    /// Match Android's confidential-preview lifecycle: keep an already visible preview alive
    /// across background/foreground, but invalidate work that has not presented yet.
    func handleConfidentialAttachmentPreviewWillResignActive() {
        // A confidential request may still be decrypting and therefore not have populated the
        // current-preview state yet. Invalidate it so the callback cannot present after the app
        // has resigned active.
        viewState.attachmentPreviewRequestID = nil
    }
}

// MARK: - Confidential attachment preview

private protocol DTConfidentialPreviewControlling: AnyObject {
    func present(from presenter: UIViewController)
}

private typealias DTConfidentialPreviewController = UIViewController & DTConfidentialPreviewControlling

private enum DTConfidentialPreviewFactory {
    static func load(
        attachmentStream: TSAttachmentStream,
        incomingMessage: TSIncomingMessage?,
        completion: @escaping ResultHandler
    ) {
        let contentType = attachmentStream.contentType.lowercased()
        let fileExtension = (attachmentStream.sourceFilename as NSString?)?
            .pathExtension.lowercased()
        if contentType == "application/zip" || fileExtension == "zip" {
            DTConfidentialArchivePreviewController.load(
                attachmentStream: attachmentStream,
                incomingMessage: incomingMessage,
                completion: completion
            )
        } else {
            DTConfidentialAttachmentPreviewController.load(
                attachmentStream: attachmentStream,
                incomingMessage: incomingMessage
            ) { result in
                completion(result.map { $0 as DTConfidentialPreviewController })
            }
        }
    }

    typealias ResultHandler = (
        Result<DTConfidentialPreviewController, DTQuickLookPreviewFile.PreviewError>
    ) -> Void
}

private struct DTConfidentialArchiveItem {
    let fileURL: URL
    let relativePath: String
    let byteCount: Int64
}

private final class DTConfidentialArchiveExtractionGuard: NSObject, SSZipArchiveDelegate {
    private let maximumEntryCount: Int

    init(maximumEntryCount: Int) {
        self.maximumEntryCount = maximumEntryCount
    }

    func zipArchiveShouldUnzipFile(
        at fileIndex: Int,
        totalFiles: Int,
        archivePath: String,
        fileInfo: unz_file_info
    ) -> Bool {
        totalFiles <= maximumEntryCount && fileIndex < maximumEntryCount
    }
}

/// ZIP archives use an app-owned file browser. Quick Look's archive browser creates a private
/// nested preview controller whose Save/share surfaces can't be controlled by the outer viewer.
private final class DTConfidentialArchivePreviewController:
    UIViewController,
    DTConfidentialPreviewControlling,
    UITableViewDataSource,
    UITableViewDelegate {

    private static let maximumExpandedByteCount: UInt64 = 128 * 1024 * 1024
    private static let maximumEntryCount = 512

    private let previewFileURL: URL
    private let items: [DTConfidentialArchiveItem]
    private let incomingMessage: TSIncomingMessage?
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var hasMarkedMessageViewed = false
    private var hasDestroyedMessage = false
    private var hasCleanedUp = false
    private var hasShownHint = false

    static func load(
        attachmentStream: TSAttachmentStream,
        incomingMessage: TSIncomingMessage?,
        completion: @escaping DTConfidentialPreviewFactory.ResultHandler
    ) {
        DTQuickLookPreviewFile.prepareDecryptedCopy(from: attachmentStream) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let previewFileURL):
                DispatchQueue.global(qos: .userInitiated).async {
                    let extractionResult = extractArchive(previewFileURL: previewFileURL)
                    DispatchQueue.main.async {
                        switch extractionResult {
                        case .failure(let error):
                            DTQuickLookPreviewFile.cleanUp(previewFileURL)
                            completion(.failure(error))
                        case .success(let items):
                            completion(.success(DTConfidentialArchivePreviewController(
                                previewFileURL: previewFileURL,
                                items: items,
                                filename: attachmentStream.sourceFilename,
                                incomingMessage: incomingMessage
                            )))
                        }
                    }
                }
            }
        }
    }

    private static func extractArchive(
        previewFileURL: URL
    ) -> Result<[DTConfidentialArchiveItem], DTQuickLookPreviewFile.PreviewError> {
        var payloadError: NSError?
        let payloadSize = SSZipArchive.payloadSizeForArchive(
            atPath: previewFileURL.path,
            error: &payloadError
        ).uint64Value
        guard payloadError == nil else {
            return .failure(.unsupportedFormat)
        }
        guard payloadSize <= maximumExpandedByteCount else {
            return .failure(.fileTooLarge)
        }

        let fileManager = FileManager.default
        let rootURL = previewFileURL.deletingLastPathComponent()
            .appendingPathComponent("Archive", isDirectory: true)
        do {
            try fileManager.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            var unzipError: NSError?
            let extractionGuard = DTConfidentialArchiveExtractionGuard(
                maximumEntryCount: maximumEntryCount
            )
            let succeeded = SSZipArchive.unzipFile(
                atPath: previewFileURL.path,
                toDestination: rootURL.path,
                preserveAttributes: false,
                overwrite: false,
                password: nil,
                error: &unzipError,
                delegate: extractionGuard
            )
            guard succeeded, unzipError == nil else {
                throw unzipError ?? NSError(domain: SSZipArchiveErrorDomain, code: -1)
            }

            let resourceKeys: [URLResourceKey] = [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey
            ]
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else {
                throw NSError(domain: SSZipArchiveErrorDomain, code: -1)
            }

            var items: [DTConfidentialArchiveItem] = []
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                guard values.isSymbolicLink != true else {
                    throw NSError(domain: SSZipArchiveErrorDomain, code: -1)
                }
                guard values.isRegularFile == true else { continue }
                guard items.count < maximumEntryCount else {
                    throw NSError(domain: SSZipArchiveErrorDomain, code: -1)
                }
                let standardizedPath = fileURL.standardizedFileURL.path
                guard standardizedPath.hasPrefix(rootURL.standardizedFileURL.path + "/") else {
                    throw NSError(domain: SSZipArchiveErrorDomain, code: -1)
                }
                try fileManager.setAttributes(
                    [.protectionKey: FileProtectionType.complete],
                    ofItemAtPath: fileURL.path
                )
                let relativePath = String(standardizedPath.dropFirst(rootURL.path.count + 1))
                items.append(DTConfidentialArchiveItem(
                    fileURL: fileURL,
                    relativePath: relativePath,
                    byteCount: Int64(values.fileSize ?? 0)
                ))
            }
            items.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
            return .success(items)
        } catch {
            try? fileManager.removeItem(at: rootURL)
            return .failure(.unsupportedFormat)
        }
    }

    private init(
        previewFileURL: URL,
        items: [DTConfidentialArchiveItem],
        filename: String?,
        incomingMessage: TSIncomingMessage?
    ) {
        self.previewFileURL = previewFileURL
        self.items = items
        self.incomingMessage = incomingMessage
        super.init(nibName: nil, bundle: nil)
        title = filename
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    deinit {
        destroyMessageIfNeeded()
        cleanUpArchive()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bg1Color
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(close)
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ArchiveEntry")
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        markMessageViewedIfNeeded()
        guard !hasShownHint else { return }
        hasShownHint = true
        DTConfidentialHintToast().show(in: view)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed
                || isMovingFromParent
                || (navigationController?.isBeingDismissed ?? false) else { return }
        destroyMessageIfNeeded()
        cleanUpArchive()
    }

    func present(from presenter: UIViewController) {
        let navigationController = OWSNavigationController(rootViewController: self)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ArchiveEntry", for: indexPath)
        let item = items[indexPath.row]
        var configuration = cell.defaultContentConfiguration()
        configuration.text = item.relativePath
        configuration.secondaryText = ByteCountFormatter.string(
            fromByteCount: item.byteCount,
            countStyle: .file
        )
        configuration.image = UIImage(systemName: "doc")
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        guard item.fileURL.pathExtension.lowercased() != "zip" else {
            DTToastHelper.show(withInfo: Localized("UNSUPPORTED_ATTACHMENT"))
            return
        }
        guard QLPreviewController.canPreview(item.fileURL as NSURL) else {
            DTToastHelper.show(withInfo: Localized("UNSUPPORTED_ATTACHMENT"))
            return
        }
        DTConfidentialAttachmentPreviewController.archiveEntry(
            fileURL: item.fileURL
        ).present(from: self)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func markMessageViewedIfNeeded() {
        guard !hasMarkedMessageViewed else { return }
        hasMarkedMessageViewed = true
        guard let incomingMessage else { return }
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)
    }

    private func destroyMessageIfNeeded() {
        // A controller can be released before presentation (for example, if the app resigns
        // active while decryption is finishing). Only a message that was actually shown is
        // eligible for view-once destruction.
        guard hasMarkedMessageViewed, !hasDestroyedMessage, let incomingMessage else { return }
        hasDestroyedMessage = true
        databaseStorage.asyncWrite { [incomingMessage] transaction in
            incomingMessage.anyRemove(transaction: transaction)
        }
    }

    private func cleanUpArchive() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        DTQuickLookPreviewFile.cleanUp(previewFileURL)
    }
}

/// Confidential attachments keep Quick Look's format coverage while removing its export UI and
/// blocking the controllers used for Save to Files/share. Quick Look requires a file URL, so its
/// protected plaintext staging file is deleted on dismissal and deinitialization. An already
/// visible preview remains alive across background/foreground to match Android's lifecycle.
private final class DTConfidentialAttachmentPreviewController:
    QLPreviewController,
    DTConfidentialPreviewControlling {
    private let previewFileURL: URL
    private let incomingMessage: TSIncomingMessage?
    private let ownsPreviewFile: Bool
    private let shouldConsumeMessage: Bool
    private let inertTitleView = UIView()
    private lazy var closeButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "xmark")
        configuration.baseForegroundColor = .label
        configuration.baseBackgroundColor = .secondarySystemBackground
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = Localized("BUTTON_DONE", comment: "Close confidential preview")
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        return button
    }()
    private var hasMarkedMessageViewed = false
    private var hasDestroyedMessage = false
    private var hasCleanedUpPreviewFile = false

    static func load(
        attachmentStream: TSAttachmentStream,
        incomingMessage: TSIncomingMessage?,
        completion: @escaping (
            Result<DTConfidentialAttachmentPreviewController, DTQuickLookPreviewFile.PreviewError>
        ) -> Void
    ) {
        DTQuickLookPreviewFile.prepareDecryptedCopy(from: attachmentStream) { result in
            switch result {
            case .success(let previewFileURL):
                completion(.success(DTConfidentialAttachmentPreviewController(
                    previewFileURL: previewFileURL,
                    incomingMessage: incomingMessage,
                    ownsPreviewFile: true,
                    shouldConsumeMessage: true
                )))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private init(
        previewFileURL: URL,
        incomingMessage: TSIncomingMessage?,
        ownsPreviewFile: Bool,
        shouldConsumeMessage: Bool
    ) {
        self.previewFileURL = previewFileURL
        self.incomingMessage = incomingMessage
        self.ownsPreviewFile = ownsPreviewFile
        self.shouldConsumeMessage = shouldConsumeMessage
        super.init(nibName: nil, bundle: nil)
        dataSource = self
        delegate = self
        currentPreviewItemIndex = 0
    }

    static func archiveEntry(fileURL: URL) -> DTConfidentialAttachmentPreviewController {
        DTConfidentialAttachmentPreviewController(
            previewFileURL: fileURL,
            incomingMessage: nil,
            ownsPreviewFile: false,
            shouldConsumeMessage: false
        )
    }

    deinit {
        destroyMessageIfNeeded()
        cleanUpPreviewFile()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(closeButton)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(true, animated: false)
        lockDownExportUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        lockDownExportUI()
        view.bringSubviewToFront(closeButton)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.lockDownExportUI()
        }
        markMessageViewedIfNeeded()
        DTConfidentialHintToast().show(in: view)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed
                || isMovingFromParent
                || (navigationController?.isBeingDismissed ?? false) else { return }
        destroyMessageIfNeeded()
        cleanUpPreviewFile()
    }

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard !viewControllerToPresent.containsConfidentialExportController else {
            lockDownExportUI()
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    func present(from presenter: UIViewController) {
        let navigationController = DTConfidentialPreviewNavigationController(rootViewController: self)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    private func markMessageViewedIfNeeded() {
        guard shouldConsumeMessage else { return }
        guard !hasMarkedMessageViewed else { return }
        hasMarkedMessageViewed = true
        guard let incomingMessage else { return }
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)
    }

    private func destroyMessageIfNeeded() {
        guard shouldConsumeMessage else { return }
        // Do not consume a message when an async preview controller is discarded before it ever
        // becomes visible. Android likewise consumes an incoming confidential attachment only
        // after its preview has been shown and then dismissed/destroyed.
        guard hasMarkedMessageViewed, !hasDestroyedMessage, let incomingMessage else { return }
        hasDestroyedMessage = true
        databaseStorage.asyncWrite { [incomingMessage] transaction in
            incomingMessage.anyRemove(transaction: transaction)
        }
    }

    fileprivate func lockDownExportUI() {
        let hierarchyRoot = navigationController ?? self
        hierarchyRoot.removeConfidentialExportChrome()
        hierarchyRoot.dismissConfidentialExportControllers()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.setToolbarHidden(true, animated: false)
        navigationItem.titleView = inertTitleView
    }

    private func cleanUpPreviewFile() {
        guard !hasCleanedUpPreviewFile else { return }
        hasCleanedUpPreviewFile = true
        guard ownsPreviewFile else { return }
        DTQuickLookPreviewFile.cleanUp(previewFileURL)
    }
}

private final class DTConfidentialPreviewNavigationController: OWSNavigationController {
    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        guard !viewControllerToPresent.containsConfidentialExportController else {
            (viewControllers.first as? DTConfidentialAttachmentPreviewController)?.lockDownExportUI()
            DispatchQueue.main.async {
                completion?()
            }
            return
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard !viewController.containsConfidentialExportController else {
            (viewControllers.first as? DTConfidentialAttachmentPreviewController)?.lockDownExportUI()
            return
        }
        super.pushViewController(viewController, animated: animated)
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        super.setNavigationBarHidden(true, animated: animated)
    }

    override func setToolbarHidden(_ hidden: Bool, animated: Bool) {
        super.setToolbarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        super.setNavigationBarHidden(true, animated: false)
        super.setToolbarHidden(true, animated: false)
        toolbar.isHidden = true
        toolbar.alpha = 0
        toolbar.isUserInteractionEnabled = false
        (viewControllers.first as? DTConfidentialAttachmentPreviewController)?.lockDownExportUI()
    }
}

private extension UIViewController {
    var containsConfidentialExportController: Bool {
        if self is UIActivityViewController
            || self is UIDocumentBrowserViewController
            || self is UIDocumentPickerViewController
            || self is UICloudSharingController {
            return true
        }
        return children.contains(where: \.containsConfidentialExportController)
    }

    func removeConfidentialExportChrome() {
        navigationItem.rightBarButtonItems = []
        navigationItem.leftBarButtonItems = []
        toolbarItems = []
        if #available(iOS 16.0, *) {
            navigationItem.titleMenuProvider = nil
            navigationItem.documentProperties = nil
        }

        if let navigationController = self as? UINavigationController {
            navigationController.setToolbarHidden(true, animated: false)
            navigationController.navigationBar.items?.forEach { item in
                item.rightBarButtonItems = []
                item.leftBarButtonItems = []
                if #available(iOS 16.0, *) {
                    item.titleMenuProvider = nil
                    item.documentProperties = nil
                }
            }
        }
        children.forEach { $0.removeConfidentialExportChrome() }
    }

    func dismissConfidentialExportControllers() {
        if let presentedViewController {
            if presentedViewController.containsConfidentialExportController {
                presentedViewController.dismiss(animated: false)
            } else {
                presentedViewController.dismissConfidentialExportControllers()
            }
        }
        children.forEach { $0.dismissConfidentialExportControllers() }
    }
}

extension DTConfidentialAttachmentPreviewController:
    QLPreviewControllerDataSource,
    QLPreviewControllerDelegate {

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

    func previewController(
        _ controller: QLPreviewController,
        previewItemAt index: Int
    ) -> QLPreviewItem {
        previewFileURL as QLPreviewItem
    }

    func previewController(
        _ controller: QLPreviewController,
        editingModeFor previewItem: QLPreviewItem
    ) -> QLPreviewItemEditingMode {
        .disabled
    }

    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        cleanUpPreviewFile()
    }
}

// MARK: - DTQuickLookPreviewFile

/// Keeps a QuickLook source alive if its original path is removed during preview.
enum DTQuickLookPreviewFile {

    enum PreviewError: LocalizedError {
        case decryptionFailed
        case fileTooLarge
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .decryptionFailed:
                return Localized("ERROR_DESCRIPTION_UNKNOWN_ERROR")
            case .fileTooLarge:
                return Localized("ATTACHMENT_ERROR_FILE_SIZE_TOO_LARGE")
            case .unsupportedFormat:
                return Localized("UNSUPPORTED_ATTACHMENT")
            }
        }

    }

    /// Lives inside the current per-launch temporary directory. Normal dismissal/deinit
    /// removes each preview; a later launch removes directories abandoned by a terminated app.
    private static var stagingRoot: URL {
        URL(fileURLWithPath: OWSTemporaryDirectory())
            .appendingPathComponent("QLPreview", isDirectory: true)
    }

    /// Maximum stored size accepted by the current whole-buffer decrypt path. For canonical
    /// encrypted attachments this is explicitly a ciphertext-byte limit; legacy plaintext uses
    /// its actual stored byte count. The cap is below the 200 MiB send limit because the current
    /// implementation can peak near 5x; revisit after attachment decryption becomes streaming.
    private static let maxWholeBufferPreviewStoredByteCount: UInt64 = 32 * 1024 * 1024

    static func make(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path) else { return nil }
        let directory = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stagedURL = directory.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            do {
                try fileManager.linkItem(at: sourceURL, to: stagedURL)
            } catch {
                // Hard link only works within a volume; fall back to a copy otherwise.
                try fileManager.copyItem(at: sourceURL, to: stagedURL)
            }
            return stagedURL
        } catch {
            Logger.error("[QLPreview] failed to stage \(sourceURL.lastPathComponent): \(error)")
            try? fileManager.removeItem(at: directory)
            return nil
        }
    }

    /// Decrypts off the main thread into a file Quick Look can open, so encrypted-at-rest
    /// attachments keep the same format coverage as plaintext ones. The completion runs on
    /// the main thread; on success the caller owns the URL and must `cleanUp(_:)` it once
    /// the preview is dismissed.
    static func prepareDecryptedCopy(
        from attachmentStream: TSAttachmentStream,
        completion: @escaping (Result<URL, PreviewError>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let payloadByteCount = storedPayloadByteCount(for: attachmentStream) else {
                Logger.error("[QLPreview] failed to stat the stored attachment before decrypting")
                DispatchQueue.main.async { completion(.failure(.decryptionFailed)) }
                return
            }
            guard payloadByteCount <= maxWholeBufferPreviewStoredByteCount else {
                Logger.warn("[QLPreview] refusing whole-buffer preview for \(payloadByteCount) stored bytes")
                DispatchQueue.main.async { completion(.failure(.fileTooLarge)) }
                return
            }

            let previewURL = makeDecryptedCopy(from: attachmentStream)
            DispatchQueue.main.async {
                guard let previewURL else {
                    completion(.failure(.decryptionFailed))
                    return
                }
                guard QLPreviewController.canPreview(previewURL as NSURL) else {
                    cleanUp(previewURL)
                    completion(.failure(.unsupportedFormat))
                    return
                }
                completion(.success(previewURL))
            }
        }
    }

    /// Returns the actual number of stored bytes that `decryptedData()` will read.
    /// Do not use `byteCount` or `encryptedDatalength`; both are database metadata
    /// and may under-report the file that is currently on disk.
    private static func storedPayloadByteCount(for attachmentStream: TSAttachmentStream) -> UInt64? {
        let fileManager = FileManager.default
        guard let plaintextPath = attachmentStream.filePath() else { return nil }

        let storedPath: String
        if attachmentStream.isStoredEncrypted
            || (attachmentStream.hasEncryptedFile && !fileManager.fileExists(atPath: plaintextPath)) {
            guard let encryptedPath = attachmentStream.encryptedFilePath() else { return nil }
            storedPath = encryptedPath
        } else {
            storedPath = plaintextPath
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: storedPath)
            guard let fileSize = attributes[.size] as? NSNumber else { return nil }
            return fileSize.uint64Value
        } catch {
            Logger.error("[QLPreview] failed to stat stored attachment: \(error)")
            return nil
        }
    }

    /// Quick Look requires a file URL. Keep its decrypted input in a uniquely-owned,
    /// fully protected temporary directory and remove it when the preview is dismissed.
    private static func makeDecryptedCopy(from attachmentStream: TSAttachmentStream) -> URL? {
        guard let data = attachmentStream.decryptedData(),
              let filePath = attachmentStream.filePath() else {
            return nil
        }

        let fileManager = FileManager.default
        let directory = stagingRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        // The stored path already carries the sanitized source filename and its
        // extension, which is what Quick Look uses to pick a previewer.
        let previewURL = directory.appendingPathComponent(URL(fileURLWithPath: filePath).lastPathComponent)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: directory.path
            )
            try data.write(to: previewURL, options: [.atomic, .completeFileProtection])
            return previewURL
        } catch {
            Logger.error("[QLPreview] failed to create protected preview file: \(error)")
            try? fileManager.removeItem(at: directory)
            return nil
        }
    }

    static func cleanUp(_ stagedURL: URL?) {
        guard let stagedURL else { return }
        // Never delete the original attachment path.
        guard stagedURL.path.hasPrefix(stagingRoot.path) else { return }
        try? FileManager.default.removeItem(at: stagedURL.deletingLastPathComponent())
    }

    /// Returns a valid placeholder when the preview source is missing.
    static func placeholder() -> QLPreviewItem {
        let placeholderURL = FileManager.default.temporaryDirectory.appendingPathComponent("placeholder.txt")
        try? "Placeholder".write(to: placeholderURL, atomically: true, encoding: .utf8)
        return placeholderURL as NSURL
    }
}
