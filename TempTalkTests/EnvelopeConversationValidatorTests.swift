//
//  Copyright (c) 2026 Difft. All rights reserved.
//

import XCTest
@testable import TTServiceKit

final class EnvelopeConversationValidatorTests: XCTestCase {

    func test_restGroupConversation_roundTripsIntoValidator() throws {
        let serverGroupID = "3ca7163db49f46b29afc083811e8ded4"
        let envelope = try XCTUnwrap(MessageFetcherJob.buildEnvelope(messageDict: restMessage(groupID: serverGroupID)))

        XCTAssertEqual(envelope.msgExtra?.conversationID?.groupID, Data(serverGroupID.utf8))
        XCTAssertEqual(
            DTEnvelopeConversationValidator.validationResult(
                for: envelope,
                consistentWithGroupID: Data(serverGroupID.utf8),
                context: "test"
            ),
            .matched
        )
    }

    func test_restLegacyGroupConversation_roundTripsIntoValidator() throws {
        let localGroupID = Data((0..<16).map(UInt8.init))
        let serverGroupID = try XCTUnwrap(
            TSGroupThread.transformToServerGroupId(withLocalGroupId: localGroupID)
        )
        let envelope = try XCTUnwrap(MessageFetcherJob.buildEnvelope(messageDict: restMessage(groupID: serverGroupID)))

        XCTAssertEqual(envelope.msgExtra?.conversationID?.groupID, localGroupID)
        XCTAssertEqual(
            DTEnvelopeConversationValidator.validationResult(
                for: envelope,
                consistentWithGroupID: localGroupID,
                context: "test"
            ),
            .matched
        )
    }

    func test_groupClassification_requiresNonEmptyID() throws {
        let noGroup = try DSKProtoDataMessage.builder().build()

        let emptyGroupBuilder = DSKProtoDataMessage.builder()
        emptyGroupBuilder.setGroup(try DSKProtoGroupContext.builder().build())
        let emptyGroup = try emptyGroupBuilder.build()

        let emptyIDGroupBuilder = DSKProtoGroupContext.builder()
        emptyIDGroupBuilder.setId(Data())
        let emptyIDDataMessageBuilder = DSKProtoDataMessage.builder()
        emptyIDDataMessageBuilder.setGroup(try emptyIDGroupBuilder.build())
        let emptyIDGroup = try emptyIDDataMessageBuilder.build()

        let validGroupBuilder = DSKProtoGroupContext.builder()
        validGroupBuilder.setId(Data("12345678901234567890123456789012".utf8))
        let validDataMessageBuilder = DSKProtoDataMessage.builder()
        validDataMessageBuilder.setGroup(try validGroupBuilder.build())
        let validGroup = try validDataMessageBuilder.build()

        XCTAssertFalse(DTEnvelopeConversationValidator.isGroupDataMessage(noGroup))
        XCTAssertFalse(DTEnvelopeConversationValidator.isGroupDataMessage(emptyGroup))
        XCTAssertFalse(DTEnvelopeConversationValidator.isGroupDataMessage(emptyIDGroup))
        XCTAssertTrue(DTEnvelopeConversationValidator.isGroupDataMessage(validGroup))
    }

    func test_explicitConversationMismatch_isRejected() throws {
        let envelope = try XCTUnwrap(
            MessageFetcherJob.buildEnvelope(messageDict: restMessage(groupID: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        )

        XCTAssertEqual(
            DTEnvelopeConversationValidator.validationResult(
                for: envelope,
                consistentWithGroupID: Data("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb".utf8),
                context: "test"
            ),
            .mismatched
        )
    }

    private func restMessage(groupID: String) -> [String: Any] {
        [
            "type": DSKProtoEnvelopeType.ciphertext.rawValue,
            "timestamp": UInt64(1_700_000_000_000),
            "source": "+15551234",
            "sourceDevice": UInt32(1),
            "msgType": DSKProtoEnvelopeMsgType.msgNormal.rawValue,
            "msgExtra": [
                "conversationId": [
                    "groupId": groupID,
                ],
            ],
        ]
    }
}
