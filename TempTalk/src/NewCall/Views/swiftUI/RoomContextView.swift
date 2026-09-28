
import LiveKit
import SwiftUI
import TTMessaging

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @State private var delayTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            RoomChromeContentView(
                rawSize: geometry.size,
                geometrySafeAreaInsets: geometry.safeAreaInsets
            )
        }
        .ignoresSafeArea()
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

private struct RoomChromeContentView: View {
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room

    let rawSize: CGSize
    let geometrySafeAreaInsets: EdgeInsets

    @State private var isRightItemHidden: Bool = true
    @State private var isGroupMembers: Bool = false
    @State private var showQuickPanel = false
    @State private var lastChromeToggleTime: TimeInterval = 0
    @StateObject private var viewModel = ControlBarViewModel()
    // 举手入口已下掉，注释保留逻辑
    // @State private var hasRaiseHands: Bool = RoomDataManager.shared.hasRaiseHands
    @State private var localRaiseHand: Bool = RoomDataManager.shared.localRaiseHand
    @State private var healthBannerHeight: CGFloat = 0

    var body: some View {
        // Portrait-locked, always full-screen (AppDelegate.supportedInterfaceOrientationsForWindow).
        // Use the call window's stable size, not geometry.size, which can transiently report a
        // transposed/safe-area-crushed size during screen-share orientation flips.
        let containerSize = callContainerSize(fallback: rawSize)
        let safeAreaInsets = callSafeAreaInsets(fallback: geometrySafeAreaInsets)
        // Immersive toggle is portrait-only. Use the actual geometry here; containerSize is
        // normalized for layout and is therefore always portrait-shaped.
        let isPortrait = rawSize.height >= rawSize.width
        let showControls = isPortrait ? viewModel.showControls : true
        let toolbarHeight: CGFloat = 60
        let toolbarBottomPadding: CGFloat = 24 + safeAreaInsets.bottom
        let overlayBottomInset = toolbarHeight + toolbarBottomPadding
        let navigationHeight: CGFloat = 44
        let bulletControlHeight: CGFloat = 36
        let gridBottomBelowBulletGap: CGFloat = 16
        let bulletReservedInset = bulletControlHeight + gridBottomBelowBulletGap
        let visibleToolbarInset = showControls ? overlayBottomInset : (safeAreaInsets.bottom + 24)
        let roomContentTopInset = safeAreaInsets.top + (showControls ? navigationHeight : 0)
        // Top edge for 1v1 content that must clear the navigation row (timeout banner, floating
        // preview). Deliberately independent of `showControls` so nothing jumps when the chrome
        // hides, and unlike `roomContentTopInset` it never collapses to the bare safe area.
        let belowNavigationInset = safeAreaInsets.top + navigationHeight + 8
        let roomContentBottomInset = visibleToolbarInset + bulletReservedInset
        CallStatusPresentationReader(
            currentCall: roomCtx.currentCall,
            room: room,
            roomCtx: roomCtx
        ) { callStatusPresentation in
            let healthBannerClearance = callStatusPresentation.healthStatus == nil
                ? 0
                : max(healthBannerHeight, CallConnectionHealthBanner.minimumPillHeight) + 8

            ZStack {
                CallContentView(
                    currentCall: roomCtx.currentCall,
                    containerSize: containerSize,
                    contentTopInset: roomContentTopInset,
                    contentBottomInset: roomContentBottomInset,
                    belowNavigationInset: belowNavigationInset,
                    previewTopInset: belowNavigationInset + healthBannerClearance,
                    bulletReservedInset: bulletReservedInset
                )
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleChromeControlsIfNeeded(isPortrait: isPortrait)
                }
                .animation(.easeInOut(duration: 0.25), value: showControls)

                BulletOverlayView(
                    bottomInset: visibleToolbarInset,
                    viewModel: viewModel,
                    showQuickPanel: $showQuickPanel,
                    // 举手入口已下掉，注释保留逻辑
                    // hasRaiseHand: $hasRaiseHands,
                    containerSize: containerSize
                )

                RoomChromeControlsView(
                    viewModel: viewModel,
                    currentCall: roomCtx.currentCall,
                    presentation: callStatusPresentation,
                    containerSize: containerSize,
                    safeAreaTop: safeAreaInsets.top,
                    toolbarBottomPadding: toolbarBottomPadding,
                    cameraRotateItemHidden: $isRightItemHidden,
                    isGroupMembers: $isGroupMembers,
                    localRaiseHand: $localRaiseHand,
                    leftItemAction: { roomCtx.toolbarMinimizeTaped() },
                    cameraRotateAction: switchCamera,
                    moreClickAction: {
                        DTMeetingManager.shared.presentMicNoiseVC()
                    }
                )
                .zIndex(10)

                CallConnectionHealthBanner(
                    presentation: callStatusPresentation,
                    topInset: belowNavigationInset,
                    onHeightChange: { height in
                        guard abs(healthBannerHeight - height) > 0.5 else { return }
                        healthBannerHeight = height
                    }
                )
                .zIndex(20)
            }
        }
        // Fixed to the stable window-derived size so controls stay anchored regardless of
        // any transient GeometryReader size glitch.
        .frame(width: containerSize.width, height: containerSize.height)
        // 举手入口已下掉，注释保留逻辑
        // .onReceive(RoomDataManager.shared.$hasRaiseHands) { hasRaiseHands = $0 }
        .onReceive(RoomDataManager.shared.$localRaiseHand) { localRaiseHand = $0 }
    }

    private func toggleChromeControlsIfNeeded(isPortrait: Bool) {
        guard isPortrait else {
            return
        }
        guard roomCtx.currentCall.callType != .private else {
            return
        }

        let now = CACurrentMediaTime()
        guard now - lastChromeToggleTime >= 0.45 else {
            return
        }

        lastChromeToggleTime = now
        let nextValue = !viewModel.showControls
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.showControls = nextValue
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

    private func switchCamera() {
        guard let track = roomCtx.room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
              let cameraCapturer = track.capturer as? CameraCapturer else {
            return
        }
        Task {
            try await cameraCapturer.switchCameraPosition()
        }
    }
}

