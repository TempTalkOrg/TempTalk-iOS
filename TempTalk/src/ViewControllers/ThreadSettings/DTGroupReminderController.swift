//
//  DTGroupReminderController.swift
//  Signal
//
//  Created by Ethan on 2022/8/26.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

let none = "none"
let daily = "daily"
let weekly = "weekly"
let monthly = "monthly"

@objcMembers
class DTGroupReminderController: OWSTableViewController {
    
    var thread: TSThread!
    
    var updateCompleteBlock: ( () -> Void )?
    
    lazy var updateGroupInfoAPI = DTUpdateGroupInfoAPI()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = Localized("SETTINGS_ITEM_GROUP_REMINDER", comment: "group reminder")
        updateTableContents()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateTableContents(noti:)), name: .DTGroupPeriodicRemind, object: nil)
    }
    
    @objc func updateTableContents(noti: Notification) {
        guard let notiThread = noti.object as? TSGroupThread else {
            return
        }
        self.thread = notiThread
        updateTableContents()
    }
    
    func updateTableContents() {
        
        guard let groupThread = self.thread as? TSGroupThread else {
            OWSLogger.error("\(thread.serverThreadId) not group thread")
            navigationController?.popViewController(animated: true)
            return
        }
        
        let reminderCycle = groupThread.groupModel.remindCycle
        let reminderConfig = DTGroupConfig.fetch().groupRemind
        
        let contents = OWSTableContents()
        let optionsSection = OWSTableSection()
        
        let isSelectedOff = reminderCycle == none
        let offItem = OWSTableItem(text: Localized("GROUP_REMINDER_OFF", comment: ""), actionBlock: { [weak self] in
            guard let self else {
                return
            }
            self.updateGroupReminderCycle(none)
        }, accessoryType: isSelectedOff ? .checkmark : .none)
        optionsSection.add(offItem)
        
        reminderConfig.remindCycle.forEach { cycle in
            let isSelected = reminderCycle == cycle
            var cycleTitle: String!
            if cycle == daily {
                cycleTitle = Localized("GROUP_REMINDER_DAILY", comment: "")
            } else if cycle == weekly {
                let weekday = DTGroupUtils.weekday(withRemindWeekDay: reminderConfig.remindWeekDay)
                cycleTitle = String(format: Localized("GROUP_REMINDER_EVERY", comment: ""), weekday)
            } else if cycle == monthly {
                let monthDay = DTGroupUtils.monthDay(withRemindMonthDay: reminderConfig.remindMonthDay)
                cycleTitle = String(format: Localized("GROUP_REMINDER_MONTHLY", comment: ""), monthDay)
            } else {
                return
            }
            let item = OWSTableItem(text: cycleTitle, actionBlock: { [weak self] in
                guard let self else {
                    return
                }
                self.updateGroupReminderCycle(cycle)
            }, accessoryType: isSelected ? .checkmark : .none)
            optionsSection.add(item)
        }
        
        contents.addSection(optionsSection)
        self.contents = contents
    }

    func updateGroupReminderCycle(_ cycle: String) {
        guard let groupThread = self.thread as? TSGroupThread else {
            return
        }
        let reminderCycle = groupThread.groupModel.remindCycle
        guard reminderCycle != cycle else {
            return
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            OWSLogger.error("loacalNumber == nil")
            DTToastHelper.toast(withText: "reminder set error", durationTime: 1)
            return
        }
        
        DTToastHelper.showHud(in: view)
        updateGroupInfoAPI.sendUpdateGroup(withGroupId: thread.serverThreadId, updateInfo: ["remindCycle" : cycle]) { entity in
            DTToastHelper.hide()
            self.databaseStorage.asyncWrite { transaction in
                groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                    instance.groupModel.remindCycle = cycle
                }
                DTGroupUtils.sendGroupReminderMessage(withSource: localNumber,
                                                      serverTimestamp: NSDate.ows_millisecondTimeStamp(),
                                                      isChanged: true,
                                                      thread: groupThread,
                                                      remindCycle: cycle,
                                                      transaction: transaction)
            } completion: { [self] in
                self.updateTableContents()
                guard let updateCompleteBlock = updateCompleteBlock else {
                    return
                }
                updateCompleteBlock()
            }

        } failure: { error in
            DTToastHelper.hide()
            DTToastHelper.toast(withText: error.localizedDescription,
                                durationTime: 1.5)
        }

    }
    
}
