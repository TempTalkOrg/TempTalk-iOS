//
//  DTMessageListController.swift
//  Wea
//
//  Created by Ethan on 2021/11/30.
//

import UIKit
import QuickLook
import TTServiceKit
import TTMessaging
import PureLayout
import PanModal

@objcMembers
class DTMessageListController: OWSViewController, DatabaseChangeDelegate {

    var currentThread: TSThread?
    var conversationStyle: ConversationStyle?
    var viewItems: [ConversationViewItem]?
    var viewItemCache: Dictionary<String, ConversationViewItem>?
    var attachmentDownloadFlag = [UInt64]()
    var isMultiSelectMode = false
    var currentFileURL: URL?
    lazy var selectedViewItems: [ConversationViewItem] = {
        return [ConversationViewItem]()
    }()
    
    lazy var cellCache: NSCache<AnyObject, AnyObject> = {
        let cellCache = NSCache<AnyObject, AnyObject>()
        cellCache.countLimit = 24
        
        return cellCache
    }()
    
    private var dateSeparatorView: ConversationDateSeparatorView?
    
    var kMessages = [TSMessage]()
    
    open override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }
        
    open override var shouldAutorotate: Bool {
        false
    }
    
    private lazy var renderItemBuilder = ConversationCellRenderItemBuilder()
    private var renderItems: [ConversationCellRenderItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        addNotificationObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.cellCache.removeAllObjects()
    }
    
    override func applyTheme() {
        super.applyTheme()
        collectionView.backgroundColor = Theme.bg1Color
        reloadViewItems(forceReload: true)
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
    }
    
    private func setupView() {
        view.addSubview(collectionView)
        collectionView.autoPinEdge(toSuperviewSafeArea: .top)
        collectionView.autoPinEdge(toSuperviewSafeArea: .leading)
        collectionView.autoPinEdge(toSuperviewSafeArea: .trailing)
        collectionView.autoPinEdge(toSuperviewEdge: .bottom)
        collectionView.applyInsetsFix()
    }
    
    private func addNotificationObserver() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangePreferredContentSize(noti:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
        
        self.databaseStorage.appendDatabaseChangeDelegate(self)
    }
    
    func databaseChangesDidUpdate(databaseChanges: TTServiceKit.DatabaseChanges) {
        
        owsAssertDebug(Thread.isMainThread)
        
        if !CurrentAppContext().isAppForegroundAndActive() {
            return
        }
        
        guard let currentThread = self.currentThread,
              databaseChanges.threadUniqueIds.contains(currentThread.uniqueId) else {
            return
        }
        
        self.anyUIDBDidUpdateExternally()
        
    }
    
    func databaseChangesDidUpdateExternally() {
        self.anyUIDBDidUpdateExternally()
    }
    
    func databaseChangesDidReset() {
        self.anyUIDBDidUpdateExternally()
    }
    
    
    func anyUIDBDidUpdateExternally() {
        
        owsAssertDebug(Thread.isMainThread)
        
        self.collectionView.layoutIfNeeded()
        reloadViewItems(forceReload: true)
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
    }
    
    lazy var collectionView: ConversationCollectionView = {

        let style: ConversationStyle
        if let conversationStyle = self.conversationStyle {
            style = conversationStyle
        } else if let currentThread = self.currentThread {
            style = ConversationStyle(thread: currentThread)
        } else {
            owsFailDebug("Both conversationStyle and currentThread are nil")
            preconditionFailure("DTMessageListController requires either conversationStyle or currentThread to be set before accessing collectionView")
        }

        let layout = ConversationViewLayout(conversationStyle: style)
        layout.delegate = self

        let collectionView = ConversationCollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.layoutDelegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsVerticalScrollIndicator = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
        collectionView.allowsSelection = false
        collectionView.backgroundColor = Theme.bg1Color

        collectionView.register(ConversationUnknownCell.self, forCellWithReuseIdentifier: ConversationUnknownCell.reuserIdentifier)
        collectionView.register(ConversationIncomingMessageCell.self, forCellWithReuseIdentifier: ConversationIncomingMessageCell.reuseIdentifier)
        collectionView.register(ConversationOutgoingMessageCell.self, forCellWithReuseIdentifier: ConversationOutgoingMessageCell.reuseIdentifier)

        return collectionView
    }()
        
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }
    
    override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
    }
    
    func reloadViewItems(forceReload: Bool = false) {
        
//        owsAssertDebug(kMessages.count > 0)
        
        var viewItems = Array<ConversationViewItem>()
        var itemCache = Dictionary<String, ConversationViewItem>()
        var cardItems = Array<ConversationViewItem>()
        
        kMessages.forEach { kMessage in
            
            var messageId: String
            if kMessage is TSOutgoingMessage {
                if let localNumber = TSAccountManager.localNumber() {
                    messageId = "\(kMessage.timestamp)" + localNumber
                } else {
                    messageId = "\(kMessage.timestamp)"
                }
            } else {
                // Try to get authorId for incoming messages, fallback to timestamp only
                if let incomingMessage = kMessage as? TSIncomingMessage {
                    messageId = "\(kMessage.timestamp)" + incomingMessage.authorId
                } else {
                    owsFailDebug("Expected TSIncomingMessage but got different type")
                    messageId = "\(kMessage.timestamp)"
                }
            }
            guard let viewItem = {
                if viewItemCache != nil && viewItemCache?.keys.contains(messageId) == true,
                   let cachedItem = viewItemCache?[messageId] {
                    return cachedItem
                } else {
                    if viewItemCache?.keys.contains(messageId) == true {
                        owsFailDebug("viewItemCache contained key but returned nil")
                    }
                    return conversationViewItem(from: kMessage)
                }
            }() else {
                owsFailDebug("Failed to create viewItem for message")
                return
            }

            if (viewItem.card != nil) {
                cardItems.append(viewItem)
            }
            
            if let groupThread = self.currentThread as? TSGroupThread,
               let card = viewItem.card,
               let conversationId = TSGroupThread.transformToServerGroupId(withLocalGroupId: groupThread.groupModel.groupId) {
                var source: String = ""
                if kMessage is TSOutgoingMessage {
                    if let localNumber = TSAccountManager.localNumber() {
                        source = localNumber
                    }
                } else {
                    guard let incomingMessage = kMessage as? TSIncomingMessage else {
                        owsFailDebug("Expected TSIncomingMessage but got different type")
                        return
                    }
                    source = incomingMessage.authorId
                }
                let cardUniqueId = card.generateUniqueId(withSource: source, conversationId: conversationId)
                if !cardUniqueId.isEmpty {
                    self.databaseStorage.read { transaction in
                        let latestCard = DTCardMessageEntity.anyFetch(uniqueId: cardUniqueId, transaction: transaction)
                        if let latestCard = latestCard, latestCard.version > card.version {
                            viewItem.card = latestCard;
                        }
                    }
                }
            }
            
            viewItem.isUseForMessageList = true
            if !kMessage.isContactShare() {
                viewItems.append(viewItem)
            }
            if viewItem.attachmentStream() != nil {
                itemCache[messageId] = viewItem
                attachmentDownloadFlag.removeAll { $0 == viewItem.interaction.timestamp }
            }
        }
        
        var shouldShowDateOnNextViewItem = true
        var previousViewItemTimestamp: UInt64 = 0

        viewItems.forEach { viewItem in
            let viewItemTimestamp = viewItem.interaction.timestampForSorting()
            var shouldShowDate = false
            if previousViewItemTimestamp == 0 {
                shouldShowDateOnNextViewItem = true
            }
            if DateUtil.isSameDay(timestamp: previousViewItemTimestamp, timestamp: viewItemTimestamp) == false {
                shouldShowDateOnNextViewItem = true
            }

            if shouldShowDateOnNextViewItem {
                shouldShowDate = true
                shouldShowDateOnNextViewItem = false
            }
            viewItem.shouldShowDate = shouldShowDate
            previousViewItemTimestamp = viewItemTimestamp
        }
        
        for (idx, currentViewItem) in viewItems.enumerated() {
            let previousViewItem = idx > 0 ? viewItems[idx - 1] : nil
            let nextViewItem = idx + 1 < viewItems.count ? viewItems[idx + 1] : nil
            
            var shouldShowSenderAvatar = false
            var isFirstInCluster = true
            var isLastInCluster = true
            var senderName: NSAttributedString?
            var shouldShowSenderName = true
            
            let interactionType = currentViewItem.interaction.interactionType()
            if interactionType == .outgoingMessage {
//                let outgoingMessage = currentViewItem.interaction as! TSOutgoingMessage
//                if nextViewItem != nil && nextViewItem?.interaction.interactionType() == interactionType {
//                    let nextOutgoingMessage = nextViewItem!.interaction as! TSOutgoingMessage
//                    let nextTimestampText = DateUtil.formatTimestampShort(nextViewItem!.interaction.timestamp)
//                }
                if previousViewItem == nil {
                    isFirstInCluster = true
                } else if currentViewItem.hasCellHeader == true {
                    isFirstInCluster = true
                } else {
                    isFirstInCluster = previousViewItem?.interaction.interactionType() != .outgoingMessage
                }
                
                if let nextViewItem = nextViewItem {
                    if nextViewItem.hasCellHeader == true {
                        isLastInCluster = true
                    } else {
                        isLastInCluster = nextViewItem.interaction.interactionType() != .outgoingMessage
                    }
                } else {
                    isLastInCluster = true
                }
                
                if previousViewItem != nil && previousViewItem?.interaction.interactionType() == interactionType {
                    shouldShowSenderAvatar = currentViewItem.hasCellHeader
                } else {
                    shouldShowSenderAvatar = true
                }
                
            }
            
            if interactionType == .incomingMessage {
                guard let incomingMessage = currentViewItem.interaction as? TSIncomingMessage else {
                    owsFailDebug("Expected TSIncomingMessage but got different type")
                    continue
                }
                let incomingSenderId = incomingMessage.authorId
                
                if previousViewItem == nil {
                    isFirstInCluster = true
                } else if currentViewItem.hasCellHeader {
                    isFirstInCluster = true
                } else if previousViewItem?.interaction.interactionType() != .incomingMessage {
                    isFirstInCluster = true
                } else {
                    guard let previousIncomingMessage = previousViewItem?.interaction as? TSIncomingMessage else {
                        owsFailDebug("Expected TSIncomingMessage but got different type")
                        isFirstInCluster = true
                        continue
                    }
                    isFirstInCluster = incomingSenderId != previousIncomingMessage.authorId
                }

                if let nextViewItem = nextViewItem {
                    if nextViewItem.interaction.interactionType() != .incomingMessage {
                        isLastInCluster = true
                    } else if nextViewItem.hasCellHeader {
                        isLastInCluster = true
                    } else {
                        guard let nextIncomingMessage = nextViewItem.interaction as? TSIncomingMessage else {
                            owsFailDebug("Expected TSIncomingMessage but got different type")
                            isLastInCluster = true
                            continue
                        }
                        isLastInCluster = incomingSenderId != nextIncomingMessage.authorId
                    }
                } else {
                    isLastInCluster = true
                }
                
                if previousViewItem != nil && previousViewItem?.interaction.interactionType() == interactionType {
                    guard let previousIncomingMessage = previousViewItem?.interaction as? TSIncomingMessage else {
                        owsFailDebug("Expected TSIncomingMessage but got different type")
                        shouldShowSenderAvatar = true
                        continue
                    }
                    let previousSenderId = previousIncomingMessage.authorId
                    shouldShowSenderAvatar = previousSenderId != incomingSenderId || currentViewItem.hasCellHeader
                    shouldShowSenderName = previousSenderId != incomingSenderId || currentViewItem.hasCellHeader
                } else {
                    shouldShowSenderAvatar = true
                }

                if shouldShowSenderName {
                    self.databaseStorage.read { transaction in
                        let font = UIFont.ows_dynamicTypeSubheadline.ows_semibold()
                        let textColor = ConversationStyle.bubbleTextColorIncoming
                        senderName = Environment.shared.contactsManager.attributedContactOrProfileName(
                            forPhoneIdentifier: incomingSenderId,
                            primaryFont: font,
                            secondaryFont: font.ows_italic(),
                            primaryTextColor: textColor,
                            secondaryTextColor: textColor,
                            transaction: transaction
                        )
                    }
                    
                }

            }
            
            currentViewItem.isFirstInCluster = isFirstInCluster
            currentViewItem.isLastInCluster = isLastInCluster
            currentViewItem.shouldShowSenderAvatar = shouldShowSenderAvatar
            currentViewItem.senderName = senderName
        }
        
        self.viewItemCache = itemCache
        self.viewItems = viewItems
        
        var forceRebuildIds: [String] = []
        if forceReload {
            forceRebuildIds = viewItems.map { $0.interaction.uniqueId }
        }

        let style: ConversationStyle
        if let conversationStyle = conversationStyle {
            style = conversationStyle
        } else if let currentThread = self.currentThread {
            style = ConversationStyle(thread: currentThread)
        } else {
            owsFailDebug("Both conversationStyle and currentThread are nil")
            preconditionFailure("DTMessageListController requires either conversationStyle or currentThread to be set")
        }

        self.renderItems = renderItemBuilder.syncBuild(
            viewItems: viewItems,
            forceRebuildIds: forceRebuildIds,
            style: style
        )
    }
    
    func conversationViewItem(from message: TSMessage) -> ConversationViewItem? {
        
//        var item: ConversationViewItem?
//        self.uiDatabaseConnection.read { transaction in
//            item = ConversationInteractionViewItem(sepcialInteraction: message, thread: nil, transaction: transaction, conversationStyle: self.conversationStyle)
//        }
        return nil
    }
    
    func viewItemSupportToBeSelect(_ viewItem: ConversationViewItem) -> Bool {
        return false
    }
    
    func didChangePreferredContentSize(noti: Notification) {

        self.viewItems?.forEach { viewItem in
            viewItem.clearCachedLayoutState()
        }
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()
    }
    
    func sameOneViewitemInSelectedViewItems(_ viewItem: ConversationViewItem) -> ConversationViewItem? {
        
        if !self.isMultiSelectMode {
            return nil
        }
        for viewItem_ in self.selectedViewItems {
            if viewItem_.isEqual(to: viewItem) {
                return viewItem_
            }
        }
        return nil
    }
    
    func viewItemWasSelected(_ viewItem: ConversationViewItem) -> Bool {
        
        return self.sameOneViewitemInSelectedViewItems(viewItem) != nil
    }
    
    func multiSelectViewItemsUpdate() {}
}

