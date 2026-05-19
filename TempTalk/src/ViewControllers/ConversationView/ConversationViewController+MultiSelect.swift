//
//  ConversationViewController+MultiSelect.swift
//  Difft
//
//  Multi-select UI + toolbar logic, split out of +ForwardMessage so each
//  extension carries a single responsibility.
//

import Foundation
import TTServiceKit
import TTMessaging

// MARK: - Public state

@objc extension ConversationViewController {

    var forwardToolbar: DTMultiSelectToolbar {
        get {
            if let toolbar = viewState.forwardToolbar {
                return toolbar
            }
            let newToolbar = DTMultiSelectToolbar()
            newToolbar.delegate = self
            viewState.forwardToolbar = newToolbar
            return newToolbar
        }
        set {
            viewState.forwardToolbar = newValue
        }
    }

    var isMultiSelectMode: Bool {
        get { viewState.isMultiSelectMode }
        set { viewState.isMultiSelectMode = newValue }
    }

    /// 多选模式下,是否已经选中了 message
    func isSelectedViewItemInMultiSelectMode(_ viewItem: ConversationViewItem) -> Bool {
        guard isMultiSelectMode else { return false }
        return viewState.forwardMessageItems.first(where: { $0.isEqual(to: viewItem) }) != nil
    }

    /// 多选模式下,选中或取消选中 message
    func didSelectMessageInMultiSelectMode(indexPath: IndexPath) {
        guard isMultiSelectMode else { return }
        collectionView.deselectItem(at: indexPath, animated: false)

        let viewItems = self.viewItems
        guard let viewItem = viewItems[safe: indexPath.row] else {
            owsFailDebug("Invalid view item index: \(indexPath.row)")
            return
        }

        if viewItem.isConfidentialMessage {
            DTToastHelper.toast(withText: Localized("FORWARD_MESSAGE_CONFIDENTIAL"))
            return
        }

        // 超过最大转发数量
        let isSelected = isSelectedViewItemInMultiSelectMode(viewItem)
        let maxMsgCount = 50
        if viewState.forwardMessageItems.count == maxMsgCount, !isSelected {
            DTToastHelper.toast(
                withText: String(format: Localized("FORWARD_MESSAGE_SELECT_MESSAGE_MAX_COUNT"), maxMsgCount),
                durationTime: 1
            )
            return
        }
        // 不支持转发的消息类型
        if isUnsupportMessageType(viewItem.messageCellType()) {
            DTToastHelper.toast(
                withText: Localized("FORWARD_MESSAGE_FORBIDDEN_REMINDER", comment: "attachment unsupported"),
                durationTime: 1
            )
            return
        }

        if !isSelected {
            addForwardMessage(viewItem)
        } else {
            removeForwardMessage(viewItem)
        }

        let recallableCount = countRecallableMessages()
        forwardToolbar.updateActionItemsSelectedCount(
            UInt(viewState.forwardMessageItems.count),
            maxCount: 50,
            enableCounts: [1, 2, 1, NSNumber(value: recallableCount > 0 ? 1 : UInt.max)],
            recallableCount: UInt(recallableCount)
        )
        if let cell = collectionView.cellForItem(at: indexPath) as? ConversationMessageCell {
            cell.isCellSelected = !isSelected
        }
    }

    func addForwardMessage(_ forwardMessage: ConversationViewItem) {
        viewState.forwardMessageItems.append(forwardMessage)
    }

    func removeForwardMessage(_ forwardMessage: ConversationViewItem) {
        let newForwardMessages = viewState.forwardMessageItems.filter { !$0.isEqual(to: forwardMessage) }
        viewState.forwardMessageItems = newForwardMessages
    }

    func clearAllForwardMessages() {
        viewState.forwardMessageItems.removeAll()
    }

    func countRecallableMessages() -> Int {
        let currentTimestamp = NSDate.ows_millisecondTimeStamp()
        let recallThreshold = DTRecallConfig.fetch().timeoutInterval

        return viewState.forwardMessageItems.filter { viewItem in
            guard viewItem.interaction is TSOutgoingMessage else { return false }
            let msgTimestamp = viewItem.interaction.timestamp
            guard currentTimestamp >= msgTimestamp else { return false }
            let messageDuration = Double(currentTimestamp - msgTimestamp)
            return messageDuration <= (recallThreshold * 1000)
        }.count
    }

    func applyThemeForForwardToolbar() {
        guard isMultiSelectMode else { return }
        guard let toolbar = viewState.forwardToolbar else { return }
        toolbar.applyTheme()
    }
}

// MARK: - DTMultiSelectToolbarDelegate

extension ConversationViewController: DTMultiSelectToolbarDelegate {
    func multiSelectToolbar(_: DTMultiSelectToolbar, didSelectIndex index: Int) {
        let forwardType: DTForwardMessageType = .init(rawValue: index) ?? .oneByOne

        if forwardType == .batchRecall {
            batchRecallMessages()
        } else {
            forwardMessages(forwardType: forwardType)
        }
    }

    func items(for multiSelectToolBar: DTMultiSelectToolbar) -> [DTMultiSelectToolbarItem] {
        [
            .init(imageName: "toolbar-forward",
                  title: Localized("MESSAGE_ACTION_FORWARD")),
            .init(imageName: "toolbar-combine-forward",
                  title: Localized("MESSAGE_ACTION_COMBINE_FORWARD")),
            .init(imageName: "toolbar-save",
                  title: Localized("MESSAGE_ACTION_SAVE")),
            .init(imageName: "toolbar-combine-recalled",
                  title: Localized("MESSAGE_ACTION_BATCH_RECALL"),
                  isRecallButton: true)
        ]
    }
}

// MARK: - Private helpers

private extension ConversationViewController {
    func isUnsupportMessageType(_ type: OWSMessageCellType) -> Bool {
        let unsupported: [OWSMessageCellType] = [.audio]
        return unsupported.contains(type)
    }
}
