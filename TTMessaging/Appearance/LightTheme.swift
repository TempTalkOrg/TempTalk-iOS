//
//  LightTheme.swift
//  SignalMessaging
//
//  Created by Jaymin on 2025/7/7.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

// Figma: https://www.figma.com/design/16QV9AE1wA37o9D2Xdc4sO/Wea-Design-system?node-id=1244-21129&p=f&m=dev
class LightTheme: ThemeProtocol {
    
    // MARK: Brand Color & Function Color
    static var primaryColor: UIColor { UIColor(rgbHex: 0x056FFA) }
    static var successColor: UIColor { UIColor(rgbHex: 0x01BC6A) }
    static var warningColor: UIColor { UIColor(rgbHex: 0xFFC814) }
    static var errorColor: UIColor { UIColor(rgbHex: 0xF84135) }
    static var cautionColor: UIColor { UIColor(rgbHex: 0xFF8800) }
    static var secondaryColor: UIColor { UIColor(rgbHex: 0x82C1FC) }
    static var lineColor: UIColor { UIColor(rgbHex: 0xEAECEF) }
    static var iconColor: UIColor { UIColor(rgbHex: 0x474D57) }
    static var dividerColor: UIColor { UIColor(rgbHex: 0xEAECEF) }
    
    // MARK: Text Color
    static var tprimaryColor: UIColor { UIColor(rgbHex: 0x1E2329) } // lightThemePrimaryColor
    static var tsecondaryColor: UIColor { UIColor(rgbHex: 0x474D57) }
    static var tthirdColor: UIColor { UIColor(rgbHex: 0x848E9C) }
    static var tdisableColor: UIColor { UIColor(rgbHex: 0xB7BDC6) }
    static var twhiteColor: UIColor  { UIColor(rgbHex: 0xFFFFFF) }
    static var tblackColor: UIColor  { UIColor(rgbHex: 0x181A20) }
    static var twarningColor: UIColor  { UIColor(rgbHex: 0xB06D00) }
    static var terrorColor: UIColor  { UIColor(rgbHex: 0xD9271E) }
    static var tsuccessColor: UIColor  { UIColor(rgbHex: 0x00764B) }
    static var tinfoColor: UIColor  { UIColor(rgbHex: 0x056FFA) }
    static var tcautionColor: UIColor  { UIColor(rgbHex: 0xAE5004) }
    
    // MARK: Background Color
    static var bg1Color: UIColor  { UIColor(rgbHex: 0xFFFFFF) }
    static var bg2Color: UIColor  { UIColor(rgbHex: 0xFAFAFA) }
    static var bg3Color: UIColor  { UIColor(rgbHex: 0xF5F5F5) }
    static var bg4Color: UIColor  { UIColor(rgbHex: 0xEAECEF) }
    static var bg5Color: UIColor  { UIColor(rgbHex: 0xFAFAFA) }
    static var bgdisableColor: UIColor  { UIColor(rgbHex: 0xEAECEF) }
    static var bgtooltipColor: UIColor  { UIColor(rgbHex: 0x5E6673) }
    static var bgmodalColor: UIColor  { UIColor(rgbHex: 0xFFFFFF) }
    static var bgpopupColor: UIColor  { UIColor(rgbHex: 0xFFFFFF) }
    static var bgelevateColor: UIColor  { UIColor(rgbHex: 0xF5F5F5) }
    static var bgskyColor: UIColor  { UIColor(rgbHex: 0xEBF7FF) }
    static var bgskyAlphaColor: UIColor  { UIColor(rgbHex: 0xEBF7FF) }
    static var bgConfidentialCompensatedColor: UIColor  { UIColor(rgbHex: 0xEBF7FF, alpha: 0xD9 / 255.0) }
    static var bgspaceColor: UIColor  { UIColor(rgbHex: 0x001C4E) }
    static var defaultColor: UIColor  { UIColor(rgbHex: 0xFAFAFA) }
    static var bgpagePrimaryColor: UIColor { UIColor(rgbHex: 0xFFFFFF) }
    static var bgpageSecondaryColor: UIColor { UIColor(rgbHex: 0xF5F5F5) }
    
    // MARK: Other Style
    static var barStyle: UIBarStyle  { .default }
    static var barBlurEffect: UIBlurEffect  { .init(style: .light) }
    static var keyboardAppearance: UIKeyboardAppearance  { .default }
    static var accentBlueColor: UIColor  { UIColor(rgbHex: 0x2C6BED) }
}
