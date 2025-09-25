//
//  LoginViewController.swift
//  TempTalk
//
//  Created by undefined on 20/12/24.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc class LoginViewController: OWSViewController, UITextViewDelegate {
    
    private let window = UIApplication.shared.delegate?.window
    private let legalPolicyURL = "https://temptalk.app/legal.html"
    
    // MARK: lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createViews()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func applyTheme() {
        view.backgroundColor = Theme.backgroundColor
        
        loginTipLabel.textColor = Theme.secondaryTextColor
    }
    
    // MARK: action
    @objc func signupButtonTapped() {
//        navigationController?.pushViewController(, animated: true)
        let profile = DTSettingEditProfileController(editProfileType: .signup)
        navigationController?.pushViewController(profile, animated: true)
    }
    
    @objc func loginbuttonTapped() {
        if let window = window {
            let loginVC = OWSNavigationController(rootViewController: DTSignChativeController())
            window?.rootViewController = loginVC
        } else {
            Logger.error("no window")
        }
    }
    
    private func createViews() {
        // center.y - 132
        let containerView = UIView()
        view.addSubview(containerView)
        containerView.autoPinWidthToSuperview()
        containerView.autoPinEdge(toSuperviewSafeArea: .top, withInset:window??.safeAreaInsets.top ?? 0)
//        containerView.autoAlignAxis(.horizontal, toSameAxisOf: view, withOffset: -132)
        
        containerView.addSubview(logoImageView)
        logoImageView.autoPinEdge(toSuperviewEdge: .top)
        logoImageView.autoHCenterInSuperview()
        
        containerView.addSubview(signupButton)
        signupButton.autoPinEdge(.top, to: .bottom, of: logoImageView, withOffset: 48)
        signupButton.autoPinLeadingToSuperviewMargin(withInset: 8)
        signupButton.autoPinTrailingToSuperviewMargin(withInset: 8)
        signupButton.autoSetDimension(.height, toSize: 48)
        
        let loginHStackView = UIStackView()
        loginHStackView.axis = .horizontal
        loginHStackView.spacing = 4
        loginHStackView.addArrangedSubviews([loginTipLabel, loginButton])
        containerView.addSubview(loginHStackView)
        loginHStackView.autoPinEdge(.top, to: .bottom, of: signupButton, withOffset: 24)
        loginHStackView.autoPinBottomToSuperviewMargin()
        loginHStackView.autoHCenterInSuperview()
        
        view.addSubview(userPolicyTextView)
        userPolicyTextView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        userPolicyTextView.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        userPolicyTextView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 50)
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.absoluteString == legalPolicyURL {
            let webVC = LoginPolicyWebController(urlString: legalPolicyURL)
            navigationController?.pushViewController(webVC, animated: true)
            return false
        }
        return true
    }
    
    private lazy var logoImageView: UIImageView = {
        let logoImageView = UIImageView()
        logoImageView.image = UIImage(named: "login_logo")
        logoImageView.autoSetDimensions(to: CGSize(square: 160))
        return logoImageView
    }()
    
    private lazy var signupButton: UIButton = {
        let signupButton = UIButton()
        signupButton.backgroundColor = .ows_themeBlue
        signupButton.setTitle("Sign up", for: .normal)
        signupButton.titleLabel?.textColor = .ows_white
        signupButton.layer.cornerRadius = 8
        signupButton.layer.masksToBounds = true
        signupButton.addTarget(self, action: #selector(signupButtonTapped), for: .touchUpInside)
        return signupButton
    }()
    
    private lazy var loginTipLabel: UILabel = {
        let loginTipLabel = UILabel()
        loginTipLabel.font = .systemFont(ofSize: 14)
        loginTipLabel.textColor = Theme.secondaryTextColor
        loginTipLabel.text = "Already have an account?"
        return loginTipLabel
    }()
    
    private lazy var loginButton: UIButton = {
        let loginButton = UIButton()
        loginButton.backgroundColor = .clear
        loginButton.setTitle("Log In", for: .normal)
        loginButton.setTitleColor(.ows_themeBlue, for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 14)
        loginButton.contentEdgeInsets = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        loginButton.addTarget(self, action: #selector(loginbuttonTapped), for: .touchUpInside)
        return loginButton
    }()
    
    private lazy var userPolicyTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.delegate = self
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textAlignment = .center
        
        let fullText = "\(Localized("LOGIN_BOTTOM_TIPS_FRONT"))\(Localized("LOGIN_BOTTOM_TIPS_BACKEND"))"
        let attributedString = NSMutableAttributedString(string: fullText)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        attributedString.addAttributes([
            .paragraphStyle: paragraphStyle,
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ], range: NSRange(location: 0, length: fullText.count))

        // 添加超链接并去除下划线
        let linkStyle: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: 0
        ]
        
        if let range = fullText.range(of: Localized("LOGIN_BOTTOM_TIPS_BACKEND")) {
            let nsRange = NSRange(range, in: fullText)
            attributedString.addAttribute(.link, value: legalPolicyURL, range: nsRange)
            attributedString.addAttributes(linkStyle, range: nsRange)
        }
        textView.attributedText = attributedString
        
        return textView
    }()
    
    
}
