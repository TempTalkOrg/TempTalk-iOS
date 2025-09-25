//
//  ConfidentialMessageController.swift
//  Signal
//
//  Created by hornet on 2023/2/9.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging

@objc class DTConfideMessageController: OWSViewController {
    private let message: TSMessage
    private let showMoreCount = 2
    private let rowHeight: Double = 50
    private let mainScrollView = UIScrollView()
    private var currentTapIndexPath: IndexPath?
    private var currentPoint: CGPoint?
    private var haveRead: Bool = false
    private lazy var messageLabel = {
        let privateLabel = UILabel()
        let screenWidth = UIScreen.main.bounds.width
        privateLabel.font = UIFont.systemFont(ofSize: 24)
        privateLabel.textColor = Theme.primaryTextColor
        privateLabel.frame = CGRectMake(0, 0, screenWidth - 48, CGFLOAT_MAX)
        privateLabel.numberOfLines = 0;
        return privateLabel
    }()
    
    private lazy var mainTableView = {
        let mainTableView = UITableView.init(frame: CGRectZero, style: UITableView.Style.plain)
        mainTableView.delegate = self
        mainTableView.dataSource = self
        mainTableView.estimatedRowHeight = 50
        mainTableView.isScrollEnabled = false
        mainTableView.isUserInteractionEnabled = false
        mainTableView.showsVerticalScrollIndicator = false
        mainTableView.bounces = false
        mainTableView.separatorStyle = .none
        mainTableView.backgroundColor = UIColor.clear
        mainTableView.register(DTConfideMessageCell.self, forCellReuseIdentifier: DTConfideMessageCell.confideMessageCellIdentifier())
        return mainTableView
    }()
    
    private let contentView = UIView()
    private var confideMessageArr = [Any]()
    
    @available(*, unavailable, message:"use other constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc required init(_ message: TSMessage) {
        self.message = message
        super.init()
    }
    
    @objc func tapGestureEvent()  {
        
    }
    
    @objc func swipeGestureEvent()  {
        
    }
    
    override func loadView() {
        super.loadView()
        if(message.isTextMessage()){
            seperateTheMessage()
        } else {
           
        }
        seperateTheMessage()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupUI()
        autolayout()
        refreshTheme()
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(tapGestureEvent))
        view.addGestureRecognizer(tap)
        
        let swipeTap = UISwipeGestureRecognizer.init(target: self, action: #selector(swipeGestureEvent))
        view.addGestureRecognizer(swipeTap)
    }
  
    private func setupNav(){
        if #available(iOS 13.0, *) {
            let rightBarButtonItem : UIBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.close, target: self, action: #selector(closeButtonEvent(continue:)))
            self.navigationItem.rightBarButtonItem = rightBarButtonItem
        } else {
            // Fallback on earlier versions
        }
       
    }
    
    private func setupUI() {
        view.addSubview(mainTableView)
    }
    
    private func autolayout() {
        guard let nav = self.navigationController else {return}
        let screenWidth = UIScreen.main.bounds.size.width
        if #available(iOS 11.0, *) {
            let safeArea = view.safeAreaInsets;
            mainTableView.frame = CGRectMake(0, safeArea.top + nav.navigationBar.height, screenWidth, view.frame.size.height - safeArea.top - nav.navigationBar.height)
        } else {
            mainTableView.frame = CGRectMake(0, nav.navigationBar.height, screenWidth, view.frame.size.height - nav.navigationBar.height)
        }
        
    }
    
    func seperateTheMessage(){
        guard let body = self.message.body, DTParamsUtils.validateString(body).boolValue == true else {return}
        self.messageLabel.text = body;
        self.confideMessageArr = NSObject.getSeparatedLines(from: self.messageLabel);
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
    
        refreshTheme()
    }
    
    private func refreshTheme() {
        let textColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
        titleLabel.textColor = textColor
        subtitleLabel.textColor = textColor
        continueLabel.textColor = textColor
        withoutButton.setTitleColor(UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x82C1FC : 0x056FFA), for: .normal)
        
        view.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
    }
    
    @objc private func closeButtonEvent(continue sender: UIButton) {
        self.dismiss(animated: true)
    }
    
    func deleteOrginMessage() {
        
        guard let incomingMessage = message as? TSIncomingMessage, haveRead else {
            return
        }
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)
        //rm confidentialMessage
        databaseStorage.asyncWrite { wTransaction in
            incomingMessage.anyRemove(transaction: wTransaction)
        }
    }
    
    @objc private func buttonEvent(without sender: UIButton) {
        
    }
    
    func showHomeViewController() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate;
        appDelegate?.switchToTabbarVC(fromRegistration: true)
    }
    
    
    // MARK: - lazy
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.distribution = .fill
        stackView.spacing = 16.0
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "transfer-data-devices")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.text = "Transfer Data".localized
        return label
    }()
    
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = .zero
        label.text = "For security reasons, your data is only stored on your devices. If you have your old device, you can securely transfer it to this device.".localized
        return label
    }()

    
    private lazy var continueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = .zero
        label.textAlignment = .center
        label.text = "Continuing will disable your account on other devices.".localized
        return label
    }()
    
    private lazy var withoutButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Login without Transferring".localized, for: .normal)
        button.addTarget(self, action: #selector(buttonEvent(without:)), for: .touchUpInside)
        return button
    }()
}


extension DTConfideMessageController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
}

