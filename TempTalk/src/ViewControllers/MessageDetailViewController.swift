//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import UIKit
import CoreMedia

@objc
enum MessageMetadataViewMode: UInt {
    case focusOnMessage
    case focusOnMetadata
}
class MessageDetailViewController: OWSViewController, MediaGalleryDataSourceDelegate, ConversationMessageBubbleViewDelegate {

    // MARK: Properties

    let contactsManager: OWSContactsManager

    var bubbleView: UIView?

    let mode: MessageMetadataViewMode
    let viewItem: ConversationViewItem
    var renderItem: CVMessageBubbleRenderItem?
    var isViewDidAppeare:Bool
    var message: TSMessage
    var wasDeleted: Bool = false

    var messageBubbleView: ConversationMessageBubbleView?
    var messageBubbleViewWidthLayoutConstraint: NSLayoutConstraint?
    var messageBubbleViewHeightLayoutConstraint: NSLayoutConstraint?

    var scrollView: UIScrollView!
    var contentView: UIView?
    var footer: UIToolbar?

    var attachment: TSAttachment?
    var dataSource: DataSource?
    var attachmentStream: TSAttachmentStream?
    var messageBody: String?
    
    var isShowTimestamp = true
    
    lazy var contentCellRows:[String:UIView] = { () -> [String:UIView] in
        let contentCellRows:[String:UIView] = NSMutableDictionary.init() as! [String:UIView];
        return contentCellRows
    }()
    lazy var recipientIds:[String] = { () -> [String] in
        let recipientIds:[String] = NSMutableArray.init() as! [String];
        return recipientIds
    }()
    var conversationStyle: ConversationStyle

    // MARK: Initializers

    @available(*, unavailable, message:"use other constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc
    required init(viewItem: ConversationViewItem, message: TSMessage, thread: TSThread, mode: MessageMetadataViewMode) {
        self.contactsManager = Environment.shared.contactsManager
        self.viewItem = viewItem
        self.message = message
        self.mode = mode
        self.conversationStyle = ConversationStyle(thread: thread)
        self.isViewDidAppeare = false
        super.init()
    }
    
    override func applyTheme() {
        super.applyTheme()
        updateContent()
        if (hasMediaAttachment) {
            guard let footer = footer else { return }
            footer.removeFromSuperview()
            self.footer = nil
            
            if shouldShowFooter() {
                /// 语音消息不展示footerbar
                addFooter()
            }
        }
    }
    
    // MARK: View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        updateDBConnectionAndMessageToLatest()

        self.conversationStyle.viewWidth = view.width
        self.renderItem = CVMessageBubbleRenderItem(viewItem: viewItem, conversationStyle: conversationStyle)

        self.navigationItem.title = Localized("MESSAGE_METADATA_VIEW_TITLE",
                                              comment: "Title for the 'message metadata' view.")

        createViews()
        self.view.layoutIfNeeded()
//        NotificationCenter.default.addObserver(self,
//            selector: #selector(yapDatabaseModified),
//            name: NSNotification.Name.YapDatabaseModified,
//            object: OWSPrimaryStorage.shared.dbNotificationObject)

        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(doubleClickView))
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(doubleTapGesture)
        
        if let message = self.message as? TSIncomingMessage, message.messageModeType == .confidential {
            OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(message)
        }
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let message = self.message as? TSIncomingMessage, message.messageModeType == .confidential else {
            return
        }
        self.databaseStorage.asyncWrite { wTransaction in
            message.anyRemove(transaction: wTransaction)
        }
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        Logger.debug("\(self.logTag) in \(#function)")

        super.viewWillTransition(to: size, with: coordinator)

        self.conversationStyle.viewWidth = size.width
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateMessageBubbleViewLayout()

        if mode == .focusOnMetadata {
            if let bubbleView = self.bubbleView {
                // Force layout.
                view.setNeedsLayout()
                view.layoutIfNeeded()

                let contentHeight = scrollView.contentSize.height
                let scrollViewHeight = scrollView.frame.size.height
                guard contentHeight >=  scrollViewHeight else {
                    // All content is visible within the scroll view. No need to offset.
                    return
                }

                // We want to include at least a little portion of the message, but scroll no farther than necessary.
                let showAtLeast: CGFloat = 50
                let bubbleViewBottom = bubbleView.superview!.convert(bubbleView.frame, to: scrollView).maxY
                let maxOffset =  bubbleViewBottom - showAtLeast
                let lastPage = contentHeight - scrollViewHeight

                let offset = CGPoint(x: 0, y: min(maxOffset, lastPage))
                scrollView.setContentOffset(offset, animated: false)
            }
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.isViewDidAppeare = true
    }

