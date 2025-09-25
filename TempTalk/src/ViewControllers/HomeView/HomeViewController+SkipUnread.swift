//
//  HomeViewController+SkipUnread.swift
//  Difft
//
//  Created by Jaymin on 2024/9/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

extension HomeViewController {
    
    private struct AssociatedKeys {
        static var lastSkippedThreadId: UInt8 = 0
    }
    
    // 上一次跳转到的未读消息
    private var lastSkippedThreadId: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.lastSkippedThreadId) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lastSkippedThreadId, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc func scrollToNextUnreadConversation() {
        // 0.如果 tableView 内容高度不足以滑动，跳过后续流程
        guard self.tableView.contentSize.height > self.tableView.bounds.size.height else {
            return
        }
        
        // 1.如果首页没有任何会话在展示，跳过后续流程
        let countOfThreads = self.threadMapping.numberOfItems(inSection: HomeViewControllerSection.conversations.rawValue)
        guard countOfThreads > 0 else {
            return
        }
        
        // 2.如果没有未读消息（包括勿扰和非勿扰），跳过后续流程
        var unreadThreads = DTThreadHelper.sharedManager().unMutedThreadArr.reversed() as? [TSThread]
        if (unreadThreads?.count ?? 0) == 0 {
            unreadThreads = DTThreadHelper.sharedManager().mutedThreadArr.reversed() as? [TSThread]
        }
        guard let unreadThreads, let firstUnreadThread = unreadThreads.first, let lastUnreadThread = unreadThreads.last else {
            return
        }
        
        // 3.列表可见范围的 indexPath 为空，跳过后续流程
        guard let visibleIndexPaths = self.tableView.indexPathsForVisibleRows, !visibleIndexPaths.isEmpty else {
            return
        }
        
        // 4.寻找列表可见范围内的 thread id 集合，如果所有 thread 都不在可见范围内，直接跳转到 firstUnreadThread
        let threadIndexPaths = visibleIndexPaths.filter { $0.section == HomeViewControllerSection.conversations.rawValue }
        let visibleThreadIds = threadIndexPaths.compactMap { self.threadMapping.thread(indexPath: $0)?.uniqueId }
        guard !visibleThreadIds.isEmpty else {
            scrollToUnreadThread(threadId: firstUnreadThread.uniqueId)
            return
        }
        
        // 5.如果 unreadThreads 都不在可见范围内，直接跳转到 firstUnreadThread
        if let firstVisibleIndexPath = threadIndexPaths.first,
           let lastVisibleIndexPath = threadIndexPaths.last,
           let firstUnreadIndexPath = self.threadMapping.indexPath(uniqueId: firstUnreadThread.uniqueId),
           let lastUnreadIndexpath = self.threadMapping.indexPath(uniqueId: lastUnreadThread.uniqueId),
           ((firstUnreadIndexPath.row > lastVisibleIndexPath.row) || (lastUnreadIndexpath.row < firstVisibleIndexPath.row)) {
            scrollToUnreadThread(threadId: firstUnreadThread.uniqueId)
            return
        }
        
        // 6.如果 unreadThreads 全部/部分在可见范围内
        // 6.1 如果 tableView 已经滑到底了，直接滚动回第一条的位置
        let maxOffsetY = self.tableView.contentSize.height - self.tableView.bounds.size.height
        let currentOffsetY = self.tableView.contentOffset.y
        if (maxOffsetY - currentOffsetY) < 70 { // 70 是行高，如果可滚动范围小于 70，直接返回第一条位置
            scrollToUnreadThread(threadId: firstUnreadThread.uniqueId)
            return
        }
        
        // 6.2 如果还没有滑到底，跳转到可见范围内第一条未读消息，且不能为上一次跳转到的未读消息
        var targetThreadId: String?
        for threadId in visibleThreadIds {
            if let lastSkippedThreadId, lastSkippedThreadId == threadId {
                continue
            }
            if let _ = unreadThreads.first(where: { $0.uniqueId == threadId }) {
                targetThreadId = threadId
                break
            }
        }
        if let targetThreadId {
            scrollToUnreadThread(threadId: targetThreadId)
        } else {
            // 可见范围内展示完最后一条 unread thread 后，需要循环到第一条
            scrollToUnreadThread(threadId: firstUnreadThread.uniqueId)
        }
    }
    
    private func scrollToUnreadThread(threadId: String) {
        self.scrollToThread(threadId: threadId, scrollPosition: .top, animated: true)
        self.lastSkippedThreadId = threadId
    }
    
    private func clearUnreadPosition() {
        self.lastSkippedThreadId = nil
    }
}
