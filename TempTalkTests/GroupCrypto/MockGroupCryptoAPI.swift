//
//  MockGroupCryptoAPI.swift
//  TempTalkTests
//

import Foundation
@testable import Yelling

final class MockGroupCryptoAPI: GroupCryptoAPI {

    private(set) var upgradeCallCount = 0
    private(set) var disposeCallCount = 0
    private(set) var lastUpgradeGroupId: String?
    private(set) var lastUpgradeRequest: UpgradeGroupCryptoRequest?
    private(set) var lastDisposeGroupId: String?
    private(set) var lastDisposeRequest: CryptoDisposeRequest?

    var upgradeError: Error?
    var disposeError: Error?

    func upgradeToEncrypted(groupId: String, request: UpgradeGroupCryptoRequest) async throws {
        upgradeCallCount += 1
        lastUpgradeGroupId = groupId
        lastUpgradeRequest = request
        if let error = upgradeError { throw error }
    }

    func cryptoDispose(groupId: String, request: CryptoDisposeRequest) async throws {
        disposeCallCount += 1
        lastDisposeGroupId = groupId
        lastDisposeRequest = request
        if let error = disposeError { throw error }
    }

    func reset() {
        upgradeCallCount = 0
        disposeCallCount = 0
        lastUpgradeGroupId = nil
        lastUpgradeRequest = nil
        lastDisposeGroupId = nil
        lastDisposeRequest = nil
        upgradeError = nil
        disposeError = nil
    }
}
