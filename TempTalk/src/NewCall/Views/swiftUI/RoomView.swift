/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LiveKit
import SFSafeSymbols
import SwiftUI

#if !os(macOS) && !os(tvOS)
    let adaptiveMin = 170.0
    let toolbarPlacement: ToolbarItemPlacement = .bottomBar
#else
    let adaptiveMin = 300.0
    let toolbarPlacement: ToolbarItemPlacement = .primaryAction
#endif

extension CIImage {
    // helper to create a `CIImage` for both platforms
    convenience init(named name: String) {
        #if !os(macOS)
            self.init(cgImage: UIImage(named: name)!.cgImage!)
        #else
            self.init(data: NSImage(named: name)!.tiffRepresentation!)!
        #endif
    }
}

#if os(macOS)
    // keeps weak reference to NSWindow
    class WindowAccess: ObservableObject {
        private weak var window: NSWindow?

        deinit {
            // reset changed properties
            DispatchQueue.main.async { [weak window] in
                window?.level = .normal
            }
        }

        @Published public var pinned: Bool = false {
            didSet {
                guard oldValue != pinned else { return }
                level = pinned ? .floating : .normal
            }
        }

        private var level: NSWindow.Level {
            get { window?.level ?? .normal }
            set {
                Task { @MainActor in
                    window?.level = newValue
                    objectWillChange.send()
                }
            }
        }

        public func set(window: NSWindow?) {
            self.window = window
            Task { @MainActor in
                objectWillChange.send()
            }
        }
    }
#endif

struct RoomView: View {

    let logTag: String = "[newcall]"
    /// Stable full-screen size from RoomContextView.callContainerSize(); threaded into the grid.
    let containerSize: CGSize
    let contentTopInset: CGFloat
    let contentBottomInset: CGFloat

    @EnvironmentObject var liveKitCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room
    
    @State var isCameraPublishingBusy = false
    @State var isMicrophonePublishingBusy = false
    @State var isScreenSharePublishingBusy = false
    @State var isARCameraPublishingBusy = false

    @State private var screenPickerPresented = false
    @State private var publishOptionsPickerPresented = false

    @State private var cameraPublishOptions = VideoPublishOptions()

    @State private var showConnectionTime = true
    @State private var canSwitchCameraPosition = false

    var body: some View {
        ZStack {
            if case .connecting = room.connectionState {
                Text("Connecting...")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Render live participants for connected AND reconnecting states. The SDK keeps the
                // roster across reconnect (Route B); VideoView freezes the last frame. No snapshot /
                // avatar-only reconnect grid.
                let participants = DTMeetingManager.shared.sortedMeetingParticipants()
                ParticipantLayout(
                    participants,
                    spacing: 8,
                    stableWidth: containerSize.width,
                    topPadding: contentTopInset + 8,
                    bottomPadding: contentBottomInset,
                    id: { participant in
                        participant.sid?.stringValue ?? participant.identity?.stringValue ?? participant.id
                    }
                ) { participant in
                    ParticipantView(participant: participant, videoViewMode: .fill)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityIdentifier(DTCallAccessibilityID.root)
    }
}

struct ParticipantLayout<Data: RandomAccessCollection, Content: View>: View {
    private let items: [(id: String, view: AnyView)]
    let spacing: CGFloat
    /// Stable container width provided by the caller (RoomContextView.callContainerSize()).
    /// Used as a floor so a transient/stale inner GeometryReader width at call setup can't
    /// collapse tiles into a tiny top-left square. Single source of truth stays in the caller.
    let stableWidth: CGFloat

    let edgeSpacing: CGFloat = 20.0
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    init(
        _ data: Data,
        spacing: CGFloat,
        stableWidth: CGFloat,
        topPadding: CGFloat = 8.0,
        bottomPadding: CGFloat = 64.0,
        id idProvider: (Data.Element) -> String,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.stableWidth = stableWidth
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.items = data.map { element in
            (id: idProvider(element), view: AnyView(content(element)))
        }
    }
    
    func grid(axis: Axis) -> some View {
        GeometryReader { proxy in
            // Normally trust the live layout width so tile sizing/margins are unchanged. The
            // inner GeometryReader can transiently report a small/stale width while the call
            // window frame is still settling at call setup, which would collapse every tile into
            // a tiny square pinned top-left; floor it by the caller-provided stable width so only
            // the degenerate case is corrected.
            let width = max(proxy.size.width, stableWidth)
            let availableWidth = max(0, width - edgeSpacing * 2)
            let extraMargin: CGFloat = 12
            let itemSize = floor((availableWidth - spacing - extraMargin) / 2)
            ScrollView([axis == .vertical ? .vertical : .horizontal]) {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(itemSize), spacing: spacing, alignment: .center),
                        GridItem(.fixed(itemSize), spacing: spacing, alignment: .center)
                    ],
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(items, id: \.id) { item in
                        item.view
                            .frame(width: itemSize, height: itemSize)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, edgeSpacing)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
        }
    }
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            grid(axis: .vertical)
        }
    }
}

extension GeometryProxy {
    public var isTall: Bool {
        size.height > size.width
    }

    var isWide: Bool {
        size.width > size.height
    }
}
