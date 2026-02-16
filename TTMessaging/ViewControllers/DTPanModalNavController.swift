//
//  DTPanModalNavController.swift
//  TTMessaging
//
//  Created by Ethan on 28/02/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import PanModal

public protocol DTPanModalNavigationChildController: AnyObject {
    func layoutDidUpdateWhenViewWillAppear()
}

@objc
public class DTPanModalNavController: OWSNavigationController, PanModalPresentable {
    
    public var isShortFormEnabled = true
    public var defaultHeight: CGFloat = 434.0
    
    private var viewHasAppeared = false
    private var ignorePanGestureInContent = false
    
    private var forbidPanGesture = false
    
    public override init() {
        super.init()
    }
    
    @objc
    public convenience init(
        rootViewController: UIViewController,
        defaultHeight: CGFloat,
        ignorePanGestureInContent: Bool = false
    ) {
        self.init()
        self.viewControllers = [rootViewController]
        self.defaultHeight = defaultHeight
        self.ignorePanGestureInContent = ignorePanGestureInContent
    }
    
    @objc
    public convenience init(
        rootViewController: UIViewController,
        defaultHeight: CGFloat,
        ignorePanGestureInContent: Bool = false,
        forbidPanGesture: Bool = false
    ) {
        self.init()
        self.viewControllers = [rootViewController]
        self.defaultHeight = defaultHeight
        self.ignorePanGestureInContent = ignorePanGestureInContent
        self.forbidPanGesture = forbidPanGesture
    }
    
    // TODO: 改造 OWSNavigationController 的同名方法，直接调用到父类的初始化方法会造成 present 失败
    /// convenience initial
    /// - Parameter rootViewController: rootViewController
    public convenience init(rootViewController: UIViewController) {
        self.init()
        self.viewControllers = [rootViewController]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // DTPanModalNavController 被 present 后，自身又 present 一个新的 vc，当新的 vc dismiss 后，需要进行布局更新
        if viewHasAppeared {
            panModalSetNeedsLayoutUpdate()
            if let child = topViewController as? DTPanModalNavigationChildController {
                child.layoutDidUpdateWhenViewWillAppear()
            }
        } else {
            viewHasAppeared = true
        }
    }
    
    /// 保存原始的 defaultHeight，用于 pop 时恢复
    private var originalDefaultHeight: CGFloat?

    public override func popViewController(animated: Bool) -> UIViewController? {
        // 记录被 pop 的 VC 是否需要 longForm
        let poppedVCNeedsLongForm = topViewController?.panModalNeedsLongForm ?? false
        let poppedVC = super.popViewController(animated: animated)

        // 如果 pop 掉的是需要 longForm 的 VC，而新的 topVC 不需要，则恢复到 shortForm
        let newTopVCNeedsLongForm = topViewController?.panModalNeedsLongForm ?? false

        if poppedVCNeedsLongForm && !newTopVCNeedsLongForm {
            // 恢复原始高度
            if let originalHeight = originalDefaultHeight {
                defaultHeight = originalHeight
            }
            isShortFormEnabled = true

            // 延迟执行，确保 pop 动画完成后再更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self = self else { return }
                self.updatePanModalHeight()
            }
        } else {
            panModalSetNeedsLayoutUpdate()
        }

        return poppedVC
    }

    /// 强制更新 PanModal 高度
    private func updatePanModalHeight() {
        guard let presentationController = presentationController as? PanModalPresentationController else {
            return
        }

        // 根据当前 topVC 决定目标状态
        let targetState: PanModalPresentationController.PresentationState =
            (topViewController?.panModalNeedsLongForm ?? false) ? .longForm : .shortForm

        // 强制刷新布局并转换到目标状态
        presentationController.setNeedsLayoutUpdate()
        presentationController.transition(to: targetState)
    }
    
    public override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        // 如果新的 VC 需要 longForm 高度（四分之三屏）
        let needsLongForm = viewController.panModalNeedsLongForm

        if needsLongForm {
            // 保存原始高度
            if originalDefaultHeight == nil {
                originalDefaultHeight = defaultHeight
            }
        }

        super.pushViewController(viewController, animated: animated)

        if needsLongForm {
            // push 完成后立即更新高度（此时 topViewController 已经是新的 VC）
            DispatchQueue.main.async { [weak self] in
                self?.updatePanModalHeight()
            }
        } else {
            panModalSetNeedsLayoutUpdate()
        }
    }

    // MARK: - Pan Modal Presentable

    public var panScrollable: UIScrollView? {
        // 返回 nil 避免某些 scrollView 导致死循环
        if let child = topViewController as? PanModalPresentable {
            return child.panScrollable
        }
        return nil
    }

    public var shortFormHeight: PanModalHeight {
        // 只有当子 VC 明确需要 longForm 时，才使用子 VC 的 shortFormHeight
        if let child = topViewController, child.panModalNeedsLongForm {
            if let panModalChild = child as? PanModalPresentable {
                return panModalChild.shortFormHeight
            }
        }
        // 否则使用 defaultHeight
        return isShortFormEnabled ? .contentHeight(defaultHeight) : .contentHeight(UIScreen.main.bounds.height)
    }

    public var longFormHeight: PanModalHeight {
        // 只有当子 VC 明确需要 longForm 时，才使用子 VC 的 longFormHeight
        if let child = topViewController, child.panModalNeedsLongForm {
            if let panModalChild = child as? PanModalPresentable {
                return panModalChild.longFormHeight
            }
        }
        // 否则使用 defaultHeight 或全屏
        return isShortFormEnabled ? .contentHeight(defaultHeight) : .contentHeight(UIScreen.main.bounds.height)
    }
    
    public var scrollIndicatorInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: view.safeAreaInsets.bottom, right: 0)
    }
    
    public var anchorModalToLongForm: Bool {
        return false
    }
    
    public func shouldRespond(to panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        // 解决手势冲突，当 ignorePanGestureInContent = true 时，在 navigationController view 范围内的 panModalGestureRecognizer 不生效
        if forbidPanGesture {
            return false
        }
        
        if ignorePanGestureInContent {
            let location = panModalGestureRecognizer.location(in: self.view)
            // 允许在 navigationBar 这个范围拖动整个 panModal 窗口
            return location.y <= 44
        }
        return true
    }
    
    public func shouldPrioritize(panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        return false
    }
    
    public func willTransition(to state: PanModalPresentationController.PresentationState) {
        guard isShortFormEnabled, case .longForm = state
        else { return }

        // 只有当 topViewController 明确需要 longForm 时才允许展开到全屏
        guard topViewController?.panModalNeedsLongForm == true else { return }

        isShortFormEnabled = false
        panModalSetNeedsLayoutUpdate()
    }
}

extension DTPanModalNavController {
    /// 解决 presentPanModal 无法在 Objective-C 中直接使用的问题
    @objc
    func presentPanModal(from sourceViewController: UIViewController) {
        sourceViewController.presentPanModal(self)
    }
}

extension UIViewController {
    @objc
    public var isPanModalPresentable: Bool {
        (self as? PanModalPresentable) != nil
    }

    /// 标记该 VC 是否需要使用 longForm 高度（四分之三屏）
    /// 子类可以重写此属性来指定自己需要的高度模式
    @objc
    open var panModalNeedsLongForm: Bool {
        return false
    }
}
