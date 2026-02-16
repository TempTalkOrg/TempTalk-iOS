//
//  DTImageDownloadingView.swift
//  Difft
//
//  Created by Jaymin on 2025/11/17.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import SnapKit
import TTMessaging

class DTImageDownloadingView: UIView {
    
    enum State {
        case readyToDownload
        case downloading
        case downloadFailed
        case expired
    }
    
    private lazy var actionContainerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var actionIcon = UIImageView()
    
    private lazy var processView = CircularProcessView()
    
    private lazy var expiredContainerView = UIView()
    private lazy var expiredIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "attachment-expired-icon")?.withRenderingMode(.alwaysTemplate)
        return imageView
    }()
    private lazy var expiredLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.text = Localized("ATTACHMENT_DOWNLOADING_STATUS_EXPIRED")
        return label
    }()
    
    private var currentState: State = .readyToDownload
    private let attachmentPointer: TSAttachmentPointer
    
    init(attachmentPointer: TSAttachmentPointer) {
        self.attachmentPointer = attachmentPointer
        super.init(frame: .zero)
        
        switch attachmentPointer.state {
        case .enqueued:
            self.currentState = .readyToDownload
        case .downloading:
            self.currentState = .downloading
        case .failed:
            self.currentState = .downloadFailed
        case .expired:
            self.currentState = .expired
        default:
            self.currentState = .readyToDownload
        }
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(actionContainerView)
        actionContainerView.addSubview(processView)
        actionContainerView.addSubview(actionIcon)
        
        expiredContainerView.isHidden = true
        addSubview(expiredContainerView)
        expiredContainerView.addSubview(expiredIcon)
        expiredContainerView.addSubview(expiredLabel)
        
        actionContainerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(48)
        }
        
        processView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        actionIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        expiredContainerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        expiredIcon.snp.makeConstraints { make in
            make.width.height.equalTo(24)
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        expiredLabel.snp.makeConstraints { make in
            make.top.equalTo(expiredIcon.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        applyTheme()
        refreshState()
    }
    
    private func refreshState() {
        switch currentState {
        case .readyToDownload:
            processView.isHidden = true
            actionContainerView.isHidden = false
            expiredContainerView.isHidden = true
            actionIcon.image = UIImage(named: "attachment-download-icon")
            
        case .downloading:
            processView.isHidden = false
            actionContainerView.isHidden = false
            expiredContainerView.isHidden = true
            actionIcon.image = UIImage(named: "attachment-download-icon")
            
        case .downloadFailed:
            processView.isHidden = true
            actionContainerView.isHidden = false
            expiredContainerView.isHidden = true
            actionIcon.image = UIImage(named: "attachment-retry-icon")
            
        case .expired:
            processView.isHidden = true
            actionContainerView.isHidden = true
            expiredContainerView.isHidden = false
        }
        
        if currentState == .downloading {
            processView.progress = 0.05
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(attachmentDownloadProgress(_:)),
                name: NSNotification.Name.attachmentDownloadProgress,
                object: nil
            )
        } else {
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    @objc
    private func attachmentDownloadProgress(_ notification: Notification) {
        let attachmentId = attachmentPointer.uniqueId
        
        guard let progress = (notification as NSNotification).userInfo?[kAttachmentDownloadProgressKey] as? CGFloat else {
            owsFailDebug("Attachment download notification missing progress.")
            return
        }
        guard let notificationAttachmentId = (notification as NSNotification).userInfo?[kAttachmentDownloadAttachmentIDKey] as? String else {
            owsFailDebug("Attachment download notification missing attachment id.")
            return
        }
        guard notificationAttachmentId == attachmentId else {
            return
        }
        processView.progress = max(progress, 0.05)
    }
    
    private func applyTheme() {
        backgroundColor = Theme.bg3Color
        actionContainerView.backgroundColor = UIColor(rgbHex: 0x181A20).withAlphaComponent(0.4)
        expiredIcon.tintColor = Theme.tdisableColor
        expiredLabel.textColor = Theme.tdisableColor
    }
}

private class CircularProcessView: UIView {
    
    // MARK: - Public properties
    var progress: CGFloat = 0 {
        didSet { updateProgress() }
    }
    
    // MARK: - Layers
    private let progressLayer = CAShapeLayer()
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutCircularLayers()
    }
    
    // MARK: - Setup
    private func setupLayers() {
        layer.addSublayer(progressLayer)

        progressLayer.lineWidth = 2
        progressLayer.strokeColor = Theme.lineColor.cgColor
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
    }
    
    // MARK: - Drawing
    private func layoutCircularLayers() {
        let size = min(bounds.width, bounds.height)
        let radius = size / 2 - 2
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let circlePath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        
        progressLayer.path = circlePath.cgPath
    }
    
    // MARK: - Public API
    func setProgress(_ value: CGFloat, animated: Bool = true) {
        let newValue = min(max(value, 0), 1)
        
        if animated {
            let anim = CABasicAnimation(keyPath: "strokeEnd")
            anim.fromValue = progressLayer.strokeEnd
            anim.toValue = newValue
            anim.duration = 0.3
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.add(anim, forKey: "progress")
        }
        
        progress = newValue
        progressLayer.strokeEnd = newValue
    }
    
    private func updateProgress() {
        progressLayer.strokeEnd = progress
    }
}
