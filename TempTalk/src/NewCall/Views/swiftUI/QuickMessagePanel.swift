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

class DanmakuCell: UICollectionViewCell {
    static let identifier = "DanmakuCell"
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

class QuickMessagePanel: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collectionView: UICollectionView
    var messages: [String] = []
    var onMessageTap: ((String) -> Void)?

    override init(frame: CGRect) {
        let layout = LeftAlignedFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        collectionView.layer.cornerRadius = 8
        collectionView.layer.masksToBounds = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(DanmakuCell.self, forCellWithReuseIdentifier: DanmakuCell.identifier)
        collectionView.backgroundColor = UIColor.color(rgbHex: 0x1E2329)
        addSubview(collectionView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.frame = bounds
    }

    func reload(messages: [String]) {
        self.messages = messages
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        messages.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DanmakuCell.identifier, for: indexPath) as! DanmakuCell
        let message = messages[indexPath.item]
        cell.label.text = message
        cell.onTap = { [weak self] in
            self?.onMessageTap?(message)
        }
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text = messages[indexPath.item]
        let maxWidth: CGFloat = collectionView.bounds.width - 16
        let size = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: 999),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 14)],
            context: nil).size
        return CGSize(width: min(size.width + 20, maxWidth), height: 36)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct QuickMessagePanelUIKitWrapper: UIViewRepresentable {
    
    var messages: [String]
    var onTap: (String) -> Void

    func makeUIView(context: Context) -> QuickMessagePanel {
        let view = QuickMessagePanel()
        view.onMessageTap = onTap
        return view
    }

    func updateUIView(_ uiView: QuickMessagePanel, context: Context) {
        uiView.reload(messages: messages)
    }
}
