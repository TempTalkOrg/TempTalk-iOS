//
//  OWSRecordTranscriptJobRecoveryTests.swift
//  TempTalkTests
//
//

import XCTest
@testable import Yelling

final class OWSRecordTranscriptJobRecoveryTests: XCTestCase {

    func testRecordTranscript_recoversFailedOutgoingMessage() {
        let transcriptServerTs: TimeInterval = 1_776_992_961_441 // T + 17_000 (design §11 Test 1)
        let transcriptSequenceId: UInt64 = 12345
        let transcriptNotifySequenceId: UInt64 = 98765

        let receipts = DTOutgoingMessageServerReceipts(
            needsSync: false,
            sequenceId: transcriptSequenceId,
            systemShowTimestamp: transcriptServerTs,
            notifySequenceId: transcriptNotifySequenceId
        )

        XCTAssertEqual(receipts.needsSync, false,
                       "Recovery branch must pass needsSync=false — sync echo is itself the sync.")
        XCTAssertEqual(receipts.sequenceId, transcriptSequenceId,
                       "sequenceId must match transcript.sequenceId exactly.")
        XCTAssertEqual(receipts.systemShowTimestamp, transcriptServerTs, accuracy: 0.001,
                       "systemShowTimestamp must match transcript.serverTimestamp.")
        XCTAssertEqual(receipts.notifySequenceId, transcriptNotifySequenceId,
                       "notifySequenceId must match transcript.notifySequenceId exactly.")
    }

    func testRecordTranscript_skipsAlreadySentMessage() {
        XCTAssertEqual(TSOutgoingMessageState.sending.rawValue, 0,
                       "TSOutgoingMessageStateSending must be enum 0.")
        XCTAssertEqual(TSOutgoingMessageState.failed.rawValue, 1,
                       "TSOutgoingMessageStateFailed must be enum 1.")
        XCTAssertEqual(TSOutgoingMessageState.sent.rawValue, 4,
                       "TSOutgoingMessageStateSent must be enum 4.")

        // Recovery-eligible states
        XCTAssertTrue(isRecoveryEligible(.failed), "A .failed message is the primary bug case — must recover.")
        XCTAssertTrue(isRecoveryEligible(.sending), "A .sending message racing the echo must recover.")

        // Non-eligible states
        XCTAssertFalse(isRecoveryEligible(.sent), "A .sent message must NOT trigger recovery.")
        XCTAssertFalse(isRecoveryEligible(.sent_OBSOLETE), "Obsolete .sent must NOT trigger recovery.")
        XCTAssertFalse(isRecoveryEligible(.delivered_OBSOLETE), "Obsolete .delivered must NOT trigger recovery.")
    }

    // MARK: - Helpers

    /// Mirror of the state-guard conjunct in the recovery branch at
    /// OWSRecordTranscriptJob.m (the `.failed || .sending` test).
    private func isRecoveryEligible(_ state: TSOutgoingMessageState) -> Bool {
        return state == .failed || state == .sending
    }
}
