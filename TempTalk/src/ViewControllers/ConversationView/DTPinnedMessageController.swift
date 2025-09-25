//
//  DTPinnedMessageController.swift
//  Wea
//
//  Created by Ethan on 2022/3/15.
//

import UIKit

class DTPinnedMessageController: DTMessageListController {

    var targetThreads: [TSThread]!
    var forwardType = DTForwardMessageType.oneByOne
    var skipToOrigionMessageHandler: ((_ message: TSMessage) -> Void)!
        
    lazy var selectToolbar: DTMultiSelectToolbar = {
        let selectToolbar = DTMultiSelectToolbar()
        selectToolbar.delegate = self
        return selectToolbar
    }()
    
    lazy var serverGroupId: String? = {
        let groupThread = currentThread as! TSGroupThread
        return TSGroupThread.transformToServerGroupId(withLocalGroupId: groupThread.groupModel.groupId)
    }()
    
    lazy var pinAPI: DTGroupPinAPI = DTGroupPinAPI()
    
    private var isFirstLoad = true
    
    override func applyTheme() {
        super.applyTheme()
        selectToolbar.applyTheme()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
       
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(closeItemAction))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editItemAction))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard isFirstLoad == true else {
            return
        }
        isFirstLoad = false
        if collectionView.contentSize.height > collectionView.bounds.size.height {
            collectionView.scrollToBottom(animated: false)
        }
    }

    func closeItemAction() {
        
        dismiss(animated: true)
    }
    
    func editItemAction() {
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelItemAction))
        
        isMultiSelectMode = true
        collectionView.allowsMultipleSelection = true
        collectionView.reloadData()
        
        self.selectToolbar.showIn(self.view)
        self.selectToolbar.updateActionItemsSelectedCount(0, maxCount: 50, enableCounts: [1, 1, 1])
        
        var contentInset = self.collectionView.contentInset
        contentInset.bottom += self.selectToolbar.kToolbarHeight
        self.collectionView.contentInset = contentInset
        self.collectionView.scrollIndicatorInsets = contentInset
    }
    
    func cancelItemAction() {
        
        self.selectedViewItems.removeAll()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editItemAction))
        isMultiSelectMode = false
        collectionView.allowsMultipleSelection = false
        collectionView.reloadData()
        
        self.selectToolbar.hide(animated: true)
        
        var contentInset = self.collectionView.contentInset
        contentInset.bottom -= self.selectToolbar.kToolbarHeight
        UIView.animate(withDuration: 0.2) {
            self.collectionView.contentInset = contentInset
            self.collectionView.scrollIndicatorInsets = contentInset
        }
        
    }
    
    override func databaseChangesDidUpdate(databaseChanges: TTServiceKit.DatabaseChanges) {
        
        owsAssertDebug(Thread.isMainThread)
        
        guard CurrentAppContext().isAppForegroundAndActive() else {
            return
        }
        
        guard databaseChanges.tableNames.contains("model_DTPinnedMessage") else {
            return
        }
        
        guard (serverGroupId != nil) else {
            return
        }
        
        self.anyUIDBDidUpdateExternally()
        
    }
    
    override func databaseChangesDidUpdateExternally() {
        self.anyUIDBDidUpdateExternally()
    }
    
    override func databaseChangesDidReset() {
        self.anyUIDBDidUpdateExternally()
    }
    
    override func anyUIDBDidUpdateExternally() {
        
        owsAssertDebug(Thread.isMainThread)

        reloadMessages(forceReload: true)
        
    }
    
    override func conversationViewItem(from message: TSMessage) -> ConversationViewItem? {
        
        var item: ConversationViewItem?
        self.databaseStorage.read { transaction in
            item = ConversationInteractionViewItem(sepcialInteraction: message, thread: self.currentThread, transaction: transaction, conversationStyle: self.conversationStyle)
        }
        return item
    }
    
    func reloadMessages(forceReload: Bool = false) {
        
        guard let localPinned = DTPinnedDataSource.shared().localPinnedMessages(withGroupId: serverGroupId) else {
            Logger.error("error no localPinned")
            return
        }
        
        kMessages.removeAll()
        localPinned.forEach {
            kMessages.append($0.contentMessage)
        }
        
        if kMessages.count == 0 {
            navigationController?.dismiss(animated: true)
        } else {
            self.navigationItem.title = Localized("PINNED_MESSAGES_VC_TITLE", comment: "") + "(\(self.kMessages.count))"
            if isMultiSelectMode {
                var pinIds = [String]()
                kMessages.forEach { message in
                    guard let pinId = message.pinId else { return }
                    pinIds.append(pinId)
                }
                
                var deletePinIds = [String]()
                selectedViewItems.forEach { viewItem in
                    guard let selectedMessage = viewItem.interaction as? TSMessage else {
                        return
                    }
                    guard let pinId = selectedMessage.pinId else {
                        return
                    }
                    if !pinIds.contains(pinId) {
                        deletePinIds.append(pinId)
                    }
                }
                selectedViewItems.removeAll { viewItem in
                    let message = viewItem.interaction as! TSMessage
                    guard let pinId = message.pinId else {
                        return false
                    }
                    return deletePinIds.contains(pinId)
                }

                multiSelectViewItemsUpdate()
            }
        }
        
        reloadViewItems(forceReload: forceReload)
        self.collectionView.layoutIfNeeded()
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.reloadData()

    }
    
    func configure(thread: TSThread) {
                
        self.currentThread = thread
        conversationStyle = ConversationStyle(thread: thread)
        conversationStyle.viewWidth = view.width
                
        reloadMessages()
    }
    
    override func multiSelectViewItemsUpdate() {
        self.selectToolbar.updateActionItemsSelectedCount(UInt(self.selectedViewItems.count), maxCount: 50, enableCounts: [1, 1, 1])
    }
    
    override func viewItemSupportToBeSelect(_ viewItem: ConversationViewItem) -> Bool {
        
        let unsupportCelltype = [OWSMessageCellType.audio, OWSMessageCellType.contactShare]
        let cellType = viewItem.messageCellType()
        return !unsupportCelltype.contains(cellType)
    }
    
    func messageCell(_ cell: ConversationMessageCell, didTapSkipToOrigionWith viewItem: any ConversationViewItem) {
        owsAssertDebug(Thread.isMainThread)
        
        guard viewItem.interaction is TSMessage else {
            return
        }
        guard viewItem.isPinned == true else {
            return
        }
        self.skipToOrigionMessageHandler(viewItem.interaction as! TSMessage)
    }
}

