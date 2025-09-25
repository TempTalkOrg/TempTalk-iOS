//
//  DTPickerViewController.swift
//  TTMessaging
//
//  Created by Ethan on 01/09/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit

@objcMembers
public class DTPickerViewController: OWSViewController {

    public weak var dataSource: DTPickerViewControllerDataSource?
    public weak var delegate: DTPickerViewControllerDelegate?
    
    var selectRow: (Int, Int, Bool)?

    lazy var backgroundView: UIView = {
        let backgroundView = UIView()
        backgroundView.backgroundColor = Theme.backgroundColor
//        backgroundView.setCornerRadius([.topLeft, .topRight], 10)
        if #available(iOS 16.2, *) {
            backgroundView.layer.cornerRadius = 10
            backgroundView.layer.masksToBounds = true
        }

        return backgroundView
    }()
    
    lazy var btnDone: UIButton = {
        let btnDone = UIButton(type: .custom)
        btnDone.titleLabel?.font = .systemFont(ofSize: 16)
        btnDone.setTitle("Done", for: .normal)
        btnDone.setTitle("Done", for: .highlighted)
        btnDone.addTarget(self, action: #selector(btnDoneAction), for: .touchUpInside)
        
        return btnDone
    }()
    
    lazy var btnCancel: UIButton = {
        let btnCancel = UIButton(type: .custom)
        btnCancel.titleLabel?.font = .systemFont(ofSize: 16)
        btnCancel.setTitle("Cancel", for: .normal)
        btnCancel.setTitle("Cancel", for: .highlighted)
        btnCancel.addTarget(self, action: #selector(btnCancelAction(_:)), for: .touchUpInside)

        return btnCancel
    }()
    
    lazy var pickerView: UIPickerView = {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        
        return pickerView
    }()
    
    private var bottomConstraint: NSLayoutConstraint!

    public override func applyTheme() {
        
        let themeBlue = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x82C1FC) : UIColor.ows_themeBlue
        
        guard isViewLoaded == true else {
            return
        }
        backgroundView.backgroundColor = Theme.backgroundColor
        btnCancel.setTitleColor(themeBlue, for: .normal)
        btnCancel.setTitleColor(themeBlue, for: .highlighted)
        btnDone.setTitleColor(themeBlue, for: .normal)
        btnDone.setTitleColor(themeBlue, for: .highlighted)
    }
    
    public override func loadView() {
        super.loadView()
        
        setupUI()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        NSLayoutConstraint.deactivate([bottomConstraint])
        self.bottomConstraint = self.backgroundView.autoPinEdge(toSuperviewEdge: .bottom)

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseInOut) {
            self.view.backgroundColor = .black.withAlphaComponent(0.2)
            self.view.layoutIfNeeded()
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()

        guard let selectRow = selectRow else {
            return
        }
        pickerView.selectRow(selectRow.0, inComponent: selectRow.1, animated: selectRow.2)
    }
    
    func setupUI() {
        
        view.backgroundColor = .clear
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(btnCancelAction(_:)))
        view.addGestureRecognizer(tap)
        
        view.addSubview(backgroundView)
        backgroundView.addSubview(btnCancel)
        backgroundView.addSubview(btnDone)
        backgroundView.addSubview(pickerView)
        
        bottomConstraint = backgroundView.autoPinEdge(toSuperviewEdge: .bottom, withInset: -300)
        backgroundView.autoPinEdge(toSuperviewEdge: .leading)
        backgroundView.autoPinEdge(toSuperviewEdge: .trailing)
        backgroundView.autoSetDimension(.height, toSize: 300)
        
        btnCancel.autoSetDimensions(to: CGSize(width: 80, height: 40))
        btnCancel.autoPinEdge(toSuperviewEdge: .leading)
        btnCancel.autoPinEdge(toSuperviewEdge: .top)
        
        btnDone.autoSetDimensions(to: CGSize(width: 80, height: 40))
        btnDone.autoPinEdge(toSuperviewEdge: .trailing)
        btnDone.autoPinEdge(toSuperviewEdge: .top)
        
        pickerView.autoPinEdge(toSuperviewEdge: .leading)
        pickerView.autoPinEdge(toSuperviewEdge: .trailing)
        pickerView.autoPinEdge(.top, to: .bottom, of: btnCancel)
        pickerView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20)

        applyTheme()
    }
    
    @objc
    func btnDoneAction() {
        btnCancelAction(nil)
        
        guard let delegate = delegate, delegate.responds(to:#selector(DTPickerViewControllerDelegate.doneAction)) else {
            return
        }
        delegate.doneAction?()
    }
    
    @objc
    func btnCancelAction(_ sender: Any?) {
        if let tap = sender as? UITapGestureRecognizer {
            let touch = tap.location(in: view)
            guard touch.y <= view.height - backgroundView.height else {
                return
            }
        }
        
        NSLayoutConstraint.deactivate([bottomConstraint])
        bottomConstraint = backgroundView.autoPinEdge(toSuperviewEdge: .bottom, withInset: -300)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: .curveEaseOut) {
            self.view.backgroundColor = .clear
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false)
        }

    }
    
    public
    func selectRow(row: Int, inComponent: Int = 0, animated: Bool = false) {
        selectRow = (row, inComponent, animated)
    }
}

extension DTPickerViewController: UIPickerViewDataSource {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        guard let dataSource = dataSource else {
            return 0
        }
        return dataSource.numberOfComponents(in: self)
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        guard let dataSource = dataSource else {
            return 0
        }
        
        return dataSource.pickerViewController(self, numberOfRowsInComponent: component)
    }

}

extension DTPickerViewController: UIPickerViewDelegate {
        
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let delegate = delegate else {
            return
        }
                                                     
        delegate.pickerViewController(self, didSelectRow: row, inComponent: component)
    }
    
    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        guard let delegate = delegate else {
            return 40
        }
        
        return delegate.pickerViewController(self, rowHeightForComponent: component)
    }
    
//    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        guard let delegate = delegate else {
//            return nil
//        }
//
//        return delegate.pickerViewController(self, titleForRow: row, forComponent: component)
//    }
    
    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        guard let delegate = delegate else {
            return UIView()
        }
        
        return delegate.pickerViewController(self, viewForRow: row, forComponent: component, reusing: view)
    }
        
}

typealias PickerDataSource = DTPickerViewControllerDataSource
@objc public protocol DTPickerViewControllerDataSource: NSObjectProtocol {
    
    func numberOfComponents(in pickerViewController: DTPickerViewController) -> Int
    
    func pickerViewController(_ pickerViewController: DTPickerViewController, numberOfRowsInComponent component: Int) -> Int
}

typealias PickerDelegate = DTPickerViewControllerDelegate
@objc public protocol DTPickerViewControllerDelegate: NSObjectProtocol {
            
    func pickerViewController(_ pickerViewController: DTPickerViewController, didSelectRow row: Int, inComponent component: Int)

    func pickerViewController(_ pickerViewController: DTPickerViewController, rowHeightForComponent component: Int) -> CGFloat
    
    func pickerViewController(_ pickerViewController: DTPickerViewController, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView
        
    @objc optional func doneAction()
    
//    func pickerViewController(_ pickerViewController: DTPickerViewController, titleForRow row: Int, forComponent component: Int) -> String?
    
}
