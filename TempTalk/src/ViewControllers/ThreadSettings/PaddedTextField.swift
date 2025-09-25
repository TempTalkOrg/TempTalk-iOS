//
//  PaddedTextField.swift
//  Difft
//
//  Created by Kris.s on 2025/4/18.
//  Copyright © 2025 Difft. All rights reserved.
//


import UIKit

@objc(TTPaddedTextField)
@objcMembers
class PaddedTextField: UITextField {

    // 默认内边距
    private var textInsets: UIEdgeInsets = .zero

    // 提供 ObjC 可调用的设置方法
    func setTextPadding(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        textInsets = UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
        setNeedsDisplay()
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.inset(by: textInsets)
    }
}

