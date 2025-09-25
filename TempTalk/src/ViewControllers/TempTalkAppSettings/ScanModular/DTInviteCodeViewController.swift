//
//  DTInviteCodeViewController.swift
//  Signal
//
//  Created by Kris.s on 2024/11/8.
//  Copyright © 2024 Difft. All rights reserved.
//
import Foundation
import SnapKit
import QRCode

struct InviteCodeEntity: Codable {
    var inviteCode: String
    var randomCode: String
    var randomCodeTTL: UInt64
    var randomCodeExpiration: UInt64
    var inviteLink: String
}

final class DTInviteCodeViewController: SettingBaseViewController {
    
    var displayLink: CADisplayLink?
    var startTimestamp: UInt64 = 0
    let maximumCycleCount = 3
    var randomNumberCount = 0
    var remainCountdown: UInt64 = 0
    var requestingInviteCode = false
    var requestErrorCount = 0
    var inviteCodeEntity: InviteCodeEntity?
    
    fileprivate lazy var animationLayer: CALayer = {
        let animationLayer = CALayer()
        return animationLayer
    }()
    
    fileprivate var inviteUrl: String?
    
    fileprivate lazy var backBtn: UIButton = {
        let backBtn = UIButton()
        backBtn.setTitleColor(Theme.primaryTextColor, for: .normal)
        backBtn.setBackgroundImage(UIImage.init(named: "NavBarBackNew"), for: .normal)
        backBtn.addTarget(self, action: #selector(backBtnClick), for: .touchUpInside)
        return backBtn
    }()
    
    fileprivate lazy var bgImageView: UIImageView = {
        let bgImageView = UIImageView.init(image: UIImage(named: "view_background"))
        bgImageView.contentMode = .scaleAspectFill
        return bgImageView
    }()
    
    fileprivate lazy var cardContainerView: UIView = {
        let cardContainerView = UIView()
        cardContainerView.clipsToBounds = true
        cardContainerView.layer.cornerRadius = 6.0
        cardContainerView.layer.shadowColor = UIColor(rgbHex: 0x181a20).cgColor
        cardContainerView.layer.shadowOffset = CGSize(width: 1, height: 1)
        cardContainerView.layer.shadowRadius = 1
        cardContainerView.layer.shadowOpacity = 0.3

        return cardContainerView
    }()
    
    fileprivate lazy var avatarView: DTAvatarImageView = {
        let view = DTAvatarImageView()
        view.imageForSelfType = .original;
        return view
    }()
    
    fileprivate lazy var nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.font = UIFont.systemFont(ofSize: 20)
        return nameLabel
    }()
    
    fileprivate lazy var tipsLabel: UILabel = {
        let tipsLabel = UILabel()
        tipsLabel.font = UIFont.systemFont(ofSize: 12)
        return tipsLabel
    }()
    
    fileprivate lazy var qrCodeView = UIImageView()
    
    fileprivate lazy var numberLabel: UILabel = {
        let numberLabel = UILabel()
        numberLabel.textAlignment = .left
        numberLabel.numberOfLines = 1
        numberLabel.font = UIFont.boldSystemFont(ofSize: 32)
        return numberLabel
    }()
    
    fileprivate lazy var inviteFullTipsLabel: UILabel = {
        let inviteFullTipsLabel = UILabel()
        inviteFullTipsLabel.text = Localized("INVITE_FRIEND_FULL_TIPS")
        inviteFullTipsLabel.font = UIFont.systemFont(ofSize: 12)
        inviteFullTipsLabel.textColor = UIColor.color(rgbHex: 0xF84135)
        inviteFullTipsLabel.textAlignment = .center
        inviteFullTipsLabel.numberOfLines = 1
        inviteFullTipsLabel.isHidden = true
        return inviteFullTipsLabel
    }()
    
    fileprivate lazy var countdownView: UIView = {
        let countdownView = UIView()
        countdownView.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
        countdownView.isHidden = true
        return countdownView
    }()
    
    
    fileprivate lazy var regenerateView: DTInviteActionView = {
        var iconImage: UIImage
        if let image = UIImage(named: "invite_regenerate") {
            iconImage = image
        } else {
            iconImage = #imageLiteral(resourceName: "icon_unselected")
        }
        let action = MenuAction(image: iconImage, title: "", subtitle: nil, block: {[weak self] _ in
            self?.requestAndRefreshQRCodeView(regenerate: true) {
                //regenerate QR code completion
            }
        })
        let regenerateView = DTInviteActionView(action: action, direction: .horizontal)
        return regenerateView
    }()
    
