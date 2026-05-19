//
//  SpeakerFloatingView.swift
//  TempTalk
//
//  Created on 2026/4/28.
//  Copyright © 2026 Difft. All rights reserved.
//

import SwiftUI
import LiveKit
import Combine
import Lottie

// MARK: - State bridge (UIKit ↔ SwiftUI)

private class SpeakerFloatingStateBridge: ObservableObject {
    @Published var isExpanded: Bool = true
    @Published var contentVersion: UInt = 0
    func refreshContent() { contentVersion &+= 1 }
}

// MARK: - SwiftUI Content

struct SpeakerFloatingView: View {
    @ObservedObject fileprivate var state: SpeakerFloatingStateBridge

    private var speakingParticipant: Participant? {
        DTMeetingManager.shared.currentSpeakingParticipant()
    }

    private var lineUp: [Participant] {
        DTMeetingManager.shared.micOnLineUp()
    }

    var body: some View {
        let _ = state.contentVersion
        let speaker = speakingParticipant
        let lineup = lineUp

        floatingBody(speaker: speaker, lineup: lineup)
            .onReceive(RoomDataManager.shared.messageMeetingPublisher) { _ in
                state.refreshContent()
            }
    }

    @ViewBuilder
    private func floatingBody(speaker: Participant?, lineup: [Participant]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(speaker: speaker, lineup: lineup)

            if state.isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color(hex: 0x474D57))
                        .frame(height: 1)

                    Text(Localized("CALL_MIC_QUEUE_TITLE"))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: 0xB7BDC6))

                    ForEach(lineup, id: \.identity) { participant in
                        micQueueRow(participant: participant)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(8)
        .frame(width: 160, alignment: .leading)
        .background(Color(hex: 0x1E2329))
        .clipped()
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: 0x5E6673).opacity(0.9), lineWidth: 1)
        )
    }

    // MARK: - Header row

    private var displayParticipant: Participant? {
        if let s = speakingParticipant { return s }
        guard let room = DTMeetingManager.shared.roomContext?.room else { return nil }
        let all: [Participant] = [room.localParticipant] + Array(room.remoteParticipants.values)
        return all.first { $0.videoTracks.contains(where: { $0.source == .screenShareVideo }) }
    }

    private var displayName: String {
        if let p = displayParticipant {
            let rid = p.identity?.stringValue.components(separatedBy: ".").first ?? ""
            return DTLiveKitCallModel.getDisplayName(recipientId: rid)
        }
        if let item = DTMeetingManager.shared.fetchSharingItem() {
            return item.displayName ?? item.recipientId ?? ""
        }
        return ""
    }

    private func isScreenSharer(_ participant: Participant?) -> Bool {
        guard let p = participant else { return false }
        return p.videoTracks.contains(where: { $0.source == .screenShareVideo })
    }

    private func headerRow(speaker: Participant?, lineup: [Participant]) -> some View {
        let name = displayName
        let display = speaker ?? displayParticipant
        let showShareIcon = isScreenSharer(display)

        return HStack(spacing: 4) {
            if showShareIcon {
                Image("ic_call_sharing")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }

            micStateIcon(speaker: speaker, display: display)

            if !name.isEmpty {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0xEAECEF))
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 0)
                    .lineLimit(1)
            }

            if !state.isExpanded && !lineup.isEmpty {
                Spacer(minLength: 0)

                Rectangle()
                    .fill(Color(hex: 0x474D57))
                    .frame(width: 1, height: 12)

                micQueueAvatarPreview(lineup: lineup)
                    .padding(.trailing, 4)
            }
        }
        .frame(height: 16)
    }

    @ViewBuilder
    private func micStateIcon(speaker: Participant?, display: Participant?) -> some View {
        if speaker?.isSpeaking == true {
            LottieView(animation: .named("Meeting_audio"))
                .playing(loopMode: .loop)
                .frame(width: 16, height: 16)
        } else if let display, display.isMicrophoneEnabled() {
            Image("ic_call_unmuted")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image("tabler_microphone-muted")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Avatar preview (collapsed)

    private func micQueueAvatarPreview(lineup: [Participant]) -> some View {
        let previews = Array(lineup.prefix(2))
        return HStack(spacing: -4) {
            ForEach(previews, id: \.identity) { participant in
                let rid = participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
                AvatarImageViewRepresentable(recipientId: rid)
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Mic queue row

    private func micQueueRow(participant: Participant) -> some View {
        let recipientId = participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
        let name = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)

        return HStack(spacing: 8) {
            AvatarImageViewRepresentable(recipientId: recipientId)
                .frame(width: 16, height: 16)
                .clipShape(Circle())

            Text(name)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xB7BDC6))
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 0)
                .lineLimit(1)
        }
    }
}

// MARK: - Passthrough Container (touch isolation)

