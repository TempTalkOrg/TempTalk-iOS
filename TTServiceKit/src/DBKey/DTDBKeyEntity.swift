//
//  DTDBKeyEntity.swift
//  TTServiceKit
//
//  Created by Kris.s on 2023/9/25.
//
struct DTDBKeyEntity: Codable {
    var privateKey: String
    var publicKey: String
    var registerFlag: Bool
    var rekeyFlag: Bool
}