    @objc
    func doubleClickView() {
        isShowTimestamp = !isShowTimestamp
        updateContent()
    }

    // MARK: - Create Views

    private func createViews() {
        view.backgroundColor = Theme.backgroundColor

        let scrollView = UIScrollView()
        self.scrollView = scrollView
        view.addSubview(scrollView)
        scrollView.autoPinWidthToSuperview(withMargin: 0)
        scrollView.autoPinEdge(toSuperviewSafeArea: .top)

        let contentView = UIView.container()
        self.contentView = contentView
        scrollView.addSubview(contentView)
        contentView.autoPinLeadingToSuperviewMargin()
        contentView.autoPinTrailingToSuperviewMargin()
        contentView.autoPinEdge(toSuperviewEdge: .top)
        contentView.autoPinEdge(toSuperviewEdge: .bottom)
        scrollView.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        if hasMediaAttachment {
            if viewItem.attachmentStream()?.attachmentType == .voiceMessage {
                /// 语音消息不展示footerbar
                scrollView.applyInsetsFix()
                scrollView.autoPinEdge(toSuperviewEdge: .bottom)
            } else {
                addFooter()
            }
        } else {
            scrollView.applyInsetsFix()
            scrollView.autoPinEdge(toSuperviewEdge: .bottom)
        }

        updateContent()
    }
    
