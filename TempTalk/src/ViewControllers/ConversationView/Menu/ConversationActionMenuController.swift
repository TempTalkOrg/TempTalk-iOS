//
//  ConversationActionMenuController.swift
//  Difft
//
//  Created by Jaymin on 2024/6/14.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SnapKit
import TTMessaging
import TTServiceKit

class ConversationActionMenuController: OWSViewController {
    
    typealias ArrowDirection = ConversationActionMenuContainerView.ArrowDirection
    
    enum Constants {
        static let navigationBarHeight: CGFloat = 44
        static let inputBarHeight: CGFloat = 94
        static let containerViewMarginTop: CGFloat = 2
    }
    
    private var actions: [MenuAction]
    private var emojiAction: MenuEmojiAction?
    private let sourceView: UIView
    private let sourceViewController: UIViewController
    private var textSelectionView: DTTextSelectionView?
    
    private var lineView: UIView?
    private var moreEmojiButton: UIButton?
    private var actionButtons: [ActionButton] = []
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    private lazy var containerView = ConversationActionMenuContainerView()
    
    private var contentSize: CGSize = .zero
    
    private var sourceViewFrame: CGRect {
        self.view.convert(sourceView.frame, fromViewOrWindow: sourceView.superview)
    }
    
    private let screenWidth = UIScreen.main.bounds.size.width
    private let screenHeight = UIScreen.main.bounds.size.height

