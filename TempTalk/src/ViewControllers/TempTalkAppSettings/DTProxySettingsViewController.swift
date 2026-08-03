//
//  DTProxySettingsViewController.swift
//  TempTalk
//
//  Self-hosted proxy settings page. Lets the user paste a `ytp://config?...` proxy address,
//  toggle the proxy on/off, and see a single main status. Address and the on/off
//  switch are two independent states: "Save address" only persists the address and
//  triggers a probe; the switch is a separate action that activates immediately. Unsaved edits
//  are drafts — never auto-saved, never probed until Save.
//
//  Laid out as a grouped UITableView so the page matches the rest of the app settings
//  (DTSecurityAndPrivacyViewController): rounded cards on `bgpageSecondaryColor`, gray footer
//  text between groups. The controls are VC-owned and hosted inside static cells (see
//  DTProxySettingsViewController+Table), so all state/probe logic stays imperative and testable.
//

import Foundation
import TTServiceKit

// Subclasses SettingBaseViewController (a thin shim, no lifecycle of its own) to inherit the
// settings-page nav bar theming (OWSNavigationChildController → bgpageSecondaryColor).
@objc class DTProxySettingsViewController: SettingBaseViewController, UIGestureRecognizerDelegate {

    /// Official proxy help page ("Learn more").
    static let learnMoreURL = "https://quicall.app/proxy-help.html"

