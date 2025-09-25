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
    
    public override func popViewController(animated: Bool) -> UIViewController? {
        let vc = super.popViewController(animated: animated)
        panModalSetNeedsLayoutUpdate()
        return vc
    }
    
    public override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        panModalSetNeedsLayoutUpdate()
    }
    
    // MARK: - Pan Modal Presentable
    
    public var panScrollable: UIScrollView? {
        return (topViewController as? PanModalPresentable)?.panScrollable
    }
    
    public var shortFormHeight: PanModalHeight {
        return isShortFormEnabled ? .contentHeight(defaultHeight) : .contentHeight(UIScreen.main.bounds.height)
    }
    
    public var longFormHeight: PanModalHeight {
        return .contentHeight(UIScreen.main.bounds.height)
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
}
