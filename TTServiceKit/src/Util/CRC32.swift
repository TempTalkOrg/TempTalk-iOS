//
// Copyright 2022 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import zlib

/// CRC32 implements the 32-bit cyclic redundancy check algorithm.
///
/// Example usage:
///
/// ```
/// var crc = CRC32()
///
/// crc.update(with: Data([1, 2, 3])
/// crc.update(with: Data([4, 5, 6])
///
/// let checksum: UInt32 = crc.value
/// ```
public struct CRC32 {
    private var rawValue: CUnsignedLong

    public var value: UInt32 { UInt32(rawValue) }

    public init() {
        self.init(rawValue: 0)
    }

    private init(rawValue: CUnsignedLong) {
        self.rawValue = rawValue
    }

    public func update(with data: Data) -> CRC32 {
        let newRawValue = data.withUnsafeBytes { bytes -> CUnsignedLong in
            let pointerForC = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self)
            return crc32(self.rawValue, pointerForC, UInt32(bytes.count))
        }
        return CRC32(rawValue: newRawValue)
    }
}

struct CRC32Util {
    private static let table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[idx]
        }
        return crc ^ 0xffffffff
    }

    static func checksum(_ string: String) -> UInt32 {
        let data = Data(string.utf8)
        return checksum(data)
    }
}
