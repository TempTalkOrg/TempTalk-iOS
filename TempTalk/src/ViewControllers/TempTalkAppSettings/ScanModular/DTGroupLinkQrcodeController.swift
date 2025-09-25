//
//  DTGroupLinkQrcodeController.swift
//  Signal
//
//  Created by hornet on 2023/5/16.
//  Copyright © 2023 Difft. All rights reserved.
//
import TTServiceKit

class DTGroupLinkQrcodeController : OWSViewController , DTInviteCodeContentDelegate {
    static let shortInviteCode = "shortGroupInviteCode"
    let inviteCodeApi: DTInviteToGroupAPI =  DTInviteToGroupAPI()
    let qrcodeView : QRCodeView = QRCodeView()
    let contentView = UIView()
    var inviteCodeContentView :DTInviteCodeContent?
    var inviteCode :String=""
    var inviteUrl :String=""
    var gThread :TSGroupThread
    
    @objc init(gThread: TSGroupThread) {
        self.gThread = gThread
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        inviteCodeContentView = DTInviteCodeContent(delegate: self, isGroupLink: true)
        guard let inviteCodeContentView = inviteCodeContentView else { return }
        self.view.addSubview(contentView)
        self.view.addSubview(inviteCodeContentView)
        addGesture()
        prepareData()
    }
    
    func addGesture() {
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(tapGesture))
        view.addGestureRecognizer(tap)
    }
    
    @objc func tapGesture() {
        self.dismiss(animated: true)
    }
    
    func setupUILayout() {
        guard let inviteCodeContentView = inviteCodeContentView else { return }
        contentView.autoPinEdgesToSuperviewEdges()
        inviteCodeContentView.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self.view)
        inviteCodeContentView.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self.view)
        inviteCodeContentView.autoSetDimension(ALDimension.height, toSize: 514)
        inviteCodeContentView.autoPinEdge(ALEdge.bottom, to: ALEdge.bottom, of: self.view)
        inviteCodeContentView.backgroundColor = UIColor(rgbHex: 0xffffff, alpha:0.93)

        inviteCodeContentView.layer.maskedCorners = [.layerMinXMinYCorner,.layerMaxXMinYCorner]
        inviteCodeContentView.layer.cornerRadius = 8
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUILayout()
        self.navigationController?.navigationBar.isHidden = true
        view.backgroundColor = Theme.secondaryBackgroundColor
        contentView.backgroundColor = Theme.secondaryBackgroundColor
        
    }
    @objc
    func prepareData() {
            self.requestInviteCode()
    }
    
    func requestInviteCode()  {
        let gid: String? = TSGroupThread.transformToServerGroupId(withLocalGroupId: gThread.groupModel.groupId)
        guard let gid = gid  else {
            return
        }
        self.inviteCodeApi.getInviteCode(withGId: gid) {[weak self]  inviteCode in
            guard let self = self else { return }
            guard let inviteCodeContentView = self.inviteCodeContentView else { return }
            self.inviteCode = inviteCode.stripped
            self.inviteUrl = self.groupLinkInviteUrl();
            inviteCodeContentView.configData(urlString: self.inviteUrl)
        } failure: { error in
                DTToastHelper._showError(error.localizedDescription)
        }
    }
    
    override func applyTheme() {
        super.applyTheme()
        self.inviteCodeContentView?.backgroundColor = UIColor(rgbHex: 0xffffff, alpha:0.93)
        view.backgroundColor = Theme.secondaryBackgroundColor
        contentView.backgroundColor = Theme.secondaryBackgroundColor
    }
    
    func inviteCodeContentView(_ inviteView: DTInviteCodeContent, actionType:DTInviteCodeContentActionType, sender: UIButton) {
        switch actionType {
        case .scan:
            let scanVc : DTScanQRCodeController =  DTScanQRCodeController()
            self.navigationController?.pushViewController(scanVc, animated: true)
        case .regenerate :
           return
        case .share:
            if(self.inviteCode.count > 0) {
                let inviteMessage = self.inviteDisplayText()
                let activityController = UIActivityViewController.init(activityItems: [inviteMessage], applicationActivities: nil)
                activityController.completionWithItemsHandler =  { activity, success, items, error in
                    if(success == true){
                        self.dismiss(animated: true)
                    }
                }
                self.navigationController?.present(activityController, animated: true, completion:nil)
            } else{
                
            }
        case .copyLink:
            if(self.inviteCode.count > 0) {
                let pasteboard: UIPasteboard = UIPasteboard.general
                pasteboard.string = self.inviteDisplayText()
                self.dismiss(animated: true) {
                    DTToastHelper.toast(withText: Localized("COPYID", comment: ""))
                }
            } else {
                OWSLogger.error("inviteCode 邀请码异常");
            }
        case .cancel: self.dismiss(animated: true)
        }
    }
    
    func displayName() -> String {
        guard let localNumber = TSAccountManager.localNumber() else {
            return ""
        }
        return Environment.shared.contactsManager.contactOrProfileName(forPhoneIdentifier: localNumber)
    }
        
    func inviteDisplayText() -> String {
        return String(format: Localized("SHARE_GROUP_LINK_INVITE_TEXT", comment: ""), TSConstants.appDisplayName, threadName()) + "\n" + self.groupLinkInviteUrl()
    }
    
    func groupLinkInviteUrl() -> String {
        let finalCode = inviteCode.byURLQueryEncode()
        if(TSConstants.isUsingProductionService){
            return "https://chative.com/u/g.html?i=" + finalCode
        }
        return "https://www.test.chative.im/u/g.html?i=" + finalCode
    }
    
    func inviteMessageText() -> String {
        return String(format: Localized("SHARE_GROUP_LINK_INVITE_TEXT", comment: ""), TSConstants.appDisplayName, threadName()) + "(" + self.groupLinkInviteUrl() + ")"
    }
    
    func threadName() -> String {
        var threadName: String = ""
        self.databaseStorage.read { transaction in
            threadName = self.gThread.name(with: transaction)
        }
        
        if threadName.count == 0 {
            return MessageStrings.newGroupDefaultTitle()
        }
        return threadName
    }
    
}