    private var safeAreaInsets: UIEdgeInsets {
        let keyWindow = UIApplication.shared.windows.last { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets ?? .zero
    }
    
    // 屏幕可见区域的垂直方向范围
    private lazy var visibleRange: (top: CGFloat, bottom: CGFloat) = {
        let visibleAreaTop: CGFloat = safeAreaInsets.top + Constants.navigationBarHeight
        let visibleAreaBottom: CGFloat = screenHeight - safeAreaInsets.bottom - Constants.inputBarHeight
        return (visibleAreaTop, visibleAreaBottom)
    }()
    
    // 记录 TextView 是否选中了全部的文本
    var isSelectedAll = false
    
    private var isNeedCloseAfterScroll = false
    
    var dismissHandler: (() -> Void)?
    
    init(
        actions: [MenuAction],
        emojiAction: MenuEmojiAction?,
        sourceView: UIView,
        sourceViewController: UIViewController,
        textSelectionView: DTTextSelectionView? = nil
    ) {
        self.actions = actions
        self.emojiAction = emojiAction
        self.sourceView = sourceView
        self.sourceViewController = sourceViewController
        self.textSelectionView = textSelectionView
        super.init()
    }
    
    override func loadView() {
        self.view = HitTestView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configueView()
        refreshContainerView()
    }
    
    func update(actions: [MenuAction], emojiAction: MenuEmojiAction?) {
        self.actions = actions
        self.emojiAction = emojiAction
        
        contentSize = .zero
        actionButtons.removeAll()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        moreEmojiButton = nil
        lineView = nil
        
        refreshContainerView()
    }
    
    // 隐藏菜单（并不是关闭 dismiss，还在屏幕上，只是不显示）
    func hideMenu(animation: Bool) {
        guard containerView.alpha > 0 else { return }
        if animation {
            UIView.animate(withDuration: 0.35, delay: 0) {
                self.containerView.alpha = 0
            }
        } else {
            self.containerView.alpha = 0
        }
    }
    
    // 显示菜单
    func showMenu(animation: Bool) {
        guard containerView.alpha == 0 else { return }
        
        guard !isNeedCloseAfterScroll else {
            dismissMenu(animation: false)
            return
        }
        
        refreshContainerViewFrame()
        
        if animation {
            UIView.animate(withDuration: 0.35, delay: 0) {
                self.containerView.alpha = 1.0
            }
        } else {
            self.containerView.alpha = 1.0
        }
    }
    
    // 根据 sourceView 位置判断是否需要关闭弹窗
    func dismissMenuIfNeed(offset: CGFloat) {
        var sourceViewFrame = self.sourceViewFrame
        sourceViewFrame.y = sourceViewFrame.y - offset
        if sourceViewFrame.y > visibleRange.bottom || CGRectGetMaxY(sourceViewFrame) < visibleRange.top {
            isNeedCloseAfterScroll = true
        } else {
            isNeedCloseAfterScroll = false
        }
    }
    
    // 关闭菜单
    func dismissMenu(animation: Bool, completion: (() -> Void)? = nil) {
        dismissHandler?()
        dismiss(animated: animation, completion: completion)
    }
    
    private func configueView() {
        view.backgroundColor = .clear
        
        if let hitTestView = view as? HitTestView {
            hitTestView.hitTestBlock = { [weak self] point, event in
                guard let self else { return .default }
                return self.hitTest(point: point, event: event)
            }
        }
        
        view.addSubview(containerView)
        containerView.addSubview(contentView)
    }
    
    private func hitTest(point: CGPoint, event: UIEvent?) -> HitTestView.Result {
        // 如果在 containerView 范围内，交给 containerView 自行处理
        if CGRectContainsPoint(containerView.frame, point) {
            return .default
        }
        
        let sourceViewFrame = self.sourceViewFrame
        // 由于光标实际上会超出 sourceView 范围，为了能使光标响应事件，增加可响应范围
        let fixedSpacing: CGFloat = 5
        let fixedSourceViewFrame = CGRect(
            x: sourceViewFrame.x,
            y: sourceViewFrame.y - fixedSpacing,
            width: sourceViewFrame.width,
            height: sourceViewFrame.height + fixedSpacing * 2
        )
        // 如果在 sourceView 范围内，交给 sourceViewController (ConversationViewController) 处理
        // 不直接让 sourceView 处理，是因为光标可能超过 sourceView 范围
        if CGRectContainsPoint(fixedSourceViewFrame, point) {
            let convertedPoint = sourceViewController.view.convert(point, from: self.view)
            let res = sourceViewController.view.hitTest(convertedPoint, with: event)
            return .specified(res)
            
        // 不在上述范围内，让 sourceViewController 响应事件（为了不影响滑动空白区域），并关闭弹窗
        } else {
            // 延迟是为防止在返回 hitTest view 之前关闭会导致事件不能正常响应
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.dismissHandler?()
                self.dismiss(animated: false)
            }
            let convertedPoint = sourceViewController.view.convert(point, from: self.view)
            let res = sourceViewController.view.hitTest(convertedPoint, with: event)
            return .specified(res)
        }
    }
    