class SpeakerFloatingContainer: UIView {

    private let hitPadding: CGFloat = 30

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for sub in subviews.reversed() where sub.isUserInteractionEnabled && !sub.isHidden {
            let converted = sub.convert(point, from: self)
            let hitRect: CGRect
            if let floatingView = sub as? SpeakerFloatingUIView {
                hitRect = CGRect(origin: .zero, size: floatingView.currentContentSize)
            } else {
                hitRect = sub.bounds
            }
            guard hitRect.insetBy(dx: -hitPadding, dy: -hitPadding).contains(converted) else { continue }
            return sub
        }
        return nil
    }

    func addToSuperview(_ superview: UIView) {
        superview.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor),
        ])
    }
}

// MARK: - UIKit Hosting Wrapper

class SpeakerFloatingUIView: UIView {

    private var hostingController: UIHostingController<SpeakerFloatingView>?
    private let stateBridge = SpeakerFloatingStateBridge()
    private var touchPoint: CGPoint = .zero
    private var totalDragDistance: CGFloat = 0
    private var isDragging = false
    private var isAnimating = false
    private var s_constraints = [NSLayoutConstraint]()
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private let collapsedHeight: CGFloat = 32
    private let topMargin: CGFloat = 50.0
    private let rightMargin: CGFloat = 25.0
    private let margin: CGFloat = 15.0
    private let dragThreshold: CGFloat = 8
    private var contentObserver: AnyCancellable?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        layer.cornerRadius = 8
        isUserInteractionEnabled = true

