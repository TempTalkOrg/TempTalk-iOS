//
//  DTMultiSelectToolbar.swift
//  Wea
//
//  Created by Ethan on 2021/12/15.
//

import UIKit
import SnapKit
import TTMessaging

struct DTMultiSelectToolbarItem {
    let imageName: String
    let title: String
    let isRecallButton: Bool

    init(imageName: String, title: String, isRecallButton: Bool = false) {
        self.imageName = imageName
        self.title = title
        self.isRecallButton = isRecallButton
    }
}

protocol DTMultiSelectToolbarDelegate: AnyObject {
    func multiSelectToolbar(_: DTMultiSelectToolbar, didSelectIndex index: Int)
    func items(for multiSelectToolBar: DTMultiSelectToolbar) -> [DTMultiSelectToolbarItem]
}

class DTMultiSelectToolbar: UIView {

    let kToolbarHeight = 49.0
    private var backgroundColor_: UIColor {
        get {
            Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x1C1C1C) : UIColor(rgbHex: 0xF5F5F5)
        }
    }
    
    private let actionStackView: UIStackView
    private let blurEffectView: UIVisualEffectView
    private let topLine: UIView
    private var actionItems = [ToolBarActionButton]()
    private var verticalConstraint: NSLayoutConstraint?
    var superView: UIView?
    
    private lazy var totalCountLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10)
        label.textColor = Theme.tprimaryColor
        label.backgroundColor = Theme.bg2Color
        return label
    }()
    
    weak var delegate: DTMultiSelectToolbarDelegate?
        
    override init(frame: CGRect) {
        
        actionStackView = UIStackView()
        actionStackView.axis = .horizontal
        actionStackView.distribution = .fillEqually
        actionStackView.alignment = .fill
        
        blurEffectView = UIVisualEffectView(effect: Theme.barBlurEffect)
        
        topLine = UIView()
        topLine.backgroundColor = Theme.lineColor
        
        super.init(frame: frame)

        autoresizingMask = .flexibleHeight
        
        addSubview(blurEffectView)
        blurEffectView.backgroundColor = Theme.bg1Color
        blurEffectView.contentView.addSubview(topLine)
        blurEffectView.contentView.addSubview(totalCountLabel)
        blurEffectView.contentView.addSubview(actionStackView)
        
        blurEffectView.autoPinEdgesToSuperviewEdges()
        
        topLine.autoSetDimension(.height, toSize: CGHairlineWidth())
        topLine.autoPinEdge(toSuperviewEdge: .top)
        topLine.autoPinEdge(toSuperviewEdge: .leading)
        topLine.autoPinEdge(toSuperviewEdge: .trailing)
        
        totalCountLabel.autoSetDimension(.height, toSize: 20)
        totalCountLabel.autoPinEdge(.top, to: .bottom, of: topLine, withOffset: 0)
        totalCountLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
        totalCountLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)
        
        actionStackView.autoSetDimension(.height, toSize: 44)
        actionStackView.autoPinEdge(.top, to: .bottom, of: totalCountLabel, withOffset: 16)
        actionStackView.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        actionStackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        actionStackView.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 16)
        
        blurEffectView.autoPinEdge(toSuperviewEdge: .leading)
        blurEffectView.autoPinEdge(toSuperviewEdge: .trailing)
        verticalConstraint = blurEffectView.autoPinEdge(.bottom, to: .bottom, of: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        .zero
    }
    
    func reloadContents() {
        actionStackView.arrangedSubviews.forEach {
            $0.removeFromSuperview()
        }
        actionItems.removeAll()

        guard let items = delegate?.items(for: self), !items.isEmpty else {
            return
        }
        for i in 0...items.count - 1 {
            let item = items[i]
            let actionItem = ToolBarActionButton(type: .custom)
            actionItem.tag = i
            actionItem.isRecallButton = item.isRecallButton
            let btnImage = UIImage(named: item.imageName)?.withRenderingMode(.alwaysTemplate)
            actionItem.setImage(btnImage, for: .normal)
            actionItem.setImage(btnImage, for: .highlighted)
            actionItem.setTitle(item.title, for: .normal)
            actionItem.setTitle(item.title, for: .highlighted)
            actionItem.tintColor = item.isRecallButton ? Theme.terrorColor : Theme.tsecondaryColor
            actionItem.addTarget(self, action: #selector(toolbarItemsAction(_:)), for: .touchUpInside)
            actionStackView.addArrangedSubview(actionItem)
            actionItems.append(actionItem)
        }
    }
    
    @objc
    func toolbarItemsAction(_ btnAction: UIButton) {
        delegate?.multiSelectToolbar(self, didSelectIndex: btnAction.tag)
    }
    
    public func applyTheme() {
        blurEffectView.backgroundColor = Theme.bg1Color
        blurEffectView.effect = Theme.barBlurEffect
        topLine.backgroundColor = Theme.lineColor
        totalCountLabel.textColor = Theme.tprimaryColor
        totalCountLabel.backgroundColor = Theme.bg2Color

        actionItems.forEach {
            $0.tintColor = $0.isRecallButton ? Theme.terrorColor : Theme.tsecondaryColor
            $0.applyTheme()
        }
    }
        
    /// 更新item的数字和enable状态
    /// - Parameters:
    ///   - selectedCount: 选择消息数量
    ///   - enableCounts: enable最低支持数量，一一对应
    ///   - recallableCount: 可撤回消息数量
    func updateActionItemsSelectedCount(_ selectedCount: UInt, maxCount: UInt, enableCounts: [NSNumber], recallableCount: UInt = 0) {

        totalCountLabel.text = "\(selectedCount)/\(maxCount) \(Localized("LONG_TEXT_VIEW_TITLE"))"

        for (idx, item) in actionItems.enumerated() {
            let enableCount = enableCounts[idx].uintValue
            let isEnabled = selectedCount > enableCount - 1
            item.isEnabled = isEnabled

            // Update recall button title with count
            if item.isRecallButton {
                item.updateRecallCount(recallableCount)
                // Update tint color based on enabled state
                item.tintColor = isEnabled ? Theme.terrorColor : Theme.tdisableColor
            }
        }
    }
    
    public func showIn(_ superview: UIView) {
        superView = superview
        superView?.addSubview(self)
        
        reloadContents()
        
        autoPinEdge(toSuperviewEdge: .leading)
        autoPinEdge(toSuperviewEdge: .trailing)
        autoPinEdge(toSuperviewEdge: .bottom)
        self.layoutIfNeeded()
        
        NSLayoutConstraint.deactivate([verticalConstraint!])
        verticalConstraint = blurEffectView.autoPinEdge(toSuperviewEdge: .bottom)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 15.0, options: .curveEaseOut) {
            self.layoutIfNeeded()
        } completion: { _ in
            self.autoPinHeight(toHeightOf: self.blurEffectView)
        }
    }

    public func hide(animated: Bool) {
        
        NSLayoutConstraint.deactivate([verticalConstraint!])
        verticalConstraint = blurEffectView.autoPinEdge(.top, to: .bottom, of: self)
        if !animated {
            self.removeFromSuperview()
        } else {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 15.0, options: .curveEaseOut) {
                self.layoutIfNeeded()
            } completion: { _ in
                self.removeFromSuperview()
            }
        }
    }
}