    fileprivate lazy var scanActionView: DTInviteActionView = {
        var iconImage: UIImage
        if let image = UIImage(named: "invite_scan") {
            iconImage = image
        } else {
            iconImage = #imageLiteral(resourceName: "icon_unselected")
        }
        let action = MenuAction(image: iconImage, title: Localized("INVITE_SCAN"), subtitle: nil, block: {[weak self] _ in
            let scanVc : DTScanQRCodeController =  DTScanQRCodeController()
            self?.navigationController?.pushViewController(scanVc, animated: true)
        })
        let scanActionView = DTInviteActionView(action: action)
        return scanActionView
    }()
    
    fileprivate lazy var enterCodeActionView: DTInviteActionView = {
        var iconImage: UIImage
        if let image = UIImage(named: "invite_enter_code") {
            iconImage = image
        } else {
            iconImage = #imageLiteral(resourceName: "icon_unselected")
        }
        let action = MenuAction(image: iconImage, title: Localized("INVITE_ENTER_CODE"), subtitle: nil, block: {[weak self] _ in
            let enterCodeVc = EnterCodeViewController()
            self?.navigationController?.pushViewController(enterCodeVc, animated: true)
        })
        let copyLinkActionView = DTInviteActionView(action: action)
        return copyLinkActionView
    }()
    
