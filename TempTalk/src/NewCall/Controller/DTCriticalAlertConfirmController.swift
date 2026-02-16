//
//  DTCriticalAlertConfirmController.swift
//  Difft
//
//  Created by henry on 2026/01/29.
//  Copyright © 2026 Difft. All rights reserved.
//

import TTServiceKit
import TTMessaging
import PanModal

// MARK: - 自定义气泡提示视图（支持动态箭头位置）

class CriticalAlertBubbleTipView: UIView {
    private let label = UILabel()
    private let backgroundView = UIView()
    private let triangleView = CriticalAlertTriangleView()
    private var arrowOffsetConstraint: NSLayoutConstraint?

    init(text: String, arrowOffset: CGFloat = 0) {
        super.init(frame: .zero)

        backgroundColor = .clear

        // 气泡背景
        backgroundView.backgroundColor = UIColor(rgbHex: 0x5E6673)
        backgroundView.layer.cornerRadius = 8
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        // 文本
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        // 箭头
        triangleView.fillColor = UIColor(rgbHex: 0x5E6673)
        triangleView.direction = .up
        triangleView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(triangleView)
        addSubview(backgroundView)
        backgroundView.addSubview(label)

        // 箭头位置约束（可动态调整）- 使用 centerX 来精确对齐
        arrowOffsetConstraint = triangleView.centerXAnchor.constraint(equalTo: trailingAnchor, constant: arrowOffset)

        NSLayoutConstraint.activate([
            triangleView.topAnchor.constraint(equalTo: topAnchor),
            arrowOffsetConstraint!,
            triangleView.widthAnchor.constraint(equalToConstant: 14),
            triangleView.heightAnchor.constraint(equalToConstant: 8),

            backgroundView.topAnchor.constraint(equalTo: triangleView.bottomAnchor, constant: -2),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            label.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class CriticalAlertTriangleView: UIView {
    enum Direction {
        case up, down
    }

    var fillColor: UIColor = UIColor(rgbHex: 0x5E6673)
    var direction: Direction = .up

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let path = UIBezierPath()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        case .down:
            path.move(to: CGPoint(x: bounds.midX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
        }
        path.close()

        context.setFillColor(fillColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    }
}

// MARK: - DTCriticalAlertConfirmController


@objcMembers
class DTCriticalAlertConfirmController: OWSTableViewController {

    private var tipsButton: UIButton?
    private var currentBubble: CriticalAlertBubbleTipView?
    private let invitedUserIds: [String]
    private let callType: CallType

    init(invitedUserIds: [String], callType: CallType) {
        self.invitedUserIds = invitedUserIds
        self.callType = callType
        super.init()
    }

    override func loadView() {
        super.loadView()
        self.createViews()
    }

    func createViews() {
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 200
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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 移除气泡（无论是通过按钮还是点击背景关闭）
        currentBubble?.removeFromSuperview()
        currentBubble = nil
    }

    func updateTableContents() {
        let contents = OWSTableContents()

        // 标题和描述 Section
        let headerSection = OWSTableSection()
        headerSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.headerCell() ?? UITableViewCell()
        }, customRowHeight: UITableView.automaticDimension, actionBlock: {}))
        contents.addSection(headerSection)

        // 按钮 Section
        let buttonSection = OWSTableSection()
        buttonSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.buttonCell() ?? UITableViewCell()
        }, customRowHeight: 70, actionBlock: {}))
        contents.addSection(buttonSection)

