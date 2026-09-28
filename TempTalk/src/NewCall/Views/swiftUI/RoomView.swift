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
import QuartzCore
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

struct MeetingGridLayout: Equatable {
    enum Mode: Equatable {
        case legacy
        case fixed
        case gallery
    }

    let mode: Mode
    let columns: Int
    let itemSize: CGSize
    let scrollable: Bool
    let visibleWindow: Int
    let centersLastItem: Bool
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let verticalContentPadding: CGFloat

    static func resolve(
        count: Int,
        containerSize: CGSize,
        isLandscape: Bool,
        topInset: CGFloat,
        bottomInset: CGFloat,
        bulletReservedInset: CGFloat = 0,
        spacing: CGFloat = 8,
        edgeSpacing: CGFloat = 12
    ) -> MeetingGridLayout {
        let safeCount = max(count, 0)
        let width = max(containerSize.width, 0)
        let height = max(containerSize.height, 0)
        let availableWidth = max(0, width - edgeSpacing * 2)
        let availableHeight = max(0, height - topInset - bottomInset)

        if safeCount == 1 {
            let fullWidth = max(width, 0)
            let fullHeight = max(height, 0)
            return MeetingGridLayout(
                mode: .fixed,
                columns: 1,
                itemSize: CGSize(width: fullWidth, height: fullHeight),
                scrollable: false,
                visibleWindow: 1,
                centersLastItem: false,
                horizontalPadding: 0,
                topPadding: 0,
                bottomPadding: 0,
                verticalContentPadding: 0
            )
        }

        if safeCount == 2 {
            let rows = CGFloat(max(safeCount, 1))
            let itemHeight = floor((availableHeight - spacing * max(rows - 1, 0)) / rows)
            return MeetingGridLayout(
                mode: .fixed,
                columns: 1,
                itemSize: CGSize(width: availableWidth, height: max(itemHeight, 0)),
                scrollable: false,
                visibleWindow: safeCount,
                centersLastItem: false,
                horizontalPadding: edgeSpacing,
                topPadding: topInset,
                bottomPadding: bottomInset,
                verticalContentPadding: 0
            )
        }

        guard safeCount > 2 else {
            return MeetingGridLayout(
                mode: .fixed,
                columns: 1,
                itemSize: .zero,
                scrollable: false,
                visibleWindow: 0,
                centersLastItem: false,
                horizontalPadding: edgeSpacing,
                topPadding: topInset,
                bottomPadding: bottomInset,
                verticalContentPadding: 0
            )
        }

        if safeCount == 3 {
            // Anchor the 3-up column to the toolbar top rather than the bullet/emoji control
            // above it, so it reclaims the space the bullet-avoidance inset would reserve.
            let bottomToToolbar = max(0, bottomInset - bulletReservedInset)
            let availableToToolbar = max(0, height - topInset - bottomToToolbar)
            let rowHeight = floor((availableToToolbar - spacing * 2) / 3)
            let side = max(0, min(availableWidth, rowHeight))
            let contentHeight = side * 3 + spacing * 2
            let letterbox = max(0, (availableToToolbar - contentHeight) / 2)
            return MeetingGridLayout(
                mode: .fixed,
                columns: 1,
                itemSize: CGSize(width: side, height: side),
                scrollable: false,
                visibleWindow: 3,
                centersLastItem: false,
                horizontalPadding: edgeSpacing,
                topPadding: topInset,
                bottomPadding: bottomToToolbar,
                verticalContentPadding: letterbox
            )
        }

        let columns = 2
        let itemWidth = max(0, floor((availableWidth - spacing) / CGFloat(columns)))

        // 4/5/6 all use square (1:1) tiles. Tile size is bounded by the inset-aware available
        // height so tiles never overflow, but the block is centered on the FULL screen height
        // (ignoring the bottom toolbar) so it sits at the visual center instead of being pushed
        // up by the large bottom inset. max(topInset,…) keeps it clear of the top nav bar.
        if safeCount <= 6 {
            let rows = CGFloat(Int(ceil(Double(safeCount) / Double(columns))))
            let rowHeight = floor((availableHeight - spacing * max(rows - 1, 0)) / rows)
            let side = max(0, min(itemWidth, rowHeight))
            let contentHeight = side * rows + spacing * max(rows - 1, 0)
            let screenCenteredTop = max(topInset, (height - contentHeight) / 2)
            return MeetingGridLayout(
                mode: .fixed,
                columns: columns,
                itemSize: CGSize(width: side, height: side),
                scrollable: false,
                visibleWindow: safeCount,
                centersLastItem: safeCount % columns == 1,
                horizontalPadding: edgeSpacing,
                topPadding: screenCenteredTop,
                bottomPadding: 0,
                verticalContentPadding: 0
            )
        }

        let visibleRows = max(1, Int(floor((availableHeight + spacing) / max(itemWidth + spacing, 1))))
        return MeetingGridLayout(
            mode: .gallery,
            columns: columns,
            itemSize: CGSize(width: itemWidth, height: itemWidth),
            scrollable: true,
            visibleWindow: max(columns, visibleRows * columns),
            centersLastItem: false,
            horizontalPadding: edgeSpacing,
            topPadding: topInset,
            bottomPadding: bottomInset,
            verticalContentPadding: 0
        )
    }
}

