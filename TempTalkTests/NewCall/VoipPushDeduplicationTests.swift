import XCTest
@testable import Yelling

final class VoipPushDeduplicationTests: XCTestCase {
    func testDuplicateReportReusesCallKitUUID() {
        let sut = DTVoipEnvelopeDeduplicator()

        let first = sut.claimReport(for: "same-envelope")
        let duplicate = sut.claimReport(for: "same-envelope")

        XCTAssertTrue(first.isFirstDelivery)
        XCTAssertFalse(duplicate.isFirstDelivery)
        XCTAssertEqual(first.callKitUUID, duplicate.callKitUUID)
    }

    func testConcurrentReportsHaveOneOwnerAndOneCallKitUUID() {
        let sut = DTVoipEnvelopeDeduplicator()
        let resultLock = NSLock()
        var results = [DTVoipReportClaim]()

        DispatchQueue.concurrentPerform(iterations: 50) { _ in
            let result = sut.claimReport(for: "concurrent-envelope")
            resultLock.lock()
            results.append(result)
            resultLock.unlock()
        }

        XCTAssertEqual(results.filter(\.isFirstDelivery).count, 1)
        XCTAssertEqual(Set(results.map(\.callKitUUID)).count, 1)
    }

    func testAcceptedDuplicateStaysAliveWhileOwnerExists() {
        let sut = DTVoipEnvelopeDeduplicator()
        let owner = sut.claimReport(for: "active-envelope")
        let duplicate = sut.claimReport(for: "active-envelope")

        XCTAssertFalse(
            sut.shouldEndAcceptedDuplicate(
                for: "active-envelope",
                callKitUUID: duplicate.callKitUUID
            )
        )
        XCTAssertEqual(owner.callKitUUID, duplicate.callKitUUID)
    }

    func testAcceptedDuplicateEndsAfterOwnerTerminates() {
        let sut = DTVoipEnvelopeDeduplicator()
        let owner = sut.claimReport(for: "ended-envelope")
        let duplicate = sut.claimReport(for: "ended-envelope")

        sut.markTerminal(callKitUUID: owner.callKitUUID)
        XCTAssertTrue(
            sut.shouldEndAcceptedDuplicate(
                for: "ended-envelope",
                callKitUUID: duplicate.callKitUUID
            )
        )
    }

    func testOwnerTeardownMarksPreviouslyAcceptedDuplicateTerminal() {
        let sut = DTVoipEnvelopeDeduplicator()
        let owner = sut.claimReport(for: "racing-envelope")
        let duplicate = sut.claimReport(for: "racing-envelope")

        XCTAssertFalse(
            sut.shouldEndAcceptedDuplicate(
                for: "racing-envelope",
                callKitUUID: duplicate.callKitUUID
            )
        )
        sut.markTerminal(callKitUUID: owner.callKitUUID)
        XCTAssertTrue(
            sut.shouldEndAcceptedDuplicate(
                for: "racing-envelope",
                callKitUUID: duplicate.callKitUUID
            )
        )
    }

    func testAcceptedOldDuplicateEndsAfterClaimIsForgotten() {
        let sut = DTVoipEnvelopeDeduplicator()
        let duplicate = sut.claimReport(for: "forgotten-envelope")
        sut.forget("forgotten-envelope")

        XCTAssertTrue(
            sut.shouldEndAcceptedDuplicate(
                for: "forgotten-envelope",
                callKitUUID: duplicate.callKitUUID
            )
        )
    }

    func testProviderResetMakesEveryClaimTerminal() {
        let sut = DTVoipEnvelopeDeduplicator()
        let first = sut.claimReport(for: "first-envelope")
        let second = sut.claimReport(for: "second-envelope")

        sut.markAllTerminal()

        XCTAssertTrue(
            sut.shouldEndAcceptedDuplicate(
                for: "first-envelope",
                callKitUUID: first.callKitUUID
            )
        )
        XCTAssertTrue(
            sut.shouldEndAcceptedDuplicate(
                for: "second-envelope",
                callKitUUID: second.callKitUUID
            )
        )
    }

    func testForgottenIdentityCanBeClaimedAgain() {
        let sut = DTVoipEnvelopeDeduplicator()
        _ = sut.claimReport(for: "retryable-envelope")

        sut.forget("retryable-envelope")
        let retried = sut.claimReport(for: "retryable-envelope")

        XCTAssertTrue(retried.isFirstDelivery)
    }

    func testLegacyDuplicateHasStableIdentity() throws {
        let callInfo: NSDictionary = [
            "caller": "alice",
            "meetingId": "room-1",
            "startAt": 1_725_000_000,
            "channelName": "channel-1",
            "eid": "event-1",
        ]

        let firstIdentity = try XCTUnwrap(
            DTVoipIdentityBuilder.identity(forLegacyCallInfo: callInfo)
        )
        let duplicateIdentity = try XCTUnwrap(
            DTVoipIdentityBuilder.identity(forLegacyCallInfo: callInfo)
        )

        XCTAssertEqual(firstIdentity, duplicateIdentity)
    }

    func testLegacyReinviteUsesDifferentIdentity() {
        let first: NSDictionary = [
            "caller": "alice",
            "meetingId": "room-1",
            "startAt": 1_725_000_000,
            "channelName": "channel-1",
        ]
        let reinvite: NSDictionary = [
            "caller": "alice",
            "meetingId": "room-1",
            "startAt": 1_725_000_001,
            "channelName": "channel-1",
        ]

        XCTAssertNotEqual(
            DTVoipIdentityBuilder.identity(forLegacyCallInfo: first),
            DTVoipIdentityBuilder.identity(forLegacyCallInfo: reinvite)
        )
    }

    func testLegacyPushWithoutStartAtSkipsDeduplication() {
        let callInfo: NSDictionary = [
            "caller": "alice",
            "meetingId": "room-1",
            "channelName": "channel-1",
        ]

        XCTAssertNil(DTVoipIdentityBuilder.identity(forLegacyCallInfo: callInfo))
    }
}
