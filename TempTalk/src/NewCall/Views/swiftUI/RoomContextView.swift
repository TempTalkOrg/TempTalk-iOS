
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
            AvatarImageViewRepresentable(recipientId: recipientId)
                .frame(width: 120, height: 120)
            Text(name)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 200) // 用 padding 来替代 .position
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
            
            if showQuickPanel {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showQuickPanel = false
                    }
                
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
            }
            
            if hasRaiseHand {
                HandsControlViewRepresentable()
                    .frame(height: controlViewHeight)
                    .frame(width: DTMeetingManager.shared.calculateRaiseHandsWidth())
                    .padding(.leading, paddingOverlayLeading)
                    .padding(.bottom, paddingBottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            DTBulletChatControlViewRepresentable(showQuickPanel: $showQuickPanel)
                .frame(width: 172, height: controlViewHeight)
                .padding(.leading, paddingOverlayLeading)
                .padding(.bottom, 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
