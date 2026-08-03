//
//  CallNavigationView.swift
//  TempTalk
//
//  Created by Ethan on 25/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import SFSafeSymbols
import LiveKit

struct CallNavigationView: View {

    @ObservedObject var currentCall: DTLiveKitCallModel
    @Binding var cameraRotateItemHidden: Bool
    @EnvironmentObject var room: Room
    @EnvironmentObject var roomCtx: RoomContext

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
            CallNavigationCenterView(currentCall: currentCall)
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
    @ObservedObject private var timerManager = TimerDataManager.shared
    @ObservedObject private var dataManager = RoomDataManager.shared
    @EnvironmentObject var room: Room
    @EnvironmentObject var roomCtx: RoomContext

    var body: some View {
        let isReconnecting = roomCtx.isRoomReconnecting
        let isPrivateOutgoing = currentCall.callType == .private && currentCall.callState == .outgoing
        let shouldShow = isPrivateOutgoing ? DTMeetingManager.shared.inMeeting : true
        let shouldShowRoomName = currentCall.callType != .private
        // Roster is kept across reconnect (Route B), so participantCount stays accurate; no cached fallback.
        let displayCount = dataManager.participantCount

        if shouldShow {
            VStack(spacing: 2) {
                if shouldShowRoomName {
                    Text("\(currentCall.roomName)(\(displayCount))")
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                }


                if isReconnecting {
                    statusText(Localized("MEETING_NAVAGATION_CONNECTING"))
                } else if let duration = timerManager.duration, duration > 0 {
                    let stringDuration = DTLiveKitCallModel.stringDuration(duration)
                    if timerManager.isShowCountDownView {
                        CountdownView(
                            stringDuration: stringDuration,
                            timerManager: timerManager
                        )
                    } else {
                        statusText(stringDuration)
                            .accessibilityIdentifier(DTCallAccessibilityID.callDuration)
                    }
                } else if currentCall.callType == .private {
                    statusText(Localized("MEETING_NAVAGATION_CONNECTING"))
                }
            }
        } else {
            VStack(spacing: 2) {
                if isPrivateOutgoing, !DTMeetingManager.shared.inMeeting {
                    statusText(Localized("MEETING_NAVAGATION_CALLING"))
                }
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
