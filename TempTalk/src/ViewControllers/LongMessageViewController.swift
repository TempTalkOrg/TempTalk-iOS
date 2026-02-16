//
//  LongMessageViewController.swift
//  Difft
//
//  Created by henry on 2025/11/19.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import SnapKit
import SignalCoreKit
import PanModal

// MARK: - CustomTextView

/// 自定义 UITextView，禁用系统菜单但保留选中效果
private class LongMessageTextView: UITextView {

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // 禁用所有系统菜单项
        return false
    }
}

// MARK: - LongMessageViewController

@objc
public class LongMessageViewController: OWSViewController {

    // MARK: - Properties

    private let viewItem: ConversationViewItem?
    private let messageBody: String
    private var messageTextView: UITextView?
    private var textViewHeightConstraint: Constraint?

    // Action menu
    private var actionMenuController: ConversationActionMenuController?

    // 标记是否正在调整文本选择（拖拽光标）
    private var isAdjustingSelection = false

    // 记录滚动开始时的触摸点位置
    private var scrollBeganTouchPoint: CGPoint?

    // 用于管理菜单显示的延迟任务，可以取消
    private var menuPresentWorkItem: DispatchWorkItem?

    // Forward
    private var targetThreads: [TSThread]?
    private var forwardingText: String?

    // 标记是否全选转发（用于判断是否带消息来源）
    private var isForwardingFullText = false

    static let kVisitingCardScheme = "personinfocard"

    // MARK: - Initialization

    @available(*, unavailable, message:"use other constructor instead.")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc
    public required init(viewItem: ConversationViewItem) {
        self.viewItem = viewItem
        self.messageBody = LongMessageViewController.displayableText(viewItem: viewItem)
        super.init()
    }

    @objc
    public required init(messageBody: String) {
        self.viewItem = nil
        self.messageBody = messageBody
        super.init()
    }

    private class func displayableText(viewItem: ConversationViewItem) -> String {
        guard viewItem.hasBodyText else {
            return ""
        }
        guard let displayableText = viewItem.displayableBodyText() else {
            return ""
        }
        return displayableText.fullText
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadContent()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 确保主题正确应用
        applyTheme()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.bg1Color

        // 添加点击手势，点击屏幕任意位置即可关闭
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        // 创建自定义 UITextView（禁用系统菜单）
        messageTextView = LongMessageTextView()
        messageTextView?.backgroundColor = .clear
        messageTextView?.isEditable = false
        messageTextView?.isSelectable = true  // 启用选择功能
        messageTextView?.isScrollEnabled = true
        messageTextView?.dataDetectorTypes = .link
        messageTextView?.delegate = self
        messageTextView?.showsHorizontalScrollIndicator = false
        messageTextView?.showsVerticalScrollIndicator = true
        messageTextView?.isUserInteractionEnabled = true
        messageTextView?.textContainer.lineBreakMode = .byWordWrapping
        messageTextView?.layoutManager.allowsNonContiguousLayout = false
        messageTextView?.layoutManager.usesFontLeading = true
        messageTextView?.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        messageTextView?.linkTextAttributes = [
            .foregroundColor: Theme.tinfoColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        // 添加点击手势到 TextView，用于取消选择
        let textViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTextViewTap(_:)))
        textViewTapGesture.delegate = self
        messageTextView?.addGestureRecognizer(textViewTapGesture)

