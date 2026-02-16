//
//  FloatingConversationViewController.swift
//  TempTalk
//
//  Created by henry on 2025-12-26.
//  Copyright © 2025 Difft Inc. All rights reserved.
//

import UIKit

/// 浮动聊天窗口控制器
class FloatingConversationViewController: UIViewController {

    // MARK: - Constants

    private enum GestureConstants {
        static let dismissibleAreaBufferHeight: CGFloat = 80  // 导航栏下方的可拖拽缓冲区高度
        static let defaultNavigationBarHeight: CGFloat = 44   // 默认导航栏高度
    }

    // MARK: - Properties

    private let thread: TSThread?
    private let configuration: FloatingConversationConfiguration
    private var conversationVC: ConversationViewController?
    private var customViewController: UIViewController?
    private var shouldWrapInNavigationController: Bool

    private let dimView = UIView()
    private let containerWrapperView = UIView() // 包装视图，包含 dragIndicator 和 containerView
    internal let containerView = UIView()
    private let dragIndicator = UIView()
    private let conversationContainerView = UIView()

    private var currentMode: FloatingHeightMode = .compact
    private var hasKeyboardAppeared = false
    private var isViewVisible = false
    private var viewDidAppearTime: Date?
    private var usePushStyleDismiss = false
    private var shouldDismissPersonalCard = true
    private var isFullScreenMode = false
    private var isDismissing = false

    private var panGestureRecognizer: UIPanGestureRecognizer?
    private var panStartY: CGFloat = 0

    // MARK: - Computed Properties

    private var screenHeight: CGFloat {
        return view.bounds.height
    }

    private func containerHeight(for mode: FloatingHeightMode) -> CGFloat {
        return mode.height(for: screenHeight, config: configuration)
    }

    // MARK: - Initialization

    /// 使用任意 UIViewController 初始化（通用能力）
    init(viewController: UIViewController,
         configuration: FloatingConversationConfiguration = .default,
         wrapInNavigationController: Bool = true) {
        self.customViewController = viewController
        self.conversationVC = viewController as? ConversationViewController
        self.thread = nil
        self.configuration = configuration
        self.shouldWrapInNavigationController = wrapInNavigationController

        super.init(nibName: nil, bundle: nil)

        self.transitioningDelegate = self
        self.modalPresentationStyle = .custom
    }

    /// 使用 ConversationViewController 初始化（便捷方法）
    convenience init(conversationViewController: ConversationViewController,
                     configuration: FloatingConversationConfiguration = .default) {
        self.init(viewController: conversationViewController,
                  configuration: configuration,
                  wrapInNavigationController: true)
    }

    /// 使用 TSThread 初始化（兼容旧代码）
    init(thread: TSThread, configuration: FloatingConversationConfiguration = .default) {
        self.thread = thread
        self.configuration = configuration
        self.shouldWrapInNavigationController = true

        super.init(nibName: nil, bundle: nil)

        self.transitioningDelegate = self
        self.modalPresentationStyle = .custom
    }