    private func refreshContainerView() {
        guard !actions.isEmpty else { return }
        
        // 最多展示 5 个 action
        let maxCountOfActions = 5
        let countOfActions = 5
        let contentViewWidth = ActionButton.buttonWidth * CGFloat(countOfActions) + ActionButton.buttonMargin * CGFloat(countOfActions - 1)
        var contentViewHeight: CGFloat = 0
        
        // emojis，最多展示 4 个 emoji + more
        if let emojiAction, !emojiAction.emojis.isEmpty {
            let emojiStackView = UIStackView()
            emojiStackView.axis = .horizontal
            emojiStackView.distribution = .equalSpacing

            emojiAction.emojis.prefix(4).forEach { emoji in
                let button = EmojiButton()
                button.emoji = emoji
                button.isSelected = emojiAction.selectedEmojis.contains(emoji)
                button.didTapHandler = { [weak self] in
                    self?.dismissHandler?()
                    emojiAction.block(emoji)
                    self?.dismiss(animated: true)
                }
                emojiStackView.addArrangedSubview(button)
                button.snp.makeConstraints { make in
                    make.width.equalTo(EmojiButton.buttonSize)
                }
            }
            let moreButton = UIButton()
            let moreImage = UIImage(named: "ic_select_more_emoji")?.withRenderingMode(.alwaysTemplate)
            moreButton.setImage(moreImage, for: .normal)
            moreButton.addTarget(self, action: #selector(didTapSelectMoreEmojiButton), for: .touchUpInside)
            emojiStackView.addArrangedSubview(moreButton)
            moreButton.snp.makeConstraints { make in
                make.width.equalTo(EmojiButton.buttonSize)
            }
            self.moreEmojiButton = moreButton
            
            contentView.addSubview(emojiStackView)
            let emojiStackViewLeft: CGFloat = 6
            let emojiStackViewWidth = contentViewWidth - emojiStackViewLeft * 2
            emojiStackView.frame = CGRect(x: emojiStackViewLeft, y: 10, width: emojiStackViewWidth, height: EmojiButton.buttonSize)
            
            let lineView = UIView()
            contentView.addSubview(lineView)
            lineView.frame = CGRect(x: 0, y: CGRectGetMaxY(emojiStackView.frame) + 10, width: contentViewWidth, height: 1.0)
            self.lineView = lineView
            
            contentViewHeight = CGRectGetMaxY(lineView.frame)
        }
        
        // actions，最多展示 5 个，超过 5 个时展示 4 个 action + more
        contentViewHeight += 16
        let isNeedShowMore = actions.count > maxCountOfActions
        let prefix = isNeedShowMore ? maxCountOfActions - 1 : actions.count
        actions.prefix(prefix).enumerated().forEach { index, action in
            let button = ActionButton()
            button.action = action
            button.addTarget(self, action: #selector(actionButtonDidTap(_:)), for: .touchUpInside)
            contentView.addSubview(button)
            actionButtons.append(button)
            
            let buttonLeft = CGFloat(index) * (ActionButton.buttonWidth + ActionButton.buttonMargin)
            button.frame = CGRectMake(buttonLeft, contentViewHeight, ActionButton.buttonWidth, ActionButton.buttonHeight)
        }
        if isNeedShowMore {
            let moreAction = MenuAction(
                image: #imageLiteral(resourceName: "ic_longpress_more").withRenderingMode(.alwaysTemplate),
                title: Localized("MENU_ACTION_MORE_ACTION"),
                subtitle: nil,
                dismissBeforePerformAction: false
            ) { [weak self] _ in
                self?.didTapSelectMoreActionButton()
            }
            let moreActionButton = ActionButton()
            moreActionButton.action = moreAction
            moreActionButton.addTarget(self, action: #selector(actionButtonDidTap(_:)), for: .touchUpInside)
            contentView.addSubview(moreActionButton)
            let moreActionButtonLeft = CGFloat(actionButtons.count) * (ActionButton.buttonWidth + ActionButton.buttonMargin)
            moreActionButton.frame = CGRectMake(
                moreActionButtonLeft,
                contentViewHeight,
                ActionButton.buttonWidth,
                ActionButton.buttonHeight
            )
            actionButtons.append(moreActionButton)
        }
        contentViewHeight += ActionButton.buttonHeight + 16
        
        self.contentSize = CGSize(width: contentViewWidth, height: contentViewHeight)
        
        refreshContainerViewFrame()
        
        applyTheme()
    }
    
    private func refreshContainerViewFrame() {
        guard !CGSizeEqualToSize(contentSize, .zero) else { return }
        
        let arrowHeight = ConversationActionMenuContainerView.arrowHeight
        let containerViewPaddingH: CGFloat = 8
        let containerViewWidth = contentSize.width + containerViewPaddingH * 2
        let containerViewHeight = contentSize.height + arrowHeight
        let sourceViewFrame = self.sourceViewFrame
        
        // 1.计算 sourceRect，如果存在光标（textSelectionView != nil），根据光标位置计算 sourceRect，否则根据 sourceViewFrame 计算
        var sourceRect: CGRect = sourceViewFrame
        
        // 根据光标位置计算 sourceRect
        if let textSelectionView {
            
            let selectionViewFrame = textSelectionView.convert(textSelectionView.bounds, toViewOrWindow: self.view)
            let leftKnobFrame = textSelectionView.convert(textSelectionView.getLeftKnobFrame(), toViewOrWindow: self.view)
            let rightKnobFrame = textSelectionView.convert(textSelectionView.getRightKnobFrame(), toViewOrWindow: self.view)
            
            // 左光标是否在屏幕可视范围内
            let leftKnobIsOnWindow = CGRectGetMaxY(leftKnobFrame) > visibleRange.top && leftKnobFrame.y < visibleRange.bottom
            // 右光标是否在屏幕可视范围内
            let rightKnobIsOnWindow = CGRectGetMaxY(rightKnobFrame) > visibleRange.top && rightKnobFrame.y < visibleRange.bottom
            
            func getRect(targetKnobFrame: CGRect, otherKnobFrame: CGRect) -> CGRect {
                let targetKnobIsTop = targetKnobFrame.y < otherKnobFrame.y
                var rectX = targetKnobIsTop ? targetKnobFrame.x : selectionViewFrame.x
                var rectWidth = targetKnobIsTop ? CGRectGetMaxX(selectionViewFrame) - rectX : CGRectGetMaxX(targetKnobFrame) - rectX
                if rectWidth < 0 {
                    rectX = selectionViewFrame.x
                    rectWidth = selectionViewFrame.width
                }
                let rectY = targetKnobFrame.y
                let rectHeight = targetKnobFrame.height
                return CGRectMake(rectX, rectY, rectWidth, rectHeight)
            }
            
            switch (leftKnobIsOnWindow, rightKnobIsOnWindow) {
            case (true, true):
                if abs(CGRectGetMaxY(leftKnobFrame) - CGRectGetMaxY(rightKnobFrame)) < 20 {
                    // 左右光标在同一行
                    let rectX = min(CGRectGetMidX(leftKnobFrame), CGRectGetMidX(rightKnobFrame))
                    let rectY = min(leftKnobFrame.y, rightKnobFrame.y)
                    let rectWidth = max(CGRectGetMidX(leftKnobFrame), CGRectGetMidX(rightKnobFrame)) - rectX
                    let rectHeight = max(CGRectGetMaxY(leftKnobFrame), CGRectGetMaxY(rightKnobFrame)) - rectY
                    sourceRect = CGRectMake(rectX, rectY, rectWidth, rectHeight)
                } else {
                    // 左右光标不在同一行
                    let leftRect = getRect(targetKnobFrame: leftKnobFrame, otherKnobFrame: rightKnobFrame)
                    let rightRect = getRect(targetKnobFrame: rightKnobFrame, otherKnobFrame: leftKnobFrame)
                    let (topRect, bottomRect): (CGRect, CGRect) = {
                        if leftRect.y < rightRect.y {
                            return (leftRect, rightRect)
                        }
                        return (rightRect, leftRect)
                    }()
                    let rectY = topRect.y
                    let rectHeight = CGRectGetMaxY(bottomRect) - topRect.y
                    if (rectY + rectHeight + Constants.containerViewMarginTop + containerViewHeight) < visibleRange.bottom {
                        sourceRect = CGRectMake(bottomRect.x, rectY, bottomRect.width, rectHeight)
                    } else if (rectY - Constants.containerViewMarginTop - containerViewHeight) > visibleRange.top {
                        sourceRect = CGRectMake(topRect.x, rectY, topRect.width, rectHeight)
                    } else {
                        sourceRect = topRect
                    }
                }
            case (true, false):
                sourceRect = getRect(targetKnobFrame: leftKnobFrame, otherKnobFrame: rightKnobFrame)
            case (false, true):
                sourceRect = getRect(targetKnobFrame: rightKnobFrame, otherKnobFrame: leftKnobFrame)
            default:
                let rectY = (visibleRange.bottom - visibleRange.top) * 0.5 + visibleRange.top
                sourceRect = CGRectMake(selectionViewFrame.x, rectY, selectionViewFrame.width, 1)
            }
        }
        
        // 2.计算 containerView 顶部间距和箭头朝向
        var position = getContainerViewPosition(
            containerViewWidth: containerViewWidth,
            containerViewHeight: containerViewHeight,
            sourceRect: sourceRect
        )
        // 如果根据 sourceRect 计算 containerView 的位置超出了可视范围，调整位置，并使 menu 尽量少遮挡 sourceView
        if position == nil {
            if (sourceViewFrame.y - visibleRange.top) > (visibleRange.bottom - CGRectGetMaxY(sourceViewFrame)) {
                position = (visibleRange.top, .bottom)
            } else {
                position = (visibleRange.bottom - containerViewHeight - Constants.containerViewMarginTop, .top)
            }
        }
        
        // 3.计算 containerView 左边距
        // - converViewFrame 和 sourceRect 尽量保持水平居中对齐
        // - converViewFrame x 最小值为 8，最大值为 screenWidth - 8
        let containerViewLeft: CGFloat = {
            let minMargin: CGFloat = 8
            var left = CGRectGetMinX(sourceRect) + sourceRect.size.width * 0.5 - containerViewWidth * 0.5
            if left < minMargin {
                return minMargin
            }
            let maxMargin = screenWidth - minMargin - containerViewWidth
            if left > maxMargin {
                return maxMargin
            }
            return left
        }()
        
        // 3. 更新 containerView 和 contentView frame
        if let position {
            containerView.frame = CGRectMake(containerViewLeft, position.top, containerViewWidth, containerViewHeight)
            containerView.configue(sourceRect: sourceRect, arrowDirection: position.direction)
            contentView.frame = CGRectMake(
                containerViewPaddingH,
                position.direction == .top ? arrowHeight : 0,
                contentSize.width,
                contentSize.height
            )
        }
    }
    
    // 根据 sourceRect 计算 containerView 上边距和箭头朝向
    private func getContainerViewPosition(
        containerViewWidth: CGFloat,
        containerViewHeight: CGFloat,
        sourceRect: CGRect
    ) -> (top: CGFloat, direction: ArrowDirection)? {
        
        var containerViewTop: CGFloat = .zero
        var arrowDirection: ArrowDirection = .top
        
        // 1.判断 menu 展示在 sourceRect 下方是否合适
        let maxTop = visibleRange.bottom - containerViewHeight - Constants.containerViewMarginTop
        containerViewTop = CGRectGetMaxY(sourceRect) + Constants.containerViewMarginTop
        if containerViewTop <= maxTop {
            arrowDirection = .top
            return (top: containerViewTop, direction: arrowDirection)
        }
        
        // 2.判断 menu 展示在 sourceRect 上方是否合适
        let minTop = visibleRange.top
        containerViewTop = CGRectGetMinY(sourceRect) - Constants.containerViewMarginTop - containerViewHeight
        if containerViewTop >= minTop {
            arrowDirection = .bottom
            return (top: containerViewTop, direction: arrowDirection)
        }
        
        // 以上情况都不符合，没有找到合适的位置
        return nil
    }
    
    @objc
    private func didTapSelectMoreEmojiButton() {
        dismissHandler?()
        guard let presentingViewController else {
            dismiss(animated: true)
            return
        }
        guard let emojiAction else { return }
        dismiss(animated: false) {
            let emojiSheetController = ConversationEmojiSheetViewController(emojiAction: emojiAction)
            presentingViewController.presentPanModal(emojiSheetController)
        }
    }
    
    @objc
    private func actionButtonDidTap(_ sender: ActionButton) {
        guard let action = sender.action else {
            dismiss(animated: true)
            return
        }
        if action.dismissBeforePerformAction {
            dismiss(animated: true) {
                action.block(action)
                self.dismissHandler?()
            }
        } else {
            action.block(action)
        }
    }
    
    private func didTapSelectMoreActionButton() {
        dismissHandler?()
        guard let presentingViewController, !actions.isEmpty else {
            dismiss(animated: true)
            return
        }
        dismiss(animated: false) {
            let actionSheetController = ConversationActionMenuSheetController(actions: self.actions)
            presentingViewController.presentPanModal(actionSheetController)
        }
    }
    
    override func applyTheme() {
        self.containerView.containerBackgroundColor = UIColor(rgbHex: 0x474D57)
        self.moreEmojiButton?.tintColor = UIColor(rgbHex: 0xEAECEF)
        self.lineView?.backgroundColor = UIColor(rgbHex: 0x5E6673)
        
        actionButtons.forEach {
            $0.tintColor = UIColor(rgbHex: 0xEAECEF)
            $0.setTitleColor(UIColor(rgbHex: 0xEAECEF), for: .normal)
        }
    }
}

// MARK: - Emoji Button

private class EmojiButton: UIView {
   
    static let buttonSize: CGFloat = 36
    
    var emoji: String? {
        didSet {
            emojiLabel.text = emoji
        }
    }
    
    var isSelected: Bool = false {
        didSet {
            if oldValue != isSelected {
                refreshBackgroundViewColor()
            }
        }
    }
    
    var didTapHandler: (() -> Void)?
    
    private lazy var backgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Self.buttonSize * 0.5
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var emojiLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24)
        label.textAlignment = .center
        return label
    }()
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
        
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(emojiLabel)
        emojiLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapEmoji(_:)))
        addGestureRecognizer(tap)
        
        refreshBackgroundViewColor()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func refreshBackgroundViewColor() {
        if isSelected {
            backgroundView.backgroundColor = UIColor(rgbHex: 0x5E6673)
        } else {
            backgroundView.backgroundColor = .clear
        }
    }
    
    @objc
    func tapEmoji(_ tap: UITapGestureRecognizer) {
        didTapHandler?()
    }
}