// MARK: - DateSeparatorView

extension DTMessageListController {
    private func refreshDateSeparator() {
        let currentOffset = CGPoint(
            x: collectionView.contentOffset.x,
            y: collectionView.contentOffset.y + collectionView.contentInset.top
        )
        let minScrollDistance = ConversationDateSeparatorView.Constants.height
        guard currentOffset.y > minScrollDistance else {
            if let dateSeparatorView, !dateSeparatorView.isHidden {
                dateSeparatorView.isHidden = true
            }
            return
        }
        guard let indexPath = collectionView.indexPathForItem(at: currentOffset) else {
            return
        }
        guard let viewItem = viewItems?[safe: indexPath.row] else {
            return
        }
        if dateSeparatorView == nil {
            let separatorView = ConversationDateSeparatorView()
            view.addSubview(separatorView)
            separatorView.snp.makeConstraints { make in
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(collectionView.contentInset.top)
                make.centerX.equalToSuperview()
            }
            dateSeparatorView = separatorView
        }
        dateSeparatorView?.isHidden = false
        dateSeparatorView?.configure(viewItem: viewItem)
        dateSeparatorView?.refreshTheme()
    }
    
    func refreshDateSeparatorViewPosition() {
        guard let dateSeparatorView, !dateSeparatorView.isHidden, dateSeparatorView.superview != nil else {
            return
        }
        dateSeparatorView.snp.updateConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(collectionView.contentInset.top)
        }
    }
}

