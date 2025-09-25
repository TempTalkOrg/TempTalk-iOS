//
//  DTLeaveOrDisbandGroup.swift
//  
//
//  Created by Ethan on 27/07/2023.
//

import UIKit

@objcMembers
public class DTLeaveOrDisbandGroup: NSObject {

    static let removeMemberApi = DTRemoveMembersOfAGroupAPI()
    static let dismissGroupApi = DTDismissAGroupAPI()
    
    @objc
    static func leaveOrDisbandGroup(_ groupThread: TSGroupThread, viewController: UIViewController, needAlert: Bool = true, completion: (() -> Void)? = nil) {
        
        let isOwner = groupThread.groupModel.groupOwner == TSAccountManager.localNumber()
        if (needAlert == false) {
            if (isOwner) {
                dismissGroup(groupThread, completion)
            } else {
                leaveGroup(groupThread, completion)
            }
            return
        }
        
        let title = Localized(isOwner ? "CONFIRM_DISMISS_GROUP_TITLE" : "CONFIRM_LEAVE_GROUP_TITLE", comment: "")
        let message = Localized(isOwner ? "CONFIRM_DISBAND_GROUP_DESCRIPTION" : "CONFIRM_LEAVE_GROUP_DESCRIPTION", comment: "")
        let actionTitle = Localized(isOwner ? "CONFIRM_DISBAND" : "LEAVE_BUTTON_TITLE", comment: "")
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: actionTitle, style: .destructive) { alertAction in
            if (isOwner) {
                dismissGroup(groupThread, completion)
            } else {
                leaveGroup(groupThread, completion)
            }
        }
        alertController.addAction(action)
        alertController.addAction(OWSAlerts.cancelAction)
        
        viewController.present(alertController, animated: true)
    }
    
    static func leaveGroup(_ groupThread: TSGroupThread, _ completion: (() -> Void)?) {
        
        let serverThreadId = groupThread.serverThreadId
        if (serverThreadId.isEmpty) { return }
        
        func next() {
            DTPinnedDataSource.shared().removeAllPinnedMessage(serverThreadId)
            self.databaseStorage.write { transaction in
                
                groupThread.anyRemove(transaction: transaction)
                DTGroupUtils.removeGroupBaseInfo(withGid: serverThreadId, transaction: transaction)
            }
            
            guard let localNumber = TSAccountManager.localNumber() else {
                DTToastHelper.show(withInfo: "Leave group failure, try again!")
                return
            }
            //MARK: 退群通知server处理预约会议
            DTCalendarManager.shared.groupChange(gid: groupThread.serverThreadId, actionCode: 2, target: [localNumber])

            let channelName = DTCallManager.generateGroupChannelName(by: groupThread)
            DTCallManager.sharedInstance().putMeetingGroupMemberLeaveBychannelName(channelName) { responseBodyJson in
                guard let responseObject = responseBodyJson as? [String: Any] else {
                    return
                }
                guard let status = responseObject["status"] as? NSNumber else {
                    return
                }
                if (status.intValue == 0) {
                    Logger.info("[\(DTLeaveOrDisbandGroup.self)] leave group success: \(channelName)")
                } else {
                    Logger.info("[\(DTLeaveOrDisbandGroup.self)] leave group fail: \(channelName), status: \(status)")
                }
            } failure: { error in
                Logger.error("[\(DTLeaveOrDisbandGroup.self)] leave group fail: \(channelName), reason: \(error.localizedDescription)")
            }
            
            guard let completion = completion else {
                return
            }
            completion()
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            DTToastHelper.show(withInfo: "Leave group failure, try again!")
            return
        }
        
        DTToastHelper.svShow()
        DTLeaveOrDisbandGroup.removeMemberApi.sendRequestWith(withGroupId: serverThreadId, numbers: [localNumber]) { _ in
            DTToastHelper.dismiss()
            next()
        } failure: { error in
            let err = error as NSError
            if (err.code == DTAPIRequestResponseStatus.noPermission.rawValue) {
                next()
            } else {
                DTToastHelper.show(withInfo: err.localizedDescription)
            }
        }
    }
    
    static func dismissGroup(_ groupThread: TSGroupThread, _ completion: (() -> Void)?) {
        
        let serverThreadId = groupThread.serverThreadId
        if (serverThreadId.isEmpty) { return }
        
        func next() {
            DTPinnedDataSource.shared().removeAllPinnedMessage(serverThreadId)
            
            self.databaseStorage.write { transaction in
                groupThread.anyRemove(transaction: transaction)
                DTGroupUtils.removeGroupBaseInfo(withGid: serverThreadId, transaction: transaction)
            }
            
            //MARK: 解散群通知server处理预约会议
            DTCalendarManager.shared.groupChange(gid: groupThread.serverThreadId, actionCode: 5)
            
            guard let completion = completion else {
                return
            }
            completion()
        }
        
        DTToastHelper.svShow()
        DTLeaveOrDisbandGroup.dismissGroupApi.sendRequest(withGroupId: serverThreadId) { responseObject in
            DTToastHelper.dismiss()
            next()
        } failure: { error in
            let err = error as NSError
            if (err.code == DTAPIRequestResponseStatus.noPermission.rawValue) {
                next()
            } else {
                DTToastHelper.show(withInfo: err.localizedDescription)
            }
        }
    }
    
}
