
import LiveKit
import SwiftUI

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @EnvironmentObject var appCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext

    @ObservedObject private var currentCall = DTMeetingManager.shared.currentCall

    @State private var isRightItemHidden: Bool = true
    @State private var isGroupMembers: Bool = false
    @State private var showQuickPanel = false
    @State private var isPopupPresented = false
    @State private var hasRaiseHands: Bool = RoomDataManager.shared.hasRaiseHands
    @State private var localRaiseHand: Bool = RoomDataManager.shared.localRaiseHand

    @State private var delayTask: Task<Void, Never>?

    var body: some View {
        let toolbarHeight: CGFloat = 60
        let toolbarBottomPadding: CGFloat = 24
        let overlayBottomInset = toolbarHeight + toolbarBottomPadding

        ZStack {
            // 背景色
            backgroundView

            // 主内容
            CallContentView(currentCall: currentCall)
                .environmentObject(appCtx)
                .environmentObject(roomCtx)

            // 弹幕和控制层（放在底部工具栏之上）
            BulletOverlayView(
                bottomInset: overlayBottomInset,
                showQuickPanel: $showQuickPanel,
                hasRaiseHand: $hasRaiseHands
            )

            // 顶部导航
            CallNavigationView(
                currentCall: roomCtx.currentCall,
                cameraRotateItemHidden: $isRightItemHidden,
                leftItemAction: { roomCtx.toolbarMinimizeTaped() },
                cameraRotateAction: switchCamera
            )
            .environmentObject(roomCtx.room)
            .environmentObject(roomCtx)
            .frame(maxHeight: .infinity, alignment: .top)

            // 底部工具栏
            BottomToolbarView(
                isScreenSharing: false,
                cameraPublishHandler: { isCameraEnabled in
                    isRightItemHidden = !isCameraEnabled
                },
                barClickHandler: {},
                moreClickHandler: {
                    DTMeetingManager.shared.presentMicNoiseVC()
                },
                isGroupMembers: $isGroupMembers,
                localRaiseHand: $localRaiseHand
            )
            .environmentObject(appCtx)
            .environmentObject(roomCtx)
            .environmentObject(roomCtx.room)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, toolbarBottomPadding)
        }
        .onReceive(RoomDataManager.shared.$hasRaiseHands) { hasRaiseHands = $0 }
        .onReceive(RoomDataManager.shared.$localRaiseHand) { localRaiseHand = $0 }
        .onAppear {
            delayTask = Task {
                if DTMeetingManager.shared.isFromCallkit && needLayoutTopVCScreenShare() {
                    Logger.info("[newCall] callkit open sharePresent")
                    DTMeetingManager.shared.isFromCallkit = false
                    roomCtx.presentShareView()
                }
            }
        }
        .onDisappear {
            delayTask?.cancel()
        }
    }
    
    private var backgroundView: some View {
        Group {
            if currentCall.callType == .private {
                Color.dtBackground
            } else {
                Color(hex: 0x0B0E11)
            }
        }.ignoresSafeArea()
    }
    
    private func switchCamera() {
        Task {
            guard let track = roomCtx.room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
                  let cameraCapturer = track.capturer as? CameraCapturer else {
                return
            }
            try await cameraCapturer.switchCameraPosition()
        }
    }
    
    private func needLayoutTopVCScreenShare() -> Bool {
        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()
        let topName = String(describing: type(of: topVC))
        Logger.info("[RoomContext] current screnen top name \(topName)")
        let isShare = DTMeetingManager.shared.roomContext?.room.isScreenShareActive() ?? false
        let isTopScreenVC = topName.contains("DTHostingController") && topName.contains("CallScreenShareView")
        if isShare && !isTopScreenVC {
            return true
        }
        return false
    }

}

struct CallContentView: View {
    @ObservedObject var currentCall: DTLiveKitCallModel
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: LiveKitContext

    var body: some View {
        let currentCall = roomCtx.currentCall

        Group {
            if currentCall.callType == .private {
                if currentCall.isCaller && currentCall.callState != .answering {
                    CallerWaitingView()
                } else {
                    Room1on1ContentView()
                        .environmentObject(appCtx)
                        .environmentObject(roomCtx)
                        .environmentObject(roomCtx.room)
                }
            } else {
                RoomView()
                    .environmentObject(appCtx)
                    .environmentObject(roomCtx)
                    .environmentObject(roomCtx.room)
            }
        }
    }
}

struct CallerWaitingView: View {
    @EnvironmentObject var roomCtx: RoomContext
    @ObservedObject var currentCall = DTMeetingManager.shared.currentCall

