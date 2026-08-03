//
//  DTProxySettingsViewController+State.swift
//  TempTalk
//
//  Connectivity state machine for the proxy settings page. Stage 1 (outer hop)
//  always runs from a saved valid address; stage 2 (end-to-end through the tunnel) runs only
//  while the proxy is on. The two stages collapse into the single main status the UI shows.
//

import Foundation
import TTServiceKit

extension DTProxySettingsViewController {

    /// Probe the saved address. Stage 1 needs only a parsed config (independent of the tunnel);
    /// stage 2 needs the tunnel running, so it runs only when the proxy is enabled.
    func checkConnectivity() {
        checkGeneration += 1
        let gen = checkGeneration

        guard let config = ProxyConfig.parse(savedAddress) else {
            stage1 = .none
            stage2 = .none
            renderUI()
            return
        }

        stage1 = .checking
        stage2 = .none
        renderUI()

        ProxyConnectivityChecker.check(config) { [weak self] result in
            guard let self, gen == self.checkGeneration else { return }
            switch result {
            case .ok:
                self.stage1 = .available
                guard ProxyManager.shared.isEnabled else {
                    // Switch off: show "proxy available" only, no business status, no entry update.
                    self.stage2 = .none
                    self.renderUI()
                    return
                }
                self.stage2 = .checking
                self.renderUI()
                ProxyE2eProbe.probe { [weak self] e2e in
                    guard let self, gen == self.checkGeneration else { return }
                    self.stage2 = (e2e == .ok) ? .ok : .failed
                    self.recordProbeIfEnabled()
                    self.renderUI()
                }
            case .pinMismatch:
                self.stage1 = .pinMismatch
                self.stage2 = .none
                self.recordProbeIfEnabled()
                self.renderUI()
            case .timeout:
                self.stage1 = .timeout
                self.stage2 = .none
                self.recordProbeIfEnabled()
                self.renderUI()
            case .cannotConnect:
                self.stage1 = .cannotConnect
                self.stage2 = .none
                self.recordProbeIfEnabled()
                self.renderUI()
            }
        }
    }

    /// Persist the latest verdict for the entry row, only while the proxy is on.
    func recordProbeIfEnabled() {
        guard ProxyManager.shared.isEnabled else { return }
        switch mainStatus() {
        case .connected, .available:
            ProxyManager.shared.recordProbeResult(available: true)
        case .businessFailed, .unavailable, .verifyFailed:
            ProxyManager.shared.recordProbeResult(available: false)
        case .none, .checking:
            break
        }
    }

    /// Collapse the two stages into the single status shown, by priority.
    func mainStatus() -> MainStatus {
        switch stage1 {
        case .none: return .none
        case .checking: return .checking
        case .pinMismatch: return .verifyFailed
        case .timeout, .cannotConnect: return .unavailable
        case .available:
            switch stage2 {
            case .checking: return .checking
            case .ok: return .connected
            case .failed: return .businessFailed
            case .none: return .available
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension DTProxySettingsViewController: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        // No address editing during a call; show the toast instead of opening the keyboard.
        guard !isCallActive else {
            DTToastHelper.toast(withText: Localized("PROXY_CALL_IN_PROGRESS"), durationTime: 2)
            return false
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        // Editing is a draft: clear any prior probe result and recompute Save highlight. The
        // address is only persisted via the Save button — never auto-saved.
        if stage1 != .none || stage2 != .none {
            checkGeneration += 1   // ignore an in-flight probe for the now-stale address
            stage1 = .none
            stage2 = .none
        }
        renderUI()
    }
}
