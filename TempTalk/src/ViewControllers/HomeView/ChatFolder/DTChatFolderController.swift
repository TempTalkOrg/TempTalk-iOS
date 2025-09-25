//
//  DTChatFolderController.swift
//  Wea
//
//  Created by Ethan on 2022/4/14.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import SVProgressHUD
import TTMessaging

@objcMembers
class DTChatFolderController: OWSTableViewController {

    var selectedThread: TSThread? //this thead ready to add to a folder
    private var isForSelect: Bool {
        return selectedThread != nil
    }
                
    var isEditMode = false
    
    var chatFolders: [DTChatFolderEntity]!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadLatestChatFolders()
        updateContents()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = Localized(!isForSelect ? "CHAT_FOLDER_VC_TITLE" : "CHAT_FOLDER_VC_SELECT_TITLE", comment: "Chat Folders")
        if isForSelect {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(backItemAction))
        }
            
        delegate = self
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
    }
    
    func editItemAction() {
        if tableView.isEditing {
            tableView.isEditing = false
            return
        }
        leftEdgePanGestureDisabled(true)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneItemAction))
        isEditMode = true
        tableView.setEditing(true, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateContents()
        }
    }
    
    func stopItemAction() {
        leftEdgePanGestureDisabled(false)

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editItemAction))
        isEditMode = false
        tableView.setEditing(false, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateContents()
        }
    }
    
    func doneItemAction() {
        
        if self.chatFolders.isEmpty {
            return
        }
        
        stopItemAction()
        SVProgressHUD.show()
        DTChatFolderManager.saveChatFolders(chatFolders) {
            SVProgressHUD.showSuccess(withStatus: Localized("CHAT_FOLDER_SAVE_SUCCESS_TIP", comment: ""))
        } failure: { error in
            SVProgressHUD.showError(withStatus: Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: ""))
        }
    }
    
    func backItemAction() {
        navigationController?.dismiss(animated: true)
    }
    
    func loadLatestChatFolders() {
        chatFolders = {
            var copyFolders = [DTChatFolderEntity]()
            DTChatFolderManager.shared().chatFolders.forEach { folder in
                let copyFolder = folder.copy()
                copyFolders.append(copyFolder as! DTChatFolderEntity)
            }
            return copyFolders
        }()
        
        if !chatFolders.isEmpty && !isForSelect {
            if isEditMode {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneItemAction))
            } else {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editItemAction))
            }
        }
    }
    
    func updateContents() {
        
        let threadCounts = folderThreadCounts()
        
        let contents = OWSTableContents()
            
        let folderSection = OWSTableSection()
        folderSection.customHeaderView = customHeaderView(title: Localized("CHAT_FOLDER_MINE_TITLE", comment: ""))
        folderSection.customHeaderHeight = NSNumber(value: 44)
        if isEditMode {
            folderSection.footerTitle = Localized("CHAT_FOLDER_CHANGER_ORDER_TIPS", comment: "")
            folderSection.customFooterHeight = NSNumber(value: 44)
        }
        
        var folderNames = [String]()
        var containsVega = false
        for (index, chatFolder) in chatFolders.enumerated() {
            //添加到folderNames的folder不会在recommend里展示，custom vega 不应加入， custom vega 和 recommend 可以同时存在
            if excludeCustomVega(chatFolder: chatFolder) {
                folderNames.append(chatFolder.name)
            }
            if chatFolder.name == kChatFolderVegaKey {
                containsVega = true
            }
            if isForSelect && DTChatFolderManager.recommendKeys().contains(chatFolder.name) && excludeCustomVega(chatFolder: chatFolder) {
                //会话左滑动添加到folder，需要支持custom vega，custom vega 需要展示
                continue
            }
            let item = OWSTableItem(customCellBlock: { [weak self] in
                guard let self else {
                    return UITableViewCell()
                }
                let title = chatFolder.displayName
                let lbTitle = self.lbTitle(title: title)
                let lbsubTitle = self.lbsubTitle(title: chatFolder.excludeFromAll ? "(Hidden from All)" : "")
                let lbThreadCount = self.lbThreadCount(threadCounts[index])
                let cell = DTChatFolderCell(iconName: "ic_chat_folder_title", subviews: [lbTitle, lbsubTitle, lbThreadCount], separatorNeed: true)
                if self.isForSelect {
                    lbThreadCount.isHidden = true
                    guard let selectedThread = self.selectedThread else {
                        return cell
                    }
                    
                    var result = false
                    self.databaseStorage.read { transaction in
                        result = chatFolder.isContain(selectedThread, transaction: transaction)
                    }
                    cell.accessoryType = result == true ? .checkmark : .none
                } else {
                    cell.accessoryView = self.isEditMode || chatFolder.folderType == .custom ? DTChatFolderCell.accessoryArrow() : nil
                    lbThreadCount.isHidden = self.isEditMode
                }
                return cell
            }, customRowHeight: 50) { [weak self] in
                guard let self else { return }
                if DTChatFolderManager.recommendKeys().contains(chatFolder.name) && !self.tableView.isEditing && self.excludeCustomVega(chatFolder: chatFolder) {
                    SVProgressHUD.showInfo(withStatus: Localized("CHAT_FOLDER_NOT_ALLOW_EDIT", comment: ""))
                    return
                }
                if self.isForSelect {
                    guard let selectedThread = self.selectedThread else {
                        return
                    }
                    
                    var canAdd = false
                    var canRemove = false
                    self.databaseStorage.read { transaction in
                        canAdd = !chatFolder.isManualContain(selectedThread) && !chatFolder.isConditonsContain(selectedThread, transaction: transaction)
                        canRemove = chatFolder.isManualContain(selectedThread) && !chatFolder.isConditonsContain(selectedThread, transaction: transaction)
                    }
                    
                    if !canAdd && !canRemove {
                        return
                    }
                    
                    var notice = ""
                    var isAdd = false
                    if canAdd {
                        notice = Localized("CHAT_FOLDER_ADD_TO_FOLDER_TIP", comment: "")
                        isAdd = true
                    } else if canRemove {
                        notice = Localized("CHAT_FOLDER_REMOVE_FROM_FOLDER_TIP", comment: "")
                        isAdd = false
                    }
                    self.showAlert(.alert, title:Localized("COMMON_NOTICE_TITLE", comment: ""), msg: notice, cancelTitle: Localized("TXT_CANCEL_TITLE", comment: ""), confirmTitle: Localized("TXT_CONFIRM_TITLE", comment: ""), confirmStyle: .default) {
                        self.updateChatFolder(index, isAdd: isAdd)
                    }
                } else {
                    if self.isEditMode {
                        return
                    }
                    let editFolderVC = DTCreateFolderController()
                    editFolderVC.shouldUseTheme = true
                    editFolderVC.mode = .edit
                    editFolderVC.currentIndex = index
                    self.navigationController?.pushViewController(editFolderVC, animated: true)
                }
            }
            item.canEdit = !isForSelect
            item.canMove = !isForSelect
            folderSection.add(item)
        }
        contents.addSection(folderSection)
        
        if !isForSelect && DTChatFolderManager.leftCount() > 0 {
            
            let addSection = OWSTableSection()
            if self.chatFolders.isEmpty {
                addSection.footerTitle = Localized("CHAT_FOLDER_ADD_FOLDER_TIPS", comment: "")
            }
            let addItem = OWSTableItem(customCellBlock: {
                let cell = DTChatFolderCell(title: Localized("CHAT_FOLDER_ADD_FOLDER", comment: ""), iconName: "ic_circled_plus", separatorNeed: false, tintColor: .ows_materialBlue)
                cell.accessoryView = DTChatFolderCell.accessoryArrow(tintColor: .ows_materialBlue)
                
                return cell
            }, customRowHeight: 50) { [weak self] in
                guard let self else { return }
                let createFolderVC = DTCreateFolderController()
                createFolderVC.shouldUseTheme = true
                self.navigationController?.pushViewController(createFolderVC, animated: true)
            }
            addSection.add(addItem)
            
            let blackCell = OWSTableItem.blankItemWithcustomRowHeight(5, backgroundColor: Theme.backgroundColor)
            addSection.add(blackCell)
            
            contents.addSection(addSection)
        }
        
        if !isForSelect {
            let recommendSection = OWSTableSection()
            recommendSection.customHeaderView = customHeaderView(title: Localized("CHAT_FOLDER_RECOMMEND_TITLE", comment: ""))
            recommendSection.customHeaderHeight = NSNumber(value: 44)
            let remainTitles = DTChatFolderManager.recommendKeys().filter { !folderNames.contains($0) }
//            if !remainTitles.isEmpty {
                remainTitles.forEach { title in
                    let item = OWSTableItem(customCellBlock: {
                        var displayName: String = ""
                        if title == kChatFolderPrivateKey {
                            displayName = Localized("CHAT_FOLDER_RECOMMEDN_PRIVATE", comment: "")
                        } else if title == kChatFolderUnreadKey {
                            displayName = Localized("CHAT_FOLDER_RECOMMEDN_UNREAD", comment: "")
                        } else if title == kChatFolderAtMeKey {
                            displayName = Localized("CHAT_FOLDER_RECOMMEDN_ATME", comment: "")
                        } else if title == kChatFolderVegaKey {
                            displayName = "Vega";
                        }
                        return DTChatFolderCell(title: displayName, iconName: "ic_circled_plus", separatorNeed: true, tintColor: UIColor.ows_materialBlue)
                    }, customRowHeight: 50) {[weak self] in
                        guard let self else { return }
                        if folderNames.contains(title) || (title == kChatFolderVegaKey && containsVega) {
                            SVProgressHUD.showInfo(withStatus: Localized("CHAT_FOLDER_ADD_RECOMMEND_EXIST_NAME_TIPS", comment: ""))
                            return
                        }
                        
                        if title == kChatFolderVegaKey {
                            let actionSheetContrl = ActionSheetController.init(title: nil, message: Localized("CHAT_FOLDER_EXCLUDE_FROM_ALL_TITLE", comment: ""))
                            let cancelAction = ActionSheetAction.init(title: Localized("CHAT_FOLDER_EXCLUDE_FROM_ALL_CANCEL", comment: ""), style: .default) { action in
                                self.updateRecommendFolder(title: title, excludeFromAll: false)
                            }
                            actionSheetContrl.addAction(cancelAction)
                            let confirmAction = ActionSheetAction.init(title: Localized("CHAT_FOLDER_EXCLUDE_FROM_ALL_CONFIRM", comment: ""), style: .destructive) { action in
                                self.updateRecommendFolder(title: title, excludeFromAll: true)
                            }
                            actionSheetContrl.addAction(confirmAction)
                            self.presentActionSheet(actionSheetContrl)
                            return
                        }
                        self.updateRecommendFolder(title: title, excludeFromAll: false)
                    }
                    recommendSection.add(item)
                }
            contents.addSection(recommendSection)
//            }
        }
        self.contents = contents
    }
    
    //过滤掉custom vega
    func excludeCustomVega(chatFolder: DTChatFolderEntity) -> Bool {
        return chatFolder.name != kChatFolderVegaKey || chatFolder.folderType == .recommend
    }
    
    func updateRecommendFolder(title: String, excludeFromAll: Bool) {
        
        SVProgressHUD.show()
        
        let recommendFolder = DTChatFolderEntity()
        recommendFolder.folderType = .recommend
        recommendFolder.name = title
        recommendFolder.cIds = []
        recommendFolder.conditions = nil
        recommendFolder.excludeFromAll = excludeFromAll
        
        self.chatFolders.insert(recommendFolder, at: 0)
        DTChatFolderManager.saveChatFolders(self.chatFolders) {
            SVProgressHUD.dismiss()
            self.loadLatestChatFolders()
            self.updateContents()
        } failure: { error in
            SVProgressHUD.showError(withStatus: Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: ""))
        }
    }
    
    func updateChatFolder(_ index: Int, isAdd: Bool) {
        let chatFolder = chatFolders[index]
        var cIds = chatFolder.cIds
        var hasKeywords = false
        if let conditions = chatFolder.conditions, let keywords = conditions.keywords {
            hasKeywords = !keywords.isEmpty
        }
        if !isAdd && chatFolder.cIds.count == 1 && !hasKeywords {
            SVProgressHUD.showInfo(withStatus: Localized("CHAT_FOLDER_REMOVE_LAST_TIP", comment: ""))
            return
        }

        guard let selectedThread = selectedThread else { return }
        guard let threadEntity = DTFolderThreadEntity(thread: selectedThread) else {
            SVProgressHUD.showError(withStatus: Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: ""))
            return
        }
        if isAdd {
            cIds.append(threadEntity)
        } else {
            cIds.removeAll {
                $0.id == selectedThread.serverThreadId
            }
        }
        chatFolder.cIds = cIds
        chatFolders.replaceSubrange(index...index, with: [chatFolder])
        
        SVProgressHUD.show()
        DTChatFolderManager.saveChatFolders(chatFolders) {
            DispatchMainThreadSafe {
                self.updateContents()
                SVProgressHUD.showSuccess(withStatus: Localized("CHAT_FOLDER_SAVE_SUCCESS_TIP", comment: ""))
                SVProgressHUD.dismiss(withDelay: 1) {
                    self.navigationController?.dismiss(animated: true)
                }
            }
        } failure: { error in
            SVProgressHUD.showError(withStatus: Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: ""))
        }
    }
    
    override func applyTheme() {
        super.applyTheme()
        updateContents()
    }
    
    func lbTitle(title: String) -> UILabel {
        let lbTitle = UILabel()
        lbTitle.text = title
        lbTitle.textColor = Theme.primaryTextColor
        lbTitle.font = .ows_dynamicTypeBody
        lbTitle.lineBreakMode = .byTruncatingTail
        lbTitle.setContentHuggingHigh()
        lbTitle.setCompressionResistanceHigh()
        
        return lbTitle
    }
    
    func lbsubTitle(title: String) -> UILabel {
        let lbsubTitle = UILabel()
        lbsubTitle.text = title
        lbsubTitle.textColor = Theme.middleGrayColor
        lbsubTitle.font = .ows_dynamicTypeBody2
        lbsubTitle.lineBreakMode = .byTruncatingTail
        lbsubTitle.setContentHuggingLow()
        lbsubTitle.setCompressionResistanceHigh()
        
        return lbsubTitle
    }
    
    func lbThreadCount(_ count: Int) -> UILabel {
        let lb = UILabel()
        lb.text = "\(count)"
        lb.textColor = Theme.primaryTextColor
        lb.setContentHuggingHigh()
        lb.setCompressionResistanceHigh()
        
        return lb
    }
    
    func folderThreadCounts() ->[Int] {
        var tmpCounts = [Int]()
        databaseStorage.read { transaction in
            self.chatFolders.forEach { folder in
                let count = folder.numberOfThreads(with: transaction)
                tmpCounts.append(count)
            }
        }
        
        return tmpCounts
    }
        
}

