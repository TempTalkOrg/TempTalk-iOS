//
//  IncomingCallBannerView.swift
//  TempTalk
//
//  Created on 2026/05/20.
//

import SwiftUI
import TTMessaging
import SFSafeSymbols

struct IncomingCallBannerView: View {

    let callerName: String
    let callerId: String
    let isGroupCall: Bool
    var onAnswer: () -> Void
    var onDecline: () -> Void

    @State private var offset: CGFloat = -200

    private var callTypeLabel: String {
        let appName = TSConstants.appDisplayName
        if isGroupCall {
            return "\(appName) \(Localized("GROUP_CALL_WAITING_ANSWER"))"
        } else {
            return "\(appName) \(Localized("CALL_VIEW_AUDIO_SOURCE_LABEL"))..."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    AvatarImageViewRepresentable(recipientId: callerId)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .padding(.trailing, 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(callTypeLabel)
                            .font(.system(size: 15))
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(1)

                        Text(callerName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    Button(action: onDecline) {
                        Image(systemSymbol: .xmark)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .background(Color(white: 0.45, opacity: 0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 16)

                    Button(action: onAnswer) {
                        Image(systemSymbol: .checkmark)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.18, green: 0.72, blue: 0.32))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 18)

                Spacer(minLength: 0)
            }
            .frame(height: 120)
            .background(
                ZStack {
                    if #available(iOS 15.0, *) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.thickMaterial)
                            .environment(\.colorScheme, .dark)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12, opacity: 0.96))
                    }
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.top, 2)
        .offset(y: offset)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                offset = 0
            }
        }
    }
}