        if let messageTextView = messageTextView {
            view.addSubview(messageTextView)
            messageTextView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualTo(view.safeAreaLayoutGuide.snp.top).offset(30)
            make.bottom.lessThanOrEqualTo(view.safeAreaLayoutGuide.snp.bottom).offset(-30)
            textViewHeightConstraint = make.height.equalTo(100).constraint // 初始高度，会在 loadContent 中更新
            }
        }

        applyTheme()
    }

    private func loadContent() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let viewItem = self.viewItem {
                let attributedText = self.buildAttributedText(viewItem: viewItem)
                self.messageTextView?.attributedText = attributedText
            } else {
                let attributedText = self.buildPlainAttributedText(text: self.messageBody)
                self.messageTextView?.attributedText = attributedText
            }

            // 计算内容实际需要的高度
            let textViewWidth = UIScreen.main.bounds.width - 56 // 28*2 padding
            guard let messageTextView = self.messageTextView else { return }
            let size = messageTextView.sizeThatFits(CGSize(
                width: textViewWidth,
                height: .greatestFiniteMagnitude
            ))

            // 更新高度约束
            let maxHeight = UIScreen.main.bounds.height - 100 // 留出上下安全区域
            let targetHeight = min(size.height, maxHeight)
            self.textViewHeightConstraint?.update(offset: targetHeight)

            // 强制布局更新，确保frame有正确的值
            self.view.layoutIfNeeded()

            self.messageTextView?.contentOffset = .zero
        }
    }

    // MARK: - Attributed Text Building

    private func buildPlainAttributedText(text: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 24, weight: .regular)
        let textColor = Theme.tprimaryColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 12  // 36px line height - 24px font size = 12px spacing
        // 根据文本长度判断对齐方式：大于200字使用左对齐，否则居中对齐
        paragraphStyle.alignment = text.count > 200 ? .left : .center

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    private func buildAttributedText(viewItem: ConversationViewItem) -> NSAttributedString {
        guard let displayableBodyText = viewItem.displayableBodyText() else {
            return buildPlainAttributedText(text: messageBody)
        }

        let text = displayableBodyText.fullText
        guard !text.isEmpty else {
            return buildPlainAttributedText(text: messageBody)
        }

        // 使用更大的字体（24pt）
        let font = UIFont.systemFont(ofSize: 24, weight: .regular)
        let textColor = Theme.tprimaryColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 12  // 36px line height - 24px font size = 12px spacing
        // 根据文本长度判断对齐方式：大于200字使用左对齐，否则居中对齐
        paragraphStyle.alignment = text.count > 200 ? .left : .center

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        // Handle forward message source links
        DTPatternHelper.getForwardMessageSourceText(with: text, withCallBackCheckingResult: { resultArray in
            resultArray.forEach { result in
                let range = result.range(at: 0)
                if range.length > 0 {
                    let substring = text.substring(withRange: range)
                    let uid = DTPatternHelper.getForwardUidString(substring)
                    attributedString.addAttribute(
                        .link,
                        value: "\(Self.kVisitingCardScheme)://\(uid)",
                        range: range
                    )
                    attributedString.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: Theme.tinfoColor,
                        range: range
                    )
                }
            }
        })

        // Handle mentions
        if let mentions = viewItem.mentions {
            mentions.forEach { mention in
                let range = NSMakeRange(Int(mention.start), Int(mention.length))
                if range.location + range.length > text.count {
                    Logger.error("[mention] range:\(range) out of bounds")
                    return
                }
                attributedString.addAttribute(
                    .foregroundColor,
                    value: Theme.tinfoColor,
                    range: range
                )
                attributedString.addAttribute(
                    .link,
                    value: "\(Self.kVisitingCardScheme)://\(mention.uid)",
                    range: range
                )
            }
        }

        return attributedString
    }
    
    public override func applyTheme() {
        super.applyTheme()

        view.backgroundColor = Theme.bg1Color

        // 重新构建 attributedText 以应用新的主题颜色
        if let viewItem = self.viewItem {
            let attributedText = self.buildAttributedText(viewItem: viewItem)
            messageTextView?.attributedText = attributedText
        } else if !messageBody.isEmpty {
            let attributedText = self.buildPlainAttributedText(text: messageBody)
            messageTextView?.attributedText = attributedText
        }
    }

    // MARK: - Actions

    @objc private func handleTap() {
        // 如果有菜单，关闭菜单和选择
        if let actionMenuController = actionMenuController {
            dismissMenuAndCancelSelection()
            return
        }

        // 如果 textView 正在滚动，点击只是停止滚动，不关闭页面
        if messageTextView?.isDecelerating == true || messageTextView?.isDragging == true {
            return
        }

        // 否则关闭整个页面
        dismiss(animated: true)
    }

    @objc private func handleTextViewTap(_ gesture: UITapGestureRecognizer) {
        // 如果有选中的文本或菜单，点击 TextView 空白区域取消选择
        if (messageTextView?.selectedRange.length ?? 0) > 0 || actionMenuController != nil {
            let location = gesture.location(in: messageTextView)

            // 检查点击位置是否在文本范围内
            guard let messageTextView = messageTextView else { return }
            let textContainer = messageTextView.textContainer
            let layoutManager = messageTextView.layoutManager
            let textStorage = messageTextView.textStorage

            var locationInTextContainer = location
            locationInTextContainer.x -= messageTextView.textContainerInset.left
            locationInTextContainer.y -= messageTextView.textContainerInset.top

            let characterIndex = layoutManager.characterIndex(
                for: locationInTextContainer,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            // 如果点击在文本范围外，或者在已选中文本外，取消选择
            if characterIndex >= textStorage.length || !isTapInSelectedText(characterIndex) {
                dismissMenuAndCancelSelection()
            }
        }
    }

    /// 判断点击的字符索引是否在选中文本范围内
    private func isTapInSelectedText(_ characterIndex: Int) -> Bool {
        guard let messageTextView = messageTextView else { return false }
        let selectedRange = messageTextView.selectedRange
        return characterIndex >= selectedRange.location &&
               characterIndex < selectedRange.location + selectedRange.length
    }

    // MARK: - Menu Management

    /// 显示操作菜单
    private func presentActionMenu(at point: CGPoint? = nil) {
        guard let messageTextView = messageTextView else { return }
        let actions = createMenuActions()
        let menuPosition = calculateMenuPosition()

        let menuVC = ConversationActionMenuController(
            actions: actions,
            emojiAction: nil,
            sourceView: messageTextView,
            sourceViewController: self,
            textSelectionView: nil
        )

        menuVC.dismissHandler = { [weak self] in
            self?.cancelTextSelection()
            self?.actionMenuController = nil
        }

        menuVC.isSelectedAll = isTextFullySelected()

        // 设置初始位置，避免菜单位置跳动
        // 使用兜底的选中区域（如果无法获取，使用 messageTextView 的 frame）
        let selectedRect = getSelectedTextRect() ?? (messageTextView.frame)
        menuVC.setInitialMenuPosition(
            top: menuPosition.top,
            left: menuPosition.left,
            arrowDirection: menuPosition.arrowDirection,
            sourceRect: selectedRect
        )

        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.modalTransitionStyle = .crossDissolve
        present(menuVC, animated: true)

        actionMenuController = menuVC
    }

    /// 创建菜单操作项
    private func createMenuActions() -> [MenuAction] {
        var actions: [MenuAction] = []

        // Copy
        actions.append(MenuAction(
            image: #imageLiteral(resourceName: "ic_longpress_copy"),
            title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""),
            subtitle: nil,
            block: { [weak self] _ in
                self?.copySelectedText()
            }
        ))

        // Forward
        actions.append(MenuAction(
            image: #imageLiteral(resourceName: "ic_forward"),
            title: Localized("MESSAGE_ACTION_FORWARD", comment: ""),
            subtitle: nil,
            block: { [weak self] _ in
                self?.forwardSelectedText()
            }
        ))

        // Translate
        actions.append(MenuAction(
            image: #imageLiteral(resourceName: "ic_inputbar_translate"),
            title: Localized("MESSAGE_ACTION_TRANSLATE_TEXT", comment: ""),
            subtitle: nil,
            block: { [weak self] _ in
                self?.translateSelectedText()
            }
        ))

        // Select All
        if !isTextFullySelected() {
            actions.append(MenuAction(
                image: #imageLiteral(resourceName: "ic_select_all"),
                title: Localized("MESSAGE_ACTION_SELECT_ALL", comment: ""),
                subtitle: nil,
                dismissBeforePerformAction: false,
                block: { [weak self] _ in
                    self?.selectAllText()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self?.updateMenuAfterSelectAll()
                    }
                }
            ))
        }

        return actions
    }

    /// 更新菜单（Select All 之后）
    private func updateMenuAfterSelectAll() {
        guard let actionMenuController = actionMenuController else { return }

        let actions = createMenuActions()
        actionMenuController.update(actions: actions, emojiAction: nil)
        actionMenuController.isSelectedAll = true

        positionMenuForSelectedText()
    }

    /// 关闭菜单并取消文本选择
    private func dismissMenuAndCancelSelection() {
        actionMenuController?.dismiss(animated: true) {
            self.actionMenuController = nil
        }
        cancelTextSelection()
    }

    // MARK: - Menu Actions

    private func copySelectedText() {
        guard let selectedText = getSelectedText() else { return }
        DTSecurePasteboard.setString(selectedText)
        DTToastHelper.show(withInfo: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""))
    }

    private func forwardSelectedText() {
        guard let selectedText = getSelectedText() else { return }
        // 记录是否全选
        isForwardingFullText = isTextFullySelected()
        forwardText(selectedText)
    }

    private func translateSelectedText() {
        guard let selectedText = getSelectedText() else { return }

        // 获取目标翻译语言（从 app 设置中获取）
        let targetLanguage = getTargetTranslateLanguage()
        translateText(selectedText, to: targetLanguage)
    }

    // MARK: - Menu Position Calculation

    /// 获取选中文本在 view 中的位置
    private func getSelectedTextRect() -> CGRect? {
        guard let selectedRange = messageTextView?.selectedTextRange else { return nil }

        // 获取选中文本的所有矩形区域
        let rects = messageTextView?.selectionRects(for: selectedRange)

        // 计算所有矩形的并集
        guard let tempRect = rects else { return nil }
        let unionRect = tempRect
            .filter { !$0.rect.isEmpty }
            .map { $0.rect }
            .reduce(CGRect.null) { $0.union($1) }

        guard !unionRect.isNull && !unionRect.isEmpty else { return nil }

        // 转换到 view 坐标系
        return messageTextView?.convert(unionRect, to: view)
    }

    /// 计算菜单位置信息
    private func calculateMenuPosition() -> (top: CGFloat, left: CGFloat, arrowDirection: ConversationActionMenuController.ArrowDirection) {
        guard let rectInView = getSelectedTextRect() else {
            // 兜底：如果无法获取选中区域，使用屏幕中央位置
            return getFallbackMenuPosition()
        }

        // 菜单尺寸（估算）
        let menuHeight: CGFloat = 100
        let menuWidth: CGFloat = 300
        let margin: CGFloat = 4

        // 屏幕安全区域
        let safeAreaTop = view.safeAreaInsets.top + 44
        let safeAreaBottom = view.bounds.height - view.safeAreaInsets.bottom - 20

        var menuTop: CGFloat
        var arrowDirection: ConversationActionMenuController.ArrowDirection

        // 判断上方是否有足够空间
        let canShowAbove = rectInView.minY > (safeAreaTop + menuHeight + margin)
        let canShowBelow = (rectInView.maxY + menuHeight + margin) < safeAreaBottom

        if canShowAbove {
            // 优先显示在上方
            menuTop = rectInView.minY - menuHeight - margin
            arrowDirection = .bottom
        } else if canShowBelow {
            // 显示在下方
            menuTop = rectInView.maxY + margin
            arrowDirection = .top
        } else {
            // 上下都放不下，使用兜底位置
            return getFallbackMenuPosition()
        }

        // 边界检查：确保菜单在安全区域内
        menuTop = max(safeAreaTop, min(menuTop, safeAreaBottom - menuHeight))

        // 计算左边距（居中对齐，但不超出屏幕）
        let menuLeft = max(8, min(view.bounds.width - menuWidth - 8, rectInView.midX - menuWidth / 2))

        return (top: menuTop, left: menuLeft, arrowDirection: arrowDirection)
    }

    /// 兜底菜单位置（当无法正常计算位置时使用）
    private func getFallbackMenuPosition() -> (top: CGFloat, left: CGFloat, arrowDirection: ConversationActionMenuController.ArrowDirection) {
        let menuHeight: CGFloat = 100
        let menuWidth: CGFloat = 300

        // 使用屏幕中央偏上的位置
        let screenCenterY = view.bounds.height / 2
        let menuTop = max(view.safeAreaInsets.top + 44, screenCenterY - menuHeight - 50)
        let menuLeft = (view.bounds.width - menuWidth) / 2

        // 默认箭头朝上
        return (top: menuTop, left: menuLeft, arrowDirection: .top)
    }

    /// 更新菜单位置
    private func positionMenuForSelectedText() {
        guard let actionMenuController = actionMenuController else { return }

        let menuPosition = calculateMenuPosition()
        let selectedRect = getSelectedTextRect() ?? (messageTextView?.frame ?? .zero)

        actionMenuController.setMenuPosition(
            top: menuPosition.top,
            left: menuPosition.left,
            arrowDirection: menuPosition.arrowDirection,
            sourceRect: selectedRect
        )
    }

    // MARK: - Text Selection Helpers

    /// 获取当前选中的文本
    private func getSelectedText() -> String? {
        let selectedRange = messageTextView?.selectedRange
        guard let selectedRange = selectedRange, selectedRange.length > 0 else { return nil }
        return messageTextView?.text.substring(withRange: selectedRange)
    }

    /// 判断是否全选
    private func isTextFullySelected() -> Bool {
        return messageTextView?.selectedRange.length == messageTextView?.attributedText.length
    }

    /// 全选文本
    private func selectAllText() {
        messageTextView?.selectedRange = NSRange(location: 0, length: messageTextView?.attributedText.length ?? 0)
    }

    /// 取消文本选择
    private func cancelTextSelection() {
        messageTextView?.selectedRange = NSRange(location: 0, length: 0)
    }

    // MARK: - Forward & Translate

    private func forwardText(_ text: String) {
        guard !text.isEmpty else { return }

        // 存储要转发的文本
        self.forwardingText = text

        // 显示选择线程界面
        let selectThreadVC = SelectThreadViewController()
        selectThreadVC.selectThreadViewDelegate = self
        let selectThreadNav = OWSNavigationController(rootViewController: selectThreadVC)
        self.present(selectThreadNav, animated: true, completion: nil)
    }

    /// 获取 app 设置中的目标翻译语言
    private func getTargetTranslateLanguage() -> DTTranslateMessageType {
        // 如果有 viewItem，尝试从其关联的 thread 中获取设置
        if let viewItem = viewItem,
           let translateSettingType = viewItem.thread.translateSettingType?.intValue,
           let translateType = DTTranslateMessageType(rawValue: translateSettingType) {
            // 如果设置有效且不是原文模式，返回该设置
            if translateType != .original && translateType != .unknow {
                return translateType
            }
        }

        // 默认根据系统语言选择翻译目标语言
        if DateUtil.isChinese() {
            return .chinese
        } else {
            return .english
        }
    }

    private func translateText(_ text: String, to language: DTTranslateMessageType) {
        // 创建翻译结果页面
        let sourceLanguage: DTTranslateMessageType = language == .english ? .chinese : .english
        let translateVC = TranslateResultViewController(
            originalText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: language
        )

        // 使用 PanModal 展示
        presentPanModal(translateVC)
    }

    // MARK: - First Responder

    public override var canBecomeFirstResponder: Bool {
        return true
    }

    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
    }
}

