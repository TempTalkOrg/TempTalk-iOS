//
//  DTUnlockScreenViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class DTUnlockScreenViewController: DTScreenLockBaseViewController {
    
    @objc public var salt = ""
    @objc public var verifyToServer = false
    
    let forgotBtn: UIButton = UIButton(type: .custom)
    let switchPasswordBtn: UIButton = UIButton(type: .custom)
    let switchPatternBtn: UIButton = UIButton(type: .custom)
    let seperatorView: UIView = UIView()
    
    var password: String = ""
    let maxRetryCount = 10
    
    let GWidth = UIScreen.main.bounds.width
    let GHeight = UIScreen.main.bounds.height
    let minScreenDimension = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
    let patternWidth: CGFloat = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 100
    let patternHeight: CGFloat = 300
    let patternX: CGFloat = 50
    
    let LogoY = 88
    let LogoH = 160
    let LogoTitlePadding = 10
    let titleH = 28
    let errorTipsH = 31
    let patternErrorPadding = 40
    
    var patternView: PatternLockView!
    let patternConfig: PatternLockViewConfig = PatternLockConfig()
    
    let attemptsThreshold = 5
    
    // 倒计时相关属性
    private var countdownTimer: Timer?
    private var remainingSeconds: Int = 0
    private var isCountdownActive: Bool = false

    public override func setupUI() {
        patternView = PatternLockView(config: patternConfig)
        patternView.delegate = self
        view.addSubview(patternView)
        view.addSubview(logoIconImageView)
        view.addSubview(titleLabel)
        view.addSubview(passcodeField)
        view.addSubview(lineView)
        view.addSubview(errorTipsLabel)
        view.addSubview(doneButton)
        
        switchPasswordBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        switchPasswordBtn.titleLabel?.textAlignment = .right
        switchPasswordBtn.setTitleColor(UIColor.ows_gray45, for: .normal)
        switchPasswordBtn.setTitle(Localized("SCREENLOCK_SETPASSCODE_SWITCH_TIPS"), for: .normal)
        switchPasswordBtn.addTarget(self, action: #selector(switchPasscodeAction), for: .touchUpInside)
        view.addSubview(switchPasswordBtn)
        
        switchPatternBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        switchPatternBtn.titleLabel?.textAlignment = .right
        switchPatternBtn.setTitleColor(UIColor.ows_gray45, for: .normal)
        switchPatternBtn.setTitle(Localized("SCREENLOCK_SETPATTERN_SWITCH_TIPS"), for: .normal)
        switchPatternBtn.addTarget(self, action: #selector(switchPatternAction), for: .touchUpInside)
        view.addSubview(switchPatternBtn)
        
        forgotBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        forgotBtn.setTitleColor(UIColor.ows_gray45, for: .normal)
        forgotBtn.setTitle(Localized("SCREENLOCK_SETPASSCODE_FORGOT_TIPS"), for: .normal)
        forgotBtn.addTarget(self, action: #selector(forgotAction), for: .touchUpInside)
        
        view.addSubview(forgotBtn)
        
        seperatorView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x2B3139) : UIColor.color(rgbHex: 0xEAECEF)
        view.addSubview(seperatorView)
    }
    
    public override func autolayout() {
       // 布局手势
        updateUILayout(with: shouldShowPatternView())
    }

    public override func refreshTheme() {
        super.refreshTheme()

        let hintColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57)
        switchPasswordBtn.setTitleColor(hintColor, for: .normal)
        switchPatternBtn.setTitleColor(hintColor, for: .normal)
        forgotBtn.setTitleColor(hintColor, for: .normal)
        seperatorView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x2B3139) : UIColor.color(rgbHex: 0xEAECEF)

        patternView?.applyPalette(
            PatternLockPalette.current(),
            pathEnabled: ScreenLock.shared.isScreenLockPatternPathEnabled()
        )
    }
    
    func updateUILayout(with shouldShowPattern: Bool) {
        updateSubViews(with: shouldShowPattern)
        updateSubViewsLayout(with: shouldShowPattern)
    }
    
    func updateSubViews(with shouldShowPattern: Bool) {
        let attempts = shouldShowPattern ? ScreenLock.shared.patternAttempts() : ScreenLock.shared.passcodeAttempts()
        let title = shouldShowPattern ? Localized("SCREENLOCK_SETPATTERN_FORGOT_TIPS") : Localized("SCREENLOCK_SETPASSCODE_FORGOT_TIPS")
        forgotBtn.setTitle(title, for: .normal)
        passcodeField.isHidden = shouldShowPattern
        lineView.isHidden = shouldShowPattern
        doneButton.isHidden = shouldShowPattern
        patternView.isHidden = !shouldShowPattern
        let showSwitchButtons = shouldShowSwitchBtn()
        switchPatternBtn.isHidden = !showSwitchButtons || shouldShowPattern
        switchPasswordBtn.isHidden = !showSwitchButtons || !shouldShowPattern
        seperatorView.isHidden = !shouldShowSwitchBtn()
        
        if isCountdownActive && remainingSeconds > 0 {
            updateCountdownText(seconds: remainingSeconds)
            if shouldShowPattern {
                closePatternUserInteractionEnabled()
            } else {
                closePasswordUserInteractionEnabled()
            }
        } else if attempts >= attemptsThreshold {
            if attempts >= self.maxRetryCount - 1 {
                self.errorTipsLabel.text = Localized("SCREENLOCK_ERROR_MORE_TIPS")
                self.errorTipsLabel.isHidden = false
            } else {
//                self.showNextTime(nextAttempts: attempts)
            }
        } else {
            self.errorTipsLabel.isHidden = true
            // 确保交互已恢复
            if shouldShowPattern {
                openPatternUserInteractionEnabled()
            } else {
                openPasswordUserInteractionEnabled()
            }
        }
    }
    
    func updateSubViewsLayout(with shouldShowPattern: Bool) {
        // Deactivate existing constraints for specific views that need layout updates
        let managedSubviews: [UIView] = [
            logoIconImageView,
            titleLabel,
            passcodeField,
            lineView,
            errorTipsLabel,
            doneButton,
            patternView,
            switchPasswordBtn,
            switchPatternBtn,
            forgotBtn,
            seperatorView
        ]

        managedSubviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let constraintsToDeactivate = view.constraints.filter { constraint in
            guard
                let first = constraint.firstItem as? UIView,
                let second = constraint.secondItem as? UIView
            else { return false }
            return managedSubviews.contains(first) || managedSubviews.contains(second)
        }

        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        
        logoIconImageView.autoPinEdge(toSuperviewEdge: .top, withInset: 108)
        logoIconImageView.autoSetDimensions(to: CGSize(width: 160, height: 160))
        logoIconImageView.autoHCenterInSuperview()
        
        titleLabel.autoPinEdge(.top, to: .bottom, of: logoIconImageView, withOffset: 10)
        titleLabel.autoSetDimension(.height, toSize: 28.0)
        titleLabel.autoHCenterInSuperview()
        
        if shouldShowPattern {
            passcodeField.resignFirstResponder()
            
            errorTipsLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 0)
            errorTipsLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
            errorTipsLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
            errorTipsLabel.autoSetDimension(.height, toSize: 31.0)
            errorTipsLabel.autoHCenterInSuperview()
            
            let logoMar = LogoY + LogoH + LogoTitlePadding
            let titleErrorMar = titleH + errorTipsH + patternErrorPadding
            let patternY: CGFloat = CGFloat(logoMar + titleErrorMar)
            patternView.autoPinEdge(.top, to: .top, of: view, withOffset: patternY)
            patternView.autoPinEdge(.left, to: .left, of: view, withOffset: patternX)
            patternView.autoSetDimension(.height, toSize: patternHeight)
            patternView.autoSetDimension(.width, toSize: patternWidth)
            
            if shouldShowSwitchBtn() {
                // switchBtn 在左侧
                switchPatternBtn.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: -60)
                switchPatternBtn.autoSetDimensions(to: CGSize(width: 130, height: 20))
                switchPatternBtn.autoPinEdge(.right, to: .right, of: view, withOffset: -minScreenDimension * 0.5 - 10)
                
                switchPasswordBtn.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: -60)
                switchPasswordBtn.autoSetDimensions(to: CGSize(width: 130, height: 20))
                switchPasswordBtn.autoPinEdge(.right, to: .right, of: view, withOffset: -minScreenDimension * 0.5 - 10)
                
                seperatorView.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: -65)
                seperatorView.autoPinEdge(.left, to: .right, of: switchPasswordBtn, withOffset: 10)
                seperatorView.autoSetDimension(.height, toSize: 12)
                seperatorView.autoSetDimension(.width, toSize: 2)

                // forgotBtn 在右侧
                forgotBtn.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: -60)
                forgotBtn.autoSetDimensions(to: CGSize(width: 118, height: 20))
                forgotBtn.autoPinEdge(.left, to: .right, of: seperatorView, withOffset: 10)
            } else {
                forgotBtn.autoPinEdge(.bottom, to: .bottom, of: view, withOffset: -60)
                forgotBtn.autoHCenterInSuperview()
                forgotBtn.autoSetDimension(.height, toSize: 20)
                forgotBtn.autoSetDimension(.width, toSize: 118)
            }
            
        } else {
            passcodeField.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 24)
            passcodeField.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
            passcodeField.autoPinEdge(.right, to: .right, of: view, withOffset: -12)
            passcodeField.autoSetDimension(.height, toSize: 30.0)
            
            lineView.autoPinEdge(.top, to: .bottom, of: passcodeField, withOffset: 0)
            lineView.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
            lineView.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
            lineView.autoSetDimension(.height, toSize: 1.0/UIScreen.main.scale)
            lineView.autoHCenterInSuperview()
            
            errorTipsLabel.autoPinEdge(.top, to: .bottom, of: lineView, withOffset: 0)
            errorTipsLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
            errorTipsLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
            errorTipsLabel.autoSetDimension(.height, toSize: 31.0)
            errorTipsLabel.autoHCenterInSuperview()
            
            doneButton.autoPinEdge(.top, to: .bottom, of: errorTipsLabel, withOffset: 16)
            doneButton.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
            doneButton.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
            doneButton.autoSetDimension(.height, toSize: 48)
            
            if shouldShowSwitchBtn() {
                // switchBtn 在左测
                switchPatternBtn.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 12)
                switchPatternBtn.autoSetDimensions(to: CGSize(width: 130, height: 20))
                switchPatternBtn.autoPinEdge(.right, to: .right, of: view, withOffset: -minScreenDimension * 0.5 - 10)
                
                switchPasswordBtn.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 12)
                switchPasswordBtn.autoSetDimensions(to: CGSize(width: 130, height: 20))
                switchPasswordBtn.autoPinEdge(.right, to: .right, of: view, withOffset: -minScreenDimension * 0.5 - 10)
                
                seperatorView.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 16)
                seperatorView.autoPinEdge(.left, to: .right, of: switchPatternBtn, withOffset: 10)
                seperatorView.autoSetDimension(.height, toSize: 12)
                seperatorView.autoSetDimension(.width, toSize: 2)

                // forgotBtn 在右侧
                forgotBtn.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 12)
                forgotBtn.autoSetDimensions(to: CGSize(width: 118, height: 20))
                forgotBtn.autoPinEdge(.left, to: .right, of: seperatorView, withOffset: 10)
            } else {
                forgotBtn.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 12)
                forgotBtn.autoHCenterInSuperview()
                forgotBtn.autoSetDimension(.height, toSize: 20)
                forgotBtn.autoSetDimension(.width, toSize: 118)
            }
        }
    }
    
    @objc private func forgotAction() {
        let alertVC = UIAlertController(
            title: Localized("SCREENLOCK_LOGOUT_TITLE_ALERT"),
            message: Localized("SCREENLOCK_LOGOUT_DESCRIPTION_ALERT"),
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: Localized("SETTINGS_VERIFY_EMAIL_NUMBER_CANCEL"), style: .cancel)
        alertVC.addAction(cancelAction)
        
        let confirmAction = UIAlertAction(
                title: Localized("SCREENLOCK_LOGOUT_ACTION"),
                style: .destructive
        ) { _ in
            guard let doneCallback = self.doneCallback else {
                Logger.info("unlockSuccess method not implemented!")
                return
            }
            doneCallback(self.password)
            ScreenLock.shared.clearPasscodeAttempts()
            ScreenLock.shared.clearPatternAttempts()
            self.logoutWithoutClearData()
        }

        alertVC.addAction(confirmAction)
        present(alertVC, animated: true)
    }
    
    func logoutWithoutClearData() {
        LogoutManager.shared.handleKickoutMessage()
    }
    
    @objc private func switchPasscodeAction() {
        // 停止倒计时
        stopCountdown()
        // 恢复交互状态
        openPatternUserInteractionEnabled()
        openPasswordUserInteractionEnabled()
        
        updateUILayout(with: false)
        titleLabel.text = Localized("UNLOCKSCREEN_TITLE", comment: "")
    }
    
    @objc private func switchPatternAction() {
        // 停止倒计时
        stopCountdown()
        // 恢复交互状态
        openPatternUserInteractionEnabled()
        openPasswordUserInteractionEnabled()
        
        updateUILayout(with: true)
        titleLabel.text = Localized("SETTINGS_DRAW_START_PATTERN", comment: "")
    }
    
    private func showNextTime(nextAttempts: Int) {
        //显示下一次的预计时间
        let nextDelay = (nextAttempts - 4) * (nextAttempts - 4)
        errorTipsLabel.text = String(format: Localized("SCREENLOCK_PASSCODESUCCESS_ATTEMPTS"), nextDelay)
        errorTipsLabel.isHidden = false
    }
    
    private func updateCountdownText(seconds: Int) {
        errorTipsLabel.text = String(format: Localized("SCREENLOCK_PASSCODESUCCESS_ATTEMPTS"), seconds)
        errorTipsLabel.isHidden = false
    }
    
    private func startCountdown(delay: Int, isShowPattern: Bool, attempts: Int) {
        stopCountdown()
        remainingSeconds = delay
        isCountdownActive = true
        
        if isShowPattern {
            closePatternUserInteractionEnabled()
        } else {
            closePasswordUserInteractionEnabled()
        }
        
        // 更新初始倒计时文本
        updateCountdownText(seconds: remainingSeconds)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.remainingSeconds -= 1
            if self.remainingSeconds > 0 {
                self.updateCountdownText(seconds: self.remainingSeconds)
            } else {
                self.stopCountdown()
                self.errorTipsLabel.isHidden = true
                
                // 恢复交互
                if isShowPattern {
                    openPatternUserInteractionEnabled()
                } else {
                    openPasswordUserInteractionEnabled()
                    
                }
                if attempts + 1 >= self.maxRetryCount {
                    self.errorTipsLabel.text = Localized("SCREENLOCK_ERROR_MORE_TIPS")
                    self.errorTipsLabel.isHidden = false
                } else {
//                    self.showNextTime(nextAttempts: attempts + 1)
                }
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        remainingSeconds = 0
    }
    
    private func checkShowLoadingView(with isShowPattern: Bool, completion: @escaping () -> Bool) {
        let attempts = isShowPattern ? ScreenLock.shared.patternAttempts() :  ScreenLock.shared.passcodeAttempts()
        let verifyResult = completion()
        if verifyResult {
            self.errorTipsLabel.isHidden = true
            self.stopCountdown()
            if isShowPattern {
                openPatternUserInteractionEnabled()
            } else {
                openPasswordUserInteractionEnabled()
            }
        } else {
            if attempts >= self.maxRetryCount {
                self.errorTipsLabel.text = Localized("SCREENLOCK_ERROR_MORE_TIPS")
                self.errorTipsLabel.isHidden = false
            } else if attempts >= attemptsThreshold {
                let delay = (attempts - 4) * (attempts - 4)
                self.startCountdown(delay: delay, isShowPattern: isShowPattern, attempts: attempts)
            } else {
                self.errorTipsLabel.isHidden = true
            }
        }
    }
    
    private func openPatternUserInteractionEnabled() {
        self.patternView.isUserInteractionEnabled = true
        self.patternView.shouldPatternEnable = false
        self.patternView.reset()
    }
    
    private func closePatternUserInteractionEnabled() {
        self.patternView.shouldPatternEnable = true
        self.patternView.isUserInteractionEnabled = false
    }
    
    private func openPasswordUserInteractionEnabled() {
        self.passcodeField.isEnabled = true
        self.doneButton.setBackgroundColors(upColor: UIColor.ows_signalBrandBlue)
    }
    
    private func closePasswordUserInteractionEnabled() {
        self.passcodeField.isEnabled = false
        self.doneButton.setBackgroundColors(upColor: UIColor.color(rgbHex: 0xEAECEF))
    }
    
    @objc public override func doneButtonClick() {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            let targetHash = ScreenLock.shared.passcode()
            let screenlockCrypto = DTScreenLockCrypto()
            if !verifyToServer {
                self.checkShowLoadingView(with: false) {
                    let result = screenlockCrypto.verifyPasscode(passcode: passcode, targetHash: targetHash)
                    if result {
                        self.passcodeField.resignFirstResponder()
                        doneCallback(passcode)
                        ScreenLock.shared.clearPasscodeAttempts()
                        return true
                    } else {
                        let attempts = ScreenLock.shared.passcodeAttempts()
                        if attempts >= self.maxRetryCount {
                            // 退出登录
                            doneCallback(passcode)
                            ScreenLock.shared.clearPasscodeAttempts()
                            self.logoutWithoutClearData()
                        } else {
                            self.showPasscodeErrorAlert(with: false)
                            self.passcodeField.text = ""
                            ScreenLock.shared.increasePasscodeAttempts()
                        }
                        return false
                    }
                }
            } else {
                
                if(salt.isEmpty){
                    DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    Logger.error(" DTUnlockScreenViewController salt is empty!")
                    return
                }
                
                guard let passcodeHash = screenlockCrypto.hashPasscode(passcode: passcode, salt: salt) else{
                    DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    Logger.error(" DTUnlockScreenViewController passcodeHash is empty!")
                    return
                }
                
                passcodeField.resignFirstResponder()
                doneCallback(passcodeHash)
                
            }
            
        } else {
            let alertController = UIAlertController(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TITLE", comment: ""),
                                                    message: Localized("Passcode length error!",
                                                                       comment: ""),
                                                    preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_OKBTN", comment: ""), style: .default)
            alertController.addAction(okAction)
            self.present(alertController, animated: true)
            
        }
    }
    
    public override func autoSubmit() {
        
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        //大于等于阈值不走自动验证逻辑
        let attempts = ScreenLock.shared.passcodeAttempts()
        if attempts >= attemptsThreshold {
            return
        }
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            let targetHash = ScreenLock.shared.passcode()
            let screenlockCrypto = DTScreenLockCrypto()
            if !verifyToServer {
                let result = screenlockCrypto.verifyPasscode(passcode: passcode, targetHash: targetHash)
                if result {
                    passcodeField.resignFirstResponder()
                    doneCallback(passcode)
                    ScreenLock.shared.clearPasscodeAttempts()
                }
            }
        }
    }
    
    func showPasscodeErrorAlert(with isPattern: Bool) {
        let message = isPattern ? Localized("SCREENLOCK_CONFIRMPATTERN_ERROR_TIPS", comment: "") : Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TIPS", comment: "")
        let alertController = UIAlertController(
            title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TITLE", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        let okAction = UIAlertAction(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_OKBTN", comment: ""), style: .default)
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    public override var shouldAutorotate: Bool {
        return false
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCountdown()
    }
    
    deinit {
        stopCountdown()
    }
    
}

