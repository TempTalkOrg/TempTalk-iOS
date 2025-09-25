//
//  ConversationActionMenuSheetController.swift
//  Difft
//
//  Created by Jaymin on 2024/7/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import PanModal
import SnapKit
import TTMessaging

public final class ConversationActionMenuSheetController: OWSViewController {
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private(set) var actions: [MenuAction] = []
    private var contentHeight: CGFloat = .zero
    
    public init(actions: [MenuAction]) {
        super.init()
        self.actions = actions
        self.contentHeight = CGFloat(actions.count) * 45.0 + 12.0
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    public func present(from sourceViewController: UIViewController) {
        sourceViewController.presentPanModal(self)
    }
    
    private func setupView() {
        let actionViews = actions.map {
            let actionView = ActionView(action: $0)
            actionView.delegate = self
            return actionView
        }
        stackView.addArrangedSubviews(actionViews)
        view.addSubview(stackView)
        stackView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 12.0)
        stackView.autoPinEdge(toSuperviewEdge: .leading)
        stackView.autoPinEdge(toSuperviewEdge: .trailing)
        stackView.autoPinEdge(toSuperviewSafeArea: .bottom)
        stackView.autoSetDimension(.height, toSize: CGFloat(actions.count) * 45.0)
        
        applyTheme()
    }
    
    public override func applyTheme() {
        super.applyTheme()
        stackView.subviews.forEach {
            if let subview = $0 as? ActionView {
                subview.applyTheme()
            }
        }
    }
}

extension ConversationActionMenuSheetController: ActionViewDelegate {
    fileprivate func actionView(_ actionView: ActionView, didTapWith action: MenuAction) {
        dismiss(animated: true) {
            action.block(action)
        }
    }
}

extension ConversationActionMenuSheetController: PanModalPresentable {
    public var panScrollable: UIScrollView? {
        nil
    }
    
    public var shortFormHeight: PanModalHeight {
        .contentHeight(contentHeight)
    }
    
    public var longFormHeight: PanModalHeight {
        .contentHeight(contentHeight)
    }
}

private protocol ActionViewDelegate: AnyObject {
    func actionView(_ actionView: ActionView, didTapWith action: MenuAction)
}

private class ActionView: UIView {
    
    private lazy var iconImageView: UIImageView = UIImageView()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private var action: MenuAction
    weak var delegate: ActionViewDelegate?
    
    init(action: MenuAction) {
        self.action = action
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionViewPressed))
        addGestureRecognizer(tapGesture)
        
        addSubview(iconImageView)
        iconImageView.image = action.image
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.equalTo(24)
        }
        
        addSubview(titleLabel)
        titleLabel.text = action.title
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
        }
        
        applyTheme()
    }
    
    @objc private func actionViewPressed() {
        delegate?.actionView(self, didTapWith: action)
    }
    
    func applyTheme() {
        backgroundColor = Theme.backgroundColor
        iconImageView.tintColor = Theme.tabbarTitleNormalColor
        titleLabel.textColor = Theme.primaryTextColor
        
        if action.title == Localized("MESSAGE_ACTION_RECALL", comment: "") {
            // 撤回
            iconImageView.tintColor = UIColor.color(rgbHex: 0xD9271E)
            titleLabel.textColor = UIColor.color(rgbHex: 0xD9271E)
        }
    }
}
