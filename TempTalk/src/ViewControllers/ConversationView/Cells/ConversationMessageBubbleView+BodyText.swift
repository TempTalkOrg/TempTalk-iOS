//
//  ConversationMessageBubbleView+BodyText.swift
//  Signal
//
//  Created by Jaymin on 2024/4/26.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging

extension ConversationMessageBubbleView {
    
    static let confViewTag = 1000001
    
    func configureBodyTextView(renderItem: CVMessageBubbleRenderItem, textViews: inout [TextViewEntity]) {
        guard let bodyTextItem = renderItem.bodyTextRenderItem, let bodyTextConfig = bodyTextItem.bodyTextConfig else {
            return
        }
        
        bodyTextView.isHidden = false
        bodyTextConfig.applyForRendering(textView: bodyTextView)
        textViews.append(.init(view: bodyTextView, height: bodyTextItem.viewSize.height))
        
        switch bodyTextItem.bodyTextStyle {
        case .normal:
            if bodyTextItem.hasTapForMore {
                let readMoreButton = createReadMoreButton(
                    textColor: Theme.tinfoColor,
                    renderItem: renderItem
                )
                textViews.append(.init(view: readMoreButton, height: renderItem.caption1FontHeight))
            }
            bodyTextView.maskEnable = false
            
        case .combinedForwarding:
            let textColor = bodyTextItem.bodyTextColor.withAlphaComponent(0.5)
            let lineColor = bodyTextItem.bodyTextColor.withAlphaComponent(bodyTextItem.isIncomingMessage ? 0.1 : 0.2)
            let chatHistoryLabel = createChatHistoryLabel(textColor: textColor, lineColor: lineColor)
            textViews.append(.init(view: chatHistoryLabel, height: renderItem.caption1FontHeight + 2))
            bodyTextView.maskEnable = false
            
        case .card:
            bodyTextView.frame = .init(x: 0, y: 0, width: bodyTextItem.viewSize.width, height: bodyTextItem.viewSize.height)
            bodyTextView.maskEnable = false
            
        case .confidential:
            bodyTextView.maskEnable = true
            bodyTextView.linkTextAttributes = [:]
            if let attributedText = bodyTextView.attributedText {
                let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
                mutableAttributedText.removeAttribute(.link, range: NSRange(location: 0, length: mutableAttributedText.length))
                mutableAttributedText.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: mutableAttributedText.length))
                bodyTextView.attributedText = mutableAttributedText
            }
        default:
            bodyTextView.maskEnable = false
        }
        
        bodyTextView.setNeedsDisplay()
    }
    
    private func createReadMoreButton(textColor: UIColor, renderItem: CVMessageBubbleRenderItem) -> UIView {
        // 创建一个容器视图，用于左对齐按钮
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // 创建按钮
        let readMoreButton = UIButton(type: .system)
        readMoreButton.setTitle(Localized("CONVERSATION_CELL_OVERSIZE_TEXT_TAP_FOR_MORE"), for: .normal)
        readMoreButton.titleLabel?.font = UIFont.systemFont(ofSize: 16.0)
        readMoreButton.setTitleColor(textColor, for: .normal)
        readMoreButton.contentHorizontalAlignment = .leading
        
        // 添加点击事件
        readMoreButton.addTarget(self, action: #selector(readMoreButtonTapped), for: .touchUpInside)
        
        // 将按钮添加到容器视图
        containerView.addSubview(readMoreButton)
        readMoreButton.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.bottom.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
        
        return containerView
    }
    
    @objc private func readMoreButtonTapped(_ sender: UIButton) {
        guard let renderItem = self.renderItem else {
            Logger.info("[bubble] read more renderItem is nil]")
            return
        }
        let viewItem = renderItem.viewItem
        delegate?.messageBubbleView?(self, didTapReadMoreMessageWith: viewItem)
    }
    
    private func createChatHistoryLabel(textColor: UIColor, lineColor: UIColor) -> UIView {
        let chatHistoryLabel = UILabel()
        chatHistoryLabel.text = Localized("FORWARD_MESSAGE_CHAT_HISTORY")
        chatHistoryLabel.font = .ows_dynamicTypeCaption1
        chatHistoryLabel.textColor = textColor
        
        let line = UIView()
        line.backgroundColor = lineColor
        chatHistoryLabel.addSubview(line)
        line.snp.makeConstraints { make in
            make.height.equalTo(1.0 / UIScreen.main.scale)
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        return chatHistoryLabel
    }
}

// MARK: Text Selection

extension ConversationMessageBubbleView: DTTextSelectionViewDelegate {
    
    func textViewSelectAll() {
        if let bodyTextSelectionView {
            bodyTextSelectionView.removeFromSuperview()
            self.bodyTextSelectionView = nil
        }
        let selectionView = DTTextSelectionView(textView: bodyTextView)
        selectionView.delegate = self
        selectionView.frame = bodyTextView.convert(bodyTextView.bounds, toViewOrWindow: self)
        addSubview(selectionView)
    
        selectionView.selectAll(animated: false)
        bodyTextSelectionView = selectionView
    }
    
    func textViewCancelSelect() {
        bodyTextSelectionView?.dismissSelection()
        bodyTextSelectionView?.removeFromSuperview()
        bodyTextSelectionView = nil
    }
    
    func selectionViewDidBeginSelect(_ selectionView: DTTextSelectionView) {
        textDelegate?.bubbleViewDidBeginSelectText(self)
    }
    
    func selectionViewDidChangeSelectedRange(_ selectionView: DTTextSelectionView) {}
    
    func selectionViewDidEndSelect(_ selectionView: DTTextSelectionView) {
        guard let viewItem = renderItem?.viewItem else { return }
        textDelegate?.bubbleView(
            self,
            didEndSelectTextWith: bodyTextView,
            selectionView: selectionView,
            viewItem: viewItem
        )
    }
    
    func selectionViewDidSingleTap(_ selectionView: DTTextSelectionView) {
        textDelegate?.bubbleViewDidSingleTapSelectionView(self)
    }
}
