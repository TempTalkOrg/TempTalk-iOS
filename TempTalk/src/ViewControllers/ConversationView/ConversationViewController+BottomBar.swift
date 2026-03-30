//
//  ConversationViewController+BottomBar.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import Foundation
import PureLayout
import TTServiceKit

// MARK: - InputToolbar

@objc
extension ConversationViewController {
    var inputToolbar: ConversationInputToolbar {
        if let toolbar = viewState.inputToolbar {
            return toolbar
        }
        let toolbar = createInputToolBar()
        viewState.inputToolbar = toolbar
        return toolbar
    }
    
    var bottomBar: UIView {
        viewState.bottomBar
    }
    
    var bottomBarBottomConstraint: NSLayoutConstraint? {
        get { viewState.bottomBarBottomConstraint }
        set { viewState.bottomBarBottomConstraint = newValue }
    }
    
    var inputAccessoryPlaceholder: InputAccessoryViewPlaceholder {
        viewState.inputAccessoryPlaceholder
    }
    
    var isDismissingInteractively: Bool {
        get { viewState.isDismissingInteractively }
        set { viewState.isDismissingInteractively = newValue }
    }
    
    var viewHasEverAppeared: Bool {
        get { viewState.viewHasEverAppeared }
        set { viewState.viewHasEverAppeared = newValue }
    }
    
    var isViewCompletelyAppeared: Bool {
        get { viewState.isViewCompletelyAppeared }
        set { viewState.isViewCompletelyAppeared = newValue }
    }
    
    var shouldAnimateKeyboardChanges: Bool {
        get { viewState.shouldAnimateKeyboardChanges }
        set { viewState.shouldAnimateKeyboardChanges = newValue }
    }
    
    func setupBottomBar() {
        view.addSubview(bottomBar)
        bottomBarBottomConstraint = bottomBar.autoPinEdge(toSuperviewEdge: .bottom)
        bottomBar.autoPinWidthToSuperview()
    }
    
    func reloadBottomBar() {
        let bottomView: UIView
        
        if showRequestBar {
            bottomView = friendReqBar
            self.friendReqBar.setLabelText(thread.conversationEntity?.findyouDescribe)
        } else if isMultiSelectMode {
            bottomView = self.forwardToolbar
            self.forwardToolbar.reloadContents()
        } else {
            bottomView = self.inputToolbar
        }
        
        if bottomView.superview === self.bottomBar, self.viewHasEverAppeared {
            // Do nothing, the view has not changed.
            if let currentView = self.bottomBar.subviews.first, currentView === bottomView {
                return
            }
        }
        
        self.bottomBar.subviews.forEach {
            $0.removeFromSuperview()
        }
        
        self.bottomBar.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewEdges()
        
        if viewHasEverAppeared {
            updateInputAccessoryPlaceholderHeight()
            updateContentInsets(animated: true)
        }
    }
    
    func inputToolbarRelationship() -> InputToolbarRelationship {
        let friendship = (self.thread.isGroupThread() || self.isFriend) ? InputToolbarRelationship.normal : InputToolbarRelationship.notFriend
        return friendship
    }
    
    func inputToolbarState() -> InputToolbarState {
        let inputToolbarState = self.thread.conversationEntity?.confidentialMode == .confidential ? InputToolbarState.confidential : InputToolbarState.normal
        return inputToolbarState
    }
    
