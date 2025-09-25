//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit

class ImageCacheRecord: NSObject {
    var variations: [CGFloat: UIImage]
    init(variations: [CGFloat: UIImage]) {
        self.variations = variations
    }
}

/**
 * A two dimensional hash, allowing you to store variations under a single key.
 * This is useful because we generate multiple diameters of an image, but when we
 * want to clear out the images for a key we want to clear out *all* variations.
 */
@objc
public class ImageCache: NSObject {

    let backingCache: LRUCache<NSObject, ImageCacheRecord>

    public override init() {
        self.backingCache = LRUCache(maxSize: 128, nseMaxSize:0)
    }

    @objc
    public func image(forKey key: NSObject, diameter: CGFloat) -> UIImage? {
        guard let record = backingCache.object(forKey: key) else {
            return nil
        }
        return record.variations[diameter]
    }

    @objc
    public func setImage(_ image: UIImage, forKey key: NSObject, diameter: CGFloat) {
        if let existingRecord = backingCache.object(forKey: key) {
            existingRecord.variations[diameter] = image
            backingCache.setObject(existingRecord, forKey: key)
        } else {
            let newRecord = ImageCacheRecord(variations: [diameter: image])
            backingCache.setObject(newRecord, forKey: key)
        }
    }

    @objc
    public func removeAllImages() {
        backingCache.removeAllObjects()
    }

    @objc
    public func removeAllImages(forKey key: NSObject) {
        backingCache.removeObject(forKey: key)
    }
}
