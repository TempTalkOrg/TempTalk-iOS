//
//  DTPIPView.swift
//  Signal
//
//  Created by Ethan on 12/01/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import TTMessaging
import TTServiceKit

@objcMembers
public class DTPIPView: UIView {
    
    private var displayItem: DTMultiChatItemModel?
    var speakingItem: DTMultiChatItemModel? {
        willSet {
            guard let newValue else {
                DispatchMainThreadSafe { [self] in
                    if let speakingItem {
                        if speakingItem.isSharing {
                            if speakingItem.isMute {
                                speakingAnimation.state = .muted
                            } else {
                                if speakingItem.isSpeaking {
                                    speakingAnimation.state = .speaking
                                } else {
                                    speakingAnimation.state = .unmuted
                                }
                            }
                        } else {
                            speakingAnimation.state = speakingItem.isMute ? .muted : .unmuted
                            updateToSharing()
                        }
                    } else {
                        guard let displayItem else {
                            return
                        }
                        if displayItem.isSharing {
                            
                            guard let sharingItem = DTMeetingManager.shared.fetchSharingItem() else {
                                return
                            }
                            setNewSpeakingItem(sharingItem)
                        } else {
                            speakingAnimation.state = displayItem.isMute ? .muted : .unmuted
                        }
                    }
                }

                return
            }
                   
            stopTimer()
            setNewSpeakingItem(newValue)
        }
    }
    
    private let viewSize = CGSize(width: 120, height: 90)
    private var avatarSize: CGFloat {
        return max(viewSize.height / 2, 56.0)
    }
    private let topMargin = 50.0
    private let leftMargin = 25.0
    private let margin = 15.0
    private var touchPoint: CGPoint = .zero
    private var s_constraints = [NSLayoutConstraint]()
    private var avatarView: AvatarImageView!
    
    private var userView: UIStackView!
    private var lbName: UILabel!
    private var shareIcon: UIImageView!
    private var videoView: UIView!
    
    private var countDownMaskView: UIView!
    private var countDownView: SwingingAlarmView!
    
    private lazy var speakingAnimation: DTSpeakingAnimationView = {
        let speakingAnimation = DTSpeakingAnimationView(iconColor: nil)
        speakingAnimation.state = .unmuted
        speakingAnimation.autoSetDimension(.width, toSize: 16)
        speakingAnimation.setCompressionResistanceHigh()
        return speakingAnimation
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.darkThemeNavbarBackgroundColor
        layer.cornerRadius = 8
        layer.masksToBounds = true
        isUserInteractionEnabled = true
        setContentHuggingHigh()
        autoSetDimensions(to: viewSize)
        
        avatarView = AvatarImageView()
        addSubview(avatarView)
        
//        videoView = UIView()
//        addSubview(videoView)
        
        countDownMaskView = UIView()
        countDownMaskView.backgroundColor = UIColor(rgbHex: 0x181A20)
        countDownMaskView.alpha = 0.8
        countDownMaskView.layer.cornerRadius = 4
        countDownMaskView.layer.masksToBounds = true
        countDownMaskView.isHidden = true
        addSubview(countDownMaskView)
        
        countDownView = SwingingAlarmView()
        countDownMaskView.addSubview(countDownView)
        
        lbName = UILabel()
        lbName.backgroundColor = .clear
        lbName.textAlignment = .center
        lbName.textColor = .white
        lbName.font = .systemFont(ofSize: 12)
        
        let spacer1 = UIView(), spacer2 = UIView()
        spacer1.autoSetDimension(.width, toSize: 2)
        spacer2.autoSetDimension(.width, toSize: 2)
        
        shareIcon = UIImageView(image: #imageLiteral(resourceName: "ic_call_sharing"))
        shareIcon.contentMode = .center
        shareIcon.isHidden = true
        shareIcon.setCompressionResistanceHigh()
        
        userView = UIStackView(arrangedSubviews: [spacer1, shareIcon, speakingAnimation, lbName, spacer2])
        userView.axis = .horizontal
        userView.backgroundColor = UIColor(rgbHex: 0x181A20).withAlphaComponent(0.8)
        userView.spacing = 2
        userView.layer.masksToBounds = true
        userView.layer.cornerRadius = 4
        userView.isUserInteractionEnabled = false
        
        addSubview(userView)
        
        avatarView.autoSetDimensions(to: CGSize(square: avatarSize))
        avatarView.autoCenterInSuperview()
        
//        videoView.autoPinEdgesToSuperviewEdges()
        
        userView.autoPinEdge(toSuperviewEdge: .leading, withInset: 4)
        userView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 4, relation: .greaterThanOrEqual)
        userView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 4)
        userView.autoSetDimension(.height, toSize: 24)
        
