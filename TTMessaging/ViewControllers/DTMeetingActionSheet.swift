//
//  DTMeetingActionSheet.swift
//  SignalMessaging
//
//  Created by Ethan on 2022/11/30.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import SignalServiceKit

@objc
public enum JoinMeetingType: Int {
    case start = 0, join, checkMembers
}

@objc
public class DTMeetingActionSheet: OWSViewController {

    public static var startTitle: String { "Start" }
    public static var joinTitle: String { "Join" }
    public static var startMessage: String { "Ready to start?" }
    
    @objc
    public var startOrJoinMeetingBlock: ( () -> Void )?
    
    private let maxAvatarCount = 4
    
    private let contentView = UIView()
    private let stackView = UIStackView()
    private weak var lbTitle: UILabel!
    private weak var lbMessage: UILabel!
    private weak var loading: UIActivityIndicatorView!
    private weak var btnStart: UIButton!
    
    private var joinType = JoinMeetingType.join

    var height: CGFloat {
        return stackView.height
    }

    @objc
    public override init() {
        super.init()
        modalPresentationStyle = .custom
        transitioningDelegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive), name: .OWSApplicationWillResignActive, object: nil)
    }

    @objc
    public convenience init(title: String? = nil, 
                            message: String? = nil,
                            channelName: String?,
                            joinType: JoinMeetingType = .join,
                            isLiveStream: Bool = false) {
        self.init()
        
        self.joinType = joinType
        createHeader()
        createButtons(joinType: joinType)
        lbTitle.text = title

        switch joinType {
        case .start:
            loading.isHidden = true
            lbMessage.text = DTMeetingActionSheet.startMessage
        case .join:
            joinMeeting(channelName: channelName,
                        title: title,
                        isLiveStream: isLiveStream)
        case .checkMembers:
            checkMembers(channelName: channelName, 
                         title: title,
                         isLiveStream: isLiveStream)
        }
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func applicationWillResignActive() {
        dismiss(animated: true)
    }
    
    func joinMeeting(channelName: String?, 
                     title: String?,
                     isLiveStream: Bool) {
        lbMessage.isHidden = true
        guard let channelName = channelName else {
            self.loadingStop()
            Logger.error("[join Meeting] without channelName")
            return
        }
        
        DTCallManager.sharedInstance().getMeetingOnlineStatus(byChannelName: channelName) { object in
    
            let responseObject = object as! [String : Any]
            let status = (responseObject["status"] as! NSNumber).intValue
            if (status != 0) {
                Logger.error("[join meeting] error status: \(status)")
                self.loadingStop()
                return
            }
            guard let data = responseObject["data"] as? [String : Any], let members = data["users"] as? [String] else {
                self.lbMessage.text = self.messageOfMeetingMember(members: [])
                self.lbMessage.isHidden = false
                return
            }
            
            if let name = data["name"] as? String, !name.isEmpty, name != title, !isLiveStream {
                self.lbTitle.text = name
            }
            
            var removeDuplicatesMembers = [String]()
            //MARK: 刚退会未收到自己退出消息，点击bar请求会议状态成员数组会包含自己
            members.forEach { account in
                var memberId = account
                if (!account.hasPrefix(MeetingAccoutPrefix_Web)) {
                    memberId = account.transforUserAccountToCallNumber()
                }
                if (!removeDuplicatesMembers.contains(memberId)) {
                    removeDuplicatesMembers.append(memberId)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loading.stopAnimating()
                self.lbMessage.text = self.messageOfMeetingMember(members: removeDuplicatesMembers)
                self.lbMessage.isHidden = false
                self.createMembersView(members: removeDuplicatesMembers)
            }
        } failure: { _ in
            self.loadingStop()
        }
    }
    
    func checkMembers(channelName: String?,
                      title: String?,
                      isLiveStream: Bool) {
        lbTitle.text = title
        lbMessage.text = DTMeetingActionSheet.startMessage
        
        guard let channelName = channelName else {
            self.loadingStop()
            Logger.error("[check Members] without channelName")
            return
        }
        
        DTCallManager.sharedInstance().getMeetingOnlineStatus(byChannelName: channelName) { object in
            let responseObject = object as! [String : Any]
            let status = (responseObject["status"] as! NSNumber).intValue
            if (status != 0) {
                Logger.error("[check Members] error status: \(status)")
                self.loadingStop()
                return
            }
            guard let data = responseObject["data"] as? [String : Any] else {
                Logger.error("[check Members] error data nil")
                self.loadingStop()
                return
            }
            
            if let name = data["name"] as? String, !name.isEmpty, name != title, !isLiveStream {
                self.lbTitle.text = name
            }
            
            if let currentGroupMeetingMembers = data["users"] as? [String], !currentGroupMeetingMembers.isEmpty {
                var removeDuplicatesMembers = [String]()
                currentGroupMeetingMembers.forEach { account in
                    var memberId = account
                    if (!account.hasPrefix(MeetingAccoutPrefix_Web)) {
                        memberId = account.transforUserAccountToCallNumber()
                    }
                    if (!removeDuplicatesMembers.contains(memberId)) {
                        removeDuplicatesMembers.append(memberId)
                    }
                }
                self.updateButtonTitle(newTitle: DTMeetingActionSheet.joinTitle)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loading.stopAnimating()
                    self.lbMessage.text = self.messageOfMeetingMember(members: removeDuplicatesMembers)
                    self.lbMessage.isHidden = false
                    self.createMembersView(members: removeDuplicatesMembers)
                }
                return
            }
                        
            guard let tmpUserMeetings = data["userInOtherMeeting"] as? [[String : String]], !tmpUserMeetings.isEmpty else {
                self.loadingStop()
                return
            }
            var usersInOtherMeeting = [String]()
            tmpUserMeetings.forEach { otherMeeting in
                if let channel = otherMeeting["channelName"], let account = otherMeeting["account"], channel != channelName {
                    let recipientId = account.transforUserAccountToCallNumber()
                    if (!usersInOtherMeeting.contains(recipientId)) {
                        usersInOtherMeeting.append(recipientId)
                    }
                }
            }
            if (usersInOtherMeeting.isEmpty) {
                self.loadingStop()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loading.stopAnimating()
                self.createGroupMemberInOtherMeetingView(usersInOtherMeeting)
            }
        } failure: { error in
            self.loadingStop()
            Logger.error("[check Members] error: \(error.localizedDescription)")
        }

    }
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return Theme.isDarkThemeEnabled ? .lightContent : .default
    }
    
    public override func applyTheme() {
        view.backgroundColor = .clear
    }

    override public func loadView() {
        view = UIView()
        view.backgroundColor = .clear

        contentView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x1C1C1E) : UIColor(rgbHex: 0xF2F2F7)
        view.addSubview(contentView)
        contentView.autoPinEdge(toSuperviewEdge: .leading)
        contentView.autoPinEdge(toSuperviewEdge: .trailing)
        contentView.autoPinEdge(toSuperviewEdge: .bottom)

        stackView.axis = .vertical
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 0, leading: 16, bottom: 24 + view.safeAreaInsets.bottom, trailing: 16)
        
        contentView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        let handleContainer = UIView()
        handleContainer.autoSetDimension(.height, toSize: 42)
        stackView.insertArrangedSubview(handleContainer, at: 0)
        