extension DTUnlockScreenViewController: PatternLockViewDelegate {
    public func lockView(_ lockView: PatternLockView, didConnectedGrid grid: any PatternLockGrid) {
        password += grid.identifier
    }
    
    public func lockViewShouldShowErrorBeforeConnectCompleted(_ lockView: PatternLockView) -> Bool {
        return true
    }
    
    public func lockViewDidConnectCompleted(_ lockView: PatternLockView) {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        // 验证的逻辑
        self.checkShowLoadingView(with: true) {
            let savePasswordHash = ScreenLock.shared.screenLockPattern()
            let result = DTScreenLockCrypto().verifyPasscode(passcode: self.password, targetHash: savePasswordHash)
            if result {
                self.passcodeField.resignFirstResponder()
                doneCallback(self.password)
                ScreenLock.shared.clearPatternAttempts()
                self.password = ""
                return true
            } else {
                let attempts = ScreenLock.shared.patternAttempts()
                if attempts >= self.maxRetryCount {
                    // 退出登录
                    doneCallback(self.password)
                    ScreenLock.shared.clearPatternAttempts()
                    self.logoutWithoutClearData()
                } else {
                    self.showPasscodeErrorAlert(with: true)
                    self.passcodeField.text = ""
                    ScreenLock.shared.increasePatternAttempts()
                }
                self.password = ""
                return false
            }
        }
    }
}
