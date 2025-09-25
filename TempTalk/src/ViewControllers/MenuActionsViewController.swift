//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTMessaging
import UIKit

@objc
public class MenuAction: NSObject {
    let block: (MenuAction) -> Void
    let image: UIImage
    let title: String
    let subtitle: String?
    let dismissBeforePerformAction: Bool

    public init(
        image: UIImage,
        title: String,
        subtitle: String?,
        dismissBeforePerformAction: Bool = true,
        block: @escaping (MenuAction) -> Void
    ) {
        self.image = image.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
        self.title = title
        self.subtitle = subtitle
        self.block = block
        self.dismissBeforePerformAction = dismissBeforePerformAction
    }
}

@objc
public class MenuEmojiAction: NSObject {
    let block: (String) -> Void
    let emojis: [String]
    let selectedEmojis: [String]
    
    public init(emojis: [String], selectedEmojis: [String] = [], block: @escaping (String) -> Void) {
        self.emojis = emojis
        self.selectedEmojis = selectedEmojis
        self.block = block
    }
}


@objc
protocol MenuActionsViewControllerDelegate: AnyObject {
    func menuActionsDidHide(_ menuActionsViewController: MenuActionsViewController)
}

@objc
class MenuActionsViewController: OWSViewController, MenuActionSheetDelegate {

    @objc
    weak var delegate: MenuActionsViewControllerDelegate?

    private var emojiAction: MenuEmojiAction?
    private var actionSheetView: MenuActionSheetView!
    
    deinit {
        Logger.verbose("\(logTag) in \(#function)")
        assert(didInformDelegateOfDismissalAnimation)
//        assert(didInformDelegateThatDisappearenceCompleted)
    }

    @objc
    required init(actions: [MenuAction], emojiAction: MenuEmojiAction?) {
   
        super.init()
        actionSheetView = MenuActionSheetView(actions: actions, emojiAction: emojiAction)
        actionSheetView.expandHandler = { [weak self] isExpand in
            guard let self else { return }
            if let actionSheetViewVerticalConstraint {
                NSLayoutConstraint.deactivate([actionSheetViewVerticalConstraint])
            }
            actionSheetView.superview?.layoutIfNeeded()
            let lessUsedCount = DTReactionHelper.lessUsed().count
            let lessUsedViewHeight = ((lessUsedCount-1)/7+1) * 50
            actionSheetViewVerticalConstraint = actionSheetView.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: isExpand ? CGFloat(lessUsedViewHeight) : 0)
        }
        self.emojiAction = emojiAction
        
        actionSheetView.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func applyTheme() {
        actionSheetView.applyTheme()
    }

    // MARK: View LifeCycle

    var actionSheetViewVerticalConstraint: NSLayoutConstraint?