extension DTConfideMessageController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.confideMessageArr.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return CGFloat(rowHeight)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DTConfideMessageCell.confideMessageCellIdentifier(), for: indexPath) as? DTConfideMessageCell
        guard let cell = cell else {
            OWSLogger.debug("cell == nil")
            return UITableViewCell.init()
        }
        let messageText = self.confideMessageArr[indexPath.row] as? String
        cell.reloadWithMessage(messageText: messageText)
        return cell
    }
    
}

extension DTConfideMessageController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let fignerTouch = touches.first
        guard let fignerTouch = fignerTouch else { return }
        let touchPoint = fignerTouch.location(in: self.mainTableView)
        let indexPath = self.mainTableView.indexPathForRow(at: touchPoint)
        guard let indexPath = indexPath else {return}
        haveRead = true
        self.deleteOrginMessage()
        self.currentTapIndexPath = indexPath
        let cell  = self.mainTableView.cellForRow(at: indexPath) as? DTConfideMessageCell
        guard let cell = cell else { return  }
        cell.showDetailMessage()
        
        let visiablePaths = self.mainTableView.indexPathsForVisibleRows
        guard let visiablePaths = visiablePaths else {
            return
        }
        for visiablePath in visiablePaths {
            let visiableCell = self.mainTableView.cellForRow(at: visiablePath) as? DTConfideMessageCell
            guard let visiableCell = visiableCell else { continue }
            if(abs(visiablePath.row - indexPath.row) <= showMoreCount  ){
                visiableCell.showDetailMessage()
            } else {
                visiableCell.hideDetailMessage()
            }
        }
        
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let fignerTouch = touches.first
        guard let fignerTouch = fignerTouch else { return }
        let touchPoint = fignerTouch.location(in: self.mainTableView)
        let indexPath = self.mainTableView.indexPathForRow(at: touchPoint)
        guard let indexPath = indexPath else { return }
        haveRead = true
        self.deleteOrginMessage()
        if(self.currentTapIndexPath?.row != indexPath.row){
//            playSystemSound()
            let preIndexPath = self.currentTapIndexPath
            self.currentTapIndexPath = indexPath
            let cell  = self.mainTableView.cellForRow(at: indexPath) as? DTConfideMessageCell
            let visiablePaths = self.mainTableView.indexPathsForVisibleRows
            guard let visiablePaths = visiablePaths else {
                return
            }
            for visiablePath in visiablePaths {
                let visiableCell = self.mainTableView.cellForRow(at: visiablePath) as? DTConfideMessageCell
                guard let visiableCell = visiableCell else { continue }
                if(abs(visiablePath.row - indexPath.row) <= showMoreCount  ){
                    visiableCell.showDetailMessage()
                } else {
                    visiableCell.hideDetailMessage()
                }
            }
            self.scrollMaintableView(touchPoint: touchPoint)
        }
        
        self.currentPoint = touchPoint
        OWSLogger.debug("touchesMoved  indexPath.row = \(String(describing: indexPath.row)) indexPath.sec = \(String(describing: indexPath.section))")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        OWSLogger.debug("touches Cancelled")
        let visiablePaths = self.mainTableView.indexPathsForVisibleRows
        guard let visiablePaths = visiablePaths else {
            return
        }
        
        for visiablePath in visiablePaths {
            let visiableCell = self.mainTableView.cellForRow(at: visiablePath) as? DTConfideMessageCell
            guard let visiableCell = visiableCell else { continue }
            visiableCell.hideDetailMessage()
        }
        
        let fignerTouch = touches.first
        guard let fignerTouch = fignerTouch else { return }
        let touchPoint = fignerTouch.location(in: self.mainTableView)
        let indexPath = self.mainTableView.indexPathForRow(at: touchPoint)
        guard let _ = indexPath else { return }
        haveRead = true
        self.deleteOrginMessage()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        OWSLogger.debug("touchesEnded")
        let visiablePaths = self.mainTableView.indexPathsForVisibleRows
        guard let visiablePaths = visiablePaths else {
            return
        }
        for visiablePath in visiablePaths {
            let visiableCell = self.mainTableView.cellForRow(at: visiablePath) as? DTConfideMessageCell
            guard let visiableCell = visiableCell else { continue }
            visiableCell.hideDetailMessage()
        }
        
        let fignerTouch = touches.first
        guard let fignerTouch = fignerTouch else { return }
        let touchPoint = fignerTouch.location(in: self.mainTableView)
        let indexPath = self.mainTableView.indexPathForRow(at: touchPoint)
        guard let _ = indexPath else {return}
        haveRead = true
        self.deleteOrginMessage()
    }

    func playSystemSound() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    func scrollMaintableView(touchPoint: CGPoint)  {
        guard let currentPoint = self.currentPoint else {return}
        OWSLogger.debug("touchesMoved currentPoint.y =\(currentPoint.y) touchPoint.y= \(touchPoint.y) went ")
        if(currentPoint.y > touchPoint.y && currentPoint.y > screenHeight / 2.0){
            let contnetOffSetY = self.mainTableView.contentOffset.y
            if(contnetOffSetY >= Double(rowHeight)){
                self.mainTableView.setContentOffset(CGPoint(x: 0, y: contnetOffSetY - rowHeight), animated: true)
            } else {
                self.mainTableView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
            }
        } else if (currentPoint.y < touchPoint.y && currentPoint.y > screenHeight / 2.0) {
            let contnetOffSetY = self.mainTableView.contentOffset.y
            self.mainTableView.setContentOffset(CGPoint(x: 0, y: contnetOffSetY + rowHeight ), animated: true)
        }
    }
}

//extension DTConfideMessageController : UIAdaptivePresentationControllerDelegate {
//    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
//        return true;
//    }
//}


