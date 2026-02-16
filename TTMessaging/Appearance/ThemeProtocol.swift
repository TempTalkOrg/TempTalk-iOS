//
//  ThemeProtocol.swift
//  SignalMessaging
//
//  Created by Jaymin on 2025/7/7.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

// Figma: https://www.figma.com/design/16QV9AE1wA37o9D2Xdc4sO/Wea-Design-system?node-id=1244-21129&p=f&m=dev
@objc public protocol ThemeProtocol {
    
    // MARK: Brand Color & Function Color
    static var primaryColor: UIColor { get } // cursorColor accentBlueColor themeBlueColor
    static var successColor: UIColor { get }
    static var warningColor: UIColor { get }
    static var errorColor: UIColor { get } // redBgroundColor destructiveRed
    static var cautionColor: UIColor { get }
    static var secondaryColor: UIColor { get }
    static var lineColor: UIColor { get } // hairlineColor outlineColor cellSeparatorColor(alpha:0.2)
    static var iconColor: UIColor { get } // primaryIconColor
    static var dividerColor: UIColor { get } // dividerColor
    
    // MARK: Text Color
    static var tprimaryColor: UIColor { get } // primaryTextColor navbarTitleColor alertCancelColor
    static var tsecondaryColor: UIColor { get } // secondaryTextAndIconColor tabbarTitleNormalColor
    static var tthirdColor: UIColor { get } // ternaryTextColor placeholderColor
    static var tdisableColor: UIColor { get } // thirdTextAndIconColor
    static var twhiteColor: UIColor { get }
    static var tblackColor: UIColor { get }
    static var twarningColor: UIColor { get }
    static var terrorColor: UIColor { get }
    static var tsuccessColor: UIColor { get }
    static var tinfoColor: UIColor { get } // tabbarTitleSelectedColor indicatorLineColor alertConfirmColor
    static var tcautionColor: UIColor { get }
    
    // MARK: Background Color
    static var bg1Color: UIColor { get } // backgroundColor navbarBackgroundColor tabbarBackgroundColor toolbarBackgroundColor tableCellBackgroundColor
    static var bg2Color: UIColor { get } // secondaryBackgroundColor washColor stickBackgroundColor tableViewBackgroundColor searchFieldBackgroundColor
    static var bg3Color: UIColor { get } // conversationInputBackgroundColor attachmentKeyboardItemBackgroundColor cellSelectedColor tableCellSelectedBackgroundColor
    static var bg4Color: UIColor { get } // translateBackgroundColor tableCell2SelectedBackgroundColor
    static var bg5Color: UIColor { get }
    static var bgdisableColor: UIColor { get } // buttonDisableColor tableView2SeparatorColor
    static var bgtooltipColor: UIColor { get } // middleGrayColor
    static var bgmodalColor: UIColor { get }
    static var bgpopupColor: UIColor { get } // tableSettingCellBackgroundColor
    static var bgelevateColor: UIColor { get } // blankBackgroundColor
    static var bgskyColor: UIColor { get } // bubleOutgoingBackgroundColor
    static var bgspaceColor: UIColor { get }
    static var defaultColor: UIColor { get }
    static var bgpagePrimaryColor: UIColor { get }
    static var bgpageSecondaryColor: UIColor { get }
    
    // MARK: Other Style
    static var barStyle: UIBarStyle { get }
    static var barBlurEffect: UIBlurEffect { get }
    static var keyboardAppearance: UIKeyboardAppearance { get }
    static var accentBlueColor: UIColor { get }
}