    func recreateInputToolbar() {
        let quotedReplyDraft = inputToolbar.quotedReplyDraft
        let threadType = inputToolbar.threadType

        // 保存键盘状态
        let wasFirstResponder = inputToolbar.inputTextView.isFirstResponder
        let savedText = inputToolbar.inputTextView.text

        Logger.info("[Keyboard] recreateInputToolbar, wasFirstResponder=\(wasFirstResponder), currentTextLen=\(savedText?.count ?? 0)")

        let inputToolbar = ConversationInputToolbar(conversationStyle: self.conversationStyle,
                                                    messageDraft: self.thread.messageDraft,
                                                    quotedReplyDraft: quotedReplyDraft,
                                                    inputToolbarDelegate: self,
                                                    inputTextViewDelegate: self,
                                                    inputToolbarState: inputToolbarState(),
                                                    relationship: inputToolbarRelationship(),
                                                    threadType: threadType)
        viewState.inputToolbar = inputToolbar

        // Update confidential button visibility based on group size
        updateConfidentialButtonVisibility()

        // 之前是 first responder，恢复文字和键盘状态
        if wasFirstResponder {
            Logger.info("[Keyboard] recreateInputToolbar → restoring keyboard and text")
            DispatchQueue.main.async {
                inputToolbar.inputTextView.text = savedText
                inputToolbar.beginEditingMessage()
            }
        }
    }
    
    private func createInputToolBar() -> ConversationInputToolbar {

        // TODO: keyboard draft and quote
        let threadType: InputToolbarThreadType
        if self.thread.isGroupThread() {
            threadType = .group
        } else {
            threadType = .contact
        }
        let inputToolbar = ConversationInputToolbar(conversationStyle: self.conversationStyle,
                                                    messageDraft: self.thread.messageDraft,
                                                    quotedReplyDraft: nil,
                                                    inputToolbarDelegate: self,
                                                    inputTextViewDelegate: self,
                                                    inputToolbarState: inputToolbarState(),
                                                    relationship: inputToolbarRelationship(),
                                                    threadType: threadType)

        // Update confidential button visibility based on group size
        // Must set viewState.inputToolbar first to avoid infinite loop
        viewState.inputToolbar = inputToolbar
        updateConfidentialButtonVisibility()

        return inputToolbar
    }

    /// Update confidential button visibility based on group member count
    /// - For groups with ≥20 members: hide the confidential message button
    /// - For groups with <20 members or non-group conversations: show the button normally
    func updateConfidentialButtonVisibility() {
        if let contactThread = thread as? TSContactThread,
           contactThread.contactIdentifier() == TSConstants.officialBotId {
            inputToolbar.shouldHideConfidentialButton = true
            return
        }

        guard isGroupConversation, let groupThread = thread as? TSGroupThread else {
            inputToolbar.shouldHideConfidentialButton = !isFriend
            return
        }

        let memberCount = groupThread.groupModel.groupMemberIds.count
        let groupConfig = DTGroupConfig.fetch()
        let threshold = groupConfig.confidentialModeThreshold
        inputToolbar.shouldHideConfidentialButton = memberCount >= threshold
    }
    
    func updateBottomBarPosition() {
        AssertIsOnMainThread()
        
        guard self.isViewVisible else {
            Logger.error("[Conversation] current isViewVisible is false")
            return
        }
        
        // Don't update the bottom bar position if an interactive pop is in progress
        switch navigationController?.interactivePopGestureRecognizer?.state {
        case .possible, .failed:
            break
        default:
            return
        }
        
        guard let bottomBarBottomConstraint = bottomBarBottomConstraint,
              let bottomBarSuperview = bottomBar.superview else {
            Logger.error("[Conversation] bottombar superview is nil")
            return
        }
        let bottomBarPosition = -inputAccessoryPlaceholder.keyboardOverlap
        let didChange = bottomBarBottomConstraint.constant != bottomBarPosition
        guard didChange else {
            // This is a normal case - no need to update if position hasn't changed
            return
        }
        bottomBarBottomConstraint.constant = bottomBarPosition
        
        // We always want to apply the new bottom bar position immediately,
        // as this only happens during animations (interactive or otherwise)
        bottomBarSuperview.layoutIfNeeded()
    }
    
    func hideInputIfNeeded() {
        if peek {
            inputToolbar.isHidden = true
            forceDissmissKeyBoard()  // peek 模式强制收起
            return
        }
        if isUserLeftGroup {
            // user has requested they leave the group. further sends disallowed
            inputToolbar.isHidden = true
            forceDissmissKeyBoard()  // 用户已退群，强制收起
        } else {
            inputToolbar.isHidden = false
        }
    }
    
