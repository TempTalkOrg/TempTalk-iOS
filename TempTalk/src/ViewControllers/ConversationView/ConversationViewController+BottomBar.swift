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
        let inputToolbar = ConversationInputToolbar(conversationStyle: self.conversationStyle,
                                                    messageDraft: self.thread.messageDraft,
                                                    quotedReplyDraft: quotedReplyDraft,
                                                    inputToolbarDelegate: self,
                                                    inputTextViewDelegate: self,
                                                    inputToolbarState: inputToolbarState(),
                                                    relationship: inputToolbarRelationship(),
                                                    threadType: threadType)
        viewState.inputToolbar = inputToolbar
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
        return inputToolbar
    }
    
    func updateBottomBarPosition() {
        AssertIsOnMainThread()
        
        guard self.isViewVisible else {
            return
        }
        
        // Don't update the bottom bar position if an interactive pop is in progress
        switch navigationController?.interactivePopGestureRecognizer?.state {
        case .possible, .failed:
            break
        default:
            return
        }
        
        self.bottomBarBottomConstraint?.constant = -self.inputAccessoryPlaceholder.keyboardOverlap
        
        // We always want to apply the new bottom bar position immediately,
        // as this only happens during animations (interactive or otherwise)
        self.bottomBar.superview?.layoutIfNeeded()
    }
    
    func hideInputIfNeeded() {
        if peek {
            inputToolbar.isHidden = true
            dismissKeyBoard()
            return
        }
        if isUserLeftGroup {
            // user has requested they leave the group. further sends disallowed
            inputToolbar.isHidden = true
            dismissKeyBoard()
        } else {
            inputToolbar.isHidden = false
        }
    }
    
    func updateContentInsets(animated: Bool) {
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
        
        // Ensure the latest bottomBar height is retrieved to avoid using stale height values
        self.bottomBar.setNeedsLayout()
        self.bottomBar.layoutIfNeeded()
        
        // Recalculate the bottom padding to ensure precision
        let keyboardOverlap = inputAccessoryPlaceholder.keyboardOverlap
        let bottomBarHeight = bottomBar.bounds.height
        let bottomLayoutGuideLength = self.bottomLayoutGuide.length
        
        newInsets.bottom = max(0, keyboardOverlap + bottomBarHeight - bottomLayoutGuideLength)
        
        let wasScrolledToBottom = self.isScrolledToBottom
        
        // Changing the contentInset can change the contentOffset, so make sure we
        // stash the current value before making any changes.
        let oldYOffset = collectionView.contentOffset.y
        
        if collectionView.contentInset != newInsets {
            collectionView.contentInset = newInsets
        }
        collectionView.scrollIndicatorInsets = newInsets
        
        func adjustInsets() {
            // Adjust content offset to prevent the presented keyboard from obscuring content.
            if !self.viewHasEverAppeared {
                scrollToDefaultPosition(animated: false)
                
            } else if wasScrolledToBottom {
                // If we were scrolled to the bottom, don't do any fancy math. Just stay at the bottom.
                scrollToBottom(animated: false)
                
            } else if self.isViewCompletelyAppeared {
                // The content offset can go negative, up to the size of the top layout guide.
                // This accounts for the extended layout under the navigation bar.
                let insetChange = newInsets.bottom - oldInsets.bottom
                
                // Only update the content offset if the inset has changed.
                if insetChange != 0 {
                    // The content offset can go negative, up to the size of the top layout guide.
                    // This accounts for the extended layout under the navigation bar.
                    let minYOffset = -self.topLayoutGuide.length
                    let newYOffset = CGFloatClamp(oldYOffset + insetChange, minYOffset, safeContentHeight)
                    let newOffset = CGPointMake(0, newYOffset)
                    collectionView.setContentOffset(newOffset, animated: false)
                }
            }
        }
        
        if animated {
            adjustInsets()
        } else {
            UIView.performWithoutAnimation {
                adjustInsets()
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
    func popKeyBoard() {
        self.inputToolbar.beginEditingMessage()
    }
    
    func dismissKeyBoard() {
        if self.inputToolbar.isFirstResponder {
            self.inputToolbar.endEditingMessage()
        }
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
        AssertIsOnMainThread()

        updateBottomBarPosition()
        updateContentInsets(animated: false)
    }

    public func inputAccessoryPlaceholderKeyboardIsDismissing(animationDuration: TimeInterval,
                                                              animationCurve: UIView.AnimationCurve) {
        AssertIsOnMainThread()

        handleKeyboardStateChange(animationDuration: animationDuration,
                                  animationCurve: animationCurve)
    }

    public func inputAccessoryPlaceholderKeyboardDidDismiss() {
        AssertIsOnMainThread()

        updateBottomBarPosition()
        updateContentInsets(animated: false)
    }

    public func inputAccessoryPlaceholderKeyboardIsDismissingInteractively() {
        AssertIsOnMainThread()

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
//            if hasViewDidAppearEverCompleted {
//                // Make note of when the keyboard animation will block
//                // loads from landing during the keyboard animation.
//                // It isn't safe to block loads for long, so we cap
//                // how long they will be blocked for.
//                let animationCompletionDate = Date().addingTimeInterval(duration)
//                let lastKeyboardAnimationDate = Date().addingTimeInterval(-1.0)
//                if viewState.lastKeyboardAnimationDate == nil || viewState.lastKeyboardAnimationDate! < lastKeyboardAnimationDate {
//                    viewState.lastKeyboardAnimationDate = animationCompletionDate
//                }
//            }

            // The animation curve provided by the keyboard notifications
            // is a private value not represented in UIViewAnimationOptions.
            // We don't use a block based animation here because it's not
            // possible to pass a curve directly to block animations.
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: animationCurve.asAnimationOptions,
                animations: { [self] in
                    updateBottomBarPosition()
                    // To minimize risk, only animatedly update insets when animating quoted reply for now
                    if isAnimatingHeightChange { updateContentInsets(animated: false) }
                }
            )
            if !isAnimatingHeightChange { updateContentInsets(animated: false) }
        } else {
            updateBottomBarPosition()
            updateContentInsets(animated: false)
        }
    }
    
//    private func handleKeyboardStateChange(
//        animationDuration: TimeInterval,
//        animationCurve: UIView.AnimationCurve
//    ) {
//        guard shouldAnimateKeyboardChanges else {
//            // Force layout update even when animation is not required
//            updateBottomBarPosition()
//            updateContentInsets(animated: false)
//            return
//        }
//        guard inputToolbar.isInputViewFirstResponder else {
//            // Force layout update even when animation is not required
//            updateBottomBarPosition()
//            updateContentInsets(animated: false)
//            return
//        }
//        if animationDuration > 0 {
//            // The animation curve provided by the keyboard notifications
//            // is a private value not represented in UIViewAnimationOptions.
//            // We don't use a block based animation here because it's not
//            // possible to pass a curve directly to block animations.
//            UIView.beginAnimations("keyboardStateChange", context: nil)
//            UIView.setAnimationBeginsFromCurrentState(true)
//            UIView.setAnimationCurve(animationCurve)
//            UIView.setAnimationDuration(animationDuration)
//            updateBottomBarPosition()
//            UIView.commitAnimations()
//            updateContentInsets(animated: true)
//        } else {
//            updateBottomBarPosition()
//            updateContentInsets(animated: false)
//        }
//    }
    
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
        
        let newDesiredHeight = self.bottomBar.height
        
        // 只有当高度真正改变时才更新，避免不必要的布局更新
        if abs(self.inputAccessoryPlaceholder.desiredHeight - newDesiredHeight) > 0.1 {
            self.inputAccessoryPlaceholder.desiredHeight = newDesiredHeight
            
            // 延迟执行内容边距更新，确保inputAccessoryPlaceholder状态已同步
            DispatchQueue.main.async { [weak self] in
                self?.updateContentInsets(animated: false)
            }
        }
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
                if self.isScrolledToBottom {
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
