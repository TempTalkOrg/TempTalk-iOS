//
//  DTPasscodeSuccessViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class DTPasscodeSuccessViewController: DTScreenLockBaseViewController {
    
    public override func setupUI() {
        logoIconImageView.image = UIImage(named: "screenLock_success")
        titleLabel.text = Localized("SCREENLOCK_PASSCODESUCCESS_TITLE", comment: "")
        tipsLabel.text = Localized("SCREENLOCK_PASSCODESUCCESS_TIPS", comment: "")
        doneButton.setTitle(title: Localized("SCREENLOCK_PASSCODESUCCESS_CONFIRM", comment: ""), font: OWSFlatButton.orignalFontForHeight(16), titleColor: UIColor.white)
        doneButton.setEnabled(true)
        
        view.addSubview(logoIconImageView)
        view.addSubview(titleLabel)
        view.addSubview(tipsLabel)
        view.addSubview(doneButton)
    }
    
    public override func autolayout() {
        
        logoIconImageView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 88)
        logoIconImageView.autoSetDimensions(to: CGSize(width: 48, height: 48))
        logoIconImageView.autoHCenterInSuperview()
        
        titleLabel.autoPinEdge(.top, to: .bottom, of: logoIconImageView, withOffset: 10)
        titleLabel.autoHCenterInSuperview()
        
        tipsLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 32)
        tipsLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
        tipsLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
        tipsLabel.autoHCenterInSuperview()
        
        doneButton.autoPinEdge(.top, to: .bottom, of: tipsLabel, withOffset: 48)
        doneButton.autoPinEdge(.left, to: .left, of: view, withOffset: 24)
        doneButton.autoPinEdge(.right, to: .right, of: view, withOffset: -24)
        doneButton.autoSetDimension(.height, toSize: 48)
    }
    
    @objc public override func doneButtonClick() {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        doneCallback(nil)
    }
    
}