extension DTMessageListController: ConversationCollectionViewDelegate {
    
    func collectionViewWillChangeSize(from oldSize: CGSize, to newSize: CGSize) {
//        owsAssertDebug(Thread.isMainThread)
    }
    
    func collectionViewDidChangeSize(from oldSize: CGSize, to newSize: CGSize) {
        self.conversationStyle?.viewWidth = newSize.width
    }
    
    func collectionViewDidChangeContentInset(_ oldContentInset: UIEdgeInsets, to newContentInset: UIEdgeInsets) {
        refreshDateSeparatorViewPosition()
    }
}

extension DTMessageListController: ConversationViewLayoutDelegate {
    var layoutItems: [any ConversationViewLayoutItem] {
        self.renderItems
    }
    
    var layoutHeaderHeight: CGFloat {
        CGFloat.leastNormalMagnitude
    }
    
    var layoutFooterHeight: CGFloat {
        CGFloat.leastNormalMagnitude
    }
}

extension DTMessageListController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.renderItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let renderItem = self.renderItems[safe: indexPath.item] else {
            Logger.error("DTMessageListController can not find the viewItem for indexPath:\(indexPath)")
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: ConversationUnknownCell.reuserIdentifier,
                for: indexPath
            )
        }
        
        let cell = renderItem.dequeueCell(for: collectionView, indexPath: indexPath)
        switch (cell, renderItem) {
        case (let messageCell as ConversationMessageCell, let messageRenderItem as ConversationMessageRenderItem):
            messageCell.delegate = self
            messageCell.messageBubbleView.delegate = self
            messageCell.configure(renderItem: messageRenderItem)
            messageCell.isMultiSelectMode = isMultiSelectMode
            messageCell.isCellSelected = viewItemWasSelected(messageRenderItem.viewItem)
            messageCell.refreshTheme()
            
        default:
            break
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        owsAssertDebug(cell is ConversationCell)
        let cell = cell as! ConversationCell
        cell.isCellVisible = true
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        owsAssertDebug(cell is ConversationCell)
        let cell = cell as! ConversationCell
        cell.isCellVisible = false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard self.isMultiSelectMode == true, let viewItems = self.viewItems else {
            return
        }
        collectionView.deselectItem(at: indexPath, animated: false)
        let currentViewItem = viewItems[indexPath.item]
        let isSelected = self.viewItemWasSelected(currentViewItem)
        let maxSelectCount = 50
        if self.selectedViewItems.count == maxSelectCount && !isSelected {
            DTToastHelper.toast(withText: String(format: Localized("FORWARD_MESSAGE_SELECT_MESSAGE_MAX_COUNT", comment: ""), maxSelectCount), durationTime: 1)
            return
        }
        
//        if currentViewItem.messageCellType() == .downloadingAttachment {
//            DTToastHelper.toast(withText: Localized("FORWARD_MESSAGE_ATTACHMENT_NOT_DOWNLOADED", comment: "attachment is not downloaded"), in: self.view, durationTime: 1)
//            return
//        }
        
//        if !self.viewItemSupportToBeSelect(currentViewItem) {
//            DTToastHelper.toast(withText: Localized("FORWARD_MESSAGE_FORBIDDEN_REMINDER", comment: "attachment unsupported"), in: self.view, durationTime: 1)
//            return
//        }
        
        if !isSelected {
            self.selectedViewItems.append(currentViewItem)
        } else {
            let viewItemSaved = self.sameOneViewitemInSelectedViewItems(currentViewItem)
            self.selectedViewItems.removeAll(where: {$0.itemId() == viewItemSaved?.itemId() })
        }
         
        self.multiSelectViewItemsUpdate()
        collectionView.reloadItems(at: [indexPath])
    }
}