extension DTChatFolderController: OWSTableViewControllerDelegate {
    
    func _tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let targetFolder = self.chatFolders[indexPath.row]
        let isRecommend = DTChatFolderManager.recommendKeys().contains(targetFolder.name)
        let actionTitle = isRecommend ? Localized("CHAT_FOLDER_ITEM_REMOVE", comment: "") : Localized("TXT_DELETE_TITLE", comment: "")
        let actionSheetMsg = isRecommend ? Localized("CHAT_FOLDER_REMOVE_TIP", comment: "") : Localized("CHAT_FOLDER_DELETE_TIP", comment: "")

        let removeAction = UIContextualAction(style: .destructive, title: actionTitle) { (_, _, completionHandler) in
            
            let actionSheet = ActionSheetController(title: nil, message: actionSheetMsg)
            actionSheet.addAction(OWSActionSheets.cancelAction)
            let sureAction = ActionSheetAction(title: Localized("TXT_CONFIRM_TITLE", comment: ""), style: .destructive) { [weak self] _ in
                guard let self else {
                    return
                }
                self.chatFolders.remove(at: indexPath.row)
                SVProgressHUD.show()
                DTChatFolderManager.saveChatFolders(self.chatFolders) {
                    self.updateContents()
                    if self.chatFolders.isEmpty {
                        self.stopItemAction()
                    }
                    SVProgressHUD.showSuccess(withStatus: Localized("CHAT_FOLDER_UPDATE_SUCCESS_TIP", comment: ""))
                } failure: { error in
                    if indexPath.row < self.chatFolders.count {
                        self.chatFolders.insert(targetFolder, at: indexPath.row)
                    } else if indexPath.row == self.chatFolders.count {
                        self.chatFolders.append(targetFolder)
                    }
                    SVProgressHUD.showError(withStatus: Localized("CHAT_FOLDER_UPDATE_FAILED_TIP", comment: ""))
                }
            }
            actionSheet.addAction(sureAction)
            self.presentActionSheet(actionSheet)
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    
    func originalTableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let targetFolder = chatFolders[sourceIndexPath.row]
        chatFolders.remove(at: sourceIndexPath.row)
        chatFolders.insert(targetFolder, at: destinationIndexPath.row)
        updateContents()
    }
    
