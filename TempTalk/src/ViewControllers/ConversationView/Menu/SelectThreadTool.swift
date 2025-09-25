//
//  SelectThreadTool.swift
//  Difft
//
//  Created by Jaymin on 2024/6/18.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

/// wrap SelectThreadViewController
/// 通过 block 解决某些页面存在多个选择 thread 场景，delegate 不好处理不同场景逻辑的情况
class SelectThreadTool: NSObject, SelectThreadViewControllerDelegate {
    
    var isCanSelectThread: ((TSThread) -> Bool)?
    var didSelectedThreads: (([TSThread]) -> Void)?
    var dismissHander: (() -> Void)?
    
    weak var selectThreadViewController: SelectThreadViewController?
    
    /// 展示选择会话页面
    func showSelectThreadViewController(source: UIViewController) {
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let navigationVC = OWSNavigationController(rootViewController: selectThreadVC)
        source.present(navigationVC, animated: true)
        self.selectThreadViewController = selectThreadVC
    }
    
    func forwordThreadCanBeSelested(_ thread: TSThread) -> Bool {
        return isCanSelectThread?(thread) ?? true
    }
    
    func canSelectBlockedContact() -> Bool {
        false
    }
    
    func threadsWasSelected(_ threads: [TSThread]) {
        didSelectedThreads?(threads)
        self.selectThreadViewController?.dismiss(animated: true, completion: {
            self.dismissHander?()
        })
    }
}