extension DTMessageListController: ConversationMessageCellDelegate {
    func messageCell(
        _ cell: ConversationMessageCell,
        didLongPressBubbleViewWith messageType: ConversationMessageType,
        viewItem: any ConversationViewItem,
        bubbleView: ConversationMessageBubbleView
    ) {
        if messageType == .text {
            self.presentMessage(focusedCell: cell, viewItem: viewItem)
        }
    }
    
    func messageCell(_ cell: ConversationMessageCell, shouldBeginPanToQuoteWith viewItem: any ConversationViewItem, bubbleView: ConversationMessageBubbleView) -> Bool {
        return false
    }
    
    func messageCell(_ cell: ConversationMessageCell, didPanToQuoteWith viewItem: any ConversationViewItem, bubbleView: ConversationMessageBubbleView) {
        
    }
    
    func mediaCache(for cell: ConversationMessageCell) -> NSCache<AnyObject, AnyObject> {
        return self.cellCache
    }
    
    func contactsManager(for cell: ConversationMessageCell) -> OWSContactsManager {
        return Environment.shared.contactsManager
    }
    
    private func presentMessage(focusedCell: ConversationMessageCell, viewItem: ConversationViewItem) {
        
        let currentBubleView: ConversationMessageBubbleView? = focusedCell.messageBubbleView
        guard let bubleView = currentBubleView else {
            OWSLogger.info("bubleView is nil")
            return
        }

        if bubleView.canBecomeFirstResponder {
            bubleView.becomeFirstResponder()
        }
        let copyItem = UIMenuItem(title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""), action: #selector(copyAction))
        let menuController = UIMenuController.shared
        menuController.menuItems = [copyItem]
        if #available(iOS 13.0, *) {
            menuController.showMenu(from: bubleView, rect: bubleView.bounds)
        } else {
            menuController.setTargetRect(bubleView.bounds, in: bubleView)
            menuController.setMenuVisible(true, animated: true)
        }
    }
    
    func copyAction(menu: UIMenuController) {
        guard let bubleView = menu.value(forKey: "targetView") as? ConversationMessageBubbleView else {
            return
        }
        guard let viewItem = bubleView.renderItem?.viewItem else {
            return
        }
        var copyItems = [String]()
        guard let copyText = viewItem.displayableBodyText()?.fullText else {
            return
        }
        copyItems.append(copyText)
        if let jsonMentions = viewItem.convertMentionsToJson() {
            copyItems.append(jsonMentions)
        }
        DTSecurePasteboard.setStrings(copyItems)
    }
}

