//
//  HandsControlViewRepresentable.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import Combine

struct HandsControlViewRepresentable: UIViewRepresentable {
    
    var onTap: (() -> Void)?
    
    func makeUIView(context: Context) -> HandsControlView {
        let inputView = HandsControlView()
        inputView.updateContents()
        inputView.onTap = onTap
        context.coordinator.cancellable?.cancel()
        context.coordinator.cancellable = RoomDataManager.shared.raiseHandsPublisher
                .receive(on: RunLoop.main)
                .sink {_ in 
                    inputView.updateContents()
                }

        return inputView
    }

    func updateUIView(_ uiView: HandsControlView, context: Context) {
        uiView.onTap = onTap
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject {
        var cancellable: AnyCancellable?
        
        deinit {
            cancellable?.cancel()
        }
    }
    
}