//        let responseView = UIView()
//        handleContainer.addSubview(responseView)
//        responseView.autoSetDimension(.width, toSize: 100)
//        responseView.autoHCenterInSuperview()
//        responseView.autoPinEdge(toSuperviewEdge: .top)
//        responseView.autoPinEdge(toSuperviewEdge: .bottom)
        
        let handle = UIView()
        handle.backgroundColor = .gray
        handle.layer.masksToBounds = true
        handle.layer.cornerRadius = 2.5
        handleContainer.addSubview(handle)
        handle.autoSetDimensions(to: CGSize(width: 36, height: 5))
        handle.autoPinEdge(toSuperviewEdge: .top, withInset: 7)
        handle.autoHCenterInSuperview()

        // Support tapping the backdrop to cancel the action sheet.
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapBackdrop(_:)))
        view.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGestureAction(_:)))
        stackView.addGestureRecognizer(pan)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let cornerRadius: CGFloat = 10
        let path = UIBezierPath(
            roundedRect: contentView.bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        contentView.layer.mask = shapeLayer
    }

    @objc func didTapBackdrop(_ sender: UITapGestureRecognizer) {

        let point = sender.location(in: view)
        guard !contentView.frame.contains(point) else { return }

        dismiss(animated: true)
    }
    
    @objc func panGestureAction(_ sender: UIPanGestureRecognizer) {

//        let point = sender.location(in: contentView)
//        if btnStart.frame.contains(point) {
//            return
//        }
        
        let translationY = sender.translation(in: sender.view!).y

        switch sender.state {
        case .began:
            break
        case .changed:
            view.transform = CGAffineTransform(translationX: 0, y: max(translationY, 0))
        case .ended, .cancelled:
            if translationY > height * 2/5 {
                UIView.animate(withDuration: 0.2, animations: {
                    self.contentView.transform = CGAffineTransform(translationX: 0, y: self.height)
                }, completion: {_ in
                    self.dismiss(animated: true, completion: nil)
                })
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.view.transform = CGAffineTransformIdentity
                })
            }
        case .failed, .possible:
            break
        @unknown default:
            break
        }
    }

    func createHeader() {

        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.layoutMargins = UIEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        headerStack.spacing = 5
        stackView.addArrangedSubview(headerStack)

        // Title
        let titleLabel = UILabel()
        lbTitle = titleLabel
        titleLabel.textColor = Theme.primaryTextColor
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.textAlignment = .center
        titleLabel.text = title
        titleLabel.setCompressionResistanceVerticalHigh()
        headerStack.addArrangedSubview(titleLabel)

        // Message
        let messageLabel = UILabel()
        lbMessage = messageLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textColor = Theme.tabbarTitleNormalColor
        messageLabel.font = .systemFont(ofSize: 14, weight: .light)
        messageLabel.setCompressionResistanceVerticalHigh()
        headerStack.addArrangedSubview(messageLabel)
        
        // Loading
        let loading: UIActivityIndicatorView!
        if #available(iOSApplicationExtension 13.0, *) {
            loading = UIActivityIndicatorView(style: .medium)
        } else {
            loading = UIActivityIndicatorView(style: .gray)
        }
        self.loading = loading
        loading.hidesWhenStopped = true
        loading.tintColor = Theme.tabbarTitleNormalColor
        loading.autoSetDimension(.height, toSize: 81)
        loading.startAnimating()
        headerStack.addArrangedSubview(loading)
    }
        
    func createMembersView(members: [String]?) {
        
        guard let members = members, members.count > 0 else { return }
            
        let membersView = UIView()
        stackView.insertArrangedSubview(membersView, at: 2)
        
        let containerView = UIView()
        membersView.addSubview(containerView)
        containerView.autoCenterInSuperview()
        containerView.autoPinEdge(toSuperviewEdge: .top, withInset: 24)
        containerView.autoPinEdge(toSuperviewEdge: .bottom)

//        let contactsManager = Environment.shared.contactsManager
        let overlap = 8
        let avatarWidth = 40
        
        var finalIndex = 0
        if (members.count > maxAvatarCount) {
            finalIndex = maxAvatarCount - 2
        } else if (members.count == maxAvatarCount) {
            finalIndex = maxAvatarCount - 1
        } else {
            finalIndex = members.count - 1
        }
        let targetMembers = members[0...finalIndex]
        
        for (index, memberId) in targetMembers.enumerated() {
            let avatarView = AvatarImageView()
//            avatarView.isDisplayStatus = false
            avatarView.autoSetDimensions(to: CGSize(width: avatarWidth, height: avatarWidth))
            containerView.addSubview(avatarView)
//            var avatar: [String : Any]?
            var displayName = memberId

            if (memberId.hasPrefix(MeetingAccoutPrefix_Web)) {
                displayName = memberId.getWebUserName()
            }
//            else {
//                if let contactsManager = contactsManager, let signalAccount = contactsManager.signalAccount(forRecipientId: memberId), let contact = signalAccount.contact, let _avatar = contact.avatar as? [String: Any] {
//                    avatar = _avatar
//                    displayName = signalAccount.contactFullName() ?? memberId
//                }
//            }
            avatarView.setImageWithRecipientId(memberId, displayName: displayName)
//            avatarView.setImage(avatar: avatar, recipientId: memberId, displayName: displayName, completion: nil)

            avatarView.autoPinEdge(toSuperviewEdge: .top)
            avatarView.autoPinEdge(toSuperviewEdge: .bottom)
            avatarView.autoPinEdge(toSuperviewEdge: .leading, withInset: CGFloat((avatarWidth - overlap) * index))
            if (index == finalIndex && members.count <= maxAvatarCount) {
                avatarView.autoPinEdge(toSuperviewEdge: .trailing)
            }
        }
        
        if (members.count > maxAvatarCount) {
            let lbOtherNumber = UILabel()
            containerView.addSubview(lbOtherNumber)
            lbOtherNumber.textColor = Theme.isDarkThemeEnabled ? .white : Theme.darkThemeBackgroundColor
            lbOtherNumber.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.ows_tabbarNormal : UIColor.ows_tabbarNormalDark
            lbOtherNumber.font = .systemFont(ofSize: 13)
            lbOtherNumber.textAlignment = .center
            lbOtherNumber.layer.masksToBounds = true
            lbOtherNumber.layer.cornerRadius = 20
            
            if (members.count <= 101) {
                lbOtherNumber.text = "+\(members.count - maxAvatarCount + 1)"
            } else {
                lbOtherNumber.text = "+99"
            }
            
            lbOtherNumber.autoSetDimensions(to: CGSize(width: avatarWidth, height: avatarWidth))
            lbOtherNumber.autoPinEdge(toSuperviewEdge: .top)
            lbOtherNumber.autoPinEdge(toSuperviewEdge: .bottom)
            lbOtherNumber.autoPinEdge(toSuperviewEdge: .leading, withInset: CGFloat((avatarWidth - overlap) * (maxAvatarCount - 1)))
            lbOtherNumber.autoPinEdge(toSuperviewEdge: .trailing)
        }
    }
    
    func createGroupMemberInOtherMeetingView(_ inOtherMeetingMembers: [String]?) {
        guard let inOtherMeetingMembers = inOtherMeetingMembers, inOtherMeetingMembers.count > 0 else { return }
        
        let containerView = UIView()
        stackView.insertArrangedSubview(containerView, at: 2)
        
        let spacerView = UIView()
        containerView.addSubview(spacerView)
        spacerView.autoPinEdge(toSuperviewEdge: .top)
        spacerView.autoPinEdge(toSuperviewEdge: .left)
        spacerView.autoPinEdge(toSuperviewEdge: .right)
        spacerView.autoSetDimension(.height, toSize: 24)

        let lbMsg = MarginLabel()
        lbMsg.backgroundColor = .white.withAlphaComponent(Theme.isDarkThemeEnabled ? 0.1 : 0.6)
        lbMsg.font = .systemFont(ofSize: 14)
        lbMsg.textColor = Theme.primaryTextColor
        lbMsg.numberOfLines = 5
        lbMsg.lineBreakMode = .byTruncatingMiddle
        lbMsg.layer.masksToBounds = true
        lbMsg.layer.cornerRadius = 8
        containerView.addSubview(lbMsg)
        lbMsg.autoPinEdge(.top, to: .bottom, of: spacerView)
        lbMsg.autoPinEdge(toSuperviewEdge: .left, withInset: 8)
        lbMsg.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        lbMsg.autoPinEdge(toSuperviewEdge: .bottom)
        
        let tipIcon = UIImageView(image: #imageLiteral(resourceName: "ic_other_meeting_tip"))
        containerView.addSubview(tipIcon)
        tipIcon.autoSetDimensions(to: CGSizeMake(20, 20))
        tipIcon.autoPinEdge(.top, to: .top, of: lbMsg, withOffset: 12)
        tipIcon.autoPinEdge(.left, to: .left, of: lbMsg, withOffset: 10)

        lbMsg.text = messageOfInOtherMeetingMember(members: inOtherMeetingMembers)
    }
    
    func createButtons(joinType: JoinMeetingType) {
        
        let spacer = UIView()
        spacer.autoSetDimension(.height, toSize: 32)
        
        let btnStart = UIButton(type: .custom)
        self.btnStart = btnStart
        btnStart.backgroundColor = UIColor.ows_themeBlue
        btnStart.titleLabel!.font = UIFont.systemFont(ofSize: 15)
        btnStart.setTitleColor(.white, for: .normal)
        btnStart.setTitleColor(.white, for: .highlighted)
        var btnTitle: String!
        switch joinType {
        case .start, .checkMembers: btnTitle = DTMeetingActionSheet.startTitle
        case .join: btnTitle = DTMeetingActionSheet.joinTitle
        }
        btnStart.setTitle(btnTitle, for: .normal)
        btnStart.setTitle(btnTitle, for: .highlighted)
        btnStart.layer.masksToBounds = true
        btnStart.layer.cornerRadius = 8
        btnStart.autoSetDimension(.height, toSize: 48)
        btnStart.addTarget(self, action: #selector(btnStartAction(_:)), for: .touchUpInside)
        
        let btnStack = UIStackView(arrangedSubviews: [spacer, btnStart])
        btnStack.axis = .vertical
        stackView.addArrangedSubview(btnStack)
    }
    
    @objc func btnStartAction(_ sender: UIButton!) {
        guard let startOrJoinMeetingBlock = startOrJoinMeetingBlock else {
            return
        }
        
        dismiss(animated: true) {
            startOrJoinMeetingBlock()
        }
    }
    
    func updateButtonTitle(newTitle: String) {
        btnStart.setTitle(newTitle, for: .normal)
        btnStart.setTitle(newTitle, for: .highlighted)
    }
        
    func messageOfMeetingMember(members: [String]) -> String {
        
        let readyToJoin = "Ready to join?"
        let contactsManager = Environment.shared.contactsManager!
        if (members.isEmpty) {
            return "No one else is here, " + readyToJoin
        }
        let displayCount = min(members.count, 4)
        var pureNames = [String]()
        for i in 0..<displayCount {
            let memberId = members[i]
            var pureName = memberId
            if (memberId.hasPrefix(MeetingAccoutPrefix_Web)) {
                pureName = memberId.getWebUserName()
            } else {
                pureName = contactsManager.displayName(forPhoneIdentifier: members[i]).removeBUMessage()
            }
            pureNames.append(pureName)
        }
        if (members.count == 1) {
            return "\(pureNames[0]) is in this meeting, " + readyToJoin
        } else if (members.count == 2) {
            return "\(pureNames[0]) and \(pureNames[1]) are in this meeting, " + readyToJoin
        } else if (members.count == 3) {
            return "\(pureNames[0]), \(pureNames[1]) and \(pureNames[2]) are in this meeting, " + readyToJoin
        } else if (members.count == 4) {
            return "\(pureNames[0]), \(pureNames[1]), \(pureNames[2]) and \(pureNames[3]) are in this meeting, " + readyToJoin
        }
        //MARK: members.count > 4
        return "\(pureNames[0]), \(pureNames[1]), \(pureNames[2]) and \(members.count - 3) more are in this meeting, " + readyToJoin
    }
    
    func messageOfInOtherMeetingMember(members: [String]) -> String {
        
        let inAnotherMeeting = "in another meeting."
        let contactsManager = Environment.shared.contactsManager!
        let displayCount = min(members.count, 4)
        var pureNames = [String]()
        for i in 0..<displayCount {
            let pureName = contactsManager.displayName(forPhoneIdentifier: members[i]).removeBUMessage()
            pureNames.append(pureName)
        }
        if (members.count == 1) {
            return "\(pureNames[0]) is " + inAnotherMeeting
        } else if (members.count == 2) {
            return "\(pureNames[0]) and \(pureNames[1]) are " + inAnotherMeeting
        } else if (members.count == 3) {
            return "\(pureNames[0]), \(pureNames[1]) and \(pureNames[2]) are " + inAnotherMeeting
        } else if (members.count == 4) {
            return "\(pureNames[0]), \(pureNames[1]), \(pureNames[2]) and \(pureNames[3]) are " + inAnotherMeeting
        }
        //MARK: members.count > 4
        return "\(pureNames[0]), \(pureNames[1]), \(pureNames[2]) and \(members.count - 3) more are " + inAnotherMeeting
    }
        
    func loadingStop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.loading.stopAnimating()
        }
    }

}