    fileprivate lazy var shareActionView: DTInviteActionView = {
        var iconImage: UIImage
        if let image = UIImage(named: "invite_share") {
            iconImage = image
        } else {
            iconImage = #imageLiteral(resourceName: "icon_unselected")
        }
        let action = MenuAction(image: iconImage, title: Localized("INVITE_SHARE"), subtitle: nil, block: {[weak self] _ in
            
            let inviteDesc = Localized("INVITE_DESC") + " " + (self?.inviteCodeEntity?.inviteLink ?? "https://temptalk.app")
            let activityController = UIActivityViewController.init(activityItems: [inviteDesc], applicationActivities: nil)
            activityController.completionWithItemsHandler =  { activity, success, items, error in
                if(success == true){
                    self?.navigationController?.popViewController(animated: true)
                }
            }
            self?.navigationController?.present(activityController, animated: true, completion:nil)
        })
        let shareActionView = DTInviteActionView(action: action)
        return shareActionView
    }()
    
    
    func startTimer() {
   
        DispatchMainThreadSafe { [self] in
            invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(countDownAction))
            displayLink?.add(to: .main, forMode: .common)
            Logger.info("\(logTag) timer start")
        }
    }

    func stopTimer() {
      
        Logger.info("\(logTag) timer stop")
        invalidate()
    }
    
    func invalidate() {
        guard let displayLink else { return }
        displayLink.invalidate()
        self.displayLink = nil
        randomNumberCount = 0
    }
    
    @objc func countDownAction() {
        
        guard let inviteCodeEntity else {
            self.requestAndRefreshQRCodeView(regenerate: false) {
                
            }
            return
        }
        
        let spendTime = NSDate.ows_millisecondTimeStamp() - startTimestamp
        let totalCountdown = inviteCodeEntity.randomCodeExpiration * 1000
        if spendTime < totalCountdown{
            remainCountdown = totalCountdown - spendTime
        } else {
            remainCountdown = 0
        }
        
        if remainCountdown <= 0,
           randomNumberCount < maximumCycleCount {
            self.requestAndRefreshQRCodeView(regenerate: false) {
                
            }
        } else {
            let rightMargin = (1 - CGFloat(remainCountdown)/CGFloat(totalCountdown)) * CGRectGetWidth(self.cardContainerView.bounds)
            self.countdownView.snp.updateConstraints { make in
                make.right.equalToSuperview().offset(-rightMargin)
            }
        }
    }
    
    func refresRandomNumberView(text: String) -> () {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .kern: 30.0
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        numberLabel.attributedText = attributedText
        countdownView.isHidden = false
        showInviteLinkView(isShow: text == "****")
    }
    
    func showInviteLinkView(isShow: Bool) -> () {
        if isShow {
            inviteFullTipsLabel.isHidden = false
            numberLabel.textAlignment = .center
            numberLabel.font = UIFont.boldSystemFont(ofSize: 45)
            removeAnimateNumberLabel()
        } else {
            inviteFullTipsLabel.isHidden = true
            numberLabel.textAlignment = .left
            numberLabel.font = UIFont.boldSystemFont(ofSize: 32)
            animateNumberLabel()
        }
    }
    
    func animateNumberLabel() {
        // 创建一个缩放动画
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.7
        scaleAnimation.duration = 1.0
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.autoreverses = true
        
        // 添加动画到numberLabel的layer
        numberLabel.layer.add(scaleAnimation, forKey: "scaleAnimation")
    }
    
    func removeAnimateNumberLabel() {
        numberLabel.layer.removeAllAnimations()
    }
    
    override func loadView() {
       super.loadView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        animationLayer.frame = numberLabel.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupLayout()
        updateContent()
        applyTheme()
        // 监听应用状态变化
       NotificationCenter.default.addObserver(self,
                                              selector: #selector(appWillEnterForeground),
                                              name: UIApplication.willEnterForegroundNotification,
                                              object: nil)
       NotificationCenter.default.addObserver(self,
                                              selector: #selector(appDidEnterBackground),
                                              name: UIApplication.didEnterBackgroundNotification,
                                              object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        OWSLogger.info("invite code view deinit.")
    }
    
    func startDownCode() {
        startTimer()
        animateNumberLabel()
    }
    
    func stopDownCode() {
        stopTimer()
        numberLabel.layer.removeAllAnimations()
    }
    
    @objc func appWillEnterForeground() {
        startDownCode()
    }

    @objc func appDidEnterBackground() {
        stopDownCode()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = true
        startDownCode()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.navigationBar.isHidden = false
        stopDownCode()
    }
    
    private func setupView() {
        self.view.addSubview(bgImageView)
        self.view.addSubview(backBtn)
        self.view.addSubview(cardContainerView)
        self.view.addSubview(avatarView)
        self.cardContainerView.addSubview(nameLabel)
        self.cardContainerView.addSubview(tipsLabel)
        self.cardContainerView.addSubview(qrCodeView)
        self.cardContainerView.addSubview(regenerateView)
        self.cardContainerView.addSubview(numberLabel)
        self.cardContainerView.addSubview(inviteFullTipsLabel)
        self.cardContainerView.addSubview(countdownView)
        self.view.addSubview(scanActionView)
        self.view.addSubview(enterCodeActionView)
        self.view.addSubview(shareActionView)
        numberLabel.layer.addSublayer(animationLayer)
    }
    
    func setupLayout() {
        
        backBtn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.left.equalToSuperview().offset(10)
            make.width.height.equalTo(24)
        }
        
        bgImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        cardContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(138)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.height.equalTo(432)
        }
        
        avatarView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(cardContainerView.snp.top)
            make.width.height.equalTo(88)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(28)
            make.top.equalTo(avatarView.snp.bottom).offset(16)
        }
        
        tipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(16)
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
        }
        
        qrCodeView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.width.equalTo(200)
            make.top.equalTo(tipsLabel.snp.bottom).offset(16)
        }
        
        regenerateView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(30)
        }
        
        numberLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(40)
            make.width.equalTo(175)
            make.top.equalTo(qrCodeView.snp.bottom).offset(16)
        }
        
        inviteFullTipsLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.height.equalTo(16)
            make.width.equalTo(UIScreen.main.bounds.width - 50)
            make.top.equalTo(numberLabel.snp.bottom).offset(12)
        }
        
        countdownView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(4)
        }
        
        scanActionView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(38)
            make.bottom.equalToSuperview().offset(-58)
            make.width.height.equalTo(88)
        }
        
        enterCodeActionView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(scanActionView.snp.bottom)
            make.width.height.equalTo(88)
        }
        
        shareActionView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-38)
            make.bottom.equalTo(scanActionView.snp.bottom)
            make.width.height.equalTo(88)
        }
    }
    
    override func applyTheme() {
        super.applyTheme()
        self.view.backgroundColor = Theme.defaultBackgroundColor
        avatarView.backgroundColor = UIColor.clear
        cardContainerView.backgroundColor = Theme.defaultTableCellBackgroundColor
        nameLabel.textColor = Theme.primaryTextColor
        tipsLabel.textColor = Theme.secondaryTextColor
        self.view.subviews.forEach {
            if let subview = $0 as? DTInviteActionView {
                subview.applyTheme()
            }
        }
    }
    
    @objc func backBtnClick() {
        if let presentingViewController = self.presentingViewController {
            presentingViewController.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    func updateContent() {
        var localAccount: SignalAccount?
        var inviteCode: String?
        self.databaseStorage.asyncRead { transaction in
            guard let localNumber = TSAccountManager.shared.localNumber(with: transaction) else {
                OWSLogger.error("localNumber is nil !")
                return
            }
            localAccount = Environment.shared.contactsManager.signalAccount(forRecipientId: localNumber, transaction: transaction)
            
            inviteCode = TSAccountManager.sharedInstance().storedInviteCode(with: transaction)
        } completion: {
            let avatar = localAccount?.contact?.avatar as? [String: Any]
            self.avatarView.setImage(avatar: avatar, recipientId: localAccount?.recipientId, displayName: localAccount?.contact?.fullName, completion: nil)
            self.nameLabel.text = localAccount?.contact?.fullName
            
            if let joinedAt = localAccount?.contact?.joinedAt {
                self.tipsLabel.text = joinedAt + " " + Localized("INVITE_JOINED")
            }
            
            var cacheQRSuccess = false
            if let inviteCode = inviteCode {
                if let challengeCode = TSAccountManager.sharedInstance().challengeCodeCache().firstObject as? String {
                    if let linkUrl = self.generateLinkUrl(inviteCode: inviteCode, challengeCode: challengeCode) {
                        OWSLogger.info("use cache linkUrl !")
                        self.refreshQRCodeView(linkUrl: linkUrl)
                        cacheQRSuccess = true
                    }
                }
            }
            OWSLogger.info("fetching and generate linkUrl !")
            if !cacheQRSuccess {
                DTToastHelper.show()
            }
            self.requestAndRefreshQRCodeView(regenerate: false) {
                if !cacheQRSuccess {
                    DTToastHelper.hide()
                }
            }
        }
    }
    
    //MARK: QR code
    func requestAndRefreshQRCodeView(regenerate: Bool, completion: @escaping () -> Void) {
        
        if regenerate {
            randomNumberCount = 0
            requestErrorCount = 0
        }
        
        guard !requestingInviteCode, requestErrorCount < 3 else {
            return
        }
        requestingInviteCode = true
        self.requestInviteCode(regenerate: regenerate) { inviteCodeEntity in
            self.requestingInviteCode = false
            
            guard let inviteCode = inviteCodeEntity?.inviteCode.stripped else {
                self.requestErrorCount += 1
                DTToastHelper.toast(withText: "data error!")
                completion()
                return
            }
            
            guard let inviteLink = inviteCodeEntity?.inviteLink.stripped else {
                self.requestErrorCount += 1
                DTToastHelper.toast(withText: "generate url error!")
                completion()
                return
            }
            
            var linkUrl: String?
            self.databaseStorage.asyncWrite { wTransaction in
                TSAccountManager.sharedInstance().storeInviteCode(inviteCode, transaction: wTransaction)
                TSAccountManager.sharedInstance().storeInviteLink(inviteLink, transaction: wTransaction)
                linkUrl = inviteLink
            } completion: {
                if let linkUrl = linkUrl,
                   let randomCode = inviteCodeEntity?.randomCode.stripped {
                    self.requestErrorCount = 0
                    self.refreshQRCodeView(linkUrl: linkUrl)
                    self.randomNumberCount += 1
                    self.refresRandomNumberView(text: randomCode)
                    completion()
                } else {
                    self.requestErrorCount += 1
                    DTToastHelper.toast(withText: "generate url error!")
                    completion()
                }
            }
        }
    }
    
    func refreshQRCodeView(linkUrl: String) {
        
        if linkUrl.isEmpty {
            OWSLogger.error("qr code url is empty !")
            return
         }
        do {
            let doc = try QRCode.Document(utf8String: linkUrl)
            doc.design.backgroundColor(UIColor.white.cgColor)
            doc.design.shape.eye = QRCode.EyeShape.RoundedRect()
            if let logoImage = UIImage(named: "qr_logo"), let logoCGImage = logoImage.cgImage {
                doc.logoTemplate = QRCode.LogoTemplate(
                    image: logoCGImage,
                    path: CGPath(rect: CGRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30), transform: nil),
                    inset: 0
                )
            }
            doc.design.additionalQuietZonePixels = 2
            doc.design.style.backgroundFractionalCornerRadius = 3.0
            let cgImage = try doc.cgImage(CGSize(width: 300, height: 300))
            self.qrCodeView.image = UIImage(cgImage: cgImage)
        } catch {
            OWSLogger.error("generate QR code error: \(error)")
        }
         
    }
    
    func generateLinkUrl(inviteCode: String, challengeCode: String) -> String? {
        var inviteLink: String?
        self.databaseStorage.read(block: { readTrasation in
            inviteLink = TSAccountManager.sharedInstance().storedInviteLink(with: readTrasation) ?? ""
        });
        return inviteLink
    }
    
    func requestInviteCode(regenerate: Bool, completion: @escaping (InviteCodeEntity?) -> Void)  {
        TSAccountManager.sharedInstance().requestLongPeroidInviteCode(NSNumber.init(value: regenerate), shortNumber: NSNumber.init(value: 1)) { [weak self] metaEntity in
            OWSLogger.info("invite code vc requestInviteCode \(metaEntity)")
            guard self != nil else { return }
            let responseData = metaEntity.data;
            guard let responseData = responseData as? Dictionary<String, Any> else {return}
            guard let tmpInviteCode = responseData["inviteCode"] as? String else {return}
            guard let tmpInviteLink = responseData["inviteLink"] as? String else {return}
            let inviteCode = tmpInviteCode.stripped
            let inviteLink = tmpInviteLink.stripped
            if inviteCode.isEmpty || inviteLink.isEmpty {
                DTToastHelper.toast(withText: "inviteCode data error!")
                completion(nil)
                return
            }
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: responseData, options: [])
                let decoder = JSONDecoder()
                self?.inviteCodeEntity = try decoder.decode(InviteCodeEntity.self, from: jsonData)
                self?.startTimestamp = NSDate.ows_millisecondTimeStamp()
                self?.remainCountdown = (self?.inviteCodeEntity?.randomCodeTTL ?? 0) * 1000
                completion(self?.inviteCodeEntity)
            } catch let decodingError {
                let errorMessage = NSError.errorDesc(decodingError, errResponse: nil)
                DTToastHelper.toast(withText: errorMessage)
            }
        } failure: { error in
            let errorMessage = NSError.errorDesc(error, errResponse: nil)
            DTToastHelper.toast(withText: errorMessage)
            completion(nil)
        }
    }
    
}