// MARK: - Action Button

private class ActionButton: UIButton {
    
    static let imageWidth: CGFloat = 20
    static let buttonWidth: CGFloat = 55
    static let buttonHeight: CGFloat = 40
    static let buttonMargin: CGFloat = 7
    
    var action: MenuAction? {
        didSet {
            if let action {
                self.setImage(action.image, for: .normal)
                self.setTitle(action.title, for: .normal)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        titleLabel?.font = .systemFont(ofSize: 12)
        titleLabel?.textAlignment = .center
        titleLabel?.numberOfLines = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        imageView?.sizeToFit()
        let imageScale: CGFloat = {
            let width = imageView?.width ?? .zero
            let height = imageView?.height ?? .zero
            guard width > 0, height > 0 else {
                return .zero
            }
            return height / width
        }()
        let imageViewHeight = imageScale * Self.imageWidth
        imageView?.frame = CGRect(
            x: (self.width - Self.imageWidth) * 0.5,
            y: 0,
            width: Self.imageWidth,
            height: imageViewHeight
        )
        
        titleLabel?.sizeToFit()
        let titleHeight = titleLabel?.height ?? .zero
        titleLabel?.frame = CGRectMake(
            0, 
            imageViewHeight,
            self.bounds.size.width,
            titleHeight
        )
    }
}

// MARK: - Hit Test

private class HitTestView: UIView {
    enum Result: Equatable {
        case `default`
        case specified(UIView?)
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch(lhs, rhs) {
            case (.default, .default):
                return true
            case (.specified(let lhsView), .specified(let rhsView)):
                return lhsView === rhsView
            default:
                return false
            }
        }
    }
    
    var hitTestBlock: ((CGPoint, UIEvent?) -> Result)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hitTestBlock {
            let res = hitTestBlock(point, event)
            switch(res) {
            case .specified(let view):
                return view
            default:
                return super.hitTest(point, with: event)
            }
        }
        return super.hitTest(point, with: event)
    }
}