    func updateContentInsets(
        animated: Bool,
        forceScrollToDefaultPosition: Bool = false,
        allowAutoScroll: Bool = true
    ) {
        AssertIsOnMainThread()
        
        // Don't update the bottom bar position if an interactive pop is in progress
        switch navigationController?.interactivePopGestureRecognizer?.state {
        case .possible, .failed:
            break
        default:
            return
        }
        
        self.view.layoutIfNeeded()
        
        let oldInsets = collectionView.contentInset
        var newInsets = oldInsets
        newInsets.bottom = inputAccessoryPlaceholder.keyboardOverlap + bottomBar.height - view.safeAreaInsets.bottom
        
        let wasScrolledToBottom = self.isScrolledToBottom
        
        // Changing the contentInset can change the contentOffset, so make sure we
        // stash the current value before making any changes.
        let oldYOffset = collectionView.contentOffset.y
        
        if collectionView.contentInset != newInsets {
            collectionView.contentInset = newInsets
        }
        collectionView.scrollIndicatorInsets = newInsets
        
        guard allowAutoScroll else {
            return
        }
        
        func adjustInsets() {
            let insetChange = newInsets.bottom - oldInsets.bottom
            let isKeyboardActuallyVisible = self.inputToolbar.isInputViewFirstResponder

            let keyboardVisible: Bool
            if #available(iOS 15.0, *) {
                let keyboardHeight = self.view.keyboardLayoutGuide.layoutFrame.height - self.view.safeAreaInsets.bottom
                keyboardVisible = keyboardHeight > 100
            } else {
                // iOS 15 以下使用 isInputViewFirstResponder 作为 fallback
                keyboardVisible = isKeyboardActuallyVisible
            }


            // 1. 初始加载或强制滚动
            if !self.viewHasEverAppeared || forceScrollToDefaultPosition {
                scrollToDefaultPosition(animated: false)
                return
            }

            // 2. 键盘弹起或已在底部的情况
            if (wasScrolledToBottom || (insetChange > 0 && isKeyboardActuallyVisible)) && !self.isScreenOrientationChanging {
                let hasFocusMessage = conversationViewModel.viewState.focusItemIndex != nil
                let justCompletedInitialScroll = viewState.hasCompletedInitialScroll && !viewState.userHasScrolled
                let hasFloatingConversationPresented = presentedViewController is FloatingConversationViewController

                // 2.1 正常情况：滚动到底部
                if !hasFocusMessage && !justCompletedInitialScroll && !hasFloatingConversationPresented {
                    scrollToBottom(animated: false)
                }
                // 2.2 从搜索跳转 + 键盘弹起：调整滚动确保焦点消息可见
                else if hasFocusMessage && justCompletedInitialScroll && insetChange > 0 {
                    if let focusIndex = conversationViewModel.viewState.focusItemIndex?.intValue {
                        let indexPath = IndexPath(row: focusIndex, section: 0)
                        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                    }
                }
                // 2.3a 用户主动弹起键盘：清除保护并滚动到底部
                // 用户弹起键盘是明确的输入信号，应该滚动到底部
                else if isKeyboardActuallyVisible && insetChange > 0 && !hasFocusMessage {
                    // 清除初始滚动保护，因为用户已经开始交互
                    viewState.initialScrollTargetOffset = nil
                    viewState.initialScrollProtectionDeadline = nil
                    scrollToBottom(animated: false)
                }
                // 2.3b 其他保护情况：不滚动
                else {
                }
                return
            }

            // 3. 视图完全显示后的 content offset 调整
            if self.isViewCompletelyAppeared {

                // 3.1 浮动窗口覆盖时不调整
                if presentedViewController is FloatingConversationViewController {
                    return
                }

                // 3.2 从搜索跳转时不调整（保护焦点位置）
                let hasFocusMessage = conversationViewModel.viewState.focusItemIndex != nil
                let justCompletedInitialScroll = viewState.hasCompletedInitialScroll && !viewState.userHasScrolled
                if hasFocusMessage && justCompletedInitialScroll {
                    return
                }

                // 3.3 初始滚动位置保护：如果在保护期内且有目标位置，恢复到目标位置
                if let targetOffset = viewState.initialScrollTargetOffset,
                   let deadline = viewState.initialScrollProtectionDeadline,
                   Date() < deadline {
                    // 检查当前位置是否偏离目标位置超过阈值（50pt）
                    let currentOffset = collectionView.contentOffset.y
                    let offsetDrift = abs(currentOffset - targetOffset)
                    if offsetDrift > 50 {
                        let minYOffset = -view.safeAreaInsets.top
                        let restoredOffset = CGFloatClamp(targetOffset, minYOffset, safeContentHeight)
                        collectionView.setContentOffset(CGPoint(x: 0, y: restoredOffset), animated: false)
                        return
                    } else {
                    }
                }

                // 清除过期的保护
                if let deadline = viewState.initialScrollProtectionDeadline, Date() >= deadline {
                    viewState.initialScrollTargetOffset = nil
                    viewState.initialScrollProtectionDeadline = nil
                }

                // 3.4 刚完成初始滚动时，只在键盘闪现消失时不调整（防止键盘闪现导致的偏移）
                // 键盘闪现的特征：insetChange < 0（消失）且键盘实际不可见（keyboardVisible = false）
                // 用户主动操作键盘：keyboardVisible 会正确反映键盘状态，需要正常调整
                if justCompletedInitialScroll && insetChange < 0 && !keyboardVisible {
                    return
                }

                // 3.5 正常调整 content offset
                if insetChange != 0 {
                    // 3.5a 如果在初始滚动保护期内，跳过键盘引起的自动调整
                    // 这样可以防止刚进入页面时键盘事件导致未读消息位置下移
                    // 但只在有未读消息的情况下保护，否则会影响正常的键盘滚动行为
                    if let targetOffset = viewState.initialScrollTargetOffset,
                       let deadline = viewState.initialScrollProtectionDeadline,
                       Date() < deadline,
                       conversationViewModel.viewState.unreadIndicatorIndex != nil {
                        return
                    }

                    let minYOffset = -view.safeAreaInsets.top
                    let newYOffset = CGFloatClamp(oldYOffset + insetChange, minYOffset, safeContentHeight)
                    let newOffset = CGPointMake(0, newYOffset)
                    collectionView.setContentOffset(newOffset, animated: false)
                } else {
                }
            } else {
            }
        }

