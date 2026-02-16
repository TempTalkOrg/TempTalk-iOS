//
//  QuickMessagePanel.swift
//  Difft
//
//  Created by Henry on 2025/4/9.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

class LeftAlignedFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }

        var leftMargin: CGFloat = sectionInset.left
        var maxY: CGFloat = -1.0

        for attr in attributes {
            // 对于 footer，让它占满整个宽度，不受 sectionInset 影响
            if attr.representedElementKind == UICollectionView.elementKindSectionFooter {
                var frame = attr.frame
                frame.origin.x = 0
                frame.size.width = collectionViewContentSize.width
                attr.frame = frame
                continue
            }

            if attr.frame.origin.y >= maxY {
                leftMargin = sectionInset.left
            }

            attr.frame.origin.x = leftMargin
            leftMargin += attr.frame.width + minimumInteritemSpacing
            maxY = max(maxY, attr.frame.maxY)
        }
        return attributes
    }
}

// Emoji Cell - 无背景，大字号
class EmojiCell: UICollectionViewCell {
    static let identifier = "EmojiCell"
    let label = UILabel()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .systemFont(ofSize: 28)
        label.textColor = UIColor.color(rgbHex: 0xEAECEF)
        label.backgroundColor = .clear // 无背景色
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        label.addGestureRecognizer(tap)

        contentView.addSubview(label)
    }

    @objc func tapAction() {
        onTap?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Text Cell - 有背景，小字号
class TextCell: UICollectionViewCell {
    static let identifier = "TextCell"
    let label = UILabel()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor.color(rgbHex: 0xEAECEF)
        label.backgroundColor = UIColor.color(rgbHex: 0x2B3139)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        label.addGestureRecognizer(tap)

        contentView.addSubview(label)
    }

    @objc func tapAction() {
        onTap?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DividerView: UICollectionReusableView {
    static let identifier = "DividerView"

    private let lineView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        lineView.backgroundColor = UIColor.color(rgbHex: 0x2B3139)
        lineView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lineView)

        // 使用 Auto Layout 确保分割线从左到右完全占满
        NSLayoutConstraint.activate([
            lineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lineView.topAnchor.constraint(equalTo: topAnchor),
            lineView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class QuickMessagePanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collectionView: UICollectionView
    var emojiPresets: [String] = []
    var textPresets: [String] = []
    var onMessageTap: ((String) -> Void)?

    override init(frame: CGRect) {
        let layout = LeftAlignedFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        // 设置面板背景色
        backgroundColor = Theme.dark.bg2Color
        layer.cornerRadius = 8
        layer.masksToBounds = true

        collectionView.layer.cornerRadius = 8
        collectionView.layer.masksToBounds = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.identifier)
        collectionView.register(TextCell.self, forCellWithReuseIdentifier: TextCell.identifier)
        collectionView.register(DividerView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: DividerView.identifier)
        collectionView.backgroundColor = .clear // CollectionView 背景透明，使用面板背景色
        addSubview(collectionView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
    }

    func reload(emojiPresets: [String], textPresets: [String]) {
        self.emojiPresets = emojiPresets
        self.textPresets = textPresets
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2 // Section 0: emoji, Section 1: text
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return emojiPresets.count
        } else {
            return textPresets.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            // Emoji Cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.identifier, for: indexPath) as! EmojiCell
            let message = emojiPresets[indexPath.item]
            cell.label.text = message
            cell.onTap = { [weak self] in
                self?.onMessageTap?(message)
            }
            return cell
        } else {
            // Text Cell
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCell.identifier, for: indexPath) as! TextCell
            let message = textPresets[indexPath.item]
            cell.label.text = message
            cell.onTap = { [weak self] in
                self?.onMessageTap?(message)
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionFooter && indexPath.section == 0 {
            let divider = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: DividerView.identifier, for: indexPath) as! DividerView
            return divider
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if section == 0 {
            return CGSize(width: collectionView.bounds.width, height: 16) // 分割线高度
        }
        return .zero
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            // Emoji Cell - 固定大小，确保一行显示
            let text = emojiPresets[indexPath.item]
            let size = (text as NSString).boundingRect(
                with: CGSize(width: 999, height: 999),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: UIFont.systemFont(ofSize: 28)],
                context: nil).size
            // 给 emoji 留一些额外空间
            return CGSize(width: size.width + 8, height: 40)
        } else {
            // Text Cell - 动态宽度
            let text = textPresets[indexPath.item]
            let maxWidth: CGFloat = collectionView.bounds.width - 16
            let size = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: 999),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: UIFont.systemFont(ofSize: 14)],
                context: nil).size
            return CGSize(width: min(size.width + 20, maxWidth), height: 36)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct QuickMessagePanelUIKitWrapper: UIViewRepresentable {

    var emojiPresets: [String]
    var textPresets: [String]
    var onTap: (String) -> Void

    func makeUIView(context: Context) -> QuickMessagePanel {
        let panel = QuickMessagePanel()
        panel.onMessageTap = onTap
        return panel
    }

    func updateUIView(_ uiView: QuickMessagePanel, context: Context) {
        uiView.reload(emojiPresets: emojiPresets, textPresets: textPresets)
    }
}
