//
//  DTTableViewDefaultStyle.swift
//  Signal
//
//  Created by hornet on 2023/5/23.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

enum TableViewCellBorderType {
    case none
    case all
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var rectCorner: UIRectCorner {
        switch self {
        case .none:
            return []
        case .all:
            return [.topLeft,.topRight,.bottomLeft,.bottomRight]
        case .top:
            return [.topLeft, .topRight]
        case .bottom:
            return [.bottomLeft, .bottomRight]
        case .left:
            return [.topLeft, .bottomLeft]
        case .right:
            return [.topRight, .bottomRight]
        case .topLeft:
            return [.topLeft]
        case .topRight:
            return [.topRight]
        case .bottomLeft:
            return [.bottomLeft]
        case .bottomRight:
            return [.bottomRight]
        }
    }
}

let  accessoryImageViewSize : CGFloat = 16
let defaultBaseStyleCellMargin : CGFloat = -14
///仅仅作为基类使用
class DTDefaultBaseStyleCell: UITableViewCell {
    var inset: CGFloat = 16
    let icon: UIImageView = UIImageView()
    let titleLable: UILabel = UILabel()
    let seperateLineView: UIView = UIView()
    var titleTextColor : UIColor = Theme.primaryTextColor {
        didSet {
            titleLable.textColor = titleTextColor
        }
    }
    var model : DTSettingItem?
    
    var longPressDelegate:DTDefaultBaseStyleCellLongPressDelegate?
    var accessoryImageViewLayoutConstraint : NSLayoutConstraint?
    public lazy var accessoryImageView: UIImageView = {
        let accessoryImageView = UIImageView()
        accessoryImageView.image = UIImage(named: "default_accessory_arrow")
        return accessoryImageView
    }()
    var showAccessoryImageView = true {
        didSet {
            accessoryImageView.isHidden = !showAccessoryImageView
        }
    }
    var borderType : TableViewCellBorderType = .none
    
    func setBorder(_ borderType: TableViewCellBorderType) {
        let maskLayer = CAShapeLayer()
        // 将borderType转换为UIRectCorner枚举类型，并用它来创建圆角路径。
        maskLayer.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: contentView.bounds.width, height: contentView.bounds.height),
                                      byRoundingCorners: borderType.rectCorner,
                                      cornerRadii: CGSize(width: 10, height: 10)).cgPath
        contentView.layer.mask = maskLayer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset))
        setBorder(borderType)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.autoresizingMask = []
        self.prepareUI()
        self.prepareUILayout()
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressClick(_:)))
        self.addGestureRecognizer(longPressRecognizer)
    }
    
    func reloadCell<T: DTSettingItem>(model: T) {
        self.model = model
        // 你的代码
        titleLable.text = model.title
        titleLable.sizeToFit()
        applyTheme()
        guard model.cellStyle != nil else { return }
    }
    
    func applyTheme()  {
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultTableCellBackgroundColor
        titleLable.textColor = titleTextColor
        seperateLineView.backgroundColor = Theme.defaultBackgroundColor
    }
    
    var cornersToRound: UIRectCorner = .allCorners {
        didSet {
            setNeedsLayout()
        }
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepareUI() {
        contentView.addSubview(titleLable)
        contentView.addSubview(accessoryImageView)
        contentView.addSubview(seperateLineView)
        titleLable.font = UIFont.ows_dynamicTypeBody
    }
    
    func prepareUILayout() {
        titleLable.autoPinEdge(toSuperviewEdge: .left ,withInset: 16)
        titleLable.autoVCenterInSuperview()
        
        accessoryImageView.autoPinEdge(.right, to: .right, of: contentView , withOffset: -14)
        accessoryImageViewLayoutConstraint = accessoryImageView.autoSetDimension(.width, toSize: accessoryImageViewSize)
        accessoryImageView.autoSetDimension(.height, toSize: accessoryImageViewSize)
        accessoryImageView.autoVCenterInSuperview()
        
        seperateLineView.autoPinEdge(toSuperviewEdge: .left ,withInset: 0)
        seperateLineView.autoPinEdge(toSuperviewEdge: .right ,withInset: 0)
        seperateLineView.autoPinEdge(toSuperviewEdge: .bottom ,withInset: 0)
        seperateLineView.autoSetDimension(.height, toSize: 1.0)
    }
    
    @objc func longPressClick(_ longPressGesture: UILongPressGestureRecognizer)  {
        self.longPressDelegate?.longPressClick(self, longPressGesture: longPressGesture)
    }
}

protocol DTDefaultBaseStyleCellLongPressDelegate: NSObjectProtocol {
    func longPressClick(_ cell: DTDefaultBaseStyleCell, longPressGesture: UILongPressGestureRecognizer)
}
