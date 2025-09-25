//
//  DTRaiseHandController.swift
//  Difft
//
//  Created by Henry on 2025/7/3.
//  Copyright © 2025 Difft. All rights reserved.
//

import TTServiceKit
import TTMessaging
import PanModal

@objcMembers
class DTRaiseHandController: OWSTableViewController {
    
    override func loadView() {
        super.loadView()
        self.createViews()
    }
    
    func createViews() {
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 60
        self.tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor(rgbHex: 0x2B3139)
    }
    
    override func applyTheme() {
        super.applyTheme()
        updateTableContents()
        
        view.backgroundColor = Theme.defaultBackgroundColor
        tableView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableContents()
        RoomDataManager.shared.onRaiseHandsUpdate = {
            DispatchMainThreadSafe {
                self.updateTableContents()
            }
        }
    }
    
    
    func updateTableContents() {
        let contents = OWSTableContents()
        let topSection = OWSTableSection()
        let handsSection = OWSTableSection()
        
        let participants = RoomDataManager.shared.handsData
        let participantCount = participants.count
        
        topSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.handsHeaderCell(participantCount: participantCount) ?? UITableViewCell()
        }, customRowHeight: 40, actionBlock: {}))
        
        for participantId in participants {
            handsSection.add(OWSTableItem(customCellBlock: { [weak self] in
                guard let self else { return UITableViewCell() }
                return self.raiseHandCell(participantId: participantId, onLowerTap: {
                        Task {
                            await DTMeetingManager.shared.handCancelRemoteSyncStatus(participantId: participantId)
                        }
                    })
            }, customRowHeight: 64, actionBlock: {}))
        }
        
        contents.addSection(topSection)
        contents.addSection(handsSection)
        
        self.contents = contents
    }
    
    func handsHeaderCell(participantCount: Int) -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        
        let iconView = UIImageView()
        iconView.image = UIImage(named: "tabler_hand_lower_header")
        iconView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(Localized("RAISE_HANDS_TITLE")) (\(participantCount))"
        label.textColor = UIColor.color(rgbHex: 0xB7BDC6)
        
        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        cell.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        return cell
    }
    
    func raiseHandCell(participantId: String, onLowerTap: @escaping () -> Void) -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        
        guard let contactsManager = Environment.shared.contactsManager, let signalAccount = contactsManager.signalAccount(forRecipientId: participantId), let contact = signalAccount.contact else {
            return cell
        }
        
        let avatarView = DTAvatarImageView()
        let nameLabel = UILabel()
        let lowerButton = UIButton(type: .system)
       
        // 头像样式
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20 // 半径为 width/2，实现圆形
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        avatarView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        if let avatar_ = contact.avatar as? [String : Any] {
            avatarView.setImage(avatar: avatar_, recipientId: participantId, displayName: signalAccount.contactFullName(), completion: nil)
        }

        // 名称标签
        nameLabel.font = .systemFont(ofSize: 15)
        nameLabel.textColor = UIColor.white
        nameLabel.numberOfLines = 2 // 最多两行
        nameLabel.text = contactsManager.displayName(forPhoneIdentifier: participantId)

        // 放下手按钮
        lowerButton.setTitle("Lower", for: .normal)
        lowerButton.setTitleColor(.color(rgbHex: 0xB7BDC6), for: .normal)
        lowerButton.addAction(UIAction(handler: { _ in
            onLowerTap()
        }), for: .touchUpInside)
        
        // 水平堆叠：头像 - 名字 - 按钮
        let stack = UIStackView(arrangedSubviews: [avatarView, nameLabel, lowerButton])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center

        cell.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12),
        ])

        // 让 nameLabel 自动扩展宽度，但不挤压按钮
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        lowerButton.setContentHuggingPriority(.required, for: .horizontal)
        lowerButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return cell
    }
}

extension DTRaiseHandController : PanModalPresentable {
    
    var panScrollable: UIScrollView? {
        return tableView
    }
}
