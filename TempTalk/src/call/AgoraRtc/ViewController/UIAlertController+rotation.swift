//
//  UIAlertController+rotation.swift
//  Signal
//
//  Created by Felix on 2022/8/18.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import UIKit

@objc class DTAlertController: UIAlertController {
    
    override func loadView() {
        super.loadView()
        overrideUserInterfaceStyle = .dark
    }
    
    open override var shouldAutorotate: Bool {
        get {
            return false
        }
    }
}

//@objc class DTAlertController: UIAlertController {
//
//    open override func viewDidLayoutSubviews() {
//
//        super.viewDidLayoutSubviews()
//
//        if preferredStyle == .alert { return }
//
//        for i in self.actions {
//            let attributedText = NSAttributedString(string: i.title ?? "", attributes: [NSAttributedString.Key.font : UIFont.systemFont(ofSize: 16)])
//            guard let label = (i.value(forKey: "__representer") as AnyObject).value(forKey: "label") as? UILabel else { return }
//            label.attributedText = attributedText
//        }
//    }
//
//}


