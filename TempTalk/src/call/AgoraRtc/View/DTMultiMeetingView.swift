//
//  Untitled.swift
//  Difft
//
//  Created by Henry on 2025/7/4.
//  Copyright © 2025 Difft. All rights reserved.
//

@objc
extension DTMultiMeetingView {
    func getHangupList() -> [String] {
        return RoomDataManager.shared.handsData
    }
}