struct ActiveSpeakerParticipantSnapshot: Equatable {
    let id: String
    let isSpeaking: Bool
    let isScreenSharing: Bool
    let isCameraEnabled: Bool
    let isMicrophoneEnabled: Bool
    let audioLevel: Float
    let lastSpokeAt: UInt64
    var isLocal: Bool = false
}

struct ActiveSpeakerScheduler {
    struct State: Equatable {
        var visibleIds: [String] = []
        var speakingSince: [String: TimeInterval] = [:]
        var holdUntil: [String: TimeInterval] = [:]
        var queuedIds: [String] = []
        var lastSpeakingAt: [String: TimeInterval] = [:]
        var lastTickAt: TimeInterval = 0
    }

    static let promoteDelay: TimeInterval = 1.5
    static let holdTime: TimeInterval = 4.0
    /// Brief VAD dropouts shorter than this are treated as continued speech, so a
    /// choppy-but-continuous speaker doesn't keep resetting the promote timer.
    static let speakingHangover: TimeInterval = 0.6

    static func scheduledIds(
        participants: [ActiveSpeakerParticipantSnapshot],
        visibleWindow: Int,
        now: TimeInterval,
        state: inout State
    ) -> [String] {
        let participantIds = participants.map(\.id)
        guard participants.count >= 7, visibleWindow > 0, visibleWindow < participants.count else {
            state = State(visibleIds: participantIds)
            return participantIds
        }

        let validIds = Set(participantIds)
        state.visibleIds = state.visibleIds.filter { validIds.contains($0) }
        state.queuedIds = state.queuedIds.filter { validIds.contains($0) }
        state.speakingSince = state.speakingSince.filter { validIds.contains($0.key) }
        state.lastSpeakingAt = state.lastSpeakingAt.filter { validIds.contains($0.key) }
        state.holdUntil = state.holdUntil.filter { validIds.contains($0.key) && $0.value > now }

        // Trim to the current window: it can shrink without a tick (e.g. showing portrait chrome
        // grows the insets and drops a gallery row), and a stale over-full list would skew which
        // ids the scheduler treats as on-screen. Growth is handled by the trailing fill below.
        if state.visibleIds.count > visibleWindow {
            state.visibleIds = Array(state.visibleIds.prefix(visibleWindow))
        }

        // Advance the debounce/promotion clock at most once per distinct tick. `now` only moves
        // on the 0.3s timer, so repeated SwiftUI body passes within a frame reuse the last
        // arrangement instead of stacking promotions on the same timestamp.
        if now > state.lastTickAt {
            state.lastTickAt = now
            advancePromotions(participants: participants, visibleWindow: visibleWindow, now: now, state: &state)
        }

        // Always keep the window filled so mid-frame roster growth still shows everyone.
        appendMissingVisibleIds(from: participantIds, visibleWindow: visibleWindow, state: &state)

        let finalVisibleSet = Set(state.visibleIds)
        let remaining = participantIds.filter { !finalVisibleSet.contains($0) }
        return state.visibleIds + remaining
    }

    /// One tick of speaker debounce: refresh speaking state, queue eligible off-screen speakers,
    /// and promote a single queued speaker into a free slot. Must only run when `now` advanced.
    private static func advancePromotions(
        participants: [ActiveSpeakerParticipantSnapshot],
        visibleWindow: Int,
        now: TimeInterval,
        state: inout State
    ) {
        let participantIds = participants.map(\.id)

        // Bridge brief VAD dropouts: a participant counts as speaking while still within
        // `speakingHangover` of the last observed speaking sample.
        var effectivelySpeaking = Set<String>()
        for participant in participants where participant.isSpeaking {
            state.lastSpeakingAt[participant.id] = now
        }
        for participant in participants {
            if let last = state.lastSpeakingAt[participant.id], now - last < speakingHangover {
                effectivelySpeaking.insert(participant.id)
                state.speakingSince[participant.id] = state.speakingSince[participant.id] ?? now
            } else {
                state.speakingSince[participant.id] = nil
                state.lastSpeakingAt[participant.id] = nil
                state.queuedIds.removeAll { $0 == participant.id }
            }
        }

        appendMissingVisibleIds(from: participantIds, visibleWindow: visibleWindow, state: &state)

        let visibleSet = Set(state.visibleIds)
        for participant in participants {
            guard !visibleSet.contains(participant.id),
                  effectivelySpeaking.contains(participant.id),
                  let since = state.speakingSince[participant.id],
                  now - since >= promoteDelay,
                  !state.queuedIds.contains(participant.id) else {
                continue
            }
            state.queuedIds.append(participant.id)
        }

        promoteOneQueuedSpeaker(
            participants: participants,
            effectivelySpeaking: effectivelySpeaking,
            now: now,
            state: &state
        )
    }

