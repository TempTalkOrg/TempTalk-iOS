//
//  ConversationEmojiSheetViewController.swift
//  Difft
//
//  Created by Jaymin on 2024/6/18.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import PanModal
import SnapKit
import TTMessaging

class ConversationEmojiSheetViewController: OWSViewController {
    
    struct Item {
        let emoji: String
        let isSelected: Bool
    }
    
    private lazy var layout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSize(width: 48, height: 48)
        return layout
    }()
    
    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(EmojiSheetCell.self, forCellWithReuseIdentifier: EmojiSheetCell.reuseIdentifier)
        collectionView.contentInset = .init(top: 0, left: 0, bottom: bottomInset, right: 0)
        
        return collectionView
    }()
    
    private let emojiAction: MenuEmojiAction
    private let items: [Item]
    
    init(emojiAction: MenuEmojiAction) {
        self.emojiAction = emojiAction
        let emojis = emojiAction.emojis + DTReactionHelper.lessUsed()
        self.items = emojis.map {
            .init(emoji: $0, isSelected: emojiAction.selectedEmojis.contains($0))
        }
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(13)
            make.trailing.equalToSuperview().offset(-13)
            make.bottom.equalToSuperview()
        }
        applyTheme()
    }
    
    override func applyTheme() {
        view.backgroundColor = Theme.stickBackgroundColor
        collectionView.backgroundColor = Theme.stickBackgroundColor
        collectionView.reloadData()
    }
}

extension ConversationEmojiSheetViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let item = items[safe: indexPath.row] else {
            return UICollectionViewCell()
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiSheetCell.reuseIdentifier, for: indexPath)
        if let emojiCell = cell as? EmojiSheetCell {
            emojiCell.item = item
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = items[safe: indexPath.row] else {
            return
        }
        emojiAction.block(item.emoji)
        dismiss(animated: true)
    }
}

private class EmojiSheetCell: UICollectionViewCell {
    
    static let reuseIdentifier: String = "EmojiSheetCell"
    
    private lazy var emojiLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 26)
        return label
    }()
    
    private lazy var selectedView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        return view
    }()
    
    var item: ConversationEmojiSheetViewController.Item? {
        didSet {
            emojiLabel.text = item?.emoji
            refreshTheme()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        refreshTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        contentView.addSubview(selectedView)
        selectedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.addSubview(emojiLabel)
        emojiLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func refreshTheme() {
        backgroundColor = Theme.stickBackgroundColor
        contentView.backgroundColor = Theme.stickBackgroundColor
        selectedView.backgroundColor = (item?.isSelected ?? false) ? Theme.hairlineColor : .clear
    }
}

extension ConversationEmojiSheetViewController: PanModalPresentable {
    private var estimateHeight: CGFloat {
        let cols = Int(floor((UIScreen.main.bounds.size.width - 26) / 48))
        let rows = (items.count + cols - 1) / cols
        return CGFloat(rows) * 48 + 12 + bottomInset
    }
    
    private var bottomInset: CGFloat {
        let keyWindow = UIApplication.shared.windows.last { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.bottom ?? 0
    }
    
    public var panScrollable: UIScrollView? {
        nil
    }
    
    public var shortFormHeight: PanModalHeight {
        .contentHeight(estimateHeight)
    }
    
    public var longFormHeight: PanModalHeight {
        .contentHeight(estimateHeight)
    }
}
