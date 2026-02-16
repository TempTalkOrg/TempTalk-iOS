//
//  FloatingConversationTransition.swift
//  TempTalk
//
//  Created by henry on 2025-12-26.
//  Copyright © 2025 Difft Inc. All rights reserved.
//

import UIKit

/// 浮动聊天窗口的自定义转场动画
class FloatingConversationTransition: NSObject, UIViewControllerAnimatedTransitioning {

    let style: FloatingTransitionStyle
    let isPresenting: Bool

    init(style: FloatingTransitionStyle, isPresenting: Bool) {
        self.style = style
        self.isPresenting = isPresenting
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(using: transitionContext)
        } else {
            animateDismissal(using: transitionContext)
        }
    }

    // MARK: - Private Methods

    private func animatePresentation(using context: UIViewControllerContextTransitioning) {
        guard let toVC = context.viewController(forKey: .to) as? FloatingConversationViewController,
              let toView = toVC.view else {
            context.completeTransition(false)
            return
        }

        let containerView = context.containerView
        let fromView = context.view(forKey: .from)

        containerView.addSubview(toView)
        toView.frame = containerView.bounds

        switch style {
        case .push:
            // Push风格：模仿系统原生push动画
            let containerWidth = containerView.bounds.width

            // 新页面从右侧滑入
            toView.frame = containerView.bounds.offsetBy(dx: containerWidth, dy: 0)

            // 给旧页面添加阴影效果
            let shadowView = UIView(frame: containerView.bounds)
            shadowView.backgroundColor = UIColor.black
            shadowView.alpha = 0
            if let fromView = fromView {
                containerView.insertSubview(shadowView, aboveSubview: fromView)
            }

            UIView.animate(
                withDuration: transitionDuration(using: context),
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    // 新页面滑入到正常位置
                    toView.frame = containerView.bounds

                    // 旧页面向左移动1/3宽度
                    if let fromView = fromView {
                        fromView.frame = containerView.bounds.offsetBy(dx: -containerWidth / 3, dy: 0)
                    }

                    // 阴影逐渐加深
                    shadowView.alpha = 0.3
                },
                completion: { finished in
                    shadowView.removeFromSuperview()
                    if let fromView = fromView {
                        fromView.frame = containerView.bounds
                    }
                    context.completeTransition(finished)
                }
            )

        case .present:
            // Present风格：从底部滑入
            let containerHeight = toVC.containerView.bounds.height
            toVC.containerView.transform = CGAffineTransform(translationX: 0, y: containerHeight)

            UIView.animate(
                withDuration: transitionDuration(using: context),
                delay: 0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.5
            ) {
                toVC.containerView.transform = .identity
            } completion: { finished in
                context.completeTransition(finished)
            }
        }
    }

    private func animateDismissal(using context: UIViewControllerContextTransitioning) {
        guard let fromVC = context.viewController(forKey: .from) as? FloatingConversationViewController,
              let fromView = fromVC.view else {
            context.completeTransition(false)
            return
        }

        let containerView = context.containerView
        let toView = context.view(forKey: .to)

        switch style {
        case .push:
            // Push风格：模仿系统原生pop动画
            let containerWidth = containerView.bounds.width

            // 给当前页面添加阴影效果
            let shadowView = UIView(frame: containerView.bounds)
            shadowView.backgroundColor = UIColor.black
            shadowView.alpha = 0.3
            containerView.insertSubview(shadowView, aboveSubview: toView ?? fromView)

            // 让旧页面初始状态为向左偏移1/3
            if let toView = toView {
                toView.frame = containerView.bounds.offsetBy(dx: -containerWidth / 3, dy: 0)
            }

            UIView.animate(
                withDuration: transitionDuration(using: context),
                delay: 0,
                options: [.curveEaseOut],
                animations: {
                    // 当前页面向右滑出
                    fromView.frame = containerView.bounds.offsetBy(dx: containerWidth, dy: 0)

                    // 旧页面向右移动回到正常位置
                    if let toView = toView {
                        toView.frame = containerView.bounds
                    }

                    // 阴影逐渐消失
                    shadowView.alpha = 0
                },
                completion: { finished in
                    shadowView.removeFromSuperview()
                    context.completeTransition(finished)
                }
            )

        case .present:
            // Present风格：向底部滑出
            let containerHeight = fromVC.containerView.bounds.height

            UIView.animate(
                withDuration: transitionDuration(using: context),
                delay: 0,
                options: .curveEaseIn
            ) {
                fromVC.containerView.transform = CGAffineTransform(translationX: 0, y: containerHeight)
            } completion: { finished in
                context.completeTransition(finished)
            }
        }
    }
}