    override func loadView() {
        self.view = UIView()

        view.addSubview(actionSheetView)

        actionSheetView.autoPinWidthToSuperview()
        actionSheetView.setContentHuggingVerticalHigh()
        actionSheetView.setCompressionResistanceHigh()
        self.actionSheetViewVerticalConstraint = actionSheetView.autoPinEdge(.top, to: .bottom, of: self.view)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapBackground(gesture:)))
        view.addGestureRecognizer(tapGesture)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)

        self.animatePresentation()
    }

    override func viewDidDisappear(_ animated: Bool) {
        Logger.debug("\(logTag) in \(#function)")
        super.viewDidDisappear(animated)

        // When the user has manually dismissed the menu, we do a nice animation
        // but if the view otherwise disappears (e.g. due to resigning active),
        // we still want to give the delegate the information it needs to restore it's UI.
        ensureDelegateIsInformedOfDismissalAnimation()
//        ensureDelegateIsInformedThatDisappearenceCompleted()
    }

    // MARK: Present / Dismiss animations

    private func animatePresentation() {
        guard let actionSheetViewVerticalConstraint = self.actionSheetViewVerticalConstraint else {
            owsFailDebug("\(self.logTag) in \(#function) actionSheetViewVerticalConstraint was unexpectedly nil")
            return
        }

        // darken background
        let backgroundDuration: TimeInterval = 0.2
        UIView.animate(withDuration: backgroundDuration) {
            self.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        }

        self.actionSheetView.superview?.layoutIfNeeded()

        NSLayoutConstraint.deactivate([actionSheetViewVerticalConstraint])
        self.actionSheetViewVerticalConstraint = self.actionSheetView.autoPinEdge(toSuperviewEdge: .bottom)
        UIView.animate(withDuration: backgroundDuration,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: {
                        self.actionSheetView.superview?.layoutIfNeeded()
        },
                       completion: nil)
    }
    
    private func animateDismiss(_ completion: (() -> Void)?) {
        guard let actionSheetViewVerticalConstraint else {
            owsFailDebug("\(self.logTag) in \(#function) actionSheetVerticalConstraint was unexpectedly nil")
            self.delegate?.menuActionsDidHide(self)
            return
        }

        self.actionSheetView.superview?.layoutIfNeeded()
        NSLayoutConstraint.deactivate([actionSheetViewVerticalConstraint])

        let dismissDuration: TimeInterval = 0.2
        self.actionSheetViewVerticalConstraint = self.actionSheetView.autoPinEdge(.top, to: .bottom, of: self.view)
        UIView.animate(withDuration: dismissDuration,
                       delay: 0,
                       options: .curveEaseOut,
                       animations: {
                        self.view.backgroundColor = UIColor.clear
                        self.actionSheetView.superview?.layoutIfNeeded()
                        self.ensureDelegateIsInformedOfDismissalAnimation()
        },
                       completion: { _ in
                        self.view.isHidden = true
//                        self.ensureDelegateIsInformedThatDisappearenceCompleted()
                      
                        self.dismiss(animated: false) {
                            if let completion {
                                completion()
                            }
                        }
        })
    }

    private func animateDismiss(action: MenuAction?) {
        animateDismiss {
            if let action {
                action.block(action)
            }
        }
    }
    
    private func animateDismiss(emojiAction: MenuEmojiAction?, emoji: String?) {
        animateDismiss {
            if let emojiAction, let emoji {
                emojiAction.block(emoji)
            }
        }
    }

//    var didInformDelegateThatDisappearenceCompleted = false
//    func ensureDelegateIsInformedThatDisappearenceCompleted() {
//        guard !didInformDelegateThatDisappearenceCompleted else {
//            Logger.debug("\(logTag) in \(#function) ignoring redundant 'disappeared' notification")
//            return
//        }
//        didInformDelegateThatDisappearenceCompleted = true
//
//        self.delegate?.menuActionsDidHide(self)
//    }

    var didInformDelegateOfDismissalAnimation = false
    func ensureDelegateIsInformedOfDismissalAnimation() {
        guard !didInformDelegateOfDismissalAnimation else {
            Logger.debug("\(logTag) in \(#function) ignoring redundant 'dismissal' notification")
            return
        }
        didInformDelegateOfDismissalAnimation = true
    }

    // MARK: Actions

    @objc
    func didTapBackground(gesture: UIGestureRecognizer) {
        let location = gesture.location(in: view)
//        if let emojiView = actionSheetView.emojiView, emojiView.frame.contains(location) {
//            actionSheetView.selectEmojiContainer(location: location, fromView: self.actionSheetView)
//        }
        if !actionSheetView.frame.contains(location) {
            animateDismiss(nil)
        }
    }

    // MARK: MenuActionSheetDelegate

    func actionSheet(_ actionSheet: MenuActionSheetView, didSelectAction action: MenuAction) {
        animateDismiss(action: action)
    }
    
    func actionSheet(_ actionSheet: MenuActionSheetView, didSelectEmoji emoji: String) {
        animateDismiss(emojiAction: self.emojiAction, emoji: emoji)
    }
}

protocol MenuActionSheetDelegate: AnyObject {
    func actionSheet(_ actionSheet: MenuActionSheetView, didSelectAction action: MenuAction)
    func actionSheet(_ actionSheet: MenuActionSheetView, didSelectEmoji emoji: String)
}