private class ToolBarActionButton: UIButton {

    var isRecallButton: Bool = false
    private var baseTitle: String = ""
    private var recallCount: UInt = 0

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel?.textAlignment = .center
        titleLabel?.font = .ows_dynamicTypeFootnote
        titleLabel?.numberOfLines = 2
        titleLabel?.lineBreakMode = .byWordWrapping

        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setTitle(_ title: String?, for state: UIControl.State) {
        if state == .normal, let title = title {
            baseTitle = title
        }
        super.setTitle(title, for: state)
    }

    func updateRecallCount(_ count: UInt) {
        recallCount = count
        if isRecallButton && count > 0 {
            let titleWithCount = "\(baseTitle)(\(count))"
            super.setTitle(titleWithCount, for: .normal)
            super.setTitle(titleWithCount, for: .highlighted)
        } else {
            super.setTitle(baseTitle, for: .normal)
            super.setTitle(baseTitle, for: .highlighted)
        }
        // Update title color after changing title
        applyTheme()
    }

    func applyTheme() {
        if isRecallButton {
            setTitleColor(Theme.terrorColor, for: .normal)
        } else {
            setTitleColor(Theme.tsecondaryColor, for: .normal)
        }
        setTitleColor(Theme.tdisableColor, for: .disabled)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView?.frame = CGRectMake((self.width - 24) * 0.5, 0, 24, 24)

        if let titleLabel = titleLabel {
            let maxSize = CGSize(width: self.width, height: CGFloat.greatestFiniteMagnitude)
            let size = titleLabel.sizeThatFits(maxSize)
            titleLabel.frame = CGRectMake(0, 28, self.width, size.height)
        }
    }
}
