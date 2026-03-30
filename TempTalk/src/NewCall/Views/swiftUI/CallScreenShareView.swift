//
//  CallScreenShareView.swift
//  TempTalk
//
//  Created by Ethan on 18/02/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import LiveKit
import SFSafeSymbols
import SnapKit

struct CallScreenShareView: View {
    
    @EnvironmentObject var roomCtx: RoomContext
    @State private var isRendering = false
    @State private var isGroupMembers: Bool = false
    // 展示快速点击的弹幕
    @State private var showQuickPanel = false
    @State private var showPlaceholder = true
    // 用于防抖的任务
    @State private var debounceTask: Task<Void, Never>?

    @ObservedObject private var timerManager = TimerDataManager.shared
    @ObservedObject private var roomDataManager = RoomDataManager.shared
    
    var appCtx: LiveKitContext? {
        DTMeetingManager.shared.appContext
    }
    
    var minimizeAction: () -> Void
    
    // 控制视图隐藏和消失
    @StateObject private var viewModel = ControlBarViewModel()
    
    @State private var isPopupPresented = false
    @State private var showCriticalAlertConfirm = false
    @State private var raiseHandsWidth: CGFloat = DTMeetingManager.shared.calculateRaiseHandsWidth()

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 屏幕共享内容
                screenShareContentView(geometry: geometry)