    // 15秒超时逻辑
    @State private var callingStartTime: Date?
    @State private var callingTimer: Timer?
    @State private var showTimeoutAlert: Bool = false

    // Tips 气泡相关
    @State private var showTipsBubble = false
    @State private var tipsButtonFrame: CGRect = .zero
    
    func otherRecipientId() -> String {
        var recipientId = currentCall.conversationId ?? ""
        if roomCtx.room.connectionState == .reconnecting {
            let localNum = TSAccountManager.localNumber()
            let participants = DTMeetingManager.shared.sortedReconnectingParticipants()
            for participant in participants {
                if participant.identity != localNum {
                    recipientId = participant.identity
                }
            }
        }
        return recipientId
    }

    var body: some View {
        let recipientId = otherRecipientId()
        let name = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)

        VStack {
            ZStack(alignment: .top) {
                // 背景内容
                VStack {
                    Spacer() // 让内容整体居中偏下
                    AvatarImageViewRepresentable(recipientId: recipientId)
                        .frame(width: 120, height: 120)
                        .offset(y: -40)
                    Text(name)
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                        .padding(.top, 10)
                        .offset(y: -40)
                    Spacer()
                }
            
                if showTimeoutAlert {
                    HStack(spacing: 8) {
                        Image("call_calling_critical")

                        HStack(spacing: 0) {
                            Text(Localized("MEETING_CRITICAL_ALERT_NO_ANSWER"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white)

                            Button(action: sendTimeoutMessage) {
                                Text(Localized("MEETING_CRITICAL_ALERT_SEND"))
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color(hex: 0x82C1FC))
                            }
                        }

                        // Tips 按钮（在同一个背景内）
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
                                    key: CallerWaitingTipsButtonFramePreferenceKey.self,
                                    value: geo.frame(in: .global)
                                )
                            }
                        )
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(rgbHex: 0x2B3139))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding(.top, 45)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showTimeoutAlert)
                }

                // Tips 气泡（只在超时提示显示时才显示）
                if showTipsBubble && showTimeoutAlert {
                    CallerWaitingTipsBubbleView(
                        text: Localized("CRITICAL_ALERT_CONFIRM_TIPS_MESSAGE"),
                        buttonFrame: tipsButtonFrame
                    )
                    .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(CallerWaitingTipsButtonFramePreferenceKey.self) { frame in
            tipsButtonFrame = frame
        }
        .onAppear {
            startCallingTimerIfNeeded()
        }
        .onDisappear {
            stopCallingTimer()
        }
        .onChange(of: currentCall.callState) { newState in
            if newState != .outgoing {
                stopCallingTimer()
            }
        }
    }
    
    private func startCallingTimerIfNeeded() {
        // 只在1v1通话outgoing状态时开始计时
        guard currentCall.callType == .private && 
              currentCall.callState == .outgoing && 
              currentCall.isCaller else {
            return
        }
        
        callingStartTime = Date()
        showTimeoutAlert = false
        
        // 15秒后显示超时提示
        callingTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if callingStartTime != nil {
                    showTimeoutAlert = true
                }
            }
        }
    }
    
    private func stopCallingTimer() {
        callingTimer?.invalidate()
        callingTimer = nil
        callingStartTime = nil
        showTimeoutAlert = false
        showTipsBubble = false
    }
    
    private func sendTimeoutMessage() {
        Task {
            await DTMeetingManager.shared.sendCriticalAlert(message: Localized("MEETING_CRITICAL_ALERT_DANMU"))
        }
        // 关闭提示和气泡
        showTimeoutAlert = false
        showTipsBubble = false
    }
}

struct BulletOverlayView: View {
    let bottomInset: CGFloat
    @Binding var showQuickPanel: Bool
    @Binding var hasRaiseHand: Bool
    @State private var raiseHandsWidth: CGFloat = DTMeetingManager.shared.calculateRaiseHandsWidth()

