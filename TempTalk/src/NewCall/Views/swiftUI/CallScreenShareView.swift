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
    @State private var screenShareUnmuteCounter: Int = 0
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
    @State private var quickPanelHeight: CGFloat = 170

    public var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size

            ZStack {
                screenShareContentView(geometry: geometry)

                topBarView
                    .opacity(viewModel.showControls ? 1 : 0)
                    .allowsHitTesting(viewModel.showControls)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.showControls)

                // 举手入口已下掉，注释保留逻辑
                // 右上角”举手”按钮
                // if roomDataManager.hasRaiseHands {
                //     raiseHandButtonView
                // }

                bulletChatOverlay(containerSize: containerSize)

                bottomToolbarView(containerSize: containerSize)
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
                        },
                        containerSize: containerSize
                    )
                    .transition(.move(edge: .bottom))
                    .animation(.easeOut(duration: 0.3), value: isPopupPresented)
                    .allowsHitTesting(isPopupPresented)
                }

                if showCriticalAlertConfirm {
                    CriticalAlertConfirmBottomPopupView(
                        onDismiss: {
                            showCriticalAlertConfirm = false
                        },
                        invitedUserIds: Array(DTMeetingManager.shared.currentCall.invitedCriticalAlertUsers),
                        callType: DTMeetingManager.shared.currentCall.callType,
                        containerSize: containerSize
                    )
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.3), value: showCriticalAlertConfirm)
                }
                
                memberListOverlay(containerSize: containerSize)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .onAppear {
                DTMeetingManager.shared.setCameraRotation(orientation: .landscapeRight)
                viewModel.hiddenTopBottomBar()
            }
            .onDisappear {
                DTMeetingManager.shared.setCameraRotation(orientation: .portrait)
                roomCtx.inviteVC?.dismiss(animated: false)
                roomCtx.inviteVC = nil
                cleanUpResourcesSync()
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
        let insets = OWSWindowManager.shared().callViewWindow.safeAreaInsets
        let safeWidth = screenSize.width - insets.left - insets.right

        return ZStack {
            if let publication = roomCtx.screenSharePublication,
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
                    .id("\(track.sid?.stringValue ?? "")-\(screenShareUnmuteCounter)-\(roomCtx.videoRefreshToken)")
                    .frame(
                        width: safeWidth,
                        height: screenSize.height,
                        alignment: .center
                    )
                    .padding(.leading, insets.left)
                    .padding(.trailing, insets.right)
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
                .onChange(of: publication.isMuted) { isMuted in
                    if !isMuted {
                        screenShareUnmuteCounter += 1
                    }
                }
            }

            if showPlaceholder || roomCtx.isRoomReconnecting || roomCtx.screenSharePublication?.isMuted == true {
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
        .onChange(of: roomCtx.videoRefreshToken) { _ in
            isRendering = false
        }
    }

    private var waitingForScreenPlaceholder: some View {
        VStack(spacing: 8) {
            Image("call_screen_share")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("Waiting for screen…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dtBackground.ignoresSafeArea())
        .allowsHitTesting(false)
    }
    
    
    private var topBarView: some View {
        let insets = OWSWindowManager.shared().callViewWindow.safeAreaInsets
        let barHeight = 62 + insets.top
        return ZStack {
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
                .offset(y: insets.top < 10 ? 10 - insets.top : 0)
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
                .offset(x: -36)

                Spacer()
            }
            .padding(.top, insets.top)
            .padding(.leading, 43)
            .padding(.trailing, insets.right)
        }
        .frame(height: barHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    
    private var raiseHandButtonView: some View {
        let controlBottom: CGFloat = 30
        let controlHeight: CGFloat = 36
        let bottomPadding = viewModel.showControls
            ? controlBottom + controlHeight + 10
            : controlBottom

        return HandsControlViewRepresentable {
            isGroupMembers.toggle()
        }
        .frame(width: raiseHandsWidth, height: 36)
        .padding(.bottom, bottomPadding)
        .padding(.leading, 45)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showControls)
    }
    
    
    private func bulletChatOverlay(containerSize: CGSize) -> some View {
        let isLandscape = containerSize.width > containerSize.height
        let bulletChatWidth = isLandscape ? containerSize.width * 0.5 : containerSize.width

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

            DTEmojiFlyingViewRepresentable(containerSize: CGSize(width: bulletChatWidth, height: 0), isLandscape: isLandscape)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)

            if showQuickPanel, viewModel.showControls {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { showQuickPanel = false }
                    .allowsHitTesting(viewModel.showControls)

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
                .padding(.leading, 30)
                .padding(.bottom, 75)
                .allowsHitTesting(showQuickPanel && viewModel.showControls)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 15)
    }
    
    
    @ViewBuilder
    private func bottomToolbarView(containerSize: CGSize) -> some View {
        let bottomInset: CGFloat = OWSWindowManager.shared().callViewWindow.safeAreaInsets.bottom
        if let appCtx {
            BottomToolbarView(
                isScreenSharing: true,
                containerSize: containerSize,
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
            .environmentObject(appCtx)
            .environment(\.colorScheme, .dark)
            .padding(.bottom, max(20, bottomInset + 10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
    
    
    @ViewBuilder
    private func memberListOverlay(containerSize: CGSize) -> some View {
        if isGroupMembers {
            MemberContainerView(
                onCancel: { isGroupMembers = false },
                onAddMember: { roomCtx.presentInviteView() },
                containerSize: containerSize
            )
            .frame(width: 200)
            .frame(maxHeight: .infinity, alignment: .trailing)
            .background(Color(rgbHex: 0x2B3139))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .transition(.move(edge: .trailing))
            .animation(.easeOut(duration: 0.2), value: isGroupMembers)
        }
    }
    
    
    private func cleanUpResourcesSync() {
        debounceTask?.cancel()
        debounceTask = nil
        isRendering = false
        showQuickPanel = false
        isGroupMembers = false
        RoomDataManager.shared.onPipUpdate = nil
        // 提前捕获 track 引用，避免在 async 中访问可能已析构的 roomCtx
        if let track = roomCtx.screenSharePublication?.track as? VideoTrack {
            Task { [weak track] in
                try? await track?.stop()
            }
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

        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()
        if DTMeetingManager.shared.roomContext?.isShareViewController(topVC) == true {
            topVC.view.subviews.filter { $0 is SpeakerFloatingContainer }.forEach { $0.removeFromSuperview() }

            let container = SpeakerFloatingContainer()
            container.addToSuperview(topVC.view)

            let speakerFloating = SpeakerFloatingUIView()
            speakerFloating.addToContainer(container, in: topVC)
        }

        context.coordinator.observeZoomChange(for: scrollView)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let newContent = content
        DispatchQueue.main.async {
            context.coordinator.hostingController?.rootView = newContent
        }
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
            let hc = hostingController
            hostingController = nil
            if Thread.isMainThread {
                hc?.view.removeFromSuperview()
                hc?.removeFromParent()
            } else {
                DispatchQueue.main.async {
                    hc?.view.removeFromSuperview()
                    hc?.removeFromParent()
                }
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
