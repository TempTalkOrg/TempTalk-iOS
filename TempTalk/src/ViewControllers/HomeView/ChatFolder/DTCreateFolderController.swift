//
//  DTCreateFolderController.swift
//  Wea
//
//  Created by Ethan on 2022/4/16.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import SVProgressHUD
import TTServiceKit

@objcMembers
class DTCreateFolderController: OWSTableViewController {
    
    @objc enum FolderEditMode: Int {
        case create, edit
    }
    
    let DTFolderNameMaxKenght = 12
    let keywordsMinLength = 2
    let KeywordsMaxLength = 64
    let maxGroupOwnerCount = 5
    
    ///禁止的folder name
    let forbiddenNames = {
        return ["私聊", "Private" , "未读", "Unread", "@我", "@Me", kChatFolderVegaKey]
    }
    
    var mode = FolderEditMode.create
    
    @objc var currentIndex: Int = 0
        
    private var currentFolder = DTChatFolderEntity()
    private var origionFolder: DTChatFolderEntity!
    
    var tfFolderName: UITextField!
    var tfKeywords: UITextField!
    
    let tfFolderNameTag = 100
    let tfKeywordsTag = 101

    var selectedThreads = [TSThread]()
    
    var isSelectGroupOwner = false
            
    override func viewDidLoad() {
        super.viewDidLoad()
        switch mode {
        case .create:
            navigationItem.title =  Localized("CHAT_FOLDER_CREATE_FOLDER", comment: "")
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: Localized("LIGHT_TASK_CREATE_BUTTON_TITLE", comment: ""), style: .plain, target: self, action: #selector(saveItemAction))
            navigationItem.rightBarButtonItem?.isEnabled = false
            currentFolder.folderType = .custom
            self.updateContents()
            break
        case .edit:
            navigationItem.title =  Localized("CHAT_FOLDER_EDIT_FOLDER", comment: "")
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveItemAction))
            
            origionFolder = DTChatFolderManager.shared().chatFolders[safe: currentIndex]!
            currentFolder.folderType = origionFolder.folderType
            currentFolder.name = origionFolder.name
            currentFolder.sortIndex = origionFolder.sortIndex
            currentFolder.cIds = origionFolder.cIds.copy
            let conditions = DTFolderConditions()!
            conditions.keywords = origionFolder.conditions?.keywords
            conditions.groupOwners = origionFolder.conditions?.groupOwners
            currentFolder.conditions = conditions
            
            databaseStorage.asyncRead { transaction in
                self.origionFolder.cIds.forEach { threadEntity in
                    if let thread = DTChatFolderManager.getThreadWithThreadId(threadEntity.id, transaction: transaction){
                        self.selectedThreads.append(thread)
                    }
                }
            } completion: {
                self.updateContents()
            }
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
        
        delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Theme.backgroundColor
        autoPinView(toBottomOfViewControllerOrKeyboard: tableView, avoidNotch: true)
    }
    
    func updateContents() {
        
        let contents = OWSTableContents()
        
        let inputSection = OWSTableSection()
        inputSection.customHeaderView = customHeaderView(title: Localized("CHAT_FOLDER_FOLDER_NAME", comment: ""))
        inputSection.customHeaderHeight = NSNumber(value: 44)
        let tfFolderName = textField(placeholder: Localized("CHAT_FOLDER_FOLDER_NAME", comment: "folder name"), leftIconName: nil)
        tfFolderName.text = currentFolder.name
        tfFolderName.tag = tfFolderNameTag
        tfFolderName.delegate = self
        tfFolderName.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        self.tfFolderName = tfFolderName
        let inputItem = OWSTableItem(customCellBlock: {
            return DTChatFolderCell(iconName: nil, subviews: [tfFolderName])//"ic_chat_folder_title"
        }, customRowHeight: 50) {
            return
        }
        inputSection.add(inputItem)
        
        let blackCell = OWSTableItem.blankItemWithcustomRowHeight(10, backgroundColor: Theme.backgroundColor)
        inputSection.add(blackCell)

        contents.addSection(inputSection)
        
        let addChatsSection = OWSTableSection()
        addChatsSection.customHeaderView = customHeaderView(title: Localized("CHAT_FOLDER_INCLUDED_CHATS", comment: ""))
        addChatsSection.customHeaderHeight = NSNumber(value: 44)
        addChatsSection.footerTitle = Localized("CHAT_FOLDER_ADD_CHATS_TIPS", comment: "")

        let chatsItem = OWSTableItem(customCellBlock: {
            let cell = DTChatFolderCell(title:Localized("CHAT_FOLDER_ADD_CHATS", comment: "add chats"), iconName: "ic_circled_plus", separatorNeed: false, tintColor: .ows_materialBlue)
            cell.accessoryView = DTChatFolderCell.accessoryArrow()
            return cell
        }, customRowHeight: 50) { [weak self] in
            guard let self else { return }
            self.isSelectGroupOwner = false
            let selectThreadVC = SelectThreadViewController()
            selectThreadVC.selectThreadViewDelegate = self
            selectThreadVC.maxSelectCount = 50
            selectThreadVC.isDefaultMultiSelect = true
            selectThreadVC.existingThreadIds = self.ignoreThreadIds()
            let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
            self.present(selectThreadNav, animated: true)
        }
        addChatsSection.add(chatsItem)
        contents.addSection(addChatsSection)

        if !selectedThreads.isEmpty {
            let threadsSection = OWSTableSection()
            for (_, thd) in selectedThreads.enumerated() {

                let threadItem = OWSTableItem(customCellBlock: {
                    
                    let cell = ContactTableViewCell()
                    cell.tintColor = .ows_materialBlue
                    cell.configure(with: thd, contactsManager:Environment.shared.contactsManager)

                    return cell
                }, customRowHeight:70)
                threadItem.canEdit = true
                threadsSection.add(threadItem)
            }
            
            let blackCell1 = OWSTableItem.blankItemWithcustomRowHeight(10, backgroundColor: Theme.backgroundColor)
            threadsSection.add(blackCell1)

            contents.addSection(threadsSection)
        }

        let addKeywordsSection = OWSTableSection()
        addKeywordsSection.customHeaderView = customHeaderView(title:Localized("CHAT_FOLDER_INCLUDED_CONDITIONS", comment: ""))
        addKeywordsSection.customHeaderHeight = NSNumber(value: 44)
//        addKeywordsSection.footerTitle = "Choose chats with these conditions will appear in this folder"
        let lbKeywords = UILabel()
        lbKeywords.text = Localized("CHAT_FOLDER_KEYWORDS", comment: "")
        lbKeywords.font = .systemFont(ofSize: 17, weight: .medium)
        lbKeywords.textColor = Theme.primaryTextColor
        lbKeywords.setContentHuggingHigh()
        
        let keywordsPlaceholder = String(format: Localized("CHAT_FOLDER_ADD_CONDITIONS_PLACEHOLDER", comment: ""), keywordsMinLength, KeywordsMaxLength)
        let tfKeywords = textField(placeholder: keywordsPlaceholder, leftIconName: nil)
        tfKeywords.tag = tfKeywordsTag
        tfKeywords.delegate = self
        
        tfKeywords.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        self.tfKeywords = tfKeywords
        
        let keywordsItem = OWSTableItem(customCellBlock: { [weak self] in
            guard let self else {
                return UITableViewCell()
            }
            if let conditions = self.currentFolder.conditions, let keywords = conditions.keywords {
                tfKeywords.text = keywords
            }
            let cell = DTChatFolderCell(iconName: nil, subviews: [lbKeywords, tfKeywords])
            return cell
        }, customRowHeight: 50)
        addKeywordsSection.add(keywordsItem)
        contents.addSection(addKeywordsSection)
        
        let addGroupOwnersSection = OWSTableSection()
        var groupOwnerIds = [String]()
        if let conditions = currentFolder.conditions, let groupOwners = conditions.groupOwners, !groupOwners.isEmpty {
            groupOwnerIds = groupOwners.components(separatedBy: [","].first!)
        }
        
        if groupOwnerIds.count < maxGroupOwnerCount {
            let addGroupOwnerItem = OWSTableItem(customCellBlock: {
                let cell = DTChatFolderCell(title:"Add Group Owner", iconName: "ic_circled_plus", separatorNeed: false, tintColor: .ows_materialBlue)
                cell.accessoryView = DTChatFolderCell.accessoryArrow()
                return cell
            }, customRowHeight: 50) { [weak self] in
                guard let self else { return }
                
                self.isSelectGroupOwner = true
                let selectThreadVC = SelectThreadViewController()
                selectThreadVC.selectThreadViewDelegate = self
                selectThreadVC.maxSelectCount = UInt(self.maxGroupOwnerCount - groupOwnerIds.count)
                selectThreadVC.isDefaultMultiSelect = true
                selectThreadVC.existingThreadIds = groupOwnerIds
                let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
                self.present(selectThreadNav, animated: true)
            }
            addGroupOwnersSection.add(addGroupOwnerItem)
        }
        
        if let conditions = currentFolder.conditions, let groupOwners = conditions.groupOwners, !groupOwners.isEmpty {
            var availableGroupOwners = groupOwners.stripped
            if availableGroupOwners.hasPrefix(",") {
                availableGroupOwners.removeFirst()
            }
            if availableGroupOwners.hasSuffix(",") {
                availableGroupOwners.removeLast()
            }
            let groupOwnerIds = availableGroupOwners.components(separatedBy: [","].first!)
            groupOwnerIds.forEach { groupOwnerId in
                let groupOwnerItem = OWSTableItem(customCellBlock: {
                    let cell = DTChatFolderCell(groupOwnerId: groupOwnerId)
                    
                    return cell
                }, customRowHeight: 50, actionWithIndexPathBlock: nil)
                groupOwnerItem.canEdit = true
                addGroupOwnersSection.add(groupOwnerItem)
            }
        }
        contents.addSection(addGroupOwnersSection)
        
        self.contents = contents
    }
    
    /*
    func addKeywords() {
        let addConditionsVC = DTAddConditionsController()
        if let conditions = currentFolder.conditions, let keywords = conditions.keywords {
            addConditionsVC.lastKeywords = keywords
        }
        addConditionsVC.shouldUseTheme = true
        addConditionsVC.saveKeywordsHandler = { [weak self] kwords in
            guard let self else {
                return
            }
            let conditions = DTFolderConditions()!
            conditions.keywords = kwords
            self.currentFolder.conditions = conditions
            self.updateEditItemEnabled()
            self.updateContents()
        }
        self.navigationController?.pushViewController(addConditionsVC, animated: true)
    }
    */
    
    func textField(placeholder: String, leftIconName: String?) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.backgroundColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x312F34) : UIColor(rgbHex: 0xF3F1F4)
        textField.returnKeyType = .done
        textField.borderStyle = .none
        textField.layer.cornerRadius = 10
        textField.layer.borderColor = Theme.primaryTextColor.cgColor
        let spacerView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 44))
        textField.leftViewMode = .always
        textField.rightView = spacerView
        textField.rightViewMode = .always
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: Theme.placeholderColor])
        textField.setContentHuggingHorizontalLow()
        textField.autoSetDimension(.height, toSize: 44)
        guard let leftIconName = leftIconName else {
            textField.leftView = spacerView
            return textField
        }
        
        let leftView = UIImageView(image: UIImage(named: leftIconName)?.withRenderingMode(.alwaysTemplate))
        leftView.tintColor = Theme.primaryTextColor
        leftView.contentMode = .center
        leftView.autoSetDimensions(to: CGSize(width: 50, height: 44))
        textField.leftView = leftView
        
        return textField
    }
    
    override func applyTheme() {
        super.applyTheme()
        updateContents()
    }
    
    func ignoreThreadIds() -> [String] {
        var ignoreThreadIds = [String]()

        selectedThreads.forEach {
            ignoreThreadIds.append($0.serverThreadId)
        }

        return ignoreThreadIds
    }
    
    func updateEditItemEnabled() {
        
        guard currentFolder.name.count > 0 else {
            navigationItem.rightBarButtonItem?.isEnabled = false
            return
        }
        
        var keywords: String?
        if let conditions = currentFolder.conditions, let kw = conditions.keywords {
            keywords = kw
        }
        
        var hasGroupOwners = false
        if let conditions = currentFolder.conditions, let groupOwners = conditions.groupOwners {
            hasGroupOwners = !groupOwners.isEmpty
        }

        var isEnabled = false
        if let keywords = keywords, !keywords.isEmpty {
            isEnabled = keywords.count > keywordsMinLength - 1 && keywords.count < KeywordsMaxLength + 1
        } else {
            isEnabled = !selectedThreads.isEmpty || hasGroupOwners
        }
        navigationItem.rightBarButtonItem?.isEnabled = isEnabled
    }
    
    func foldedNameTextFieldShake() {
        let shake = CAKeyframeAnimation(keyPath: "position.x")
        shake.values = [0, -5, 5, -5, 0]
        shake.isAdditive = true
        shake.duration = 0.2
        self.tfFolderName.layer.add(shake, forKey:"shake")
    }
        
    @objc func saveItemAction() {
        
        var chatFolders = [DTChatFolderEntity]()
        DTChatFolderManager.shared().chatFolders.copy.forEach { folder in
            chatFolders.append(folder)
        }

        var existFolderName = false
        for (idx, chatFolder) in chatFolders.enumerated() {
            if mode == .create {
                if currentFolder.name == chatFolder.displayName {
                    existFolderName = true
                    break
                }
            } else {
                if currentFolder.name == chatFolder.displayName && currentIndex != idx {
                    existFolderName = true
                    break
                }
            }
        }
        
        if existFolderName {
            foldedNameTextFieldShake()
            SVProgressHUD.showInfo(withStatus: Localized("CHAT_FOLDER_FOLDER_NAME_EXIST_TIP", comment: ""))
            return
        }
        
        if forbiddenNames().contains(currentFolder.name) {
            foldedNameTextFieldShake()
            SVProgressHUD.showInfo(withStatus: Localized("CHAT_FOLDER_NAME_CONFLICT", comment: ""))
            return
        }
                
        var cIds = [DTFolderThreadEntity]()
        selectedThreads.forEach { thread in
            guard let threadEntity = DTFolderThreadEntity(thread: thread) else {
                return
            }
            cIds.append(threadEntity)
        }
        if cIds.isEmpty && currentFolder.conditions?.keywords == nil && currentFolder.conditions?.groupOwners == nil  {
            var failTips: String!
            if self.mode == .create {
                failTips = Localized("CHAT_FOLDER_CREATE_FAILED_TIP", comment: "")
            } else {
                failTips = Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: "")
            }
            SVProgressHUD.showError(withStatus: failTips)
            return
        }
        
        currentFolder.cIds = cIds
        if mode == .create {
            chatFolders.append(currentFolder)
        } else {
            chatFolders.replaceSubrange(currentIndex...currentIndex, with: [currentFolder])
        }

        SVProgressHUD.show()
        DTChatFolderManager.saveChatFolders(chatFolders) {
            var successTips: String!
            if self.mode == .create {
                successTips = Localized("CHAT_FOLDER_CREATE_SUCCESS_TIP", comment: "")
            } else {
                successTips = Localized("CHAT_FOLDER_SAVE_SUCCESS_TIP", comment: "")
            }
            SVProgressHUD.showSuccess(withStatus: successTips)
            SVProgressHUD.dismiss(withDelay: 1, completion: {
                self.navigationController?.popViewController(animated: true)
            })
        } failure: { error in
            var failTips: String!
            SVProgressHUD.dismiss(withDelay: 1, completion: {
                if self.mode == .create {
                    failTips = Localized("CHAT_FOLDER_CREATE_FAILED_TIP", comment: "")
                } else {
                    failTips = Localized("CHAT_FOLDER_SAVE_FAILED_TIP", comment: "")
                }
                SVProgressHUD.showError(withStatus: failTips)
            })
        }

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