// MARK: - UITextViewDelegate

extension LongMessageViewController: UITextViewDelegate {
    public func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        // 如果有选中的文本或显示的菜单，点击 link/mention 应该先取消选中
        if textView.selectedRange.length > 0 || actionMenuController != nil {
            dismissMenuAndCancelSelection()
            return false
        }

        // 过滤掉 @all 的点击
        let mentionsAll = "\(Self.kVisitingCardScheme)://\(MENTIONS_ALL)"
        guard !URL.absoluteString.contains(mentionsAll) else { return false }

        // 使用 AppLinkManager 处理 URL（包括普通链接和 mention 点击）
        _ = AppLinkManager.handle(url: URL, fromExternal: false, sourceVC: self)
        return false
    }

    // MARK: - Scroll View Delegate (滚动处理)

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollBeganTouchPoint = scrollView.panGestureRecognizer.location(in: messageTextView)

        // 立即检查：如果触摸点不在选中区域，重置 isAdjustingSelection
        if let touchPoint = scrollBeganTouchPoint, !isTouchInSelection(touchPoint) {
            isAdjustingSelection = false
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 如果触摸点不在选中区域，立即隐藏（提高响应速度）
        if let touchPoint = scrollBeganTouchPoint, !isTouchInSelection(touchPoint) {
            // 手动滚动：隐藏菜单并取消文本选择
            if actionMenuController != nil {
                actionMenuController?.dismiss(animated: false)
                actionMenuController = nil
            }
            cancelTextSelection()
            isAdjustingSelection = false
            return
        }

        // 如果正在调整文本选择（拖拽光标），不隐藏菜单
        if isAdjustingSelection {
            return
        }

        // 其他情况：隐藏菜单并取消文本选择
        if actionMenuController != nil {
            actionMenuController?.dismiss(animated: false)
            actionMenuController = nil
        }
        cancelTextSelection()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        scrollBeganTouchPoint = nil
        isAdjustingSelection = false
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isAdjustingSelection = false
    }

    /// 判断触摸点是否在选中文本区域内
    private func isTouchInSelection(_ point: CGPoint) -> Bool {
        guard let range = messageTextView?.selectedTextRange else { return false }
        let rects = messageTextView?.selectionRects(for: range)
        guard let rects = rects else { return false }
        return rects.contains { rect in
            rect.rect.insetBy(dx: -10, dy: -10).contains(point)
        }
    }

    // MARK: - Text View Delegate (文本选择处理)

    public func textViewDidChangeSelection(_ textView: UITextView) {
        // 标记正在调整文本选择（拖拽光标）
        if textView.isFirstResponder {
            isAdjustingSelection = true
        }

        // 取消之前的延迟菜单显示任务
        menuPresentWorkItem?.cancel()
        menuPresentWorkItem = nil

        let selectedRange = textView.selectedRange

        if selectedRange.length > 0 {
            // 有选中文本：关闭旧菜单，延迟显示新菜单
            actionMenuController?.dismiss(animated: false)
            actionMenuController = nil

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self,
                      self.messageTextView?.selectedRange.length ?? 0 > 0 else { return }
                self.presentActionMenu(at: nil)
            }
            menuPresentWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        } else {
            // 无选中文本：关闭菜单并重置状态
            actionMenuController?.dismiss(animated: true)
            actionMenuController = nil
            isAdjustingSelection = false
        }
    }
}