        if animated {
            adjustInsets()
        } else {
            UIView.performWithoutAnimation {
                adjustInsets()
            }
        }

        // Reset orientation changing flag after adjusting insets, but not inside the animation block
        if self.isScreenOrientationChanging {
            DispatchQueue.main.async { [weak self] in
                self?.isScreenOrientationChanging = false
            }
        }
    }
}

// MARK: - Drafts

@objc extension ConversationViewController {
    func loadDraftInCompose() {
        AssertIsOnMainThread()
        
        if isGroupConversation,
           let groupThread = self.thread as? TSGroupThread,
           !groupThread.isLocalUserInGroup() {
            return
        }
        
        var draft: String = .empty
        var mentionsDraft: [DTMention] = []
        databaseStorage.uiRead { [weak self] transaction in
            guard let self else { return }
            draft = self.thread.currentDraft(with: transaction)
            mentionsDraft = self.thread.currentMentionsDraft(with: transaction)
        }
        let currentTextLen = self.inputToolbar.inputTextView.text?.count ?? 0
        if isUserActivelyTyping && currentTextLen > 0 && draft != self.inputToolbar.inputTextView.text {
            Logger.warn("[Keyboard] loadDraftInCompose skipped: user is typing, currentTextLen=\(currentTextLen), draftLen=\(draft.count)")
            return
        }
        self.inputToolbar.setMessageBody(draft, animated: false)
        if !draft.isEmpty, !mentionsDraft.isEmpty {
            self.inputToolbar.atCache.setMentions(mentionsDraft, body: draft)
        }
    }
    