extension DTCreateFolderController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if textField.tag == tfFolderNameTag {
            guard let tempText = self.tfFolderName.text else {
                currentFolder.name = ""
                updateEditItemEnabled()
                return
            }
            if tempText.count == 0 {
                currentFolder.name = ""
                updateEditItemEnabled()
            }
        } else {
            
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let text = textField.text else { return false }
        if textField.tag == tfFolderNameTag {
            
            let newString = text.replacingCharacters(in: text.toRange(range)!, with: string)
            if newString.count > DTFolderNameMaxKenght {
                foldedNameTextFieldShake()
                return false
            }
            let strippedFolderName = newString.stripped
            currentFolder.name = strippedFolderName
            updateEditItemEnabled()
            
            return true
        }
        
        let availableKeywords = text.replacingCharacters(in: text.toRange(range)!, with: string).stripped
        if availableKeywords.count > KeywordsMaxLength {
            currentFolder.conditions?.keywords = availableKeywords
            updateEditItemEnabled()
            return false
        }
        if availableKeywords.count >= keywordsMinLength {
            if let conditions = currentFolder.conditions {
                conditions.keywords = availableKeywords
            } else {
                let conditions = DTFolderConditions()!
                conditions.keywords = availableKeywords
                currentFolder.conditions = conditions
            }
        } else {
            currentFolder.conditions?.keywords = availableKeywords
        }
        updateEditItemEnabled()

        return true

    }

}