class MenuActionSheetView: UIView, MenuActionViewDelegate, DTEmojiReactionDelegate {
    
    var expandHandler: ( (Bool) -> Void )?
    
    private let actionStackView: UIStackView
    private var actions: [MenuAction]
    private var emojiView: DTEmojiActionView!
    private var actionViews: [MenuActionView]
    private var hapticFeedback: HapticFeedback
    private var hasEverHighlightedAction = false
    private var hasEverHighlightedEmoji = false

    weak var delegate: MenuActionSheetDelegate?

    override var bounds: CGRect {
        didSet {
            updateMask()
        }
    }

    convenience init(actions: [MenuAction], emojiAction: MenuEmojiAction?) {
        self.init(frame: CGRect.zero)
        if let emojiAction = emojiAction {
            self.addEmojiAction(emojiAction)
        }
        actions.forEach { self.addAction($0) }
    }

    override init(frame: CGRect) {
        actionStackView = UIStackView()
        actionStackView.axis = .vertical
        actionStackView.spacing = CGHairlineWidth()

        actions = []
        actionViews = []
        hapticFeedback = HapticFeedback()

        super.init(frame: frame)

        backgroundColor = Theme.tableCellBackgroundColor
        addSubview(actionStackView)
        actionStackView.autoPinEdgesToSuperviewEdges()

        self.clipsToBounds = true

        let touchGesture = UILongPressGestureRecognizer(target: self, action: #selector(didTouch(gesture:)))
        touchGesture.delegate = self
        touchGesture.minimumPressDuration = 0.0
        touchGesture.allowableMovement = CGFloat.greatestFiniteMagnitude
        self.addGestureRecognizer(touchGesture)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
    
    func applyTheme() {
        backgroundColor = Theme.tableCellBackgroundColor

        if let emojiView {
            emojiView.applyTheme()
        }
        
        actionViews.forEach {
            $0.applyTheme()
        }
    }

    @objc
    public func didTouch(gesture: UIGestureRecognizer) {
        
        let location = gesture.location(in: self)
        if let emojiView, emojiView.frame.contains(location) {
            unhighlightAllActionViews()
            return
        }
        
        switch gesture.state {
        case .possible:
            break
        case .began:
            highlightEmojiContainer(location: location, fromView: self)
            highlightActionView(location: location, fromView: self)
        case .changed:
            highlightEmojiContainer(location: location, fromView: self)
            highlightActionView(location: location, fromView: self)
        case .ended:
            Logger.debug("\(logTag) in \(#function) ended")
            selectActionView(location: location, fromView: self)
        case .cancelled:
            Logger.debug("\(logTag) in \(#function) canceled")
            unhighlightAllEmojis()
            unhighlightAllActionViews()
        case .failed:
            Logger.debug("\(logTag) in \(#function) failed")
            unhighlightAllEmojis()
            unhighlightAllActionViews()
        @unknown default: break
        }
    }

    public func addEmojiAction(_ emojiAction: MenuEmojiAction) {
        emojiView = DTEmojiActionView(emojiAction: emojiAction)
        emojiView.delegate = self
        emojiView.expandHandler = { [weak self] isExpand in
            guard let self, let expandHandler else { return}
            expandHandler(isExpand)
        }
        if let scrollView = emojiView.subviews[0] as? UIScrollView {
            scrollView.delegate = self
        }
        self.actionStackView.addArrangedSubview(emojiView)
    }
    
    public func addAction(_ action: MenuAction) {
        actions.append(action)

        let actionView = MenuActionView(action: action)
        actionView.delegate = self
        actionViews.append(actionView)

        self.actionStackView.addArrangedSubview(actionView)
    }

    // MARK: MenuActionViewDelegate
    func actionView(_ actionView: MenuActionView, didSelectAction action: MenuAction) {
        self.delegate?.actionSheet(self, didSelectAction: action)
    }

    // MARK: DTEmojiReactionDelegate
    func emojiView(_ emojiView: DTEmojiActionView, didSelectEmoji emoji: String) {
        self.delegate?.actionSheet(self, didSelectEmoji: emoji)
    }

    // MARK:

    private func updateMask() {
        let cornerRadius: CGFloat = 16
        let path: UIBezierPath = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }

    private func unhighlightAllActionViews() {
        for actionView in actionViews {
            actionView.isHighlighted = false
        }
    }

    private func actionView(touchedBy touchPoint: CGPoint, fromView: UIView) -> MenuActionView? {
        for actionView in actionViews {
            let convertedPoint = actionView.convert(touchPoint, from: fromView)
            if actionView.point(inside: convertedPoint, with: nil) {
                return actionView
            }
        }
        return nil
    }

    private func highlightActionView(location: CGPoint, fromView: UIView) {
        guard let touchedView = actionView(touchedBy: location, fromView: fromView) else {
            unhighlightAllActionViews()
            return
        }

        if hasEverHighlightedAction, !touchedView.isHighlighted {
            self.hapticFeedback.selectionChanged()
        }
        touchedView.isHighlighted = true
        hasEverHighlightedAction = true

        self.actionViews.filter { $0 != touchedView }.forEach {  $0.isHighlighted = false }
    }

    private func selectActionView(location: CGPoint, fromView: UIView) {
        guard let selectedView: MenuActionView = actionView(touchedBy: location, fromView: fromView) else {
            unhighlightAllActionViews()
            return
        }
        selectedView.isHighlighted = true
        self.actionViews.filter { $0 != selectedView }.forEach {  $0.isHighlighted = false }
        delegate?.actionSheet(self, didSelectAction: selectedView.action)
    }
    
    private func unhighlightAllEmojis() {
        emojiView?.emojiContainers().forEach {
            $0.isHighlighted = false
        }
    }
    
    private func emojiContainer(touchedBy touchPoint: CGPoint, fromView: UIView) -> DTEmojiContainer? {
        guard let emojiView = emojiView else { return nil }
        
        for subview in emojiView.emojiContainers() {
            let convertedPoint = subview.convert(touchPoint, from: fromView)
            if subview.point(inside: convertedPoint, with: nil) {
                return subview
            }
        }
        
        return nil
    }

    private func highlightEmojiContainer(location: CGPoint, fromView: UIView) {
        guard let touchedEmoji = emojiContainer(touchedBy: location, fromView: fromView) else {
            unhighlightAllEmojis()
            return
        }

        if hasEverHighlightedEmoji, !touchedEmoji.isHighlighted {
            self.hapticFeedback.selectionChanged()
        }
        touchedEmoji.isHighlighted = true
        hasEverHighlightedEmoji = true

        self.emojiView?.emojiContainers().filter { $0 != touchedEmoji }.forEach {
            $0.isHighlighted = false
        }
    }
    
    private func longPress() -> UILongPressGestureRecognizer? {
        guard let gestureRecognizers = gestureRecognizers else {
            return nil
        }
        var targetGesture: UILongPressGestureRecognizer?
        gestureRecognizers.forEach { gesture in
            if gesture is UILongPressGestureRecognizer {
                targetGesture = gesture as? UILongPressGestureRecognizer
                return
            }
        }
        return targetGesture
    }
    
}

extension MenuActionSheetView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let emojiView {
            if otherGestureRecognizer is UITapGestureRecognizer {
                let location = otherGestureRecognizer.location(in: self)
                return location.y < emojiView.height
            } else {
                return true
            }
        }
        return false
    }
}

