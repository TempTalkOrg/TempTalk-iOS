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

/// Text view with all system menu items disabled. Selection and link interaction are
/// turned off entirely (isSelectable = false); taps and long-presses are driven by our
/// own gesture recognizers, so the system never paints its selection loupe or link preview.
private class LongMessageTextView: UITextView {

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
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

    // Always-available dismiss control (a long link can cover the whole screen,
    // leaving no blank area to tap for tap-to-dismiss).
    private var closeButton: UIButton?

    // Action menu
    private var actionMenuController: ConversationActionMenuController?

    // The interaction is fully custom (the text view is not selectable). A long-press either
    // targets a single link (activeLinkText set, link range highlighted, menu anchored at the
    // touch point) or the body text, where it starts a word selection that the user can extend
    // with drag handles (textSelectionView set, menu follows the selection knobs).
    private var activeLinkText: String?
    private var linkMenuAnchorRect: CGRect?
    private var highlightedLinkRange: NSRange?

    // Word/range selection for body text (reuses the chat-bubble selection component).
    private var textSelectionView: DTTextSelectionView?

    // True while the user is dragging a selection knob. Knob drags auto-scroll the text view,
    // and scrollViewDidScroll would otherwise dismiss the menu mid-adjustment; this guards it.
    private var isAdjustingSelection = false

    // True while a long-press is in flight. The tap that ends the long-press fires in the same
    // touch sequence and would otherwise immediately dismiss the just-shown menu; we swallow it
    // so the menu stays up until a separate, later tap.
    private var isHandlingLongPress = false

    // Forward
    private var targetThreads: [TSThread]?
    private var forwardingText: String?

    // Whether the current forward targets the whole message (forwards the original message,
    // carrying its source). A partial text selection forwards as plain text instead.
    private var isForwardingFullText = false

    // Whether the current forward acts on a single link. A link is "bringing a URL out" rather
    // than relaying someone's message, so it does not leave a forward-trace notice. Captured at
    // forward time because activeLinkText is cleared once the menu dismisses.
    private var isForwardingLink = false

    static let kVisitingCardScheme = "personinfocard"

    /// Text the current menu acts on: a single link when long-pressing a link, the selected
    /// substring when a body-text selection is active, otherwise the whole message.
    private var actionTargetText: String {
        if let activeLinkText { return activeLinkText }
        if let range = textSelectionView?.getSelection(), range.length > 0,
           let full = messageTextView?.text as NSString?,
           range.location + range.length <= full.length {
            return full.substring(with: range)
        }
        return messageTextView?.text ?? ""
    }

    /// Whether the active body-text selection currently covers the entire message.
    private var isSelectionWholeText: Bool {
        guard let range = textSelectionView?.getSelection(),
              let full = messageTextView?.text as NSString? else { return false }
        return range.length == full.length
    }

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
        applyTheme()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateContentInset()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.bg1Color

