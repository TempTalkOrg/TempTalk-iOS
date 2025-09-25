//
//  HomeViewController+Stick.swift
//  Wea
//
//  Created by Ethan on 2022/6/7.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import SignalCoreKit
import SVProgressHUD

@objc extension HomeViewController {
    
    func stickNoteToSelfIfNeeded() {
        
        let inboxCount = self.threadMapping.inboxCount
        let archiveCount = self.threadMapping.archiveCount
        guard self.isFromRegistration && inboxCount == 0 && archiveCount == 0 else {
            return
        }
        
        self.databaseStorage.asyncWrite { transaction in
            let localNumber = TSAccountManager.shared.localNumber(with: transaction)
            if let localNumber = localNumber {
            
                let noteThread = TSContactThread.getOrCreateThread(withContactId: localNumber, transaction: transaction)
                noteThread.anyUpdateContactThread(transaction: transaction) { t in
                    t.stickThread()
                }
            }
        }
    }
    
    func stickThread(indexPath: IndexPath) {
        
        guard indexPath.section == HomeViewControllerSection.conversations.rawValue else {
            owsFailDebug("\(self.logTag) failure: unexpected section: \(indexPath.section)")
            return
        }
        
        let maxCountOfStickThread = DTStickyConfig.maxStickCount()
        var numberOfStickThread = 0
        
        self.databaseStorage.uiRead { transaction in

            let threadFinder = AnyThreadFinder()
            do {
                try threadFinder.enumerateVisibleThreads(isArchived: false, transaction: transaction) {
                    if $0.isSticked {
                        numberOfStickThread += 1
                    }
                }
            } catch {
                owsFailDebug("enumerateVisibleThreads error:\(error)")
            }
        }
         
        
        guard let currentThread = self.threadMapping.thread(indexPath: indexPath) else {
            return
        }
        
        if !currentThread.isSticked && numberOfStickThread >= maxCountOfStickThread {
            SVProgressHUD.showInfo(withStatus: String(format: Localized("NUMBER_OF_STICK_THREAD_MAX", comment: ""), maxCountOfStickThread))
            return
        }
        
        DTToastHelper.show()
        self.databaseStorage.asyncWrite { transaction in
            
            if currentThread.isSticked {
                
                currentThread.anyUpdate(transaction: transaction) { t in
                    t.unstickThread()
                }
            } else {
                
                currentThread.anyUpdate(transaction: transaction) { t in
                    t.unarchiveThread()
                    t.stickThread()
                }
            }
        } completion: {
            
            DTToastHelper.hide()
        }
    }
    
}
