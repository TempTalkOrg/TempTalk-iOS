//
//  DTPersonCardController.swift
//  Signal
//
//  Created by user on 2024/2/19.
//  Copyright © 2024 Difft. All rights reserved.
//

//import Foundation
//

import TTServiceKit
import TTMessaging
import PanModal

@objc enum DTPersonalCardType : Int{
    case selfCanEdit // 自己的名片可编辑
    case selfNoneEdit // 自己的名片无法编辑
    case selfNoneEditWithPresentModel // 自己的名片无法编辑(show present)
    case other // 他人的名片
}

class DTPersonalCardController: OWSTableViewController,
                                DTCardAlertViewControllerDelegate {
    
    var recipientId: String?
    var account: SignalAccount
    var type: DTPersonalCardType
    
    var iconImage: DTAvatarImageView?
    let avatarViewHelper: AvatarViewHelper = AvatarViewHelper()
    var alertController: UIAlertController?
    var avatarImage: UIImage?
    var attachmentEntity: DTProfileAttachmentEntity?
    
    var contactThread: TSContactThread?
    var viewDidAppear: Bool
    @objc var isFromSameThread: Bool = false
    @objc var isFromContacts: Bool = false  // 标记是否从通讯录进入
    var targetThreads: [TSThread]?
    var signatureLabel: UILabel?
    var isShortFormEnabled = true
    
    private lazy var backBtn: UIButton = {
        let button = UIButton()
        button.setTitleColor(Theme.tprimaryColor, for: .normal)
        button.setBackgroundImage(UIImage(named: "NavBarBackNew"), for: .normal)
        button.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        return button
    }()
    
    var accessoryArrow: UIImageView?
    var photoBrowser: DTImageBrowserView?
    
    var commonGroupContext: DTCommonGroupContext?
    
    
    override func loadView() {
        super.loadView()
        self.view.backgroundColor = Theme.bgpageSecondaryColor
        self.createViews()
        self.avatarViewHelper.delegate = self
    }
    
    @objc init(type: DTPersonalCardType, recipientId: String, account: SignalAccount?) {
        self.type = type
        self.recipientId = recipientId
        if let account {
            self.account = account
        } else {
            self.account = SignalAccount(recipientId: recipientId)
        }
        self.viewDidAppear = false
        super.init()
    }
    
    @objc static func preConfigure(withRecipientId recipientId: String, complete completeBlock: ((SignalAccount?) -> Void)?) {
        guard let contactsManager = Environment.shared.contactsManager else { return }
        var account: SignalAccount?
        databaseStorage.read { transaction in
            account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)
        }
        if account != nil,
           account?.contact != nil,
           account?.contact?.fullName != recipientId,
            let sourceDescribe = account?.contact?.sourceDescribe,
            !sourceDescribe.isEmpty {
            completeBlock?(account)
        } else {
            fetchAccountData(recipientId: recipientId, contactsManager: contactsManager, completion: completeBlock)
        }
    }
    
    static func fetchAccountData(
        recipientId: String,
        contactsManager: OWSContactsManager,
        completion: ((SignalAccount?) -> Void)?
    ) {
        
        guard !recipientId.isEmpty else {
            completion?(nil)
            return
        }
        TSAccountManager.sharedInstance().getContactMessageV1(byPhoneNumber: [recipientId]) { contacts in
            guard let newContact = contacts.first as? Contact else { return }
            
            self.databaseStorage.asyncWrite { transaction in
                guard let contactsManager = Environment.shared.contactsManager else {return}
                let newAccount = SignalAccount(recipientId: recipientId)
                newAccount.contact = newContact
                contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transaction)
                transaction.addAsyncCompletionOnMain {
                    completion?(newAccount)
                }
            }
            
        } failure: { error in
            DTToastHelper.toast(withText: "Data error!")
            Logger.error("prepareAccountData error:\(error)")
            completion?(nil)
        }
    }
    
    func createViews() {
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 60
        self.tableView.separatorStyle = .none
        self.tableView.backgroundColor = Theme.bg1Color
        self.tableView.isScrollEnabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let recipientId {
            let thread = TSContactThread.getOrCreateThread(contactId: recipientId)
            self.contactThread = thread
            weak var weakSelf = self
            self.commonGroupContext = DTCommonGroupContext(contactThread: thread, completion: {
                weakSelf?.updateTableContents()
            })
            self.commonGroupContext?.fetchInCommonGroupsData()
        }

        addCloseBarItem()
        updateTableContents()
        requestUserMessage()
        NotificationCenter.default.addObserver(self, selector: #selector(signalAccountsDidChange), name: NSNotification.Name.OWSContactsManagerSignalAccountsDidChange, object: nil)
    }

    func addCloseBarItem() {
        if isPresented() {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "nav_bar_close"), style: .plain, target: self, action: #selector(backBtnClick))
        }
    }
    
    func updateMoreBtnStatus() {
        if account.isFriend {
            let moreBtn = UIBarButtonItem(image: UIImage(named: "nav_bar_more"), style: .plain, target: self, action: #selector(moreBtnClick))
            if type == .other {
                // Show edit button for both bot and non-bot accounts
                let editButton = UIButton(type: .custom)
                let editImage = UIImage(named: "setting_edit")?.withRenderingMode(.alwaysTemplate)
                editButton.setImage(editImage, for: .normal)
                editButton.tintColor = navigationController?.navigationBar.tintColor
                editButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
                editButton.addTarget(self, action: #selector(editNameBtnClick), for: .touchUpInside)
                let editBtn = UIBarButtonItem(customView: editButton)
                self.navigationItem.rightBarButtonItems = [moreBtn, editBtn]
            } else {
                self.navigationItem.rightBarButtonItems = [moreBtn]
            }
        } else {
            self.navigationItem.rightBarButtonItems = nil
        }
    }
    
    func isPresented() -> Bool {
        return presentingViewController != nil
    }
    deinit{
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.viewDidAppear = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.viewDidAppear = false;
    }

    override func applyTheme() {

        super.applyTheme()
        updateTableContents()

        view.backgroundColor = Theme.bgpageSecondaryColor
        tableView.backgroundColor = Theme.bg1Color

    }
    
    @objc func signalAccountsDidChange(notify: Notification) {
        reloadAccountFromDB()
    }

    @objc func reloadAccountFromDB() {
        let contactsManager = Environment.shared.contactsManager
        databaseStorage.asyncRead {[weak self] transaction in
            guard let self, let recipientId = self.recipientId else {return}
            if let account = contactsManager?.signalAccount(forRecipientId: recipientId, transaction: transaction) {
                self.account = account
            }
        } completion: {
            self.updateTableContents()
        }
    }
    
    @objc func performUpdateTableContents(withDelayTime time: TimeInterval) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateTableContents), object: nil)
        perform(#selector(updateTableContents), with: nil, afterDelay: time, inModes: [RunLoop.Mode.default])
    }
    
    @objc func updateTableContents() {
        
        updateMoreBtnStatus()
        
        guard let recipientId = self.recipientId, let contactThread else {
            return
        }
                
        let contents = OWSTableContents()
        let topSection = OWSTableSection()
        
        topSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.personCardHeaderCell() ?? UITableViewCell()
        }, customRowHeight: UITableView.automaticDimension, actionBlock: {}))
        
        topSection.add(OWSTableItem(customCellBlock: { [weak self] in
            guard let self else { return UITableViewCell()}
            return self.quickActionCell()
        }, customRowHeight: 96, actionBlock: {}))
        
        let contactsSection = OWSTableSection()
        
        contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
            guard let self else { return UITableViewCell()}
            return self.cornerRadiusCell()
        }, customRowHeight: 16, actionBlock: {}))
        
        contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
            guard let self else { return UITableViewCell()}
            return self.sectionHeaderCell(title: Localized("CONTACT_PROFILE_BUSINESS_CONTACT_INFO"))
        }, customRowHeight: 40, actionBlock: {}))

        contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
            guard let self else { return UITableViewCell()}
            let customUid = account.contact?.customUid
            let displayId = NSString.displayUserId(withCustomUid: customUid, recipientId: recipientId)
            return self.personCardForOther(withTitle: Localized("PERSON_CARD_ID"), detailText: displayId, longPressSel: #selector(self.longPressIDClick(_:)), accessoryType: .none)
        }, customRowHeight: 36, actionBlock: {}))
        
        let isMe = recipientId == TSAccountManager.shared.localNumber()
        
        if isMe,
           let email = TSAccountManager.shared.loadStoredUserEmail() {
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("PERSON_CARD_EMAIL"), detailText: email, longPressSel: #selector(self.longPressEmailClick(_:)), accessoryType: .none)
            }, customRowHeight: 36, actionBlock: {}))
        }
        
        if isMe,
           let phoneNumber = TSAccountManager.shared.loadStoredUserPhone() {
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("PERSON_CARD_PHONE_NUMBER"), detailText: phoneNumber, longPressSel: #selector(self.longPressPhoneNumberClick(_:)), accessoryType: .none)
            }, customRowHeight: 36, actionBlock: {}))
        }
        
        if let contact = account.contact,
           let joinedAt = contact.joinedAt,
            !joinedAt.isEmpty {
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("JOINED"), detailText: joinedAt, longPressSel: nil, accessoryType: .none)
            }, customRowHeight: 36, actionBlock: {}))
        }
        
        if type == .other,
           let contact = account.contact,
           let sourceDesc = contact.sourceDescribe,
           !sourceDesc.isEmpty {
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("MET_METHOD"), detailText: sourceDesc, longPressSel: nil, accessoryType: .none, numberOfLines: 0)
            }, customRowHeight: UITableView.automaticDimension, actionBlock: {}))
        }

        if account.isBot() {
            let botWebsite = "https://yelling.pro"
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("PERSON_CARD_WEBSITE"), detailText: botWebsite, detailColor: Theme.tinfoColor, longPressSel: nil, accessoryType: .none)
            }, customRowHeight: 36, actionBlock: {
                if let url = URL(string: botWebsite) {
                    UIApplication.shared.open(url)
                }
            }))
        } else if !isMe {
            var detailText = "0"
            let commonGroups = commonGroupContext?.inCommonGroups
            if let commonGroups, !commonGroups.isEmpty {
                detailText = "\(commonGroups.count)"
            }
            contactsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell()}
                return self.personCardForOther(withTitle: Localized("GROUPS"), detailText: detailText, longPressSel: nil, accessoryType: .disclosureIndicator)
            }, customRowHeight: 36, actionBlock: { [weak self] in
                self?.showCommonGroups()
            }))
        }
        
        contents.addSection(topSection)
        contents.addSection(contactsSection)

        self.contents = contents
    }
    
    func requestUserMessage() {
        guard let recipientId = recipientId else { return }
        TSAccountManager.sharedInstance().getContactMessageV1(byPhoneNumber: [recipientId]) { [weak self] contacts in
            guard let self = self, let newContact = contacts.first as? Contact else { return }
            
            //当前存在，并且相同
            if let contact = self.account.contact, contact.isEqual(newContact) { return }
            
            //当前存在，不相同，但是new是非好友
            if let contact = self.account.contact, !contact.isEqual(newContact) {
                if newContact.isExternal {
                    //不完全替换，防止添加好友跳转到card页面后头像、时间被覆盖
                    if contact.isExternal != newContact.isExternal ||
                        contact.fullName != newContact.fullName {
                        contact.isExternal = newContact.isExternal
                        contact.fullName = newContact.fullName
                    } else {
                        return
                    }
                } else {
                    self.account.contact = newContact
                }
            } else {
                self.account.contact = newContact
            }
            
            self.databaseStorage.asyncWrite { transaction in
                guard let contactsManager = Environment.shared.contactsManager else {return}
                
                contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: self.account, with: transaction)
                
            } completion: {
                
            }
            
        } failure: { error in
            Logger.info("requestUserMessage fail")
        }
    }
    
    private func updateLocalProfile(completion: @escaping () -> Void) {
        guard let recipientId = recipientId, let fullName = account.contact?.fullName, let contactsManager = Environment.shared.contactsManager else {return}
        
        OWSProfileManager.shared().updateLocalProfileName(fullName, avatarImage: avatarImage) {
            DTToastHelper.dismiss(withDelay: 0.2)
            
            self.databaseStorage.asyncWrite { transaction in
                
                let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)
                if let contact = account?.contact {
                    let avatar = OWSProfileManager.shared().localAvatar()
                    contact.avatar = avatar
                    if let newAccount = account?.copy() as? SignalAccount {
                        contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transaction)
                        
                        self.iconImage?.setImage(avatar: contact.avatar as? [String : Any], recipientId: recipientId, displayName: newAccount.contactFullName(), completion: nil)
                    }
                }
                
            } completion: {
                completion()
            }
            
        } failure: {
            DTToastHelper.dismiss(withInfo: Localized("PROFILE_VIEW_ERROR_UPDATE_FAILED", comment: "Error message shown when a profile update fails."))
        }
    }
    
    func uploadAvaterToTheServer(completion: @escaping () -> Void) {
        DTToastHelper.show(withStatus: Localized("PROFILE_VIEW_SAVING", comment: "Alert title that indicates the user's profile view is being saved."))
        updateLocalProfile(completion: completion)
    }
    
    @objc func backBtnClick() {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func moreBtnClick() {
        guard let contactThread else {
            return
        }

        let settingsVC = OWSConversationSettingsViewController()
        settingsVC.configure(with: contactThread)
        settingsVC.showVerificationOnAppear = false

        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true) {
                // dismiss 完成后，找到底层的 ViewController 并 push settingsVC
                if let conversationVC = self.findConversationViewController(from: presentingVC) {
                    conversationVC.navigationController?.pushViewController(settingsVC, animated: true)
                } else if let navController = presentingVC as? UINavigationController {
                    navController.pushViewController(settingsVC, animated: true)
                } else if let navController = presentingVC.navigationController {
                    navController.pushViewController(settingsVC, animated: true)
                }
            }
        } else {
            self.navigationController?.pushViewController(settingsVC, animated: true)
        }
    }

    private func showCommonGroups() {
        guard let commonGroupContext = commonGroupContext,
              let inCommonGroups = commonGroupContext.inCommonGroups,
              !inCommonGroups.isEmpty else {
            return
        }

        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                // dismiss 完成后，找到底层的 ViewController 并 push 共同群 VC
                if let conversationVC = self.findConversationViewController(from: presentingVC),
                   let navController = conversationVC.navigationController {
                    commonGroupContext.showCommonView(with: navController)
                } else if let navController = presentingVC as? UINavigationController {
                    commonGroupContext.showCommonView(with: navController)
                } else if let navController = presentingVC.navigationController {
                    commonGroupContext.showCommonView(with: navController)
                }
            }
        } else {
            if let navigationController = self.navigationController {
                commonGroupContext.showCommonView(with: navigationController)
            }
        }
    }
    
    func showDetailAlertViewController(withTitle title: String, detail contentString: String, type: DTCardAlertViewType, maxLength: UInt, tag: Int) {
        showDetailAlertViewController(withTitle: title, detailAttributedString: NSAttributedString(string: contentString), type: type, maxLength: maxLength, tag: tag)
    }
    
    func getAttributedString(content: String, image: UIImage, font: UIFont) -> NSAttributedString {
        let contentAtt = NSMutableAttributedString(string: "\(content) ", attributes: [.font: UIFont(name: "PingFangSC-Medium", size: 20)!, .foregroundColor: Theme.tprimaryColor])
        let imageMent = NSTextAttachment()
        imageMent.image = image
        let paddingTop = font.lineHeight - font.pointSize - 2
        imageMent.bounds = CGRect(x: 0, y: -paddingTop, width: font.lineHeight, height: font.lineHeight)
        let imageAtt = NSAttributedString(attachment: imageMent)
        contentAtt.append(imageAtt)
        return contentAtt
    }

    
    func personCardHeaderCell() -> UITableViewCell {
        let lightBgColor = UIColor(rgbHex: 0xFAFAFA)
        let darkBgColor = UIColor(rgbHex: 0x181A20)
        // let darkBgColor = UIColor(rgbHex: 0x2B3139)
        
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = Theme.bgpageSecondaryColor
        cell.contentView.backgroundColor = Theme.bgpageSecondaryColor
        
        let containStackView = UIStackView()
        containStackView.axis = .vertical
        containStackView.alignment = .center
        containStackView.distribution = .fill
        cell.contentView.addSubview(containStackView)
        containStackView.autoPinEdgesToSuperviewEdges()
        
        let topContentRow = UIStackView()
        topContentRow.spacing = 10
        topContentRow.axis = .horizontal
        topContentRow.alignment = .center
        topContentRow.distribution = .fill
        topContentRow.isLayoutMarginsRelativeArrangement = true
        topContentRow.layoutMargins = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 15)
        containStackView.addArrangedSubview(topContentRow)
        topContentRow.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        topContentRow.autoSetDimension(.height, toSize: 132)
        
        let topRightContentView = UIStackView()
        topRightContentView.spacing = 5
        topRightContentView.axis = .vertical
        topRightContentView.alignment = .leading
        topRightContentView.distribution = .fill
        
        let nameLabel = UILabel()
        nameLabel.font = UIFont(name: "PingFangSC-Medium", size: 20)
        nameLabel.textColor = Theme.tprimaryColor
        nameLabel.numberOfLines = 2
        nameLabel.isUserInteractionEnabled = false  // Disable tap gesture for name label
        let displayName = Environment.shared.contactsManager?.displayName(forPhoneIdentifier: recipientId) ?? ""
        // For avatar generation, use nickname only (not remark name)
        let nicknameForAvatar: String = {
            if let name = Environment.shared.contactsManager?.rawDisplayName(forPhoneIdentifier: recipientId ?? "") {
                return name
            }
            return recipientId ?? ""
        }()
        if type == .other && account.isBot() {
            let supportIcon = UIImage(named: "setting_support")
            let displayNameAttributed = generateNameAttributedString(displayName.ows_stripped(), image: supportIcon, font: UIFont(name: "PingFangSC-Medium", size: 12))
            nameLabel.attributedText = displayNameAttributed
        } else {
            nameLabel.text = displayName.ows_stripped()
        }
        topRightContentView.addArrangedSubview(nameLabel)

        if self.type != .selfCanEdit {
            if account.isBot() {
                let secondaryLabel = UILabel()
                secondaryLabel.textColor = Theme.tsecondaryColor
                secondaryLabel.font = UIFont.ows_regularFont(withSize: 14)
                secondaryLabel.textAlignment = .left
                secondaryLabel.isUserInteractionEnabled = false
                let rawName = Environment.shared.contactsManager?.rawDisplayName(forPhoneIdentifier: recipientId ?? "") ?? ""
                secondaryLabel.text = rawName
                topRightContentView.addArrangedSubview(secondaryLabel)
            } else if let contact = account.contact {
                let hasRemarkAvatar = contact.remarkAvatar != nil && !contact.remarkAvatar!.isEmpty
                let hasRemarkName = contact.remark != nil && !contact.remark!.isEmpty

                if hasRemarkAvatar {
                    let originalRow = UIStackView()
                    originalRow.axis = .horizontal
                    originalRow.alignment = .center
                    originalRow.spacing = 4

                    if !hasRemarkName {
                        let originalLabel = UILabel()
                        originalLabel.text = Localized("PERSON_CARD_ORIGINAL_LABEL", comment: "")
                        originalLabel.font = .systemFont(ofSize: 12)
                        originalLabel.textColor = Theme.tthirdColor
                        originalLabel.setContentHuggingPriority(.required, for: .horizontal)
                        originalRow.addArrangedSubview(originalLabel)
                    }

                    let smallAvatar = DTAvatarImageView()
                    smallAvatar.autoSetDimensions(to: CGSize(width: 16, height: 16))
                    smallAvatar.isUserInteractionEnabled = true
                    smallAvatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapOriginalAvatar)))
                    smallAvatar.setImage(
                        avatar: contact.avatar as? [String: Any],
                        recipientId: recipientId,
                        displayName: contact.fullName,
                        completion: nil
                    )
                    originalRow.addArrangedSubview(smallAvatar)

                    if hasRemarkName {
                        let nameLabel = UILabel()
                        nameLabel.text = contact.fullName
                        nameLabel.font = UIFont.ows_regularFont(withSize: 14)
                        nameLabel.textColor = Theme.tsecondaryColor
                        originalRow.addArrangedSubview(nameLabel)
                    }

                    topRightContentView.addArrangedSubview(originalRow)
                } else if hasRemarkName {
                    let secondaryLabel = UILabel()
                    secondaryLabel.textColor = Theme.tsecondaryColor
                    secondaryLabel.font = UIFont.ows_regularFont(withSize: 14)
                    secondaryLabel.textAlignment = .left
                    secondaryLabel.isUserInteractionEnabled = false
                    secondaryLabel.text = Localized("CONTACT_PROFILE_NAME", comment: "") + ": \(contact.fullName)"
                    topRightContentView.addArrangedSubview(secondaryLabel)
                }
            }
        }
        
        let avatarContentView = UIView()
        iconImage = DTAvatarImageView()
        guard let iconImage = iconImage else { return OWSTableItem.newCell()}
        iconImage.imageForSelfType = .original
        iconImage.stateBackgroundColor = Theme.bg1Color
        let tapAvatarRecognizer = UITapGestureRecognizer(target: self, action: #selector(changeUserAvatarImage))
        iconImage.isUserInteractionEnabled = true
        iconImage.addGestureRecognizer(tapAvatarRecognizer)
        
        avatarContentView.addSubview(iconImage)
        iconImage.autoPinEdgesToSuperviewEdges()
        avatarContentView.autoSetDimension(.height, toSize: 75)
        avatarContentView.autoSetDimension(.width, toSize: 75)
        iconImage.setImage(signalAccount: account, displayName: nicknameForAvatar, completion: nil)
        
        topContentRow.addArrangedSubview(avatarContentView)
        topContentRow.addArrangedSubview(topRightContentView)
        
        return cell
    }
    
    
    @objc func closeButtonClick(_ sender: UIButton) {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func changeUserAvatarImage(_ tap: UITapGestureRecognizer) {
        showAvatarBrowserViewAnimate(true)
    }
    
    @objc func tapNameClick(tapRecognizer: UITapGestureRecognizer) {
        editNameBtnClick()
    }

    @objc func editNameBtnClick() {
        guard self.type == .other,
              let recipientId,
              recipientId != TSAccountManager.sharedInstance().localNumber() else {
            return
        }

        let remarkVC = DTEditContactRemarkViewController(recipientId: recipientId, account: account)
        remarkVC.editDelegate = self

        if let presentingVC = self.presentingViewController {
            presentingVC.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                if let conversationVC = self.findConversationViewController(from: presentingVC) {
                    conversationVC.navigationController?.pushViewController(remarkVC, animated: true)
                } else if let navController = presentingVC as? UINavigationController {
                    navController.pushViewController(remarkVC, animated: true)
                } else if let navController = presentingVC.navigationController {
                    navController.pushViewController(remarkVC, animated: true)
                }
            }
        } else {
            navigationController?.pushViewController(remarkVC, animated: true)
        }
    }
    
    @objc func tapOriginalAvatar(_ tap: UITapGestureRecognizer) {
        guard let smallAvatar = tap.view as? DTAvatarImageView,
              let window = view.window else { return }

        var items = [DTImageViewModel]()
        let item = DTImageViewModel()
        item.thumbView = smallAvatar
        item.image = smallAvatar.image
        item.largeImageSize = CGSize(width: 180, height: 180)
        item.avatar = account.contact?.avatar
        item.receptid = recipientId
        items.append(item)

        photoBrowser = DTImageBrowserView(groupItems: items)
        photoBrowser?.present(fromImageView: smallAvatar, toContainer: window, animated: true, completion: nil)
    }

    func showAvatarBrowserViewAnimate(_ animate: Bool) {
        
        guard let contactsManager = Environment.shared.contactsManager, let recipientId = self.recipientId else {
            return
        }
        var account: SignalAccount?
        databaseStorage.asyncWrite { transaction in
            account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)
            DispatchQueue.main.async {
                var items = [DTImageViewModel]()
                let item = DTImageViewModel()
                if let iconImage = self.iconImage, let window = self.view.window{
                    item.thumbView = iconImage
                    item.image = iconImage.image
                    item.largeImageSize = CGSize(width: 180, height: 180)
                    // 放大查看与头像展示保持同一优先级。
                    item.avatar = account?.contact?.remarkAvatar ?? account?.contact?.avatar
                    item.receptid = self.recipientId
                    items.append(item)
                    self.photoBrowser = DTImageBrowserView(groupItems: items)
                    
                    self.photoBrowser?.present(fromImageView: iconImage, toContainer: window, animated: true) {
                        if self.type == .selfCanEdit {
                            self.avatarViewHelper.showChangeAvatarUI()
                        }
                    }
                }
                
            }
        }
    }
    
    func generateNameAttributedString(_ content: String, image: UIImage?, font: UIFont?) -> NSAttributedString {
        guard let image else {
            return NSAttributedString(string: content)
        }
        let textFont = UIFont(name: "PingFangSC-Medium", size: 20) ?? UIFont.systemFont(ofSize: 20)
        let contentAtt = NSMutableAttributedString(string: content, attributes: [.font: textFont, .foregroundColor: Theme.tprimaryColor])
        let imageMent = NSTextAttachment()
        imageMent.image = image
        let imageAtt = NSAttributedString(attachment: imageMent)
        contentAtt.append(NSAttributedString(string: " ", attributes: [.font: font]))
        contentAtt.append(imageAtt)
        return contentAtt
    }
    
    func convertStringToNumber(_ string: String) -> NSNumber? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.number(from: string)
    }
    
    func isChineseLanguage() -> Bool {
        let languages = NSLocale.preferredLanguages
        let pfLanguageCode = languages[0]
        return pfLanguageCode == "zh-Hant" || pfLanguageCode.hasPrefix("zh-Hant") || pfLanguageCode.hasPrefix("yue-Hant") || pfLanguageCode == "zh-HK" || pfLanguageCode == "zh-TW" || pfLanguageCode == "zh-Hans" || pfLanguageCode.hasPrefix("yue-Hans") || pfLanguageCode.hasPrefix("zh-Hans")
    }
    
    func getResultDate(startDate: Date, timeInterval: TimeInterval) -> Date {
        let resultDate = Date(timeInterval: timeInterval, since: startDate)
        return resultDate
    }
    
    
    func signatureInfoCell(signature: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "UITableViewCellStyleSignatureInfo")
        cell.selectionStyle = .none
        signatureLabel = UILabel()
        guard let signatureLabel = signatureLabel else {
            return UITableViewCell()
        }
        cell.contentView.addSubview(signatureLabel)
        
        cell.backgroundColor = Theme.bg1Color
        cell.contentView.backgroundColor = Theme.bg1Color
        
        let sigAttString = createAttributedString(from: signature, with: 14)
        signatureLabel.attributedText = sigAttString
        signatureLabel.font = UIFont.ows_regularFont(withSize: 14)
        signatureLabel.numberOfLines = 2
        signatureLabel.autoPinLeadingAndTrailingToSuperviewMargin()
        signatureLabel.autoPinEdge(.top, to: .top, of: cell.contentView)
        
        if let thumbsUpEntity = self.account.contact?.thumbsUp, (thumbsUpEntity.thumbsUpCount != 0)  {
            signatureLabel.autoPinEdge(.bottom, to: .bottom, of: cell.contentView, withOffset: -12)
        } else {
            signatureLabel.autoPinEdge(.bottom, to: .bottom, of: cell.contentView, withOffset: -24)
        }
        
        return cell
    }
    
    func createAttributedString(from string: String, with fontSize: Int) -> NSMutableAttributedString? {
        guard !string.isEmpty else { return nil }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: CGFloat(fontSize)),
            .foregroundColor: Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xB7BDC6) : UIColor(rgbHex: 0x707A8A),
            .paragraphStyle: {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 5
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 0
                return paragraphStyle
            }()
        ]

        let attributedString = NSMutableAttributedString(string: string, attributes: attributes)
        return attributedString
    }
    
    func quickActionCell() -> DTQuickActionCell {
        let cell = DTQuickActionCell(style: .default, reuseIdentifier: "UITableViewCellStyleQuickActionCell")
        cell.cellDelegate = self
        cell.backgroundColor = Theme.bgpageSecondaryColor
        cell.contentView.backgroundColor = Theme.bgpageSecondaryColor
        
        cell.haveCall = canCall()
        cell.isFriend = account.isFriend
        cell.setupAllSubViews()
       
        return cell
    }
    
    func canCall() -> Bool {
        if let recipientId = self.recipientId,
            self.type == .other,
           recipientId.count > 6,
           account.isFriend {
            return true
        }
        
        return false
    }
    
    func cornerRadiusCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "UITableViewCellSectionRadiusStyleIdentifier")
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = Theme.bg1Color
        return cell
    }
    
    func sectionHeaderCell(title: String) -> UITableViewCell {
        let sectionHeaderCell = UITableViewCell(style: .default, reuseIdentifier: "UITableViewCellSectionHeaderStyleIdentifier")
        let titleLabel = UILabel()
        sectionHeaderCell.contentView.addSubview(titleLabel)
        titleLabel.autoPinEdge(toSuperviewEdge: .top)
        titleLabel.autoPinEdge(toSuperviewMargin: .leading)
        titleLabel.autoPinEdge(toSuperviewMargin: .trailing)
        titleLabel.autoPinEdge(toSuperviewEdge: .bottom)
        titleLabel.text = title
        titleLabel.font = UIFont(name: "PingFangSC-Medium", size: 16)
        sectionHeaderCell.selectionStyle = .none
        sectionHeaderCell.backgroundColor = Theme.bg1Color
        sectionHeaderCell.contentView.backgroundColor = Theme.bg1Color
        return sectionHeaderCell
    }
    
    func personCardForOther(withTitle title: String, detailText detail: String, detailColor: UIColor? = nil, longPressSel seletor: Selector?, accessoryType: UITableViewCell.AccessoryType, numberOfLines: Int = 1) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "UITableViewCellStyleValue1")
        cell.textLabel?.text = title
        cell.textLabel?.font = UIFont.ows_regularFont(withSize: 14, scaled: false)
        cell.textLabel?.textColor = Theme.tprimaryColor

        cell.backgroundColor = Theme.bg1Color
        cell.contentView.backgroundColor = Theme.bg1Color
        cell.selectionStyle = .none

        let detailTextLabel = UILabel()
        detailTextLabel.font = UIFont.systemFont(ofSize: 14)
        detailTextLabel.textColor = detailColor ?? Theme.tsecondaryColor
        detailTextLabel.text = detail
        detailTextLabel.textAlignment = .left
        detailTextLabel.numberOfLines = numberOfLines
        cell.contentView.addSubview(detailTextLabel)
        detailTextLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 120)
        detailTextLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 25)
        if numberOfLines != 1 {
            detailTextLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
            detailTextLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        } else {
            detailTextLabel.autoVCenterInSuperview()
        }

        if let selector = seletor {
            let longPress = UILongPressGestureRecognizer(target: self, action: selector)
            longPress.minimumPressDuration = 1
            cell.contentView.addGestureRecognizer(longPress)
        }

        cell.detailTextLabel?.textColor = Theme.tsecondaryColor

        if accessoryType == .disclosureIndicator {
            let arrowImageView = UIImageView(image: UIImage(named: "default_accessory_arrow"))
            arrowImageView.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
            cell.accessoryView = arrowImageView
        } else {
            cell.accessoryType = accessoryType
        }

        return cell
    }
    
    @objc func longPressNameClick(_ longPress: UILongPressGestureRecognizer) {
        if let contact = self.account.contact,
           !contact.fullName.isEmpty {
            copyUserInfo(text: contact.fullName)
        }
    }
    
    @objc func longPressEmailClick(_ longPress: UILongPressGestureRecognizer) {
        if let email = TSAccountManager.shared.loadStoredUserEmail() {
            copyUserInfo(text: email)
        }
    }
    
    @objc func longPressPhoneNumberClick(_ longPress: UILongPressGestureRecognizer) {
        if let phoneNumber = TSAccountManager.shared.loadStoredUserPhone() {
            copyUserInfo(text: phoneNumber)
        }
    }
    
    @objc func longPressIDClick(_ longPressGesture: UILongPressGestureRecognizer) {
        if let recipientId {
            let customUid = account.contact?.customUid
            let displayId = NSString.displayUserId(withCustomUid: customUid, recipientId: recipientId)
            copyUserInfo(text: displayId)
        }
    }
    
    func copyUserInfo(text: String) {
        guard !text.isEmpty else {
            return
        }
        DTSecurePasteboard.setString(text)
        DTToastHelper.toast(withText: Localized("COPYID", "copy to pastboard"), durationTime: 2)
    }
    
    func setAvatarImage(_ avatarImage: UIImage) {
        
        self.avatarImage = avatarImage
        uploadAvaterToTheServer {
            self.photoBrowser?.updateCurrentImage(avatarImage)
        }
    }
    
    func liveKitCall() {
        guard !self.isUserDeregistered(), let recipientId else {
            DTToastHelper.showInfo("Account was deregistered!")
            return
        }
        
        if DTMeetingManager.shared.hasMeeting, OWSWindowManager.shared().hasCall() {
            DTMeetingManager.shared.restoreFullScreenView()
            return
        }

        let thread = TSContactThread.getOrCreateThread(contactId: recipientId)
        self.contactThread = thread
        
        if let targetCall = DTMeetingManager.shared.currentThreadTargetCall(thread) {
            if targetCall.isCaller {
                DTMeetingManager.shared.startCall(
                    thread: thread,
                    displayLoading: true
                )
            } else {
                DTMeetingManager.shared.acceptCall(call: targetCall)
            }
        } else {
            DTMeetingManager.shared.startCall(
                thread: thread,
                displayLoading: true
            )
        }
    }
    
    func showDetailAlertViewController(withTitle title: String, detailAttributedString contentString: NSAttributedString, type: DTCardAlertViewType, maxLength: UInt, tag: Int) {
        
        guard let recipientId = self.recipientId else {return}
        let alertViewController = DTCardAlertViewController(recipientId, type: type)
        alertViewController.titleString = title
        alertViewController.attributedContentString = contentString
        if maxLength > 0 {
            alertViewController.maxLength = maxLength
        }
        alertViewController.contentString = contentString.string
        alertViewController.tag = Int32(tag)
        alertViewController.alertDelegate = self
        alertViewController.modalPresentationStyle = .overFullScreen
        self.navigationController?.present(alertViewController, animated: false, completion: nil)
    }
    
    func cardAlert(_ alert: DTCardAlertViewController?, actionType: DTCardAlertActionType, changedText: String?, defaultText: String?) {
        guard actionType != .cancel, changedText != defaultText else { return }
        switch alert?.tag {
        case 10001: // name
            guard let changedText = changedText, !changedText.isEmpty else {
                renameErrorAlertMsg(Localized("RENAME_ERROR_CANNOT_EMPTY", ""))
                
                return
            }
            let parms = ["name": changedText]
            requestForEditPersonInfo(withParams: parms)
            
            
        case 10002: // signature
            
            if let signature = changedText?.trimmingCharacters(in: .whitespacesAndNewlines), !signature.isEmpty {
                let parms : [String : Any] = ["signature": signature]
                requestForEditPersonInfo(withParams: parms)
            }
            
        default:
            break
        }
    }
    
    func requestForEditPersonInfo(withParams parms: [String: Any]) {
        
        DTToastHelper.svShow()
        let request = OWSRequestFactory.putV1Profile(withParams: parms)
        self.networkManager.makeRequest(request, success: { response in
            guard let responseObject = response.responseBodyJson as? [String : Any],
                  DTParamsUtils.validateDictionary(responseObject).boolValue == true else {
                DTToastHelper.dismiss(withInfo: Localized("UPDATENAME_FAILED", ""))
                return
            }
            DTToastHelper.dismiss(withDelay: 0.2)
            guard let statusNumber = responseObject["status"] as? NSNumber else { return }
            let status = statusNumber.intValue
            if status == 0 {
                if let userName = parms["name"] as? String {
                    self.dealPersonInfoNameResponse(withUserName: userName)
                } else if let signature = parms["signature"] as? String {
                    self.dealPersonInfoNameResponse(withSignature: signature)
                }
            } else {
                var errorMsg = Localized("UPDATENAME_FAILED", "")
                switch status {
                case 10100:
                    errorMsg = Localized("RENAME_ERROR_UNSUPPORTED_CHARACTER", "")
                case 10101:
                    errorMsg = Localized("RENAME_ERROR_FORMAT_ERROR", "")
                case 10102:
                    errorMsg = Localized("RENAME_ERROR_TOO_LONG", "")
                case 10103:
                    errorMsg = Localized("RENAME_ERROR_ALREADY_EXISTS", "")
                case 10104:
                    errorMsg = Localized("RENAME_ERROR_INTERN_NO_PERMISSION", "")
                default:
                    break
                }
                if let errorMsg = errorMsg, !errorMsg.isEmpty {
                    self.renameErrorAlertMsg(errorMsg)
                }
            }
        }, failure: { errorWrapper in
            
            let error = errorWrapper.asNSError
            if error.code == 403 {
                DTToastHelper.dismiss(withInfo: Localized("BIM_OPERATION_FORBIDDEN", ""))
            } else {
                DTToastHelper.dismiss(withInfo: Localized("UPDATENAME_FAILED", ""))
            }
        })
    }
    
    func renameErrorAlertMsg(_ msg: String) {
        
        showAlert(.alert, title: Localized("COMMON_NOTICE_TITLE", ""), msg: msg, cancelTitle: nil, confirmTitle: Localized("MESSAGE_ACTION_DELETE_MESSAGE_OK", ""), confirmStyle: .default, confirmHandler: nil)
        
    }
    
    func dealPersonInfoNameResponse(withUserName userName: String) {
        
        guard let recipientId = self.recipientId else {return}
        self.databaseStorage.asyncWrite { transation in
            if let contactsManager = Environment.shared.contactsManager,
               let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transation) {
                
                account.contact?.fullName = userName
                let newAccount = account.copy() as! SignalAccount
                contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transation)
                transation.addAsyncCompletionOnMain {
                    self.updateTableContents()
                    
                }
            }
        }
    }
    
    func dealPersonInfoNameResponse(withSignature signature: String) {
        
        guard let recipientId = self.recipientId else {return}
        self.databaseStorage.asyncWrite { transation in
            
            if let contactsManager = Environment.shared.contactsManager,
               let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transation){
                let newAccount = account.copy() as! SignalAccount
                newAccount.contact = newAccount.contact?.copy() as? Contact
                newAccount.contact?.signature = signature
                contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transation)
            }
        }
        
    }
    
    func formatString(with nameArr: [String], thumbsUpEntity: DTThumbsUpEntity) -> String {
        
        if nameArr.isEmpty {
            return ""
        }
        
        var resultString = ""
        for (index, name) in nameArr.enumerated() {
            resultString += index == 0 ? "\(name)" : (index < nameArr.count - 1 ? ", \(name)" : " and \(name)")
        }
        
        var formatString = ""
        if thumbsUpEntity.thumbsUpCount > 3 {
            
            let nameArrCount = nameArr.count
            let string = String(format: Localized("PERSON_CARD_LIKES_MORE"), Int(thumbsUpEntity.thumbsUpCount) - nameArrCount)
            formatString = "\(resultString), \(string)"
            
        } else {
            
            formatString = resultString
            
        }
        
        return formatString
    }
    
}

