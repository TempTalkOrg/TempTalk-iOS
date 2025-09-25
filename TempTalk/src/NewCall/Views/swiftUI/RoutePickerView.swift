//
//  RoutePickerView.swift
//  Difft
//
//  Created by Henry on 2025/5/20.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import AVKit

struct RoutePickerView: UIViewRepresentable {
    
    var portType: AVAudioSession.Port  // 传入状态
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let pickerView = AVRoutePickerView()
        pickerView.activeTintColor = .clear
        pickerView.tintColor = .clear

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 1001
        imageView.translatesAutoresizingMaskIntoConstraints = false
        pickerView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: pickerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: pickerView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: pickerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: pickerView.trailingAnchor)
        ])
        
        imageView.image = pickerIconImage()
        
        return pickerView
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        if let imageView = uiView.viewWithTag(1001) as? UIImageView {
            imageView.image = pickerIconImage()
        }
    }
    
    private func pickerIconImage() -> UIImage? {
        switch portType {
        case .builtInReceiver:
            return UIImage(named: "ic_call_phone")
        case .builtInSpeaker:
            return UIImage(named: "ic_call_speaker")
        case .headphones:
            return UIImage(named: "ic_wired_headset")
        case .bluetoothLE, .bluetoothHFP, .bluetoothA2DP:
            return UIImage(named: "ic_wireless_headset")
        default:
            return UIImage(named: "ic_wired_headset")
        }
    }
}