extension DTPinnedMessageController: DTMultiSelectToolbarDelegate {
    
    func multiSelectToolbar(_: DTMultiSelectToolbar, didSelectIndex index: Int) {
        
        self.selectedViewItems = self.selectedViewItems.sorted(by: {
            $0.interaction.timestampForSorting() > $1.interaction.timestampForSorting()
        })
        
        if index == 0 {
            forwardMessage(.oneByOne)
        } else if index == 1 {
            forwardMessage(.note)
        } else {
            var alertMsg: String
            if self.selectedViewItems.count == 1 {
                alertMsg = Localized("UNPIN_ONE_MESSAGE_NOTICE", comment: "")
            } else {
                alertMsg = String(format: Localized("UNPIN_MESSAGES_NOTICE", comment: ""), self.selectedViewItems.count)
            }
            self.showAlert(.alert, title: Localized("COMMON_NOTICE_TITLE", comment: ""), msg: alertMsg, cancelTitle: Localized("TXT_CANCEL_TITLE", comment: ""), confirmTitle: Localized("TXT_CONFIRM_TITLE", comment: ""), confirmStyle:.default) {
                var pinIds = [String]()
                self.selectedViewItems.forEach { viewItem in
                    guard let selectedMessage = viewItem.interaction as? TSMessage else {
                        return
                    }
                    guard let pinId = selectedMessage.pinId else {
                        return
                    }
                    pinIds.append(pinId)
                }
                let groupThread = self.currentThread as! TSGroupThread
                guard let groupId = TSGroupThread.transformToServerGroupId(withLocalGroupId: groupThread.groupModel.groupId) else {
                    Logger.error("no groupid")
                    return
                }
                
                DTToastHelper.showHud(in: self.view)
                self.pinAPI.unpinMessages(pinIds, gid: groupId, success: { _ in
                    DTToastHelper.hide()
                    self.databaseStorage.write { transaction in
                        pinIds.forEach { pinId in
                            guard let localPinned = DTPinnedMessage.anyFetch(uniqueId: pinId, transaction: transaction) else {
                                
                                self.reloadMessages()
                                return
                            }
                            localPinned.removePinMessage(with: transaction)
//                            self.kMessages.removeAll {
//                                $0.pinId == pinId
//                            }
                            self.selectedViewItems.removeAll { viewItem in
                                let message = viewItem.interaction as! TSMessage
                                return message.pinId == pinId
                            }
                        }
                    }
                    
                }, failure: {_ in
                    DTToastHelper.hide()
                    DTToastHelper.toast(withText: Localized("UNPIN_MESSAGE_FAILED", comment: ""), durationTime: 1)
                })
            }
        }
        
    }
    