        self.contents = contents
    }

    func headerCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = Localized("CRITICAL_ALERT_CONFIRM_TITLE") // "Critical Alert"
        titleLabel.textColor = UIColor(rgbHex: 0xEAECEF)
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        // 提示按钮
        let tipsButton = UIButton(type: .custom)
        tipsButton.setImage(UIImage(named: "critical_alert_confirm_tips"), for: .normal)
        tipsButton.addTarget(self, action: #selector(tipsButtonTapped), for: .touchUpInside)
        tipsButton.autoSetDimensions(to: CGSize(width: 24, height: 24))
        self.tipsButton = tipsButton

        // 标题和提示按钮的水平布局
        let titleRow = UIStackView(arrangedSubviews: [titleLabel, tipsButton])
        titleRow.axis = .horizontal
        titleRow.spacing = 8
        titleRow.alignment = .center

        // 描述
        let descLabel = UILabel()
        descLabel.text = generateDescriptionText()
        descLabel.textColor = UIColor(rgbHex: 0xB7BDC6)
        descLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0

        // 垂直布局
        let stackView = UIStackView(arrangedSubviews: [titleRow, descLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center

        cell.contentView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20))

        return cell
    }

    func buttonCell() -> UITableViewCell {
        let cell = OWSTableItem.newCell()
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true
        cell.separatorInset = UIEdgeInsets(top: 0, left: UIScreen.main.bounds.size.width, bottom: 0, right: 0)
        cell.selectionStyle = .none
        cell.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cell.contentView.backgroundColor = UIColor(rgbHex: 0x2B3139)

        // Cancel 按钮
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(Localized("CRITICAL_ALERT_CANCEL"), for: .normal) // "Cancel"
        cancelButton.setTitleColor(UIColor.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.backgroundColor = UIColor(rgbHex: 0x2B3139)
        cancelButton.layer.cornerRadius = 8
        cancelButton.layer.borderWidth = 1
        cancelButton.layer.borderColor = UIColor(rgbHex: 0x474D57).cgColor
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        // Send 按钮
        let sendButton = UIButton(type: .system)
        sendButton.setTitle(Localized("CRITICAL_ALERT_SEND"), for: .normal) // "Send"
        sendButton.setTitleColor(UIColor.white, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        sendButton.backgroundColor = UIColor(rgbHex: 0x056FFA)
        sendButton.layer.cornerRadius = 8
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)

        // 水平布局
        let stackView = UIStackView(arrangedSubviews: [cancelButton, sendButton])
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually

        cell.contentView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12, left: 20, bottom: 6, right: 20))

        // 按钮高度约束
        cancelButton.autoSetDimension(.height, toSize: 40)
        sendButton.autoSetDimension(.height, toSize: 40)

        return cell
    }

    private func generateDescriptionText() -> String {
        let contactsManager = Environment.shared.contactsManager

        // 获取用户显示名称
        let displayNames = invitedUserIds.compactMap { userId in
            contactsManager?.displayName(forPhoneIdentifier: userId)
        }

        switch callType {
        case .instant:
            // Instant: Send to [最多3人名] and [剩余人数] more
            if displayNames.isEmpty {
                return Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT_EMPTY")
            }

            let maxDisplayCount = 3
            let displayedNames = Array(displayNames.prefix(maxDisplayCount))
            let remainingCount = displayNames.count - displayedNames.count

            let namesText = displayedNames.joined(separator: ", ")

            if remainingCount > 0 {
                return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT_WITH_MORE"), namesText, remainingCount + maxDisplayCount)
            } else {
                return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT"), namesText)
            }

        case .group:
            // Group: 根据是否有邀请人显示不同文案
            if displayNames.isEmpty {
                // 只有群成员
                return Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP")
            } else {
                // 群成员 + 邀请人
                let maxDisplayCount = 3
                let displayedNames = Array(displayNames.prefix(maxDisplayCount))
                let remainingCount = displayNames.count - displayedNames.count

                let namesText = displayedNames.joined(separator: ", ")

                if remainingCount > 0 {
                    return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP_WITH_INVITED_MORE"), namesText, remainingCount + maxDisplayCount)
                } else {
                    return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP_WITH_INVITED"), namesText)
                }
            }

        default:
            return Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP")
        }
    }

    @objc private func tipsButtonTapped() {
        guard let tipsButton = self.tipsButton,
              let window = self.view.window else { return }

        // 如果气泡已存在，则隐藏它（toggle off）
        if let existingBubble = self.currentBubble {
            UIView.animate(withDuration: 0.25, animations: {
                existingBubble.alpha = 0
            }) { _ in
                existingBubble.removeFromSuperview()
                self.currentBubble = nil
            }
            return
        }

        // 将 tipsButton 的坐标转换到 window
        let tipFrame = tipsButton.convert(tipsButton.bounds, to: window)
        let buttonCenterX = tipFrame.midX

        // 气泡右边缘距离屏幕右边缘 20pt
        let bubbleTrailing = window.bounds.width - 20

        // 计算箭头偏移：箭头中心应该对准按钮中心
        // arrowOffset 是箭头距离气泡右边缘的距离（负值表示向左）
        let arrowOffset = buttonCenterX - bubbleTrailing

        // 创建气泡
        let bubble = CriticalAlertBubbleTipView(text: Localized("CRITICAL_ALERT_CONFIRM_TIPS_MESSAGE"), arrowOffset: arrowOffset)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(bubble)
        window.bringSubviewToFront(bubble)

        // 保存气泡引用
        self.currentBubble = bubble

        NSLayoutConstraint.activate([
            bubble.trailingAnchor.constraint(equalTo: window.leadingAnchor, constant: bubbleTrailing),
            bubble.topAnchor.constraint(equalTo: window.topAnchor, constant: tipFrame.maxY)
        ])

        bubble.alpha = 0
        UIView.animate(withDuration: 0.25) {
            bubble.alpha = 1
        }
    }

    @objc private func cancelButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func sendButtonTapped() {
        self.dismiss(animated: true) { [weak self] in
            guard self != nil else { return }
            Task {
                await DTMeetingManager.shared.sendCriticalAlert(
                    message: Localized("MEETING_CRITICAL_ALERT_DANMU")
                )
            }
        }
    }
}

extension DTCriticalAlertConfirmController: PanModalPresentable {
    var panScrollable: UIScrollView? {
        return tableView
    }

    var shortFormHeight: PanModalHeight {
        return .intrinsicHeight
    }

    var longFormHeight: PanModalHeight {
        return .intrinsicHeight
    }
}