private struct RoomChromeControlsView: View {
    @ObservedObject var viewModel: ControlBarViewModel
    @ObservedObject var currentCall: DTLiveKitCallModel
    let presentation: CallStatusPresentation

    let containerSize: CGSize
    let safeAreaTop: CGFloat
    let toolbarBottomPadding: CGFloat
    @Binding var cameraRotateItemHidden: Bool
    @Binding var isGroupMembers: Bool
    @Binding var localRaiseHand: Bool
    let leftItemAction: () -> Void
    let cameraRotateAction: () -> Void
    let moreClickAction: () -> Void

    var body: some View {
        let showControls = viewModel.showControls

        ZStack {
            VStack(spacing: 0) {
                CallNavigationView(
                    currentCall: currentCall,
                    cameraRotateItemHidden: $cameraRotateItemHidden,
                    presentation: presentation,
                    leftItemAction: leftItemAction,
                    cameraRotateAction: cameraRotateAction
                )
                .padding(.top, safeAreaTop)

                Spacer(minLength: 0)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .opacity(showControls ? 1 : 0)
            .allowsHitTesting(showControls)
            .animation(.easeInOut(duration: 0.2), value: showControls)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                BottomToolbarView(
                    isScreenSharing: false,
                    containerSize: containerSize,
                    cameraPublishHandler: { isCameraEnabled in
                        cameraRotateItemHidden = !isCameraEnabled
                    },
                    barClickHandler: {
                        viewModel.showControls = true
                    },
                    moreClickHandler: moreClickAction,
                    isGroupMembers: $isGroupMembers,
                    localRaiseHand: $localRaiseHand
                )
                .padding(.bottom, toolbarBottomPadding)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .opacity(showControls ? 1 : 0)
            .allowsHitTesting(showControls)
            .animation(.easeInOut(duration: 0.2), value: showControls)
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }
}

struct CallContentView: View {
    @ObservedObject var currentCall: DTLiveKitCallModel
    let containerSize: CGSize
    let contentTopInset: CGFloat
    let contentBottomInset: CGFloat
    /// Top edge for 1v1 content that has to sit below the navigation row.
    let belowNavigationInset: CGFloat
    /// Default floating-preview top edge after clearing the rendered banner plus an 8pt gap.
    let previewTopInset: CGFloat
    var bulletReservedInset: CGFloat = 0
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var appCtx: LiveKitContext

    var body: some View {
        let currentCall = roomCtx.currentCall

        // Background lives in the same branch as the layout: splitting the two let a 1on1
        // call upgraded to instant keep the 1on1 background behind the meeting grid, making
        // the tiles indistinguishable from it.
        ZStack {
            if currentCall.callType == .private {
                Color.dtBackground.ignoresSafeArea()

                if currentCall.isCaller && currentCall.callState != .answering {
                    CallerWaitingView(alertTopInset: belowNavigationInset)
                } else {
                    Room1on1ContentView(previewTopInset: previewTopInset)
                }
            } else {
                Color(Theme.dark.bgelevateColor).ignoresSafeArea()

                RoomView(
                    containerSize: containerSize,
                    contentTopInset: contentTopInset,
                    contentBottomInset: contentBottomInset,
                    bulletReservedInset: bulletReservedInset
                )
            }
        }
    }
}

struct CallerWaitingView: View {
    /// Where the timeout banner starts, so it sits below the navigation row instead of on top of
    /// the call status. Kept independent of `showControls` so the banner never jumps.
    let alertTopInset: CGFloat

    @EnvironmentObject var roomCtx: RoomContext
    @ObservedObject var currentCall = DTMeetingManager.shared.currentCall

    // 15秒超时逻辑
    @State private var callingStartTime: Date?
    @State private var callingTimer: Timer?
    @State private var showTimeoutAlert: Bool = false

    // Tips 气泡相关
    @State private var showTipsBubble = false
    
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
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(rgbHex: 0x2B3139))
                .cornerRadius(8)
                .overlay {
                    GeometryReader { geometry in
                        if showTipsBubble {
                            CallerWaitingTipsBubbleView(
                                text: Localized("CRITICAL_ALERT_CONFIRM_TIPS_MESSAGE")
                            )
                            .offset(
                                x: max(0, geometry.size.width - 228),
                                y: geometry.size.height + 4
                            )
                            .transition(.opacity)
                            .allowsHitTesting(false)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .shadow(radius: 2)
                .padding(.top, alertTopInset)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showTimeoutAlert)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @ObservedObject var viewModel: ControlBarViewModel
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
        let showControls = viewModel.showControls

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

            if showQuickPanel, showControls {
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

            DTBulletChatControlViewRepresentable(
                showQuickPanel: $showQuickPanel,
                onClickInput: {
                    viewModel.showControls = true
                }
            )
                .frame(height: controlViewHeight)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .opacity(showControls ? 1 : 0)
                .allowsHitTesting(showControls)
                .animation(.easeInOut(duration: 0.2), value: showControls)
        }
        .onChange(of: viewModel.showControls) { showControls in
            if !showControls {
                showQuickPanel = false
            }
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

    var body: some View {
        let bubbleMaxWidth: CGFloat = 220

        VStack(spacing: -2) {
            HStack(spacing: 0) {
                Spacer()

                CallerWaitingTriangleShape()
                    .fill(Color(hex: 0x5E6673))
                    .frame(width: 14, height: 8)
            }
            .frame(width: bubbleMaxWidth)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: bubbleMaxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(hex: 0x5E6673))
                .cornerRadius(8)
        }
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
