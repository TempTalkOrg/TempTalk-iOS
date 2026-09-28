//
//  CallMediaPermissionCoordinator.swift
//  TempTalk
//
//  Copyright © 2026 Difft. All rights reserved.
//

import AVFoundation
import LiveKit
import TTMessaging
import TTServiceKit
import UIKit

/// Local media a LiveKit call can capture on this device. Screen share is absent on
/// purpose: iOS only subscribes to remote shares, it never publishes one.
enum CallMedia: String {
    case microphone
    case camera

    var avMediaType: AVMediaType {
        switch self {
        case .microphone: return .audio
        case .camera: return .video
        }
    }
}

/// What a user-initiated enable tap should do next.
enum CallMediaPermissionUserAction: Equatable {
    /// Already authorized — go straight to LiveKit.
    case enable
    /// Never asked — let iOS show its own authorization prompt.
    case requestSystemPrompt
    /// Hard denial — only our own "Cancel / Settings" dialog can help.
    case showSettingsGuide
}

/// Authorization state of a `CallMedia`, named explicitly so logs stay readable.
enum CallMediaPermissionStatus: String {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unknown

    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        @unknown default: self = .unknown
        }
    }

    /// Automatic paths (initial setup, CallKit, reconnect, prewarm) may only start capture
    /// when access is already granted: they must never surface a prompt.
    var allowsAutomaticEnable: Bool {
        self == .authorized
    }

    /// Only a hard denial earns the persistent badge, so a user who was never asked
    /// doesn't see a failure state.
    var showsPermissionBadge: Bool {
        self == .denied || self == .restricted
    }

    var userAction: CallMediaPermissionUserAction {
        switch self {
        case .authorized: return .enable
        case .notDetermined: return .requestSystemPrompt
        case .denied, .restricted, .unknown: return .showSettingsGuide
        }
    }
}

/// Single owner of microphone / camera permission handling for LiveKit calls.
///
/// Permission is device-global, so this is a shared object rather than per-room state:
/// the toolbar badge, the automatic gates and the audio-session prewarm all read the
/// same answer. Rules it enforces (see the cross-platform media permission spec):
///
/// - Joining a call never prompts and never toasts.
/// - Automatic enable paths check only and fail safely.
/// - Only a user-initiated tap may prompt or show the settings guide.
/// - One dialog per tap: the system prompt and our settings guide never overlap.
/// - Returning from Settings refreshes state but never enables capture on its own.
///
/// State is only ever mutated on the main actor (the mutating members are annotated);
/// `currentStatus(of:)` stays available to gates running off it.
final class CallMediaPermissionCoordinator: ObservableObject {
    static let shared = CallMediaPermissionCoordinator()

    private let logTag: String = "[newcall][mediaPermission]"

    @Published private(set) var microphoneStatus: CallMediaPermissionStatus
    @Published private(set) var cameraStatus: CallMediaPermissionStatus

    /// The microphone is the only medium with a persistent badge: the camera is optional,
    /// so its failures stay dialog-only instead of reading as a hard fault.
    var showsMicrophonePermissionBadge: Bool {
        microphoneStatus.showsPermissionBadge
    }

    private var isRequestingSystemPrompt = false
    private var isShowingSettingsGuide = false
    /// Weak: when the call window goes away it takes the dialog with it.
    private weak var presentedSettingsGuide: UIAlertController?

    /// Dedup state for the settings guide. The flag alone would be enough for the normal
    /// dismiss paths, but a dialog torn down with its window never runs them — a dropped
    /// controller reference clears the flag so later taps aren't swallowed forever.
    private var isPresentingSettingsGuide: Bool {
        if isShowingSettingsGuide, presentedSettingsGuide == nil {
            isShowingSettingsGuide = false
        }
        return isShowingSettingsGuide
    }

    private init() {
        microphoneStatus = Self.currentStatus(of: .microphone)
        cameraStatus = Self.currentStatus(of: .camera)
    }

    // MARK: - Status

    /// Thread-safe status read for gates that run off the main actor.
    static func currentStatus(of media: CallMedia) -> CallMediaPermissionStatus {
        CallMediaPermissionStatus(AVCaptureDevice.authorizationStatus(for: media.avMediaType))
    }

    func status(of media: CallMedia) -> CallMediaPermissionStatus {
        switch media {
        case .microphone: return microphoneStatus
        case .camera: return cameraStatus
        }
    }

    /// Re-reads both statuses, e.g. when the app returns to the foreground: a grant made in
    /// Settings clears the badge, without turning anything on.
    @MainActor
    func refreshStatuses(reason: String) {
        let microphone = Self.currentStatus(of: .microphone)
        let camera = Self.currentStatus(of: .camera)
        guard microphone != microphoneStatus || camera != cameraStatus else { return }

        Logger.info("\(logTag) status changed (\(reason)): microphone \(microphoneStatus.rawValue) -> \(microphone.rawValue), camera \(cameraStatus.rawValue) -> \(camera.rawValue)")
        microphoneStatus = microphone
        cameraStatus = camera
    }

