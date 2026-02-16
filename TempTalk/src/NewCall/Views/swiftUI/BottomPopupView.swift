//
//  BottomPopupView.swift
//  Difft
//
//  Created by Henry on 2025/7/17.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

struct BottomPopupView: View {
    let onDismiss: () -> Void
    let onShowCriticalAlertConfirm: () -> Void
    @State private var isSwitchOn: Bool = DTMeetingManager.shared.roomContext?.isDenoiseFilterEnabled() ?? true
    @ObservedObject private var roomDataManager = RoomDataManager.shared
    @State private var refreshTrigger = false

    @GestureState private var dragOffset = CGSize.zero
    @State private var offsetY: CGFloat = 0
    let meetingManager = DTMeetingManager.shared

    var body: some View {

        let _ = refreshTrigger // Force rebuild when notifications fire
        let buttons = buildButtons()
        let count = buttons.count
        let kScreenWidth: CGFloat = min(screenWidth, screenHeight)
        
        // 根据数量自适应 spacing
        let spacing: CGFloat = {
            switch count {
            case 1: return 0
            case 2: return 100
            case 3: return 30
            case 4: return 0
            default: return 40
            }
        }()
        
        ZStack {
            // 背景层，点击时触发收起
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 弹出层
            VStack {
                Spacer()
                VStack {
                    HStack(spacing: spacing) {
                        ForEach(buttons.indices, id: \.self) { idx in
                            buttons[idx]
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 50)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .animation(.easeInOut(duration: 0.25), value: count)
                    
                    HStack {
                        Text(Localized("CALLING_NOISE_TITLE"))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                        Spacer()
                        SwitchView(isOn: $isSwitchOn)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: kScreenWidth - 20, height: 55)
                    .background(Color(hex: 0x474D57).cornerRadius(8))
                    .padding(.top, -10)

                    Spacer()
                }
                .frame(width: kScreenWidth, height: 210)
                .background(
                    Color(hex: 0x2B3139)
                        .clipShape(RoundedCorner(radius: 10, corners: [.topLeft, .topRight]))
                )
                .offset(y: offsetY + dragOffset.height)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.height > 0 {
                                state = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 50 {
                                onDismiss()
                            }
                        }
                )
                .animation(.easeOut(duration: 0.25), value: dragOffset)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CallStateDidChange"))) { _ in
            refreshTrigger.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DTGroupCriticalAlertChangedNotification"))) { _ in
            refreshTrigger.toggle()
        }
    }

    private func buildButtons() -> [AnyView] {
            var result: [AnyView] = []
            let call = meetingManager.currentCall
            let buttonWidth: CGFloat = 100

            // Always show invite button
            result.append(AnyView(
                VerticalIconTextButton(
                    normalImage: Image("calling_invite"),
                    title: Localized("CALL_INVITE_MEMBERS")
                ) {
                    meetingManager.roomContext?.presentInviteView()
                }
                .frame(width: buttonWidth, height: 76)
            ))

            switch call.callType {
            case .private:
                // Private call: show switch camera if enabled, and critical alert if outgoing and not in meeting
                if meetingManager.openCallCamera {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_switch"),
                            title: Localized("CALL_MORE_SWITCH_CAMERA")
                        ) {
                            meetingManager.switchCamera()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }

                if !meetingManager.inMeeting, call.callState == .outgoing {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_critical"),
                            title: Localized("CALL_MORE_CRITICAL_ALERT")
                        ) {
                            handleCriticalAlertTap()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }

            case .group:
                // Group call: show raise hand, switch camera if enabled, and critical alert if enabled in group settings
                guard
                    let gid = call.conversationId,
                    let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
                    let groupThread = TSGroupThread.getWithGroupId(groupId)
                else {
                    break
                }

                result.append(AnyView(
                    VerticalIconTextButton(
                        normalImage: Image("calling_lowerHand"),
                        selectedImage: Image("calling_raiseHand"),
                        title: Localized("RAISE_HANDS_TITLE"),
                        isSelected: $roomDataManager.localRaiseHand
                    ) {
                        Task {
                            if roomDataManager.localRaiseHand {
                                await meetingManager.handCancelRemoteSyncStatus(
                                    participantId: meetingManager.roomContext?
                                        .room.localParticipant.identity?.stringValue
                                        .components(separatedBy: ".").first ?? ""
                                )
                                roomDataManager.localRaiseHand = false
                            } else {
                                await meetingManager.handRaiseRemoteSyncStatus()
                                roomDataManager.localRaiseHand = true
                            }
                        }
                    }
                    .frame(width: buttonWidth, height: 76)
                ))

                if meetingManager.openCallCamera {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_switch"),
                            title: Localized("CALL_MORE_SWITCH_CAMERA")
                        ) {
                            meetingManager.switchCamera()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }

                if groupThread.groupModel.criticalAlert {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_critical"),
                            title: Localized("CALL_MORE_CRITICAL_ALERT")
                        ) {
                            handleCriticalAlertTap()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }

            default:
                // Instant call: show switch camera if enabled, and critical alert if there are invited users
                if meetingManager.openCallCamera {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_switch"),
                            title: Localized("CALL_MORE_SWITCH_CAMERA")
                        ) {
                            meetingManager.switchCamera()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }

                if meetingManager.currentCall.invitedCriticalAlertUsers.count > 0 {
                    result.append(AnyView(
                        VerticalIconTextButton(
                            normalImage: Image("call_critical"),
                            title: Localized("CALL_MORE_CRITICAL_ALERT")
                        ) {
                            handleCriticalAlertTap()
                        }
                        .frame(width: buttonWidth, height: 76)
                    ))
                }
            }

            return result
        }

    private func handleCriticalAlertTap() {
        // 判断是否需要显示二次确认弹窗
        if meetingManager.shouldShowCriticalAlertConfirm {
            // Instant/Group: 显示二次确认弹窗（使用 SwiftUI 版本，适配横屏分享状态）
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onShowCriticalAlertConfirm()
            }
        } else {
            // 1v1: 直接发送 Critical Alert
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                Task {
                    await meetingManager.sendCriticalAlert(
                        message: Localized("MEETING_CRITICAL_ALERT_DANMU")
                    )
                }
            }
        }
    }
}


