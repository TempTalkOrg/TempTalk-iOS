//
//  ConversationViewController+friend.swift
//  Signal
//
//  Created by Kris.s on 2024/11/22.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
extension ConversationViewController: DTRequestBarDelegate {
    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, ignoreSender: UIButton) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func didTapConversationRequestBarDelegate(_ requestBar: DTRequestBar, acceptSender: UIButton) {
        
        guard let contactThread = self.thread as? TSContactThread else {
            return
        }
        
        DTToastHelper.show()
        AddFriendHandler.requestAddFriend(identifier: contactThread.contactIdentifier(),
                                          sourceType: .inUserCard,
                                          sourceConversationID: nil,
                                          shareContactCardUId: nil,
                                          action: nil,
                                          success: {
            DTToastHelper.hide()
            // Remove warning header when friend request is accepted
            self.removeWarningHeaderIfNeeded(force: true)
        }) { errorString in
            OWSLogger.error("request accept friend error: \(errorString)!")
            DTToastHelper.hide()
            DTToastHelper.toast(withText: errorString, in: self.view, durationTime: 3.0, afterDelay: 0.2)
        }

    }
    
    
    var friendReqBar: DTRequestBar {

        if let requestBar = viewState.friendReqBar {
            return requestBar
        }

        let requestBar = DTRequestBar()
        requestBar.delegate = self
        return requestBar
    }

    var warningHeaderView: DTConversationWarningHeaderView {
        if let headerView = viewState.warningHeaderView {
            return headerView
        }

        let headerView = DTConversationWarningHeaderView()
        viewState.warningHeaderView = headerView
        return headerView
    }

    var isFriend: Bool {
        guard let contactThread = self.thread as? TSContactThread else {
            return false
        }
        return contactThread.isFriend
    }
    
    var isBot: Bool {
        if self.thread.isKind(of: TSContactThread.self) {
            let isNotBot = (self.thread.contactIdentifier()?.count ?? 0) > 6
            return !isNotBot
        }
        return false
    }
    
    var showRequestBar: Bool {
        if isFriend {
            return false
        }
        guard let contactThread = self.thread as? TSContactThread else {
            return false
        }
        return contactThread.receivedFriendReq
    }

    var showWarningHeader: Bool {
        guard let _ = self.thread as? TSContactThread else {
            return false
        }
        return !isFriend
    }

    func updateWarningHeaderLayout() {
        if !showWarningHeader {
            removeWarningHeaderIfNeeded()
            return
        }

        guard let headerView = viewState.warningHeaderView else {
            return
        }

        let width = collectionView.bounds.width
        let height = headerView.intrinsicContentSize.height

        headerView.frame = CGRect(x: 0, y: -height, width: width, height: height)

        if collectionView.contentInset.top != height {
            var currentInset = collectionView.contentInset
            currentInset.top = height
            collectionView.contentInset = currentInset

            var scrollInset = collectionView.scrollIndicatorInsets
            scrollInset.top = height
            collectionView.scrollIndicatorInsets = scrollInset
        }
    }

    func removeWarningHeaderIfNeeded(force: Bool = false) {
        guard let headerView = viewState.warningHeaderView,
              headerView.superview != nil else {
            return
        }

        guard force || isFriend else {
            return
        }

        headerView.removeFromSuperview()
        viewState.warningHeaderView = nil

        var currentInset = collectionView.contentInset
        currentInset.top = 0
        collectionView.contentInset = currentInset

        var scrollInset = collectionView.scrollIndicatorInsets
        scrollInset.top = 0
        collectionView.scrollIndicatorInsets = scrollInset
    }

    //send message
    func handleAddFriendRequest(message: TSMessage,
                                sourceType: DTSourceToPersonalCardType,
                                sourceConversationID: String?,
                                shareContactCardUId: String?,
                                action: String?) {
        
        guard let contactThread = self.thread as? TSContactThread else {
            return
        }
        
        if message is DTScreenShotOutgoingMessage {
            return
        }
        
        if isFriend {
            return
        }
        
        let diffTime = TimeInterval(NSDate.ows_millisecondTimeStamp()) - viewState.friendReqTime
        
        if diffTime < 2 * kSecondInterval {
            return
        }
        
        AddFriendHandler.requestAddFriend(identifier: contactThread.contactIdentifier(),
                                          sourceType: sourceType,
                                          sourceConversationID: sourceConversationID,
                                          shareContactCardUId: shareContactCardUId,
                                          action: action,
                                          success: {
            self.markSendAddFriendAction()
        }) { errorString in
            OWSLogger.error("requestAddFriend after message error: \(errorString)!")
        }
        
    }
    
    func markSendAddFriendAction() {
        guard self.thread is TSContactThread else {
            return
        }
        self.viewState.friendReqTime = TimeInterval(NSDate.ows_millisecondTimeStamp())
    }
    
}
