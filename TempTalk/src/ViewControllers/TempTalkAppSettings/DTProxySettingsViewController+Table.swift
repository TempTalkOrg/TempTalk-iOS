//
//  DTProxySettingsViewController+Table.swift
//  TempTalk
//
//  Table layout for the proxy settings page: builds the grouped table, wraps the VC-owned
//  controls in card / footer cells, and keeps the Save button above the keyboard. Kept apart
//  from the VC so the state/probe/action logic stays in one focused file.
//

import UIKit
import TTServiceKit

extension DTProxySettingsViewController {

    // MARK: Table setup

    func buildTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 56
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }

        view.addSubview(tableView)
        view.addSubview(saveButton)

        tableView.autoPinEdge(toSuperviewSafeArea: .top)
        tableView.autoPinEdge(toSuperviewSafeArea: .leading)
        tableView.autoPinEdge(toSuperviewSafeArea: .trailing)

        saveButton.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 16)
        saveButton.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 16)
        saveButtonBottomConstraint = saveButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 24)
        saveButton.autoSetDimension(.height, toSize: 48)
        saveButton.autoPinEdge(.top, to: .bottom, of: tableView, withOffset: 8)
    }

    func applyCardTheme() {
        [useProxyCell, useProxyFooterCell, protectCallCell, protectFooterCell, addressCell]
            .compactMap { $0 as? DTProxyContainerCell }
            .forEach { $0.applyContainerTheme() }
    }

    // MARK: Cell builders (each hosts VC-owned controls; returned directly, never reused)

    func makeUseProxyCell() -> UITableViewCell {
        let stack = UIStackView(arrangedSubviews: [useProxyTitleLabel, useProxySwitch])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        useProxySwitch.setContentHuggingPriority(.required, for: .horizontal)
        useProxySwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        let cell = DTProxyContainerCell()
        cell.host(stack, style: .card)
        return cell
    }

    func makeUseProxyFooterCell() -> UITableViewCell {
        let cell = DTProxyContainerCell()
        cell.host(useProxyDescTextView, style: .footer)
        return cell
    }

    func makeProtectCallCell() -> UITableViewCell {
        let stack = UIStackView(arrangedSubviews: [protectCallTitleLabel, protectCallSwitch])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        protectCallSwitch.setContentHuggingPriority(.required, for: .horizontal)
        protectCallSwitch.setContentCompressionResistancePriority(.required, for: .horizontal)
        let cell = DTProxyContainerCell()
        cell.host(stack, style: .card)
        // Tap the row to hint when the switch is disabled (Use proxy off). The gesture skips
        // UIControls (see gestureRecognizer(_:shouldReceive:)) so the switch still toggles.
        let tap = UITapGestureRecognizer(target: self, action: #selector(protectCallRowTapped))
        tap.delegate = self
        cell.contentView.addGestureRecognizer(tap)
        return cell
    }

    func makeProtectFooterCell() -> UITableViewCell {
        let cell = DTProxyContainerCell()
        cell.host(protectCallDescLabel, style: .footer)
        return cell
    }

    func makeAddressCell() -> UITableViewCell {
        addressTextView.addSubview(addressPlaceholderLabel)
        addressPlaceholderLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        addressPlaceholderLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        addressTextView.autoSetDimension(.height, toSize: 96, relation: .greaterThanOrEqual)

        let stack = UIStackView(arrangedSubviews: [addressTitleLabel, addressTextView, noTurnWarningLabel, statusRow])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 10
        let cell = DTProxyContainerCell()
        cell.host(stack, style: .field)
        return cell
    }

    // MARK: Keyboard (keep Save button above the keyboard)

    func setupKeyboardHandling() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self   // skip taps on controls so Save fires on the first tap (not just dismiss)
        view.addGestureRecognizer(tap)
        tableView.keyboardDismissMode = .interactive

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func keyboardWillChangeFrame(_ note: Notification) {
        guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let overlap = max(0, view.bounds.maxY - view.convert(frame, from: nil).minY)
        let bottomInset = view.safeAreaInsets.bottom
        saveButtonBottomConstraint?.constant = -(24 + max(0, overlap - bottomInset))
        view.layoutIfNeeded()
        // Keep the address field visible above the shrunken table while editing.
        if addressTextView.isFirstResponder, let indexPath = addressIndexPath {
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }

    @objc func keyboardWillHide() {
        saveButtonBottomConstraint?.constant = -24
        view.layoutIfNeeded()
    }

    // Let the dismiss-keyboard / protect-hint taps fall through everywhere EXCEPT controls
    // (Save / switch / recheck), so those still fire directly instead of being spent on the tap.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIControl)
    }

    private var addressIndexPath: IndexPath? {
        guard let row = rows.firstIndex(of: .address) else { return nil }
        return IndexPath(row: row, section: 0)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension DTProxySettingsViewController: UITableViewDataSource, UITableViewDelegate {

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        rows[indexPath.row] == .spacer ? 24 : UITableView.automaticDimension
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.row] {
        case .useProxy:       return useProxyCell
        case .useProxyFooter: return useProxyFooterCell
        case .protectCall:    return protectCallCell
        case .protectFooter:  return protectFooterCell
        case .address:        return addressCell
        case .spacer:
            let cell = UITableViewCell()
            cell.selectionStyle = .none
            cell.backgroundColor = Theme.bgpageSecondaryColor
            cell.contentView.backgroundColor = Theme.bgpageSecondaryColor
            return cell
        }
    }
}