                // 顶部控制栏
                topBarView
                    .opacity(viewModel.showControls ? 1 : 0)
                    .allowsHitTesting(viewModel.showControls)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showControls)

                // 右上角”举手”按钮
                if roomDataManager.hasRaiseHands {
                    raiseHandButtonView
                }

                // 左下角弹幕 & 控制栏 & 快捷弹幕面板
                bulletChatOverlay

                // 底部工具栏
                bottomToolbarView(geometry: geometry)
                    .opacity(viewModel.showControls ? 1 : 0)
                    .allowsHitTesting(viewModel.showControls)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showControls)
                
                if isPopupPresented {
                    BottomPopupView(
                        onDismiss: {
                            isPopupPresented = false
                        },
                        onShowCriticalAlertConfirm: {
                            showCriticalAlertConfirm = true
                        }
                    )
                    .transition(.move(edge: .bottom))
                    .animation(.easeOut(duration: 0.3), value: isPopupPresented)
                    .allowsHitTesting(isPopupPresented)
                }

                // Critical Alert 确认弹窗
                if showCriticalAlertConfirm {
                    CriticalAlertConfirmBottomPopupView(
                        onDismiss: {
                            showCriticalAlertConfirm = false
                        },
                        invitedUserIds: Array(DTMeetingManager.shared.currentCall.invitedCriticalAlertUsers),
                        callType: DTMeetingManager.shared.currentCall.callType
                    )
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.3), value: showCriticalAlertConfirm)
                }
                
                // 右侧滑出成员列表
                memberListOverlay
            }
            .onAppear {
                DTMeetingManager.shared.setCameraRotation(orientation: .landscapeRight)
                viewModel.hiddenTopBottomBar()
            }
            .onDisappear {
                DTMeetingManager.shared.setCameraRotation(orientation: .portrait)
                // 清理邀请好友页面（如果存在）
                roomCtx.inviteVC?.dismiss(animated: false)
                roomCtx.inviteVC = nil
                Task { await cleanUpResources() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                handleAppDidBecomeActive()
            }
            .onReceive(RoomDataManager.shared.raiseHandsPublisher) { _ in
                raiseHandsWidth = DTMeetingManager.shared.calculateRaiseHandsWidth()
            }
        }
        .ignoresSafeArea()
    }
    
    private func handleAppDidBecomeActive() {
        Logger.info("[newcall] screen share view did become active, refreshing reference")
        roomCtx.refreshScreenShareReference()
    }
    
    private func screenShareContentView(geometry: GeometryProxy) -> some View {
        let screenSize = geometry.size
        let maxDimension = max(screenSize.width, screenSize.height)
        let minDimension = min(screenSize.width, screenSize.height)

        return ZStack {
            if let publication = roomCtx.screenSharePublication,
               !publication.isMuted,
               let track = publication.track as? VideoTrack
            {
                ZoomableScrollView {
                    SwiftUIVideoView(
                        track,
                        layoutMode: .fit,
                        renderMode: .sampleBuffer,
                        isAutoPauseResumeSampleBuffer: true,
                        pinchToZoomOptions: .resetOnRelease,
                        didRenderFirstFrame: $isRendering
                    )
                    .id(track.sid)
                    .frame(
                        width: maxDimension - 200,
                        height: minDimension,
                        alignment: .center
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: isRendering) { rendering in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            Logger.info("[newcall] video showPlaceholder status \(!isRendering)")
                            showPlaceholder = !isRendering
                        }
                    }
                }
            }
            
            if showPlaceholder {
                waitingForScreenPlaceholder
                        .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.showControls.toggle()
            if viewModel.showControls {
                viewModel.hiddenTopBottomBar()
            }
        }
    }
    
    // 占位图视图
    private var waitingForScreenPlaceholder: some View {
        ZStack {
            Color.dtBackground.ignoresSafeArea()
            
            VStack(spacing: 8) {
                Image("call_screen_share")
                    .font(.system(size: 20))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("Waiting for screen…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .allowsHitTesting(false)
    }
    
    
    private var topBarView: some View {
        VStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0.4), Color.clear]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                HStack {
                    Button(action: minimizeAction) {
                        Image("ic_call_mini")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    Spacer()

                    HStack(spacing: 10) {
                        if roomCtx.currentCall.callType != .private {
                            Text("\(roomCtx.currentCall.roomName)")
                                .font(.system(size: 16, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        if let duration = timerManager.duration, duration > 0 {
                            let stringDuration = DTLiveKitCallModel.stringDuration(duration)
                            Text(stringDuration)
                        } else if roomCtx.currentCall.callType == .private {
                            Text("connecting...")
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .offset(x: -30, y: -10)

                    Spacer()
                }
                .padding(.leading, 16)
            }
            .frame(height: 62)
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
    
    
    private var raiseHandButtonView: some View {
        VStack {
            HStack {
                Spacer()
                HandsControlViewRepresentable {
                    isGroupMembers.toggle()
                }
                .frame(width: raiseHandsWidth)
                .frame(height: 36)
            }
            .padding(.top, 10)
            .padding(.trailing, 15)
            Spacer()
        }
    }
    
    
    private var bulletChatOverlay: some View {
        // 根据屏幕方向动态计算弹幕宽度
        let currentScreenSize = UIScreen.main.bounds.size
        let isLandscape = currentScreenSize.width > currentScreenSize.height
        let bulletChatWidth = isLandscape ? currentScreenSize.width * 0.5 : currentScreenSize.width

        return ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                DTBulletChatViewRepresentable()
                    .frame(width: bulletChatWidth, height: 320)
                    .padding(.top, 20)
                    .padding(.leading, -15)
                    .allowsHitTesting(false)

                DTBulletChatControlViewRepresentable(
                    showQuickPanel: $showQuickPanel,
                    onClickInput: {
                        viewModel.userPressedButton()
                    }
                )
                .frame(height: 36)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.bottom, 30)
                .padding(.leading, 30)
                .opacity(viewModel.showControls ? 1 : 0)
                .allowsHitTesting(viewModel.showControls)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DTEmojiFlyingViewRepresentable(containerSize: CGSize(width: bulletChatWidth, height: 0))
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            if showQuickPanel, viewModel.showControls {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showQuickPanel = false
                    }
                    .allowsHitTesting(viewModel.showControls)

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
                .padding(.leading, 30)
                .padding(.bottom, 75)
                .allowsHitTesting(showQuickPanel && viewModel.showControls)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 15) // 整体向右偏移15px，避开灵动岛和摄像头
    }
    
    
    private func bottomToolbarView(geometry: GeometryProxy) -> some View {
        let bottomInset: CGFloat = OWSWindowManager.shared().callViewWindow.safeAreaInsets.bottom
        return BottomToolbarView(
            isScreenSharing: true,
            cameraPublishHandler: { _ in },
            barClickHandler: {
                viewModel.userPressedButton()
            },
            moreClickHandler: {
                isPopupPresented = true
            },
            isGroupMembers: $isGroupMembers,
            localRaiseHand: $roomDataManager.localRaiseHand
        )
        .environmentObject(appCtx!)
        .environmentObject(roomCtx)
        .environmentObject(roomCtx.room)
        .environment(\.colorScheme, .dark)
        .padding(.bottom, max(20, bottomInset + 10))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
    
    
    private var memberListOverlay: some View {
        HStack {
            Spacer()
            if isGroupMembers {
                VStack {
                    MemberContainerView(
                        onCancel: { isGroupMembers = false },
                        onAddMember: { roomCtx.presentInviteView() }
                    )
                    .environmentObject(roomCtx)
                }
                .frame(width: 200)
                .frame(maxHeight: .infinity)
                .background(Color(rgbHex: 0x2B3139))
                .transition(.move(edge: .trailing))
                .animation(.easeOut(duration: 0.2), value: isGroupMembers)
            }
        }
    }
    
    
    private func cleanUpResources() async {
        debounceTask?.cancel()
        debounceTask = nil
        isRendering = false
        showQuickPanel = false
        isGroupMembers = false
        RoomDataManager.shared.onPipUpdate = nil
        if let track = roomCtx.screenSharePublication?.track as? VideoTrack {
            try? await track.stop()
        }
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 8.0
        scrollView.zoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let hostingController = UIHostingController(rootView: content)
        if #available(iOS 16.4, *) {
            hostingController.safeAreaRegions = []
        }
        context.coordinator.hostingController = hostingController
        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostedView)

        hostedView.snp.makeConstraints { make in
            make.edges.equalTo(scrollView.contentLayoutGuide)
            make.width.equalTo(scrollView.frameLayoutGuide)
            make.height.equalTo(scrollView.frameLayoutGuide)
        }

        let pipView = DTPIPView()
        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()
        if NSStringFromClass(type(of: topVC)).contains("DTHostingController"), NSStringFromClass(type(of: topVC)).contains("CallScreenShareView") {
            pipView.addToSuperview(topVC.view)
            pipView.updatePipViewCountDown()
            if let shareItem = DTMeetingManager.shared.fetchSharingItem() {
                pipView.setNewSpeakingItem(shareItem)
            }
            RoomDataManager.shared.onPipUpdate = { [weak pipView] in
                DispatchQueue.main.async {
                    guard let pipView else { return }
                    if let speakingItem = DTMeetingManager.shared.fetchSpeakingItem() {
                        pipView.setNewSpeakingItem(speakingItem)
                    } else if let shareItem = DTMeetingManager.shared.fetchSharingItem() {
                        pipView.setNewSpeakingItem(shareItem)
                    }
                    if DTMeetingManager.shared.isPresentedShare() {
                        pipView.updatePipViewCountDown()
                    }
                }
            }
        }

        context.coordinator.observeZoomChange(for: scrollView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
        if context.coordinator.needsInitialLayout, uiView.bounds.size != .zero {
            context.coordinator.needsInitialLayout = false
            uiView.contentOffset = .zero
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var lastContentOffset: CGPoint = .zero
        var hostingController: UIHostingController<Content>?
        var needsInitialLayout = true
        private var zoomChangeObserver: NSObjectProtocol?

        deinit {
            if let observer = zoomChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func observeZoomChange(for scrollView: UIScrollView) {
            guard zoomChangeObserver == nil else { return }
            zoomChangeObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("CallShareZoomDidChange"),
                object: nil,
                queue: .main
            ) { [weak self, weak scrollView] _ in
                guard let self, let scrollView else { return }
                self.restoreZoomState(scrollView: scrollView)
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if scrollView.zoomScale < 1.0 {
                scrollView.zoomScale = 1.0
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
                lastContentOffset = scrollView.contentOffset
            }
        }

        func restoreZoomState(scrollView: UIScrollView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self else { return }
                scrollView.contentOffset = self.lastContentOffset
            }
        }
    }
}
