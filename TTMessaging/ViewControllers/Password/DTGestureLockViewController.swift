//
//  DTGestureLockViewController.swift
//  Difft
//
//  Created by henry on 2025/9/23.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit

let lessConnectPointsNum: Int = 4

class WarnLabel: UILabel {
    private enum WarnState {
        case normal
        case warn
    }

    private var state: WarnState = .normal

    override init(frame: CGRect) {
        super.init(frame: frame)
        textAlignment = .center
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showNormal(with message: String) {
        text = message
        state = .normal
        textColor = PatternLockPalette.current().dotNormalColor
    }

    func showWarn(with message: String) {
        text = message
        state = .warn
        textColor = PatternLockPalette.current().warningColor
        layer.gp_shake()
    }

    func refreshTheme() {
        switch state {
        case .normal:
            textColor = PatternLockPalette.current().dotNormalColor
        case .warn:
            textColor = PatternLockPalette.current().warningColor
        }
    }
}

class DTGestureLockViewController: DTScreenLockBaseViewController {

    let GWidth = UIScreen.main.bounds.width
    let GHeight = UIScreen.main.bounds.height
    let patternWidth: CGFloat = UIScreen.main.bounds.width - 100
    let patternHeight: CGFloat = 300
    let patternX: CGFloat = 50
    
    var lockView: PatternLockView!
    let patternConfig: PatternLockViewConfig = PatternLockConfig()
    
    fileprivate lazy var nameLabel: UILabel = {
        let label = UILabel(frame: CGRect(x: patternX, y: 100 + statusBarHeight(), width: patternWidth, height: 30))
        label.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        label.textAlignment = .center
        return label
    }()

    fileprivate lazy var warnLabel: WarnLabel = {
        let label = WarnLabel(frame: CGRect(x: patternX, y: 164 + statusBarHeight(), width: patternWidth, height: 20))
        label.font = UIFont.systemFont(ofSize: 14)
        return label
    }()
    
    fileprivate lazy var exclamationIcon: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.image = UIImage(named: "passcode_exclamation-circle")
        return imageView
    }()
    
    fileprivate lazy var exclamationLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 0;
        label.text = Localized("SETTINGS_PATTERN_TIPS")
        return label
    }()

    var password: String = ""
    var firstPassword: String = ""
    var secondPassword: String = ""

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        updateSetUI()
    }
    
    func updateSetUI() {
        nameLabel.text = Localized("SETTINGS_CREATE_PATTERN")
        warnLabel.text = Localized("SETTINGS_DRAW_PATTERN")
    }
    
    public override func setupUI() {
        setupSubviews()
    }
    
    public override func autolayout() {
        lockView.autoPinEdge(.left, to: .left, of: self.view, withOffset: patternX)
        lockView.autoPinEdge(.top, to: .top, of: self.view, withOffset: 288 + statusBarHeight())
        lockView.autoSetDimension(.width, toSize: patternWidth)
        lockView.autoSetDimension(.height, toSize: patternHeight)
        
        exclamationIcon.autoPinEdge(.bottom, to: .bottom, of: self.view, withOffset: -100)
        exclamationIcon.autoPinEdge(.left, to: .left, of: self.view, withOffset: 20)
        exclamationIcon.autoSetDimension(.width, toSize: 16)
        exclamationIcon.autoSetDimension(.height, toSize: 20)
        
        exclamationLabel.autoPinEdge(.top, to: .top, of: self.exclamationIcon)
        exclamationLabel.autoPinEdge(.left, to: .right, of: exclamationIcon, withOffset: 8)
        exclamationLabel.autoPinEdge(.right, to: .right, of: self.view, withOffset: -20)
    }
    
    public override func refreshTheme() {
        super.refreshTheme()
        let palette = PatternLockPalette.current()
        exclamationLabel.textColor = palette.dotNormalColor
        warnLabel.refreshTheme()
        lockView?.applyPalette(palette, pathEnabled: ScreenLock.shared.isScreenLockPatternPathEnabled())
    }
    
    @objc override public func doneButtonClick() {
       // 手势没有确认
    }

    deinit {
        Logger.debug("DTGestureLockViewController deinit")
    }

    // MARK: - layout
    func setupSubviews() {
        lockView = PatternLockView(config: patternConfig)
        lockView.delegate = self
        view.addSubview(lockView)
        view.addSubview(nameLabel)
        view.addSubview(warnLabel)
        view.addSubview(exclamationIcon)
        view.addSubview(exclamationLabel)
    }
}

extension DTGestureLockViewController: PatternLockViewDelegate {
    func lockView(_ lockView: PatternLockView, didConnectedGrid grid: any PatternLockGrid) {
        password += grid.identifier
    }
    
    func lockViewShouldShowErrorBeforeConnectCompleted(_ lockView: PatternLockView) -> Bool {
        return true
    }
    
    func lockViewDidConnectCompleted(_ lockView: PatternLockView) {
        if password.count < lessConnectPointsNum {
            nameLabel.text = Localized("SETTINGS_CREATE_PATTERN")
            warnLabel.showWarn(with: Localized("SETTINGS_LEAST_DOTS_PATTERN"))
        } else {
            setPassword()
        }

        password = ""
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait   // 仅竖屏
    }

    override var shouldAutorotate: Bool {
        return false       // 禁止自动旋转
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}

extension DTGestureLockViewController {
    func setPassword() {
        if firstPassword.isEmpty {
            firstPassword = password
            nameLabel.text = Localized("SETTINGS_CONFIRM_PATTERN")
            warnLabel.showNormal(with: Localized("SETTINGS_DRAW_AGAIN_PATTERN"))
        } else {
            secondPassword = password
            if firstPassword == secondPassword {
                DTToastHelper.show(withInfo: Localized("SETTINGS_DRAW_SUCCESS_TOAST"))
                
                guard let passcodeHash = DTScreenLockCrypto().hashPasscode(passcode: firstPassword) else{
                    DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    Logger.error("passcodeHash is empty!")
                    return
                }
                
                ScreenLock.shared.setScreenLockPattern(passcodeHash)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            } else {
                nameLabel.text = Localized("SETTINGS_CONFIRM_PATTERN")
                warnLabel.showWarn(with: Localized("SETTINGS_DRAW_ERROR_PATTERN"))
                DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                    self.nameLabel.text = Localized("SETTINGS_CREATE_PATTERN")
                    self.warnLabel.showNormal(with: Localized("SETTINGS_DRAW_PATTERN"))
                }
                firstPassword = ""
                secondPassword = ""
            }
        }
    }
}

// MARK: - CALayer
extension CALayer {
    public func gp_shake() {
        let keyFrameAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        let s = 16
        keyFrameAnimation.values = [0, s, -s, 0]
        keyFrameAnimation.duration = 0.3
        keyFrameAnimation.repeatCount = 1
        add(keyFrameAnimation, forKey: "shake")
    }
}
