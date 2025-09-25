//
//  UIImage+Extension.swift
//  Signal
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    static func qrCode(_ string: String, foregroundColor: UIColor = .black, backgroundColor: UIColor = .white, largeSize: Bool = true) throws -> UIImage {
        
        guard let data = string.data(using: .utf8) else {
            throw OWSAssertionError("data wrapper failed")
        }
        
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw OWSAssertionError("filter was unexpectedly nil")
        }
        
        filter.setDefaults()
        filter.setValue(data, forKey: "inputMessage")

        guard let ciImage = filter.outputImage else {
            throw OWSAssertionError("ciImage was unexpectedly nil")
        }

        let colorParameters = [
            "inputColor0": CIColor(color: foregroundColor),
            "inputColor1": CIColor(color: backgroundColor)
        ]

        let recoloredCIImage = ciImage.applyingFilter("CIFalseColor", parameters: colorParameters)

        let scaledCIIimage = (largeSize
            ? recoloredCIImage.transformed(by: CGAffineTransform.scale(10.0))
            : recoloredCIImage)

        let context = CIContext(options: nil)
        
        guard let cgImage = context.createCGImage(scaledCIIimage, from: scaledCIIimage.extent) else {
            throw OWSAssertionError("cgImage was unexpectedly nil")
        }

        let image = UIImage(cgImage: cgImage)
        
        return image
    }
}
