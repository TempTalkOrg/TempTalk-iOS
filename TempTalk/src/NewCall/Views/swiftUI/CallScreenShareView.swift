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
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isGroupMembers: Bool = false
    // 展示快速点击的弹幕
    @State private var showQuickPanel = false
    
    @StateObject private var timerManager = TimerDataManager.shared
    @StateObject private var roomDataManager = RoomDataManager.shared
    
    var appCtx: LiveKitContext? {
        DTMeetingManager.shared.appContext
    }
    
    var minimizeAction: () -> Void
    
    // 控制视图隐藏和消失
    @StateObject private var viewModel = ControlBarViewModel()
    
    @State private var isPopupPresented = false

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 屏幕共享内容
                screenShareContentView(geometry: geometry)

                // 顶部控制栏
                if viewModel.showControls {
                    topBarView
                }

                // 右上角“举手”按钮
                if roomDataManager.hasRaiseHands {
                    raiseHandButtonView
                }

                // 左下角弹幕 & 控制栏 & 快捷弹幕面板
                bulletChatOverlay

                // 底部工具栏
                if viewModel.showControls {
                    bottomToolbarView
                }
                
                if isPopupPresented {
                    BottomPopupView {
                        isPopupPresented = false
                    }
                    .transition(.move(edge: .bottom))
                    .animation(.easeOut(duration: 0.3), value: isPopupPresented)
                    .allowsHitTesting(isPopupPresented)
                }
                
                // 右侧滑出成员列表
                memberListOverlay
            }
            .ignoresSafeArea()
            .onAppear {
                viewModel.hiddenTopBottomBar()
            }
            .onDisappear {
                Task { await cleanUpResources() }
            }
        }
    }
    
    private func screenShareContentView(geometry: GeometryProxy) -> some View {
        Group {
            if let publication = roomCtx.screenSharePublication,
               !publication.isMuted,
               let track = publication.track as? VideoTrack
            {
                ZoomableScrollView {
                    let notchOffset = geometry.safeAreaInsets.leading
                    
                    SwiftUIVideoView(
                        track,
                        layoutMode: .fit,
                        pinchToZoomOptions: .resetOnRelease,
                        isRendering: $isRendering
                    )
                    .frame(
                        maxWidth: max(screenWidth, screenHeight) - 200,
                        maxHeight: min(screenWidth, screenHeight),
                        alignment: .center
                    )
                    .offset(x: notchOffset > 0 ? -notchOffset : 0)
                }
                .ignoresSafeArea()
                .background(Color.dtBackground)
                .onTapGesture {
                    withAnimation {
                        viewModel.showControls.toggle()
                        if viewModel.showControls {
                            viewModel.hiddenTopBottomBar()
                        }
                    }
                }

                if !isRendering {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
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
                .frame(width: DTMeetingManager.shared.calculateRaiseHandsWidth())
                .frame(height: 36)
            }
            .padding(.top, 10)
            .padding(.trailing, 15)
            Spacer()
        }
    }
    
    
    private var bulletChatOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                DTBulletChatViewRepresentable()
                    .frame(width: min(screenWidth, screenHeight) + 150)
                    .padding(.top, 20)
                    .padding(.leading, -30)
                    .allowsHitTesting(false)
               
                if viewModel.showControls {
                    DTBulletChatControlViewRepresentable(
                        showQuickPanel: $showQuickPanel,
                        onClickInput: {
                            viewModel.userPressedButton()
                        }
                    )
                    .frame(width: 172, height: 36)
                    .padding(.bottom, 30)
                    .padding(.leading, 30)
                    .allowsHitTesting(viewModel.showControls)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)

            if showQuickPanel, viewModel.showControls {
                let messages = DTMeetingManager.shared.sampleBulletRtmCalls()
                QuickMessagePanelUIKitWrapper(messages: messages) { message in
                    Task {
                        await DTMeetingManager.shared.sendDanmu(message)
                        showQuickPanel = false
                    }
                }
                .frame(width: 270)
                .frame(height: 270)
                .padding(.leading, 30)
                .padding(.bottom, 75)
                .allowsHitTesting(showQuickPanel && viewModel.showControls)
            }
        }
    }
    
    
    private var bottomToolbarView: some View {
        VStack {
            Spacer()
            BottomToolbarView(
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
            .frame(
                maxWidth: min(screenWidth, screenHeight),
                maxHeight: .infinity,
                alignment: .bottom
            )
            .padding(.bottom, 20)
        }
        .animation(.easeInOut, value: viewModel.showControls)
    }
    
    
    private var memberListOverlay: some View {
        HStack {
            Spacer()
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
            .offset(x: isGroupMembers ? 0 : 200)
            .animation(.easeOut(duration: 0.2), value: isGroupMembers)
        }
    }
    
    
    private func cleanUpResources() async {
        isRendering = false
        showQuickPanel = false
        isGroupMembers = false
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
        scrollView.maximumZoomScale = 2.0
        scrollView.zoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .always
        
        // 创建 UIHostingController 以加载 SwiftUI 视图
        let hostedView = UIHostingController(rootView: content).view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostedView)

        hostedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.frameLayoutGuide.snp.width)
            make.height.equalTo(scrollView.frameLayoutGuide.snp.height)
        }
        
        let pipView = DTPIPView()
        let callWindow = OWSWindowManager.shared().callViewWindow
        let topVC = callWindow.findTopViewController()
        if NSStringFromClass(type(of: topVC)).contains("DTHostingController"), NSStringFromClass(type(of: topVC)).contains("CallScreenShareView"){
            pipView.addToSuperview(topVC.view)
            pipView.updatePipViewCountDown()
            if let shareItem = DTMeetingManager.shared.fetchSharingItem() {
                pipView.setNewSpeakingItem(shareItem)
            }
            RoomDataManager.shared.onPipUpdate = {
                DispatchQueue.main.async {
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
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        NotificationCenter.default.addObserver(forName: Notification.Name("CallShareZoomDidChange"), object: nil, queue: .main) { notification in
            context.coordinator.restoreZoomState(scrollView: uiView)
        }
        
        if let hosting = uiView.subviews.first {
            hosting.setNeedsLayout()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var lastContentOffset: CGPoint = .zero  // 记录 contentOffset
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
        
        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            if let hostedView = scrollView.subviews.first {
                hostedView.frame = CGRect(origin: .zero, size: scrollView.bounds.size)
            }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                scrollView.contentOffset = self.lastContentOffset
            }
        }
    }
}
