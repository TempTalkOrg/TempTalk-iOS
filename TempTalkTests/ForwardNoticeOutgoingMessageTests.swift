import XCTest
@testable import Yelling

final class ForwardNoticeOutgoingMessageTests: XCTestCase {

    // MARK: - Primary payload

    func test_forwardNoticeMessage_buildPlainTextData_containsForwardNoticePayload() throws {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "target-user"),
            scene: .combined,
            sourceAuthorIds: ["alice", "bob"],
            messageCount: 3,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        let data = try XCTUnwrap(message.buildPlainTextData(makeRecipient(recipientId: "target-user")))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.hasForwardNotice)
        XCTAssertEqual(content.forwardNotice.scene.rawValue, DTForwardNoticeScene.combined.rawValue)
        XCTAssertEqual(content.forwardNotice.sourceAuthorIds, ["alice", "bob"])
        XCTAssertEqual(content.forwardNotice.messageCount, 3)
    }

    func test_forwardNoticeMessage_buildPlainTextData_fillsConversationForOneOnOne() throws {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "peer-uid"),
            scene: .oneByOne,
            sourceAuthorIds: ["alice"],
            messageCount: 2,
            sourceConversation: .oneOnOne(number: "peer-uid")
        )

        let data = try XCTUnwrap(message.buildPlainTextData(makeRecipient(recipientId: "peer-uid")))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.forwardNotice.hasConversation)
        XCTAssertEqual(content.forwardNotice.conversation.number, "peer-uid")
        XCTAssertEqual(content.forwardNotice.conversation.groupID.count, 0)
    }

    func test_forwardNoticeMessage_buildPlainTextData_fillsConversationForGroup() throws {
        let groupId = Data([0x01, 0x02, 0x03, 0x04])
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "anyone"),
            scene: .combined,
            sourceAuthorIds: ["alice"],
            messageCount: 5,
            sourceConversation: .group(groupId: groupId)
        )

        let data = try XCTUnwrap(message.buildPlainTextData(makeRecipient(recipientId: "anyone")))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.forwardNotice.hasConversation)
        XCTAssertEqual(content.forwardNotice.conversation.groupID, groupId)
    }

    func test_forwardNoticeMessage_buildParams_setsMsgTypeToForwardNotice() throws {
        let thread = makeThread(contactId: "target-user")
        let recipient = makeRecipient(recipientId: "target-user")
        let message = TSOutgoingForwardNoticeMessage(
            thread: thread,
            scene: .single,
            sourceAuthorIds: ["alice"],
            messageCount: 1,
            sourceConversation: .oneOnOne(number: "target-user")
        )
        let serializedData = try XCTUnwrap(message.buildPlainTextData(recipient))
        let paramsBuilder = DTMessageParamsBuilder()

        let params = try XCTUnwrap(
            paramsBuilder.buildParams(
                with: message,
                to: thread,
                recipient: recipient,
                messageType: TSEncryptedWhisperMessageType,
                serializedData: serializedData,
                legacySerializedData: nil,
                recipientPeerContexts: [],
                syncContent: nil
            )
        )

        XCTAssertEqual(params["msgType"] as? Int32, 14)
    }

    // MARK: - Sync payload (v3: SyncMessage.forwardNoticeSync 直接是 ForwardNoticeMessage)

    func test_syncForwardNoticeMessage_buildParams_setsMsgTypeToSync() throws {
        let thread = makeThread(contactId: "target-user")
        let recipient = makeRecipient(recipientId: "self-user")
        let message = DTOutgoingSyncForwardNoticeMessage(
            thread: thread,
            scene: .oneByOne,
            sourceAuthorIds: ["alice", "bob"],
            messageCount: 2,
            sourceConversation: .oneOnOne(number: "target-user")
        )
        let serializedData = try XCTUnwrap(message.buildPlainTextData(recipient))
        let content = try DifftServiceProtos_Content(serializedData: serializedData)
        let paramsBuilder = DTMessageParamsBuilder()

        let params = try XCTUnwrap(
            paramsBuilder.buildParams(
                with: message,
                to: thread,
                recipient: recipient,
                messageType: TSEncryptedWhisperMessageType,
                serializedData: serializedData,
                legacySerializedData: nil,
                recipientPeerContexts: [],
                syncContent: nil
            )
        )

        XCTAssertTrue(content.hasSyncMessage)
        XCTAssertTrue(content.syncMessage.hasForwardNoticeSync)
        // v3: forwardNoticeSync 直接就是 ForwardNoticeMessage — 字段直接访问
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.conversation.number, "target-user")
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.messageCount, 2)
        XCTAssertEqual(params["msgType"] as? Int32, 2)
    }

    func test_syncForwardNoticeMessage_buildPlainTextData_containsFullSyncPayload() throws {
        let thread = makeThread(contactId: "target-user")
        let recipient = makeRecipient(recipientId: "self-user")
        let message = DTOutgoingSyncForwardNoticeMessage(
            thread: thread,
            scene: .combined,
            sourceAuthorIds: ["alice", "bob", "carol"],
            messageCount: 3,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        let data = try XCTUnwrap(message.buildPlainTextData(recipient))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.hasSyncMessage)
        XCTAssertTrue(content.syncMessage.hasForwardNoticeSync)
        XCTAssertEqual(
            content.syncMessage.forwardNoticeSync.scene.rawValue,
            DTForwardNoticeScene.combined.rawValue
        )
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.sourceAuthorIds, ["alice", "bob", "carol"])
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.messageCount, 3)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.conversation.number, "target-user")
    }

    // MARK: - v4 sync via syncContent

    func test_forwardNoticeMessage_buildSyncPlainTextData_containsSyncPayload() throws {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "target-user"),
            scene: .combined,
            sourceAuthorIds: ["alice", "bob"],
            messageCount: 3,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        let data = try XCTUnwrap(message.buildSyncPlainTextData(makeRecipient(recipientId: "self-user")))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.hasSyncMessage)
        XCTAssertTrue(content.syncMessage.hasForwardNoticeSync)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.scene.rawValue, DTForwardNoticeScene.combined.rawValue)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.sourceAuthorIds, ["alice", "bob"])
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.messageCount, 3)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.conversation.number, "target-user")
    }

    // MARK: - Runtime flags

    func test_forwardNoticeMessage_runtimeFlags_oneOnOne_shouldSyncTranscript() {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "target-user"),
            scene: .single,
            sourceAuthorIds: ["alice"],
            messageCount: 1,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        XCTAssertFalse(message.shouldBeSaved())
        XCTAssertTrue(message.shouldSyncTranscript())
        XCTAssertTrue(message.isSilent)
        XCTAssertEqual(message.messageState, .sent)
    }

    func test_forwardNoticeMessage_runtimeFlags_group_shouldNotSyncTranscript() {
        let groupId = Data([0x01, 0x02, 0x03, 0x04])
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "target-user"),
            scene: .combined,
            sourceAuthorIds: ["alice"],
            messageCount: 1,
            sourceConversation: .group(groupId: groupId)
        )

        XCTAssertFalse(message.shouldBeSaved())
        XCTAssertFalse(message.shouldSyncTranscript())
        XCTAssertTrue(message.isSilent)
    }

    func test_forwardNoticeMessage_runtimeFlags_noteToSelf_shouldNotSyncTranscript() {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "self-user"),
            scene: .saveToNotes,
            sourceAuthorIds: ["alice"],
            messageCount: 1,
            sourceConversation: .noteToSelf(localNumber: "self-user")
        )

        XCTAssertFalse(message.shouldBeSaved())
        XCTAssertFalse(message.shouldSyncTranscript())
        XCTAssertTrue(message.isSilent)
    }

    func test_syncForwardNoticeMessage_runtimeFlags_areSilentAndTransient() {
        let thread = makeThread(contactId: "target-user")
        let message = DTOutgoingSyncForwardNoticeMessage(
            thread: thread,
            scene: .oneByOne,
            sourceAuthorIds: ["alice", "bob"],
            messageCount: 2,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        XCTAssertFalse(message.shouldBeSaved())
        XCTAssertFalse(message.shouldSyncTranscript())
        XCTAssertTrue(message.isSilent)
        XCTAssertEqual(message.uniqueThreadId, thread.uniqueId)
    }

    // MARK: - Scene enum coverage

    func test_forwardNoticeMessage_buildPlainTextData_serializesAllScenesCorrectly() throws {
        let cases: [(scene: DTForwardNoticeScene, expectedRawValue: Int)] = [
            (.single, 0),
            (.oneByOne, 1),
            (.combined, 2),
            (.saveToNotes, 3),
        ]

        for item in cases {
            let message = TSOutgoingForwardNoticeMessage(
                thread: makeThread(contactId: "target-user"),
                scene: item.scene,
                sourceAuthorIds: ["alice"],
                messageCount: 1,
                sourceConversation: .oneOnOne(number: "target-user")
            )
            let data = try XCTUnwrap(message.buildPlainTextData(makeRecipient(recipientId: "target-user")))
            let content = try DifftServiceProtos_Content(serializedData: data)

            XCTAssertTrue(content.hasForwardNotice)
            XCTAssertEqual(
                Int(content.forwardNotice.scene.rawValue),
                item.expectedRawValue,
                "scene=\(item.scene) should map to rawValue=\(item.expectedRawValue)"
            )
        }
    }

    // MARK: - Edge cases

    func test_forwardNoticeMessage_buildPlainTextData_supportsEmptySourceAuthorsAndZeroCount() throws {
        let message = TSOutgoingForwardNoticeMessage(
            thread: makeThread(contactId: "target-user"),
            scene: .oneByOne,
            sourceAuthorIds: [],
            messageCount: 0,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        let data = try XCTUnwrap(message.buildPlainTextData(makeRecipient(recipientId: "target-user")))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.hasForwardNotice)
        XCTAssertEqual(content.forwardNotice.sourceAuthorIds.count, 0)
        XCTAssertEqual(content.forwardNotice.messageCount, 0)
    }

    func test_syncForwardNoticeMessage_buildPlainTextData_supportsEmptySourceAuthorsAndZeroCount() throws {
        let thread = makeThread(contactId: "target-user")
        let recipient = makeRecipient(recipientId: "self-user")
        let message = DTOutgoingSyncForwardNoticeMessage(
            thread: thread,
            scene: .single,
            sourceAuthorIds: [],
            messageCount: 0,
            sourceConversation: .oneOnOne(number: "target-user")
        )

        let data = try XCTUnwrap(message.buildPlainTextData(recipient))
        let content = try DifftServiceProtos_Content(serializedData: data)

        XCTAssertTrue(content.hasSyncMessage)
        XCTAssertTrue(content.syncMessage.hasForwardNoticeSync)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.sourceAuthorIds.count, 0)
        XCTAssertEqual(content.syncMessage.forwardNoticeSync.messageCount, 0)
    }

    // MARK: - Helpers

    private func makeThread(contactId: String) -> TSContactThread {
        TSContactThread(contactId: contactId)
    }

    private func makeRecipient(recipientId: String) -> SignalRecipient {
        SignalRecipient(textSecureIdentifier: recipientId, relay: nil)
    }
}
