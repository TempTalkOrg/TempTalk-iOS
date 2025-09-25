//
//  DTAvatarImageView.swift
//  TTMessaging
//
//  Created by hornet on 2022/8/4.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit
import SDWebImage

@objc
public enum DTAvatarImageForSelfType: Int {
    case original = 0, noteToSelf = 1
}

@objc public class  DTAvatarImageView : UIView{

    @objc
    public var recipientId: String? {
        /// TODO 待优化
        didSet {
//            OWSLogger.debug("[userstate] \(oldValue ?? "") -> \(recipientId ?? "")")
            updateUserStateImage()
        }
    }
    
    @objc public func resetForReuse() {
        self.recipientId = nil
        self.stateView.isHidden = true
        self.stateView.backgroundColor = Theme.backgroundColor
        self.userStateImageView.image = nil
    }
    
    public var isDisplayStatus = false
        
    @objc public var stateBackgroundColor: UIColor = .clear {
        willSet {
            self.stateView.backgroundColor = newValue
        }
    }
    
    @objc
    public var imageForSelfType: DTAvatarImageForSelfType = .noteToSelf
    
    func updateUserStateImage() {
        if(!CurrentAppContext().isMainApp){
            return
        }
        guard isDisplayStatus == true else {
            self.stateView.isHidden = true
            return
        }
        guard let recipientId = recipientId else { stateView.isHidden = true
            return
        }
        if let localNumber = TSAccountManager.localNumber(), recipientId == localNumber && imageForSelfType == .noteToSelf {
            stateView.isHidden = true;
            return
        }
        
        guard recipientId.count > 6 else {
            stateView.isHidden = false
            return
        }
    }
    
    @objc public var image: UIImage? {
        didSet {
            self.avatarImageView.image = image
        }
    }
    
    @objc public let avatarImageView: AvatarImageView = AvatarImageView.init(image: nil)
    let stateView = UIView()
    let userStateImageView: UIImageView = UIImageView()

    private override init(frame: CGRect) {
        super.init(frame: .zero)
        isDisplayStatus = false
        setupSubviews()
        configInitalProperty()
        imageForSelfType = .noteToSelf
    }
    
    func configInitalProperty (){
        self.autoPinToSquareAspectRatio()
        self.layer.minificationFilter = CALayerContentsFilter.trilinear
        self.layer.magnificationFilter = CALayerContentsFilter.trilinear
        self.layer.masksToBounds = true
        avatarImageView.setContentHuggingHigh()
        avatarImageView.setCompressionResistanceHigh()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        
    }
    
    func setupSubviews() {
        addSubview(avatarImageView)
    
        stateView.isHidden = true
        stateView.backgroundColor = Theme.backgroundColor
        stateView.layer.masksToBounds = true
        addSubview(stateView)
        stateView.addSubview(userStateImageView)
        
        avatarImageView.autoPinEdgesToSuperviewEdges()
        stateView.autoPinEdge(toSuperviewEdge: .bottom)
        stateView.autoPinEdge(toSuperviewEdge: .right)
        stateView.autoMatch(.width, to: .width, of: self, withMultiplier: 5/16)
        stateView.autoMatch(.height, to: .height, of: self, withMultiplier: 5/16)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [self] in
            userStateImageView.autoPinEdgesToSuperviewEdges(with: .init(margin: 1/36 * avatarImageView.width))
            stateView.layer.cornerRadius = stateView.width / 2
        }
    }
}

public extension DTAvatarImageView {
    
    @objc 
    func setImage(recipientId: String?, displayName: String) {
        
        self.recipientId = recipientId
        avatarImageView.setImageWithRecipientId(recipientId, displayName: displayName)
    }
    
    @objc
    func setImage(avatar: [String : Any], recipientId: String?,completion:((UIImage) -> Void)?) {
        guard let recipientId = recipientId else { return  }
        self.recipientId = recipientId;
        avatarImageView.setImageWithContactAvatar(avatar, recipientId: recipientId, displayName: nil, completion: completion)
    }
    
    @objc
    func setImage(avatar: [String : Any]?, recipientId: String?, displayName: String?, completion:((UIImage) -> Void)?) {
//        guard let recipientId = recipientId else { return  }
        self.recipientId = recipientId;
        avatarImageView.setImageWithContactAvatar(avatar, recipientId: recipientId, displayName: displayName, completion: completion)
    }
    
//    @objc
//    func setImageWithContactAvatar(avatar: [String : Any],recipientId: String?) {
//        self.recipientId = recipientId;
//        configLayout()
//        avatarImageView.setImageWithContactAvatar(avatar)
//    }
    
    @objc
    func setImageWithRecipientId(avatar: [String : Any], recipientId: String?) {
        guard let recipientId = recipientId else { return  }
        self.recipientId = recipientId;
        avatarImageView.setImageWithRecipientId(recipientId)
    }
    
    @objc
    func setImageWith(thread: TSGroupThread, contactsManager: OWSContactsManager) {
        self.recipientId = nil;
        avatarImageView.setImageWith(thread, diameter: UInt(self.width), contactsManager: contactsManager)
    }
    
    @objc
    func setImageWith(thread: TSGroupThread, contactsManager: OWSContactsManager, completion: ((UIImage) -> Void)?) {
        self.recipientId = nil;
        avatarImageView.setImageWith(thread, diameter: UInt(self.width), contactsManager: contactsManager, completion: completion)
    }
    
    @objc
    func dt_setImage(with imageurl: URL?, placeholderImage: UIImage?,recipientId: String?){
        self.recipientId = recipientId;
        avatarImageView.dt_setImage(with: imageurl, placeholderImage: placeholderImage)
    }
}
