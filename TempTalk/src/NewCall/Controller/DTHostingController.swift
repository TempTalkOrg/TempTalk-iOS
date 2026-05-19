//
//  DTHostingController.swift
//  TempTalk
//
//  Created by Ethan on 09/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import UIKit
import Foundation

class DTHostingController<Content: View>: UIHostingController<Content> {
    
    init(rootView: Content, backgroundColor: UIColor = UIColor(rgbHex: 0x181A20)) {
        super.init(rootView: rootView)
        
        self.overrideUserInterfaceStyle = .dark
        self.view.backgroundColor = backgroundColor
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        additionalSafeAreaInsets = .zero
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
        
    @objc
    func themeDidChange() {
        
        // 保证会议vc背景始终为深色
        view.backgroundColor = .black
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