    // MARK: - Gates

    /// Gate for automatic enable paths: check only, never prompt, fail safely.
    @MainActor
    func allowsAutomaticEnable(of media: CallMedia) -> Bool {
        refreshStatuses(reason: "automatic enable gate for \(media.rawValue)")
        let status = status(of: media)
        if !status.allowsAutomaticEnable {
            Logger.info("\(logTag) automatic \(media.rawValue) enable blocked: status=\(status.rawValue)")
        }
        return status.allowsAutomaticEnable
    }

    /// Gate for user-initiated enable taps: may request the system prompt or show the
    /// settings guide. Returns whether capture may start now.
    @MainActor
    func requestAccessForUserAction(of media: CallMedia) async -> Bool {
        refreshStatuses(reason: "user action gate for \(media.rawValue)")
        let status = status(of: media)
        Logger.info("\(logTag) user requested \(media.rawValue): status=\(status.rawValue)")

        switch status.userAction {
        case .enable:
            return true

        case .requestSystemPrompt:
            guard !isRequestingSystemPrompt, !isPresentingSettingsGuide else {
                Logger.info("\(logTag) skip \(media.rawValue) system prompt: another permission dialog is showing")
                return false
            }
            isRequestingSystemPrompt = true
            let granted = await LiveKitSDK.ensureDeviceAccess(for: [media.avMediaType])
            isRequestingSystemPrompt = false
            refreshStatuses(reason: "system prompt result for \(media.rawValue)")
            Logger.info("\(logTag) \(media.rawValue) system prompt granted=\(granted)")
            return granted

        case .showSettingsGuide:
            presentSettingsGuide(for: media)
            return false
        }
    }

    /// LiveKit refused capture at runtime — the status changed under us, or the device
    /// failed in a way that surfaces as an access denial. Only a user-initiated attempt
    /// gets a dialog; automatic paths just refresh state and log.
    @MainActor
    func handleDeviceAccessDenied(of media: CallMedia, userInitiated: Bool) {
        Logger.warn("\(logTag) LiveKit reported \(media.rawValue) access denied, userInitiated=\(userInitiated)")
        refreshStatuses(reason: "device access denied for \(media.rawValue)")
        guard userInitiated else { return }
        presentSettingsGuide(for: media)
    }

    // MARK: - Settings guide

    @MainActor
    private func presentSettingsGuide(for media: CallMedia) {
        guard !isPresentingSettingsGuide, !isRequestingSystemPrompt else {
            Logger.info("\(logTag) skip \(media.rawValue) settings guide: another permission dialog is showing")
            return
        }
        guard let presenter = presentingViewController() else {
            Logger.warn("\(logTag) skip \(media.rawValue) settings guide: no view controller to present on")
            return
        }

        let alert = DTAlertController(
            title: media.permissionGuideTitle,
            message: media.permissionGuideMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: CommonStrings.cancelButton(), style: .cancel) { [weak self] _ in
            self?.isShowingSettingsGuide = false
        })
        alert.addAction(UIAlertAction(title: CommonStrings.openSettingsButton(), style: .default) { [weak self] _ in
            self?.isShowingSettingsGuide = false
            // Only opens Settings: coming back refreshes state, it never starts capture.
            UIApplication.shared.openSystemSettings()
        })

        isShowingSettingsGuide = true
        presentedSettingsGuide = alert
        Logger.info("\(logTag) present \(media.rawValue) settings guide")
        presenter.present(alert, animated: true)
    }

    /// Call UI lives in its own window above the main one, so `frontmostViewController`
    /// (which walks the main window) is only the fallback for a hidden call window.
    @MainActor
    private func presentingViewController() -> UIViewController? {
        let callWindow = OWSWindowManager.shared().callViewWindow
        if !callWindow.isHidden {
            return callWindow.findTopViewController()
        }
        return CurrentAppContext().frontmostViewController()
    }
}

private extension CallMedia {
    var permissionGuideTitle: String {
        switch self {
        case .microphone: return Localized("CALL_MEDIA_PERMISSION_MICROPHONE_TITLE")
        case .camera: return Localized("CALL_MEDIA_PERMISSION_CAMERA_TITLE")
        }
    }

    /// Both messages name the app twice ("<app> can't access … go to Settings > <app>"),
    /// hence the repeated positional specifier in the strings file.
    var permissionGuideMessage: String {
        let key: String
        switch self {
        case .microphone: key = "CALL_MEDIA_PERMISSION_MICROPHONE_MESSAGE"
        case .camera: key = "CALL_MEDIA_PERMISSION_CAMERA_MESSAGE"
        }
        return Localized(key, arguments: TSConstants.appDisplayName)
    }
}