        countDownMaskView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 4)
        countDownMaskView.autoPinEdge(toSuperviewEdge: .top, withInset: 4)
        countDownMaskView.autoSetDimension(.height, toSize: 24)
        // 同样可以指定最小宽度
        countDownMaskView.autoSetDimension(.width, toSize: 60, relation: .greaterThanOrEqual)
        
        countDownView.autoPinEdgesToSuperviewEdges(with: .init(top: 0, left: 3, bottom: 0, right: 3))
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        Logger.debug("deinit.")
        NSLayoutConstraint.deactivate(s_constraints)
        s_constraints.removeAll()
        stopTimer()
    }
    
    @objc
    func updatePipViewCountDown() {
        countDownMaskView.isHidden = !TimerDataManager.shared.isShowCountDownView
        countDownView.isHidden = !TimerDataManager.shared.isShowCountDownView
        countDownView.imageName = TimerDataManager.shared.imageName
        countDownView.message = TimerDataManager.shared.displayTime
        countDownView.textColor = TimerDataManager.shared.textColor
        if TimerDataManager.shared.isShaking {
            countDownView.startSwinging()
        } else {
            countDownView.stopSwinging()
        }
        
        if TimerDataManager.shared.isVibrating {
            countDownView.startVibrating()
        } else {
            countDownView.stopVibrating()
        }
    }
    
    @objc
    func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let superview = superview else {
            return
        }
        
        let location = pan.location(in: superview)
        switch pan.state {
        case .began: 
            touchPoint = location
            break
        case .changed, .cancelled, .failed:
            var frame = self.frame
            frame.x = self.frame.x + location.x - touchPoint.x
            frame.y = self.frame.y + location.y - touchPoint.y
            if frame.x < 0 {
                frame.x = 0
            } else if frame.x >= superview.width - viewSize.width {
                frame.x = superview.width - viewSize.width
            }
            if frame.y < 0 {
                frame.y = 0
            } else if frame.y >= min(screenWidth, screenHeight) - viewSize.height {
                frame.y = min(screenWidth, screenHeight) - viewSize.height
            }
            touchPoint = location
            self.frame = frame
            if !s_constraints.isEmpty {
                NSLayoutConstraint.deactivate(s_constraints)
            }
            s_constraints.append(autoPinEdge(toSuperviewEdge: .leading, withInset: frame.x))
            s_constraints.append(autoPinEdge(toSuperviewEdge: .top, withInset: frame.y))
            break
        case .ended:
            var targetX: CGFloat = 0, targetY: CGFloat = 0
            if center.x >= superview.width/2 {
                targetX = superview.width - viewSize.width - margin
            } else {
                targetX = margin
            }
            if frame.y < margin {
                targetY = margin
            } else if frame.maxY >= min(screenWidth, screenHeight) {
                targetY = min(screenWidth, screenHeight) - viewSize.height - margin
            } else {
                targetY = self.frame.y
            }
            
            if !s_constraints.isEmpty {
                NSLayoutConstraint.deactivate(s_constraints)
            }
            s_constraints.append(autoPinEdge(toSuperviewEdge: .leading, withInset: targetX))
            s_constraints.append(autoPinEdge(toSuperviewEdge: .top, withInset: targetY))

            UIView.animate(withDuration: 0.3) { [self] in
                frame = CGRectMake(targetX, targetY, viewSize.width, viewSize.height)
                layoutIfNeeded()
            }

            break
        default: break
        }
    }
    
    func addToSuperview(_ superview: UIView) {
        
        superview.addSubview(self)
        s_constraints.append(autoPinEdge(toSuperviewEdge: .top, withInset: topMargin))
        s_constraints.append(autoPinEdge(toSuperviewEdge: .leading , withInset: leftMargin))
    }
    
    func setNewSpeakingItem(_ newValue: DTMultiChatItemModel) {
        
        guard let account = newValue.account else {
            return
        }
        displayItem = newValue

        let uid = account.transforUserAccountToCallNumber()
        let displayName = newValue.displayName ?? uid

        DispatchMainThreadSafe { [self] in
            if let account = newValue.account, account.hasPrefix(MeetingAccoutPrefix_Web) {
                let colorName = TSThread.stableConversationColorName(for: account)
                let color = UIColor.ows_conversationColor(colorName: colorName)!
                avatarView.image = OWSContactAvatarBuilder(
                    name: displayName,
                    color: color,
                    diameter: UInt(viewSize.height)/2).buildImageForTemporary()
            } else {
                avatarView.setImageWithRecipientId(uid, displayName: displayName)
            }
            lbName.text = newValue.displayName ?? newValue.recipientId
            shareIcon.isHidden = !newValue.isSharing
            
            if newValue.isMute {
                speakingAnimation.state = .muted
            } else {
                if newValue.isSpeaking {
                    speakingAnimation.state = .speaking
                } else {
                    speakingAnimation.state = .unmuted
                }
            }
            
//            if let speakingItem, speakingItem.account == newValue.account {
//                if !newValue.isVideoEnable, !videoView.subviews.isEmpty {
//                    videoView.removeAllSubviews()
//                }
//                return
//            }
//            
//            if !videoView.subviews.isEmpty {
//                videoView.removeAllSubviews()
//            }
//            
//            if newValue.isVideoEnable,
//                let account = newValue.account,
//                let renderView = DTRenderViewManager.shareManager.renderView(account: account) {
//                renderView.isHidden = false
//                videoView.addSubview(renderView)
//                renderView.autoPinEdgesToSuperviewEdges()
//            }
            
            // 筛选出对应的participant对象
            DTMeetingManager.shared.updateVideoView(item: newValue, containView: self, aboveView: avatarView)
        }
    }
    
    ///画中画没人讲话后3秒再切换到share user
    private var timer: Timer?
    
    func updateToSharing() {
        
        if timer != nil { stopTimer() }
        
        var seconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            guard let self else {
                self?.stopTimer()
                return
            }
            seconds += 1
            if seconds >= 3 {
                stopTimer()
               
                guard let sharingItem = DTMeetingManager.shared.fetchSharingItem() else {
                    return
                }

                setNewSpeakingItem(sharingItem)
            }
        })
        
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    func stopTimer() {
        guard let timer else { return }
        
        timer.invalidate()
        self.timer = nil
    }
    
}
