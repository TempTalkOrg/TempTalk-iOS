//
//  DTGifFavoriteActionPopover.swift
//  TempTalk
//
//  Small floating action shown on long-pressing a GIF in the picker grid (Figma 16746-18086 /
//  16881-19489): a single "Add to Favorite" / "Remove form Favorite" pill anchored at the cell.
//  Tapping the pill toggles; tapping anywhere else dismisses. Colors follow the theme
//  (bgpopup / tprimary) so it adapts to dark & light mode.
//

import UIKit
import TTServiceKit
import TTMessaging
import PureLayout

final class DTGifFavoriteActionPopover: UIView {

    enum Mode { case add, remove }

    private let pill = UIView()
    private let iconView = UIImageView()
    private let label = UILabel()
    private var onTap: (() -> Void)?

    // MARK: - Present / dismiss

    @discardableResult
    static func present(in host: UIView,
                        anchorRect: CGRect,
                        mode: Mode,
                        onTap: @escaping () -> Void) -> DTGifFavoriteActionPopover {
        // Only one popover at a time.
        host.subviews.compactMap { $0 as? DTGifFavoriteActionPopover }.forEach { $0.removeFromSuperview() }

        let popover = DTGifFavoriteActionPopover(mode: mode)
        popover.onTap = onTap
        popover.frame = host.bounds
        popover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(popover)
        popover.positionPill(anchorRect: anchorRect, in: host.bounds)
        popover.animateIn()
        return popover
    }

    // MARK: - Init

    init(mode: Mode) {
        super.init(frame: .zero)
        backgroundColor = .clear
        setupPill(mode: mode)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupPill(mode: Mode) {
        pill.backgroundColor = Theme.bgpopupColor
        pill.layer.cornerRadius = 8
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.12
        pill.layer.shadowRadius = 12
        pill.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(pill)

        iconView.image = UIImage(named: mode == .add ? "gif_fav_star" : "gif_fav_star_off")?
            .withRenderingMode(.alwaysTemplate)
        iconView.tintColor = Theme.tprimaryColor
        iconView.contentMode = .scaleAspectFit

        label.text = Localized(mode == .add ? "MESSAGE_ACTION_ADD_TO_FAVORITE" : "GIF_FAVORITE_REMOVE")
        label.font = .systemFont(ofSize: 16)
        label.textColor = Theme.tprimaryColor

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        pill.addSubview(stack)
        iconView.autoSetDimensions(to: CGSize(square: 20))
        stack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
    }

    // MARK: - Layout

    private func positionPill(anchorRect: CGRect, in bounds: CGRect) {
        layoutIfNeeded()
        let size = pill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let margin: CGFloat = 8

        // Upper-right of the cell: pill's left edge at the cell's horizontal center,
        // top one-fifth down from the cell's top. Clamped inside the panel.
        var x = anchorRect.midX
        var y = anchorRect.minY + anchorRect.height / 5
        x = max(margin, min(x, bounds.width - margin - size.width))
        y = max(margin, min(y, bounds.height - margin - size.height))
        pill.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    // MARK: - Interaction

    @objc
    private func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        if pill.frame.contains(point) {
            let action = onTap
            dismiss { action?() }
        } else {
            dismiss(nil)
        }
    }

    private func animateIn() {
        pill.alpha = 0
        pill.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.16) {
            self.pill.alpha = 1
            self.pill.transform = .identity
        }
    }

    private func dismiss(_ completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.12, animations: {
            self.pill.alpha = 0
            self.pill.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }
}
