//
//  HomeViewController+Unread.swift
//  Signal
//
//  Created by hornet on 2022/7/4.
//  Copyright © 2022 Difft. All rights reserved.
//

import SignalCoreKit
import SVProgressHUD
import TTServiceKit
import Accelerate
import Foundation
import UIKit
@objc extension HomeViewController {
    
    func clearUnreadBadge(for thread: TSThread){
        guard thread.isUnread else {
            return
        }
        if thread.isGroupThread(){
            guard let gThread = thread as? TSGroupThread  else {return};
            self.sendSyncReadMessageForClearUnReadBadge(thread: gThread, groupid: gThread.groupModel.groupId, number: nil)
        } else {
            guard let cThread = thread as? TSContactThread  else {return};
            self.sendSyncReadMessageForClearUnReadBadge(thread: cThread, groupid: nil, number: cThread.contactIdentifier())
        }
    }
    
    func unreadThread(indexPath: IndexPath, threadViewModel: ThreadViewModel) {
        guard indexPath.section == HomeViewControllerSection.conversations.rawValue else {
            owsFailDebug("\(self.logTag) failure: unexpected section: \(indexPath.section)")
            return
        }
        guard var currentThread = self.threadMapping.thread(indexPath: indexPath) else {
            return
        }
        
        //获取最新thread，避免使用mapping cached thread，因为有会话列表是否需要刷新对比；
        self.databaseStorage.read { transaction in
            if let latestThread = TSThread.anyFetch(uniqueId: currentThread.uniqueId, transaction: transaction) {
                currentThread = latestThread
            }
        }
        
        //表示当前用户是置为未读的状态 - UI展示 置为已读 action 置为已读
        if threadViewModel.hasUnreadMessages || threadViewModel.threadRecord.isUnread {
            markAsReadActionSyncReadMessage(thread: currentThread)
            markAsRead(thread: currentThread)
        } else {
            markAsUnread(thread: currentThread)
        }
    }
    
    //标记为已读
    func markAsRead(thread: TSThread)  {
        self.databaseStorage.asyncWrite {transaction  in
            OWSLogger.info("mark conversation as read threadName = \(thread.name(with: transaction))")
            thread.markAllAsRead(with: transaction)
        }
    }
    
    //本地消息标记为未读的同时需要发送同步消息 -- mac端接收同步消息之后处理UI
    func markAsReadActionSyncReadMessage(thread: TSThread) {
        if thread.isGroupThread(){
            guard let gThread = thread as? TSGroupThread  else {return};
            self.sendSyncReadMessage(thread: thread, groupid: gThread.groupModel.groupId, number: nil)
        } else {
            guard let cThread = thread as? TSContactThread  else {return};
            self.sendSyncReadMessage(thread: thread, groupid: nil, number: cThread.contactIdentifier())
        }
    }
    
    //标记为未读
    func markAsUnread(thread: TSThread)  {
        if thread.isGroupThread(){
            guard let gThread = thread as? TSGroupThread  else {return};
            self.sendSyncUnreadMessage(thread: thread, groupid: gThread.groupModel.groupId, number: nil)
        } else {
            guard let cThread = thread as? TSContactThread  else {return};
            self.sendSyncUnreadMessage(thread: thread, groupid: nil, number: cThread.contactIdentifier())
        }
        
    }
    //0: 清除设定的未读状态 1、置未读 2、置全部已读
    func sendSyncUnreadMessage(thread: TSThread, groupid: Data?, number: String?) {
        sendSyncMessage(thread: thread, unread: 1, groupid: groupid, number: number)
    }
    
    func sendSyncReadMessage(thread: TSThread, groupid: Data?, number: String?) {
        sendSyncMessage(thread: thread, unread: 2, groupid: groupid, number: number)
    }
    
    func sendSyncReadMessageForClearUnReadBadge(thread: TSThread, groupid: Data?, number: String?) {
        sendSyncMessage(thread: thread, unread: 0, groupid: groupid, number: number)
    }
    
    func sendSyncMessage(thread: TSThread,unread: UInt32, groupid: Data?, number: String?) {
        let unreadEntity = DTUnreadEntity.init()!
        let covnersation = DTConversationInfoEntity.init()!
        unreadEntity.unreadFlag = unread
        covnersation.number = number
        covnersation.groupId = groupid
        unreadEntity.covnersation = covnersation
        
        let unreadSyncMessage :DTOutgoingUnreadSyncMessage = DTOutgoingUnreadSyncMessage.init(outgoingMessageWithUnRead: unreadEntity)
        unreadSyncMessage.associatedUniqueThreadId = thread.uniqueId;
        self.messageSender.enqueue(unreadSyncMessage) {[weak self] in
            self?.databaseStorage.asyncWrite(block: { transaction in
                thread.anyUpdate(transaction: transaction) { instance in
                    instance.unreadTimeStimeStamp = unreadSyncMessage.serverTimestamp;
                    instance.unreadFlag = unread;
                }
            })
        } failure: { error in
            Logger.error("")
        }
    }
    
    func getUnreadContextualAction(indexpath: IndexPath, threadViewModel: ThreadViewModel) -> UIContextualAction {
        let archiveAction :UIContextualAction = UIContextualAction.init(style: .normal, title: Localized("HOME_TABLE_ACTION_ARCHIVE", comment: "")) { action, sourceView, completionHandler in
            completionHandler(true)
        }
        archiveAction.backgroundColor = UIColor.ows_materialBlue
        var readActionTitle :String? = nil
        if threadViewModel.hasUnreadMessages || threadViewModel.threadRecord.isUnread {
            readActionTitle = Localized("HOME_TABLE_ACTION_READ", comment: "")
        } else {
            readActionTitle =  Localized("HOME_TABLE_ACTION_UNREAD",
                                                 comment:"Pressing this button cancel stick for an thread")
        }
        let readAction :UIContextualAction = UIContextualAction.init(style: .normal, title: readActionTitle) { action, sourceView, completionHandler in
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(720)) {
                self.unreadThread(indexPath: indexpath, threadViewModel: threadViewModel)
            }
            completionHandler(true)
        }
        readAction.backgroundColor = UIColor.ows_materialBlue
        return readAction
    }
}