extension DTMessageListController: ConversationMessageBubbleViewDelegate {
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapImageViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        self.previewAttachment(attachmentStream)
//        guard viewItem.interaction is TSMessage else {
//            return
//        }
//        let mediaMessage = viewItem.interaction as! TSMessage
//        let mediaGalleryVC = MediaGalleryViewController(thread: self.currentThread, uiDatabaseConnection: self.uiDatabaseConnection)
//        mediaGalleryVC.presentDetailView(fromViewController: self, mediaMessage: mediaMessage, replacingView: imageView)
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapVideoViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        self.previewAttachment(attachmentStream)
//        guard viewItem.interaction is TSMessage else {
//            return
//        }
//        let mediaMessage = viewItem.interaction as! TSMessage
//        let mediaGalleryVC = MediaGalleryViewController(thread: self.currentThread, uiDatabaseConnection: self.uiDatabaseConnection)
//        mediaGalleryVC.presentDetailView(fromViewController: self, mediaMessage: mediaMessage, replacingView: imageView)
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapGenericAttachmentViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream
    ) {
        self.previewAttachment(attachmentStream)
    }
    
    func previewAttachment(_ attachmentStream: TSAttachmentStream) {
        owsAssertDebug(Thread.isMainThread)
        
        guard let filePath = attachmentStream.filePath() else {
            return
        }
        guard FileManager.default.fileExists(atPath: filePath) else {
            owsAssertDebug(FileManager.default.fileExists(atPath: filePath))
            return
        }
        currentFileURL = URL(fileURLWithPath: filePath)
        guard let currentFileURL = currentFileURL, QLPreviewController.canPreview(currentFileURL as QLPreviewItem) else {
            DTToastHelper.show(withInfo: "Unsupported file type")
            return
        }
        let previewController = QLPreviewController()
        previewController.delegate = self
        previewController.dataSource = self
        present(previewController, animated: true)
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapTruncatedTextMessageWith viewItem: any ConversationViewItem
    ) {
        owsAssertDebug(Thread.isMainThread)
        owsAssertDebug(viewItem.interaction is TSMessage)
        let longTextVC = LongTextViewController(viewItem: viewItem)
        navigationController?.pushViewController(longTextVC, animated: true)
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedAttachmentWith viewItem: any ConversationViewItem,
        autoRestart: Bool,
        attachmentPointer: TSAttachmentPointer
    ) {
        owsAssertDebug(Thread.isMainThread)
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        
        if autoRestart == true {
            guard !attachmentDownloadFlag.contains(viewItem.interaction.timestamp) else {
                return
            }
            attachmentDownloadFlag.append(viewItem.interaction.timestamp)
            let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
            processor.fetchAttachments(for: message, forceDownload: false) { attachmentStream in
                OWSLogger.info("Successfully redownloaded attachment")
            } failure: { error in
                OWSLogger.warn("Failed to redownload message with error:\(error.localizedDescription)")
            }
        } else {
            //        var title: String?
            var retryActionText: String!
            if (attachmentPointer.state == .enqueued) {
                retryActionText = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTION", comment: "Action sheet button text")
            } else {
                //            title = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTIONSHEET_TITLE", comment: "Action sheet title after tapping on failed download.")
                retryActionText = Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_RETRY_ACTION", comment: "Action sheet button text")
            }
            
            let actionSheet = ActionSheetController(title: nil, message: nil)
            actionSheet.addAction(OWSActionSheets.cancelAction)
            
            let retryAction = ActionSheetAction(title: retryActionText, style: .default) { action in
                let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
                processor.fetchAttachments(for: message, forceDownload: true) { attachmentStream in
                    OWSLogger.info("Successfully redownloaded attachment")
                } failure: { error in
                    OWSLogger.warn("Failed to redownload message with error:\(error.localizedDescription)")
                }
            }
            actionSheet.addAction(retryAction)
            
            self.presentActionSheet(actionSheet)
        }
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapCombinedForwardingItemWith viewItem: any ConversationViewItem
    ) {
        owsAssertDebug(Thread.isMainThread)

        guard let combinedForwardingMessage = viewItem.combinedForwardingMessage else {
            owsFailDebug("combinedForwardingMessage is nil")
            return
        }
        owsAssertDebug(combinedForwardingMessage.timestamp > 0)
        owsAssertDebug(combinedForwardingMessage.authorId.count > 0)

        guard let combinedMessage = viewItem.interaction as? TSMessage else {
            return
        }

        guard let combinedForwardingMsg = combinedMessage.combinedForwardingMessage else {
            owsFailDebug("combinedMessage.combinedForwardingMessage is nil")
            return
        }

        let isGroupChat = combinedForwardingMsg.isFromGroup
        let combinedMessageVC = DTCombinedMessageController()
        combinedMessageVC.shouldUseTheme = true
        guard let currentThread = self.currentThread else { return }
        combinedMessageVC.configure(thread: currentThread, combinedMessage: combinedMessage, isGroupChat: isGroupChat)

        // 使用 PanModal 方式展示
        let navController = DTPanModalNavController(
            rootViewController: combinedMessageVC,
            defaultHeight: UIScreen.main.bounds.height * 0.75
        )
        presentPanModal(navController)
    }

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedThumbnailWith viewItem: any ConversationViewItem,
        quotedReply: OWSQuotedReplyModel,
        attachmentPointer: TSAttachmentPointer
    ) {
        guard viewItem.interaction is TSMessage else {
            owsFailDebug("message had unexpected class: \(viewItem.interaction)")
            return
        }
        let message = viewItem.interaction as!TSMessage
        let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
        self.databaseStorage.asyncWrite { transaction in
            processor.fetchAttachments(for: message, forceDownload: true, transaction: transaction) { attachmentStream in
                self.databaseStorage.asyncWrite { successTransaction in
                    message.setQuotedMessageThumbnailAttachmentStream(attachmentStream)
                    message.anyInsert(transaction: successTransaction)
                }
            } failure: { error in
                self.databaseStorage.asyncWrite { failureTransaction in
                    self.databaseStorage.touch(interaction: message, shouldReindex: false, transaction: failureTransaction)
                }
            }
        }
    }
    
    func messageBubbleView(_ bubbleView: ConversationMessageBubbleView, didTapLinkWith viewItem: any ConversationViewItem, url: URL) {
        _ = AppLinkManager.handle(url: url, fromExternal: false, sourceVC: self)
    }
}