    func saveDraft() {
        guard !self.inputToolbar.isHidden else {
            if isGroupConversation,
               let groupThread = self.thread as? TSGroupThread,
               !groupThread.isLocalUserInGroup() {
                
                databaseStorage.asyncWrite { [weak self] transaction in
                    guard let self else { return }
                    self.thread.clearDraft(with: transaction)
                }
            }
            return
        }
        
        var draftQuoteMessageId: String = .empty
        if let replyModel = self.inputToolbar.quotedReplyDraft, let interaction = replyModel.replyItem?.interaction {
            draftQuoteMessageId = interaction.uniqueId
        }
        let currentDraft = self.inputToolbar.messageBodyForSending
        let previousMessageDraft = self.thread.messageDraft
        let previousDraftQuoteMessageId = self.thread.draftQuoteMessageId
        
        if currentDraft != previousMessageDraft ||
            draftQuoteMessageId != previousDraftQuoteMessageId {
            
            databaseStorage.asyncWrite { [weak self] transaction in
                guard let self else { return }
                // TODO: perf combine setDraft and setDraftQuoteMessageId
                if let currentDraft = currentDraft {
                    let currentMentionsDraft = self.inputToolbar.atCache.allMentions(currentDraft)
                    self.thread.setMentionsDraft(currentMentionsDraft, transaction: transaction)
                    self.thread.setDraft(currentDraft, transaction: transaction)
                }
                
                self.thread.setDraftQuoteMessageId(draftQuoteMessageId, transaction: transaction)
                
                transaction.addAsyncCompletionOnMain {
                    NotificationCenter.default.post(name: .DTSaveDraftSucess, object: nil)
                }
            }
        }
    }
}

// MARK: - Keyboard Shortcuts

@objc
extension ConversationViewController {
    @objc func popKeyBoard() {
        self.inputToolbar.beginEditingMessage()
    }

    func dismissKeyBoard(byUserAction: Bool = false) {
        // 用户正在输入时，非用户主动操作不收起键盘
        if isUserActivelyTyping && !byUserAction {
            return
        }
        Logger.info("[Keyboard] dismissKeyBoard byUserAction=\(byUserAction), isFirstResponder=\(inputToolbar.inputTextView.isFirstResponder), textLen=\(inputToolbar.inputTextView.text?.count ?? 0)")
        self.inputToolbar.endEditingMessage()
        self.inputToolbar.clearDesiredKeyboard()
    }

    /// 强制收起键盘（仅用于页面消失、退群等真正需要强制收起的场景）
    func forceDissmissKeyBoard() {
        Logger.info("[Keyboard] forceDissmissKeyBoard, isFirstResponder=\(inputToolbar.inputTextView.isFirstResponder), textLen=\(inputToolbar.inputTextView.text?.count ?? 0)")
        self.inputToolbar.endEditingMessage()
        self.inputToolbar.clearDesiredKeyboard()
    }
}

// MARK: - InputAccessoryPlaceholder

extension ConversationViewController: InputAccessoryViewPlaceholderDelegate {
    public func inputAccessoryPlaceholderKeyboardIsPresenting(animationDuration: TimeInterval,
                                                              animationCurve: UIView.AnimationCurve) {
        AssertIsOnMainThread()

        handleKeyboardStateChange(animationDuration: animationDuration,
                                  animationCurve: animationCurve)
    }

    public func inputAccessoryPlaceholderKeyboardDidPresent() {
        guard viewHasEverAppeared else { return }

        updateBottomBarPosition()
        updateContentInsets(animated: false)

        // 键盘完全显示后，清除搜索跳转的焦点保护
        let hasFocusMessage = conversationViewModel.viewState.focusItemIndex != nil
        let justCompletedInitialScroll = viewState.hasCompletedInitialScroll && !viewState.userHasScrolled

        if hasFocusMessage && justCompletedInitialScroll {
            conversationViewModel.focusMessageIdOnOpen = nil
            conversationViewModel.clearFocusMessageIndex()
            viewState.userHasScrolled = true
        }
    }

