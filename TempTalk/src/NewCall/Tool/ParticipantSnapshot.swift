//
//  ParticipantSnapshot.swift
//  Difft
//
//  Created by Henry on 2025/6/17.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit
import SwiftUI
import Combine

class ParticipantSnapshot: ObservableObject, Identifiable, Equatable {
    let id: String
    let identity: String
    let isMicMuted: Bool

    init(id: String, identity: String, isMicMuted: Bool = true) {
        self.id = id
        self.identity = identity
        self.isMicMuted = isMicMuted
    }

    convenience init(from participant: Participant) {
        self.init(
            id: Self.parseId(participant),
            identity: Self.parseIdentity(participant),
            isMicMuted: participant.firstAudioPublication?.isMuted ?? true
        )
    }
    
    private static func parseId(_ participant: Participant) -> String {
        return participant.identity?.stringValue ?? ""
    }
    
    private static func parseIdentity(_ participant: Participant) -> String {
        return participant.identity?.stringValue.components(separatedBy: ".").first ?? ""
    }
    
    static func == (lhs: ParticipantSnapshot, rhs: ParticipantSnapshot) -> Bool {
        return lhs.id == rhs.id &&
               lhs.identity == rhs.identity &&
               lhs.isMicMuted == rhs.isMicMuted
    }
    
    func snapshotParticipants(_ participants: [Participant]) -> [ParticipantSnapshot] {
        return participants.map { ParticipantSnapshot(from: $0) }
    }
}
