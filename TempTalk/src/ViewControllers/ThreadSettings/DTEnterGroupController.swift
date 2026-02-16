//
//  DTEnterGroupController.swift
//  Wea
//
//  Created by Ethan on 2022/2/25.
//

import UIKit
import TTServiceKit
import SVProgressHUD

class DTEnterGroupController: OWSViewController {

    @objc var groupEntity: DTInviteToGroupEntity?

    @IBOutlet weak var groupAvatar: AvatarImageView?
    @IBOutlet weak var lbGroupName: UILabel?
    @IBOutlet weak var btnEnterGroup: UIButton?

    @objc var inviteCode: String?
    
    lazy var joinGroupApi = DTInviteToGroupAPI()
    lazy var groupUpdateProcessor = DTGroupUpdateMessageProcessor()
    lazy var avatarUpdateProcessor = DTGroupAvatarUpdateProcessor()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(dismissVC))
        view.backgroundColor = Theme.bg1Color

        if let groupEntity = self.groupEntity {
            self.lbGroupName?.text = threadName() + "(\(groupEntity.membersCount))"
            self.btnEnterGroup?.setTitle(Localized("ENTER_GROUP_ACTION", comment: ""), for: .normal)

            guard groupEntity.avatar.count > 0 else {
                return
            }
            self.avatarUpdateProcessor.handleReceivedGroupAvatarUpdate(withAvatarUpdate: groupEntity.avatar) { stream in
                DispatchMainThreadSafe {
                    self.groupAvatar?.image = stream.image()
                }
            } failure: {_ in

            }
        }
    }

    func threadName() -> String {
        guard let groupEntity = self.groupEntity else {
            return MessageStrings.newGroupDefaultTitle()
        }
        let threadName = groupEntity.name
        if threadName.count == 0 {
            return MessageStrings.newGroupDefaultTitle()
        }

        return threadName
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true, completion: nil)
    }
    
    func groupThread(gid: Data?) -> TSGroupThread? {
    
        guard let gid = gid else { return nil }
        guard gid.count > 0 else { return nil }
        
        var groupThread: TSGroupThread?
        self.databaseStorage.read { transaction in
            groupThread = TSGroupThread(groupId: gid, transaction: transaction)
        }
        
        return groupThread
    }
    
    @IBAction func btnEnterGroupAction(_ sender: Any) {

        guard let inviteCode = inviteCode else { return }
        DTToastHelper.svShow()
        joinGroupApi.joinGroup(byInviteCode: inviteCode) { entity, status in
        

            DTToastHelper.dismiss(withDelay: 0.5) { [self] in
               
                guard let gid = TSGroupThread.transformToLocalGroupId(withServerGroupId: entity.gid) else {
                    return
                }
                guard let groupThread = groupThread(gid: gid) else {
                    guard let newGroupThread = groupThreadFromGroupInfo(gid, entity) else {
                        return
                    }
                    pushToGroupConversation(groupThread: newGroupThread)
                    return
                }
                let memberIds = groupThread.groupModel.groupMemberIds
                if let localNumber = TSAccountManager.localNumber(), memberIds.contains(localNumber) {
                    pushToGroupConversation(groupThread: groupThread)
                } else {
                    guard let newGroupThread = groupThreadFromGroupInfo(gid, entity) else {
                        return
                    }
                    pushToGroupConversation(groupThread: newGroupThread)
                }
            }
            guard let localNumber = TSAccountManager.localNumber() else {
                DTToastHelper.show(withInfo: "join group failure, try again!")
                return
            }
            
        } failure: { error in
            let err = error as NSError
            DTToastHelper.dismiss(withDelay: 0.5) {
                if (err.code == DTAPIRequestResponseStatus.OK.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_INVALID_ARGUMENT", comment: ""))
                    return
                } else if (err.code == DTAPIRequestResponseStatus.noPermission.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_INVITER_EXCEPTION", comment: ""))
                    return
                } else if (err.code == DTAPIRequestResponseStatus.noSuchGroup.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_GROUP_EXCEPTION", comment: ""))
                    return
                } else if (err.code == DTAPIRequestResponseStatus.invalidToken.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_INVITATION_EXCEPTION", comment: ""))
                    return
                } else if (err.code == DTAPIRequestResponseStatus.groupIsFull.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_GROUP_FULL", comment: ""))
                    return
                } else if (err.code == DTAPIRequestResponseStatus.noSuchGroupTask.rawValue) {
                    SVProgressHUD.showInfo(withStatus: Localized("GROUP_COMMEN_ERROR_INVITER_NOT_EXIST", comment: ""))
                    return
                } else {
                    SVProgressHUD.showInfo(withStatus: err.localizedDescription)
                }
            }
        }
         
    }
        
    func pushToGroupConversation(groupThread: TSGroupThread) {
        
        // NOTE: 修复在同一进程中先离开群组，又通过链接加入群组时，离开时间段 group 更新内容没有同步的问题，例如 pin 消息
        ConversationViewController.setNeedsRefreshGroupInfo(for: groupThread.serverThreadId)
        
        let tabbarVC = self.presentingViewController as! UITabBarController
        let currentNav = tabbarVC.selectedViewController as! UINavigationController
        currentNav.popToRootViewController(animated: false)
        tabbarVC.selectedIndex = 0
        let homeNav = tabbarVC.selectedViewController as! UINavigationController
        let homeVC = homeNav.viewControllers.first as! HomeViewController
        homeVC.present(groupThread, action: .none)
    }
    
    func groupThreadFromGroupInfo(_ gid: Data, _ entity: DTInviteToGroupEntity) -> TSGroupThread? {
       
        var newGroupThread: TSGroupThread?
        
        self.databaseStorage.write { transaction in
            newGroupThread = self.groupUpdateProcessor.generateConverationByInvite(withGroupId: gid, groupInfo: entity, transaction: transaction)
        }
        
        return newGroupThread
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
        
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }
        
    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }
    
}
