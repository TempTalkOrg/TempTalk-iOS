//
//  DTBulletChatView.swift
//  Wea
//
//  Created by Ethan on 2022/8/3.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging

enum BulletMessageType: String {
    case text = "text"
    case join = "join"
    case left = "left"
    case mic_on = "mic-on"
    case mic_off = "mic-off"
    case mute_other = "mute-other"
    case start_screen = "start-screen"
    case local_tips = "local-tips"
    case video_on = "video-on"
    case video_off = "video-off"
//    case caption_on = "caption-on"
}

@objcMembers
class DTBulletChatView: UIView {

    lazy var origionMsgs: Array<DTBulletChatModel> = []
    var displayMsgs: Array<DTBulletChatModel> = []
    private var disappearTimers: [String: Timer] = [:]

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.isUserInteractionEnabled = false
        tableView.backgroundColor = .clear
        tableView.isScrollEnabled = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.transform = CGAffineTransform(1, 0, 0, -1, 0, 0)
        tableView.register(DTBulletChatCell.self, forCellReuseIdentifier: DTBulletChatCell.reuseIdentifier())
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        return tableView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(tableView)
        tableView.autoPinEdgesToSuperviewEdges()
        Logger.info("[BulletChat] DTBulletChatView init with frame: \(frame)")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        Logger.info("[BulletChat] DTBulletChatView layoutSubviews - frame: \(frame), bounds: \(bounds), tableView.frame: \(tableView.frame)")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func insertBulletChat(_ chatModel: DTBulletChatModel) {
        guard BulletMessageType(rawValue: chatModel.type) != nil else {
            Logger.info("[BulletChat] DTBulletChatView insertBulletChat - invalid type: \(chatModel.type)")
            return
        }

        Logger.info("[BulletChat] DTBulletChatView insertBulletChat - type: \(chatModel.type), text: \(chatModel.text), bounds: \(bounds.size), frame: \(frame)")

        // 使用复合键（时间戳 + ID）进行去重，避免快速发送消息时的时间戳冲突
        let messageKey = "\(chatModel.timestamp)_\(chatModel.id)"
        var isDupli = false

        if (origionMsgs.count >= 50) {
            origionMsgs.removeLast()
        }

        for origionMsg in origionMsgs {
            let existingKey = "\(origionMsg.timestamp)_\(origionMsg.id)"
            if existingKey == messageKey {
                isDupli = true
                break
            }
        }
        if !isDupli  {
            origionMsgs.append(chatModel)
        }

        if (displayMsgs.count >= 5) {
            displayMsgs.removeLast()
        }

        guard !isDupli else {
            Logger.info("[BulletChat] DTBulletChatView insertBulletChat - duplicate message, skipping")
            return
        }

        if displayMsgs.isEmpty {
            displayMsgs.append(chatModel)
        } else {
            displayMsgs.insert(chatModel, at: 0)
        }

        Logger.info("[BulletChat] DTBulletChatView insertBulletChat - added to displayMsgs, count: \(displayMsgs.count)")

        reloadData()
        disappearTimers[messageKey]?.invalidate()
        let duration = TimeInterval(DTMeetingManager.shared.autoHideTimeoutDuration())
        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            displayMsgs.removeAll { "\($0.timestamp)_\($0.id)" == messageKey }
            disappearTimers.removeValue(forKey: messageKey)
            reloadData()
        }
        disappearTimers[messageKey] = timer

    }
    
    func reloadData() {
        tableView.reloadData()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        disappearTimers.values.forEach { $0.invalidate() }
        disappearTimers.removeAll()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

extension DTBulletChatView: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        displayMsgs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: DTBulletChatCell.reuseIdentifier(), for: indexPath) as! DTBulletChatCell
        if indexPath.row < displayMsgs.count {
            cell.chatModel = displayMsgs[indexPath.row]
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        UIView.performWithoutAnimation {
            cell.transform = tableView.transform
        }
    }
    
}


class DTBulletChatCell: UITableViewCell {
    
