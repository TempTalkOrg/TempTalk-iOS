
import LiveKit
import SwiftUI

// Attaches RoomContext and Room to the environment
struct RoomContextView: View {
    @EnvironmentObject var appCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext
    
    @StateObject private var currentCall = DTMeetingManager.shared.currentCall
    @StateObject private var dataManager = RoomDataManager.shared
    
    @State private var isRightItemHidden: Bool = true
    @State private var isGroupMembers: Bool = false
    @State private var showQuickPanel = false
    @State private var isPopupPresented = false
    
    @State private var delayTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // 背景色
            backgroundView
            
            // 主内容
            CallContentView(currentCall: currentCall)
                .environmentObject(appCtx)
                .environmentObject(roomCtx)

            // 弹幕和控制层
            BulletOverlayView(
                showQuickPanel: $showQuickPanel,
                hasRaiseHand: $dataManager.hasRaiseHands
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
                localRaiseHand: $dataManager.localRaiseHand
            )
            .environmentObject(appCtx)
            .environmentObject(roomCtx)
            .environmentObject(roomCtx.room)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 60)
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            delayTask = Task {
                // 检查启动的视频分享
                if  DTMeetingManager.shared.isFromCallkit && needLayoutTopVCScreenShare() {
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
    @StateObject var currentCall = DTMeetingManager.shared.currentCall
    
    // 15秒超时逻辑
    @State private var callingStartTime: Date?
    @State private var callingTimer: Timer?
    @State private var showTimeoutAlert: Bool = false
    
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
                    Button(action: sendTimeoutMessage) {
                        HStack(spacing: 8) {
                            Image("call_calling_critical")
                            Text(Localized("MEETING_CRITICAL_ALERT_TIPS"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(rgbHex: 0x2B3139))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                    }
                    .padding(.top, 45)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showTimeoutAlert)
                }
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
    }
    
    private func sendTimeoutMessage() {
        Task {
            await DTMeetingManager.shared.sendCriticalAlertWithBarrage(Localized("MEETING_CRITICAL_ALERT_DANMU"))
        }
        // 关闭提示
        showTimeoutAlert = false
    }
}

struct BulletOverlayView: View {
    @Binding var showQuickPanel: Bool
    @Binding var hasRaiseHand: Bool

    var body: some View {
        let quickMessagePanelWidth: CGFloat = 270

        ZStack {
            
            let paddingBottom: CGFloat = hasRaiseHand ? 90 + 36 + 10 : 90
            let paddingLeading: CGFloat = 30
            let paddingOverlayLeading: CGFloat = 45
            let controlViewHeight: CGFloat = 36
            let paddingMargin: CGFloat = 10
            
            DTBulletChatViewRepresentable()
                .frame(width: min(screenWidth, screenHeight))
                .padding(.leading, paddingLeading)
                .padding(.bottom, paddingBottom + paddingMargin * 0.5 + controlViewHeight)
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
                QuickMessagePanelUIKitWrapper(
                    messages: DTMeetingManager.shared.sampleBulletRtmCalls()
                ) { message in
                    Task {
                        await DTMeetingManager.shared.sendDanmu(message)
                        showQuickPanel = false
                    }
                }
                .frame(width: quickMessagePanelWidth, height: 270)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, paddingBottom + paddingMargin + controlViewHeight)
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
                    .frame(width: DTMeetingManager.shared.calculateRaiseHandsWidth())
                    .padding(.leading, paddingOverlayLeading)
                    .padding(.bottom, paddingBottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(hasRaiseHand)
            }

            DTBulletChatControlViewRepresentable(showQuickPanel: $showQuickPanel)
                .frame(width: 172, height: controlViewHeight)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .allowsHitTesting(true)
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