private class DTMeetingPreviewPresentationController: UIPresentationController {
    let backdropView = UIView()

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        backdropView.backgroundColor = Theme.backdropColor
    }

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView, let presentedVC = presentedViewController as? DTMeetingActionSheet else { return }
        backdropView.alpha = 0
        containerView.addSubview(backdropView)
        backdropView.autoPinEdgesToSuperviewEdges()
        containerView.layoutIfNeeded()

        var startFrame = containerView.frame
        startFrame.origin.y = presentedVC.height
        presentedVC.view.frame = startFrame

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            presentedVC.view.frame = containerView.frame
            self.backdropView.alpha = 1
        }, completion: nil)
    }

    override func dismissalTransitionWillBegin() {
        guard let containerView = containerView, let presentedVC = presentedViewController as? DTMeetingActionSheet else { return }

        var endFrame = containerView.frame
        endFrame.origin.y = presentedVC.height
        presentedVC.view.frame = containerView.frame

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            presentedVC.view.frame = endFrame
            self.backdropView.alpha = 0
        }, completion: { _ in
            self.backdropView.removeFromSuperview()
        })
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let presentedView = presentedView else { return }
        coordinator.animate(alongsideTransition: { _ in
            presentedView.frame = self.frameOfPresentedViewInContainerView
            presentedView.layoutIfNeeded()
        }, completion: nil)
    }
}

extension DTMeetingActionSheet: UIViewControllerTransitioningDelegate {
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return DTMeetingPreviewPresentationController(presentedViewController: presented, presenting: presenting)
    }

}

class MarginLabel: UILabel {
    
    var contentInset: UIEdgeInsets = .init(top: 14, leading: 37, bottom: 14, trailing: 10)
    
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        var rect: CGRect = super.textRect(forBounds: bounds.inset(by: contentInset), limitedToNumberOfLines: numberOfLines)
        rect.origin.x -= contentInset.left
        rect.origin.y -= contentInset.top
        rect.size.width += contentInset.left + contentInset.right
        rect.size.height += contentInset.top + contentInset.bottom
        return rect
    }
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInset))
    }
    
}