struct SwitchView: UIViewRepresentable {
    @Binding var isOn: Bool

    func makeUIView(context: Context) -> UISwitch {
        let uiSwitch = UISwitch()
        uiSwitch.addTarget(context.coordinator, action: #selector(Coordinator.toggleChanged(_:)), for: .valueChanged)
        return uiSwitch
    }

    func updateUIView(_ uiView: UISwitch, context: Context) {
        uiView.isOn = isOn
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isOn: $isOn)
    }

    class Coordinator: NSObject {
        var isOn: Binding<Bool>

        init(isOn: Binding<Bool>) {
            self.isOn = isOn
        }

        @objc func toggleChanged(_ sender: UISwitch) {
            Task { @MainActor in
                isOn.wrappedValue = sender.isOn
                guard let roomContext = DTMeetingManager.shared.roomContext else {
                    Logger.info("\(DTMeetingManager.shared.logTag) Room context is nil when changing noise settings")
                    return
                }
                roomContext.setDenoiseFilter(enabled: sender.isOn)
            }
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 10.0
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct VerticalIconTextButton: View {
    let normalImage: Image
    let selectedImage: Image?
    let title: String
    private var isSelected: Binding<Bool>?
    let action: () -> Void

    init(
        normalImage: Image,
        selectedImage: Image? = nil,
        title: String,
        isSelected: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        self.normalImage = normalImage
        self.selectedImage = selectedImage
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    init(
        normalImage: Image,
        selectedImage: Image? = nil,
        title: String,
        action: @escaping () -> Void
    ) {
        self.normalImage = normalImage
        self.selectedImage = selectedImage
        self.title = title
        self.isSelected = nil
        self.action = action
    }

    var body: some View {
        VStack(spacing: 6) {
            let showSelected = isSelected?.wrappedValue ?? false
            (showSelected ? selectedImage ?? Image("calling_raiseHand") : normalImage)
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: 0xEAECEF))
        }
        .padding(8)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}
