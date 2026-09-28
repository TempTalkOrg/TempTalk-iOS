//
//  UIImage+Extension.swift
//  Signal
//
//  Created by User on 2023/1/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UIKit
import QRCodeGenerator

extension UIImage {
    static func qrCode(_ string: String, foregroundColor: UIColor = .black, backgroundColor: UIColor = .white, largeSize: Bool = true) throws -> UIImage {
        // Core Image's first CIContext render can take several seconds on a
        // cold launch. Generate the QR matrix in Swift and draw it directly so
        // the first QR code is as fast as subsequent refreshes.
        let qrCode = try QRCode.encode(text: string, ecl: .medium)
        let quietZoneModules = 4
        let moduleScale = CGFloat(largeSize ? 10 : 1)
        let imageSide = CGFloat(qrCode.size + quietZoneModules * 2) * moduleScale

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = backgroundColor.cgColor.alpha == 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: imageSide, height: imageSide),
            format: format
        )

        return renderer.image { context in
            context.cgContext.setFillColor(backgroundColor.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: imageSide, height: imageSide))

            context.cgContext.setFillColor(foregroundColor.cgColor)
            for y in 0..<qrCode.size {
                for x in 0..<qrCode.size where qrCode.getModule(x: x, y: y) {
                    context.cgContext.fill(
                        CGRect(
                            x: CGFloat(x + quietZoneModules) * moduleScale,
                            y: CGFloat(y + quietZoneModules) * moduleScale,
                            width: moduleScale,
                            height: moduleScale
                        )
                    )
                }
            }
        }
    }
}
