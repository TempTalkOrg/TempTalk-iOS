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
    
    @State private var cachedSnapshots: [ParticipantSnapshot] = []
    
    private func computeDisplayedSnapshots() -> [ParticipantSnapshot] {
        let currentSnapshots = DTMeetingManager.shared.sortedReconnectingParticipants()
        if !currentSnapshots.isEmpty {
            DispatchQueue.main.async {
                cachedSnapshots = currentSnapshots
            }
            return currentSnapshots
        } else {
            return cachedSnapshots
        }
    }

    var body: some View {
        ZStack {
            if case .connecting = room.connectionState {
                Text("Connecting...")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if case .connected = room.connectionState {
                let participants = DTMeetingManager.shared.sortedMeetingParticipants()
                ParticipantLayout(participants, spacing: 8, id: { participant in
                    participant.sid?.stringValue ?? participant.identity?.stringValue ?? participant.id
                }) { participant in
                    ParticipantView(participant: participant, videoViewMode: .fill)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 当新数据非空时更新缓存
                let displayedSnapshots: [ParticipantSnapshot] = computeDisplayedSnapshots()
                ParticipantLayout(displayedSnapshots, spacing: 8, id: { shot in
                    shot.id
                }) { shot in
                    ReconnectingParticipantView(snapshot: shot, videoViewMode: .fill)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct ParticipantLayout<Data: RandomAccessCollection, Content: View>: View {
    private let items: [(id: String, view: AnyView)]
    let spacing: CGFloat
    
    let edgeSpacing: CGFloat = 12.0
    let bottomPadding: CGFloat = 64.0
    let itemSize: CGFloat = (min(screenWidth, screenHeight) - 8 * 2) * 0.5 // 固定大小
    
    init(
        _ data: Data,
        spacing: CGFloat,
        id idProvider: (Data.Element) -> String,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.items = data.map { element in
            (id: idProvider(element), view: AnyView(content(element)))
        }
    }
    
    func grid(axis: Axis) -> some View {
        ScrollView([axis == .vertical ? .vertical : .horizontal]) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(itemSize), spacing: spacing), count: 2),
                alignment: .center,
                spacing: spacing
            ) {
                ForEach(items, id: \.id) { item in
                    item.view
                        .frame(width: itemSize, height: itemSize)
                        .cornerRadius(8)
                }
            }
            .padding(.leading, edgeSpacing)
            .padding(.top, spacing)
            .padding(.bottom, bottomPadding)
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