    @objc convenience init(thread: TSThread) {
        self.init(thread: thread, configuration: .default)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConversationViewController()
        setupGestures()
        setupKeyboardNotifications()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = .clear

        dimView.backgroundColor = UIColor.black.withAlphaComponent(configuration.dimViewAlpha)
        dimView.alpha = 0
        view.addSubview(dimView)
        dimView.frame = view.bounds
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        if configuration.dismissOnDimViewTap {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dimViewTapped))
            dimView.addGestureRecognizer(tapGesture)
        }

        // 添加包装视图
        containerWrapperView.backgroundColor = .clear
        view.addSubview(containerWrapperView)

        // dragIndicator 添加到包装视图
        if configuration.showDragIndicator {
            dragIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.8)
            dragIndicator.layer.cornerRadius = 2.5
            containerWrapperView.addSubview(dragIndicator)
        }

        // containerView 添加到包装视图
        containerView.backgroundColor = Theme.bg1Color
        containerView.layer.cornerRadius = configuration.cornerRadius
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.layer.masksToBounds = true
        containerWrapperView.addSubview(containerView)

        // 设置包装视图的 frame
        updateContainerFrame(mode: .compact, animated: false)

        containerView.addSubview(conversationContainerView)
        conversationContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            conversationContainerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            conversationContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            conversationContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            conversationContainerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }

    private func setupConversationViewController() {
        // 优先使用传入的自定义 ViewController
        var targetViewController: UIViewController?

        if let customVC = customViewController {
            targetViewController = customVC
        } else if conversationVC == nil, let thread = thread {
            // 如果没有传入自定义 VC，且有 thread，则创建 ConversationViewController
            let newConversationVC = ConversationViewController(
                thread: thread,
                action: .none,
                focusMessageId: nil,
                botViewItem: nil,
                viewMode: .main,
                isFromPersonalCard: true
            )
            conversationVC = newConversationVC
            targetViewController = newConversationVC
        } else if let existingConversationVC = conversationVC {
            targetViewController = existingConversationVC
        }

        // 设置 ConversationViewController 的特定属性
        conversationVC?.floatingWindowIsCompactMode = true

        guard let viewController = targetViewController else { return }

        // 根据配置决定是否包装在导航控制器中
        if shouldWrapInNavigationController {
            let navController = OWSNavigationController(rootViewController: viewController)
            addChild(navController)
            conversationContainerView.addSubview(navController.view)
            navController.view.frame = conversationContainerView.bounds
            navController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            navController.didMove(toParent: self)
            navController.navigationBar.isTranslucent = false
        } else {
            // 直接添加 ViewController，不包装导航控制器
            addChild(viewController)
            conversationContainerView.addSubview(viewController.view)
            viewController.view.frame = conversationContainerView.bounds
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.didMove(toParent: self)
        }
    }

    // MARK: - Container Layout

    private func updateContainerFrame(mode: FloatingHeightMode, animated: Bool) {
        let height = containerHeight(for: mode)
        let indicatorHeight: CGFloat = configuration.showDragIndicator ? 13 : 0 // 5(indicator) + 8(gap)
        let wrapperHeight = height + indicatorHeight

        // wrapper 需要向上偏移 indicatorHeight，这样 containerView 才能正确显示在 screenHeight - height 的位置
        let targetWrapperFrame = CGRect(
            x: 0,
            y: screenHeight - height - indicatorHeight,
            width: view.bounds.width,
            height: wrapperHeight
        )

        let shouldShowCorner = (mode != .fullscreen)

        let animations = {
            // 移动 wrapper，dragIndicator 和 containerView 会自动跟随
            self.containerWrapperView.frame = targetWrapperFrame

            // containerView 在 wrapper 内的位置
            self.containerView.frame = CGRect(
                x: 0,
                y: indicatorHeight,
                width: self.view.bounds.width,
                height: height
            )

            // dragIndicator 在 wrapper 内的位置
            if self.configuration.showDragIndicator {
                let indicatorWidth: CGFloat = 40
                let indicatorY: CGFloat = indicatorHeight - 5 - 8 // indicator高度5，距离containerView 8pt
                self.dragIndicator.frame = CGRect(
                    x: (self.view.bounds.width - indicatorWidth) / 2,
                    y: indicatorY,
                    width: indicatorWidth,
                    height: 5
                )
                // 全屏时隐藏 dragIndicator
                self.dragIndicator.alpha = shouldShowCorner ? 1.0 : 0.0
            }

            self.containerView.layer.cornerRadius = shouldShowCorner ? self.configuration.cornerRadius : 0

            // 全屏时隐藏 dimView
            if mode == .fullscreen {
                self.dimView.alpha = 0
            }
        }

        if animated {
            UIView.animate(
                withDuration: configuration.heightAnimationDuration,
                delay: 0,
                usingSpringWithDamping: 1.0,
                initialSpringVelocity: 0,
                options: .curveEaseOut
            ) {
                animations()
            }
        } else {
            animations()
        }

        currentMode = mode

        conversationVC?.floatingWindowIsCompactMode = (mode == .compact)
        conversationVC?.updateBarButtonItems()
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        Logger.debug("[FloatingConversation] keyboardWillShow - isViewVisible: \(isViewVisible), currentMode: \(currentMode), hasKeyboardAppeared: \(hasKeyboardAppeared)")

        guard isViewVisible else {
            Logger.debug("[FloatingConversation] keyboardWillShow - view not visible, ignoring")
            return
        }

        guard currentMode == .compact else {
            Logger.debug("[FloatingConversation] keyboardWillShow - not in compact mode, ignoring")
            return
        }

        guard conversationVC?.presentedViewController == nil else {
            Logger.debug("[FloatingConversation] keyboardWillShow - has presented VC, ignoring")
            return
        }

        guard !hasKeyboardAppeared else {
            Logger.debug("[FloatingConversation] keyboardWillShow - keyboard already appeared, ignoring")
            return
        }

        if let appearTime = viewDidAppearTime {
            let timeSinceAppear = Date().timeIntervalSince(appearTime)
            Logger.debug("[FloatingConversation] keyboardWillShow - timeSinceAppear: \(timeSinceAppear)")
            guard timeSinceAppear > 0.2 else {
                Logger.debug("[FloatingConversation] keyboardWillShow - too soon after appear, ignoring")
                return
            }
        } else {
            Logger.debug("[FloatingConversation] keyboardWillShow - no appearTime, ignoring")
            return
        }

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            Logger.debug("[FloatingConversation] keyboardWillShow - no keyboard frame, ignoring")
            return
        }

        let screenHeight = UIScreen.main.bounds.height
        Logger.debug("[FloatingConversation] keyboardWillShow - keyboardFrame: \(keyboardFrame), screenHeight: \(screenHeight)")

        guard keyboardFrame.height > 200, keyboardFrame.origin.y < screenHeight else {
            Logger.debug("[FloatingConversation] keyboardWillShow - invalid keyboard frame, ignoring")
            return
        }

        Logger.debug("[FloatingConversation] keyboardWillShow - expanding to 90%")
        hasKeyboardAppeared = true

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve << 16)
        ) {
            self.updateContainerFrame(mode: .expanded, animated: false)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        // 键盘收起时不做任何操作
    }

    // MARK: - Button Actions

    @objc func switchToFullScreen() {
        isFullScreenMode = true
        conversationVC?.isFullScreenMode = true

        // 提前清理 HomeViewController 的导航栏，让返回更丝滑
        popToHomeViewController()

        // 使用微信风格的 Spring 动画，更流畅自然
        // 先设置目标状态，然后一起动画
        let fullHeight = self.view.bounds.height

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.6,
            options: [.curveEaseInOut, .beginFromCurrentState],
            animations: {
                // 同时移动 containerWrapperView 到顶部（让 containerView 和 dragIndicator 一起移动）
                self.containerWrapperView.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: self.view.bounds.width,
                    height: fullHeight
                )

                // containerView 填充整个 wrapper
                self.containerView.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: self.view.bounds.width,
                    height: fullHeight
                )

                // 圆角变为 0
                self.containerView.layer.cornerRadius = 0
                self.containerView.layer.masksToBounds = true

                // dimView 淡出（放在最后，确保与其他动画同步）
                self.dimView.alpha = 0

                // dragIndicator 淡出
                if self.configuration.showDragIndicator {
                    self.dragIndicator.alpha = 0
                }
            },
            completion: { _ in
                self.currentMode = .fullscreen
                self.conversationVC?.floatingWindowIsCompactMode = false
                self.conversationVC?.updateBarButtonItems()
                self.conversationVC?.updateContentInsets(animated: false)
                self.conversationVC?.inputToolbar.ensureTextViewHeight()
                self.conversationVC?.view.setNeedsLayout()
                self.conversationVC?.view.layoutIfNeeded()

                // 切换到全屏后刷新 joinbar 状态
                self.conversationVC?.refreshJoinBarView()

                // 展开动画结束后，切换到 push 模式以支持侧滑返回
                self.convertToPushMode()
            }
        )
    }

    @objc func dismissWithPopStyle() {
        usePushStyleDismiss = true
        shouldDismissPersonalCard = false
        dismiss(animated: true)
    }

    @objc func dismissWithPushStyleAndReturnToHome() {
        conversationVC?.isFromPersonalCard = false
        usePushStyleDismiss = true
        shouldDismissPersonalCard = false
        // 不需要在这里清理导航栈，因为在 switchToFullScreen 时已经清理过了
        dismiss(animated: true)
    }

    // 清理导航栈，返回到 HomeViewController
    private func popToHomeViewController() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController,
              let homeNav = tabBarController.selectedViewController as? UINavigationController else {
            return
        }

        // 将导航栈 pop 回 HomeViewController（根视图控制器）
        homeNav.popToRootViewController(animated: false)
    }

    // 将 present 模式切换为 push 模式，以支持侧滑返回手势
    private func convertToPushMode() {
        guard let conversationVC = self.conversationVC,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController,
              let homeNav = tabBarController.selectedViewController as? UINavigationController else {
            return
        }

        // 保存对 conversationVC 的强引用
        let vcToReuse = conversationVC

        // 创建截图覆盖层，避免切换时闪烁
        let snapshotView = containerView.snapshotView(afterScreenUpdates: false) ?? UIView()
        snapshotView.frame = containerView.frame
        window.addSubview(snapshotView)

        // 从当前的 navigationController 中移除
        if let navController = conversationVC.navigationController {
            navController.willMove(toParent: nil)
            navController.view.removeFromSuperview()
            navController.removeFromParent()
        }

        // 清空本地引用，避免在 dismiss 时被清理
        self.conversationVC = nil

        // 使用 UIView.performWithoutAnimation 确保无动画切换
        UIView.performWithoutAnimation {
            // Dismiss 当前的 FloatingConversationViewController（无动画）
            self.presentingViewController?.dismiss(animated: false) {
                // Dismiss 完成后，将 conversationVC push 到主导航控制器（无动画）
                UIView.performWithoutAnimation {
                    homeNav.pushViewController(vcToReuse, animated: false)
                }

                // 更新状态
                vcToReuse.isFromPersonalCard = false
                vcToReuse.floatingWindowIsCompactMode = false
                vcToReuse.updateBarButtonItems()

                // 移除截图覆盖层
                DispatchQueue.main.async {
                    snapshotView.removeFromSuperview()
                }
            }
        }
    }

    // MARK: - Gestures

    private func setupGestures() {
        guard configuration.enablePullToDismiss else { return }

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        containerView.addGestureRecognizer(panGesture)
        self.panGestureRecognizer = panGesture
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard currentMode != .fullscreen else { return }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            panStartY = containerWrapperView.frame.origin.y

        case .changed:
            // 只有当向下拖动时才响应（向上拖动不处理）
            if translation.y > 0 {
                // 直接移动 wrapper，dragIndicator 和 containerView 会自动跟随
                containerWrapperView.frame.origin.y = panStartY + translation.y

                // 根据拖拽进度调整 dimView 透明度
                let currentHeight = containerHeight(for: currentMode)
                let dragProgress = min(1.0, translation.y / currentHeight)
                dimView.alpha = max(0, 1 - dragProgress)
            }

        case .ended, .cancelled:
            let dragDistance = containerWrapperView.frame.origin.y - panStartY
            let currentHeight = containerHeight(for: currentMode)
            let threshold = currentHeight * configuration.pullToDismissThreshold

            // 考虑速度和距离两个因素决定是否 dismiss
            let shouldDismiss = dragDistance > threshold || velocity.y > 1000

            if shouldDismiss {
                // Dismiss 动画
                UIView.animate(
                    withDuration: 0.25,
                    delay: 0,
                    options: [.curveEaseOut]
                ) {
                    self.containerWrapperView.frame.origin.y = self.screenHeight
                    self.dimView.alpha = 0
                } completion: { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // 回弹动画，使用弹簧效果
                let springVelocity = min(max(velocity.y / 1000, 0), 10)
                UIView.animate(
                    withDuration: 0.4,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: springVelocity,
                    options: [.curveEaseInOut, .allowUserInteraction]
                ) {
                    self.containerWrapperView.frame.origin.y = self.panStartY
                    self.dimView.alpha = 1
                }
            }

        default:
            break
        }
    }

    @objc private func dimViewTapped() {
        dismiss(animated: true)
    }

    // MARK: - View Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        isViewVisible = true
        // 每次出现时重置键盘状态，确保键盘弹出时能正确切换到90%
        hasKeyboardAppeared = false

        UIView.animate(withDuration: 0.25) {
            self.dimView.alpha = 1
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        viewDidAppearTime = Date()
        conversationVC?.viewIsAppearing(false)

        DispatchQueue.main.async {
            self.conversationVC?.updateBarButtonItems()

            if let navController = self.conversationVC?.navigationController {
                navController.navigationBar.setNeedsLayout()
                navController.navigationBar.layoutIfNeeded()
            }

            // 刷新 joinbar 状态（50%和90%模式下会隐藏）
            self.conversationVC?.refreshJoinBarView()
        }

        conversationVC?.scrollToBottom(animated: false)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        guard !isDismissing else {
            completion?()
            return
        }

        isDismissing = true

        if flag {
            UIView.animate(withDuration: configuration.dismissAnimationDuration) {
                self.dimView.alpha = 0
            }
        }

        super.dismiss(animated: flag) { [weak self] in
            guard let self = self else {
                completion?()
                return
            }
            self.cleanupViewControllers()
            self.shouldDismissPersonalCard = true
            self.usePushStyleDismiss = false
            completion?()
        }
    }

    private func cleanupViewControllers() {
        // 清理手势识别器，避免循环引用
        if let panGesture = panGestureRecognizer {
            panGesture.delegate = nil
            containerView.removeGestureRecognizer(panGesture)
            panGestureRecognizer = nil
        }

        // 清理 dimView 上的手势识别器
        if let gestureRecognizers = dimView.gestureRecognizers {
            for gesture in gestureRecognizers {
                dimView.removeGestureRecognizer(gesture)
            }
        }

        // 清理 ConversationViewController（只在还存在时才清理）
        // 如果已经通过 convertToPushMode 转换，conversationVC 会是 nil
        if let navController = conversationVC?.navigationController {
            navController.willMove(toParent: nil)
            navController.view.removeFromSuperview()
            navController.removeFromParent()
        }

        conversationVC = nil

        // 清理其他状态
        viewDidAppearTime = nil
        hasKeyboardAppeared = false
        isViewVisible = false
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension FloatingConversationViewController: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        return FloatingConversationTransition(style: configuration.transitionStyle, isPresenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let style: FloatingTransitionStyle = usePushStyleDismiss ? .push : .present
        usePushStyleDismiss = false
        return FloatingConversationTransition(style: style, isPresenting: false)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension FloatingConversationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 不允许同时识别，避免手势冲突
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer,
              let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        let velocity = panGesture.velocity(in: containerView)
        let location = panGesture.location(in: containerView)

        // 如果是向上拖拽，不触发 dismiss 手势
        if velocity.y < 0 {
            return false
        }

        // 检查是否在可拖拽区域（导航栏 + 缓冲区）
        let dismissibleAreaMaxY = getDismissibleAreaMaxY()

        // 只在导航栏+缓冲区域允许dismiss，完全避免与scrollView冲突
        if location.y < dismissibleAreaMaxY {
            return true
        }

        // 在 scrollView 区域，完全禁用 dismiss 手势，让下拉刷新优先
        if let conversationVC = conversationVC {
            let scrollView = conversationVC.collectionView
            let scrollViewFrame = scrollView.convert(scrollView.bounds, to: containerView)

            if scrollViewFrame.contains(location) {
                // 完全禁用，避免与下拉刷新冲突
                return false
            }
        }

        // 其他区域（底部工具栏等）允许
        return true
    }

    // MARK: - Gesture Helper Methods

    /// 获取可拖拽区域的最大Y值（导航栏 + 缓冲区）
    private func getDismissibleAreaMaxY() -> CGFloat {
        let navigationBarMaxY = getNavigationBarMaxY()
        return navigationBarMaxY + GestureConstants.dismissibleAreaBufferHeight
    }

    /// 获取导航栏的最大Y值
    private func getNavigationBarMaxY() -> CGFloat {
        if let navController = conversationVC?.navigationController {
            return navController.navigationBar.frame.maxY
        }
        return GestureConstants.defaultNavigationBarHeight
    }
}
