//
//  Room1on1ContentView.swift
//  TempTalk
//
//  Created by undefined on 15/1/25.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import LiveKit

struct Room1on1ContentView: View {
    
    let logTag: String = "[newcall][view]"
    
    @EnvironmentObject var appCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room
    
    var currentCall: DTLiveKitCallModel { roomCtx.currentCall }
    
    private let screenWidth = UIScreen.main.bounds.width
    
    @State var videoPositionExchange: Bool = false
    @State private var cachedRemote: Participant? = nil
    
    private func participantSnapshot(isLocal: Bool) -> ParticipantSnapshot {
        let localNum = TSAccountManager.localNumber()
        let participants = DTMeetingManager.shared.sortedReconnectingParticipants()
        return participants.first(where: { (isLocal ? $0.identity == localNum : $0.identity != localNum) })
               ?? ParticipantSnapshot(id: "", identity: "")
    }
    
    var body: some View {
            ZStack {
                if roomCtx.room.connectionState == .reconnecting {
                    let local = participantSnapshot(isLocal: true)
                    let remote = participantSnapshot(isLocal: false)

                    ReconnectingParticipantView(
                        snapshot: videoPositionExchange ? local : remote,
                        is1on1: true,
                        videoViewMode: .fit
                    )
                    .environmentObject(appCtx)

                } else {
                    let local = roomCtx.room.localParticipant
                    let remoteOpt = fetch1on1OthersideParticipant()
                    let isLocalCameraOn = local.isCameraEnabled()

                    let remote = remoteOpt ?? cachedRemote

                    ZStack {
                        if let remote {
                            ParticipantView(
                                participant: videoPositionExchange ? local : remote,
                                is1on1: true,
                                videoViewMode: .fit
                            )
                            .environmentObject(appCtx)
                        }

                        if isLocalCameraOn, let remote {
                            ParticipantView(
                                participant: videoPositionExchange ? remote : local,
                                is1on1: true,
                                videoViewMode: .fit
                            )
                            .environmentObject(appCtx)
                            .frame(width: screenWidth / 3, height: screenWidth / 3 / 9 * 16)
                            .padding(.trailing, 10)
                            .padding(.top, 40)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                    }
                    .onChange(of: remoteOpt) { newValue in
                        if let newValue {
                            cachedRemote = newValue   // ✅ 在这里更新缓存
                        }
                    }
                }
            }
        }
}

extension Room1on1ContentView {
    
    func fetch1on1OthersideParticipant() -> Participant? {
        
        let otherSideId: String
        if currentCall.isCaller {
            otherSideId = currentCall.callees?.first ?? ""
        } else {
            otherSideId = currentCall.caller ?? ""
        }
                
        let otherside = room.allParticipants.first(where: { (key: Participant.Identity, value: Participant) in
            let stringIdentity = key.stringValue
            let recipientId = stringIdentity.components(separatedBy: ".").first ?? stringIdentity
            return recipientId == otherSideId
        })
                
        return otherside?.value
    }
}


