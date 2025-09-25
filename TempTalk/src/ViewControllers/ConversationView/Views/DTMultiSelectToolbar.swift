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
    var superView: UIView!
    
    private lazy var totalCountLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 10)
        label.textColor = Theme.primaryTextColor
        label.backgroundColor = Theme.stickBackgroundColor
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
        topLine.backgroundColor = Theme.hairlineColor
        
        super.init(frame: frame)

        autoresizingMask = .flexibleHeight
        
        addSubview(blurEffectView)
        blurEffectView.backgroundColor = Theme.backgroundColor
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
            let btnImage = UIImage(named: item.imageName)?.withRenderingMode(.alwaysTemplate)
            actionItem.setImage(btnImage, for: .normal)
            actionItem.setImage(btnImage, for: .highlighted)
            actionItem.setTitle(item.title, for: .normal)
            actionItem.setTitle(item.title, for: .highlighted)
            actionItem.tintColor = Theme.tabbarTitleNormalColor
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
        blurEffectView.backgroundColor = Theme.backgroundColor
        blurEffectView.effect = Theme.barBlurEffect
        topLine.backgroundColor = Theme.hairlineColor
        totalCountLabel.textColor = Theme.primaryTextColor
        totalCountLabel.backgroundColor = Theme.stickBackgroundColor
        
        actionItems.forEach {
            $0.tintColor = Theme.tabbarTitleNormalColor
        }
    }
        
    /// 更新item的数字和enable状态
    /// - Parameters:
    ///   - selectedCount: 选择消息数量
    ///   - enableCounts: enable最低支持数量，一一对应
    func updateActionItemsSelectedCount(_ selectedCount: UInt, maxCount: UInt, enableCounts: [NSNumber]) {
        
        totalCountLabel.text = "\(selectedCount)/\(maxCount) \(Localized("LONG_TEXT_VIEW_TITLE"))"
        
        for (idx, item) in actionItems.enumerated() {
            let enableCount = enableCounts[idx].uintValue
            item.isEnabled = selectedCount > enableCount - 1
        }
    }
    
    public func showIn(_ superview: UIView) {
        superView = superview
        superView.addSubview(self)
        
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel?.textAlignment = .center
        titleLabel?.font = .ows_dynamicTypeFootnote
        
        applyTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyTheme() {
        setTitleColor(Theme.tabbarTitleNormalColor, for: .normal)
        setTitleColor(Theme.thirdTextAndIconColor, for: .disabled)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.frame = CGRectMake((self.width - 24) * 0.5, 0, 24, 24)
        
        titleLabel?.sizeToFit()
        titleLabel?.frame = CGRectMake(0, 28, self.width, titleLabel?.height ?? 0)
    }
}