extension DTCreateFolderController: OWSTableViewControllerDelegate {
    
    func _tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let removeAction = UIContextualAction(style: .destructive, title: Localized("CHAT_FOLDER_ITEM_REMOVE", comment: "")) { (_, _, completionHandler) in
            let isSelectedThred = !self.selectedThreads.isEmpty && indexPath.section == 2;
            let isSelectGroupOwner = self.selectedThreads.isEmpty ? indexPath.section == 3 : indexPath.section == 4
            
            if isSelectedThred {
                self.selectedThreads.remove(at: indexPath.row)
            } else if isSelectGroupOwner {
                guard let conditions = self.currentFolder.conditions, let groupOwners = conditions.groupOwners else {
                    completionHandler(true)
                    return
                }
                var groupOwnerIds = groupOwners.components(separatedBy: [","].first!)
                var targetIndex = 0
                if groupOwnerIds.count == self.maxGroupOwnerCount {
                    targetIndex = indexPath.row
                } else {
                    targetIndex = indexPath.row - 1
                }
                groupOwnerIds.remove(at: targetIndex)
                conditions.groupOwners = groupOwnerIds.joined(separator: ",")
                self.currentFolder.conditions = conditions
            }
            self.updateEditItemEnabled()
            self.updateContents()
            completionHandler(true)
        }
        return UISwipeActionsConfiguration(actions: [removeAction])
    }

}

