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
    @StateObject private var timerManager = TimerDataManager.shared
    @Binding var cameraRotateItemHidden: Bool
    @EnvironmentObject var room: Room
    @EnvironmentObject var roomCtx: RoomContext

    var leftItemAction: () -> Void
    var cameraRotateAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer().frame(width: 15)
                // 左按钮
                Button(action: leftItemAction) {
                    Image("ic_call_mini")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                Spacer()
                centerContent()
                Spacer().frame(width: 64)
            }
            .padding(.horizontal, 10)
            .frame(height: 44) // 固定高度，和系统导航栏一致
            .padding(.top, safeAreaInsetsTop) // 自动加上状态栏/刘海高度
            .background(Color.black.opacity(currentCall.callType == .private ? 0 : 0.2))
        }
        .ignoresSafeArea(edges: .top) // 内容顶到屏幕最上方
    }

    @ViewBuilder
    private func centerContent() -> some View {
        let connectState = room.connectionState
        let isPrivateOutgoing = currentCall.callType == .private && currentCall.callState == .outgoing
        let shouldShow = isPrivateOutgoing ? DTMeetingManager.shared.inMeeting : true
        let shouldShowRoomName = currentCall.callType != .private
        let reconnectingCount = DTMeetingManager.shared.reconnectingParticipants?.count ?? 0
        let participantCount = connectState == .reconnecting ? reconnectingCount : room.allParticipants.count

        if shouldShow {
            VStack(spacing: 2) {
                // 房间名 + 人数
                if shouldShowRoomName {
                    Text("\(currentCall.roomName)(\(participantCount))")
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                }

                // 网络状态 or 通话时长
                switch connectState {
                case .reconnecting:
                    HStack(spacing: 8) {
                        DTCircleLoadingView(connectState: .connecting)
                        statusText(Localized("MEETING_NAVAGATION_CONNECTING"))
                    }
                    .fixedSize()
                case .disconnected:
                    statusText("disconnected")
                default:
                    if let duration = timerManager.duration, duration > 0 {
                        let stringDuration = DTLiveKitCallModel.stringDuration(duration)
                        if timerManager.isShowCountDownView {
                            CountdownView(
                                stringDuration: stringDuration,
                                timerManager: timerManager
                            )
                        } else {
                            statusText(stringDuration)
                        }
                    } else if currentCall.callType == .private {
                        statusText(Localized("MEETING_NAVAGATION_CONNECTING"))
                    }
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

    // MARK: - SafeArea Helper
    private var safeAreaInsetsTop: CGFloat {
        UIApplication.shared.safeAreaInsets.top
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
        HStack {
            Spacer()
            Group {
                HStack(spacing: 5) {
                    Spacer()
                    
                    Text(stringDuration)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    
                    Rectangle()
                        .fill(Color.init(hex: 0x474D57))
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

                    Spacer()
                }.offset(x: -10)
            }
            .frame(width: 200, height: 20)
            Spacer()
        }
    }
}
