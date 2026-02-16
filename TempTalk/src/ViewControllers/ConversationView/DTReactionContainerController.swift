//
//  DTReactionContainerController.swift
//  Wea
//
//  Created by Ethan on 2022/5/24.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import JXCategoryView

@objcMembers
class DTReactionContainerController: OWSViewController {

    var targetMessage: TSMessage?
    var emojiTitles: [String]?
    var selectedEmoji: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Emoji Reaction"//emojiTitleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelItemAction))

        guard let targetMessage = targetMessage else { return }
        self.databaseStorage.read { [self] transaction in
            if let tmpTitles = DTReactionHelper.emojiTitlesForMessage(targetMessage, transaction: transaction) {
                self.emojiTitles = tmpTitles
                self.layoutSubviews()
                self.emojiTitleView.titles = tmpTitles

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.emojiTitleView.selectItem(at: self.defaultSelectedIndex())
                }

            }
        }

    }

    private func defaultSelectedIndex() -> Int {
        guard let emojiTitles = emojiTitles, let selectedEmoji = selectedEmoji else {
            return 0
        }
        var existEmojis = [String]()
        for title in emojiTitles {
            guard let emoji = title.components(separatedBy: ["("]).first else {
                continue
            }
            existEmojis.append(emoji)
        }
        if existEmojis.contains(selectedEmoji) {
            return existEmojis.firstIndex(of: selectedEmoji) ?? 0
        }
        return 0
    }
    
    override func applyTheme() {
        super.applyTheme()
        
        emojiTitleView.titleColor = Theme.tprimaryColor
        emojiTitleView.backgroundColor = Theme.bg1Color
        separator.backgroundColor = Theme.lineColor
        separator1.backgroundColor = Theme.lineColor
        emojiTitleView.reloadData()
        containerView.listCellBackgroundColor = Theme.bg1Color
    }
    
    func layoutSubviews() {
        
        view.addSubview(emojiTitleView)
        view.addSubview(containerView)
        view.addSubview(separator)
        view.addSubview(separator1)
        emojiTitleView.listContainer = containerView
        
        applyTheme()
        
        emojiTitleView.autoPinEdge(toSuperviewSafeArea: .top)
        emojiTitleView.autoPinEdge(toSuperviewEdge: .leading)
        emojiTitleView.autoPinEdge(toSuperviewEdge: .trailing)
        
        separator.autoPinEdge(toSuperviewEdge: .top)
        separator.autoPinEdge(toSuperviewEdge: .leading)
        separator.autoPinEdge(toSuperviewEdge: .trailing)
        
        containerView.autoPinEdge(.top, to: .bottom, of: emojiTitleView)
//        containerView.autoPinEdge(toSuperviewEdge: .top)
        containerView.autoPinEdge(toSuperviewSafeArea: .bottom)
        containerView.autoPinEdge(toSuperviewEdge: .leading)
        containerView.autoPinEdge(toSuperviewEdge: .trailing)
        
        separator1.autoPinEdge(.top, to: .top, of: containerView)
        separator1.autoPinEdge(toSuperviewEdge: .leading)
        separator1.autoPinEdge(toSuperviewEdge: .trailing)
    }
    
    lazy var emojiTitleView: JXCategoryTitleView = {
        let titleView = JXCategoryTitleView()
        titleView.delegate = self
        titleView.titleDataSource = self
        titleView.titleFont = .systemFont(ofSize: 16)
        titleView.titleSelectedFont = .systemFont(ofSize: 16).ows_semibold()
        titleView.titleSelectedColor = .ows_materialBlue
        titleView.isTitleColorGradientEnabled = true
        titleView.isContentScrollViewClickTransitionAnimationEnabled = false
        
        let lineView = JXCategoryIndicatorLineView()
        lineView.lineStyle = .lengthenOffset
        lineView.indicatorHeight = 3
        lineView.indicatorColor = .ows_materialBlue
        titleView.indicators = [lineView]
        
        titleView.autoSetDimension(.height, toSize: 42)
//        titleView.autoSetDimensions(to: CGSize(width: UIScreen.main.bounds.width - 69, height: 44))
                
        return titleView
    }()

    lazy var separator: UIView = {
        let separator = UIView()
        separator.autoSetDimension(.height, toSize: 1 / UIScreen.main.scale)
        return separator
    }()
    
    lazy var separator1: UIView = {
        let separator = UIView()
        separator.autoSetDimension(.height, toSize: 1 / UIScreen.main.scale)
        return separator
    }()
    
    lazy var containerView: JXCategoryListContainerView = {
        let containerView = JXCategoryListContainerView(type: .collectionView, delegate: self)!
        containerView.listCellBackgroundColor = Theme.bg1Color
        
        return containerView
    }()

    func cancelItemAction() {
        dismiss(animated: true)
    }
        
}

extension DTReactionContainerController: JXCategoryViewDelegate, JXCategoryTitleViewDataSource {
    
}

extension DTReactionContainerController: JXCategoryListContainerViewDelegate {
    func number(ofListsInlistContainerView listContainerView: JXCategoryListContainerView!) -> Int {
        self.emojiTitles?.count ?? 0
    }

    func listContainerView(_ listContainerView: JXCategoryListContainerView!, initListFor index: Int) -> JXCategoryListContentViewDelegate! {

        guard let emojiTitles = emojiTitles, index < emojiTitles.count,
              let currentEmoji = emojiTitles[index].components(separatedBy: ["("]).first else {
            return nil
        }
        guard let targetMessage = targetMessage,
              let reactionSources = DTReactionHelper.reactionSources(for: targetMessage, emoji: currentEmoji) else {
            return nil
        }

        let listVC = DTReactionListController()
        listVC.shouldUseTheme = true
        listVC.reactionSources = reactionSources

        return listVC
    }

}
