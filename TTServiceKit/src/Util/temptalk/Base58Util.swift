//
//  Base58.swift
// 
//  Copyright © 2019 BitcoinKit developers
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
//  THE SOFTWARE.
//

import Foundation

private struct _Base58: Encoding {
    static let baseAlphabets = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    static var zeroAlphabet: Character = "1"
    static var base: Int = 58

    static func sizeFromByte(size: Int) -> Int {
        return size * 138 / 100 + 1
    }
    static func sizeFromBase(size: Int) -> Int {
        return size * 733 / 1000 + 1
    }
}

public struct Base58 {
    public static func encode(_ bytes: Data) -> String {
        return _Base58.encode(bytes)
    }
    public static func decode(_ string: String) -> Data? {
        return _Base58.decode(string)
    }
}

@objc public class Base58Util: NSObject {
    @objc public static func encode(_ bytes: Data) -> String {
        return Base58.encode(bytes)
    }
    
    @objc public static func decode(_ string: String) -> Data? {
        return Base58.decode(string)
    }
    
    /// 新增：支持数字转 Base58
    @objc public static func encodeNumber(_ number: UInt64) -> String {
        var value = number
        var bytes = [UInt8]()
        
        // 转成大端字节序
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        
        let data = Data(bytes)
        return Base58.encode(data)
    }
    
    /// 新增：支持 Base58 解码回数字
//    @objc public static func decodeToNumber(_ string: String) -> UInt64 {
//        guard let data = Base58.decode(string) else { return 0 }
//        
//        var result: UInt64 = 0
//        for byte in data {
//            result = (result << 8) | UInt64(byte)
//        }
//        return result
//    }
}



