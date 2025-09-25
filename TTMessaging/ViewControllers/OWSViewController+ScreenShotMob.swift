//
//  OWSViewController+ScreenShotMob.swift
//  TTMessaging
//
//  Created by hornet on 2023/5/11.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
@objc
public extension OWSViewController {
    @objc func snapshotImage() -> UIImage? {
        let bounds = UIScreen.main.bounds
        UIGraphicsBeginImageContextWithOptions(bounds.size, false, 1)
        self.view.drawHierarchy(in: bounds, afterScreenUpdates: false)
        let snapshotImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return snapshotImage
    }
}