    private func addFooter() {
        
        if footer != nil {
            return
        }
        footer = UIToolbar()
        view.addSubview(footer!)
        footer!.autoPinWidthToSuperview(withMargin: 0)
        footer!.autoPinEdge(.top, to: .bottom, of: scrollView)
        footer!.autoPinEdge(toSuperviewSafeArea: .bottom)

        footer!.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonPressed)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]
    }

    lazy var thread: TSThread = {
        var thread: TSThread?
        self.databaseStorage.read { transaction in
            thread = self.message.thread(with: transaction)
        }
        return thread!
    }()
    
    private func appendTimes(message: TSMessage, alignmentLeft: Bool = true) -> [UIView] {
        var rows = [UIView]()
        
        let sendTime = isShowTimestamp ? "\(message.timestamp)" : formatTimestamp(message.timestamp)
        let receivedTime = isShowTimestamp ? "\(message.receivedAtTimestamp)" : formatTimestamp(message.receivedAtTimestamp)
        let serverTime = isShowTimestamp ? "\(message.serverTimestamp)" : formatTimestamp(message.serverTimestamp)
        
        rows.append(valueRow(name: "", value: "\(sendTime)", alignmentLeft: alignmentLeft))
        rows.append(valueRow(name: "", value: "\(receivedTime)", alignmentLeft: alignmentLeft))
        rows.append(valueRow(name: "", value: "\(serverTime)", alignmentLeft: alignmentLeft))
        rows.append(valueRow(name: "", value: "\(message.expiresInSeconds)", alignmentLeft: alignmentLeft))
        if let cardUniqueId = message.cardUniqueId {
            var card: DTCardMessageEntity?
            self.databaseStorage.read { transaction in
                card = DTCardMessageEntity.anyFetch(uniqueId: cardUniqueId, transaction: transaction)
            }
            if let card = card {
                rows.append(valueRow(name: "", value: "\(card.timestamp)", alignmentLeft: alignmentLeft))
            }
        }
        return rows
    }
    
    private func formatTimestamp(_ timestamp: UInt64) -> String {
        let date = NSDate.ows_date(withMillisecondsSince1970: timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: date)
    }

    private func updateContent() {
        guard let contentView = contentView else {
            owsFailDebug("\(logTag) Missing contentView")
            return
        }

        // Remove any existing content views.
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }

        var rows = [UIView]()
        let contactsManager = Environment.shared.contactsManager!

        // Content
        rows += contentRows()

        // Sender?
        if let incomingMessage = message as? TSIncomingMessage {
            let senderId = incomingMessage.authorId
            let senderName = contactsManager.contactOrProfileName(forPhoneIdentifier: senderId)
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_SENDER",
                                                         comment: "Label for the 'sender' field of the 'message metadata' view."),
                                 value: senderName))
        }

        // Recipient(s)
        if let outgoingMessage = message as? TSOutgoingMessage {

            let isGroupThread = thread.isGroupThread()
            let isWithoutRecipt = thread.isWithoutReadRecipt()

            let recipientStatusGroups: [MessageReceiptStatus] = [
                .read,
                .uploading,
                .delivered,
                .sent,
                .sending,
                .failed,
                .skipped
            ]
            
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_SENT_DATE_TIME",
                                                         comment: "Label for the 'sent date & time' field of the 'message metadata' view."),
                                 value: DateUtil.formatPastTimestampRelativeToNow(message.timestamp), alignmentLeft: false))
            rows += appendTimes(message: message, alignmentLeft: false)
            
            if isGroupThread && !(isWithoutRecipt) {
                for index in 0...1 {
                    var groupRows = [UIView]()

                    // TODO: It'd be nice to inset these dividers from the edge of the screen.
                    let addDivider = {
                        let divider = UIView()
                        divider.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
                        divider.autoSetDimension(.height, toSize: 0.5)
                        groupRows.append(divider)
                    }
                    //消息的所有收件人
                    let messageRecipientIds = outgoingMessage.recipientIds()
                    //保存所有收件人
                    self.recipientIds = messageRecipientIds
                    for recipientId in messageRecipientIds {
                        guard let recipientState = outgoingMessage.recipientState(forRecipientId: recipientId) else {
                            owsFailDebug("\(self.logTag) no message status for recipient: \(recipientId).")
                            continue
                        }

                        let (recipientStatus, shortStatusMessage, _) = MessageRecipientStatusUtils.recipientStatusAndStatusMessage(outgoingMessage: outgoingMessage, recipientState: recipientState)
                        
                        if index == 0 {
                            guard recipientStatus == .read else {
                                continue
                            }
                        } else {
                            guard recipientStatus != .read else {
                                continue
                            }
                        }

                        if groupRows.count < 1 {
                            if isGroupThread {
                                groupRows.append(valueRow(name: string(for: recipientStatus),
                                                          value: ""))
                            }
                            addDivider()
                        }

                        // We use ContactCellView, not ContactTableViewCell.
                        // Table view cells don't layout properly outside the
                        // context of a table view.
                        let cellView = ContactCellView()
                        cellView.backgroundColor = Theme.backgroundColor
                        // We use the "short" status message to avoid being redundant with the section title.
                        cellView.accessoryMessage = shortStatusMessage
                        cellView.configure(withRecipientId: recipientId, contactsManager: self.contactsManager)
                        
                        let wrapper = UIView()
                        wrapper.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
                        wrapper.addSubview(cellView)
                        cellView.autoPinEdgesToSuperviewMargins()
                        self.contentCellRows[recipientId] = cellView;//缓存contentCellRows
                        groupRows.append(wrapper)
                    }

                    if groupRows.count > 0 {
                        addDivider()

                        let spacer = UIView()
                        spacer.autoSetDimension(.height, toSize: 10)
                        groupRows.append(spacer)
                    }
//                    Logger.verbose("\(groupRows.count) rows for \(recipientStatusGroup)")
                    guard groupRows.count > 0 else {
                        continue
                    }
                    rows += groupRows
                }
            }
            
            if isGroupThread {
//                rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_SENT_DATE_TIME",
//                                                             comment: "Label for the 'sent date & time' field of the 'message metadata' view."),
//                                     value: DateUtil.formatPastTimestampRelativeToNow(message.timestamp), alignmentLeft: false))
            } else {
                for recipientStatusGroup in recipientStatusGroups {
                    var groupRows = [UIView]()

                    // TODO: It'd be nice to inset these dividers from the edge of the screen.
                    let addDivider = {
                        let divider = UIView()
                        divider.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
                        divider.autoSetDimension(.height, toSize: 0.5)
                        groupRows.append(divider)
                    }

                    let messageRecipientIds = outgoingMessage.recipientIds()

                    for recipientId in messageRecipientIds {
                        guard let recipientState = outgoingMessage.recipientState(forRecipientId: recipientId) else {
                            owsFailDebug("\(self.logTag) no message status for recipient: \(recipientId).")
                            continue
                        }

                        let (recipientStatus, shortStatusMessage, _) = MessageRecipientStatusUtils.recipientStatusAndStatusMessage(outgoingMessage: outgoingMessage, recipientState: recipientState)
                        
                        guard recipientStatus == recipientStatusGroup else {
                            continue
                        }

                        if groupRows.count < 1 {
                            if isGroupThread {
                                groupRows.append(valueRow(name: string(for: recipientStatusGroup),
                                                          value: ""))
                            }

                            addDivider()
                        }

                        // We use ContactCellView, not ContactTableViewCell.
                        // Table view cells don't layout properly outside the
                        // context of a table view.
                        let cellView = ContactCellView()
                        cellView.backgroundColor = Theme.backgroundColor
                        // We use the "short" status message to avoid being redundant with the section title.
                        cellView.accessoryMessage = shortStatusMessage
                        cellView.configure(withRecipientId: recipientId, contactsManager: self.contactsManager)

                        let wrapper = UIView()
                        wrapper.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
                        wrapper.addSubview(cellView)
                        cellView.autoPinEdgesToSuperviewMargins()
                        groupRows.append(wrapper)
                    }

                    if groupRows.count > 0 {
                        addDivider()

                        let spacer = UIView()
                        spacer.autoSetDimension(.height, toSize: 10)
                        groupRows.append(spacer)
                    }

                    Logger.verbose("\(groupRows.count) rows for \(recipientStatusGroup)")
                    guard groupRows.count > 0 else {
                        continue
                    }
                    rows += groupRows
                }
            }
        }

