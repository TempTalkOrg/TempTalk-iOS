//
//  ConversationViewController+Block.swift
//  Signal
//
//  Created by Jaymin on 2024/1/16.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

// MARK: - Public

@objc
extension ConversationViewController {
    private var reminderView: DTRemindView {
        viewState.remindView
    }
    
    private var blockView: UIView {
        viewState.blockView
    }
    
    func setupRemindView() {
        view.addSubview(reminderView)
        reminderView.autoPinEdge(toSuperviewSafeArea: .top)
        reminderView.autoPinEdge(.left, to: .left, of: view)
        reminderView.autoPinEdge(.right, to: .right, of: view)
    }
    
    func setupBlockView() {
        let unblockBtn = UIButton()
        let tintColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x82C1FC) : UIColor.color(rgbHex: 0x056FFA)
        unblockBtn.setTitleColor(tintColor, for: .normal)
        unblockBtn.setTitle(Localized("BLOCK_USER_UNBLOCK"), for: .normal)
        unblockBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        unblockBtn.addTarget(self, action: #selector(unblockButtonClick), for: .touchUpInside)
        blockView.addSubview(unblockBtn)
        unblockBtn.autoAlignAxis(toSuperviewAxis: .vertical) // 水平居中
        unblockBtn.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        unblockBtn.autoSetDimension(.width, toSize: 100)
        
        let borderView = UIView()
        borderView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x2B3139) : UIColor.color(rgbHex: 0xEAECEF)
        blockView.addSubview(borderView)
        borderView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        borderView.autoSetDimension(.height, toSize: 1)
        
        view.addSubview(blockView)
        blockView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.white
        blockView.isHidden = true
        blockView.autoPinEdge(toSuperviewEdge: .bottom)
        blockView.autoPinEdge(.left, to: .left, of: view)
        blockView.autoPinEdge(.right, to: .right, of: view)
        blockView.autoSetDimension(.height, toSize: 54 + bottomInset)
    }
    
    func checkBotBlock() {
        if thread.serverThreadId.count <= 6, thread.isBlocked {
            reminderView.isHidden = false
        } else {
            reminderView.isHidden = true
        }
    }
    
    @MainActor
    func checkContactBlock() {
        guard let conversationEntity = thread.conversationEntity else {
            blockView.isHidden = true
            Logger.info("conversationEntity not ready, please retry delay")
            checkContactBlockWithDelay()
            return
        }
        
        guard thread is TSContactThread else {
            blockView.isHidden = true
            return
        }
        
        let isBlocked = conversationEntity.blockStatus == 1
    
        guard blockView.superview != nil else {
            return
        }
        
        blockView.isHidden = !isBlocked
        
        Logger.info("[conversation] blockView status \(isBlocked)")
    }
    
    @MainActor
    private func checkContactBlockWithDelay(retryCount: Int = 0) {
        let maxRetries = 10 // Limit to 5 seconds total
        guard retryCount < maxRetries else {
            Logger.error("[conversation] conversationEntity failed to load after maximum retries")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if self.thread.conversationEntity != nil {
                self.checkContactBlock()
            } else {
                Logger.info("[conversation] conversationEntity delay again, retry \(retryCount + 1)")
                self.checkContactBlockWithDelay(retryCount: retryCount + 1)
            }
        }
    }
    
    @MainActor
    func safeUpdateBlockStatus() {
        guard isViewLoaded else {
            Logger.info("conversationview not loaded")
            return
        }
        
        // 检查 block 状态
        checkContactBlock()
    }
    
    func unblockButtonClick() {
        let conversationID = thread.serverThreadId
        DTConversationSettingHelper.sharedInstance().configBlockStatus(withConversationID: conversationID, blockStatus: 0) { [weak self] in
            // 成功取消屏蔽后，更新 UI 状态
            DispatchQueue.main.async {
                self?.safeUpdateBlockStatus()
                DTToastHelper.show(withInfo: Localized("CONVERSATION_SETTINGS_STICKY_UNBLOCK_TIP"))
            }
        } failure: {
            Task { @MainActor in
                DTToastHelper.show(withInfo: Localized("BLOCK_USER_BLOCK_FAILURE_TIPS"))
            }
        }
    }
    
    func applyThemeForReminderView() {
        reminderView.applyTheme()
    }
    
    // 此处和产品 Mirana 沟通多次无果 明确要异步,且用户只要发送消息，block状态自动取消
    func asyncConfigBlockStatus() {
        guard thread.serverThreadId.count <= 6, thread.isBlocked else {
            return
        }
        DTConversationSettingHelper.sharedInstance().configBlockStatus(
            withConversationID: thread.serverThreadId,
            blockStatus: NSNumber(value: 0)
        ) {
            DTToastHelper.toast(
                withText: Localized("CONVERSATION_SETTINGS_STICKY_UNBLOCK_TIP", ""),
                durationTime: 3
            )
        } failure: {
            // 用户无感不做提示
        }
    }
    
    private var bottomInset: CGFloat {
        let keyWindow = UIApplication.shared.windows.last { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.bottom ?? 0
    }
}
