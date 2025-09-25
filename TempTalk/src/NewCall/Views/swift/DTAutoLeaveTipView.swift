//
//  DTAutoLeaveTipView.swift
//  Signal
//
//  Created by Felix on 2022/8/26.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging

@objc class DTAutoLeaveTipView: UIView {
    
    var autoLeaveTimer: Timer?
    
    private let containerView: UIView = {
        let containerView = UIView()
        containerView.backgroundColor = UIColor(rgbHex: 0x191919)
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        
        return containerView
    }()
    
    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = Theme.darkThemePrimaryColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.font = UIFont.systemFont(ofSize: 15)
        
        return titleLabel
    }()
    
    private let detailLabel: UILabel = {
        let detailLabel = UILabel()
        detailLabel.textColor = Theme.darkThemePrimaryColor
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        detailLabel.font = UIFont.systemFont(ofSize: 15)
        detailLabel.text = Localized("MEETING_GROUP_AUTO_LEAVE_DESC")
        //Localized("MEETING_AUTO_LEAVE_TIP", comment: "AUTO LEAVE Detail");
        
        return detailLabel
    }()
    
    private let hSeplineLabel: UIView = {
        let hSeplineLabel = UIView()
        hSeplineLabel.backgroundColor = Theme.cellSeparatorColor
        
        return hSeplineLabel
    }()
    
    private let vSepartor: UIView = {
        let vSepartor = UIView()
        vSepartor.backgroundColor = Theme.cellSeparatorColor
        
        return vSepartor
    }()
    
    lazy var btnLeave: UIButton = {
        let btnLeave = UIButton()
        btnLeave.setTitleColor(UIColor(rgbHex: 0xF84035), for: .normal)
        btnLeave.setTitle("Leave", for: .normal)
        btnLeave.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        btnLeave.addTarget(self, action: #selector(btnLeaveAction), for: .touchUpInside)
        
        return btnLeave
    }()
    
    lazy var confirmBtn: UIButton = {
        let confirmBtn = UIButton()
        confirmBtn.setTitleColor(.ows_accentBlueDark, for: .normal)
        confirmBtn.setTitle("Continue", for: .normal)
        confirmBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        confirmBtn.addTarget(self, action: #selector(confirmAction), for: .touchUpInside)
        
        return confirmBtn
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    public typealias Block = () -> Void
    var confirmBlock: Block? = nil
    var timeoutBlock: Block? = nil
    
    @objc init(confirmBlock: Block?, timeoutBlock: Block?) {
        super.init(frame: CGRect.zero)
        
        setupUI()
        
        self.confirmBlock = confirmBlock
        self.timeoutBlock = timeoutBlock
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        self.backgroundColor = UIColor.ows_blackAlpha40
    
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(detailLabel)
        containerView.addSubview(hSeplineLabel)
        containerView.addSubview(vSepartor)
        containerView.addSubview(btnLeave)
        containerView.addSubview(confirmBtn)
        
        containerView.autoCenterInSuperview()
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let containerWidth = min(screenWidth, screenHeight) - 100
        containerView.autoSetDimension(.width, toSize: containerWidth)
//        containerView.autoPinEdge(toSuperviewEdge: .leading, withInset: 50)
//        containerView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 50)
        
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 20)
        titleLabel.autoPinLeadingToSuperviewMargin()
        titleLabel.autoPinTrailingToSuperviewMargin()
        
        detailLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 10)
        detailLabel.autoPinEdge(toSuperviewEdge: .leading, withInset: 20)
        detailLabel.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20)

        hSeplineLabel.autoPinEdge(.top, to: .bottom, of: detailLabel, withOffset: 10)
        hSeplineLabel.autoPinEdge(toSuperviewEdge: .leading)
        hSeplineLabel.autoPinEdge(toSuperviewEdge: .trailing)
        hSeplineLabel.autoSetDimension(.height, toSize: 1/UIScreen.main.scale)
        
        btnLeave.autoPinEdge(.top, to: .bottom, of: hSeplineLabel)
        btnLeave.autoPinEdge(toSuperviewEdge: .leading)
        btnLeave.autoPinEdge(toSuperviewEdge: .bottom)
        btnLeave.autoSetDimension(.height, toSize: 44)
        
        vSepartor.autoPinEdge(.top, to: .top, of: btnLeave)
        vSepartor.autoPinEdge(.leading, to: .trailing, of: btnLeave)
        vSepartor.autoMatch(.height, to: .height, of: btnLeave)
        vSepartor.autoSetDimension(.width, toSize: 1/UIScreen.main.scale)

        confirmBtn.autoPinEdge(.top, to: .top, of: btnLeave)
        confirmBtn.autoMatch(.width, to: .width, of: btnLeave)
        confirmBtn.autoMatch(.height, to: .height, of: btnLeave)
        confirmBtn.autoPinEdge(.leading, to: .trailing, of: vSepartor)
        confirmBtn.autoPinEdge(.bottom, to: .bottom, of: btnLeave)
        confirmBtn.autoPinEdge(toSuperviewEdge: .trailing)
    }
    
    // MARK: action
    
    @objc func confirmAction() {
        stopTimeoutTimer()
        
        guard let block = confirmBlock else { return }
        
        block()
    }
    
    @objc func btnLeaveAction() {
        stopTimeoutTimer()
        
        guard let timeoutBlock else { return }
        
        timeoutBlock()
    }
    
    @objc func updateTipsLabel(_ isSoloMember: Bool) {
        if isSoloMember {
            detailLabel.text = Localized("MEETING_CONTACT_AUTO_LEAVE_DESC")
        } else {
            detailLabel.text = Localized("MEETING_GROUP_AUTO_LEAVE_DESC")
        }
    }

}

extension DTAutoLeaveTipView {
    
    @objc func startTimeoutTimer(_ timeInterval: UInt) {
        self.stopTimeoutTimer()
        
        Logger.debug("[call] ------ start")
        
        let timeout: AtomicUInt = AtomicUInt(timeInterval, lock: .init())
        let timeoutCount = timeout.get()
        self.titleLabel.text = "\(timeoutCount)s left"
        
        self.autoLeaveTimer = WeakTimer.scheduledTimer(timeInterval: 1, target: self, userInfo: nil, repeats: true, action: { [weak self] timer in
            guard let self else { return }
            
            timeout.decrementOrZero()
            
            let tCount = timeout.get()
            
            self.titleLabel.text = "\(tCount)s left"
            
//            Logger.debug("[call] ------ \(tCount)s left")
            
            if tCount == 0, let timeoutBlock = self.timeoutBlock {
                timeoutBlock()
                self.stopTimeoutTimer()
            }
        })
    }
    
    @objc func stopTimeoutTimer() {
        Logger.debug("[call] ------ stop")
        
        self.autoLeaveTimer?.invalidate()
        self.autoLeaveTimer = nil
    }
}
