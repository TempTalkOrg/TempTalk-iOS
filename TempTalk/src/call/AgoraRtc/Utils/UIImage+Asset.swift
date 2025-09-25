//
//  UIImage+Asset.swift
//  Singnal
//
//  Created by Felix on 2021/9/17.
//

/*
https://github.com/AliSoftware/SwiftGen 在电脑上安装这个工具，自动生成 Asset 的 image enum 的 Extension

CLI 切换到：./TSWeChat/Resources
命令：swiftgen images Media.xcassets
*/


typealias TSAsset = UIImage.Asset

import Foundation
import UIKit

extension UIImage {
    enum Asset : String {
        case MessageRightTopBg = "MessageRightTopBg"
        case Contacts_add_newmessage = "contacts_add_newmessage"
        case Floataction_scan = "floataction_scan"
        case Floataction_add_contacts = "floataction_add_contacts"
        case Receipt_payment_icon = "receipt_payment_icon"
        case Barbuttonicon_add = "barbuttonicon_add"
        case Floataction_create_group = "floataction_create_group"
        case Floataction_instant_meeting = "floataction_instant_meeting"
        case Floataction_chat_folder = "floataction_chat_folder"
        case Floataction_qrcode = "floataction_qr"
        var image: UIImage {
            return UIImage(asset: self)
        }
    }
    
    convenience init!(asset: Asset) {
        self.init(named: asset.rawValue)
    }
}





