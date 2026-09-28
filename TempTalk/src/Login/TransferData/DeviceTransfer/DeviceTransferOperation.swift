//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import MultipeerConnectivity

/// One-shot guard for a `CheckedContinuation` that can be reached from both the caller and
/// an MCSession completion handler. Apple does not document whether `sendResource` may both
/// return nil *and* invoke its completion handler, and resuming a checked continuation twice
/// is a fatal error, so every resume path claims this first.
final class DeviceTransferResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if hasResumed { return false }
        hasResumed = true
        return true
    }
}

// MCSession bookkeeping stays on the main actor so transfer state has a single
// isolation domain; file hashing is explicitly offloaded. Each instance belongs to
// one transfer task and one concrete session; no work is retained in a
// process-wide OperationQueue after a failed transfer.
@MainActor
final class DeviceTransferOperation {

    private enum SendPreparation {
        case invalidState
        case skip
        case send(peerId: MCPeerID, progress: Progress)
    }

    private let file: DeviceTransferProtoFile
    private let session: MCSession
    private let sourceURL: URL?

    init(session: MCSession, file: DeviceTransferProtoFile, sourceURL: URL? = nil) {
        self.session = session
        self.file = file
        self.sourceURL = sourceURL
    }

    func run() async throws {
        try Task.checkCancellation()
        try await prepareForSending()
    }

    private func prepareForSending() async throws {
        let deviceTransferService = DeviceTransferService.shared

        guard let preparation = deviceTransferService.updateCurrentAttempt(
            expectedSession: session,
            { state, _ -> SendPreparation in
                guard case .outgoing(let peerId, _, _, let transferredFiles, let progress) = state else {
                    return .invalidState
                }
                if transferredFiles.contains(file.identifier) { return .skip }
                return .send(peerId: peerId, progress: progress)
            }
        ) else {
            throw CancellationError()
        }
        switch preparation {
        case .invalidState:
            throw OWSAssertionError("Tried to transfer file while the attempt was not outgoing")
        case .skip:
            return
        case .send:
            break
        }
        guard case .send(let newDevicePeerId, let transferProgress) = preparation else {
            throw OWSAssertionError("Missing outgoing send preparation")
        }

        var temporaryPlaceholderURL: URL?
        var url = sourceURL ?? URL(
            fileURLWithPath: file.relativePath,
            relativeTo: DeviceTransferService.appSharedDataDirectory
        )

        if !OWSFileSystem.fileOrFolderExists(url: url) {
            guard ![
                DeviceTransferService.databaseWALIdentifier,
                DeviceTransferService.databaseIdentifier
            ].contains(file.identifier) else {
                throw OWSAssertionError("Mandatory database file is missing for transfer")
            }

            Logger.warn("Missing file for transfer; sending missing file placeholder")
            url = OWSFileSystem.temporaryFileUrl()
            guard FileManager.default.createFile(
                atPath: url.path,
                contents: DeviceTransferService.missingFileData,
                attributes: nil
            ) else {
                throw OWSAssertionError("Failed to create temp file for missing file \(url)")
            }
            temporaryPlaceholderURL = url
        }
        defer {
            if let temporaryPlaceholderURL {
                try? OWSFileSystem.deleteFile(url: temporaryPlaceholderURL)
            }
        }

        // Hashing runs over the whole file, including the multi-gigabyte database copy.
        // It must never run on the main actor.
        let fileURL = url
        guard let sha256Digest = try? await Task.detached(priority: .userInitiated, operation: {
            try Cryptography.computeSHA256DigestOfFile(at: fileURL)
        }).value else {
            throw OWSAssertionError("Failed to calculate sha256 for file")
        }

        try Task.checkCancellation()
        let resumeGuard = DeviceTransferResumeGuard()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let fileProgress = session.sendResource(
                at: url,
                withName: file.identifier + " " + sha256Digest.hexadecimalString,
                toPeer: newDevicePeerId,
                withCompletionHandler: { error in
                    guard resumeGuard.claim() else { return }
                    if let error {
                        Logger.error("[DeviceTransfer][OldDevice] Resource send failed: \(error)")
                        continuation.resume(throwing: DeviceTransferService.Error.connectionLost)
                    } else {
                        continuation.resume()
                    }
                }
            )

            // `sendResource` returns nil when the resource cannot be sent at all, e.g. the
            // peer already disconnected, and its completion handler is then never invoked —
            // so this continuation must be resumed here or the send suspends forever. The
            // guard covers the undocumented case where MC does both.
            guard let fileProgress else {
                Logger.error("[DeviceTransfer][OldDevice] sendResource refused file \(file.identifier)")
                guard resumeGuard.claim() else { return }
                continuation.resume(throwing: DeviceTransferService.Error.connectionLost)
                return
            }

            transferProgress.addChild(fileProgress, withPendingUnitCount: Int64(file.estimatedSize))
        }

        try Task.checkCancellation()
        let committed = deviceTransferService.updateCurrentAttempt(expectedSession: session) { state, _ -> Bool in
            guard case .outgoing = state else { return false }
            state = state.appendingFileId(file.identifier)
            return true
        } ?? false
        guard committed else { throw CancellationError() }
    }
}
