//
//  DTUpdateNoiseController.swift
//  Difft
//
//  Created by Henry on 2025/7/17.
//  Copyright © 2025 Difft. All rights reserved.
//

import TTServiceKit
import TTMessaging
import PanModal


@objcMembers
class DTUpdateNoiseController: OWSTableViewController {
    
    private var noiseSwitch = UISwitch()
    private var criticalTextView: VerticalIconTextView?
    
    let itemsCount_private: CGFloat = 3
    let itemsCount_group: CGFloat = 3
    
    override func loadView() {
        super.loadView()
        self.createViews()
    }
    
    func createViews() {
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 80
        self.tableView.separatorStyle = .none
        self.tableView.isScrollEnabled = false
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
        setupKVOObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupKVOObservers() {
        // 监听 callState 变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(callStateDidChange),
            name: NSNotification.Name("CallStateDidChange"),
            object: nil
        )
    }
    
    @objc private func callStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 重新加载表格内容以更新布局
            self.updateTableContents()
        }
    }
    
    func updateTableContents() {
        let contents = OWSTableContents()
        
        let moreSection = OWSTableSection()
        moreSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.moreUpdateCell() ?? UITableViewCell()
        }, customRowHeight: 120, actionBlock: {}))
        contents.addSection(moreSection)
        
        let noiseSection = OWSTableSection()
        noiseSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.noiseUpdateCell() ?? UITableViewCell()
        }, customRowHeight: 70, actionBlock: {}))
        contents.addSection(noiseSection)
        
        self.contents = contents
    }
    
    func noiseUpdateCell() -> UITableViewCell {
        
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        
        let rowLabel = UILabel()
        rowLabel.text = Localized("CALLING_NOISE_TITLE")
        rowLabel.textColor = UIColor.white
        rowLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        rowLabel.lineBreakMode = .byTruncatingTail
        
        noiseSwitch = UISwitch()
        noiseSwitch.isOn = DTMeetingManager.shared.roomContext?.isDenoiseFilterEnabled() ?? true
        noiseSwitch.addTarget(self, action: #selector(noiseControlDidChange), for: .valueChanged)

        let contentRow = UIStackView(arrangedSubviews: [rowLabel, noiseSwitch])
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.backgroundColor = UIColor(rgbHex: 0x474D57)
        contentRow.layer.cornerRadius = 8
        contentRow.spacing = 4
        contentRow.isLayoutMarginsRelativeArrangement = true
        contentRow.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        return cell
    }
    
    func moreUpdateCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)

        // --- UI Elements ---
        let inviteTextView = VerticalIconTextView(
            image: UIImage(named: "calling_invite"),
            title: Localized("CALL_INVITE_MEMBERS")
        ) {
            let inviteVC = DTCallInviteMemberVC()
            inviteVC.isLiveKitCall = true
            let inviteNav = OWSNavigationController(rootViewController: inviteVC)
            self.navigationController?.present(inviteNav, animated: true)
        }

        let switchCameraTextView = VerticalIconTextView(
            image: UIImage(named: "call_switch"),
            title: Localized("CALL_MORE_SWITCH_CAMERA")
        ) {
            DTMeetingManager.shared.switchCamera()
        }

        let criticalTextView = VerticalIconTextView(
            image: UIImage(named: "call_critical"),
            title: Localized("CALL_MORE_CRITICAL_ALERT")
        ) {
            self.dismiss(animated: true) { [weak self] in
                guard self != nil else { return }
                Task {
                    await DTMeetingManager.shared.sendCriticalAlertWithBarrage(Localized("MEETING_CRITICAL_ALERT_DANMU"))
                }
            }
        }

        let raiseHandTextView = VerticalIconTextView(
            image: UIImage(named: "calling_lowerHand"),
            selectedImage: UIImage(named: "calling_raiseHand"),
            title: Localized("RAISE_HANDS_TITLE")
        ) {
            if RoomDataManager.shared.localRaiseHand {
                Task {
                    await DTMeetingManager.shared.handCancelRemoteSyncStatus(
                        participantId: DTMeetingManager.shared.roomContext?.room.localParticipant.identity?.stringValue.split(separator: ".").first.map(String.init) ?? ""
                    )
                    RoomDataManager.shared.localRaiseHand = false
                }
            } else {
                Task {
                    await DTMeetingManager.shared.handRaiseRemoteSyncStatus()
                    RoomDataManager.shared.localRaiseHand = true
                }
            }
        }

        let contentRow = UIStackView()
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.distribution = .equalSpacing
        contentRow.spacing = 5
        contentRow.isLayoutMarginsRelativeArrangement = true
        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let call = DTMeetingManager.shared.currentCall
            var items: [UIView] = [inviteTextView]

            switch call.callType {
            case .private:
                if !DTMeetingManager.shared.inMeeting, call.callState == .outgoing {
                    items.append(criticalTextView)
                }

            case .group:
                guard
                    let gid = call.conversationId,
                    let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
                    let groupThread = TSGroupThread.getWithGroupId(groupId)
                else {
                    return
                }

                items.append(raiseHandTextView)

                if DTMeetingManager.shared.openCallCamera {
                    items.append(switchCameraTextView)
                }

                if groupThread.groupModel.criticalAlert {
                    items.append(criticalTextView)
                }

            default:
                if DTMeetingManager.shared.openCallCamera {
                    items.append(switchCameraTextView)
                }
            }
            self.updateSubviews(items, contentRow: contentRow)
        }

        return cell
    }
    
    func noiseControlDidChange() {
        guard let roomContext = DTMeetingManager.shared.roomContext else {
            Logger.info("\(DTMeetingManager.shared.logTag) Room context is nil when changing noise settings")
            return
        }
        roomContext.setDenoiseFilter(enabled: noiseSwitch.isOn)
    }
    
    func updateSubviews(_ subviews: [UIView], contentRow: UIStackView) {
        contentRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for view in subviews {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentRow.addArrangedSubview(view)
            view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        }

        DispatchQueue.main.async {
            guard let superview = contentRow.superview else { return }
            let width = superview.bounds.width
            guard width > 10 else { return }

            let count = CGFloat(subviews.count)
            if count > 1 {
                let padding = max(8, (width - 50 - 80 * count) / count)
                contentRow.layoutMargins = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)
            }
        }
    }
}

