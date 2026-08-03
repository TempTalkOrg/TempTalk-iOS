//
//  DTGIFSearchAsset+Extension.swift
//  TempTalk
//
//  Aspect-ratio and asset-description helpers for GIF models.
//

import Foundation
import CoreGraphics

// MARK: - Aspect Ratio

extension DTGIFSearchAsset {
    var widthValue: CGFloat {
        transformStringToCGFloat(stringValue: width)
    }

    var heightValue: CGFloat {
        transformStringToCGFloat(stringValue: height)
    }

    var aspectRatio: CGFloat {
        let height = heightValue
        guard height > 0 else {
            return 1.0
        }
        let width = widthValue
        return width / height
    }

    private func transformStringToCGFloat(stringValue: String) -> CGFloat {
        guard !stringValue.isEmpty else {
            return .zero
        }
        guard let number = NumberFormatter().number(from: stringValue) else {
            return .zero
        }
        return CGFloat(truncating: number)
    }
}

extension DTGIFSearchAssetInfo {
    var aspectRatio: CGFloat {
        originalAsset.aspectRatio
    }
}

// MARK: - Asset Description

extension DTGIFSearchAsset {
    /// WebP rendition — the only rendition the picker uses. Grid preview, sending, and favoriting
    /// all use WebP; the GIF rendition is ignored.
    var webpAssetDescription: DTAssetDescription? {
        .init(urlString: webp)
    }
}