    var body: some View {
        let paddingLeading: CGFloat = 30
        let paddingOverlayLeading: CGFloat = 45
        let controlViewHeight: CGFloat = 36
        let spacing: CGFloat = 10
        let controlStackHeight = controlViewHeight + (hasRaiseHand ? controlViewHeight + spacing : 0)
        let quickPanelBottom = bottomInset + controlStackHeight + spacing
        let bulletBottom = quickPanelBottom

        let currentScreenSize = UIScreen.main.bounds.size
        let isLandscape = currentScreenSize.width > currentScreenSize.height
        let bulletChatWidth = isLandscape ? currentScreenSize.width * 0.5 : min(currentScreenSize.width, currentScreenSize.height)

        return ZStack {
            DTBulletChatViewRepresentable()
                .frame(width: bulletChatWidth, height: 320)
                .padding(.leading, paddingLeading)
                .padding(.bottom, bulletBottom - 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)

            // 添加气泡消息视图
            DTEmojiFlyingViewRepresentable(containerSize: CGSize(width: bulletChatWidth, height: 0))
                .frame(width: bulletChatWidth)
                .padding(.leading, paddingLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)

            if showQuickPanel {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showQuickPanel = false
                    }
                    .allowsHitTesting(true)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                            }
                    )
            }
            
            if showQuickPanel {
                let config = DTMeetingManager.shared.bubbleMessageConfig()
                QuickMessagePanelUIKitWrapper(
                    emojiPresets: config.emojiPresets,
                    textPresets: config.textPresets
                ) { message in
                    Task {
                        // 发送气泡类型消息
                        await DTMeetingManager.shared.sendDanmu(message, type: .bubble)
                        showQuickPanel = false
                    }
                }
                .frame(width: 300, height: 170)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, quickPanelBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(true)
                .onTapGesture {
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                        }
                )
            }
            
            if hasRaiseHand {
                HandsControlViewRepresentable()
                    .frame(height: controlViewHeight)
                    .frame(width: raiseHandsWidth)
                    .padding(.leading, paddingOverlayLeading)
                    .padding(.bottom, bottomInset + controlViewHeight + spacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(hasRaiseHand)
            }

            DTBulletChatControlViewRepresentable(showQuickPanel: $showQuickPanel)
                .frame(height: controlViewHeight)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(true)
        }
        .onReceive(RoomDataManager.shared.raiseHandsPublisher) { _ in
            raiseHandsWidth = DTMeetingManager.shared.calculateRaiseHandsWidth()
        }
    }
}

extension Decimal {
    mutating func round(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) {
        var localCopy = self
        NSDecimalRound(&self, &localCopy, scale, roundingMode)
    }

    func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, roundingMode)
        return result
    }

    func remainder(of divisor: Decimal) -> Decimal {
        let s = self as NSDecimalNumber
        let d = divisor as NSDecimalNumber
        let b = NSDecimalNumberHandler(roundingMode: .down,
                                       scale: 0,
                                       raiseOnExactness: false,
                                       raiseOnOverflow: false,
                                       raiseOnUnderflow: false,
                                       raiseOnDivideByZero: false)
        let quotient = s.dividing(by: d, withBehavior: b)

        let subtractAmount = quotient.multiplying(by: d)
        return s.subtracting(subtractAmount) as Decimal
    }
}

extension Color {
    init(rgbHex: Int, alpha: Double = 1.0) {
        let red = Double((rgbHex >> 16) & 0xFF) / 255.0
        let green = Double((rgbHex >> 8) & 0xFF) / 255.0
        let blue = Double(rgbHex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Caller Waiting Tips Bubble View

struct CallerWaitingTipsBubbleView: View {
    let text: String
    let buttonFrame: CGRect

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let bubbleMaxWidth: CGFloat = 220
        let bubblePadding: CGFloat = 20

        // 计算气泡的 X 位置，确保不超出屏幕（向左偏移）
        let bubbleX: CGFloat = {
            let idealX = buttonFrame.midX - 60  // 向左偏移，让箭头在右侧
            let halfWidth = bubbleMaxWidth / 2

            if idealX - halfWidth < bubblePadding {
                // 左边界限制
                return bubblePadding + halfWidth
            } else if idealX + halfWidth > screenWidth - bubblePadding {
                // 右边界限制
                return screenWidth - bubblePadding - halfWidth
            } else {
                return idealX
            }
        }()

        // 计算箭头相对于气泡的偏移量（箭头指向按钮中心）
        let arrowOffset = buttonFrame.midX - bubbleX

        VStack(spacing: -2) {
            // 箭头（指向上方的按钮）
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: max(0, bubbleMaxWidth / 2 + arrowOffset - 7))

                CallerWaitingTriangleShape()
                    .fill(Color(hex: 0x5E6673))
                    .frame(width: 14, height: 8)

                Spacer()
            }
            .frame(width: bubbleMaxWidth)

            // 气泡内容
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: bubbleMaxWidth, alignment: .leading)
                .background(Color(hex: 0x5E6673))
                .cornerRadius(8)
        }
        .position(
            x: bubbleX + 15,
            y: buttonFrame.maxY - 8
        )
    }
}

struct CallerWaitingTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct CallerWaitingTipsButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
