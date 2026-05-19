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
        let actionTitle = Localized(isOwner ? "CONFIRM_DISBAND" : "CONFIRM_LEAVE_GROUP_CTA", comment: "")
        
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
            self.databaseStorage.write { transaction in
                
                groupThread.anyRemove(transaction: transaction)
                DTGroupUtils.removeGroupBaseInfo(withGid: serverThreadId, transaction: transaction)
            }
            
            guard let localNumber = TSAccountManager.localNumber() else {
                DTToastHelper.show(withInfo: "Leave group failure, try again!")
                return
            }

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
    
    static func removeMember(_ recipientId: String, from groupThread: TSGroupThread, viewController: UIViewController, needAlert: Bool = true, completion: (() -> Void)? = nil) {
        let serverThreadId = groupThread.serverThreadId
        guard !serverThreadId.isEmpty else { return }

        let doRemove = {
            DTToastHelper.svShow()
            removeMemberApi.sendRequestWith(withGroupId: serverThreadId, numbers: [recipientId]) { _ in
                DTToastHelper.dismiss()
                applyMemberRemoval([recipientId], groupThread: groupThread)
                completion?()
            } failure: { error in
                DTToastHelper.dismiss()
                let err = error as NSError
                if err.code == DTAPIRequestResponseStatus.noSuchGroupMember.rawValue {
                    applyMemberRemoval([recipientId], groupThread: groupThread)
                    completion?()
                } else {
                    DTToastHelper.show(withInfo: err.localizedDescription)
                }
            }
        }

        guard needAlert else { doRemove(); return }

        let displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: recipientId)
        let title = String(format: Localized("CONFIRM_REMOVE_MEMBER_TITLE_FORMAT"), displayName)
        let alert = UIAlertController(
            title: title,
            message: Localized("CONFIRM_REMOVE_MEMBER_BODY"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localized("CONFIRM_REMOVE_MEMBER_CTA"), style: .destructive) { _ in
            doRemove()
        })
        alert.addAction(OWSAlerts.cancelAction)
        viewController.present(alert, animated: true)
    }

    private static func applyMemberRemoval(_ removedIds: [String], groupThread: TSGroupThread) {
        let newGroupModel = DTGroupUtils.createNewGroupModel(with: groupThread.groupModel)
        var remainingMembers = Set(newGroupModel.groupMemberIds)
        let removedSet = Set(removedIds)
        remainingMembers.subtract(removedSet)
        newGroupModel.groupMemberIds = Array(remainingMembers)

        var adminList = newGroupModel.groupAdmin ?? []
        for rid in removedIds {
            adminList.removeAll { $0 == rid }
            newGroupModel.removeRapidRole(rid)
        }
        newGroupModel.groupAdmin = adminList

        var updateGroupInfo: String = ""
        var shouldAffectThreadSorting: ObjCBool = false
        databaseStorage.read { transaction in
            updateGroupInfo = DTGroupUtils.getMemberChangedInfoString(
                withJoinedMemberIds: nil,
                removedMemberIds: removedIds,
                leftMemberIds: nil,
                shouldAffectThreadSorting: &shouldAffectThreadSorting,
                transaction: transaction
            ) ?? ""
        }

        let now = NSDate.ows_millisecondTimeStamp()
        databaseStorage.asyncWrite { transaction in
            groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                instance.groupModel = newGroupModel
            }
            let systemMsg = TSInfoMessage(
                timestamp: now,
                in: groupThread,
                messageType: .typeGroupUpdate,
                customMessage: updateGroupInfo
            )
            systemMsg.isShouldAffectThreadSorting = shouldAffectThreadSorting.boolValue
            systemMsg.anyInsert(transaction: transaction)
        }

        DTGroupUtils.postRapidRoleChangeNotification(with: newGroupModel, targedMemberIds: removedIds)

        let channelName = DTCallManager.generateGroupChannelName(by: groupThread)
        DTCallManager.sharedInstance().putMeetingGroupMemberKickBychannelName(channelName, users: removedIds) { responseObject in
            guard let dict = responseObject as? [String: Any],
                  let status = dict["status"] as? Int else { return }
            if status == 0 {
                Logger.info("[\(DTLeaveOrDisbandGroup.self)] kick member success: \(channelName)")
            } else {
                Logger.error("[\(DTLeaveOrDisbandGroup.self)] kick member fail: \(channelName), status: \(status)")
            }
        } failure: { error in
            Logger.error("[\(DTLeaveOrDisbandGroup.self)] kick member fail: \(channelName), reason: \(error.localizedDescription)")
        }
    }

    static func dismissGroup(_ groupThread: TSGroupThread, _ completion: (() -> Void)?) {
        
        let serverThreadId = groupThread.serverThreadId
        if (serverThreadId.isEmpty) { return }
        
        func next() {            
            self.databaseStorage.write { transaction in
                groupThread.anyRemove(transaction: transaction)
                DTGroupUtils.removeGroupBaseInfo(withGid: serverThreadId, transaction: transaction)
            }
            
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
