//
//  SettingBaseViewController.swift
//  TempTalk
//
//  Created by Kris.s on 2024/11/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class SettingBaseViewController: OWSViewController, OWSNavigationChildController {
    
    public var navbarBackgroundColorOverride: UIColor? { Theme.defaultBackgroundColor }
    
    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }
    
    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }
    
    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool {
        if self.isKind(of: AppSettingsViewController.self) {
            return true
        }
        return false
    }
    
    public var shouldCancelNavigationBack: Bool { false }
    
}
