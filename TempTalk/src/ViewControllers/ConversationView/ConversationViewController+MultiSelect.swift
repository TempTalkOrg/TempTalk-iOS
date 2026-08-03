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
        return viewState.selectedMessageItems.first(where: { $0.isEqual(to: viewItem) }) != nil
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
        if viewState.selectedMessageItems.count == maxMsgCount, !isSelected {
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
            addSelectedMessage(viewItem)
        } else {
            removeSelectedMessage(viewItem)
        }

        let recallableCount = countRecallableMessages()
        forwardToolbar.updateActionItemsSelectedCount(
            UInt(viewState.selectedMessageItems.count),
            maxCount: 50,
            enableCounts: [1, 1, 1, NSNumber(value: recallableCount > 0 ? 1 : UInt.max)],
            recallableCount: UInt(recallableCount)
        )
        if let cell = collectionView.cellForItem(at: indexPath) as? ConversationMessageCell {
            cell.isCellSelected = !isSelected
        }
    }

    func addSelectedMessage(_ item: ConversationViewItem) {
        viewState.selectedMessageItems.append(item)
    }

    func removeSelectedMessage(_ item: ConversationViewItem) {
        let remaining = viewState.selectedMessageItems.filter { !$0.isEqual(to: item) }
        viewState.selectedMessageItems = remaining
    }

    func clearSelectedMessages() {
        viewState.selectedMessageItems.removeAll()
    }

    /// Remove stale items from the selection after a data reload
    /// (e.g. a message was recalled by the sender while multi-select is active).
    func pruneSelectedMessagesIfNeeded() {
        guard isMultiSelectMode else { return }

        let currentIds = Set(viewItems.map { $0.interaction.uniqueId })
        let before = viewState.selectedMessageItems.count
        viewState.selectedMessageItems.removeAll { !currentIds.contains($0.interaction.uniqueId) }

        guard viewState.selectedMessageItems.count != before else { return }

        let recallableCount = countRecallableMessages()
        forwardToolbar.updateActionItemsSelectedCount(
            UInt(viewState.selectedMessageItems.count),
            maxCount: 50,
            enableCounts: [1, 1, 1, NSNumber(value: recallableCount > 0 ? 1 : UInt.max)],
            recallableCount: UInt(recallableCount)
        )
        collectionView.reloadData()
    }

    func countRecallableMessages() -> Int {
        let currentTimestamp = NSDate.ows_millisecondTimeStamp()
        let recallThreshold = DTRecallConfig.fetch().timeoutInterval

        return viewState.selectedMessageItems.filter { viewItem in
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
        // Index mapping: 0=Forward, 1=Copy, 2=Save, 3=Recall
        switch index {
        case 0:
            // Forward style is decided by selection count:
            // exactly 1 selected -> one-by-one forward; >= 2 selected -> combined forward.
            forwardMessages(forwardType: viewState.selectedMessageItems.count > 1 ? .combined : .oneByOne)
        case 1:
            copySelectedMessages()
        case 2:
            forwardMessages(forwardType: .note)
        case 3:
            batchRecallMessages()
        default:
            break
        }
    }

    func items(for multiSelectToolBar: DTMultiSelectToolbar) -> [DTMultiSelectToolbarItem] {
        [
            .init(imageName: "toolbar-forward",
                  title: Localized("MESSAGE_ACTION_FORWARD")),
            .init(imageName: "conversation_muti_tabler_copy",
                  title: Localized("MESSAGE_ACTION_COPY")),
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
