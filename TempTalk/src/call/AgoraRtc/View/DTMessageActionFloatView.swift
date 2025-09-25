//
//  DTMessageActionFloatView.swift
//  Signal
//
//  Created by Felix on 2021/9/17.
//

import UIKit

private var kActionViewWidth: CGFloat {
    return DateUtil.isChinese() ? 145 : 175
}   //container view width
private var kActionViewHeight: CGFloat = 156    //container view height
private let kActionButtonHeight: CGFloat = 44   //button height
private let kFirstButtonY: CGFloat = 2 //the first button Y value

class DTMessageActionFloatView: UIView {
    @objc weak var delegate: ActionFloatViewDelegate?
//    let disposeBag = DisposeBag()
    @objc open var isAnimating : Bool = false
    var actionViewHeight : CGFloat = kActionViewHeight
    override init (frame: CGRect) {
        super.init(frame : frame)
    }
    
    convenience init () {
        self.init(frame:CGRect.zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
   @objc open func layoutSubContent() {
        self.backgroundColor = UIColor.clear
       
        let actionTitles = [
            Localized("FLOATVIEW_ACTION_CREATE_GROUP"),
            Localized("FLOATVIEW_ACTION_ADD_CONTACTS"),
            Localized("ENTER_CODE_MYCODE"),
            Localized("FLOATVIEW_ACTION_SCAN"),
        ]
        let actionImages = [
            TSAsset.Floataction_create_group.image,
            TSAsset.Floataction_add_contacts.image,
            TSAsset.Floataction_qrcode.image,
            TSAsset.Floataction_scan.image,
       ]
        
        if actionImages.count >= 4 {
            actionViewHeight = kActionViewHeight + CGFloat((actionImages.count - 3) * 44)
        }
        
        //Init containerView
        let containerView : UIView = UIView()
        containerView.backgroundColor = UIColor.clear
        self.addSubview(containerView)
        containerView.autoPinEdge(toSuperviewEdge: ALEdge.top, withInset: 0)
        containerView.autoPinEdge(toSuperviewEdge: ALEdge.right, withInset: 5)
        containerView.autoSetDimensions(to: CGSize.init(width: kActionViewWidth, height: actionViewHeight))
        
        //Init bgImageView
        let stretchInsets = UIEdgeInsets.init(top: 14, left: 6, bottom: 6, right: 34)
        let bubbleMaskImage = TSAsset.MessageRightTopBg.image.resizableImage(withCapInsets: stretchInsets, resizingMode: .stretch)
        let bgImageView: UIImageView = UIImageView(image: bubbleMaskImage)
        containerView.addSubview(bgImageView)
        bgImageView.autoPinEdgesToSuperviewEdges()
        
        //init custom buttons
        var yValue = kFirstButtonY
        for index in 0 ..< actionImages.count {
            let itemButton: UIButton = UIButton(type: .custom)
            itemButton.backgroundColor = UIColor.clear
            itemButton.titleLabel!.font = UIFont.systemFont(ofSize: 17)
            itemButton.setTitleColor(UIColor.white, for: UIControl.State())
            itemButton.setTitleColor(UIColor.white, for: .highlighted)
            let title = actionTitles[index]
//            let title = Dollar.fetch(actionTitles, index, orElse: "")
            itemButton.setTitle(title, for: .normal)
            itemButton.setTitle(title, for: .highlighted)
            let image = actionImages[index]
            image.withRenderingMode(UIImage.RenderingMode.alwaysTemplate)
//            let image = Dollar.fetch(actionImages, index, orElse: nil)
            itemButton.setImage(image, for: .normal)
            itemButton.setImage(image, for: .highlighted)
            itemButton.tintColor = UIColor.color(rgbHex: 0xffffff)
            itemButton.addTarget(self, action: #selector(DTMessageActionFloatView.buttonTaped(_:)), for: UIControl.Event.touchUpInside)
            itemButton.contentHorizontalAlignment = .left
            itemButton.contentEdgeInsets = UIEdgeInsets.init(top: 0, left: 12, bottom: 0, right: 0)
            itemButton.titleEdgeInsets = UIEdgeInsets.init(top: 0, left: 10, bottom: 0, right: 0)
            itemButton.tag = index
            containerView.addSubview(itemButton)
            
            itemButton.autoPinTopToSuperviewMargin(withInset: yValue)
            itemButton.autoPinTrailingToSuperviewMargin()
            itemButton.autoPinWidthToSuperview()
            itemButton.autoSetDimension(ALDimension.height, toSize: kActionButtonHeight)

            yValue += kActionButtonHeight
        }
        
        self.isHidden = true
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        tapAction()
    }
    
    @objc func tapAction() {
        self.hide(true)
    }
    
    @objc func updateContent (){
        for view in self.subviews {
            view.removeFromSuperview()
        }
        self.layoutSubContent()
        self.hide(false)
    }
    
    @objc func buttonTaped(_ sender: UIButton!) {
        guard let delegate = self.delegate else {
            self.hide(true)
            return
        }
        
        if delegate.responds(to: #selector(ActionFloatViewDelegate.floatViewTapItemIndex(_:))) {
            
            let type = ActionFloatViewItemType(rawValue:sender.tag)!
            delegate.floatViewTapItemIndex(type)
            self.hide(true)
        }
    }
    
    /**
     Hide the float view
     
     - parameter hide: is hide
     */
    @objc func hide(_ hide: Bool) {
        if hide {
            self.alpha = 1.0
            self.isAnimating = true;
            UIView.animate(withDuration: 0.2 ,
                animations: {
                    self.alpha = 0.0
                },
                completion: { finish in
                self.isAnimating = false;
                    self.isHidden = true
                    self.alpha = 1.0
                    self.removeFromSuperview()
                    self.delegate?.floatViewDidRemoveFromSuperView()
            })
        } else {
            self.alpha = 1.0
            self.isHidden = false
        }
    }

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    deinit {
        OWSLogger.info("DTMessageActionFloatView -> deinit::")
    }
}



/**
 *  TSMessageViewController Float view delegate methods
 */
@objc protocol ActionFloatViewDelegate: NSObjectProtocol {
    /**
     Tap the item with index
     */
    func floatViewTapItemIndex(_ type: ActionFloatViewItemType)
   
    func floatViewDidRemoveFromSuperView()

}

@objc enum ActionFloatViewItemType: Int {
    case createGroup = 0, addContacts, myCode, scan
}