    private static func appendMissingVisibleIds(
        from participantIds: [String],
        visibleWindow: Int,
        state: inout State
    ) {
        var visibleSet = Set(state.visibleIds)
        for id in participantIds where state.visibleIds.count < visibleWindow {
            guard !visibleSet.contains(id) else { continue }
            state.visibleIds.append(id)
            visibleSet.insert(id)
        }
    }

    private static func promoteOneQueuedSpeaker(
        participants: [ActiveSpeakerParticipantSnapshot],
        effectivelySpeaking: Set<String>,
        now: TimeInterval,
        state: inout State
    ) {
        let byId = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        state.queuedIds.removeAll { id in
            guard byId[id] != nil else { return true }
            return !effectivelySpeaking.contains(id) || state.visibleIds.contains(id)
        }

        guard let promoteId = state.queuedIds.first,
              let promoteSince = state.speakingSince[promoteId],
              now - promoteSince >= promoteDelay else {
            return
        }

        let candidates = state.visibleIds.enumerated().compactMap { offset, id -> (offset: Int, participant: ActiveSpeakerParticipantSnapshot)? in
            guard state.holdUntil[id, default: 0] <= now,
                  let participant = byId[id],
                  !participant.isLocal,
                  !effectivelySpeaking.contains(id),
                  !participant.isScreenSharing else {
                return nil
            }
            return (offset, participant)
        }

        guard let victim = candidates.min(by: { lhs, rhs in
            let lhsPriority = replacementPriority(lhs.participant)
            let rhsPriority = replacementPriority(rhs.participant)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            if lhs.participant.lastSpokeAt != rhs.participant.lastSpokeAt {
                return lhs.participant.lastSpokeAt < rhs.participant.lastSpokeAt
            }
            return lhs.offset < rhs.offset
        }) else {
            return
        }

        state.visibleIds[victim.offset] = promoteId
        state.holdUntil[promoteId] = now + holdTime
        state.queuedIds.removeAll { $0 == promoteId }
    }

    private static func replacementPriority(_ participant: ActiveSpeakerParticipantSnapshot) -> Int {
        if participant.isCameraEnabled { return 2 }
        if participant.isMicrophoneEnabled { return 1 }
        return 0
    }
}

struct RoomView: View {

    let logTag: String = "[newcall]"
    /// Stable full-screen size from RoomContextView.callContainerSize(); threaded into the grid.
    let containerSize: CGSize
    let contentTopInset: CGFloat
    let contentBottomInset: CGFloat
    /// Portion of `contentBottomInset` reserved to clear the bullet/emoji control; layouts that
    /// anchor to the toolbar (e.g. the 3-up column) subtract it back.
    var bulletReservedInset: CGFloat = 0

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
    @State private var useMultiGrid = false
    @State private var participantCountForMode = 0
    @State private var collapseToLegacyTask: Task<Void, Never>?
    @State private var schedulerTick: TimeInterval = CACurrentMediaTime()

