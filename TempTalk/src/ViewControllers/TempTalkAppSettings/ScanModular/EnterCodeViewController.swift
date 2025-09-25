//
//  EnterCodeViewController.swift
//  TempTalk
//
//  Created by Kris.s on 2025/1/8.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

final class EnterCodeViewController: SettingBaseViewController {
    
    static let stepTextFieldWidth = 180.0
    
    var myCodeBarBtnItem: UIBarButtonItem {
        let barButtonItem = UIBarButtonItem.init(title: Localized("ENTER_CODE_MYCODE"),
                                                 style: .plain,
                                                 target: self,
                                                 action: #selector(myCodeAction))
        return barButtonItem
    }
    
    fileprivate lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.text = Localized("ENTER_CODE_TITLE")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        return titleLabel
    }()
    
    fileprivate lazy var tipsLabel: UILabel = {
        let tipsLabel = UILabel()
        tipsLabel.textAlignment = .center
        tipsLabel.text = Localized("ENTER_CODE_TIPS")
        tipsLabel.font = UIFont.systemFont(ofSize: 14)
        return tipsLabel
    }()
    
    fileprivate lazy var codeTextField: CustomNumberInputView = {
        let codeTextField = CustomNumberInputView(frame: CGRectMake(0, 0, Self.stepTextFieldWidth, kTextFiledHeight))
        codeTextField.onInputComplete = {[weak self] code in
            if !code.isEmpty, code.count == 4 {
               //next
                guard let linkUrl = self?.generateLinkUrl(inviteCode: code),
                      let url = URL(string: linkUrl)else {
                    return
                }
                _ = AppLinkManager.handle(url: url, fromExternal: true)
            }
        }
        return codeTextField
    }()
    
    func generateLinkUrl(inviteCode: String) -> String? {
        
        
        let inviteUrl = "https://\(AppLinkNotificationHandler.kURLHostTempTalk)\(AppLinkNotificationHandler.kULinkPathInvite)?a=pi&pi=\(inviteCode)"
                
        return inviteUrl
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.async {
            self.setupView()
            self.setupLayout()
            self.applyTheme()
        }
    }
    
    deinit {
        OWSLogger.info("enter code view deinit.")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        codeTextField.showFirstResponder()
    }
    
    private func setupView() {
        self.navigationItem.rightBarButtonItem = myCodeBarBtnItem
        view.addSubview(titleLabel)
        view.addSubview(tipsLabel)
        view.addSubview(codeTextField)
    }
    
    private func previousViewIsInviteCode() -> Bool {
        return self.navigationController?.viewControllers.first as? DTInviteCodeViewController != nil
    }
    
    private func setupLayout() {
        
        if previousViewIsInviteCode() {
            titleLabel.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(20 + 44)
                make.centerX.equalToSuperview()
                make.height.equalTo(28)
            }
        } else {
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(20)
                make.centerX.equalToSuperview()
                make.height.equalTo(28)
            }
        }
        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.centerX.equalToSuperview()
            make.height.equalTo(20)
        }
        codeTextField.snp.makeConstraints { make in
            make.top.equalTo(tipsLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.height.equalTo(kTextFiledHeight)
            make.width.equalTo(Self.stepTextFieldWidth)
        }
    }
    
    override func applyTheme() {
        super.applyTheme()
        self.view.backgroundColor = Theme.defaultBackgroundColor
        tipsLabel.textColor = Theme.primaryTextColor
    }
    
    @objc func myCodeAction() {
        if previousViewIsInviteCode() {
            self.navigationController?.popViewController(animated: true, completion: nil)
        } else {
            let inviteCodeViewController = DTInviteCodeViewController()
            let navigationCtr = UINavigationController(rootViewController: inviteCodeViewController)
            self.navigationController?.present(navigationCtr, animated: true)
        }
    }
    
}