// MARK: - Card / footer container cell

/// Hosts a single content view either as a rounded card (on `bg1Color`, inset 16) or as gray
/// footer text on the page background — mirroring the grouped look of the other settings pages.
final class DTProxyContainerCell: UITableViewCell {

    // card:   rounded white surface inset 16, content padded a further 16 (switch rows).
    // footer: gray page background, content inset 32 (explanatory text between groups).
    // field:  gray page background, content inset 16 — same screen margin as a card — so the
    //         address input itself becomes the white surface aligned with the cards above.
    enum Style { case card, footer, field }

    private var style: Style = .card
    private let cardBackground = UIView()

    func host(_ content: UIView, style: Style) {
        self.style = style
        selectionStyle = .none
        content.translatesAutoresizingMaskIntoConstraints = false

        cardBackground.layer.cornerRadius = 10
        cardBackground.layer.masksToBounds = true
        contentView.addSubview(cardBackground)
        contentView.addSubview(content)

        switch style {
        case .card:
            cardBackground.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
            cardBackground.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
            cardBackground.autoPinEdge(toSuperviewEdge: .top)
            cardBackground.autoPinEdge(toSuperviewEdge: .bottom)
            content.autoPinEdge(toSuperviewEdge: .leading, withInset: 32)
            content.autoPinEdge(toSuperviewEdge: .trailing, withInset: 32)
            content.autoPinEdge(toSuperviewEdge: .top, withInset: 16)
            content.autoPinEdge(toSuperviewEdge: .bottom, withInset: 16)
        case .footer, .field:
            cardBackground.isHidden = true
            let hInset: CGFloat = style == .field ? 16 : 32
            let vInset: CGFloat = 8
            content.autoPinEdge(toSuperviewEdge: .leading, withInset: hInset)
            content.autoPinEdge(toSuperviewEdge: .trailing, withInset: hInset)
            content.autoPinEdge(toSuperviewEdge: .top, withInset: vInset)
            content.autoPinEdge(toSuperviewEdge: .bottom, withInset: vInset)
        }
        applyContainerTheme()
    }

    func applyContainerTheme() {
        backgroundColor = Theme.bgpageSecondaryColor
        contentView.backgroundColor = Theme.bgpageSecondaryColor
        cardBackground.backgroundColor = Theme.bg1Color
    }
}