        let speakerView = SpeakerFloatingView(state: stateBridge)
        let hc = UIHostingController(rootView: speakerView)
        hc.view.backgroundColor = .clear
        hc.view.isUserInteractionEnabled = false
        if #available(iOS 16.0, *) {
            hc.sizingOptions = .intrinsicContentSize
        }
        if #available(iOS 16.4, *) {
            hc.safeAreaRegions = []
        }

        let hcView = hc.view!
        addSubview(hcView)
        hcView.translatesAutoresizingMaskIntoConstraints = false
        hcView.setContentHuggingPriority(.required, for: .vertical)
        hcView.setContentCompressionResistancePriority(.required, for: .vertical)
        NSLayoutConstraint.activate([
            hcView.topAnchor.constraint(equalTo: topAnchor),
            hcView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hcView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        hostingController = hc

        let press = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
        press.minimumPressDuration = 0
        addGestureRecognizer(press)

        contentObserver = stateBridge.$contentVersion
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncConstraintsIfNeeded() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        Logger.debug("[SpeakerFloatingUIView] deinit.")
        contentObserver?.cancel()
        NSLayoutConstraint.deactivate(s_constraints)
        s_constraints.removeAll()
        if let hc = hostingController {
            hc.willMove(toParent: nil)
            hc.removeFromParent()
        }
    }

    // MARK: - Add to container

    func addToContainer(_ container: SpeakerFloatingContainer, in parentVC: UIViewController) {
        container.addSubview(self)

        if let hc = hostingController {
            parentVC.addChild(hc)
            hc.didMove(toParent: parentVC)
        }

        translatesAutoresizingMaskIntoConstraints = false
        let size = measureHostingContent()
        let topC = topAnchor.constraint(equalTo: container.topAnchor, constant: topMargin)
        let trailingC = trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -rightMargin)
        let wC = widthAnchor.constraint(equalToConstant: size.width)
        let hC = heightAnchor.constraint(equalToConstant: size.height)
        widthConstraint = wC
        heightConstraint = hC
        s_constraints = [topC, trailingC, wC, hC]
        NSLayoutConstraint.activate(s_constraints)
    }

    // MARK: - Content size (for hitTest)

    var currentContentSize: CGSize {
        CGSize(width: widthConstraint?.constant ?? 160,
               height: heightConstraint?.constant ?? collapsedHeight)
    }

    private func measureHostingContent() -> CGSize {
        guard let hcView = hostingController?.view else {
            return CGSize(width: 160, height: collapsedHeight)
        }
        hcView.setNeedsLayout()
        hcView.layoutIfNeeded()
        let size = hcView.intrinsicContentSize
        return CGSize(width: size.width > 0 ? size.width : 160,
                      height: size.height > 0 ? size.height : collapsedHeight)
    }

    /// Sync constraints when content changes (e.g. lineup update) outside of toggle animation.
    private func syncConstraintsIfNeeded() {
        guard !isDragging, !isAnimating else { return }
        let target = measureHostingContent()
        guard let wC = widthConstraint, let hC = heightConstraint else { return }
        if abs(target.width - wC.constant) > 0.5 || abs(target.height - hC.constant) > 0.5 {
            wC.constant = target.width
            hC.constant = target.height
            superview?.setNeedsLayout()
        }
    }

    // MARK: - Toggle animation

    private func performToggleAnimation() {
        guard !isAnimating, let wC = widthConstraint, let hC = heightConstraint else { return }
        isAnimating = true

        if stateBridge.isExpanded {
            // === COLLAPSE ===
            // Keep expanded content visible while UIKit shrinks the clip.
            // After animation, switch SwiftUI to collapsed.
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                hC.constant = self.collapsedHeight
                self.superview?.layoutIfNeeded()
            } completion: { [weak self] _ in
                guard let self else { return }
                self.stateBridge.isExpanded = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let size = self.measureHostingContent()
                    self.widthConstraint?.constant = size.width
                    self.heightConstraint?.constant = size.height
                    self.isAnimating = false
                }
            }
        } else {
            // === EXPAND ===
            // Switch SwiftUI to expanded first (content renders but is clipped).
            // Then animate UIKit height to reveal it.
            stateBridge.isExpanded = true
            DispatchQueue.main.async { [weak self] in
                guard let self, let wC = self.widthConstraint, let hC = self.heightConstraint else { return }
                let target = self.measureHostingContent()
                UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                    wC.constant = target.width
                    hC.constant = target.height
                    self.superview?.layoutIfNeeded()
                } completion: { [weak self] _ in
                    self?.isAnimating = false
                }
            }
        }
    }

    // MARK: - Unified gesture (tap + drag)

    @objc private func handlePress(_ gesture: UILongPressGestureRecognizer) {
        guard let container = superview else { return }
        let location = gesture.location(in: container)
        let viewW = bounds.width > 0 ? bounds.width : 160.0
        let viewH = bounds.height > 0 ? bounds.height : collapsedHeight
        let containerH = container.bounds.height

        switch gesture.state {
        case .began:
            touchPoint = location
            totalDragDistance = 0
            isDragging = false

        case .changed:
            let dx = location.x - touchPoint.x
            let dy = location.y - touchPoint.y
            totalDragDistance += abs(dx) + abs(dy)

            if !isDragging && totalDragDistance > dragThreshold {
                isDragging = true
                if !s_constraints.isEmpty {
                    NSLayoutConstraint.deactivate(s_constraints)
                    s_constraints.removeAll()
                }
                translatesAutoresizingMaskIntoConstraints = true
            }

            if isDragging {
                var fr = self.frame
                fr.origin.x += dx
                fr.origin.y += dy
                fr.origin.x = max(0, min(fr.origin.x, container.bounds.width - viewW))
                fr.origin.y = max(0, min(fr.origin.y, containerH - viewH))
                self.frame = fr
            }
            touchPoint = location

        case .ended:
            if isDragging {
                snapToEdge(in: container, containerH: containerH)
            } else {
                performToggleAnimation()
            }

        case .cancelled, .failed:
            if isDragging {
                snapToEdge(in: container, containerH: containerH)
            }

        default:
            break
        }
    }

    private func snapToEdge(in container: UIView, containerH: CGFloat) {
        isDragging = false
        let currentViewW = bounds.width > 0 ? bounds.width : 160.0
        let currentViewH = bounds.height > 0 ? bounds.height : collapsedHeight

        var targetX: CGFloat
        var targetY: CGFloat

        if center.x >= container.bounds.width / 2 {
            targetX = container.bounds.width - currentViewW - margin
        } else {
            targetX = margin
        }

        if frame.origin.y < margin {
            targetY = margin
        } else if frame.maxY >= containerH {
            targetY = containerH - currentViewH - margin
        } else {
            targetY = frame.origin.y
        }

        UIView.animate(withDuration: 0.3) {
            self.frame = CGRect(x: targetX, y: targetY, width: currentViewW, height: currentViewH)
        } completion: { [weak self] _ in
            guard let self, !self.isDragging, let sv = self.superview else { return }
            self.translatesAutoresizingMaskIntoConstraints = false

            let size = self.measureHostingContent()
            let wC = self.widthAnchor.constraint(equalToConstant: size.width)
            let hC = self.heightAnchor.constraint(equalToConstant: size.height)
            self.widthConstraint = wC
            self.heightConstraint = hC

            let topC = self.topAnchor.constraint(equalTo: sv.topAnchor, constant: targetY)
            if targetX > sv.bounds.width / 2 {
                let trailingC = self.trailingAnchor.constraint(equalTo: sv.trailingAnchor, constant: -(sv.bounds.width - targetX - currentViewW))
                self.s_constraints = [topC, trailingC, wC, hC]
            } else {
                let leadingC = self.leadingAnchor.constraint(equalTo: sv.leadingAnchor, constant: targetX)
                self.s_constraints = [topC, leadingC, wC, hC]
            }
            NSLayoutConstraint.activate(self.s_constraints)
        }
    }
}
