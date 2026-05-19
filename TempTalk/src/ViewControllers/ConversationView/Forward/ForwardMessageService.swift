//
//  ForwardMessageService.swift
//  Difft
//

import Foundation
import TTServiceKit

public actor ForwardMessageService {

    public static let shared = ForwardMessageService()

    private init() {}

    // MARK: - Public types

    public struct Request {
        public let messages: [TSMessage]
        public let targets: [TSThread]
        public let type: DTForwardMessageType
        public let sourceConversation: TSThread
        public let leaveMessage: String?

        public init(
            messages: [TSMessage],
            targets: [TSThread],
            type: DTForwardMessageType,
            sourceConversation: TSThread,
            leaveMessage: String?
        ) {
            self.messages = messages
            self.targets = targets
            self.type = type
            self.sourceConversation = sourceConversation
            self.leaveMessage = leaveMessage
        }
    }

    public struct Outcome {
        public let thread: TSThread
        public let error: Error?
        public var succeeded: Bool { error == nil }
    }

    public struct Result {
        public let outcomes: [Outcome]
        public var allSucceeded: Bool { outcomes.allSatisfy { $0.succeeded } }
        public var anySucceeded: Bool { outcomes.contains(where: { $0.succeeded }) }
    }

    // MARK: - Entry point

    public func forward(_ request: Request) async -> Result {
        guard !request.messages.isEmpty, !request.targets.isEmpty else {
            return Result(outcomes: [])
        }

        var outcomes: [Outcome] = []
        outcomes.reserveCapacity(request.targets.count)

        for target in request.targets {
            do {
                try await forwardToSingleTarget(target, request: request)
                outcomes.append(Outcome(thread: target, error: nil))
            } catch {
                Logger.error("[Forward] pipeline failed for thread=\(target.uniqueId): \(error)")
                outcomes.append(Outcome(thread: target, error: error))
            }
        }

        let result = Result(outcomes: outcomes)
        if result.anySucceeded {
            await sendAggregateNotice(request: request)
        }
        return result
    }

    // MARK: - Per-target pipeline

    private func forwardToSingleTarget(_ target: TSThread, request: Request) async throws {
        try await sendOriginalMessages(
            messages: request.messages,
            to: target,
            isFromGroup: request.sourceConversation.isGroupThread(),
            type: request.type
        )

        if let leaveMessage = request.leaveMessage, !leaveMessage.isEmpty {
            try await sendText(leaveMessage, to: target)
        }
    }

    private func sendAggregateNotice(request: Request) async {
        let sourceAuthorIds = ForwardNoticeBuilder.sourceAuthorIds(for: request.messages)
        let scene = ForwardNoticeBuilder.scene(for: request.type, messageCount: request.messages.count)
        do {
            try await ForwardNoticeDispatcher.sendNotice(
                sourceConversation: request.sourceConversation,
                scene: scene,
                sourceAuthorIds: sourceAuthorIds,
                messageCount: UInt32(request.messages.count),
                messageSender: Self.messageSender
            )
        } catch {
            Logger.error("[Forward] notice failed (best-effort) source=\(request.sourceConversation.uniqueId): \(error)")
        }
    }

    private func sendOriginalMessages(
        messages: [TSMessage],
        to target: TSThread,
        isFromGroup: Bool,
        type: DTForwardMessageType
    ) async throws {
        if type == .oneByOne {
            for message in messages {
                try await forwardBatch(isFromGroup: isFromGroup, to: target, messages: [message])
            }
        } else {
            try await forwardBatch(isFromGroup: isFromGroup, to: target, messages: messages)
        }
    }

    // MARK: - Continuation wrappers (hop to main queue — the OC helpers assert on main)

    private func forwardBatch(isFromGroup: Bool, to target: TSThread, messages: [TSMessage]) async throws {
        try await withCheckedThrowingContinuation { (raw: CheckedContinuation<Void, Error>) in
            let gate = SingleShotContinuation(raw)
            DispatchQueue.main.async {
                DTForwardMessageHelper.forwardMessageIs(
                    fromGroup: isFromGroup,
                    targetThread: target,
                    messages: messages,
                    success: { gate.resume() },
                    failure: { error in gate.resume(throwing: error) }
                )
            }
        }
    }

    private func sendText(_ text: String, to target: TSThread) async throws {
        try await withCheckedThrowingContinuation { (raw: CheckedContinuation<Void, Error>) in
            let gate = SingleShotContinuation(raw)
            DispatchQueue.main.async {
                _ = ThreadUtil.sendMessage(
                    withText: text,
                    atPersons: nil,
                    mentions: nil,
                    in: target,
                    quotedReplyModel: nil,
                    messageSender: Self.messageSender,
                    success: { gate.resume() },
                    failure: { error in gate.resume(throwing: error) }
                )
            }
        }
    }

    // MARK: - Dependencies

    private static var messageSender: MessageSender {
        SSKEnvironment.shared.messageSenderRef
    }
}