//        rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_SENT_DATE_TIME",
//                                                     comment: "Label for the 'sent date & time' field of the 'message metadata' view."),
//                             value: DateUtil.formatPastTimestampRelativeToNow(message.timestamp)))

        if message as? TSIncomingMessage != nil {
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_RECEIVED_DATE_TIME",
                                                         comment: "Label for the 'received date & time' field of the 'message metadata' view."),
                                 value: DateUtil.formatPastTimestampRelativeToNow(message.timestampForSorting())))
            rows += appendTimes(message: message)
        }

        rows += addAttachmentMetadataRows()

        // TODO: We could include the "disappearing messages" state here.

        var lastRow: UIView?
        for row in rows {
            contentView.addSubview(row)
            row.autoPinLeadingToSuperviewMargin()
            row.autoPinTrailingToSuperviewMargin()

            if let lastRow = lastRow {
                row.autoPinEdge(.top, to: .bottom, of: lastRow, withOffset: 5)
            } else {
                row.autoPinEdge(toSuperviewEdge: .top, withInset: 20)
            }

            lastRow = row
        }
        if let lastRow = lastRow {
            lastRow.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20)
        }

        updateMessageBubbleViewLayout()
    }

    private func displayableTextIfText() -> String? {
        guard viewItem.hasBodyText else {
                return nil
        }
        guard let displayableText = viewItem.displayableBodyText() else {
                return nil
        }
        let messageBody = displayableText.fullText
        guard messageBody.count > 0  else {
            return nil
        }
        return messageBody
    }

    let bubbleViewHMargin: CGFloat = 10

    private func contentRows() -> [UIView] {
        var rows = [UIView]()

        if hasMediaAttachment {
            rows += addAttachmentRows()
        }
        
        let messageBubbleView = ConversationMessageBubbleView(frame: .zero)
        messageBubbleView.delegate = self
        messageBubbleView.addTapGestureHandler()
        if let renderItem {
            renderItem.confidentialEnable = false
            messageBubbleView.configure(renderItem: renderItem, mediaCache: NSCache())
        }
        messageBubbleView.loadContent()
        self.messageBubbleView = messageBubbleView

        assert(messageBubbleView.isUserInteractionEnabled)

        let row = UIView()
        row.addSubview(messageBubbleView)
        messageBubbleView.autoPinHeightToSuperview()

        let isIncoming = self.message as? TSIncomingMessage != nil
        messageBubbleView.autoPinEdge(toSuperviewEdge: isIncoming ? .leading : .trailing, withInset: bubbleViewHMargin)

        self.messageBubbleViewWidthLayoutConstraint = messageBubbleView.autoSetDimension(.width, toSize: 0)
        self.messageBubbleViewHeightLayoutConstraint = messageBubbleView.autoSetDimension(.height, toSize: 0)
        rows.append(row)

        if rows.count == 0 {
            // Neither attachment nor body.
            owsFailDebug("\(self.logTag) Message has neither attachment nor body.")
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_NO_ATTACHMENT_OR_BODY",
                                                         comment: "Label for messages without a body or attachment in the 'message metadata' view."),
                                 value: ""))
        }

        let spacer = UIView()
        spacer.autoSetDimension(.height, toSize: 15)
        rows.append(spacer)

        return rows
    }

    private func fetchAttachment(transaction: SDSAnyReadTransaction) -> TSAttachment? {
        guard let attachmentId = message.attachmentIds.first else {
            return nil
        }

        guard let attachment = TSAttachment.anyFetch(uniqueId: attachmentId, transaction: transaction) else {
            Logger.warn("\(logTag) Missing attachment. Was it deleted?")
            return nil
        }

        return attachment
    }

    private func addAttachmentRows() -> [UIView] {
        var rows = [UIView]()

        guard let attachment = self.attachment else {
            Logger.warn("\(logTag) Missing attachment. Was it deleted?")
            return rows
        }

        guard let attachmentStream = attachment as? TSAttachmentStream else {
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_ATTACHMENT_NOT_YET_DOWNLOADED",
                                                         comment: "Label for 'not yet downloaded' attachments in the 'message metadata' view."),
                                 value: ""))
            return rows
        }
        self.attachmentStream = attachmentStream

        return rows
    }

    var hasMediaAttachment: Bool {
        guard let attachment = self.attachment else {
            return false
        }

        guard attachment.contentType != OWSMimeTypeOversizeTextMessage else {
            // to the user, oversized text attachments should behave
            // just like regular text messages.
            return false
        }

        return true
    }

    private func addAttachmentMetadataRows() -> [UIView] {
        guard hasMediaAttachment else {
            return []
        }

        var rows = [UIView]()

        if let attachment = self.attachment {
            // Only show MIME types in DEBUG builds.
            if _isDebugAssertConfiguration() {
                let contentType = attachment.contentType
                rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_ATTACHMENT_MIME_TYPE",
                                                             comment: "Label for the MIME type of attachments in the 'message metadata' view."),
                                     value: contentType))
            }
            
            if let sourceFilename = attachment.sourceFilename, shouldShowFooter() {
                rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_SOURCE_FILENAME",
                                                             comment: "Label for the original filename of any attachment in the 'message metadata' view."),
                                     value: sourceFilename))
            }
        }

        if let dataSource = self.dataSource {
            let fileSize = dataSource.dataLength()
            rows.append(valueRow(name: Localized("MESSAGE_METADATA_VIEW_ATTACHMENT_FILE_SIZE",
                                                         comment: "Label for file size of attachments in the 'message metadata' view."),
                                 value: OWSFormat.formatFileSize(UInt(fileSize))))
        }

        return rows
    }

    private func nameLabel(text: String) -> UILabel {
        let label = UILabel()
        label.textColor = Theme.primaryTextColor
        label.font = UIFont.ows_semiboldFont(withSize: 14)
        label.text = text
        label.setContentHuggingHorizontalHigh()
        return label
    }

    private func valueLabel(text: String) -> UILabel {
        let label = UILabel()
        label.textColor = Theme.secondaryTextAndIconColor
        label.font = UIFont.ows_regularFont(withSize: 14)
        label.text = text
        label.setContentHuggingHorizontalLow()
        return label
    }

    private func valueRow(name: String, value: String, subtitle: String = "", alignmentLeft: Bool = true) -> UIView {
        let row = UIView.container()
        let nameLabel = self.nameLabel(text: name)
        let valueLabel = self.valueLabel(text: value)
        row.addSubview(nameLabel)
        row.addSubview(valueLabel)
        if !alignmentLeft {
            nameLabel.textAlignment = .right
            nameLabel.setContentHuggingHorizontalLow()
            valueLabel.setContentHuggingHorizontalHigh()
        }
        nameLabel.autoPinLeadingToSuperviewMargin(withInset: 20)
        valueLabel.autoPinTrailingToSuperviewMargin(withInset: 20)
        valueLabel.autoPinLeading(toTrailingEdgeOf: nameLabel, offset: 10)
        nameLabel.autoPinEdge(toSuperviewEdge: .top)
        valueLabel.autoPinEdge(toSuperviewEdge: .top)

        if subtitle.count > 0 {
            let subtitleLabel = self.valueLabel(text: subtitle)
            subtitleLabel.textColor = Theme.ternaryTextColor
            row.addSubview(subtitleLabel)
            subtitleLabel.autoPinTrailingToSuperviewMargin()
            subtitleLabel.autoPinLeading(toTrailingEdgeOf: nameLabel, offset: 10)
            subtitleLabel.autoPinEdge(.top, to: .bottom, of: valueLabel, withOffset: 1)
            subtitleLabel.autoPinEdge(toSuperviewEdge: .bottom)
        } else if value.count > 0 {
            valueLabel.autoPinEdge(toSuperviewEdge: .bottom)
        } else {
            nameLabel.autoPinEdge(toSuperviewEdge: .bottom)
        }

        return row
    }

    // MARK: - Actions

    @objc func shareButtonPressed() {
        guard let attachmentStream = attachmentStream else {
            Logger.error("\(logTag) Share button should only be shown with attachment, but no attachment found.")
            return
        }
        AttachmentSharing.showShareUI(forAttachment: attachmentStream)
    }

    // MARK: - Actions

    // This method should be called after self.databaseConnection.beginLongLivedReadTransaction().
    private func updateDBConnectionAndMessageToLatest() {

        AssertIsOnMainThread()

        self.databaseStorage.read { transaction in
            let uniqueId = self.message.uniqueId
            
            guard let newMessage = TSInteraction.anyFetch(uniqueId: uniqueId, transaction: transaction) as? TSMessage else {
                Logger.error("\(self.logTag) Couldn't reload message.")
                return
            }
            self.message = newMessage
            self.attachment = self.fetchAttachment(transaction: transaction)
            
            if let lastestThread = self.message.thread(with: transaction), !lastestThread.isWithoutReadRecipt() {
                let finder = AnyMessageReadPositonFinder.init()
                do {
                    try finder.enumerateRecipientReadPositions(uniqueThreadId: lastestThread.uniqueId,
                                                           transaction: transaction) { readPosition in
                        if readPosition.maxServerTime >= self.message.timestampForSorting() {
                            if let outgoingMessage = self.message as? TSOutgoingMessage {
                                outgoingMessage.update(withReadRecipientId: readPosition.recipientId, readTimestamp: readPosition.readAt, transaction: transaction)
                            }
                        }
                    }
                    
                } catch {
                    owsFailDebug("error: \(error)")
                }
            }
            
        }
    }

    private func string(for messageReceiptStatus: MessageReceiptStatus) -> String {
        let isGroupThread = thread.isGroupThread()
        if isGroupThread {
            if messageReceiptStatus == .read {
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_READ",
                                  comment: "Status label for messages which are read.")
            }else{
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_UNREAD",
                                  comment: "Status label for messages which are unread.")
            }
        }else{
            switch messageReceiptStatus {
            case .uploading:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_UPLOADING",
                                  comment: "Status label for messages which are uploading.")
            case .sending:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENDING",
                                  comment: "Status label for messages which are sending.")
            case .sent:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT",
                                  comment: "Status label for messages which are sent.")
            case .delivered:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_DELIVERED",
                                  comment: "Status label for messages which are delivered.")
            case .read:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_READ",
                                  comment: "Status label for messages which are read.")
            case .failed:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_FAILED",
                                         comment: "Status label for messages which are failed.")
            case .skipped:
                return Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SKIPPED",
                                         comment: "Status label for messages which were skipped.")
            }
        }
    }

    // MARK: - Message Bubble Layout

    private func updateMessageBubbleViewLayout() {
        guard let messageBubbleView = messageBubbleView else {
            return
        }
        guard let messageBubbleViewWidthLayoutConstraint = messageBubbleViewWidthLayoutConstraint else {
            return
        }
        guard let messageBubbleViewHeightLayoutConstraint = messageBubbleViewHeightLayoutConstraint else {
            return
        }

        let messageBubbleSize = renderItem?.viewSize ?? .zero
        messageBubbleViewWidthLayoutConstraint.constant = messageBubbleSize.width
        messageBubbleViewHeightLayoutConstraint.constant = messageBubbleSize.height
    }

    // MARK: ConversationMessageBubbleView

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapImageViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        let mediaGalleryViewController = MediaGalleryViewController(thread: self.thread)

        mediaGalleryViewController.addDataSourceDelegate(self)
        mediaGalleryViewController.presentDetailView(fromViewController: self, mediaMessage: self.message, replacingView: imageView)
    }

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapVideoViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        let mediaGalleryViewController = MediaGalleryViewController(thread: self.thread)

        mediaGalleryViewController.addDataSourceDelegate(self)
        mediaGalleryViewController.presentDetailView(fromViewController: self, mediaMessage: self.message, replacingView: imageView)
    }

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapContactShareViewWith viewItem: any ConversationViewItem
    ) {
        guard let phoneNumbers = viewItem.contactShare?.phoneNumbers,
              let contact = phoneNumbers.first else {
            DTToastHelper.toast(withText: Localized("SHOW_PERSONAL_CARD_FAILED", comment: ""), durationTime: 2)
            return
        }
        let shareContactId = contact.phoneNumber
        self.showProfileCardInfo(with: shareContactId)
    }

    var audioAttachmentPlayer: OWSAudioPlayer?

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapAudioViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream
    ) {
        AssertIsOnMainThread()
        
        if attachmentStream.isVoiceMessage() {
            OWSAttachmentsProcessor.decryptVoiceAttachment(attachmentStream)
        }
            

        guard let mediaURL = attachmentStream.mediaURL() else {
            owsFailDebug("\(logTag) in \(#function) mediaURL was unexpectedly nil for attachment: \(attachmentStream)")
            return
        }

        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            owsFailDebug("\(logTag) in \(#function) audio file missing at path: \(mediaURL)")
            return
        }

        if let audioAttachmentPlayer = self.audioAttachmentPlayer {
            // Is this player associated with this media adapter?
            if let owner = audioAttachmentPlayer.owner as? ConversationViewItem {
                if owner.itemId() == viewItem.itemId() {
                    // Tap to pause & unpause.
                    audioAttachmentPlayer.togglePlayState()
                    return
                }
            }
//            if (audioAttachmentPlayer.owner as? ConversationViewItem == viewItem) {
//                // Tap to pause & unpause.
//                audioAttachmentPlayer.togglePlayState()
//                return
//            }
            audioAttachmentPlayer.stop()
            self.audioAttachmentPlayer = nil
        }

        let audioAttachmentPlayer = OWSAudioPlayer(mediaUrl: mediaURL, delegate: viewItem)
        self.audioAttachmentPlayer = audioAttachmentPlayer

        // Associate the player with this media adapter.
        audioAttachmentPlayer.owner = viewItem
        audioAttachmentPlayer.playWithPlaybackAudioCategory()
    }

    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapTruncatedTextMessageWith viewItem: any ConversationViewItem
    ) {
        guard let navigationController = self.navigationController else {
            owsFailDebug("\(logTag) in \(#function) navigationController was unexpectedly nil")
            return
        }

        let viewController = LongTextViewController(viewItem: viewItem)
        navigationController.pushViewController(viewController, animated: true)
    }
    
    // MediaGalleryDataSourceDelegate
    
    func mediaGalleryDataSource(_ mediaGalleryDataSource: MediaGalleryDataSource, willDelete items: [MediaGalleryItem], initiatedBy: MediaGalleryDataSourceDelegate) {
        Logger.info("\(self.logTag) in \(#function)")

        guard (items.map({ $0.message }) == [self.message]) else {
            // Should only be one message we can delete when viewing message details
            owsFailDebug("\(logTag) in \(#function) Unexpectedly informed of irrelevant message deletion")
            return
        }

        self.wasDeleted = true
    }

    func mediaGalleryDataSource(_ mediaGalleryDataSource: MediaGalleryDataSource, deletedSections: IndexSet, deletedItems: [IndexPath]) {
        self.dismiss(animated: true) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    deinit {
    }
    
    private func shouldShowFooter() -> Bool {
        return viewItem.attachmentStream()?.attachmentType != .voiceMessage
    }
}
