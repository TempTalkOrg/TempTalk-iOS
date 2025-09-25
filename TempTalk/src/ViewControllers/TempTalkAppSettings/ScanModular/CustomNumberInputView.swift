//
//  Untitled.swift
//  Difft
//
//  Created by Kris.s on 2025/1/8.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit

protocol EmptyDeleteTextFieldDelegate: AnyObject {
    func textFieldDidDeleteBackward(_ textField: EmptyDeleteTextField)
}

class EmptyDeleteTextField: UITextField {
    
    // 定义一个 delegate 属性
    weak var emptyDeleteDelegate: EmptyDeleteTextFieldDelegate?
    
    override func deleteBackward() {
        // 调用 delegate 方法，通知外部删除操作
        emptyDeleteDelegate?.textFieldDidDeleteBackward(self)
        super.deleteBackward()
    }
}


class CustomNumberInputView: UIView {
    
    // 配置
    var numberCount: Int = 4  // 默认6个数字
    var space: CGFloat = 12   // 数字间的间距
    var numberWidth: CGFloat = 36   // 每个数字的宽度
    var numberHeight: CGFloat = 48  // 每个数字的高度
    var numberFont: UIFont = UIFont.boldSystemFont(ofSize: 24) // 数字字体
    
    // 事件回调：输入完成时
    var onInputComplete: ((String) -> Void)?  // 现在传递完整的输入内容
    
    var replacementString: String?
    
    private var textFields: [UITextField] = []  // 存储所有的输入框
    
    // 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // 创建输入框
        for i in 0..<numberCount {
            
            let textField = EmptyDeleteTextField()
            textField.borderStyle = .none
            textField.layer.borderWidth = 1
            textField.layer.borderColor = (Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x474D57) : UIColor(rgbHex: 0xEAECEF)).cgColor
            textField.layer.cornerRadius = 4
            textField.tintColor = UIColor.color(rgbHex: 0x056FFA)
            textField.textColor = Theme.primaryTextColor
            textField.textAlignment = .center
            textField.font = numberFont
            textField.keyboardType = .numberPad
            textField.delegate = self
            textField.emptyDeleteDelegate = self
            textField.tag = i  // 每个输入框一个tag，方便管理
            
            // 设置输入框的frame
            let x = CGFloat(i) * (numberWidth + space)
            textField.frame = CGRect(x: x, y: 0, width: numberWidth, height: numberHeight)
            textField.text = ""
            
            // 添加到父视图
            self.addSubview(textField)
            textFields.append(textField)
        }
    }
    
    // 设置数字的个数
    func setNumberCount(_ count: Int) {
        numberCount = count
        for textField in textFields {
            textField.removeFromSuperview()
        }
        textFields.removeAll()
        setupView()
    }
    
    // 获取输入的内容
    func getInput() -> String {
        return textFields.compactMap { $0.text }.joined()
    }
    
    func showFirstResponder() {
        guard replacementString == nil else{
            return
        }
        textFields.first?.becomeFirstResponder()
    }
    
}

extension CustomNumberInputView: UITextFieldDelegate, EmptyDeleteTextFieldDelegate{
    
    // 每个输入框只能输入一个字符
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if string.count == 1,
           textField.text?.count == 1,
           textField.tag == numberCount - 1 {
            return false
        }
        
        replacementString = string
        if textField.text?.count == 1,
           !string.isEmpty {
            textField.text = ""
        }
        return true
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        
        // 如果输入框已满，跳到下一个输入框
        if textField.text?.count == 1 {
            if let nextField = textFields.first(where: { $0.tag == textField.tag + 1 }) {
                nextField.becomeFirstResponder()
            }
        }
        
        // 检查是否输入完成，即所有数字框都已输入
        if textFields.allSatisfy({ ($0.text?.count ?? 0) > 0 }) {
            // 达到numberCount个输入时，触发输入完成事件并传递完整的输入内容
            let input = getInput()
            onInputComplete?(input)
        }
    }
    
    func textFieldDidDeleteBackward(_ textField: EmptyDeleteTextField) {
        // 如果当前框为空，跳到上一个框
        if textField.text?.isEmpty ?? true, let previousField = textFields.first(where: { $0.tag == textField.tag - 1 }) {
            previousField.text = ""
            previousField.becomeFirstResponder()
        }
        
        textFields.filter { $0.tag > textField.tag }.forEach { nextField in
            nextField.text = ""
        }
    }
}