        // Fully custom text view: selection and the system link interaction are off, so taps
        // (open link / dismiss) and long-presses (action menu) are handled by our gestures.
        messageTextView = LongMessageTextView()
        messageTextView?.backgroundColor = .clear
        messageTextView?.isEditable = false
        messageTextView?.isSelectable = false
        messageTextView?.isScrollEnabled = true
        messageTextView?.dataDetectorTypes = []
        messageTextView?.delegate = self
        messageTextView?.showsHorizontalScrollIndicator = false
        messageTextView?.showsVerticalScrollIndicator = true
        messageTextView?.isUserInteractionEnabled = true
        messageTextView?.textContainer.lineBreakMode = .byWordWrapping
        messageTextView?.layoutManager.allowsNonContiguousLayout = false
        messageTextView?.layoutManager.usesFontLeading = true
        messageTextView?.contentInsetAdjustmentBehavior = .never
        messageTextView?.textContainerInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)

        // Tap: open a link, dismiss the menu, or dismiss the page (on blank space).
        let textViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTextViewTap(_:)))
        textViewTapGesture.delegate = self
        messageTextView?.addGestureRecognizer(textViewTapGesture)

        // Long-press: highlight the link (or target the whole message) and show the action menu.
        let textViewLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTextViewLongPress(_:)))
        textViewLongPress.minimumPressDuration = 0.3
        textViewLongPress.delegate = self
        messageTextView?.addGestureRecognizer(textViewLongPress)

        if let messageTextView = messageTextView {
            view.addSubview(messageTextView)
            messageTextView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        setupCloseButton()

        applyTheme()
    }

    /// Circular close button pinned to the bottom center, kept on top of the text view
    /// so it stays tappable even when a long link fills the entire screen.
    private func setupCloseButton() {
        let closeButton = UIButton(type: .custom)
        // Asset carries its own light/dark variants, so no template tinting is needed.
        closeButton.setImage(UIImage(named: "long_message_close"), for: .normal)
        closeButton.layer.cornerRadius = 24
        // cornerRadius rounds the background fill; keep clipping off so the drop shadow can render.
        closeButton.clipsToBounds = false
        closeButton.layer.shadowColor = UIColor.black.cgColor
        closeButton.layer.shadowOpacity = 0.4
        closeButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        closeButton.layer.shadowRadius = 3.5
        closeButton.addTarget(self, action: #selector(handleCloseButtonTap), for: .touchUpInside)

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-14)
            make.width.height.equalTo(48)
        }

        self.closeButton = closeButton
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

            self.view.layoutIfNeeded()
            self.updateContentInset()
            let topInset = self.messageTextView?.contentInset.top ?? 0
            self.messageTextView?.contentOffset = CGPoint(x: 0, y: -topInset)
        }
    }

    private func updateContentInset() {
        guard let textView = messageTextView else { return }
        let viewHeight = view.bounds.height
        guard viewHeight > 0 else { return }

        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.safeAreaInsets.bottom
        let contentHeight = textView.sizeThatFits(CGSize(
            width: textView.bounds.width,
            height: .greatestFiniteMagnitude
        )).height
        let visibleHeight = viewHeight - safeTop - safeBottom

        let newInset: UIEdgeInsets
        if contentHeight <= visibleHeight {
            let topInset = (viewHeight - contentHeight) / 2
            newInset = UIEdgeInsets(top: topInset, left: 0, bottom: viewHeight - topInset - contentHeight, right: 0)
        } else {
            newInset = UIEdgeInsets(top: safeTop, left: 0, bottom: safeBottom + 40, right: 0)
        }

        if textView.contentInset != newInset {
            textView.contentInset = newInset
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

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        applyAutoLinks(to: attributedString)
        return attributedString
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

        // Auto-detect plain URLs (replaces the system dataDetectorTypes, which only works when
        // the text view is selectable — and selection is off here).
        applyAutoLinks(to: attributedString)

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

    /// Detect plain URLs and attach `.link` + link styling. We carry the `.link` attribute purely
    /// for our own hit-testing (`linkRange(at:)`) — the system never interacts with it because the
    /// text view is non-selectable.
    private func applyAutoLinks(to attributedString: NSMutableAttributedString) {
        let nsText = attributedString.string as NSString
        guard nsText.length > 0,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return
        }
        detector.enumerateMatches(in: attributedString.string, options: [], range: NSRange(location: 0, length: nsText.length)) { match, _, _ in
            guard let match = match, let url = match.url, match.range.length > 0 else { return }
            attributedString.addAttribute(.link, value: url, range: match.range)
            attributedString.addAttribute(.foregroundColor, value: Theme.tinfoColor, range: match.range)
            attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
        }
    }

    public override func applyTheme() {
        super.applyTheme()

        view.backgroundColor = Theme.bg1Color

        // Solid surface from design token; the close icon brings its own light/dark variants.
        closeButton?.backgroundColor = Theme.bg3Color

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

    @objc private func handleCloseButtonTap() {
        // Close menu first if it is open, otherwise dismiss the whole page.
        if actionMenuController != nil {
            dismissMenuAndCancelSelection()
            return
        }
        dismiss(animated: true)
    }

    /// Tap: close an open menu, open a tapped link, or dismiss the page on blank space.
    @objc private func handleTextViewTap(_ gesture: UITapGestureRecognizer) {
        // Swallow the tap that ends a long-press, so the menu stays up after the finger lifts.
        if isHandlingLongPress { return }

        if actionMenuController != nil {
            dismissMenuAndCancelSelection()
            return
        }

        // Strict hit test: only act when the tap lands on a glyph, so taps in the blank margins
        // of a screen-filling link still dismiss the page.
        let location = gesture.location(in: messageTextView)
        if let range = linkRange(at: location, strict: true), let url = linkURL(forRange: range) {
            // 过滤掉 @all 的点击
            let mentionsAll = "\(Self.kVisitingCardScheme)://\(MENTIONS_ALL)"
            guard !url.absoluteString.contains(mentionsAll) else { return }
            _ = AppLinkManager.handle(url: url, fromExternal: false, sourceVC: self)
            return
        }

        // Blank tap: a tap that only stops momentum scrolling should not also dismiss.
        if messageTextView?.isDecelerating == true || messageTextView?.isDragging == true {
            return
        }
        dismiss(animated: true)
    }

    /// Long-press: highlight a link (or target the whole message) and show the action menu
    /// anchored at the press point.
    @objc private func handleTextViewLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .ended, .cancelled, .failed:
            // Clear after the current touch sequence so the lift of THIS long-press is swallowed
            // by handleTextViewTap, while a later separate tap still dismisses the menu.
            DispatchQueue.main.async { [weak self] in
                self?.isHandlingLongPress = false
            }
            return
        case .began:
            break
        default:
            return
        }

        guard let messageTextView = messageTextView else { return }
        isHandlingLongPress = true

        let touchInView = gesture.location(in: view)
        let touchInTextView = gesture.location(in: messageTextView)
        linkMenuAnchorRect = CGRect(x: touchInView.x, y: touchInView.y, width: 1, height: 1)

        // Lenient (nearest-character) hit test: a long press on the large preview font often
        // lands slightly off the glyph or in the inter-line gap.
        if let range = linkRange(at: touchInTextView, strict: false),
           case let linkText = (messageTextView.text as NSString).substring(with: range),
           !linkText.isEmpty {
            // Link mode: act on this link, highlight it. Drop any stale body-text selection
            // left over from a previous long-press so the two highlights never coexist.
            tearDownBodyTextSelection()
            activeLinkText = linkText
            highlightLink(range: range)
        } else if isPointOnGlyph(touchInTextView) {
            // Body-text mode: select the word under the press; the user can drag the handles
            // to extend the selection. The menu then acts on the selected substring.
            beginBodyTextSelection(at: touchInView)
        } else {
            // Blank area (margins, gaps, past the end of the text): nothing to select, so don't
            // show the menu.
            return
        }

        presentActionMenu()
    }

    /// Whether `location` (in the text view's coordinate space) lands on an actual glyph rather
    /// than blank area. Mirrors the strict hit test used by `linkRange(at:strict:)`.
    private func isPointOnGlyph(_ location: CGPoint) -> Bool {
        guard let messageTextView = messageTextView,
              messageTextView.textStorage.length > 0 else { return false }

        let textContainer = messageTextView.textContainer
        let layoutManager = messageTextView.layoutManager

        var locationInTextContainer = location
        locationInTextContainer.x -= messageTextView.textContainerInset.left
        locationInTextContainer.y -= messageTextView.textContainerInset.top

        let glyphIndex = layoutManager.glyphIndex(for: locationInTextContainer, in: textContainer)
        let glyphRect = layoutManager
            .boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
            .insetBy(dx: -2, dy: -6) // small tolerance so presses between wrapped lines still count
        return glyphRect.contains(locationInTextContainer)
    }

    /// Start a body-text selection at `touchInView` (in `view` coordinates) using the same
    /// selection component as chat bubbles. The menu follows the selection knobs.
    private func beginBodyTextSelection(at touchInView: CGPoint) {
        guard let messageTextView = messageTextView else { return }
        activeLinkText = nil
        // Body-text selection drives the menu position via its knobs, not a fixed anchor.
        linkMenuAnchorRect = nil
        // Drop any stale link highlight left over from a previous long-press.
        clearLinkHighlight()

        // Rebuild a fresh selection view each time.
        tearDownBodyTextSelection()

        let selectionView = DTTextSelectionView(textView: messageTextView)
        selectionView.delegate = self
        // The text view scrolls, so selection rects must be shifted by its contentOffset.
        selectionView.compensatesForContentOffset = true
        // messageTextView is a direct child of view, so its frame is already in view coordinates.
        selectionView.frame = messageTextView.frame
        // Keep below the close button so it stays tappable even over a full-screen selection.
        if let closeButton = closeButton {
            view.insertSubview(selectionView, belowSubview: closeButton)
        } else {
            view.addSubview(selectionView)
        }
        textSelectionView = selectionView

        selectionView.selectWord(at: view.convert(touchInView, to: selectionView), animated: true)
    }

    /// Tear down the body-text selection overlay, if any.
    private func tearDownBodyTextSelection() {
        isAdjustingSelection = false
        textSelectionView?.dismissSelection()
        textSelectionView?.removeFromSuperview()
        textSelectionView = nil
    }

    /// Paint a translucent highlight over `range` directly on the text storage (no system selection).
    private func highlightLink(range: NSRange) {
        guard let textStorage = messageTextView?.textStorage,
              range.location + range.length <= textStorage.length else { return }
        textStorage.addAttribute(.backgroundColor, value: Theme.primaryColor.withAlphaComponent(0.25), range: range)
        highlightedLinkRange = range
    }

    /// Remove the link highlight painted by `highlightLink`.
    private func clearLinkHighlight() {
        guard let range = highlightedLinkRange else { return }
        highlightedLinkRange = nil
        guard let textStorage = messageTextView?.textStorage,
              range.location + range.length <= textStorage.length else { return }
        textStorage.removeAttribute(.backgroundColor, range: range)
    }

    // MARK: - Menu Management

    /// 显示操作菜单
    private func presentActionMenu() {
        guard let messageTextView = messageTextView else { return }
        let actions = createMenuActions()

        let menuVC = ConversationActionMenuController(
            actions: actions,
            emojiAction: nil,
            sourceView: messageTextView,
            sourceViewController: self,
            textSelectionView: textSelectionView
        )

        menuVC.dismissHandler = { [weak self] in
            self?.cancelTextSelection()
            self?.actionMenuController = nil
        }

        // Only a full body-text selection counts as "select all"; a link is always partial.
        menuVC.isSelectedAll = (activeLinkText == nil) && isSelectionWholeText

        if textSelectionView == nil {
            // Link mode: no selection knobs, so anchor the menu at the touch point.
            let menuPosition = calculateMenuPosition()
            let anchorRect = linkMenuAnchorRect ?? messageTextView.frame
            menuVC.setInitialMenuPosition(
                top: menuPosition.top,
                left: menuPosition.left,
                arrowDirection: menuPosition.arrowDirection,
                sourceRect: anchorRect
            )
        } else {
            // Body-text mode: leave initialMenuPosition unset so the menu follows the selection
            // knobs. This page has no nav/input bar, so hand the menu the full-screen visible
            // range; otherwise a last-line knob is judged off-screen and the menu jumps to top.
            let safeArea = view.safeAreaInsets
            menuVC.visibleRangeOverride = (
                top: safeArea.top,
                bottom: UIScreen.main.bounds.height - safeArea.bottom
            )
        }

        menuVC.modalPresentationStyle = .overFullScreen
        menuVC.modalTransitionStyle = .crossDissolve
        // Present without animation: the highlight is already painted, and a cross-dissolve would
        // blend the un-highlighted and highlighted frames into a washed-out gray flash.
        present(menuVC, animated: false)

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

        // Select All — only in body-text mode (a link selection is always partial) and only when
        // the selection doesn't already cover the whole message. Tapping it expands the selection
        // to the full text and refreshes the menu, which drops this item. Mirrors the chat bubble
        // selection menu.
        if activeLinkText == nil, textSelectionView != nil, !isSelectionWholeText {
            actions.append(MenuAction(
                image: #imageLiteral(resourceName: "ic_select_all"),
                title: Localized("MESSAGE_ACTION_SELECT_ALL", comment: ""),
                subtitle: nil,
                dismissBeforePerformAction: false,
                block: { [weak self] _ in
                    guard let self, let menuVC = self.actionMenuController else { return }
                    self.textSelectionView?.selectAll(animated: true)
                    menuVC.update(actions: self.createMenuActions(), emojiAction: nil)
                    menuVC.isSelectedAll = true
                }
            ))
        }

        return actions
    }

    /// 关闭菜单并取消文本选择
    private func dismissMenuAndCancelSelection() {
        actionMenuController?.dismiss(animated: true) { [weak self] in
            self?.actionMenuController = nil
        }
        cancelTextSelection()
    }

    // MARK: - Menu Actions

    private func copySelectedText() {
        let selectedText = actionTargetText
        guard !selectedText.isEmpty else { return }
        DTSecurePasteboard.setString(selectedText)
        DTToastHelper.show(withInfo: Localized("MESSAGE_ACTION_COPY_TEXT", comment: ""))
        if let message = viewItem?.interaction as? TSMessage, let thread = viewItem?.thread {
            CopyNoticeDispatcher.sendNotice(for: message, in: thread)
        }
    }

    private func forwardSelectedText() {
        let selectedText = actionTargetText
        guard !selectedText.isEmpty else { return }
        let isLink = activeLinkText != nil
        // Only a full body-text selection forwards the original message (with source); a link or
        // a partial selection forwards as plain text. A link additionally suppresses the trace.
        isForwardingLink = isLink
        isForwardingFullText = !isLink && isSelectionWholeText
        forwardText(selectedText)
    }

    private func translateSelectedText() {
        let selectedText = actionTargetText
        guard !selectedText.isEmpty else { return }

        // 获取目标翻译语言（从 app 设置中获取）
        let targetLanguage = getTargetTranslateLanguage()
        translateText(selectedText, to: targetLanguage)
    }

    // MARK: - Menu Position Calculation

    /// 计算菜单位置信息
    private func calculateMenuPosition() -> (top: CGFloat, left: CGFloat, arrowDirection: ConversationActionMenuController.ArrowDirection) {
        guard let rectInView = linkMenuAnchorRect else {
            // 兜底：如果无法获取锚点区域，使用屏幕中央位置
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

    // MARK: - Selection State

    /// Drop the current menu target state and tear down both highlight mechanisms.
    private func cancelTextSelection() {
        activeLinkText = nil
        linkMenuAnchorRect = nil
        clearLinkHighlight()
        tearDownBodyTextSelection()
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
}

// MARK: - UITextViewDelegate

extension LongMessageViewController: UITextViewDelegate {

    // MARK: - Scroll View Delegate (滚动处理)

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Dragging a selection knob auto-scrolls the text view; don't treat that as a
        // user scroll that dismisses the menu mid-adjustment.
        guard !isAdjustingSelection else { return }
        // Any scroll dismisses the menu and clears the highlight.
        guard actionMenuController != nil else { return }
        actionMenuController?.dismiss(animated: false)
        actionMenuController = nil
        cancelTextSelection()
    }
}

// MARK: - DTTextSelectionViewDelegate

extension LongMessageViewController: DTTextSelectionViewDelegate {

    func selectionViewDidBeginSelect(_ selectionView: DTTextSelectionView) {
        // Knob drag started: hide the menu while the user adjusts the selection.
        isAdjustingSelection = true
        actionMenuController?.hideMenu(animation: false)
    }

    func selectionViewDidChangeSelectedRange(_ selectionView: DTTextSelectionView) {}

    func selectionViewDidEndSelect(_ selectionView: DTTextSelectionView) {
        isAdjustingSelection = false
        guard actionMenuController != nil else { return }
        // An empty selection collapses the menu; otherwise re-show it so it follows the knobs.
        guard let range = selectionView.getSelection(), range.length > 0 else {
            dismissMenuAndCancelSelection()
            return
        }
        // Rebuild so the Select All item appears/disappears as the drag moves between a partial and
        // a whole-text selection, then refresh the position to follow the knobs.
        actionMenuController?.update(actions: createMenuActions(), emojiAction: nil)
        actionMenuController?.isSelectedAll = isSelectionWholeText
        actionMenuController?.showMenu(animation: true)
    }

    func selectionViewDidSingleTap(_ selectionView: DTTextSelectionView) {
        isAdjustingSelection = false
        dismissMenuAndCancelSelection()
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

        // A link fragment isn't relaying someone's message content, so it leaves no trace.
        // Capture both flags up front so they can't be cleared by the async reset below.
        let suppressTrace = isForwardingLink
        let isFullText = isForwardingFullText

        DispatchQueue.global().async {
            targetThreads.forEach { targetThread in
                // 判断是否需要带消息来源
                if isFullText, let viewItem = self.viewItem {
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

            // Send the forward-trace notice only AFTER the forwarded message(s) are sent. Firing it
            // concurrently (as it did before) let the notice and the forwarded message grab the same
            // millisecond timestamp; since both are local-authored, their author_device_timestamp
            // uniqueIds then collide on the UNIQUE uniqueId column and collapse onto a single DB row,
            // making one of them vanish from its conversation. Sequencing guarantees the notice gets
            // a strictly later timestamp, matching the normal-forward path. See issue #531.
            if !suppressTrace {
                DispatchQueue.main.async {
                    self.sendForwardNotice()
                }
            }

            // 清除转发文本和标记
            DispatchQueue.main.async {
                self.forwardingText = nil
                self.isForwardingFullText = false
                self.isForwardingLink = false
            }
        }

        self.dismiss(animated: true) {
            DTToastHelper.toast(withText: Localized("MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", comment: "Sent"), durationTime: 1.5)
        }
    }

    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String {
        return self.forwardingText ?? ""
    }

    private func sendForwardNotice() {
        guard let message = viewItem?.interaction as? TSMessage,
              let thread = viewItem?.thread else { return }

        // Gate: trace only when leak-risk rules pass. "from" uses the bubble sender; a single
        // forwarded message gates on its original content author.
        let displayAuthorIds = ForwardNoticeBuilder.sourceAuthorIds(for: [message])
        let triggerAuthorIds = ForwardNoticeBuilder.triggerAuthorIds(for: [message])
        guard DTNoticeTraceEvaluator.shouldLeaveTrace(
            sourceThread: thread,
            targetThreads: self.targetThreads,
            contentAuthorIds: triggerAuthorIds
        ) else { return }
        let fromAuthorIds = DTNoticeTraceEvaluator.orderForDisplay(displayAuthorIds)

        Task {
            do {
                try await ForwardNoticeDispatcher.sendNotice(
                    sourceConversation: thread,
                    scene: .single,
                    sourceAuthorIds: fromAuthorIds,
                    messageCount: 1,
                    messageSender: SSKEnvironment.shared.messageSenderRef
                )
            } catch {
                Logger.error("[ForwardNotice] long message forward notice failed: \(error)")
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension LongMessageViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许手势同时识别
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 点击关闭按钮时，交给按钮自身处理，避免误触发关闭/取消选择手势
        if let closeButton = closeButton,
           closeButton.bounds.contains(touch.location(in: closeButton)) {
            return false
        }
        return true
    }

    /// Returns the range of the link (URL, mention, or forward source) hit at the given
    /// location, or nil if none is hit.
    /// - Parameter strict: when true, the point must fall inside a glyph's bounding rect.
    ///   Taps use this so that taps in blank areas still dismiss the page (a single long
    ///   link would otherwise mark the whole screen as a link). Long-press uses `false` to
    ///   snap to the nearest character, tolerating a finger that lands slightly off the
    ///   glyph or in the inter-line gap of the large preview font.
    private func linkRange(at location: CGPoint, strict: Bool) -> NSRange? {
        guard let messageTextView = messageTextView else { return nil }

        let textContainer = messageTextView.textContainer
        let layoutManager = messageTextView.layoutManager
        let textStorage = messageTextView.textStorage

        guard textStorage.length > 0 else { return nil }

        var locationInTextContainer = location
        locationInTextContainer.x -= messageTextView.textContainerInset.left
        locationInTextContainer.y -= messageTextView.textContainerInset.top

        if strict {
            // characterIndex(for:) returns the nearest char even on blank areas, so a single
            // long link would mark the whole screen as "link" and block tap-to-dismiss.
            // Verify the tap is actually inside the glyph rect first.
            let glyphIndex = layoutManager.glyphIndex(for: locationInTextContainer, in: textContainer)
            let glyphRect = layoutManager
                .boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
                .insetBy(dx: -2, dy: -6) // expand a bit so links stay tappable between wrapped lines
            guard glyphRect.contains(locationInTextContainer) else { return nil }
        }

        let characterIndex = layoutManager.characterIndex(
            for: locationInTextContainer,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard characterIndex < textStorage.length else { return nil }

        // Check whether the character carries a link attribute, returning its full range
        var effectiveRange = NSRange(location: 0, length: 0)
        guard textStorage.attribute(.link, at: characterIndex, effectiveRange: &effectiveRange) != nil else {
            return nil
        }
        return effectiveRange
    }

    /// Resolve the URL stored on the `.link` attribute at `range`. Auto-detected URLs store a
    /// `URL`; mentions / forward sources store a scheme string (e.g. `personinfocard://uid`).
    private func linkURL(forRange range: NSRange) -> URL? {
        guard let textStorage = messageTextView?.textStorage,
              range.location < textStorage.length else { return nil }
        let value = textStorage.attribute(.link, at: range.location, effectiveRange: nil)
        if let url = value as? URL { return url }
        if let string = value as? String { return URL(string: string) }
        return nil
    }
}
