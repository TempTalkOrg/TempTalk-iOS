//
//  Untitled.swift
//  Difft
//
//  Created by Henry on 2025/6/18.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

public enum ConnectState: Int {
    case connected = 0
    case connecting
    case disconnected
}

public struct DTCircleLoadingView: View {
    
    public var connectState: ConnectState
    
    @State private var isAnimating: Bool = false
    @State private var rotation: Double = 0
    
    public init(connectState: ConnectState) {
        self.connectState = connectState
    }
    
    public var body: some View {
        ZStack {
            if connectState == .disconnected {
                Image("ic_rtc_warning")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                CircleArc()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(connectState == .connecting ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isAnimating)
                    .onAppear {
                        if connectState == .connecting {
                            isAnimating = true
                        }
                    }
                    .onChange(of: connectState) { newState in
                        isAnimating = (newState == .connecting)
                    }
            }
        }
        .frame(width: 12, height: 12) // 可根据需要调整
    }
}

// 自定义圆弧
private struct CircleArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: 0)
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        return path
    }
}
