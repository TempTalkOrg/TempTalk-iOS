//
//  HomeViewController+Archive.swift
//  Signal
//
//  Created by hornet on 2022/8/8.
//  Copyright © 2022 Difft. All rights reserved.
//
import SignalCoreKit
import SVProgressHUD
import TTServiceKit
import Foundation
import UIKit
/// 首页会话归档解档的逻辑
@objc extension HomeViewController {
    
    /// 归档会话
    /// - Parameter indexpath: 会话的 indexpath
    func archiveConversation(indexpath: IndexPath) {
        if indexpath.section != HomeViewControllerSection.conversations.rawValue {
            owsFailDebug("\(self.logTag) failure: unexpected section: \(indexpath.section)")
        }
        
        guard var thread = self.threadMapping.thread(indexPath: indexpath) else {
            return
        }
        
        //获取最新thread，避免使用mapping cached thread，因为有会话列表是否需要刷新对比；
        self.databaseStorage.read { transaction in
            if let latestThread = TSThread.anyFetch(uniqueId: thread.uniqueId, transaction: transaction) {
                thread = latestThread
            }
        }
        
        if self.homeViewMode == .inbox {
            
            DTToastHelper.show()
            self.databaseStorage.asyncWrite { writeTransaction in
                
                thread.anyUpdate(transaction: writeTransaction) { t in
                    OWSLogger.info("Archive thread name = \(t.name(with: writeTransaction))")
                    
                    t.archiveThread(with: writeTransaction)
                }
            } completion: {
                
                DTToastHelper.hide()
            }
        }
        
        let archiveEntity = DTConversationArchiveEntity.init()!
        let covnersation = DTConversationInfoEntity.init()!
        archiveEntity.flag = 1
        if(thread.isGroupThread()){
            guard let gThread = thread as? TSGroupThread  else {return};
            covnersation.groupId =  gThread.groupModel.groupId
        } else {
            covnersation.number = thread.serverThreadId
        }
        archiveEntity.covnersation = covnersation
        let syncArchiveMessage: DTOutgoingSyncArchiveMessage = DTOutgoingSyncArchiveMessage(archiveEntity: archiveEntity)
        syncArchiveMessage.associatedUniqueThreadId = thread.uniqueId;
        self.messageSender.enqueue(syncArchiveMessage) {
            //TODO:  是否需要重试?
        } failure: { error in
            
        }
        self.updateViewState() 
    }
    
    /// 解档会话
    /// - Parameter indexpath: 会话的 indexpath
    func unarchiveConversation(indexpath: IndexPath) {
        if indexpath.section != HomeViewControllerSection.conversations.rawValue {
            owsFailDebug("\(self.logTag) failure: unexpected section: \(indexpath.section)")
        }
        let thread: TSThread? = self.threadMapping.thread(indexPath: indexpath)
        guard let thread = thread else { return }
        
        if self.homeViewMode == .archive {
            
            self.databaseStorage.write { writeTransaction in
                
                thread.anyUpdate(transaction: writeTransaction) { t in
                    t.unarchiveThread()
                }
            }
        }
        self.updateViewState()
    }
    
    
    /// 获取归档的ContextualAction
    /// - Parameter indexpath: tableview的indexpath
    /// - Returns: action
    func getArchiveContextualAction(indexpath: IndexPath) -> UIContextualAction {
        let archiveAction :UIContextualAction = UIContextualAction.init(style: .normal, title: Localized("HOME_TABLE_ACTION_ARCHIVE", comment: "")) { action, sourceView, completionHandler in
            self.archiveConversation(indexpath: indexpath)
            completionHandler(true)
        }
        archiveAction.backgroundColor = UIColor.ows_materialBlue
        return archiveAction
    }
}
