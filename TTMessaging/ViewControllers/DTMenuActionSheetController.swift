//
//  DTMenuActionSheetController.swift
//  TTMessaging
//
//  Created by Jaymin on 2024/3/6.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import PanModal

public final class DTMenuActionSheetController: OWSViewController {
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private(set) var actions: [Action] = []
    private var contentHeight: CGFloat = .zero
    
    public init(actions: [Action]) {
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
            let actionView = DTMenuActionView(action: $0)
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
            if let subview = $0 as? DTMenuActionView {
                subview.applyTheme()
            }
        }
    }
}

extension DTMenuActionSheetController: DTMenuActionViewDelegate {
    func actionView(_ actionView: DTMenuActionView, didPressedWith action: Action) {
        dismiss(animated: true) {
            if let handler = action.handler {
                handler()
            }
        }
    }
}

extension DTMenuActionSheetController: PanModalPresentable {
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

extension DTMenuActionSheetController {
    public struct Action {
        var icon: UIImage?
        var title: String
        var subtitle: String?
        var handler: (() -> Void)?
        
        public init(icon: UIImage? = nil, title: String, subtitle: String? = nil, handler: (() -> Void)? = nil) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.handler = handler
        }
    }
}

protocol DTMenuActionViewDelegate: AnyObject {
    func actionView(_ actionView: DTMenuActionView, didPressedWith action: DTMenuActionSheetController.Action)
}

class DTMenuActionView: UIView {
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        return stackView
    }()
    
    private lazy var iconImageView: UIImageView = UIImageView()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()
    
    var action: DTMenuActionSheetController.Action
    weak var delegate: DTMenuActionViewDelegate?
    
    init(action: DTMenuActionSheetController.Action) {
        self.action = action
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        stackView.addArrangedSubviews([
            iconImageView,
            titleLabel,
            subtitleLabel
        ])
        addSubview(stackView)
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 10)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 10)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        iconImageView.autoSetDimensions(to: CGSize(width: 20, height: 20))
        
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionViewPressed))
        addGestureRecognizer(tapGesture)
        
        if let icon = action.icon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            iconImageView.image = nil
            iconImageView.isHidden = true
        }
        titleLabel.text = action.title
        subtitleLabel.text = action.subtitle
        
        applyTheme()
    }
    
    @objc private func actionViewPressed() {
        self.delegate?.actionView(self, didPressedWith: action)
    }
    
    func applyTheme() {
        backgroundColor = Theme.backgroundColor
        iconImageView.tintColor = Theme.primaryTextColor
        titleLabel.textColor = Theme.primaryTextColor
        subtitleLabel.textColor = Theme.ternaryTextColor
    }
}