    /// Footer / description gray, matching DTSettingPlanTextCell on the other settings pages.
    private var footerTextColor: UIColor {
        Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x848E9C)
    }

    // MARK: Probe state (two orthogonal stages, rendered as one main status)

    enum Stage1 { case none, checking, available, timeout, cannotConnect, pinMismatch }
    enum Stage2 { case none, checking, ok, failed }
    enum MainStatus { case none, checking, connected, businessFailed, available, unavailable, verifyFailed }

    var stage1: Stage1 = .none
    var stage2: Stage2 = .none

    /// The persisted address (plain `ytp://` link). The switch lives in ProxyManager, not here.
    var savedAddress = ""
    var isSaving = false

    /// Bumped on every checkConnectivity() so stale stage-1/stage-2 callbacks are ignored.
    var checkGeneration = 0

    var saveButtonBottomConstraint: NSLayoutConstraint?

    // MARK: Table

    let tableView = UITableView(frame: .zero, style: .plain)

    /// The static rows, top to bottom. Spacers separate groups the way blank cells do elsewhere.
    enum Row: Equatable { case useProxy, useProxyFooter, protectCall, protectFooter, address, spacer }
    let rows: [Row] = [.useProxy, .useProxyFooter, .spacer,
                       .protectCall, .protectFooter, .spacer,
                       .address]

    // MARK: Subviews (VC-owned, hosted inside the static cells)

    lazy var useProxyTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_dynamicTypeBody
        label.text = Localized("PROXY_USE_PROXY")
        return label
    }()

    // Description + an inline "Learn more" link at the end. A non-editable text view
    // is used (not a label) so only the "Learn more" run is tappable; colors are set in applyTheme.
    lazy var useProxyDescTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        return textView
    }()

    lazy var useProxySwitch: UISwitch = {
        let view = UISwitch()
        view.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        return view
    }()

    // Protect-IP-in-calls row: only operable when Use proxy is on; gates whether calls go through the proxy.
    lazy var protectCallTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_dynamicTypeBody
        label.numberOfLines = 0
        label.text = Localized("PROXY_PROTECT_CALL_TITLE")
        return label
    }()

    lazy var protectCallDescLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_regularFont(withSize: 12)
        label.numberOfLines = 0
        label.text = Localized("PROXY_PROTECT_CALL_DESC")
        return label
    }()

    lazy var protectCallSwitch: UISwitch = {
        let view = UISwitch()
        view.addTarget(self, action: #selector(protectCallSwitchChanged), for: .valueChanged)
        return view
    }()

    lazy var addressTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_regularFont(withSize: 12)
        label.text = Localized("PROXY_ADDRESS_LABEL")
        return label
    }()

    lazy var addressTextView: UITextView = {
        let view = UITextView()
        view.font = .ows_dynamicTypeBody
        view.isScrollEnabled = false
        view.delegate = self
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        return view
    }()

    lazy var addressPlaceholderLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_dynamicTypeBody
        label.text = Localized("PROXY_ADDRESS_HINT")
        return label
    }()

    lazy var noTurnWarningLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_regularFont(withSize: 12)
        label.numberOfLines = 0
        label.text = Localized("PROXY_NO_TURN_WARNING")
        return label
    }()

    lazy var statusRow: ProxyStatusRowView = {
        let row = ProxyStatusRowView()
        row.onRecheck = { [weak self] in
            guard let self else { return }
            guard !self.isCallActive else {
                DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
                return
            }
            self.checkConnectivity()
        }
        return row
    }()

    lazy var saveButton: UIButton = {
        let button = UIButton()
        button.setTitle(Localized("PROXY_SAVE"), for: .normal)
        button.setTitleColor(.ows_white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        return button
    }()

    // Static cells, built once (see +Table). Returned directly from cellForRowAt (no reuse).
    lazy var useProxyCell = makeUseProxyCell()
    lazy var useProxyFooterCell = makeUseProxyFooterCell()
    lazy var protectCallCell = makeProtectCallCell()
    lazy var protectFooterCell = makeProtectFooterCell()
    lazy var addressCell = makeAddressCell()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized("PROXY_SETTINGS_TITLE")
        buildTable()
        setupKeyboardHandling()
        observeCallEnd()
        reloadFromManager()
        applyTheme()
        updateInteractionEnabled()
        // Auto-probe on entry only when the proxy is on and there are no unsaved edits.
        if ProxyManager.shared.isEnabled, !hasUnsavedChanges {
            checkConnectivity()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The login screen hides the nav bar; ensure it's visible when reached from there.
        navigationController?.setNavigationBarHidden(false, animated: animated)
        updateInteractionEnabled()
    }

    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        tableView.backgroundColor = Theme.bgpageSecondaryColor
        useProxyTitleLabel.textColor = Theme.tprimaryColor
        protectCallTitleLabel.textColor = Theme.tprimaryColor
        protectCallDescLabel.textColor = footerTextColor
        updateDescText()
        addressTitleLabel.textColor = footerTextColor
        addressTextView.textColor = Theme.tprimaryColor
        addressTextView.backgroundColor = Theme.bg1Color
        addressTextView.layer.borderColor = Theme.lineColor.cgColor
        addressPlaceholderLabel.textColor = Theme.tsecondaryColor
        noTurnWarningLabel.textColor = Theme.errorColor
        saveButton.setTitleColor(.ows_white, for: .normal)
        saveButton.setTitleColor(Theme.tdisableColor, for: .disabled)
        statusRow.applyTheme()
        applyCardTheme()
        tableView.reloadData()
        renderUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: State helpers

    private func reloadFromManager() {
        savedAddress = ProxyManager.shared.savedShareLink ?? ""
        addressTextView.text = savedAddress
        useProxySwitch.isOn = ProxyManager.shared.isEnabledByUser
        refreshProtectCallRow()
    }

    var addressText: String {
        addressTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var hasUnsavedChanges: Bool {
        addressText != savedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSavedValidConfig: Bool {
        ProxyConfig.parse(savedAddress) != nil
    }

    /// A call locks the page read-only: no toggling, editing, saving or rechecking.
    var isCallActive: Bool {
        DTMeetingManager.shared.hasMeeting
    }

    /// Call-restriction tip is derived from the CURRENT input's local parse, no probe needed.
    /// Only relevant when in-call IP protection is actually on — the tip tells the user to turn that
    /// switch off, which is confusing/wrong when it's already off (calls aren't blocked then anyway,
    /// since blocking is gated on `protectCallIPEnabled` in `DTMeetingManager+Call.proxyCallBlockReason`).
    var showNoTurnWarning: Bool {
        guard ProxyManager.shared.isEnabledByUser, protectCallSwitch.isOn else { return false }
        return ProxyConfig.parse(addressText)?.turnEnabled() == false
    }

    // MARK: Actions

    @objc private func switchChanged() {
        guard !isCallActive else {
            useProxySwitch.setOn(ProxyManager.shared.isEnabledByUser, animated: false)
            DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
            return
        }
        if useProxySwitch.isOn {
            // Turning on requires a saved, valid address with no pending edits.
            guard !hasUnsavedChanges, hasSavedValidConfig else {
                DTToastHelper.toast(withText: Localized("PROXY_SAVE_FIRST"), durationTime: 2)
                useProxySwitch.setOn(false, animated: true)
                return
            }
            // setEnabled applies the config off the main thread; probe once the tunnel is up (stage 2
            // routes through the loopback tunnel, so probing before it is ready would falsely fail).
            ProxyManager.shared.setEnabled(true) { [weak self] in
                self?.checkConnectivity()
            }
            refreshProtectCallRow()
            renderUI()
        } else {
            // Turning off disables immediately and keeps the address.
            ProxyManager.shared.setEnabled(false)
            refreshProtectCallRow()
            checkGeneration += 1   // cancel any in-flight probe
            stage1 = .none
            stage2 = .none
            renderUI()
        }
    }

    @objc private func protectCallSwitchChanged() {
        // During a call the proxy routing is locked, exactly like Use proxy: revert + toast.
        guard !isCallActive else {
            refreshProtectCallRow()
            DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
            return
        }
        // Only reachable while the switch is enabled (Use proxy on); persist the user's choice.
        ProxyManager.shared.protectCallIPEnabled = protectCallSwitch.isOn
    }

    @objc func protectCallRowTapped() {
        // During a call the row is locked; show the same in-call message as Use proxy.
        guard !isCallActive else {
            DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
            return
        }
        // Disabled state (Use proxy off): tapping the row hints to enable Use proxy first.
        guard !ProxyManager.shared.isEnabledByUser else { return }
        DTToastHelper.toast(withText: Localized("PROXY_PROTECT_NEED_PROXY"), durationTime: 2)
    }

    /// Sync the protect-in-calls switch with persisted state + Use-proxy gating. Disabled only when
    /// Use proxy is off (greyed, isUserInteractionEnabled=false so taps reach the row hint). During a
    /// call the switch stays enabled and protectCallSwitchChanged intercepts (revert + toast).
    func refreshProtectCallRow() {
        let proxyOn = ProxyManager.shared.isEnabledByUser
        protectCallSwitch.setOn(proxyOn && ProxyManager.shared.protectCallIPEnabled, animated: false)
        protectCallSwitch.isEnabled = proxyOn
        protectCallSwitch.isUserInteractionEnabled = proxyOn
    }

    @objc private func saveTapped() {
        guard !isSaving else { return }
        guard !isCallActive else {
            DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
            return
        }
        view.endEditing(true)   // dismiss the keyboard as part of saving — one tap, not two
        let addr = addressText

        if addr.isEmpty {
            if savedAddress.isEmpty {
                DTToastHelper.toast(withText: Localized("PROXY_ENTER_ADDRESS"), durationTime: 2)
            } else {
                // Clearing a saved address deletes it and turns the proxy off.
                ProxyManager.shared.clear()
                checkGeneration += 1
                stage1 = .none
                stage2 = .none
                reloadFromManager()
                renderUI()
            }
            return
        }

        guard let env = ProxyLinkCodec.inspect(addr) else {
            // A newer-version but well-formed link gets its own message.
            let key = ProxyLinkCodec.isUnsupportedVersion(addr) ? "PROXY_UNSUPPORTED_VERSION" : "PROXY_INVALID_ADDRESS"
            DTToastHelper.toast(withText: Localized(key), durationTime: 2)
            return
        }
        switch env.mode {
        case .plain:
            if ProxyConfig.parse(addr) != nil {
                saveAddress(addr)
            } else {
                DTToastHelper.toast(withText: Localized("PROXY_INVALID_ADDRESS"), durationTime: 2)
            }
        case .encrypted:
            promptPassphrase(for: addr)
        }
    }

    /// Save the ADDRESS only — never touches the on/off switch. Probes afterwards.
    private func saveAddress(_ addr: String) {
        // save applies the config off the main thread; probe once the tunnel is up (stage 2 routes
        // through the loopback tunnel, so probing before it is ready would falsely fail).
        ProxyManager.shared.save(shareLink: addr, enabled: ProxyManager.shared.isEnabledByUser) { [weak self] in
            self?.checkConnectivity()
        }
        savedAddress = ProxyManager.shared.savedShareLink ?? ""
        DTToastHelper.toast(withText: Localized("PROXY_SAVED"), durationTime: 2)
        renderUI()
    }

    /// Build the description with an inline, tappable "Learn more" link at the end.
    /// Called from applyTheme so the colors track the current theme.
    private func updateDescText() {
        let desc = Localized("PROXY_USE_PROXY_DESC_DETAIL")
        let learn = Localized("PROXY_LEARN_MORE")
        let full = "\(desc) \(learn)"
        let attributed = NSMutableAttributedString(string: full, attributes: [
            .font: UIFont.ows_regularFont(withSize: 12),
            .foregroundColor: footerTextColor
        ])
        let learnRange = (full as NSString).range(of: learn, options: .backwards)
        attributed.addAttribute(.link, value: Self.learnMoreURL, range: learnRange)
        useProxyDescTextView.attributedText = attributed
        useProxyDescTextView.linkTextAttributes = [.foregroundColor: Theme.primaryColor]
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL,
                  in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }

    private func promptPassphrase(for link: String) {
        let alert = UIAlertController(title: Localized("PROXY_PASSPHRASE_TITLE"),
                                      message: Localized("PROXY_PASSPHRASE_DESC"),
                                      preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = Localized("PROXY_PASSPHRASE_HINT")
            tf.isSecureTextEntry = true
        }
        let confirm = UIAlertAction(title: Localized("PROXY_PASSPHRASE_CONFIRM"), style: .default) { [weak self, weak alert] _ in
            guard let self, let pass = alert?.textFields?.first?.text, !pass.isEmpty else { return }
            self.decrypt(link: link, passphrase: pass)
        }
        alert.addAction(UIAlertAction(title: Localized("PROXY_PASSPHRASE_CANCEL"), style: .cancel))
        alert.addAction(confirm)
        present(alert, animated: true)
    }

    /// PBKDF2 (600k iterations) is slow — decrypt off the main thread. On success persist the
    /// decrypted PLAIN link so restarts don't re-prompt. The link was already inspected as
    /// encrypted, so a nil result here means a wrong passphrase.
    private func decrypt(link: String, passphrase: String) {
        isSaving = true
        renderUI()
        DispatchQueue.global().async { [weak self] in
            let cfg = ProxyConfig.parse(link, passphrase: passphrase)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                // A call may have started during passphrase entry / PBKDF2; the page is read-only
                // then, so abort the save instead of mutating state silently.
                guard !self.isCallActive else {
                    DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
                    self.renderUI()
                    return
                }
                guard let cfg else {
                    DTToastHelper.toast(withText: Localized("PROXY_PASSPHRASE_WRONG"), durationTime: 2)
                    self.renderUI()
                    return
                }
                // Save the decrypted plain link as the address (switch unchanged), then probe.
                let plainLink = cfg.toShareLink()
                guard !plainLink.isEmpty else {
                    DTToastHelper.toast(withText: Localized("PROXY_PASSPHRASE_WRONG"), durationTime: 2)
                    self.renderUI()
                    return
                }
                self.saveAddress(plainLink)
            }
        }
    }

    // MARK: Render

    func renderUI() {
        addressPlaceholderLabel.isHidden = !(addressTextView.text?.isEmpty ?? true)
        noTurnWarningLabel.isHidden = !showNoTurnWarning
        renderStatusRow()

        // Save highlights only when the address differs from what's saved, and not while busy or
        // in a call. The switch never affects it.
        let busy = isSaving || stage1 == .checking || stage2 == .checking
        let enabled = hasUnsavedChanges && !busy && !isCallActive
        saveButton.isEnabled = enabled
        saveButton.backgroundColor = enabled ? Theme.primaryColor : Theme.bgdisableColor

        // Row heights change when the warning/status collapse; re-measure without reloading.
        // Only once on screen — before that, reloadData in applyTheme handles initial sizing.
        if tableView.window != nil {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }

    private func renderStatusRow() {
        switch mainStatus() {
        case .none:
            statusRow.configure(.checking, text: nil, showRecheck: false)
        case .checking:
            statusRow.configure(.checking, text: "", showRecheck: false)
        case .connected:
            statusRow.configure(.green, text: Localized("PROXY_E2E_OK"), showRecheck: true)
        case .businessFailed:
            statusRow.configure(.red, text: Localized("PROXY_E2E_FAILED"), showRecheck: true)
        case .available:
            statusRow.configure(.green, text: Localized("PROXY_STATUS_AVAILABLE"), showRecheck: true)
        case .unavailable:
            statusRow.configure(.red, text: Localized("PROXY_STATUS_UNAVAILABLE"), showRecheck: true)
        case .verifyFailed:
            statusRow.configure(.red, text: Localized("PROXY_VERIFY_FAILED"), showRecheck: true)
        }
    }

    // MARK: Call lock

    private func observeCallEnd() {
        NotificationCenter.default.addObserver(self, selector: #selector(callDidEnd),
                                               name: .notifyCallEnd, object: nil)
    }

    @objc private func callDidEnd() {
        updateInteractionEnabled()
    }

    private func updateInteractionEnabled() {
        // Controls stay interactive during a call; each action intercepts and shows a toast
        // so the user gets feedback rather than silently-disabled controls.
        renderUI()
    }
}
