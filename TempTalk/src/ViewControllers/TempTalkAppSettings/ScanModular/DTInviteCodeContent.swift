//
//  DTInviteCodeContent.swift
//  Signal
//
//  Created by hornet on 2022/10/26.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import QRCode

enum DTInviteCodeContentActionType {
    case scan
    case regenerate
    case share
    case copyLink
    case cancel
}

protocol DTInviteCodeContentDelegate: AnyObject {
    func inviteCodeContentView(_ inviteView: DTInviteCodeContent, actionType:DTInviteCodeContentActionType, sender: UIButton)
}

class DTInviteCodeContent: UIView {
    var inviteViewDelegate: DTInviteCodeContentDelegate?
    var isGroupLink: Bool = false
    lazy var titleLable = {
        let titleLable = UILabel()
        titleLable.text =  Localized("INVITECODE", comment: "")
        titleLable.font = UIFont.systemFont(ofSize: 16)
        titleLable.textColor = UIColor.color(rgbHex: 0x1E2329)
        titleLable.textAlignment = NSTextAlignment.center
        return titleLable
    }()
    
    lazy var scanButton = {
        let scanButton = UIButton()
        scanButton.setImage(UIImage.init(named: "floataction_scan_large"), for: .normal)
        scanButton.setImage(UIImage.init(named: "floataction_scan_large"), for: .selected)
        scanButton.addTarget(self, action: #selector(scanButtonClick), for: .touchUpInside)
        return scanButton
    }()
    
    lazy var qrCodeView = {
        let qrCodeView = UIImageView()
        qrCodeView.contentMode = .scaleAspectFit
        return qrCodeView
    }()
    
    lazy var tipLable = {
        let tipLable = UILabel()
        tipLable.text =  Localized("INVITE_FRIEND_BY_QRCODE_OR_LINK", comment: "")
        tipLable.font = UIFont.systemFont(ofSize: 14)
        tipLable.textColor = UIColor.color(rgbHex: 0x1E2329)
        tipLable.textAlignment = NSTextAlignment.center
        return tipLable
    }()
    
    lazy var stackView = {
        let stackContainView = UIStackView.init()
        stackContainView.axis = .horizontal
        stackContainView.alignment = .center
        stackContainView.spacing = 5
        stackContainView.distribution = .fillEqually
        return stackContainView
    }()
    
    lazy var regenerateButton = {
        let regenerateButton = DTLayoutButton()
        regenerateButton.spacing = 12
        regenerateButton.setImage(UIImage.init(named: "scan_regenerate"), for: .normal)
        regenerateButton.setImage(UIImage.init(named: "scan_regenerate"), for: .selected)
        regenerateButton.setTitle(Localized("INVITE_REGENERATE", comment: ""), for: .normal)
        regenerateButton.layer.cornerRadius = 8
        regenerateButton.titleAlignment = DTButtonTitleAlignmentType.bottom
        regenerateButton.setTitleColor(UIColor(rgbHex: 0x1E2329), for: .normal)
        regenerateButton.layer.backgroundColor = UIColor.color(rgbHex: 0xffffff).cgColor
        regenerateButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        regenerateButton.addTarget(self, action: #selector(regenerateButtonClick), for: .touchUpInside)
        return regenerateButton
    }()
    
    lazy var shareButton = {
        let shareButton = DTLayoutButton()
        shareButton.spacing = 12
        shareButton.setImage(UIImage.init(named: "scan_share"), for: .normal)
        shareButton.setImage(UIImage.init(named: "scan_share"), for: .selected)
        shareButton.setTitle(Localized("INVITE_SHARE", comment: ""), for: .normal)
        shareButton.layer.cornerRadius = 8
        shareButton.titleAlignment = DTButtonTitleAlignmentType.bottom
        shareButton.setTitleColor(UIColor(rgbHex: 0x1E2329), for: .normal)
        shareButton.layer.backgroundColor = UIColor.color(rgbHex: 0xffffff).cgColor
        shareButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        shareButton.addTarget(self, action: #selector(shareButtonClick), for: .touchUpInside)
        return shareButton
    }()
    
    lazy var copyLinkButton = {
        let copyLinkButton = DTLayoutButton()
        copyLinkButton.spacing = 12
        copyLinkButton.setImage(UIImage.init(named: "scan_link"), for: .normal)
        copyLinkButton.setImage(UIImage.init(named: "scan_link"), for: .selected)
        copyLinkButton.setTitle(Localized("INVITE_COPY_LINK", comment: ""), for: .normal)
        copyLinkButton.layer.cornerRadius = 8
        copyLinkButton.titleAlignment = DTButtonTitleAlignmentType.bottom
        copyLinkButton.layer.backgroundColor = UIColor.color(rgbHex: 0xffffff).cgColor
        copyLinkButton.setTitleColor(UIColor(rgbHex: 0x1E2329), for: .normal)
        copyLinkButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        copyLinkButton.addTarget(self, action: #selector(copyLinkButtonClick), for: .touchUpInside)
        return copyLinkButton
    }()
    
    lazy var cancelButton = {
        let cancelButton = UIButton()
        cancelButton.setTitle(Localized("INVITE_CANCEL", comment: ""), for: .normal)
        cancelButton.layer.cornerRadius = 8
        cancelButton.layer.backgroundColor = UIColor.color(rgbHex: 0xffffff).cgColor
        cancelButton.setTitleColor(UIColor(rgbHex: 0x056FFA), for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.addTarget(self, action: #selector(cancelButtonClick), for: .touchUpInside)
        return cancelButton
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init(delegate: DTInviteCodeContentDelegate, isGroupLink: Bool = false) {
        self.init(frame: CGRectZero)
        self.isGroupLink = isGroupLink
        self.inviteViewDelegate = delegate
        addSubviews()
        configSubviewLayout()
    }
    
    func addSubviews() {
        addSubview(titleLable)
        addSubview(scanButton)
        addSubview(qrCodeView)
        addSubview(tipLable)
        
        addSubview(stackView)
        if(!self.isGroupLink){
            stackView.addArrangedSubview(regenerateButton)
        }
        stackView.addArrangedSubview(shareButton)
        stackView.addArrangedSubview(copyLinkButton)
//        addSubview(regenerateButton)
//        addSubview(shareButton)
//        addSubview(copyLinkButton)
        addSubview(cancelButton)
    }
    
    func configSubviewLayout() {
        titleLable.autoPinEdge(ALEdge.top, to: ALEdge.top, of: self, withOffset: 16)
        titleLable.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self, withOffset: 52)
        titleLable.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -52)
        titleLable.autoSetDimension(ALDimension.height, toSize: 24)
        
        scanButton.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -16)
        scanButton.autoAlignAxis(ALAxis.horizontal, toSameAxisOf: titleLable)
        
        qrCodeView.autoPinEdge(ALEdge.top, to: ALEdge.bottom, of: titleLable, withOffset: 24)
        qrCodeView.autoAlignAxis(ALAxis.vertical, toSameAxisOf: titleLable)
        qrCodeView.autoSetDimension(ALDimension.width, toSize: 200)
        qrCodeView.autoSetDimension(ALDimension.height, toSize: 200)
        qrCodeView.setCompressionResistanceHigh()
        
        tipLable.autoPinEdge(ALEdge.top, to: ALEdge.bottom, of: qrCodeView, withOffset: 12)
        tipLable.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self, withOffset: 16)
        tipLable.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -16)
        tipLable.autoSetDimension(ALDimension.height, toSize: 20)
        
        stackView.autoPinEdge(ALEdge.top, to: ALEdge.bottom, of: tipLable, withOffset: 40)
        stackView.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self, withOffset: 16)
        stackView.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -16)
        stackView.autoSetDimension(ALDimension.height, toSize: 72)
        if(!self.isGroupLink){
            regenerateButton.autoSetDimension(ALDimension.height, toSize: 72)
        }
        shareButton.autoSetDimension(ALDimension.height, toSize: 72)
        copyLinkButton.autoSetDimension(ALDimension.height, toSize: 72)
        
        cancelButton.autoPinEdge(ALEdge.top, to: ALEdge.bottom, of: stackView, withOffset: 36)
        cancelButton.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self, withOffset: 16)
        cancelButton.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -16)
        cancelButton.autoSetDimension(ALDimension.height, toSize: 20)
        cancelButton.backgroundColor = UIColor.clear
    }
    
    @objc func scanButtonClick(sender: UIButton) {
        self.inviteViewDelegate?.inviteCodeContentView(self, actionType: .scan, sender: sender)
    }
    
    @objc func regenerateButtonClick(sender: UIButton)  {
        self.inviteViewDelegate?.inviteCodeContentView(self, actionType: .regenerate, sender: sender)
    }
    
    @objc func shareButtonClick(sender: UIButton) {
        self.inviteViewDelegate?.inviteCodeContentView(self, actionType: .share, sender: sender)
    }
    
    @objc func copyLinkButtonClick(sender: UIButton) {
        self.inviteViewDelegate?.inviteCodeContentView(self, actionType: .copyLink, sender: sender)
    }
    
    @objc func cancelButtonClick(sender: UIButton) {
        self.inviteViewDelegate?.inviteCodeContentView(self, actionType: .cancel, sender: sender)
    }
    func configData(urlString: String) {
        
        if urlString.isEmpty {
            OWSLogger.error("qr code url is empty !")
            return
        }
        
        do {
            let doc = try QRCode.Document(utf8String: urlString)
            doc.design.backgroundColor(UIColor.white.cgColor)
            doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
            if let logoImage = UIImage(named: "qr_logo"), let logoCGImage = logoImage.cgImage {
                doc.logoTemplate = QRCode.LogoTemplate(
                    image: logoCGImage,
                    path: CGPath(rect: CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30), transform: nil),
                    inset: 0
                )
            }
            doc.design.additionalQuietZonePixels = 6
            doc.design.style.backgroundFractionalCornerRadius = 3.0
            let cgImage = try doc.cgImage(CGSize(width: 300, height: 300))
            
            self.qrCodeView.image = UIImage(cgImage: cgImage)
        } catch {
            
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
