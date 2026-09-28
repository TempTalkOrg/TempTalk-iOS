//
//  CallNavigationView.swift
//  TempTalk
//
//  Created by Ethan on 25/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import UIKit
import SFSafeSymbols
import LiveKit

struct CallNavigationView: View {

    @ObservedObject var currentCall: DTLiveKitCallModel
    @Binding var cameraRotateItemHidden: Bool
    let presentation: CallStatusPresentation

    var leftItemAction: () -> Void
    var cameraRotateAction: () -> Void

    var body: some View {
        HStack {
            Spacer().frame(width: 15)
            Button(action: leftItemAction) {
                Image("ic_call_mini")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            Spacer()
            CallNavigationCenterView(
                currentCall: currentCall,
                presentation: presentation
            )
            Spacer().frame(width: 64)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(
            Color.black.opacity(currentCall.callType == .private ? 0 : 0.2)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - Center content 独立子 view
// 持有自己的 @ObservedObject，SwiftUI 保证其生命周期独立于父 view 的重建
private struct CallNavigationCenterView: View {

    @ObservedObject var currentCall: DTLiveKitCallModel
    let presentation: CallStatusPresentation
    @ObservedObject private var timerManager = TimerDataManager.shared
    @ObservedObject private var dataManager = RoomDataManager.shared
    @EnvironmentObject var roomCtx: RoomContext

    var body: some View {
        let shouldShowRoomName = currentCall.callType != .private
        // Roster is kept across reconnect (Route B), so participantCount stays accurate; no cached fallback.
        let displayCount = dataManager.participantCount

        VStack(spacing: 2) {
            if shouldShowRoomName {
                Text("\(currentCall.roomName)(\(displayCount))")
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
            }

            if presentation.showsDisconnectingStatus {
                statusText(Localized("MEETING_NAVAGATION_DISCONNECTING"))
            } else if presentation.showsCallingStatus {
                CallingEncryptionStatusView {
                    roomCtx.presentEndToEndEncryptionInfo()
                }
            } else if presentation.showsDuration,
                      let duration = timerManager.duration {
                let stringDuration = DTLiveKitCallModel.stringDuration(duration)
                HStack(spacing: 4) {
                    EncryptionInfoButton {
                        roomCtx.presentEndToEndEncryptionInfo()
                    }

                    if timerManager.isShowCountDownView {
                        CountdownView(
                            stringDuration: stringDuration,
                            timerManager: timerManager
                        )
                    } else {
                        Text(stringDuration)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .accessibilityIdentifier(DTCallAccessibilityID.callDuration)
                    }
                }
                // The lock keeps an 8pt invisible leading inset inside its 20pt tap target.
                // Balance it on the trailing side so the visible lock + timer aligns with the title.
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
    }
}

enum CallStatusPresentation: Equatable {
    case idle
    case calling
    case initialConnecting
    case connected
    case reconnecting(showsDuration: Bool)
    case connectionInterrupted(showsDuration: Bool)
    case mediaRecovering(showsDuration: Bool)
    case localNetworkPoor(showsDuration: Bool)
    case remoteNetworkPoor(showsDuration: Bool)
    case disconnecting

    static func resolve(
        isDisconnecting: Bool,
        isCalling: Bool,
        hasDuration: Bool,
        hasConnectionFailure: Bool,
        isExplicitlyReconnecting: Bool,
        isInitialConnectionPending: Bool,
        hasMediaSendIssue: Bool,
        isLocalNetworkPoor: Bool,
        hasPoorRemoteNetwork: Bool,
        usesOneToOneNetworkQualityPresentation: Bool
    ) -> Self {
        if isDisconnecting {
            return .disconnecting
        }
        // `callState` is message-driven and may briefly remain `.outgoing` after media is ready.
        // A started duration is stronger evidence that the call has left the ringing phase.
        if isCalling, !hasDuration {
            return .calling
        }
        if hasConnectionFailure {
            return .connectionInterrupted(showsDuration: hasDuration)
        }
        if isExplicitlyReconnecting {
            return .reconnecting(showsDuration: hasDuration)
        }
        // Initial Connecting is a real UI phase, not an inference from the absence of duration.
        // If the timer publication arrives slightly earlier, keep the banner and hide the timer
        // until the connection/media state itself leaves this phase.
        if isInitialConnectionPending {
            return .initialConnecting
        }
        if hasMediaSendIssue {
            return .mediaRecovering(showsDuration: hasDuration)
        }
        if isLocalNetworkPoor {
            return .localNetworkPoor(showsDuration: hasDuration)
        }
        if usesOneToOneNetworkQualityPresentation, hasPoorRemoteNetwork {
            return .remoteNetworkPoor(showsDuration: hasDuration)
        }
        if hasDuration {
            return .connected
        }
        return .idle
    }

    @MainActor
    static func resolve(
        currentCall: DTLiveKitCallModel,
        meetingManager: DTMeetingManager,
        timerManager: TimerDataManager,
        room: Room,
        roomCtx: RoomContext
    ) -> Self {
        let isDisconnecting = meetingManager.lifecycleState == .disconnecting
            || room.connectionState == .disconnecting
        let isCalling = currentCall.callType == .private
            && currentCall.isCaller
            && currentCall.callState == .outgoing
            && room.remoteParticipants.isEmpty
        let hasConnectionFailure = meetingManager.hasEverConnectedToRoom
            && room.connectionState == .disconnected
            && room.disconnectError != nil
            && room.disconnectError?.type != .cancelled
        let isExplicitlyReconnecting = roomCtx.isRoomReconnecting
            || room.connectionState == .reconnecting
            || roomCtx.mediaSendStatusPresentation == .roomRecovering
        let isInitialConnectionPending = room.connectionState == .connecting
            || (currentCall.callType == .private
                && room.connectionState == .connected
                && timerManager.duration == nil)

        return resolve(
            isDisconnecting: isDisconnecting,
            isCalling: isCalling,
            hasDuration: timerManager.duration != nil,
            hasConnectionFailure: hasConnectionFailure,
            isExplicitlyReconnecting: isExplicitlyReconnecting,
            isInitialConnectionPending: isInitialConnectionPending,
            hasMediaSendIssue: roomCtx.mediaSendStatusPresentation == .mediaRecovering,
            isLocalNetworkPoor: roomCtx.networkQualitySnapshot.isLocalPoor,
            hasPoorRemoteNetwork: !roomCtx.networkQualitySnapshot.poorRemoteParticipantKeys.isEmpty,
            usesOneToOneNetworkQualityPresentation: roomCtx.usesOneToOneNetworkQualityPresentation
        )
    }

    var showsDisconnectingStatus: Bool {
        self == .disconnecting
    }

    var showsCallingStatus: Bool {
        self == .calling
    }

    var showsDuration: Bool {
        switch self {
        case .connected:
            return true
        case let .reconnecting(showsDuration),
             let .connectionInterrupted(showsDuration),
             let .mediaRecovering(showsDuration),
             let .localNetworkPoor(showsDuration),
             let .remoteNetworkPoor(showsDuration):
            return showsDuration
        case .idle, .calling, .initialConnecting, .disconnecting:
            return false
        }
    }

    var healthStatus: CallConnectionHealthStatus? {
        switch self {
        case .initialConnecting, .reconnecting:
            return .connecting
        case .connectionInterrupted:
            return .connectionInterrupted
        case .mediaRecovering:
            return .mediaRecovering
        case .localNetworkPoor:
            return .localNetworkPoor
        case .remoteNetworkPoor:
            return .remoteNetworkPoor
        case .idle, .calling, .connected, .disconnecting:
            return nil
        }
    }

}

/// Owns every observable input used by the call-status resolver. Keeping this small reader around
/// both the navigation timer and banner ensures they advance from the same render-time snapshot,
/// while Room/RoomContext reconnect and media-health publications are observed directly.
struct CallStatusPresentationReader<Content: View>: View {
    @ObservedObject private var currentCall: DTLiveKitCallModel
    @ObservedObject private var meetingManager: DTMeetingManager
    @ObservedObject private var timerManager: TimerDataManager
    @ObservedObject private var room: Room
    @ObservedObject private var roomCtx: RoomContext

    private let content: (CallStatusPresentation) -> Content

    init(
        currentCall: DTLiveKitCallModel,
        room: Room,
        roomCtx: RoomContext,
        @ViewBuilder content: @escaping (CallStatusPresentation) -> Content
    ) {
        self.currentCall = currentCall
        meetingManager = DTMeetingManager.shared
        timerManager = TimerDataManager.shared
        self.room = room
        self.roomCtx = roomCtx
        self.content = content
    }

    var body: some View {
        let presentation = CallStatusPresentation.resolve(
            currentCall: currentCall,
            meetingManager: meetingManager,
            timerManager: timerManager,
            room: room,
            roomCtx: roomCtx
        )
        let traceState = CallNetworkQualityUITraceState(
            presentation: presentation,
            callType: String(describing: currentCall.callType),
            usesOneToOnePresentation: roomCtx.usesOneToOneNetworkQualityPresentation,
            isLocalPoor: roomCtx.networkQualitySnapshot.isLocalPoor,
            remotePoorSIDs: roomCtx.networkQualitySnapshot.poorRemoteParticipantKeys.sorted()
        )
        content(presentation)
            .onAppear {
                traceState.log(trigger: "reader_appeared")
            }
            .onChange(of: traceState) { newState in
                newState.log(trigger: "resolved_state_changed")
            }
    }
}

private struct CallNetworkQualityUITraceState: Equatable {
    let presentation: CallStatusPresentation
    let callType: String
    let usesOneToOnePresentation: Bool
    let isLocalPoor: Bool
    let remotePoorSIDs: [String]

    func log(trigger: String) {
        let banner: String
        switch presentation {
        case .localNetworkPoor:
            banner = "local-network-poor"
        case .remoteNetworkPoor:
            banner = "remote-network-poor"
        default:
            banner = "none"
        }

        let badgeSIDs = usesOneToOnePresentation ? [] : remotePoorSIDs
        let blockedBy: String
        if isLocalPoor, banner != "local-network-poor" {
            blockedBy = presentation.logName
        } else if usesOneToOnePresentation,
                  !remotePoorSIDs.isEmpty,
                  banner != "remote-network-poor" {
            blockedBy = presentation.logName
        } else if !usesOneToOnePresentation, !remotePoorSIDs.isEmpty {
            blockedBy = "none-group-uses-badges"
        } else {
            blockedBy = "none"
        }

        CallNetworkQualityLog.info(
            "event=ui_state trigger=\(trigger) callType=\(callType) "
                + "mode=\(usesOneToOnePresentation ? "one-to-one-banner" : "group-badges") "
                + "resolvedPresentation=\(presentation.logName) "
                + "localPoor=\(isLocalPoor) remotePoorSIDs=\(remotePoorSIDs) "
                + "shouldShowHealthBanner=\(presentation.healthStatus != nil) "
                + "shouldShowWeakNetworkBanner=\(banner != "none") weakNetworkBanner=\(banner) "
                + "shouldShowBadges=\(!badgeSIDs.isEmpty) badgeSIDs=\(badgeSIDs) "
                + "blockedBy=\(blockedBy)"
        )
    }
}

private extension CallStatusPresentation {
    var logName: String {
        switch self {
        case .idle:
            return "idle"
        case .calling:
            return "calling"
        case .initialConnecting:
            return "initial-connecting"
        case .connected:
            return "connected"
        case .reconnecting:
            return "reconnecting"
        case .connectionInterrupted:
            return "connection-interrupted"
        case .mediaRecovering:
            return "media-recovering"
        case .localNetworkPoor:
            return "local-network-poor"
        case .remoteNetworkPoor:
            return "remote-network-poor"
        case .disconnecting:
            return "disconnecting"
        }
    }
}

struct CallConnectionHealthBanner: View {
    /// 16pt text/icon height plus 8pt vertical padding on each side.
    static let minimumPillHeight: CGFloat = 32

    let presentation: CallStatusPresentation
    let topInset: CGFloat
    let onHeightChange: (CGFloat) -> Void

    init(
        presentation: CallStatusPresentation,
        topInset: CGFloat,
        onHeightChange: @escaping (CGFloat) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.topInset = topInset
        self.onHeightChange = onHeightChange
    }

    /// Visibility is derived directly from the shared presentation. There is no retained state,
    /// minimum display duration, or transition animation, so a recovered status disappears now.
    private var healthStatus: CallConnectionHealthStatus? {
        presentation.healthStatus
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let healthStatus {
                let contentColor = Color(Theme.dark.tprimaryColor)

                HStack(spacing: 8) {
                    if healthStatus.showsSpinner {
                        DTCircleLoadingView(
                            connectState: .connecting,
                            color: contentColor,
                            size: 14
                        )
                    } else if healthStatus.usesNetworkIcon {
                        Image("ic_call_network_poor")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 16))
                            .frame(width: 16, height: 16)
                    }

                    Text(Localized(healthStatus.localizationKey))
                        .font(.system(size: 12, weight: .regular))
                        .lineSpacing(16 - UIFont.systemFont(ofSize: 12).lineHeight)
                        .frame(minHeight: 16)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundColor(contentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(Theme.dark.bg3Color))
                .cornerRadius(8)
                .shadow(radius: 2)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: CallConnectionHealthBannerHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, topInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .onPreferenceChange(CallConnectionHealthBannerHeightPreferenceKey.self) { height in
            onHeightChange(height)
        }
    }
}

private struct CallConnectionHealthBannerHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum CallConnectionHealthStatus: Equatable {
    case connecting
    case connectionInterrupted
    case mediaRecovering
    case localNetworkPoor
    case remoteNetworkPoor

    var localizationKey: String {
        switch self {
        case .connecting:
            return "MEETING_NAVAGATION_CONNECTING"
        case .connectionInterrupted:
            return "MEETING_NAVAGATION_RECONNECTING_FAILURE"
        case .mediaRecovering:
            return MediaSendStatusPresentation.recoveringLocalizationKey
        case .localNetworkPoor:
            return "MEETING_NAVAGATION_SELF_NETWORK_POOR"
        case .remoteNetworkPoor:
            return "SINGLE_CALL_CALLER_NETWORK_POOR"
        }
    }

    var showsSpinner: Bool {
        switch self {
        case .connecting, .mediaRecovering:
            return true
        case .connectionInterrupted, .localNetworkPoor, .remoteNetworkPoor:
            return false
        }
    }

    var usesNetworkIcon: Bool {
        switch self {
        case .localNetworkPoor, .remoteNetworkPoor:
            return true
        case .connecting, .connectionInterrupted, .mediaRecovering:
            return false
        }
    }
}

private struct CallingEncryptionStatusView: View {

    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var animationModel = CallingEncryptionAnimationModel()
    let onTapEncryption: () -> Void

    var body: some View {
        ZStack {
            Text(Localized("MEETING_NAVAGATION_CALLING"))
                .opacity(animationModel.showsEncryption ? 0 : 1)
                .accessibilityHidden(animationModel.showsEncryption)

            Button(action: onTapEncryption) {
                HStack(spacing: 4) {
                    Image("ic_e2ee_lock")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)

                    Text(Localized("MEETING_NAVAGATION_E2EE"))
                }
            }
            .buttonStyle(.plain)
            .opacity(animationModel.showsEncryption ? 1 : 0)
            .allowsHitTesting(animationModel.showsEncryption)
            .accessibilityHidden(!animationModel.showsEncryption)
            .accessibilityLabel(Localized("MEETING_NAVAGATION_E2EE"))
            .accessibilityHint(Localized("CONVERSATION_E2EE_LEARN_MORE"))
        }
        .font(.system(size: 12))
        .foregroundColor(.white)
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(maxWidth: .infinity)
        .onAppear {
            animationModel.start(reduceMotion: reduceMotion)
        }
        .onDisappear {
            animationModel.stop()
        }
        .onChange(of: reduceMotion) { _ in
            animationModel.start(reduceMotion: reduceMotion)
        }
    }
}

private final class CallingEncryptionAnimationModel: ObservableObject {

    // Match the HTML prototype: 43% static + 7% cross-fade in each 1.6-second half-cycle.
    private static let cycleDuration: TimeInterval = 3.2
    private static let halfCycleDuration = cycleDuration / 2
    private static let staticPhaseDuration = cycleDuration * 0.43
    private static let transitionDuration = cycleDuration * 0.07

    @Published private(set) var showsEncryption = false
    private var cycleTimer: Timer?

    deinit {
        cycleTimer?.invalidate()
    }

    func start(reduceMotion: Bool) {
        stop()

        // Keep the security state visible when Reduce Motion is enabled, matching the prototype.
        showsEncryption = reduceMotion
        guard !reduceMotion else { return }

        let timer = Timer(
            fire: Date().addingTimeInterval(Self.staticPhaseDuration),
            interval: Self.halfCycleDuration,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            withAnimation(.easeInOut(duration: Self.transitionDuration)) {
                self.showsEncryption.toggle()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        cycleTimer = timer
    }

    func stop() {
        cycleTimer?.invalidate()
        cycleTimer = nil
    }
}

struct EncryptionInfoButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("ic_e2ee_lock")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .frame(width: 20, height: 20, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .accessibilityLabel(Localized("MEETING_NAVAGATION_E2EE"))
        .accessibilityHint(Localized("CONVERSATION_E2EE_LEARN_MORE"))
    }
}


extension UIApplication {
    var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 15.0, *) {
            return connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .first?.safeAreaInsets ?? .zero
        } else {
            return windows.first?.safeAreaInsets ?? .zero
        }
    }
}

struct CountdownView: View {
    let stringDuration: String
    @ObservedObject var timerManager: TimerDataManager

    var body: some View {
        HStack(spacing: 5) {
            Text(stringDuration)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            Rectangle()
                .fill(Color(hex: 0x474D57))
                .frame(width: 1, height: 10)
                .padding(.horizontal, 2)
            
            SwingingAlarmRepresentView(
                imageName: timerManager.imageName,
                message: timerManager.displayTime,
                isAnimating: timerManager.isShaking,
                textColor: timerManager.textColor,
                isVibrating: timerManager.isVibrating
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(timerManager.displayTime)
        }
        .frame(width: 200, height: 20)
        .offset(x: -10)
    }
}
