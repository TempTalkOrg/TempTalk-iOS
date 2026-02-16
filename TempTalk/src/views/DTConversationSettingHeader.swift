//
//  DTConversationSettingHeaderView.swift
//  Signal
//
//  Created by Ethan on 27/07/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging
import PureLayout

@objc
public class DTConversationSettingHeader: UIView {

    let kHeaderAvatarWidth = 48.0
    var collectionView: UICollectionView?

    private let isGroupThread: Bool
    private let currentMemberIds: [String]
    private let addMemberBlock: (() -> Void)
    private var removeMemberBlock: (() -> Void)?
    private var viewMemberBlock: ((Int) -> Void)
    private var viewAllBlock: (() -> Void)?

    @objc required init(memberIds: [String], isGroup:Bool = true, addMember: @escaping () -> Void, removeMember: (() -> Void)? = nil, viewMember: @escaping (Int) -> Void, viewAll: (() -> Void)? = nil) {
        Logger.debug("init")

        isGroupThread = isGroup
        currentMemberIds = memberIds
        addMemberBlock = addMember
        viewMemberBlock = viewMember
        super.init(frame: .zero)

        createSubviews()
        removeMemberBlock = removeMember
        viewAllBlock = viewAll
    }

    func createSubviews() {

        let margin = floor((UIScreen.main.bounds.width - kHeaderAvatarWidth * 5) / 6 - CGFloat.leastNonzeroMagnitude)
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: kHeaderAvatarWidth, height: 66)
        layout.minimumLineSpacing = 15
        layout.minimumInteritemSpacing = margin
        layout.sectionInset = .init(hMargin: margin, vMargin: 24)
//            .init(top: 24, leading: margin, bottom: 24, trailing: margin)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView = collection
        collection.delegate = self
        collection.dataSource = self
        collection.isScrollEnabled = false
        collection.backgroundColor = Theme.bg1Color
        addSubview(collection)

        collection.register(DTConversationSettingMemberCell.self, forCellWithReuseIdentifier: DTConversationSettingMemberCell.reuseIdentifier())
        collection.register(DTConversationSettingHandleCell.self, forCellWithReuseIdentifier: DTConversationSettingHandleCell.reuseIdentifier())

        collectionView?.autoPinEdge(toSuperviewEdge: .top)
        collectionView?.autoPinEdge(toSuperviewEdge: .leading)
        collectionView?.autoPinEdge(toSuperviewEdge: .trailing)

        if (isGroupThread) {
            let btnMembers = DTLayoutButton()
            btnMembers.titleAlignment = .left
            btnMembers.spacing = 3
            btnMembers.setTitle(Localized("GROUP_MEMBERS_SECTION_TITLE_MEMBERS"), for: .normal)
            btnMembers.setTitle(Localized("GROUP_MEMBERS_SECTION_TITLE_MEMBERS"), for: .highlighted)
            btnMembers.setTitleColor(Theme.tprimaryColor, for: .normal)
            btnMembers.setTitleColor(Theme.tprimaryColor, for: .highlighted)
            let btnImage = UIImage(named: "ic_accessory_arrow")?.withRenderingMode(.alwaysTemplate)
            btnMembers.setImage(btnImage, for: .normal)
            btnMembers.setImage(btnImage, for: .highlighted)
            btnMembers.titleLabel?.font = .systemFont(ofSize: 12)
            btnMembers.addTarget(self, action: #selector(viewAllAction), for: .touchUpInside)
            btnMembers.imageView?.tintColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xB7BDC6) : UIColor(rgbHex: 0x474D57)
            addSubview(btnMembers)

            if let collectionView = collectionView {
                btnMembers.autoPinEdge(.top, to: .bottom, of: collectionView)
            }
            btnMembers.autoSetDimensions(to: CGSize(width: 80, height: 30))
            btnMembers.autoPinEdge(toSuperviewEdge: .bottom, withInset: 10)
            btnMembers.autoHCenterInSuperview()
        } else {
            collectionView?.autoPinEdge(toSuperviewEdge: .bottom)
        }
        
    }
    
    @objc func viewAllAction() {
        guard let viewAllBlock = viewAllBlock else {
            return
        }
        viewAllBlock()
    }
    
    func reloadData() {
        collectionView?.reloadData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
         Logger.debug("deinit")
    }
    
}

extension DTConversationSettingHeader: UICollectionViewDelegate, UICollectionViewDataSource {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        guard isGroupThread else { return 2 }
        
        guard !currentMemberIds.isEmpty else { return 2 }
        let groupMemberCount = currentMemberIds.count

        if (groupMemberCount == 1) { return 2 }
        
