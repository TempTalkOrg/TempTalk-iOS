//
//  MemberContainerView.swift
//  Difft
//
//  Created by Henry on 2025/4/1.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

struct MemberContainerView: View {
    @EnvironmentObject var roomCtx: RoomContext
    var onCancel: () -> Void
    var onAddMember: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: onAddMember) {
                               Image("ic_call_add_member2")
                                   .resizable()
                                   .frame(width: 20, height: 20)
                }
                .padding(.leading, 9)
                
                Spacer()
                
                Text(Localized("MEETING_SCREEN_SHARE_LIST_TITLE", comment: "") + " (\(roomCtx.callManager.allParticipantIds.count))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image("ic_call_member_close")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .padding(.trailing, 14)
            }
            .frame(maxHeight: 30)
            
            MultiMeetingView(roomCtx: _roomCtx)
            
            Spacer()
        }
        .frame(maxHeight: min(screenWidth, screenHeight))
        .padding(.top, 8)
    }
}
