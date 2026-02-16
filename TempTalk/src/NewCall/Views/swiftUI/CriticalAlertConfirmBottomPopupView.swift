//
//  CriticalAlertConfirmBottomPopupView.swift
//  Difft
//
//  Created by henry on 2026/01/29.
//  Copyright © 2026 Difft. All rights reserved.
//

import SwiftUI
import TTServiceKit
import TTMessaging

struct CriticalAlertConfirmBottomPopupView: View {
    let onDismiss: () -> Void
    let invitedUserIds: [String]
    let callType: CallType

    @GestureState private var dragOffset = CGSize.zero
    @State private var showTipsBubble = false
    @State private var tipsButtonFrame: CGRect = .zero

    let meetingManager = DTMeetingManager.shared

    var body: some View {
        let kScreenWidth: CGFloat = min(screenWidth, screenHeight)

        ZStack {
            // 背景层，点击时触发收起
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showTipsBubble = false  // 立即隐藏气泡
                    onDismiss()
                }

            // 弹出层
            VStack {
                Spacer()
                VStack(spacing: 0) {
                    // 标题和描述区域
                    VStack(spacing: 12) {
                        // 标题和提示按钮
                        HStack(spacing: 8) {
                            Text(Localized("CRITICAL_ALERT_CONFIRM_TITLE"))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(hex: 0xEAECEF))

                            Button(action: {
                                showTipsBubble.toggle()
                            }) {
                                Image("critical_alert_confirm_tips")
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: TipsButtonFramePreferenceKey.self,
                                        value: geo.frame(in: .global)
                                    )
                                }
                            )
                        }

                        // 描述文本
                        Text(generateDescriptionText())
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: 0xB7BDC6))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                    // 按钮区域
                    HStack(spacing: 12) {
                        // Cancel 按钮
                        Button(action: {
                            showTipsBubble = false  // 立即隐藏气泡
                            onDismiss()
                        }) {
                            Text(Localized("CRITICAL_ALERT_CANCEL"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color(hex: 0x2B3139))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: 0x474D57), lineWidth: 1)
                                )
                        }

                        // Send 按钮
                        Button(action: {
                            handleSendButtonTapped()
                        }) {
                            Text(Localized("CRITICAL_ALERT_SEND"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color(hex: 0x056FFA))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .frame(width: kScreenWidth)
                .background(
                    Color(hex: 0x2B3139)
                        .clipShape(CriticalAlertRoundedCorner(radius: 10, corners: [.topLeft, .topRight]))
                )
                .offset(y: dragOffset.height)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            if value.translation.height > 0 {
                                state = value.translation
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 50 {
                                showTipsBubble = false  // 立即隐藏气泡
                                onDismiss()
                            }
                        }
                )
                .animation(.easeOut(duration: 0.25), value: dragOffset)
            }

            // 气泡提示
            if showTipsBubble {
                TipsBubbleView(
                    text: Localized("CRITICAL_ALERT_CONFIRM_TIPS_MESSAGE"),
                    buttonFrame: tipsButtonFrame
                )
                .transition(.opacity)
            }
        }
        .onPreferenceChange(TipsButtonFramePreferenceKey.self) { frame in
            tipsButtonFrame = frame
        }
    }

    private func generateDescriptionText() -> String {
        let contactsManager = Environment.shared.contactsManager

        // 获取用户显示名称
        let displayNames = invitedUserIds.compactMap { userId in
            contactsManager?.displayName(forPhoneIdentifier: userId)
        }

        switch callType {
        case .instant:
            // Instant: Send to [最多3人名] and [剩余人数] more
            if displayNames.isEmpty {
                return Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT_EMPTY")
            }

            let maxDisplayCount = 3
            let displayedNames = Array(displayNames.prefix(maxDisplayCount))
            let remainingCount = displayNames.count - displayedNames.count

            let namesText = displayedNames.joined(separator: ", ")

            if remainingCount > 0 {
                return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT_WITH_MORE"), namesText, remainingCount + maxDisplayCount)
            } else {
                return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_INSTANT"), namesText)
            }

        case .group:
            // Group: 根据是否有邀请人显示不同文案
            if displayNames.isEmpty {
                // 只有群成员
                return Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP")
            } else {
                // 群成员 + 邀请人
                let maxDisplayCount = 3
                let displayedNames = Array(displayNames.prefix(maxDisplayCount))
                let remainingCount = displayNames.count - displayedNames.count

                let namesText = displayedNames.joined(separator: ", ")

                if remainingCount > 0 {
                    return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP_WITH_INVITED_MORE"), namesText, remainingCount + maxDisplayCount)
                } else {
                    return String(format: Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP_WITH_INVITED"), namesText)
                }
            }

        default:
            return Localized("CRITICAL_ALERT_CONFIRM_DESC_GROUP")
        }
    }

    private func handleSendButtonTapped() {
        showTipsBubble = false  // 立即隐藏气泡
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

// MARK: - Tips Bubble View

struct TipsBubbleView: View {
    let text: String
    let buttonFrame: CGRect

    var body: some View {
        VStack(spacing: -2) {
            // 箭头（指向上方的按钮）
            HStack(spacing: 0) {
                Spacer()

                TriangleShape()
                    .fill(Color(hex: 0x5E6673))
                    .frame(width: 14, height: 8)

                Spacer()
            }
            .frame(width: min(360, buttonFrame.width + 40))

            // 气泡内容
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: 360, alignment: .leading)
                .background(Color(hex: 0x5E6673))
                .cornerRadius(8)
        }
        .position(
            x: buttonFrame.midX,
            y: buttonFrame.maxY + 8 + 20  // 按钮底部 + 箭头高度 + 间距
        )
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct TipsButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - CriticalAlertRoundedCorner Shape

struct CriticalAlertRoundedCorner: Shape {
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
