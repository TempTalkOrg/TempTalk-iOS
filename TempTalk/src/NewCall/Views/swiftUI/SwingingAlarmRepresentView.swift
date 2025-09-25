//
//  SwingingView.swift
//  Difft
//
//  Created by Henry on 2025/6/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

struct SwingingAlarmRepresentView: UIViewRepresentable {
    var imageName: String
    var message: String
    var isAnimating: Bool
    var textColor: UIColor
    var isVibrating: Bool

    func makeUIView(context: Context) -> SwingingAlarmView {
        return SwingingAlarmView()
    }

    func updateUIView(_ uiView: SwingingAlarmView, context: Context) {
        uiView.imageName = imageName
        uiView.message = message
        uiView.textColor = textColor

        if isAnimating {
            uiView.startSwinging()
        } else {
            uiView.stopSwinging()
        }
        
        if isVibrating {
            uiView.startVibrating()
        } else {
            uiView.stopVibrating()
        }
    }
}