    func customHeaderView(title: String) -> UIView {
        let headerView = UIView()
        let lbTitle = UILabel()
        lbTitle.text = title
        lbTitle.font = .systemFont(ofSize: 20, weight: .medium)
        lbTitle.textColor = Theme.primaryTextColor
        headerView.addSubview(lbTitle)
        lbTitle.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        
        return headerView
    }
}


let DTChatFolderNormalCellID = "DTChatFolderNormalCellID"
let DTChatFolderManagerpecialCellID = "DTChatFolderManagerpecialCellID"
let DTGroupOwnerCellID = "DTGroupOwnerCellID"

class DTChatFolderCell: UITableViewCell {
    
    let contactsManager = Environment.shared.contactsManager
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        preservesSuperviewLayoutMargins = true
        contentView.preservesSuperviewLayoutMargins = true
        backgroundColor = Theme.backgroundColor
        contentView.backgroundColor = Theme.backgroundColor
    }
    
    public convenience init(title: String, iconName: String, separatorNeed: Bool, tintColor: UIColor = Theme.secondaryTextAndIconColor) {
        self.init(style: .default, reuseIdentifier: DTChatFolderNormalCellID)
        addArrangedSubviews([iconView(iconName: iconName, tintColor: tintColor), lbTitle(title: title, textColor: tintColor)])
        if separatorNeed {
          createSeparator()
        }
    }
    
    public convenience init(iconName: String?, subviews: [UIView], separatorNeed: Bool = false) {
        self.init(style: .default, reuseIdentifier: DTChatFolderManagerpecialCellID)
        var arrangeSubviews = subviews
        if separatorNeed {
          createSeparator()
        }
        guard let iconName = iconName else {
            addArrangedSubviews(arrangeSubviews)
            return
        }
        arrangeSubviews.insert(iconView(iconName: iconName), at: 0)
        addArrangedSubviews(arrangeSubviews)
    }
    
    public convenience init(groupOwnerId: String) {
        self.init(style: .default, reuseIdentifier: DTGroupOwnerCellID)
        createSeparator()
        
        let avatar = DTAvatarImageView()
        avatar.autoSetDimensions(to: CGSize(width: 24, height: 24))
        guard let contactsManager = contactsManager, let signalAccount = contactsManager.signalAccount(forRecipientId: groupOwnerId), let contact = signalAccount.contact else {
            return
        }
        if let avatar_ = contact.avatar as? [String : Any] {
            avatar.setImage(avatar: avatar_, recipientId: groupOwnerId, displayName: signalAccount.contactFullName(), completion: nil)
        }
        let displayName = contactsManager.displayName(forPhoneIdentifier: groupOwnerId)
        let lbName = lbTitle(title: displayName)
        
        addArrangedSubviews([avatar, lbName])
    }
    
    func addArrangedSubviews(_ arrangedSubviews: [UIView]) {
        
        let contentRow = UIStackView(arrangedSubviews: arrangedSubviews)
        contentRow.spacing = 12
        contentRow.alignment = .center
        contentView.addSubview(contentRow)
        contentRow.autoCenterInSuperview()
        contentRow.autoSetDimension(.height, toSize: 44)
        contentRow.autoPinEdge(toSuperviewMargin: .leading)
        contentRow.autoPinEdge(toSuperviewMargin: .trailing)
    }
    
    func lbTitle(title: String, textColor: UIColor = Theme.primaryTextColor) -> UILabel {
        let lbTitle = UILabel()
        lbTitle.text = title
        lbTitle.textColor = textColor
        lbTitle.font = .ows_dynamicTypeBody
        lbTitle.lineBreakMode = .byTruncatingTail
        
        return lbTitle
    }
    
    func iconView(iconName: String, tintColor: UIColor = Theme.secondaryTextAndIconColor) -> UIImageView {
        let iconView = UIImageView()
        iconView.contentMode = .center
        iconView.image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = tintColor
        iconView.layer.minificationFilter = .trilinear
        iconView.layer.magnificationFilter = .trilinear
        iconView.autoSetDimensions(to: CGSize(width: 24, height: 24))
        
        return iconView
    }
    
    func createSeparator() {
        let customSeparator = UIView()
        customSeparator.backgroundColor = Theme.cellSeparatorColor
        contentView.addSubview(customSeparator)
        customSeparator.autoSetDimension(.height, toSize: 1/UIScreen.main.scale)
        customSeparator.autoPinEdge(toSuperviewEdge: .leading, withInset:20)
        customSeparator.autoPinEdge(toSuperviewEdge: .trailing, withInset:-44)
        customSeparator.autoPinEdge(toSuperviewEdge: .bottom)
    }
    
    class func accessoryArrow(tintColor: UIColor = Theme.secondaryTextAndIconColor) -> UIImageView {
        let arrowImage = UIImage(named: CurrentAppContext().isRTL ? "NavBarBack" : "NavBarBackRTL")?.withRenderingMode(.alwaysTemplate)
        let arrow = UIImageView(image: arrowImage)
        arrow.tintColor = tintColor
        arrow.contentMode = .center
        arrow.setContentHuggingHigh()
        arrow.setCompressionResistanceHigh()
        
        return arrow
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.subviews.forEach {
            $0.removeFromSuperview()
        }
    }
}
