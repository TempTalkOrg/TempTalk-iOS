//
//  DTImageRecognizeButton.swift
//  Difft
//
//  Created by Jaymin on 2024/5/31.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit

class DTImageRecognizeButton: UIView {
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        let image = UIImage(named: "scan_photo_icon")?.withRenderingMode(.alwaysTemplate)
        imageView.image = image
        return imageView
    }()
    
    @objc
    var isSelected = false {
        didSet {
            applyTheme()
        }
    }
    
    @objc
    var didTapCallback: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        applyTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGesture)
    }
    
    @objc func didTap() {
        didTapCallback?()
    }
    
    @objc func applyTheme() {
        iconImageView.tintColor = .white
        if isSelected {
            backgroundColor = Theme.themeBlueColor
        } else {
            backgroundColor = UIColor(rgbHex: 0x1E2329)
        }
    }
}