    public func inputAccessoryPlaceholderKeyboardIsDismissing(animationDuration: TimeInterval,
                                                              animationCurve: UIView.AnimationCurve) {
        AssertIsOnMainThread()

        handleKeyboardStateChange(animationDuration: animationDuration,
                                  animationCurve: animationCurve)
    }

    public func inputAccessoryPlaceholderKeyboardDidDismiss() {
        if viewHasEverAppeared {
            updateBottomBarPosition()
            updateContentInsets(animated: false)
        }
    }

    public func inputAccessoryPlaceholderKeyboardIsDismissingInteractively() {
        AssertIsOnMainThread()
        // Guard against being called before view is properly initialized
        // This matches the pattern used in didPresent/didDismiss methods
        // and prevents crashes when keyboard observer fires during early initialization
        guard viewHasEverAppeared else {
            return
        }

        // No animation, just follow along with the keyboard.
        self.isDismissingInteractively = true
        updateBottomBarPosition()
        self.isDismissingInteractively = false
    }

    private func handleKeyboardStateChange(animationDuration: TimeInterval,
                                           animationCurve: UIView.AnimationCurve) {
        AssertIsOnMainThread()

        if let transitionCoordinator = self.transitionCoordinator,
           transitionCoordinator.isInteractive {
            return
        }

        let isAnimatingHeightChange = viewState.inputToolbar?.isAnimatingHeightChange ?? false
        let duration = isAnimatingHeightChange ? ConversationInputToolbar.heightChangeAnimationDuration : animationDuration

        if shouldAnimateKeyboardChanges, duration > 0 {

            // The animation curve provided by the keyboard notifications
            // is a private value not represented in UIViewAnimationOptions.
            // We don't use a block based animation here because it's not
            // possible to pass a curve directly to block animations.
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.beginFromCurrentState, animationCurve.asAnimationOptions],
                animations: { [self] in
                    updateBottomBarPosition()
                }
            )
            updateContentInsets(animated: true)
        } else {
            updateBottomBarPosition()
            updateContentInsets(animated: false)
        }
    }
    
    func updateInputAccessoryPlaceholderHeight() {
        AssertIsOnMainThread()

        // If we're currently dismissing interactively, skip updating the
        // input accessory height. Changing it while dismissing can lead to
        // an infinite loop of keyboard frame changes as the listeners in
        // InputAcessoryViewPlaceholder will end up calling back here if
        // a dismissal is in progress.
        guard !self.isDismissingInteractively else {
            return
        }

        // Apply any pending layout changes to ensure we're measuring the up-to-date height.
        self.bottomBar.superview?.layoutIfNeeded()

        // Only update if the height has actually changed to prevent layout loops
        let newHeight = self.bottomBar.height
        guard abs(self.inputAccessoryPlaceholder.desiredHeight - newHeight) > 0.01 else {
            return
        }

        self.inputAccessoryPlaceholder.desiredHeight = newHeight
    }
    
    func fixKeyboardLayoutAfterForeground() {
        AssertIsOnMainThread()
        
        // When returning from background, the keyboard state might be out of sync
        // Force sync the keyboard state first
        inputAccessoryPlaceholder.syncKeyboardState()
        
        // Force update the input accessory placeholder height and content insets
        updateInputAccessoryPlaceholderHeight()
        
        // If keyboard is visible, ensure the message list is properly positioned
        if inputToolbar.isInputViewFirstResponder {
            // Small delay to ensure keyboard frame is stable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                // Force update the bottom bar position and content insets
                self.updateBottomBarPosition()
                self.updateContentInsets(animated: false)
                
                // If we were at the bottom, stay at the bottom
                // But don't scroll if there's a focus message from search
                // Only check focusMessageIdOnOpen (not focusItemIndex) to avoid false positives
                let hasFocusMessageFromSearch = conversationViewModel.focusMessageIdOnOpen != nil

                if self.isScrolledToBottom && !hasFocusMessageFromSearch {
                    self.scrollToBottom(animated: true)
                }
            }
        } else {
            // Even when keyboard is not visible, ensure layout is correct
            updateBottomBarPosition()
            updateContentInsets(animated: false)
        }
    }
}
