
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
    // 举手入口已下掉，注释保留逻辑
    // @State private var hasRaiseHands: Bool = RoomDataManager.shared.hasRaiseHands
    @State private var localRaiseHand: Bool = RoomDataManager.shared.localRaiseHand

    @State private var delayTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let rawSize = geometry.size
            let _ = {
                if rawSize.width > rawSize.height {
                    Logger.info("[RoomContextView] GeometryReader reported landscape size: \(rawSize), safeArea: \(geometry.safeAreaInsets)")
                }
            }()
            // Portrait-locked, always full-screen (AppDelegate.supportedInterfaceOrientationsForWindow).
            // Use the call window's stable size, not geometry.size, which can transiently report a
            // transposed/safe-area-crushed size during screen-share orientation flips.
            let containerSize = callContainerSize(fallback: rawSize)
            let safeAreaInsets = callSafeAreaInsets(fallback: geometry.safeAreaInsets)
            let toolbarHeight: CGFloat = 60
            let toolbarBottomPadding: CGFloat = 24 + safeAreaInsets.bottom
            let overlayBottomInset = toolbarHeight + toolbarBottomPadding
            // The grid's top row intentionally tucks just under the translucent nav bar rather
            // than clearing its full height, so reserve only a small gap below the top safe area.
            let gridTopUnderNavGap: CGFloat = 8
            let roomContentTopInset = safeAreaInsets.top + gridTopUnderNavGap
            let roomContentBottomInset = overlayBottomInset + 8

            ZStack {
                backgroundView

                CallContentView(
                    currentCall: currentCall,
                    containerSize: containerSize,
                    contentTopInset: roomContentTopInset,
                    contentBottomInset: roomContentBottomInset
                )

                BulletOverlayView(
                    bottomInset: overlayBottomInset,
                    showQuickPanel: $showQuickPanel,
                    // 举手入口已下掉，注释保留逻辑
                    // hasRaiseHand: $hasRaiseHands,
                    containerSize: containerSize
                )

                CallNavigationView(
                    currentCall: roomCtx.currentCall,
                    cameraRotateItemHidden: $isRightItemHidden,
                    leftItemAction: { roomCtx.toolbarMinimizeTaped() },
                    cameraRotateAction: switchCamera
                )
                .padding(.top, safeAreaInsets.top)
                .frame(maxHeight: .infinity, alignment: .top)

                BottomToolbarView(
                    isScreenSharing: false,
                    containerSize: containerSize,
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
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, toolbarBottomPadding)
            }
            // Fixed to the stable window-derived size so controls stay anchored regardless of
            // any transient GeometryReader size glitch.
            .frame(width: containerSize.width, height: containerSize.height)
        }
        .ignoresSafeArea()
        // 举手入口已下掉，注释保留逻辑
        // .onReceive(RoomDataManager.shared.$hasRaiseHands) { hasRaiseHands = $0 }
        .onReceive(RoomDataManager.shared.$localRaiseHand) { localRaiseHand = $0 }
        .onAppear {
            delayTask = Task {
                if DTMeetingManager.shared.isFromCallkit && needLayoutTopVCScreenShare() {
                    Logger.info("[newCall] callkit open sharePresent")
                    DTMeetingManager.shared.isFromCallkit = false
                    DTMeetingManager.shared.roomContext?.tryPresentShareView(maxRetryCount: 3)
                }
            }
        }
        .onDisappear {
            delayTask?.cancel()
        }
    }
    
    // Stable full-screen portrait size for this page. The call window keeps correct
    // bounds across orientation flips, unlike GeometryReader.size.
    private func callContainerSize(fallback fallbackSize: CGSize) -> CGSize {
        let window = OWSWindowManager.shared().callViewWindow
        let bounds = window.bounds.size
        let sourceSize = bounds.width > 0 && bounds.height > 0 ? bounds : fallbackSize
        let width = min(sourceSize.width, sourceSize.height)
        let height = max(sourceSize.width, sourceSize.height)
        return CGSize(width: max(width, 0), height: max(height, 0))
    }

    private func callSafeAreaInsets(fallback fallbackInsets: EdgeInsets) -> EdgeInsets {
        let windowInsets = OWSWindowManager.shared().callViewWindow.safeAreaInsets
        if windowInsets != .zero {
            return EdgeInsets(
                top: windowInsets.top,
                leading: windowInsets.left,
                bottom: windowInsets.bottom,
                trailing: windowInsets.right
            )
        }
        return fallbackInsets
    }

    @ViewBuilder
    private var backgroundView: some View {
        if currentCall.callType == .private {
            Color.dtBackground.ignoresSafeArea()
        } else {
            Color(hex: 0x0B0E11).ignoresSafeArea()
        }
    }
    
    private func switchCamera() {
        guard let track = roomCtx.room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
              let cameraCapturer = track.capturer as? CameraCapturer else {
            return
        }
        Task {
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
    let containerSize: CGSize
    let contentTopInset: CGFloat
    let contentBottomInset: CGFloat
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: LiveKitContext

    @ViewBuilder
    var body: some View {
        let currentCall = roomCtx.currentCall

        if currentCall.callType == .private {
            if currentCall.isCaller && currentCall.callState != .answering {
                CallerWaitingView()
            } else {
                Room1on1ContentView()
            }
        } else {
            RoomView(
                containerSize: containerSize,
                contentTopInset: contentTopInset,
                contentBottomInset: contentBottomInset
            )
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
            // Roster is kept across reconnect (Route B); read the other side from the live room.
            let localNum = TSAccountManager.localNumber()
            for participant in roomCtx.room.remoteParticipants.values {
                if let identity = participant.identity?.stringValue, identity != localNum {
                    recipientId = identity
                }
            }
        }
        return recipientId
    }

    var body: some View {
        let recipientId = otherRecipientId()
        let name = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)

        ZStack(alignment: .top) {
            VStack {
                AvatarImageViewRepresentable(recipientId: recipientId)
                    .frame(width: 120, height: 120)
                Text(name)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -40)
        
            if showTimeoutAlert {
                HStack(spacing: 8) {
                    Image("call_calling_critical")

                    Text(Localized("MEETING_CRITICAL_ALERT_NO_ANSWER"))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)

                    Button(action: sendTimeoutMessage) {
                        Text(Localized("MEETING_CRITICAL_ALERT_SEND"))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: 0x82C1FC))
                    }

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

            if showTipsBubble && showTimeoutAlert {
                CallerWaitingTipsBubbleView(
                    text: Localized("CRITICAL_ALERT_CONFIRM_TIPS_MESSAGE"),
                    buttonFrame: tipsButtonFrame
                )
                .transition(.opacity)
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
    // 举手入口已下掉，注释保留逻辑
    // @Binding var hasRaiseHand: Bool
    var containerSize: CGSize = UIScreen.main.bounds.size
    // 举手入口已下掉，注释保留逻辑
    // @State private var raiseHandsWidth: CGFloat = DTMeetingManager.shared.calculateRaiseHandsWidth()
    @State private var quickPanelHeight: CGFloat = 170

    var body: some View {
        let paddingLeading: CGFloat = 30
        let paddingOverlayLeading: CGFloat = 45
        let controlViewHeight: CGFloat = 36
        let spacing: CGFloat = 10
        // 举手入口已下掉，注释保留逻辑
        // let controlStackHeight = controlViewHeight + (hasRaiseHand ? controlViewHeight + spacing : 0)
        let controlStackHeight = controlViewHeight
        let quickPanelBottom = bottomInset + controlStackHeight + spacing
        let bulletBottom = quickPanelBottom

        let isLandscape = containerSize.width > containerSize.height
        let bulletChatWidth = isLandscape ? containerSize.width * 0.5 : min(containerSize.width, containerSize.height)

        return ZStack {
            DTBulletChatViewRepresentable()
                .frame(width: bulletChatWidth, height: 320)
                .padding(.leading, paddingLeading)
                .padding(.bottom, bulletBottom - 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(false)

            DTEmojiFlyingViewRepresentable(containerSize: CGSize(width: bulletChatWidth, height: 0), isLandscape: isLandscape)
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
                            .onChanged { _ in }
                    )

                let config = DTMeetingManager.shared.bubbleMessageConfig()
                QuickMessagePanelUIKitWrapper(
                    emojiPresets: config.emojiPresets,
                    textPresets: config.textPresets,
                    onTap: { message in
                        Task {
                            await DTMeetingManager.shared.sendDanmu(message, type: .bubble)
                            showQuickPanel = false
                        }
                    },
                    onContentSizeChange: { size in
                        if abs(size.height - quickPanelHeight) > 0.5 {
                            quickPanelHeight = size.height
                        }
                    }
                )
                .frame(width: 300, height: quickPanelHeight)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, quickPanelBottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(true)
                .onTapGesture { }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in }
                )
            }
            
            // 举手入口已下掉，注释保留逻辑
            // if hasRaiseHand {
            //     HandsControlViewRepresentable()
            //         .frame(height: controlViewHeight)
            //         .frame(width: raiseHandsWidth)
            //         .padding(.leading, paddingOverlayLeading)
            //         .padding(.bottom, bottomInset + controlViewHeight + spacing)
            //         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            //         .allowsHitTesting(hasRaiseHand)
            // }

            DTBulletChatControlViewRepresentable(showQuickPanel: $showQuickPanel)
                .frame(height: controlViewHeight)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(true)
        }
        // 举手入口已下掉，注释保留逻辑
        // .onReceive(RoomDataManager.shared.raiseHandsPublisher) { _ in
        //     raiseHandsWidth = DTMeetingManager.shared.calculateRaiseHandsWidth()
        // }
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