    /// Hoisted so it isn't rebuilt/resubscribed on every `body` pass. Drives the active-speaker
    /// scheduler for 7+ participant grids.
    private let schedulerTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

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
                let rawCount = room.allParticipants.count
                let layout = MeetingGridLayout.resolve(
                    count: rawCount,
                    containerSize: containerSize,
                    isLandscape: containerSize.width > containerSize.height,
                    topInset: contentTopInset,
                    bottomInset: contentBottomInset,
                    bulletReservedInset: bulletReservedInset
                )
                let shouldUseMultiGrid = useMultiGrid || rawCount >= 3
                liveParticipantGrid(
                    layout: layout,
                    shouldUseMultiGrid: shouldUseMultiGrid,
                    useOneOnOneParticipantStyle: rawCount == 1
                )
                .animation(.easeInOut(duration: 0.28), value: layout)
                .animation(.easeInOut(duration: 0.28), value: rawCount)
            }
        }
        .accessibilityIdentifier(DTCallAccessibilityID.root)
        .onAppear {
            updateGridMode(for: room.allParticipants.count)
        }
        .onDisappear {
            collapseToLegacyTask?.cancel()
            DTMeetingManager.shared.resetActiveSpeakerGridState()
        }
        .onChange(of: room.allParticipants.count) { count in
            updateGridMode(for: count)
        }
        .onReceive(schedulerTimer) { _ in
            guard room.allParticipants.count >= 7 else { return }
            schedulerTick = CACurrentMediaTime()
        }
    }

    private func liveParticipantGrid(
        layout: MeetingGridLayout,
        shouldUseMultiGrid: Bool,
        useOneOnOneParticipantStyle: Bool
    ) -> some View {
        let participants = shouldUseMultiGrid
            ? DTMeetingManager.shared.sortedMeetingParticipants(
                visibleWindow: layout.visibleWindow,
                now: schedulerTick
            )
            : DTMeetingManager.shared.legacySortedMeetingParticipants()
        return ParticipantLayout(
            participants,
            layout: layout,
            spacing: 8,
            id: { participant in
                participant.identity?.stringValue ?? participant.sid?.stringValue ?? participant.id
            }
        ) { participant in
            ParticipantView(
                participant: participant,
                is1on1: useOneOnOneParticipantStyle,
                videoViewMode: .fill,
                showsPoorNetworkBadge: !roomCtx.usesOneToOneNetworkQualityPresentation
                    && roomCtx.isNetworkPoor(for: participant)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateGridMode(for count: Int) {
        participantCountForMode = count
        if count >= 3 {
            collapseToLegacyTask?.cancel()
            collapseToLegacyTask = nil
            if !useMultiGrid {
                withAnimation(.easeInOut(duration: 0.25)) {
                    useMultiGrid = true
                }
            }
            return
        }

        guard useMultiGrid else { return }
        collapseToLegacyTask?.cancel()
        collapseToLegacyTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard participantCountForMode <= 2 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    useMultiGrid = false
                    DTMeetingManager.shared.resetActiveSpeakerGridState()
                }
            }
        }
    }
}

struct ParticipantLayout<Data: RandomAccessCollection, Content: View>: View {
    private let items: [(id: String, view: AnyView)]
    let layout: MeetingGridLayout
    let spacing: CGFloat
    @Namespace private var participantTransitionNamespace

    init(
        _ data: Data,
        layout: MeetingGridLayout,
        spacing: CGFloat,
        id idProvider: (Data.Element) -> String,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.layout = layout
        self.spacing = spacing
        self.items = data.map { element in
            (id: idProvider(element), view: AnyView(content(element)))
        }
    }

    @ViewBuilder
    func resolvedGrid(_ layout: MeetingGridLayout) -> some View {
        if layout.scrollable {
            ScrollView(.vertical) {
                LazyVGrid(
                    columns: gridColumns(for: layout),
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(items, id: \.id) { item in
                        participantTile(item, layout: layout)
                    }
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.top, layout.topPadding)
                .padding(.bottom, layout.bottomPadding)
            }
        } else if layout.centersLastItem, let lastItem = items.last {
            VStack(spacing: spacing) {
                LazyVGrid(
                    columns: gridColumns(for: layout),
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(items.dropLast(), id: \.id) { item in
                        participantTile(item, layout: layout)
                    }
                }

                participantTile(lastItem, layout: layout)
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.topPadding + layout.verticalContentPadding)
            .padding(.bottom, layout.bottomPadding + layout.verticalContentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            LazyVGrid(
                columns: gridColumns(for: layout),
                alignment: .center,
                spacing: spacing
            ) {
                ForEach(items, id: \.id) { item in
                    participantTile(item, layout: layout)
                }
            }
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, layout.topPadding + layout.verticalContentPadding)
            .padding(.bottom, layout.bottomPadding + layout.verticalContentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
    
    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            resolvedGrid(layout)
                .animation(.easeInOut(duration: 0.28), value: layout)
                .animation(.easeInOut(duration: 0.28), value: itemSignature)
        }
    }

    private var itemSignature: String {
        items.map(\.id).joined(separator: "|")
    }

    private func gridColumns(for layout: MeetingGridLayout) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(layout.itemSize.width), spacing: spacing, alignment: .center),
            count: max(layout.columns, 1)
        )
    }

    private func participantTile(_ item: (id: String, view: AnyView), layout: MeetingGridLayout) -> some View {
        item.view
            .frame(width: layout.itemSize.width, height: layout.itemSize.height)
            .matchedGeometryEffect(id: item.id, in: participantTransitionNamespace, properties: .position)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