extension DTPersonalCardController : AvatarViewHelperDelegate {
    func avatarActionSheetTitle() -> String {
        return Localized("PROFILE_VIEW_AVATAR_ACTIONSHEET_TITLE", comment: "Action Sheet title prompting the user for a profile avatar")
    }
    
    func fromViewController() -> UIViewController {
        return self
    }
    
    func hasClearAvatarAction() -> Bool {
        return false
    }
    
    func avatarDidChange(_ image: UIImage) {
     let avatarImage_t = image.resizedImage(toFillPixelSize: CGSize(width: Float64(kOWSProfileManager_MaxAvatarDiameter), height: Float64(kOWSProfileManager_MaxAvatarDiameter)))
        self.setAvatarImage(avatarImage_t)
    }
    
    var clearAvatarActionLabel: String {
        return Localized("PROFILE_VIEW_CLEAR_AVATAR", comment: "Label for action that clear's the user's profile avatar")
    }
    
    func clearAvatar() {
        avatarImage = nil
    }
}

extension DTPersonalCardController : DTQuickActionCellDelegate {
    func quickActionCell(_ cell: DTQuickActionCell, button sender: DTLayoutButton, actionType type: DTQuickActionType) {
        
        handleQuickAction(type)
    }
    
    func topViewController() -> UIViewController? {
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootVC = window.rootViewController
        else { return nil }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    
    func dismissIfNeeded(_ completion: @escaping () -> Void) {
        if let presenting = presentingViewController {
            presenting.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
    
    func pushConversation(thread: TSThread) {
        let conversationVC = ConversationViewController(thread: thread, action: .none)

        // 优先使用当前的 navigationController（处理从通讯录push进来的情况）
        if let nav = self.navigationController {
            nav.pushViewController(conversationVC, animated: true)
            return
        }

        // 如果没有 navigationController，使用 topViewController（处理modal present的情况）
        guard let topVC = topViewController() else { return }

        if let nav = topVC as? UINavigationController {
            nav.pushViewController(conversationVC, animated: true)
        } else if let nav = topVC.navigationController {
            nav.pushViewController(conversationVC, animated: true)
        }
    }
    
    func showFloatingConversation(thread: TSThread, config: FloatingConversationConfiguration) {
        topViewController()?.showFloatingConversation(
            with: thread,
            configuration: config
        )
    }
    
    func handleQuickAction(_ type: DTQuickActionType) {
        switch type {

        case DTQuickActionTypeShare:
            account.isFriend ? showSelectThreadController() : handleMessageAction()

        case DTQuickActionTypeCall:
            if canCall() {
                liveKitCall()
            }

        case DTQuickActionTypeMessage:
            handleMessageAction()

        default:
            break
        }
    }
    
    private func handleMessageAction() {
        DispatchQueue.main.async {

            // 同 thread 且是 modal 进来的，直接 dismiss 并弹出键盘
            if self.isFromSameThread, self.presentingViewController != nil {
                // 在 dismiss 之前保存 presentingViewController 的引用
                let presentingVC = self.presentingViewController

                self.navigationController?.dismiss(animated: true) { [weak self] in
                    // Dismiss 完成后，找到底层的 ConversationViewController 并弹出键盘
                    self?.showKeyboardInUnderlyingConversation(presentingVC: presentingVC)
                }
                return
            }

            guard let recipientId = self.recipientId else { return }

            if !self.account.isFriend {
                AddFriendHandler.handleRequestAddFriend(identifier: recipientId,
                                                        sourceType: .inUserCard,
                                                        sourceConversationID: nil,
                                                        shareContactCardUId: nil,
                                                        action: nil)
            }

            let thread = TSContactThread.getOrCreateThread(contactId: recipientId)
            self.contactThread = thread

            if self.isFromContacts {
                self.handleContactConversation(thread: thread)
            } else {
                self.handleFloatingConversation(thread: thread)
            }
        }
    }

    private func showKeyboardInUnderlyingConversation(presentingVC: UIViewController?) {
        // 使用传入的 presentingViewController
        guard let presentingVC = presentingVC else { return }

        // 递归查找 ConversationViewController
        if let conversationVC = findConversationViewController(from: presentingVC) {
            // 延迟一下确保 dismiss 动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                conversationVC.popKeyBoard()
            }
        }
    }

    private func findConversationViewController(from viewController: UIViewController) -> ConversationViewController? {
        // 如果当前就是 ConversationViewController，直接返回
        if let conversationVC = viewController as? ConversationViewController {
            return conversationVC
        }

        // 如果是 UINavigationController，查找其 topViewController
        if let navController = viewController as? UINavigationController {
            return findConversationViewController(from: navController.topViewController ?? navController)
        }

        // 如果是 UITabBarController，查找其 selectedViewController
        if let tabBarController = viewController as? UITabBarController,
           let selectedVC = tabBarController.selectedViewController {
            return findConversationViewController(from: selectedVC)
        }

        // 如果有 presentedViewController，也尝试查找
        if let presentedVC = viewController.presentedViewController {
            if let result = findConversationViewController(from: presentedVC) {
                return result
            }
        }

        // 遍历 childViewControllers
        for child in viewController.children {
            if let result = findConversationViewController(from: child) {
                return result
            }
        }

        return nil
    }
    
    private func handleContactConversation(thread: TSThread) {
        dismissIfNeeded {
            self.pushConversation(thread: thread)
        }
    }
    
    private func handleFloatingConversation(thread: TSThread) {

        let config = FloatingConversationConfiguration(
            compactHeightRatio: 0.55,
            expandedHeightRatio: 0.9,
            transitionStyle: .present,
            showDragIndicator: true,
            dimViewAlpha: 0.7,
            dismissOnDimViewTap: true,
            enablePullToDismiss: true,
            pullToDismissThreshold: 0.3,
            cornerRadius: 16,
            heightAnimationDuration: 0.3,
            showFullscreenButton: true
        )

        let isFromLongMessage = presentingViewController is LongMessageViewController

        if isFromLongMessage,
           let longMessagePresenting = presentingViewController?.presentingViewController {

            longMessagePresenting.dismiss(animated: true) {
                self.showFloatingConversation(thread: thread, config: config)
            }
            return
        }

        dismissIfNeeded {
            self.showFloatingConversation(thread: thread, config: config)
        }
    }
    
    func appendUIDParameter(toURL urlString: String, uid: String) -> String? {
        guard let encodedUID = uid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        let separator = urlString.contains("?") ? "&" : "?"
        return urlString + separator + "uid=\(encodedUID)"
    }
}

extension DTPersonalCardController : PanModalPresentable {
    
    var panScrollable: UIScrollView? {
        return tableView
    }
}

extension DTPersonalCardController : OWSNavigationChildController {
    
    public var navbarBackgroundColorOverride: UIColor? { Theme.bgpageSecondaryColor }

    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }

    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool {
        return false
    }

    public var shouldCancelNavigationBack: Bool { false }
}

extension DTPersonalCardController: DTEditContactRemarkViewControllerDelegate {

    public func editContactRemarkDidFinish() {
        reloadAccountFromDB()
    }
}