    public var chatModel: DTBulletChatModel {
        set {
            _chatModel = newValue
            
            var attributeMessage: NSAttributedString?
            
            guard let messageType = BulletMessageType(rawValue: newValue.type) else {
                return
            }
            switch messageType {
            case .join:
                attributeMessage = NSAttributedString(string: "joined")
            case .mic_on:
                attributeMessage = NSAttributedString(string: "mic ON 🙋🙋🙋")
            case .mic_off:
                attributeMessage = NSAttributedString(string: "mic OFF 🔕")
            case .mute_other:
                attributeMessage = NSAttributedString(string: "muted you 🔕")
            case .start_screen:
                attributeMessage = NSAttributedString(string: "starts sharing 🖥")
//            case .caption_on:
//                attributeMessage = NSAttributedString(string: "turned on captions, your audio will be recorded.⚠️")
            case .local_tips, .text:
                attributeMessage = NSAttributedString(string: newValue.text)
            case .left, .video_on, .video_off: break
            }
            
            guard let attributeMessage else {
                return
            }
            
            if (messageType == .local_tips) {
                lbPrimary.attributedText = attributeMessage
            } else {
                var displayName: String? = newValue.name
                if let localNumber = TSAccountManager.localNumber(), newValue.id == localNumber {
                    displayName = "You"
                } else {
                    if newValue.id.hasPrefix(MeetingAccoutPrefix_Web) {
                        displayName = newValue.id.getWebUserName()
                    } else {
                        displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: newValue.id).removeBUMessage()
                    }
                    
                    if let name = displayName {
                        if name.count > 11 {
                            let index = name.index(name.startIndex, offsetBy: 11)
                            displayName = String(name[..<index]) + "..."
                        }
                    }
                }

                let jointMark = messageType == .text ? ": " : " "
                let finalText = NSMutableAttributedString(string: "\(displayName ?? "Unknown")" + jointMark, attributes: [.foregroundColor: UIColor.ows_themeBlueDark])
                finalText.append(attributeMessage)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineSpacing = 5
                paragraphStyle.lineBreakMode = .byWordWrapping
                finalText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: finalText.length))
                lbPrimary.attributedText = finalText
            }
        }
        get {
            _chatModel
        }
    }
    
    var _chatModel: DTBulletChatModel!

    var lbPrimary: UILabel!
    
    class func reuseIdentifier() -> String {
        return "DTBulletChatCellID"
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        
        let containerView = UIView()
        containerView.backgroundColor = UIColor(rgbHex: 0x1E2329).withAlphaComponent(0.9)
        containerView.layer.masksToBounds = true
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1.0
        containerView.layer.borderColor = UIColor.color(rgbHex: 0x32363E).cgColor
        contentView.addSubview(containerView)
        
        lbPrimary = UILabel()
        lbPrimary.textColor = .white
        lbPrimary.lineBreakMode = .byWordWrapping
        lbPrimary.numberOfLines = 2
        lbPrimary.font = .systemFont(ofSize: 16, weight: .regular)
        containerView.addSubview(lbPrimary)
        
        containerView.autoPinEdge(toSuperviewEdge: .top)
        containerView.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        containerView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        containerView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16, relation: .greaterThanOrEqual)

        lbPrimary.autoPinEdgesToSuperviewEdges(with: .init(hMargin: 12, vMargin: 8))
        lbPrimary.autoSetDimension(.height, toSize: 20, relation: .greaterThanOrEqual)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        lbPrimary.text = nil
        lbPrimary.attributedText = nil
    }
}

//    let attachment = NSTextAttachment()
//    attachment.image = UIImage(named: "ic_call_mic_on")
//    attachment.bounds = CGRectMake(-1, -3, 16, 16)
//    let attributeAttachment = NSAttributedString(attachment: attachment)
//    let attributeText = NSMutableAttributedString(string: " turned on mic 🎤🎤🎤")
//    attributeText.insert(attributeAttachment, at: 0)
//    attributeMessage = attributeText.copy() as? NSAttributedString
