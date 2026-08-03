//
//  ProxyStatusRowView.swift
//  TempTalk
//
//  Single proxy status line for the proxy settings page: a leading indicator
//  (spinner while checking, or a colored dot), the one main status text in green/red, and
//  an optional "Recheck" refresh icon on the trailing side. The status area only ever shows
//  ONE main status; this view renders whichever the VC computed by priority.
//

import UIKit
import TTServiceKit

final class ProxyStatusRowView: UIView {

    enum Indicator { case checking, green, red }

    /// Invoked when the user taps the trailing recheck icon.
    var onRecheck: (() -> Void)?

    private let indicatorContainer = UIView()
    private let dot = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let textLabel = UILabel()

    /// Trailing refresh icon (a small icon, not a text button). Template image tinted
    /// with the secondary text color so it tracks light/dark.
    private lazy var recheckButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "ic_proxy_recheck"), for: .normal)
        button.accessibilityLabel = Localized("PROXY_RECHECK")
        button.addTarget(self, action: #selector(recheckTapped), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildLayout() {
        dot.autoSetDimensions(to: CGSize(square: 10))
        dot.layer.cornerRadius = 5
        spinner.hidesWhenStopped = true
        textLabel.font = .systemFont(ofSize: 15)
        textLabel.numberOfLines = 0

        indicatorContainer.autoSetDimensions(to: CGSize(square: 16))
        indicatorContainer.addSubview(dot)
        dot.autoCenterInSuperview()
        indicatorContainer.addSubview(spinner)
        spinner.autoCenterInSuperview()

        recheckButton.autoSetDimensions(to: CGSize(square: 20))

        let row = UIStackView(arrangedSubviews: [indicatorContainer, textLabel, recheckButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        indicatorContainer.setContentHuggingPriority(.required, for: .horizontal)
        recheckButton.setContentHuggingPriority(.required, for: .horizontal)
        recheckButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(row)
        row.autoPinEdgesToSuperviewEdges()
    }

    @objc private func recheckTapped() {
        onRecheck?()
    }

    /// Render the single main status. `text == nil` hides the whole row.
    func configure(_ indicator: Indicator, text: String?, showRecheck: Bool) {
        textLabel.text = text
        recheckButton.isHidden = !showRecheck

        guard let text, !text.isEmpty || indicator == .checking else {
            isHidden = true
            spinner.stopAnimating()
            return
        }
        isHidden = false

        switch indicator {
        case .checking:
            dot.isHidden = true
            spinner.startAnimating()
            textLabel.textColor = Theme.tprimaryColor
        case .green:
            spinner.stopAnimating()
            dot.isHidden = false
            dot.backgroundColor = Theme.successColor
            textLabel.textColor = Theme.successColor
        case .red:
            spinner.stopAnimating()
            dot.isHidden = false
            dot.backgroundColor = Theme.errorColor
            textLabel.textColor = Theme.errorColor
        }
    }

    func applyTheme() {
        recheckButton.tintColor = Theme.tsecondaryColor
    }
}