extension DTUpdateNoiseController : PanModalPresentable {
    var panScrollable: UIScrollView? {
        return tableView
    }
}

class VerticalIconTextView: UIView {
    
    public let imageView = UIImageView()
    private let titleLabel = UILabel()
    private var tapAction: (() -> Void)?
    
    private var normalImage: UIImage?
    private var selectedImage: UIImage?
    private var isSelected = RoomDataManager.shared.localRaiseHand

    init(image: UIImage?, selectedImage: UIImage? = nil, title: String, tapAction: (() -> Void)? = nil) {
        super.init(frame: .zero)
        self.normalImage = image
        self.selectedImage = selectedImage
        self.tapAction = tapAction
        setupUI(image: image, title: title)
        addGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI(image: UIImage?, title: String) {
        imageView.image = isSelected ? selectedImage ?? normalImage : normalImage
        imageView.contentMode = .scaleAspectFit

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = UIColor(rgbHex: 0xEAECEF)
        titleLabel.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 6
        stackView.alignment = .center

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor)
        ])
    }

    private func addGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        self.addGestureRecognizer(tap)
        self.isUserInteractionEnabled = true
    }

    @objc private func viewTapped() {
        isSelected = !RoomDataManager.shared.localRaiseHand
        imageView.image = isSelected ? selectedImage ?? normalImage : normalImage
        tapAction?()
    }

    /// 手动设置选中状态
    func setSelected(_ selected: Bool) {
        isSelected = selected
        imageView.image = isSelected ? selectedImage ?? normalImage : normalImage
    }

    /// 手动更新图片
    func updateImages(normal: UIImage?, selected: UIImage?) {
        self.normalImage = normal
        self.selectedImage = selected
        imageView.image = isSelected ? selectedImage ?? normalImage : normalImage
    }
}