extension MenuActionSheetView: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        longPress()?.isEnabled = false
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        longPress()?.isEnabled = true
    }
}

protocol MenuActionViewDelegate: AnyObject {
    func actionView(_ actionView: MenuActionView, didSelectAction action: MenuAction)
}

class MenuActionView: UIButton {
    public weak var delegate: MenuActionViewDelegate?
    public let action: MenuAction
    var icon: UIImageView!
    var lbTitle: UILabel!
    var lbSubtitle: UILabel!

    required init(action: MenuAction) {
        self.action = action

        super.init(frame: CGRect.zero)

        isUserInteractionEnabled = true
        backgroundColor = Theme.tableCellBackgroundColor

        icon = UIImageView(image: action.image)
        let imageWidth: CGFloat = 24.5
        icon.autoSetDimensions(to: CGSize(width: imageWidth, height: imageWidth))
        icon.tintColor = Theme.secondaryTextAndIconColor
        icon.isUserInteractionEnabled = false

        lbTitle = UILabel()
        lbTitle.font = UIFont.ows_dynamicTypeBody2
        lbTitle.textColor = Theme.primaryTextColor
        lbTitle.text = action.title
        lbTitle.isUserInteractionEnabled = false

        lbSubtitle = UILabel()
        lbSubtitle.font = UIFont.ows_dynamicTypeCaption1
        lbSubtitle.textColor = Theme.secondaryTextAndIconColor
        lbSubtitle.text = action.subtitle
        lbSubtitle.isUserInteractionEnabled = false

        let textColumn = UIStackView(arrangedSubviews: [lbTitle, lbSubtitle])
        textColumn.axis = .vertical
        textColumn.alignment = .leading
        textColumn.isUserInteractionEnabled = false

        let contentRow  = UIStackView(arrangedSubviews: [icon, textColumn])
        contentRow.axis = .horizontal
        contentRow.alignment = .center
        contentRow.spacing = 12
        contentRow.isLayoutMarginsRelativeArrangement = true
        contentRow.layoutMargins = UIEdgeInsets(top: 1, left: 16, bottom: 1, right: 16)
        contentRow.isUserInteractionEnabled = false

        self.addSubview(contentRow)
        contentRow.autoPinEdgesToSuperviewMargins()

        self.isUserInteractionEnabled = false
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                backgroundColor = Theme.cellSelectedColor
            } else {
                backgroundColor = Theme.tableCellBackgroundColor
            }
        }
    }
    
    func applyTheme() {
        backgroundColor = Theme.tableCellBackgroundColor

        lbTitle.textColor = Theme.primaryTextColor
        lbSubtitle.textColor = Theme.secondaryTextAndIconColor
        icon.tintColor = Theme.secondaryTextAndIconColor

        if isHighlighted {
            backgroundColor = Theme.cellSelectedColor
        } else {
            backgroundColor = Theme.tableCellBackgroundColor
        }
    }

    @objc
    func didPress(sender: Any) {
        Logger.debug("\(logTag) in \(#function)")
        self.delegate?.actionView(self, didSelectAction: action)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

protocol DTEmojiReactionDelegate: AnyObject {
    func emojiView(_ emojiView: DTEmojiActionView, didSelectEmoji emoji: String)
}

class DTEmojiActionView: UIStackView, UIGestureRecognizerDelegate {

    var delegate: DTEmojiReactionDelegate?
    
    public let emojiAction: MenuEmojiAction
    var expandHandler: ( (Bool) -> Void )?
    
    private var recentlyUsedView: UIStackView!
    private var lessUsedView: UIView!
    private var expandView: UIView!
    private var lineMiddle: UIView!
    private var arrow: UIImageView!

    required init(emojiAction: MenuEmojiAction) {
        self.emojiAction = emojiAction
        super.init(frame: .zero)
        axis = .vertical
        
        createSubviews()
    }
    
    private func createSubviews() {
        
//        let scrollView = UIScrollView()
//        scrollView.isScrollEnabled = false
//        scrollView.showsVerticalScrollIndicator = false
//        scrollView.showsHorizontalScrollIndicator = false
        
        lessUsedView = UIView()
        lessUsedView.isHidden = true
        lessUsedView.alpha = 0
        
        expandView = UIView()
        lineMiddle = UIView()
        lineMiddle.backgroundColor = Theme.hairlineColor
        lineMiddle.autoSetDimension(.height, toSize: 1)
        expandView.addSubview(lineMiddle)
        
        let arrowImage = UIImage(named: "ic_reaction_arrow")?.withRenderingMode(.alwaysTemplate)
        arrow = UIImageView(image: arrowImage)
        arrow.contentMode = .center
        arrow.isUserInteractionEnabled = true
        arrow.layer.cornerRadius = 12
        arrow.backgroundColor = Theme.conversationInputBackgroundColor
        arrow.tintColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57)

        arrow.autoSetDimensions(to: .square(24))
        expandView.addSubview(arrow)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(expandAction))
        tap.delegate = self
        expandView.addGestureRecognizer(tap)
                
        lineMiddle.autoPinEdge(toSuperviewEdge: .leading)
        lineMiddle.autoPinEdge(toSuperviewEdge: .trailing)
        lineMiddle.autoVCenterInSuperview()
        
        arrow.autoHCenterInSuperview()
        arrow.autoPinEdge(toSuperviewEdge: .top, withInset: 3)
        arrow.autoPinEdge(toSuperviewEdge: .bottom, withInset: 3)
        
//        addArrangedSubviews([recentlyUsedView, lessUsedView, expandView])
        
        recentlyUsedView = UIStackView()
        recentlyUsedView.axis = .horizontal
        recentlyUsedView.distribution = .equalSpacing
        recentlyUsedView.isLayoutMarginsRelativeArrangement = true
        recentlyUsedView.layoutMargins = UIEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
//        scrollView.addSubview(recentlyUsedView)
        
        addArrangedSubviews([recentlyUsedView, lessUsedView, expandView])
       
//        let gradientWidth = 40.0
//        let leftLayer = CAGradientLayer()
//        leftLayer.frame = CGRect(x: 0, y: 0, width: gradientWidth, height: 50.0)
//        leftLayer.colors = [gradientColor(alpha: 1.0), gradientColor(alpha: 0.9), gradientColor(alpha: 0.0)]
//        leftLayer.locations = [0.0, 0.2, 1.0]
//        leftLayer.startPoint = .zero
//        leftLayer.endPoint = CGPoint(x: 1, y: 0)
//        layer.addSublayer(leftLayer)
//        
//        let rightLayer = CAGradientLayer()
//        rightLayer.frame = CGRect(x: UIScreen.main.bounds.width - gradientWidth, y: 0, width: gradientWidth, height: 50.0)
//        rightLayer.colors = [gradientColor(alpha: 0.0), gradientColor(alpha: 0.9), gradientColor(alpha: 1)]
//        rightLayer.locations = [0.0, 0.8, 1.0]
//        rightLayer.startPoint = .zero
//        rightLayer.endPoint = CGPoint(x: 1, y: 0)
//        layer.addSublayer(rightLayer)
        
        emojiAction.emojis.forEach { emoji in
            let emojiContainer = DTEmojiContainer(emoji: emoji) { [weak self] in
                guard let self, let delegate else { return }
                delegate.emojiView(self, didSelectEmoji: emoji)
            }
            emojiContainer.isSelected = emojiAction.selectedEmojis.contains(emoji)
            self.recentlyUsedView.addArrangedSubview(emojiContainer)
        }
        
        recentlyUsedView.autoSetDimension(.height, toSize: DTEmojiContainer.containerHeight)
//        recentlyUsedView.autoPinEdgesToSuperviewEdges()
        
        for (index, emoji) in DTReactionHelper.lessUsed().enumerated() {
            let emojiContainer = DTEmojiContainer(emoji: emoji) { [weak self] in
                guard let self, let delegate else { return }
                delegate.emojiView(self, didSelectEmoji: emoji)
            }
            emojiContainer.isSelected = emojiAction.selectedEmojis.contains(emoji)
            lessUsedView.addSubview(emojiContainer)
            
            let row = index / 7
            let column = index % 7
            emojiContainer.autoPinEdge(toSuperviewEdge: .top, withInset: CGFloat(row)*DTEmojiContainer.containerHeight)
            emojiContainer.autoPinEdge(toSuperviewEdge: .leading, withInset: CGFloat(column)*DTEmojiContainer.containerWidth+20)
            emojiContainer.autoSetDimensions(to: CGSize(width: DTEmojiContainer.containerWidth, height: DTEmojiContainer.containerHeight))
            if index == DTReactionHelper.lessUsed().count - 1 {
                emojiContainer.autoPinEdge(toSuperviewEdge: .bottom)
            }
        }

    }
    
    func applyTheme() {
        emojiContainers().forEach {
            $0.applyTheme()
        }
        lineMiddle.backgroundColor = Theme.hairlineColor
        arrow.backgroundColor = Theme.conversationInputBackgroundColor
        arrow.tintColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func emojiContainers() -> [DTEmojiContainer] {
        var emojiContainers = recentlyUsedView.arrangedSubviews as! [DTEmojiContainer]
        emojiContainers += lessUsedView.subviews as! [DTEmojiContainer]
        
        return emojiContainers
    }
    
    fileprivate func gradientColor(alpha: CGFloat) -> CGColor {
        Theme.tableCellBackgroundColor.withAlphaComponent(alpha).cgColor
    }
    
    @objc
    func expandAction() {
   
        if let expandHandler {
            expandHandler(lessUsedView.isHidden)
        }

        UIView.animate(withDuration: 0.2) { [self] in
            lessUsedView.isHidden = !lessUsedView.isHidden
            lessUsedView.alpha = lessUsedView.isHidden ? 0 : 1
            arrow.transform = arrow.transform.rotated(by: .pi)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return gestureRecognizer.view == arrow || gestureRecognizer.view == lessUsedView
    }

}

class DTEmojiContainer: UIView {
   
    static let containerHeight = 50.0
    static let containerWidth = (UIScreen.main.bounds.width - 40) / 7
    private let backgroundView = UIView()
    private let lbEmoji = DTEmojiLabel()
    private var block: ( () -> Void )?
            
    required override init(frame: CGRect) {
        isHighlighted = false
        isSelected = false
        super.init(frame: .zero)
        
        backgroundView.layer.cornerRadius = (DTEmojiContainer.containerHeight - 12) / 2
        backgroundView.clipsToBounds = true
        
        addSubview(backgroundView)
        addSubview(lbEmoji)
        
        autoSetDimensions(to: CGSize(width: DTEmojiContainer.containerHeight, height: DTEmojiContainer.containerWidth))
        lbEmoji.autoPinEdgesToSuperviewEdges()
        backgroundView.autoSetDimensions(to: .square(DTEmojiContainer.containerHeight - 12))
        backgroundView.autoCenterInSuperview()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapEmoji(_:)))
        addGestureRecognizer(tap)
        
        applyTheme()
    }
    
    convenience init(emoji: String, block: ( () -> Void )?) {
        self.init(frame: .zero)
        lbEmoji.text = emoji
        self.block = block
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isHighlighted: Bool {
        didSet {
            lbEmoji.isHighlighted = isHighlighted
        }
    }
    
    var isSelected: Bool {
        didSet {
            setBackgroundColor(isSelected)
        }
    }
    
    func setBackgroundColor(_ selected: Bool) {
        if selected {
            backgroundView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x6A6D74) : UIColor(rgbHex: 0xE8F4FC)
        } else {
            backgroundView.backgroundColor = Theme.tableCellBackgroundColor
        }
    }
    
    func applyTheme() {
        
        backgroundColor = Theme.tableCellBackgroundColor
        setBackgroundColor(isSelected)
    }
    
    @objc
    func tapEmoji(_ tap: UITapGestureRecognizer) {
      
        guard let block else { return }
        block()
    }

}

class DTEmojiLabel: UILabel {
    
    private var textInsets: UIEdgeInsets
            
    required override init(frame: CGRect) {
        textInsets = .zero
        super.init(frame: .zero)
        
        font = .ows_dynamicTypeTitle1
        textAlignment = .center
        
        setContentHuggingHigh()
        setCompressionResistanceHigh()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: self.textInsets))
    }
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                font = .systemFont(ofSize: 44)
                textInsets = UIEdgeInsets(top: -5, leading: 0, bottom: 0, trailing: 0)
            } else {
                font = .ows_dynamicTypeTitle1
                textInsets = .zero
            }
        }
    }
    
}
