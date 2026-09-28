//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import MultipeerConnectivity

extension DeviceTransferService {
    func buildManifest() throws -> DeviceTransferProtoManifest {
        var manifestBuilder = DeviceTransferProtoManifest.builder(grdbSchemaVersion: UInt64(GRDBSchemaMigrator.grdbSchemaVersionLatest))
        var estimatedTotalSize: UInt64 = 0

        // Database

        do {
            assert(StorageCoordinator.hasGrdbFile)

            let database: DeviceTransferProtoFile = try {
                let file = databaseStorage.grdbStorage.databaseFilePath
                guard let size = OWSFileSystem.fileSize(ofPath: file), size.uint64Value > 0 else {
                    throw OWSAssertionError("Failed to calculate size of database \(file)")
                }
                estimatedTotalSize += size.uint64Value
                let fileBuilder = DeviceTransferProtoFile.builder(
                    identifier: DeviceTransferService.databaseIdentifier,
                    relativePath: try pathRelativeToAppSharedDirectory(file),
                    estimatedSize: size.uint64Value
                )
                return try fileBuilder.build()
            }()

            let wal: DeviceTransferProtoFile = try {
                let file = databaseStorage.grdbStorage.databaseWALFilePath
                guard let size = OWSFileSystem.fileSize(ofPath: file), size.uint64Value > 0 else {
                    throw OWSAssertionError("Failed to calculate size of database wal \(file)")
                }
                estimatedTotalSize += size.uint64Value
                let fileBuilder = DeviceTransferProtoFile.builder(
                    identifier: DeviceTransferService.databaseWALIdentifier,
                    relativePath: try pathRelativeToAppSharedDirectory(file),
                    estimatedSize: size.uint64Value
                )
                return try fileBuilder.build()
            }()

            let databaseBuilder = DeviceTransferProtoDatabase.builder(
                key: try GRDBDatabaseStorageAdapter.keyspec.fetchData(),
                database: database,
                wal: wal
            )
            manifestBuilder.setDatabase(try databaseBuilder.build())
        }

        // Attachments, Avatars, and Stickers

        // TODO: Ideally, these paths would reference constants...
        let foldersToTransfer = ["Attachments/", "ProfileAvatars/", "GroupAvatars/", "StickerManager/", "Wallpapers/", "Library/Sounds/", "AvatarHistory/"]
        let filesToTransfer = try foldersToTransfer.flatMap { folder -> [String] in
            let url = URL(fileURLWithPath: folder, relativeTo: DeviceTransferService.appSharedDataDirectory)
            return try OWSFileSystem.recursiveFilesInDirectory(url.path)
        }

        for file in filesToTransfer {
            guard let size = OWSFileSystem.fileSize(ofPath: file) else {
                throw OWSAssertionError("Failed to calculate size of file \(file)")
            }

            guard size.uint64Value > 0 else {
                owsFailDebug("skipping empty file \(file)")
                continue
            }

            estimatedTotalSize += size.uint64Value
            let fileBuilder = DeviceTransferProtoFile.builder(
                identifier: UUID().uuidString,
                relativePath: try pathRelativeToAppSharedDirectory(file),
                estimatedSize: size.uint64Value
            )
            manifestBuilder.addFiles(try fileBuilder.build())
        }

        // Standard Defaults
        func isAppleKey(_ key: String) -> Bool {
            return key.starts(with: "NS") || key.starts(with: "Apple")
        }

        do {
            for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
                // Filter out any keys we think are managed by Apple, we don't need to transfer them.
                guard !isAppleKey(key) else { continue }

                guard let encodedValue = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) else { continue }

                let defaultBuilder = DeviceTransferProtoDefault.builder(
                    key: key,
                    encodedValue: encodedValue
                )
                manifestBuilder.addStandardDefaults(try defaultBuilder.build())
            }
        }

        // App Defaults

        do {
            for (key, value) in CurrentAppContext().appUserDefaults().dictionaryRepresentation() {
                // Filter out any keys we think are managed by Apple, we don't need to transfer them.
                guard !isAppleKey(key) else { continue }

                guard let encodedValue = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true) else { continue }

                let defaultBuilder = DeviceTransferProtoDefault.builder(
                    key: key,
                    encodedValue: encodedValue
                )
                manifestBuilder.addAppDefaults(try defaultBuilder.build())
            }
        }

        manifestBuilder.setEstimatedTotalSize(estimatedTotalSize)

        return try manifestBuilder.build()
    }

    func pathRelativeToAppSharedDirectory(_ path: String) throws -> String {
        guard !path.contains("*") else {
            throw OWSAssertionError("path contains invalid character: *")
        }

        let components = path.components(separatedBy: "/")

        guard components.first != "~" else {
            throw OWSAssertionError("path starts with invalid component: ~")
        }

        for component in components {
            guard component != "." else {
                throw OWSAssertionError("path contains invalid component: .")
            }

            guard component != ".." else {
                throw OWSAssertionError("path contains invalid component: ..")
            }
        }

        var path = path.replacingOccurrences(of: DeviceTransferService.appSharedDataDirectory.path, with: "")
        if path.starts(with: "/") { path.removeFirst() }
        return path
    }

    func handleReceivedManifest(at localURL: URL, fromPeer peerId: MCPeerID, session expectedSession: MCSession) {
        guard let snapshot = attemptSnapshot(expectedSession: expectedSession) else { return }
        guard case .idle = snapshot.state else {
            return failTransfer(.assertion, "Received manifest in unexpected state", expectedSession: expectedSession)
        }
        guard let fileSize = OWSFileSystem.fileSize(of: localURL) else {
            return failTransfer(.assertion, "Missing manifest file", expectedSession: expectedSession)
        }
        guard fileSize.uint64Value < 1024 * 1024 * 10 else {
            return failTransfer(.assertion, "Unexpectedly received a very large manifest \(fileSize)", expectedSession: expectedSession)
        }
        guard let data = try? Data(contentsOf: localURL) else {
            return failTransfer(.assertion, "Failed to read manifest data", expectedSession: expectedSession)
        }
        guard let manifest = try? DeviceTransferProtoManifest(serializedData: data) else {
            return failTransfer(.assertion, "Failed to parse manifest proto", expectedSession: expectedSession)
        }
        guard !tsAccountManager.isRegistered() else {
            return failTransfer(.assertion, "Ignoring incoming transfer to a registered device", expectedSession: expectedSession)
        }

        let progress = Progress(totalUnitCount: Int64(manifest.estimatedTotalSize))

        Logger.info(
            "[DeviceTransfer][NewDevice] Manifest parsed; " +
            "manifestBytes=\(fileSize.uint64Value), estimatedBytes=\(manifest.estimatedTotalSize), " +
            "dataFiles=\(manifest.files.count), hasDatabase=\(manifest.database != nil), " +
            "schemaVersion=\(manifest.grdbSchemaVersion)"
        )

        // Check if the device has a newer version of the database than we understand

        guard manifest.grdbSchemaVersion <= GRDBSchemaMigrator.grdbSchemaVersionLatest else {
            return failTransfer(.unsupportedVersion, "Ignoring manifest with unsupported schema version", expectedSession: expectedSession)
        }

        // Check if there is enough space on disk to receive the transfer

        guard let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(
            forPath: DeviceTransferService.appSharedDataDirectory.path
        ) else {
            return failTransfer(.assertion, "failed to calculate available disk space", expectedSession: expectedSession)
        }

        guard let freeSpaceInBytes = fileSystemAttributes[.systemFreeSize] as? UInt64, freeSpaceInBytes > manifest.estimatedTotalSize else {
            return failTransfer(.notEnoughSpace, "not enough free space to receive transfer", expectedSession: expectedSession)
        }

        // `resetTransferDirectory()` recursively deletes the pending transfer tree and rewrites
        // restoration state, and `isTransferInProgress` performs a synchronous database read
        // behind `@synchronized`. Neither may run inside the attempt lock: this method runs on
        // MCSession's delegate thread, so holding the lock across them stalls every reader of
        // `transferState`, including the main thread. Only the rename and the state commit —
        // both constant time — stay inside. A stale manifest is rejected at the commit below;
        // it can only reach the reset while the attempt is still current, and at manifest time
        // no received files exist yet, so the reset has nothing of a live attempt to destroy.
        guard isCurrentAttempt(session: expectedSession) else { return }
        resetTransferDirectory()

        do {
            let committed = try updateCurrentAttempt(expectedSession: expectedSession) { state, _ -> Bool in
                guard case .idle = state else { return false }
                guard OWSFileSystem.moveFilePath(
                    localURL.path,
                    toFilePath: URL(
                        fileURLWithPath: DeviceTransferService.manifestIdentifier,
                        relativeTo: DeviceTransferService.pendingTransferDirectory
                    ).path
                ) else {
                    throw OWSAssertionError("Failed to move manifest into place")
                }
                state = .incoming(
                    oldDevicePeerId: peerId,
                    manifest: manifest,
                    receivedFileIds: [DeviceTransferService.manifestIdentifier],
                    skippedFileIds: [],
                    progress: progress
                )
                return true
            } ?? false
            guard committed else { return }
        } catch {
            return failTransfer(.assertion, "Failed to commit manifest: \(error)", expectedSession: expectedSession)
        }

        // Account-transfer flags and UI callbacks are main-confined alongside teardown. If a
        // failure detached this attempt after the manifest commit, the first check prevents a
        // stale `true` write. If it detaches between the check and the synchronous write, its
        // already-enqueued main teardown runs after this block and clears the flag again.
        DispatchQueue.main.async {
            guard self.isCurrentAttempt(session: expectedSession) else { return }

            self.tsAccountManager.isTransferInProgress = true
            guard self.isCurrentAttempt(session: expectedSession) else { return }

            self.notifyObservers { observer in
                guard self.isCurrentAttempt(session: expectedSession) else { return }
                observer.deviceTransferServiceDidStartTransfer(progress: progress)
            }
            self.startThroughputCalculation(expectedSession: expectedSession)
        }
    }

    @MainActor
    func sendManifest(session expectedSession: MCSession) async throws {
        guard let snapshot = attemptSnapshot(expectedSession: expectedSession) else {
            throw CancellationError()
        }
        guard case .outgoing(let newDevicePeerId, _, let manifest, _, _) = snapshot.state else {
            throw OWSAssertionError("attempted to send manifest while no active outgoing transfer")
        }

        // We write the manifest to a temp file, since MCSession only allows sending "typed"
        // data when sending files, unless you do your own stream management.
        let manifestData = try manifest.serializedData()
        // Use a unique URL per attempt. A delayed completion from an earlier session must
        // never delete or overwrite the manifest that belongs to the current retry.
        let manifestFileURL = OWSFileSystem.temporaryFileUrl(fileExtension: "manifest")
        try manifestData.write(to: manifestFileURL, options: .atomic)
        defer { OWSFileSystem.deleteFileIfExists(manifestFileURL.path) }

        let resumeGuard = DeviceTransferResumeGuard()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Swift.Error>) in
            let manifestProgress = expectedSession.sendResource(
                at: manifestFileURL,
                withName: DeviceTransferService.manifestIdentifier,
                toPeer: newDevicePeerId
            ) { error in
                guard resumeGuard.claim() else { return }
                if let error = error {
                    let nsError = error as NSError
                    Logger.error(
                        "[DeviceTransfer][OldDevice] Manifest send failed; " +
                        "domain=\(nsError.domain), code=\(nsError.code), " +
                        "description=\(nsError.localizedDescription)"
                    )
                    continuation.resume(throwing: DeviceTransferService.Error.connectionLost)
                } else {
                    continuation.resume()
                }
            }

            // `sendResource` returns nil when the resource cannot be sent at all, e.g. the
            // peer already disconnected, and its completion handler is then never invoked —
            // so this continuation must be resumed here or both devices hang. The guard
            // covers the undocumented case where MC does both.
            if manifestProgress == nil, resumeGuard.claim() {
                Logger.error("[DeviceTransfer][OldDevice] sendResource refused the manifest")
                continuation.resume(throwing: DeviceTransferService.Error.connectionLost)
            }
        }

        Logger.info(
            "[DeviceTransfer][OldDevice] Manifest resource completed; " +
            "manifestBytes=\(manifestData.count), " +
            "connectedPeers=\(expectedSession.connectedPeers.count)"
        )

        try Task.checkCancellation()
        let committed = updateCurrentAttempt(expectedSession: expectedSession) { state, _ -> Bool in
            guard case .outgoing(let currentPeerId, _, _, _, _) = state,
                  currentPeerId == newDevicePeerId else { return false }
            state = state.appendingFileId(DeviceTransferService.manifestIdentifier)
            return true
        } ?? false
        guard committed else { throw CancellationError() }
        startThroughputCalculation(expectedSession: expectedSession)
    }

    func readManifestFromTransferDirectory() -> DeviceTransferProtoManifest? {
        let manifestPath = URL(
            fileURLWithPath: DeviceTransferService.manifestIdentifier,
            relativeTo: DeviceTransferService.pendingTransferDirectory
        ).path
        guard OWSFileSystem.fileOrFolderExists(atPath: manifestPath) else { return nil }
        guard let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)) else { return nil }
        return try? DeviceTransferProtoManifest(serializedData: manifestData)
    }
}
