//
//  CallAnswerView.swift
//  Signal
//
//  Created by Ethan on 27/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import SwiftUI
import TTMessaging
import SFSafeSymbols

struct CallAnswerView: View {
    
    private let logTag = "[newcall]"
    
    let currentCall: DTLiveKitCallModel
    
    var autoAccept: Bool = false
    @State var isConnecting = false
    var onAnswer: () -> Void
    var onDecline: () -> Void
    
    @State private var rotation: Double = 0
    
    func displayName() -> String {
        return Environment.shared.contactsManager.displayName(forPhoneIdentifier: currentCall.caller)
    }
    
    func roomName() -> String {
        return "\(Localized("GROUP_CALL_WAITING_ANSWER"))\(currentCall.roomName)"
    }
    
    var body: some View {
        VStack {
            VStack(spacing: 15) {
                AvatarImageViewRepresentable(recipientId: currentCall.caller ?? "TempTalk")
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                Text(displayName())
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(.top, 10)
                if currentCall.callType != .private {
                    Text(roomName())
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 230)
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            HStack(spacing: 100) {
                Button(action: {
                    onDecline()
                }) {
                    Image(systemSymbol: .phoneDownFill)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                
                Button(action: {
                    if !isConnecting {
                        isConnecting = true
                        onAnswer()
                    }
                }) {
                    VStack {
                        if isConnecting {
                            LoadingAnimationView(rotation: $rotation)
                        } else {
                            Image(systemSymbol: .phoneFill)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .background(Color.green)
                    .clipShape(Circle())
                }
                .disabled(isConnecting)
            }
            .padding(.bottom, 90)
        }
        .background(Color.dtBackground)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            Logger.info("\(logTag) callAnswerView onAppear")
            // callKit自动接听
            if autoAccept && !isConnecting {
                isConnecting = true
                onAnswer()
            }
        }.onDisappear() {
            Logger.info("\(logTag) callAnswerView DisAppear")
        }
    }

}

struct LoadingAnimationView: View {
    @Binding var rotation: Double
    
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.9)
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.white, .clear]), center: .center, startAngle: .degrees(0), endAngle: .degrees(300)),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
            )
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation += 360
                }
            }
    }
}

#Preview {
    CallAnswerView(currentCall: DTLiveKitCallModel()) {
        print("accept")
    } onDecline: {
        print("decline")
    }
}