extension DTMessageListController: UIDocumentInteractionControllerDelegate {
    
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        self
    }
    
    func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        self.view.bounds
    }
    
    func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        self.view
    }
}

extension DTMessageListController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if #available(iOS 13.0, *) {
            UIMenuController.shared.hideMenu()
        } else {
            UIMenuController.shared.setMenuVisible(false, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        refreshDateSeparator()
    }
}

extension DTMessageListController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let fileURL = self.currentFileURL else {
            owsFailDebug("currentFileURL was unexpectedly nil")
            // Dismiss the preview controller and show error to user
            controller.dismiss(animated: true) {
                OWSActionSheets.showErrorAlert(message: NSLocalizedString("FILE_PREVIEW_ERROR",
                                                                          comment: "Error message when file preview fails"))
            }
            // Create a valid placeholder file to prevent QuickLook crash
            let tempDir = FileManager.default.temporaryDirectory
            let placeholderURL = tempDir.appendingPathComponent("placeholder.txt")
            try? "Placeholder".write(to: placeholderURL, atomically: true, encoding: .utf8)
            return placeholderURL as QLPreviewItem
        }
        return fileURL as QLPreviewItem
    }
    
    public func previewControllerWillDismiss(_ controller: QLPreviewController) {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
    
    public func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }
    
}

