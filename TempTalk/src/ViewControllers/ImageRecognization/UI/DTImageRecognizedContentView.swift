//
//  DTImageRecognizedContentView.swift
//  Difft
//
//  Created by Jaymin on 2024/5/31.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SnapKit
import TTServiceKit

@objc
protocol DTImageRecognizedContentViewDelegate: AnyObject {
    func recognizedViewDidTapped(_ view: DTImageRecognizedContentView)
    func recognizedView(_ view: DTImageRecognizedContentView, didTapQRCodeWith payload: String)
}

// 封装下方便 OC 调用（DTImageRecognizeEngine 中定义的一些 struct enum 在 oc 中无法直接使用）
extension DTImageRecognizedContentView {
    @objc static func recognize(
        image: UIImage,
        size: CGSize,
        compeletion: @escaping (DTImageRecognizedContentView?) -> Void
    ) {
        DTImageRecognizationEngine.recognize(image: image).done { results in
            DispatchMainThreadSafe {
                let contentView = DTImageRecognizedContentView(imageSize: size, recognitions: results)
                compeletion(contentView)
            }
        }.catch { error in
            Logger.error("Recognize image failed, error: \(error)")
            DispatchMainThreadSafe {
                compeletion(nil)
            }
        }
    }
}

class DTImageRecognizedContentView: UIView {

    private let imageSize: CGSize
    private let recognitions: [DTImageRecognizedContent]
    
    private lazy var maskImageView = UIImageView()
    private lazy var selectionView = DTImageRecognizedTextSelectionView(recognitions: recognitions)
    
    @objc
    weak var delegate: DTImageRecognizedContentViewDelegate?
    
    init(imageSize: CGSize, recognitions: [DTImageRecognizedContent]) {
        self.imageSize = imageSize
        self.recognitions = recognitions
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        maskImageView.image = generateMaskImage(size: imageSize, recognitions: recognitions)
        addSubview(maskImageView)
        maskImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(selectionView.highlightAreaView)
        addSubview(selectionView)
        selectionView.highlightAreaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        selectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapContentView(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    @objc
    private func didTapContentView(_ sender: UIGestureRecognizer) {
        let location = sender.location(in: self)
        for recognition in self.recognitions {
            let mappedRect = recognition.rect.convertTo(size: self.bounds.size)
            if mappedRect.boundingFrame.contains(location) {
                if case let .qrCode(payload) = recognition.content {
                    delegate?.recognizedView(self, didTapQRCodeWith: payload)
                    return
                }
            }
        }
        
        delegate?.recognizedViewDidTapped(self)
    }
    
    @objc
    func dismissSelection() {
       let _ = selectionView.dismissSelection()
    }
    
    private func generateMaskImage(size: CGSize, recognitions: [DTImageRecognizedContent]) -> UIImage? {
        return generateImage(size, opaque: false, scale: 1.0, rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)
            
            context.setFillColor(UIColor(rgb: 0x000000, alpha: 0.4).cgColor)
            context.fill(bounds)
            
            context.setBlendMode(.clear)
            recognitions.forEach {
                let mappedRect = $0.rect.convertTo(
                    size: size,
                    insets: .init(top: -4, left: -2, bottom: -4, right: -2)
                )
                let path = UIBezierPath(rect: mappedRect, radius: 3.5)
                context.addPath(path.cgPath)
                context.fillPath()
            }
        })
    }
}

extension UIBezierPath {
    convenience init(rect: DTImageRecognizedContent.Rect, radius r: CGFloat) {
        let left  = CGFloat.pi
        let up    = CGFloat.pi * 1.5
        let down  = CGFloat.pi * 0.5
        let right = CGFloat.pi * 0.0
        
        self.init()
        
        addArc(withCenter: CGPoint(x: rect.topLeft.x + r, y: rect.topLeft.y + r), radius: r, startAngle: left, endAngle: up, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.topRight.x - r, y: rect.topRight.y + r), radius: r, startAngle: up, endAngle: right, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.bottomRight.x - r, y: rect.bottomRight.y - r), radius: r, startAngle: right, endAngle: down, clockwise: true)
        addArc(withCenter: CGPoint(x: rect.bottomLeft.x + r, y: rect.bottomLeft.y - r), radius: r, startAngle: down, endAngle: left, clockwise: true)
        close()
    }
}