private protocol ActionViewDelegate: AnyObject {
    func actionView(_ actionView: DTInviteActionView, didTapWith action: MenuAction)
}

private class DTInviteActionView: UIView {
    
    enum DTInviteActionViewDirection: Int {
        case vertical = 0
        case horizontal = 1
    }
    
    private lazy var iconImageView: UIImageView = UIImageView()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        if self.direction == .horizontal {
            label.textAlignment = .left
        } else {
            label.textAlignment = .center
        }
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()
    
    private var action: MenuAction
    private var direction: DTInviteActionViewDirection
    weak var delegate: ActionViewDelegate?
    
    init(action: MenuAction, direction: DTInviteActionViewDirection = .vertical) {
        self.action = action
        self.direction = direction
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionViewPressed))
        addGestureRecognizer(tapGesture)
        
        addSubview(iconImageView)
        iconImageView.image = action.image
        iconImageView.contentMode = .center
        if self.direction == .vertical {
            iconImageView.clipsToBounds = true
            iconImageView.layer.cornerRadius = 24
        }
        if self.direction == .horizontal {
            iconImageView.snp.makeConstraints { make in
                make.leading.equalToSuperview()
                make.centerY.equalToSuperview()
                make.width.height.equalTo(16)
            }
        } else {
            iconImageView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(8)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(48)
            }
        }
        
        addSubview(titleLabel)
        titleLabel.text = action.title
        if self.direction == .horizontal {
            titleLabel.snp.makeConstraints { make in
                make.left.equalTo(iconImageView.snp.right).offset(4)
                make.right.equalToSuperview()
                make.centerY.equalToSuperview()
                make.height.equalTo(16)
            }
        } else {
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(iconImageView.snp.bottom).offset(8)
                make.centerX.equalToSuperview()
                make.height.equalTo(16)
            }
        }
        
        
        applyTheme()
    }
    
    @objc private func actionViewPressed() {
        delegate?.actionView(self, didTapWith: action)
        action.block(action)
    }
    
    func applyTheme() {
        iconImageView.backgroundColor = Theme.defaultTableCellBackgroundColor
        iconImageView.tintColor = Theme.tabbarTitleNormalColor
        titleLabel.textColor = Theme.primaryTextColor
    }
}
