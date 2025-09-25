//
//  OWSAudioSliderView.swift
//  Difft
//
//  Created by Jaymin on 2024/5/21.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
class OWSAudioSliderView: UISlider {
    private var trackHeight: CGFloat = 4
    private var thumbRadius: CGFloat = 16
    
    @objc
    init(trackHeight: CGFloat = 4, thumbRadius: CGFloat = 16) {
        self.trackHeight = trackHeight
        self.thumbRadius = thumbRadius
        
        super.init(frame: .zero)
        
        let thumb = thumbImage(radius: thumbRadius)
        setThumbImage(thumb, for: .normal)
        setThumbImage(thumb, for: .highlighted)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Custom thumb view which will be converted to UIImage
    // and set as thumb. You can customize it's colors, border, etc.
    private lazy var thumbView: UIView = {
        let thumb = UIView()
        thumb.backgroundColor = .white //thumbTintColor
        thumb.layer.borderWidth = 0.4
        thumb.layer.borderColor = UIColor.color(rgbHex: 0x181A20).withAlphaComponent(0.4).cgColor
        return thumb
    }()
    
    private func thumbImage(radius: CGFloat) -> UIImage {
        // Set proper frame
        // y: radius / 2 will correctly offset the thumb
        
        thumbView.frame = CGRect(x: 0, y: radius / 2, width: radius, height: radius)
        thumbView.layer.cornerRadius = radius / 2
        
        // Convert thumbView to UIImage
        // See this: https://stackoverflow.com/a/41288197/7235585
        
        let renderer = UIGraphicsImageRenderer(bounds: thumbView.bounds)
        return renderer.image { rendererContext in
            thumbView.layer.render(in: rendererContext.cgContext)
        }
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        // Set custom track height
        // As seen here: https://stackoverflow.com/a/49428606/7235585
        var newRect = super.trackRect(forBounds: bounds)
        newRect.size.height = trackHeight
        return newRect
    }
}