        return min(groupMemberCount + 2, 10)
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        func newMemberCell(_ recipientId: String) -> DTConversationSettingMemberCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DTConversationSettingMemberCell.reuseIdentifier(), for: indexPath) as! DTConversationSettingMemberCell
            cell.configCell(recipientId)
            
            return cell
        }

        func newHandleCell(_ handleType: HandleType) -> DTConversationSettingHandleCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DTConversationSettingHandleCell.reuseIdentifier(), for: indexPath) as! DTConversationSettingHandleCell
            cell.handleType = handleType
            
            return cell
        }
        
        let groupMemberCount = currentMemberIds.count
        if (groupMemberCount == 1) {
            if (indexPath.item == 0) {
                guard indexPath.item < currentMemberIds.count else {
                    owsFailDebug("Index out of bounds: indexPath.item=\(indexPath.item), count=\(currentMemberIds.count)")
                    return UICollectionViewCell()
                }
                return newMemberCell(currentMemberIds[indexPath.item])
            } else {
                return newHandleCell(.add)
            }
        } else if (currentMemberIds.isEmpty) {
            return newHandleCell(.add)
        } else if (groupMemberCount < 8) {
            if (indexPath.item == groupMemberCount) {
                return newHandleCell(.add)
            } else if (indexPath.item == groupMemberCount + 1) {
                return newHandleCell(.remove)
            } else {
                guard indexPath.item < currentMemberIds.count else {
                    owsFailDebug("Index out of bounds: indexPath.item=\(indexPath.item), count=\(currentMemberIds.count)")
                    return UICollectionViewCell()
                }
                return newMemberCell(currentMemberIds[indexPath.item])
            }
        } else {
            if (indexPath.item == 8) {
                return newHandleCell(.add)
            } else if (indexPath.item == 9) {
                return newHandleCell(.remove)
            } else {
                guard indexPath.item < currentMemberIds.count else {
                    owsFailDebug("Index out of bounds: indexPath.item=\(indexPath.item), count=\(currentMemberIds.count)")
                    return UICollectionViewCell()
                }
                return newMemberCell(currentMemberIds[indexPath.item])
            }
        }
        
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard let cell = collectionView.cellForItem(at: indexPath) as? DTConversationSettingHandleCell else {
            viewMemberBlock(indexPath.item)
            return
        }
        
        switch cell.handleType {
        case .add:
            addMemberBlock()
        case .remove:
            removeMemberBlock?()
        }
    }
}

class DTConversationSettingMemberCell: UICollectionViewCell {

    var contactManager: OWSContactsManager? {
        return Environment.shared.contactsManager
    }

    var avatarView: AvatarImageView?
    var lbName: UILabel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        let avatar = AvatarImageView()
        avatarView = avatar
        contentView.addSubview(avatar)

        let nameLabel = UILabel()
        lbName = nameLabel
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.textAlignment = .center
        nameLabel.textColor = Theme.iconColor
        contentView.addSubview(nameLabel)

        avatar.autoPinEdge(toSuperviewEdge: .top)
        avatar.autoPinEdge(toSuperviewEdge: .leading)
        avatar.autoPinEdge(toSuperviewEdge: .trailing)

        nameLabel.autoPinEdge(toSuperviewEdge: .leading)
        nameLabel.autoPinEdge(toSuperviewEdge: .trailing)
        nameLabel.autoPinEdge(toSuperviewEdge: .bottom)
        nameLabel.autoSetDimension(.height, toSize: 16)
        if let avatarView = avatarView {
            lbName?.autoPinEdge(.top, to: .bottom, of: avatarView, withOffset: 2)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configCell(_ recipientId: String) {
        guard let contactManager = contactManager else {
            self.avatarView?.setImageWithRecipientId(recipientId, displayName: recipientId)
            self.lbName?.text = recipientId.count > 5 ? "\(recipientId.prefix(5))..." : recipientId
            return
        }

        let displayName = contactManager.displayName(forPhoneIdentifier: recipientId)
        // For avatar generation, use nickname only (not remark name)
        let nicknameForAvatar = contactManager.rawDisplayName(forPhoneIdentifier: recipientId) ?? recipientId
        self.avatarView?.setImageWithRecipientId(recipientId, displayName: nicknameForAvatar)
        self.lbName?.text = displayName.count > 5 ? "\(displayName.prefix(5))..." : displayName
    }
    
    class func reuseIdentifier() -> String {
        return "DTConversationSettingMemberCell"
    }
    
 }

enum HandleType: Int {
    case add, remove
}

class DTConversationSettingHandleCell: UICollectionViewCell {

    private var iconView: UIImageView?

    private var _handleType: HandleType = .add
    var handleType: HandleType {
        set {
            _handleType = newValue
            if (Theme.isDarkThemeEnabled)  {
                self.iconView?.image = UIImage(named: newValue == .add ? "ic_conversation_setting_add_dark" : "ic_conversation_setting_remove_dark")
                return
            }
            self.iconView?.image = UIImage(named: newValue == .add ? "ic_conversation_setting_add" : "ic_conversation_setting_remove")
        }
        get {
            _handleType
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        iconView = UIImageView()
        iconView?.contentMode = .scaleAspectFit
        if let iconView = self.iconView {
            contentView.addSubview(iconView)
            iconView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0, bottom: 18, right: 0))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    class func reuseIdentifier() -> String {
        return "DTConversationSettingHandleCell"
    }
    
}
