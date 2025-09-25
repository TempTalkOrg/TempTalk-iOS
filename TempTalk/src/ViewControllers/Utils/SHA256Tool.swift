//
//  SHA256Tool.swift
//  Difft
//
//  Created by Henry on 2025/2/26.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import CryptoKit

@objc
public class SHA256Tool: NSObject {
    private let algorithm = SHA256.self
    private var difficulty: Int

    init(difficulty: Int) {
        self.difficulty = difficulty
    }

    // 验证解答
    func verifySolution(challenge: String, solution: String) -> Bool {
        let data = (challenge + solution).data(using: .utf8)!
        // 使用 SHA-256 算法进行加密
        let hash = SHA256.hash(data: data)
        // 将加密结果转为十六进制字符串
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return hex.hasPrefix(String(repeating: "1", count: difficulty))
    }
}

class RandomString {
    private static let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    private var length: Int

    init(length: Int) {
        self.length = length
    }

    func nextString() -> String {
        var result = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<RandomString.characters.count)
            let randomChar = RandomString.characters[RandomString.characters.index(RandomString.characters.startIndex, offsetBy: randomIndex)]
            result.append(randomChar)
        }
        return result
    }
}
