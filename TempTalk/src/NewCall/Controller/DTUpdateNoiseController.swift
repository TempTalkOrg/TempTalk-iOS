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
import AudioPipelineProcessor


@objcMembers
class DTUpdateNoiseController: OWSTableViewController {
    
    private var noiseSwitch = UISwitch()
    private var criticalTextView: VerticalIconTextView?
    private var bubbleView: UIView?
    private var bubbleBackdrop: UIView?
    private var voiceBubbleView: UIView?
    private var voiceBubbleBackdrop: UIView?

    static let voicePresets: [(key: String, emoji: String, nameKey: String)] = [
        ("original", "", "CALLING_VOICE_PRESET_ORIGINAL"),
        ("goddess", "🐿️", "CALLING_VOICE_PRESET_HIGHER"),
        ("uncle", "🐻", "CALLING_VOICE_PRESET_DEEPER"),
    ]
    
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
        
        view.backgroundColor = Theme.defaultColor
        tableView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTableContents()
        setupKVOObservers()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bubbleBackdrop?.removeFromSuperview()
        bubbleBackdrop = nil
        bubbleView?.removeFromSuperview()
        bubbleView = nil
        voiceBubbleBackdrop?.removeFromSuperview()
        voiceBubbleBackdrop = nil
        voiceBubbleView?.removeFromSuperview()
        voiceBubbleView = nil
    }
    
    deinit {
        bubbleBackdrop?.removeFromSuperview()
        bubbleView?.removeFromSuperview()
        voiceBubbleBackdrop?.removeFromSuperview()
        voiceBubbleView?.removeFromSuperview()
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(criticalAlertNotifyDidChange),
            name: NSNotification.Name("DTGroupCriticalAlertChangedNotification"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(denoiseModeDidChange),
            name: .denoiseModeDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceChangerPresetDidChange),
            name: .voiceChangerPresetDidChange,
            object: nil
        )
    }

    @objc private func voiceChangerPresetDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadVoiceChangerRow()
        }
    }
    
    @objc private func denoiseModeDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadDenoiseModeRow()
        }
    }
    
    @objc private func callStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 重新加载表格内容以更新布局
            self.updateTableContents()
        }
    }
    
    @objc private func criticalAlertNotifyDidChange() {
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
        noiseSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.denoiseModeHeaderCell() ?? UITableViewCell()
        }, customRowHeight: 60, actionBlock: {}))
        noiseSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.voiceChangerHeaderCell() ?? UITableViewCell()
        }, customRowHeight: 64, actionBlock: {}))
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
            // 判断是否需要显示二次确认弹窗
            if DTMeetingManager.shared.shouldShowCriticalAlertConfirm {
                // Instant/Group: 显示二次确认弹窗
                self.dismiss(animated: true) {
                    DTMeetingManager.shared.presentCriticalAlertConfirmVC()
                }
            } else {
                // 1v1: 直接发送 Critical Alert
                self.dismiss(animated: true) { [weak self] in
                    guard self != nil else { return }
                    Task {
                        await DTMeetingManager.shared.sendCriticalAlert(message: Localized("MEETING_CRITICAL_ALERT_DANMU"))
                    }
                }
            }
        }

        // 举手入口已下掉，注释保留逻辑
        // let raiseHandTextView = VerticalIconTextView(
        //     image: UIImage(named: "calling_lowerHand"),
        //     selectedImage: UIImage(named: "calling_raiseHand"),
        //     title: Localized("RAISE_HANDS_TITLE")
        // ) {
        //     if RoomDataManager.shared.localRaiseHand {
        //         Task {
        //             await DTMeetingManager.shared.handCancelRemoteSyncStatus(
        //                 participantId: DTMeetingManager.shared.roomContext?.room.localParticipant.identity?.stringValue.split(separator: ".").first.map(String.init) ?? ""
        //             )
        //             RoomDataManager.shared.localRaiseHand = false
        //         }
        //     } else {
        //         Task {
        //             await DTMeetingManager.shared.handRaiseRemoteSyncStatus()
        //             RoomDataManager.shared.localRaiseHand = true
        //         }
        //     }
        // }

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
                if DTMeetingManager.shared.openCallCamera {
                    items.append(switchCameraTextView)
                }

                // 1v1 通话：显示 Critical Alert 入口，但点击时不显示二次确认
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

                // 举手入口已下掉，注释保留逻辑
                // items.append(raiseHandTextView)

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
                
                if DTMeetingManager.shared.currentCall.invitedCriticalAlertUsers.count > 0 {
                    items.append(criticalTextView)
                }
            }
            self.updateSubviews(items, contentRow: contentRow)
        }

        return cell
    }
    
    func denoiseModeHeaderCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.clipsToBounds = false
        cell.contentView.clipsToBounds = false

        let rowLabel = UILabel()
        rowLabel.text = Localized("CALLING_DENOISE_MODE_TITLE")
        rowLabel.textColor = UIColor.white
        rowLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)

        let isEnhanced = (DTMeetingManager.shared.roomContext?.currentAudioModule() ?? .deepfilternet) == .deepfilternet
        let currentModeText = isEnhanced
            ? Localized("CALLING_DENOISE_MODE_ENHANCED")
            : Localized("CALLING_DENOISE_MODE_STANDARD")

        let valueLabel = UILabel()
        valueLabel.text = currentModeText
        valueLabel.textColor = UIColor.white
        valueLabel.font = UIFont.systemFont(ofSize: 14)

        let arrowImage = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrowImage.tintColor = UIColor(rgbHex: 0x9CA3AF)
        arrowImage.contentMode = .scaleAspectFit
        arrowImage.translatesAutoresizingMaskIntoConstraints = false
        arrowImage.widthAnchor.constraint(equalToConstant: 14).isActive = true
        arrowImage.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let rightStack = UIStackView(arrangedSubviews: [valueLabel, arrowImage])
        rightStack.axis = .horizontal
        rightStack.spacing = 4
        rightStack.alignment = .center

        let contentRow = UIStackView(arrangedSubviews: [rowLabel, rightStack])
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.backgroundColor = UIColor(rgbHex: 0x474D57)
        contentRow.layer.cornerRadius = 8
        contentRow.isLayoutMarginsRelativeArrangement = true
        contentRow.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleModeBubble))
        contentRow.addGestureRecognizer(tap)

        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 12, bottom: 4, right: 12))
        return cell
    }

    @objc private func toggleModeBubble() {
        if bubbleView != nil {
            dismissBubble()
            return
        }
        showBubble()
    }

    private func showBubble() {
        dismissBubble()

        let isEnhanced = (DTMeetingManager.shared.roomContext?.currentAudioModule() ?? .deepfilternet) == .deepfilternet

        let bubble = UIView()
        bubble.backgroundColor = UIColor(rgbHex: 0x3C4249)
        bubble.layer.cornerRadius = 8
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.4
        bubble.layer.shadowRadius = 8
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)

        let standardRow = makeBubbleRow(
            title: Localized("CALLING_DENOISE_MODE_STANDARD"),
            isSelected: !isEnhanced
        )
        standardRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bubbleStandardTapped)))

        let separator = UIView()
        separator.backgroundColor = UIColor.white.withAlphaComponent(0.12)

        let enhancedRow = makeBubbleRow(
            title: Localized("CALLING_DENOISE_MODE_ENHANCED"),
            isSelected: isEnhanced
        )
        enhancedRow.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bubbleEnhancedTapped)))

        let stack = UIStackView(arrangedSubviews: [standardRow, separator, enhancedRow])
        stack.axis = .vertical
        stack.spacing = 0
        bubble.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bubble.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            standardRow.heightAnchor.constraint(equalToConstant: 44),
            enhancedRow.heightAnchor.constraint(equalToConstant: 44)
        ])

        guard let window = view.window else { return }

        let backdrop = UIView()
        backdrop.backgroundColor = .clear
        backdrop.frame = window.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backdropTapped)))
        window.addSubview(backdrop)
        self.bubbleBackdrop = backdrop

        bubble.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(bubble)

        let lastSection = tableView.numberOfSections - 1
        guard lastSection >= 0,
              let cell = tableView.cellForRow(at: IndexPath(row: 1, section: lastSection))
        else { return }

        let cellFrameInWindow = cell.convert(cell.bounds, to: window)
        NSLayoutConstraint.activate([
            bubble.widthAnchor.constraint(equalToConstant: 160),
            bubble.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -24),
            bubble.bottomAnchor.constraint(equalTo: window.topAnchor, constant: cellFrameInWindow.minY - 8)
        ])

        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.2) {
            bubble.alpha = 1
            bubble.transform = .identity
        }

        self.bubbleView = bubble
    }

    @objc private func backdropTapped() {
        dismissBubble()
    }

    private func dismissBubble() {
        bubbleBackdrop?.removeFromSuperview()
        bubbleBackdrop = nil

        guard let bubble = bubbleView else { return }
        UIView.animate(withDuration: 0.15, animations: {
            bubble.alpha = 0
            bubble.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            bubble.removeFromSuperview()
        }
        bubbleView = nil
    }

    private func makeBubbleRow(title: String, isSelected: Bool) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = isSelected ? UIColor(rgbHex: 0x3B82F6) : UIColor.white
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: isSelected ? .medium : .regular)

        let checkImage = UIImageView(image: UIImage(systemName: "checkmark"))
        checkImage.tintColor = UIColor(rgbHex: 0x3B82F6)
        checkImage.contentMode = .scaleAspectFit
        checkImage.isHidden = !isSelected

        container.addSubview(titleLabel)
        container.addSubview(checkImage)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        checkImage.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkImage.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            checkImage.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkImage.widthAnchor.constraint(equalToConstant: 16),
            checkImage.heightAnchor.constraint(equalToConstant: 16)
        ])

        container.isUserInteractionEnabled = true
        return container
    }

    @objc private func bubbleEnhancedTapped() {
        DTMeetingManager.shared.roomContext?.setAudioModule(.deepfilternet)
        dismissBubble()
        reloadDenoiseModeRow()
    }

    @objc private func bubbleStandardTapped() {
        DTMeetingManager.shared.roomContext?.setAudioModule(.rnnoise)
        dismissBubble()
        reloadDenoiseModeRow()
    }

    private func reloadDenoiseModeRow() {
        let sectionIndex = tableView.numberOfSections - 1
        guard sectionIndex >= 0, tableView.numberOfRows(inSection: sectionIndex) > 1 else { return }
        tableView.reloadRows(at: [IndexPath(row: 1, section: sectionIndex)], with: .none)
    }

    private func reloadVoiceChangerRow() {
        let sectionIndex = tableView.numberOfSections - 1
        guard sectionIndex >= 0, tableView.numberOfRows(inSection: sectionIndex) > 2 else { return }
        tableView.reloadRows(at: [IndexPath(row: 2, section: sectionIndex)], with: .none)
    }

    // MARK: - Voice Changer

    func voiceChangerHeaderCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.clipsToBounds = false
        cell.contentView.clipsToBounds = false

        let rowLabel = UILabel()
        rowLabel.text = Localized("CALLING_VOICE_CHANGER_TITLE")
        rowLabel.textColor = UIColor.white
        rowLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)

        let currentPreset = DTMeetingManager.shared.roomContext?.currentVoicePreset() ?? "original"
        let presetInfo = Self.voicePresets.first(where: { $0.key == currentPreset }) ?? Self.voicePresets[0]
        let localizedName = Localized(presetInfo.nameKey)
        let displayText = presetInfo.emoji.isEmpty ? localizedName : "\(presetInfo.emoji) \(localizedName)"

        let valueLabel = UILabel()
        valueLabel.text = displayText
        valueLabel.textColor = UIColor(rgbHex: 0xB7BDC6)
        valueLabel.font = UIFont.systemFont(ofSize: 14)

        let arrowImage = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowImage.tintColor = UIColor(rgbHex: 0x9CA3AF)
        arrowImage.contentMode = .scaleAspectFit
        arrowImage.translatesAutoresizingMaskIntoConstraints = false
        arrowImage.widthAnchor.constraint(equalToConstant: 14).isActive = true
        arrowImage.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let rightStack = UIStackView(arrangedSubviews: [valueLabel, arrowImage])
        rightStack.axis = .horizontal
        rightStack.spacing = 4
        rightStack.alignment = .center

        let contentRow = UIStackView(arrangedSubviews: [rowLabel, rightStack])
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.backgroundColor = UIColor(rgbHex: 0x474D57)
        contentRow.layer.cornerRadius = 8
        contentRow.isLayoutMarginsRelativeArrangement = true
        contentRow.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleVoiceChangerBubble))
        contentRow.addGestureRecognizer(tap)

        cell.contentView.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12))
        return cell
    }

    @objc private func toggleVoiceChangerBubble() {
        if voiceBubbleView != nil {
            dismissVoiceChangerBubble()
            return
        }
        showVoiceChangerBubble()
    }

    private func showVoiceChangerBubble() {
        dismissVoiceChangerBubble()

        let currentPreset = DTMeetingManager.shared.roomContext?.currentVoicePreset() ?? "original"

        let bubble = UIView()
        bubble.backgroundColor = UIColor(rgbHex: 0x3C4249)
        bubble.layer.cornerRadius = 8
        bubble.layer.shadowColor = UIColor.black.cgColor
        bubble.layer.shadowOpacity = 0.4
        bubble.layer.shadowRadius = 8
        bubble.layer.shadowOffset = CGSize(width: 0, height: 2)

        var rows: [UIView] = []
        for (index, preset) in Self.voicePresets.enumerated() {
            let localizedName = Localized(preset.nameKey)
            let displayText = preset.emoji.isEmpty ? localizedName : "\(preset.emoji) \(localizedName)"
            let row = makeBubbleRow(title: displayText, isSelected: preset.key == currentPreset)
            row.tag = index
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(voicePresetTapped(_:))))
            rows.append(row)
        }

        var arrangedSubviews: [UIView] = []
        for (i, row) in rows.enumerated() {
            arrangedSubviews.append(row)
            if i < rows.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor.white.withAlphaComponent(0.12)
                separator.tag = 9999
                arrangedSubviews.append(separator)
            }
        }

        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.axis = .vertical
        stack.spacing = 0
        bubble.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint] = [
            stack.topAnchor.constraint(equalTo: bubble.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bubble.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
        ]
        for view in arrangedSubviews {
            if view.tag == 9999 {
                constraints.append(view.heightAnchor.constraint(equalToConstant: 0.5))
            } else {
                constraints.append(view.heightAnchor.constraint(equalToConstant: 44))
            }
        }
        NSLayoutConstraint.activate(constraints)

        guard let window = view.window else { return }

        let backdrop = UIView()
        backdrop.backgroundColor = .clear
        backdrop.frame = window.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(voiceBubbleBackdropTapped)))
        window.addSubview(backdrop)
        self.voiceBubbleBackdrop = backdrop

        bubble.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(bubble)

        let lastSection = tableView.numberOfSections - 1
        let lastRow = tableView.numberOfRows(inSection: lastSection) - 1
        guard lastSection >= 0, lastRow >= 0,
              let cell = tableView.cellForRow(at: IndexPath(row: lastRow, section: lastSection))
        else { return }

        let cellFrameInWindow = cell.convert(cell.bounds, to: window)
        NSLayoutConstraint.activate([
            bubble.widthAnchor.constraint(equalToConstant: 180),
            bubble.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -24),
            bubble.bottomAnchor.constraint(equalTo: window.topAnchor, constant: cellFrameInWindow.minY - 8)
        ])

        bubble.alpha = 0
        bubble.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.2) {
            bubble.alpha = 1
            bubble.transform = .identity
        }

        self.voiceBubbleView = bubble
    }

    @objc private func voiceBubbleBackdropTapped() {
        dismissVoiceChangerBubble()
    }

    private func dismissVoiceChangerBubble() {
        voiceBubbleBackdrop?.removeFromSuperview()
        voiceBubbleBackdrop = nil

        guard let bubble = voiceBubbleView else { return }
        UIView.animate(withDuration: 0.15, animations: {
            bubble.alpha = 0
            bubble.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            bubble.removeFromSuperview()
        }
        voiceBubbleView = nil
    }

    @objc private func voicePresetTapped(_ gesture: UITapGestureRecognizer) {
        guard let index = gesture.view?.tag, index < Self.voicePresets.count else { return }
        let preset = Self.voicePresets[index]
        DTMeetingManager.shared.roomContext?.setVoiceChangerPreset(preset.key)
        dismissVoiceChangerBubble()
        reloadVoiceChangerRow()
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
