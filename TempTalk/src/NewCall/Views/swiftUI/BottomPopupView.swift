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
    @State private var isSwitchOn: Bool = DTMeetingManager.shared.roomContext?.isDenoiseFilterEnabled() ?? true
    @StateObject private var roomDataManager = RoomDataManager.shared

    @GestureState private var dragOffset = CGSize.zero
    @State private var offsetY: CGFloat = 0

    var body: some View {
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
                    HStack(spacing: 50) {
                        VerticalIconTextButton(
                            normalImage: Image("calling_invite"),
                            title: Localized("CALL_INVITE_MEMBERS"),
                            action: {
                                DTMeetingManager.shared.roomContext?.presentInviteView()
                            }
                        ).frame(width: 80, height: 76)
                        
                        if DTMeetingManager.shared.currentCall.callType != .private {
                            VerticalIconTextButton(
                                normalImage: Image("calling_lowerHand"),
                                selectedImage: Image("calling_raiseHand"),
                                title: Localized("RAISE_HANDS_TITLE"),
                                isSelected: $roomDataManager.localRaiseHand,
                                action: {
                                    if RoomDataManager.shared.localRaiseHand {
                                        Task {
                                            await DTMeetingManager.shared.handCancelRemoteSyncStatus(participantId: DTMeetingManager.shared.roomContext?.room.localParticipant.identity?.stringValue.components(separatedBy: ".").first ?? "")
                                            RoomDataManager.shared.localRaiseHand = false
                                        }
                                    } else {
                                        Task {
                                            await DTMeetingManager.shared.handRaiseRemoteSyncStatus()
                                            RoomDataManager.shared.localRaiseHand = true
                                        }
                                    }
                                }
                            ).frame(width: 80, height: 76)
                        }
                        
                        VerticalIconTextButton(
                            normalImage: Image("call_switch"),
                            title: Localized("CALL_MORE_SWITCH_CAMERA"),
                            action: {
                                DTMeetingManager.shared.switchCamera()
                            }
                        ).frame(width: 80, height: 76)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 50)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
                    HStack {
                        Text(Localized("CALLING_NOISE_TITLE"))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                        Spacer()
                        SwitchView(isOn: $isSwitchOn)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: 355, height: 55)
                    .background(Color(hex: 0x474D57).cornerRadius(8))
                    .padding(.top, -10)

                    Spacer()
                }
                .frame(width: 375, height: 210)
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
            isOn.wrappedValue = sender.isOn
            guard let roomContext = DTMeetingManager.shared.roomContext else {
                Logger.info("\(DTMeetingManager.shared.logTag) Room context is nil when changing noise settings")
                return
            }
            roomContext.setDenoiseFilter(enabled: sender.isOn)
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