    func items(for multiSelectToolBar: DTMultiSelectToolbar) -> [DTMultiSelectToolbarItem] {
        [
            .init(
                imageName: "toolbar-forward",
                title: Localized("MESSAGE_ACTION_FORWARD")
            ),
            .init(
                imageName: "toolbar-save",
                title: Localized("MESSAGE_ACTION_SAVE")
            ),
            .init(
                imageName: "toolbar-unpin",
                title: Localized("MESSAGE_ACTION_UNPIN_MESSAGE")
            )
        ]
    }
    
    func forwardMessage(_ type: DTForwardMessageType) {
        
        forwardType = type
        
        if type == .oneByOne {
            let selectThreadVC = SelectThreadViewController()
            selectThreadVC.selectThreadViewDelegate = self
            let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
            self.present(selectThreadNav, animated: true)
        } else {
            let forwardMessages = DTForwardMessageHelper.messages(from: self.selectedViewItems)
            guard let localNumber = TSAccountManager.localNumber() else {
                DTToastHelper.toast(withText: "Sending failure", durationTime: 1.5)
                return
            }
            let noteThread = TSContactThread.getOrCreateThread(contactId: localNumber)
            DTForwardMessageHelper.forwardMessageIs(fromGroup: self.currentThread.isGroupThread(), targetThread: noteThread, messages: forwardMessages, success: nil)
            if self.isMultiSelectMode {
                self.cancelItemAction()
            }
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: ""), durationTime: 1.5)
        }
    }
    
}

extension DTPinnedMessageController: SelectThreadViewControllerDelegate {

    func threadsWasSelected(_ threads: [TSThread]) {
       
        targetThreads = threads
        owsAssertDebug(targetThreads.count > 0)
        owsAssertDebug(self.presentedViewController != nil)
        owsAssertDebug(selectedViewItems.count > 0)
        
        let previewVC = DTForwardPreviewViewController()
        previewVC.modalPresentationStyle = .overFullScreen
        previewVC.delegate = self
        presentedViewController?.present(previewVC, animated: false)
    }
    
    func canSelectBlockedContact() -> Bool {
       
        false
    }
    
}

extension DTPinnedMessageController: DTForwardPreviewDelegate {
 
    func getThreadsToForwarding() -> [TSThread] {
     
        targetThreads
    }
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        
        let forwardMessages = DTForwardMessageHelper.messages(from: selectedViewItems)
        let messageSender = Environment.shared?.messageSender
        let group = DispatchGroup()
        DispatchQueue.global().async {
            self.targetThreads.forEach { targetThread in
                forwardMessages.forEach { forwardMessage in
                    group.enter()
                    DispatchQueue.main.sync {
                        DTForwardMessageHelper.forwardMessageIs(fromGroup: self.currentThread.isGroupThread(), targetThread: targetThread, messages: [forwardMessage], success: nil)
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                    group.leave()
                }
                
                guard let leaveMsg = leaveMessage?.ows_stripped() else {
                    return
                }
                if leaveMsg.isEmpty {
                    return
                }
                group.enter()
                _ = DispatchQueue.main.sync {
                    ThreadUtil.sendMessage(withText: leaveMsg, atPersons: nil, mentions: nil, in: targetThread, quotedReplyModel: nil, messageSender: messageSender!)
                }
                Thread.sleep(forTimeInterval: 0.05)
                group.leave()
            }
        }
        
        if self.isMultiSelectMode {
            cancelItemAction()
        }
        
        self.dismiss(animated: true) {
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: "Sent"), durationTime: 1.5)
        }
    }
    
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        
        DTForwardMessageHelper.previewOfMessageText(withForwardType: forwardType, thread: currentThread, viewItems: selectedViewItems)
    }
    
}