// MARK: - SelectThreadViewControllerDelegate

extension LongMessageViewController: SelectThreadViewControllerDelegate {
    public func threadsWasSelected(_ threads: [TSThread]) {
        owsAssertDebug(threads.count > 0)
        self.targetThreads = threads

        let previewVC = DTForwardPreviewViewController()
        previewVC.modalPresentationStyle = .overFullScreen
        previewVC.delegate = self
        self.presentedViewController?.present(previewVC, animated: false, completion: nil)
    }

    public func canSelectBlockedContact() -> Bool {
        return false
    }
}

// MARK: - DTForwardPreviewDelegate

extension LongMessageViewController: DTForwardPreviewDelegate {
    func getThreadsToForwarding() -> [TSThread] {
        return self.targetThreads ?? []
    }
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?) {
        guard let messageSender = Environment.shared?.messageSender else {
            Logger.error("messageSender is nil")
            return
        }

        guard let targetThreads = self.targetThreads, !targetThreads.isEmpty else {
            Logger.error("targetThreads is nil or empty")
            return
        }

        guard let forwardingText = self.forwardingText else {
            Logger.error("forwardingText is nil")
            return
        }

        DispatchQueue.global().async {
            targetThreads.forEach { targetThread in
                // 判断是否需要带消息来源
                if self.isForwardingFullText, let viewItem = self.viewItem {
                    // 全选转发：使用 DTForwardMessageHelper 转发，会自动带上消息来源
                    let message = DTForwardMessageHelper.message(from: viewItem)
                    DispatchQueue.main.sync {
                        DTForwardMessageHelper.forwardMessageIs(
                            fromGroup: false,  // LongMessage 不在群组上下文中
                            targetThread: targetThread,
                            messages: [message],
                            success: nil,
                            failure: nil
                        )
                    }
                } else {
                    // 部分选中转发：不带来源信息，直接发送文本
                    DispatchQueue.main.sync {
                        _ = ThreadUtil.sendMessage(
                            withText: forwardingText,
                            atPersons: nil,
                            mentions: nil,
                            in: targetThread,
                            quotedReplyModel: nil,
                            messageSender: messageSender,
                            success: {},
                            failure: { _ in }
                        )
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)

                // 发送留言
                guard let leaveMsg = leaveMessage?.ows_stripped(), !leaveMsg.isEmpty else {
                    return
                }
                DispatchQueue.main.sync {
                    _ = ThreadUtil.sendMessage(
                        withText: leaveMsg,
                        atPersons: nil,
                        mentions: nil,
                        in: targetThread,
                        quotedReplyModel: nil,
                        messageSender: messageSender,
                        success: {},
                        failure: { _ in }
                    )
                }
                Thread.sleep(forTimeInterval: 0.05)
            }

            // 清除转发文本和标记
            DispatchQueue.main.async {
                self.forwardingText = nil
                self.isForwardingFullText = false
            }
        }

        self.dismiss(animated: true) {
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: "Sent"), durationTime: 1.5)
        }
    }

    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        return self.forwardingText ?? ""
    }
}

// MARK: - UIGestureRecognizerDelegate

extension LongMessageViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许手势同时识别
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果点击位置在 messageTextView 内部
        let locationInTextView = touch.location(in: messageTextView)
        guard let messageTextView = messageTextView else { return true}
        if messageTextView.bounds.contains(locationInTextView) {
            // 检查点击位置是否在链接上
            if isLocationOnLink(locationInTextView) {
                // 点击的是链接，view 的 tap 手势不响应，避免 dismiss
                return false
            }
        }
        return true
    }

    /// 判断点击位置是否在链接上
    private func isLocationOnLink(_ location: CGPoint) -> Bool {
        guard let messageTextView = messageTextView else { return false }
        
        let textContainer = messageTextView.textContainer
        let layoutManager = messageTextView.layoutManager
        let textStorage = messageTextView.textStorage

        var locationInTextContainer = location
        locationInTextContainer.x -= messageTextView.textContainerInset.left
        locationInTextContainer.y -= messageTextView.textContainerInset.top

        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard characterIndex < textStorage.length else { return false }

        // 检查该位置的字符是否有 link 属性
        let attributes = textStorage.attributes(at: characterIndex, effectiveRange: nil)
        return attributes[.link] != nil
    }
}