extension DTCreateFolderController: SelectThreadViewControllerDelegate {

    func threadsWasSelected(_ threads: [TSThread]) {
       
        if isSelectGroupOwner {
            var newGroupOwnerIds = [String]()
            threads.forEach { thread in
                if !(thread is TSContactThread) {
                    return
                }
                guard let contactIdentifier = thread.contactIdentifier() else { return }
                newGroupOwnerIds.append(contactIdentifier)
            }
            if let conditions = currentFolder.conditions {
                if let groupOwners = conditions.groupOwners, !groupOwners.isEmpty {
                    var totalGroupOwnerIds = groupOwners.components(separatedBy: [","].first!)
                    totalGroupOwnerIds += newGroupOwnerIds
                    currentFolder.conditions?.groupOwners = totalGroupOwnerIds.joined(separator: ",")
                } else {
                    currentFolder.conditions?.groupOwners = newGroupOwnerIds.joined(separator: ",")
                }
            } else {
                let conditions = DTFolderConditions()!
                conditions.groupOwners = newGroupOwnerIds.joined(separator: ",")
                currentFolder.conditions = conditions
            }
        } else {
            selectedThreads += threads
        }
        updateEditItemEnabled()
        updateContents()

        presentedViewController?.dismiss(animated: true)
    }
    
    func showRecently() -> Bool {
        
        return !isSelectGroupOwner
    }
    
    func showSelfAsNote() -> Bool {
      
        return !isSelectGroupOwner
    }
    
    func selectedMaxCountAlertFormat() -> String? {
        
        return  isSelectGroupOwner ? Localized("CHAT_FOLDER_GROUP_OWNER_MAX_COUNT_TIPS", comment: "") : nil
    }
    
    func canSelectBlockedContact() -> Bool {
       
        false
    }
    
}

extension DTCreateFolderController: OWSNavigationChildController {
    
    public var shouldCancelNavigationBack: Bool {
        
        switch mode {
        case .create:
            guard let folderName = tfFolderName.text else {
                return false
            }
            if folderName.count > 0 && (selectedThreads.count > 0 || currentFolder.conditions?.keywords != nil || currentFolder.conditions?.groupOwners != nil) {
                alertToPop()
                return true
            }
        case .edit:
            if origionFolder.name != currentFolder.name {
                alertToPop()
                return true
            }
            var origionIds = [String]()
            var currentIds = [String]()
            selectedThreads.forEach {
                currentIds.append($0.serverThreadId)
            }
            origionFolder.cIds.forEach {
                origionIds.append($0.id)
            }
            if currentIds.count != origionIds.count {
                alertToPop()
                return true
            }
            let origionIdSet = Set(origionIds)
            let currentSet = Set(currentIds)
            if origionIdSet.subtracting(currentSet).count != 0 && currentSet.subtracting(origionIdSet).count != 0 {
                alertToPop()
                return true
            }
            if currentFolder.conditions?.keywords != origionFolder.conditions?.keywords || currentFolder.conditions?.groupOwners != origionFolder.conditions?.groupOwners {
                alertToPop()
                return true
            }
        }
        return false
    }
    
    func alertToPop() {
        self.showAlert(.alert, title: Localized("COMMON_NOTICE_TITLE", comment: ""), msg: Localized("CHAT_FOLDER_DISCARD_UPDATE_TIP", comment: ""), cancelTitle: Localized("CHAT_FOLDER_DISCARD_CANCEL", comment: ""), confirmTitle: Localized("CHAT_FOLDER_DISCARD_CONFIRM", comment: ""), confirmStyle: .destructive) {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // TODO: 所有页面切换到 swift 后，删除
    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }
    
    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .blur }

    public var navbarBackgroundColorOverride: UIColor? { nil }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool { false }
}

extension Array where Element: NSCopying {
    public var copy: [Element] {
        return self.map {$0.copy(with: nil) as! Element}
    }
}
