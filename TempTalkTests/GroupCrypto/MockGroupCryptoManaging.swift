//
//  MockGroupCryptoManaging.swift
//  TempTalkTests
//

import Foundation
@testable import Yelling

final class MockGroupCryptoManaging: GroupCryptoManaging {

    var stubbedIsEncrypted = false
    var stubbedHasRGroup = false
    var stubbedDecryptedName: String?
    var stubbedDecryptedAvatar: String?

    private(set) var isEncryptedCallCount = 0
    private(set) var hasRGroupCallCount = 0
    private(set) var decryptedNameCallCount = 0

    func isEncryptedGroup(groupCryptoMode: Int) -> Bool {
        isEncryptedCallCount += 1
        return groupCryptoMode > 0
    }

    func hasRGroup(gid: String, transaction: SDSAnyReadTransaction) -> Bool {
        hasRGroupCallCount += 1
        return stubbedHasRGroup
    }

    func decryptedGroupName(gid: String,
                            encryptedName: String?,
                            transaction: SDSAnyReadTransaction) -> String? {
        decryptedNameCallCount += 1
        return stubbedDecryptedName
    }

    func decryptedGroupAvatar(gid: String,
                              encryptedAvatar: String?,
                              transaction: SDSAnyReadTransaction) -> String? {
        return stubbedDecryptedAvatar
    }

    func prepareEncryptedGroupCreation(groupName: String,
                                       avatar: String?,
                                       memberUids: [String]) -> EncryptedGroupCreationParams? { nil }

    func prepareMemberBindings(gid: String,
                               newMemberUids: [String],
                               transaction: SDSAnyReadTransaction) -> [GroupMemberBinding]? { nil }

    func encryptGroupName(gid: String,
                          plainName: String,
                          transaction: SDSAnyReadTransaction) -> String? { nil }

    func encryptGroupAvatar(gid: String,
                            plainAvatar: String,
                            transaction: SDSAnyReadTransaction) -> String? { nil }

    @discardableResult
    func saveRGroupIfNeeded(gid: String,
                            rGroup: Data,
                            transaction: SDSAnyWriteTransaction) -> Bool { false }

    func getRGroupData(gid: String,
                       transaction: SDSAnyReadTransaction) -> Data? { nil }

    private(set) var deleteRGroupCallCount = 0
    private(set) var lastDeletedGid: String?

    @discardableResult
    func deleteRGroup(gid: String, transaction: SDSAnyWriteTransaction) -> Bool {
        deleteRGroupCallCount += 1
        lastDeletedGid = gid
        return true
    }

    func verifyMember(gid: String,
                      uid: String,
                      uidSignature: String,
                      transaction: SDSAnyReadTransaction) -> Bool? { nil }

    func prepareUpgradeToEncrypted(gid: String,
                                   groupName: String,
                                   avatar: String?,
                                   memberUids: [String],
                                   transaction: SDSAnyReadTransaction) -> EncryptedGroupCreationParams? { nil }

    func reset() {
        stubbedIsEncrypted = false
        stubbedHasRGroup = false
        stubbedDecryptedName = nil
        stubbedDecryptedAvatar = nil
        isEncryptedCallCount = 0
        hasRGroupCallCount = 0
        decryptedNameCallCount = 0
        deleteRGroupCallCount = 0
        lastDeletedGid = nil
    }
}
