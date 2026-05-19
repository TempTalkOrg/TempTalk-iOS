//
//  MockGroupCryptoKeyStore.swift
//  TempTalkTests
//

import Foundation
@testable import Yelling

final class MockGroupCryptoKeyStore: GroupCryptoKeyStore {

    private(set) var storage: [String: String] = [:]
    private(set) var fetchCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var deleteCallCount = 0

    func fetchRGroup(forGid gid: String, transaction: SDSAnyReadTransaction) -> String? {
        fetchCallCount += 1
        return storage[gid]
    }

    @discardableResult
    func saveRGroupIfNeeded(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) -> Bool {
        saveCallCount += 1
        if storage[gid] != nil {
            return false
        }
        storage[gid] = rGroup
        return true
    }

    private(set) var updateCallCount = 0

    func updateRGroup(gid: String, rGroup: String, transaction: SDSAnyWriteTransaction) {
        updateCallCount += 1
        storage[gid] = rGroup
    }

    func deleteRGroup(forGid gid: String, transaction: SDSAnyWriteTransaction) {
        deleteCallCount += 1
        storage.removeValue(forKey: gid)
    }

    func reset() {
        storage.removeAll()
        fetchCallCount = 0
        saveCallCount = 0
        updateCallCount = 0
        deleteCallCount = 0
    }
}
