//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import SignalCoreKit
import TTServiceKit

extension DeviceTransferService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer newDevicePeerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard isCurrentBrowser(browser) else { return }
        notifyObservers { $0.deviceTransferServiceDiscoveredNewDevice(peerId: newDevicePeerID, discoveryInfo: info) }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Swift.Error) {
        if error.isLocalNetworkPermissionDenied {
            localNetworkOperationDidReportPermissionDenied(expectedBrowser: browser)
            return
        }
        browserDidFailToStart(
            browser,
            transferError: .connectionLost,
            reason: "Browser failed to start: \(error.deviceTransferDiagnosticSummary)"
        )
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerId: MCPeerID) {}
}

extension DeviceTransferService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerId: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let activeSession = invitationSnapshot(for: advertiser)?.session
        invitationHandler(activeSession != nil, activeSession)
        if let activeSession {
            deviceSleepManager.addBlock(blockObject: activeSession)
            advertiser.stopAdvertisingPeer()
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Swift.Error) {
        if error.isLocalNetworkPermissionDenied {
            localNetworkOperationDidReportPermissionDenied(expectedAdvertiser: advertiser)
            return
        }
        failTransfer(
            .advertisingFailed,
            "Advertiser failed to start: \(error.deviceTransferDiagnosticSummary)",
            expectedAdvertiser: advertiser
        )
    }
}

private extension Swift.Error {
    /// Apple does not expose a general local-network authorization status API. Bonjour reports
    /// a denied request as PolicyDenied (-65570); MultipeerConnectivity commonly wraps that as
    /// NSNetServices error -72008. Only classify these known policy errors as permission denial.
    /// TODO: Record the complete NSError chain on physical devices before narrowing the domain
    /// checks. Simulator does not reproduce Local Network privacy authorization failures.
    var isLocalNetworkPermissionDenied: Bool {
        let error = self as NSError
        if error.code == -65_570 || (error.domain == "NSNetServicesErrorDomain" && error.code == -72_008) {
            return true
        }
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Swift.Error {
            return underlyingError.isLocalNetworkPermissionDenied
        }
        return false
    }

    var deviceTransferDiagnosticSummary: String {
        var errors = [String]()
        var currentError = self as NSError
        for _ in 0..<4 {
            errors.append("\(currentError.domain)(\(currentError.code))")
            guard let underlyingError = currentError.userInfo[NSUnderlyingErrorKey] as? NSError,
                  underlyingError !== currentError else { break }
            currentError = underlyingError
        }
        return "errorChain=\(errors.joined(separator: " -> ")), os=\(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}

extension DeviceTransferService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerId: MCPeerID, didChange state: MCSessionState) {
        // Match Signal's device-transfer threading model: release MultipeerConnectivity's
        // private delegate thread immediately and perform MCSession state handling on main.
        DispatchQueue.main.async {
            guard let snapshot = self.attemptSnapshot(expectedSession: session) else { return }
            if state == .connected {
                Logger.info(
                    "[DeviceTransfer] Peer connected; " +
                    "attemptId=\(snapshot.id), peer=\(peerId.displayName)"
                )
            }

            switch snapshot.state {
            case .outgoing(let newDevicePeerId, _, _, let transferredFiles, let progress):
                // We only care about state changes for the device we're sending to.
                guard peerId == newDevicePeerId else { return }

                switch state {
                case .connected:
                    self.notifyObservers { $0.deviceTransferServiceDidStartTransfer(progress: progress) }

                    // Only send the files if we haven't yet sent the manifest.
                    guard !transferredFiles.contains(DeviceTransferService.manifestIdentifier) else { return }

                    self.sendTransferPayload(session: session)
                case .connecting:
                    break
                case .notConnected:
                    self.failTransfer(.connectionLost, "Lost connection to new device", expectedSession: session)
                @unknown default:
                    self.failTransfer(.assertion, "Unexpected connection state: \(state.rawValue)", expectedSession: session)
                }
            case .incoming(let oldDevicePeerId, _, _, _, _):
                // We only care about state changes for the device we're receiving from.
                guard peerId == oldDevicePeerId else { return }

                if state == .notConnected {
                    self.failTransfer(.connectionLost, "Lost connection to old device", expectedSession: session)
                }
            case .idle:
                if state == .notConnected {
                    // End the whole attempt. Signal's advertiser lifecycle creates
                    // a new session when the user retries; a disconnected session
                    // must never be reused for another invitation.
                    self.failTransfer(.connectionLost, "Lost connection before receiving manifest", expectedSession: session)
                }
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerId: MCPeerID) {
        // Match `didChange`: release MultipeerConnectivity's private delegate thread. The
        // handler restores the database, resets app data and notifies the UI, none of which
        // belongs on MCSession's thread. `data` is a value, so nothing expires on return.
        DispatchQueue.main.async {
            self.handleReceivedData(data, fromPeer: peerId, session: session)
        }
    }

    private func handleReceivedData(_ data: Data, fromPeer peerId: MCPeerID, session: MCSession) {
        AssertIsOnMainThread()

        guard let snapshot = attemptSnapshot(expectedSession: session) else { return }

        switch snapshot.state {
        case .idle:
            if data == DeviceTransferService.backgroundAppMessage {
                failTransfer(.backgroundedDevice, "Peer backgrounded before sending manifest", expectedSession: session)
            }
            break
        case .outgoing(let newDevicePeerId, _, _, _, _):
            guard peerId == newDevicePeerId else {
                return owsFailDebug("Ignoring data from unexpected peer \(peerId)")
            }

            switch data {
            case DeviceTransferService.backgroundAppMessage:
                return failTransfer(.backgroundedDevice, "New device entered background", expectedSession: session)
            case DeviceTransferService.doneMessage:
                break
            default:
                return failTransfer(.assertion, "Received unexpected data", expectedSession: session)
            }

            // Notify the UI that the transfer completed successfully.
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: nil) }

            stopTransfer(expectedSession: session)

            // When the old device receives the done message from the new device,
            // it can be confident that the transfer has completed successfully and
            // clear out all data from this device. This will crash the app.
            if !DebugFlags.deviceTransferPreserveOldDevice {
                SignalApp.resetAppData()
            }

        case .incoming(let oldDevicePeerId, _, let receivedFileIds, let skippedFileIds, _):
            guard peerId == oldDevicePeerId else {
                return owsFailDebug("Ignoring data from unexpected peer \(peerId)")
            }

            switch data {
            case DeviceTransferService.backgroundAppMessage:
                return failTransfer(.backgroundedDevice, "Old device entered background", expectedSession: session)
            case DeviceTransferService.doneMessage:
                break
            default:
                return failTransfer(.assertion, "Received unexpected data", expectedSession: session)
            }

            stopThroughputCalculation(expectedAttemptId: snapshot.id)

            // When the new device receives the done message from the old device,
            // it indicates that the old device thinks we should have received
            // everything at this point.

            guard verifyTransferCompletedSuccessfully(
                receivedFileIds: receivedFileIds,
                skippedFileIds: skippedFileIds
            ) else {
                return failTransfer(.assertion, "transfer is missing data", expectedSession: session)
            }

            // Record that we have a pending restore, so even if the app exits
            // we can still know to restore the data that was transferred.
            let startPhase = RestorationPhase.start
            Logger.info("Setting restoration phase to: \(startPhase)")
            rawRestorationPhase = startPhase.rawValue

            // Try and notify the old device that we agree, everything is done.
            // At this point, we consider the transfer complete regardless of
            // whether or not this message is received by the old device. If the
            // old device misses this message (because the app crashes, etc.) it
            // will continue acting as if it is "unregistered", but it won't delete
            // all data because it doesn't know for sure if the data was safely
            // received by the new device.
            do {
                try sendDoneMessage(to: oldDevicePeerId, session: session)
            } catch {
                owsFailDebug("Failed to send done message to old device \(error)")
            }

            // Notify the UI that the transfer completed successfully.
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: nil) }

            // Try and restore the received data. If for some reason the app exits
            // or crashes at this point, we will retry the restore when the app next
            // launches.
            do {
                try restoreTransferredData()
            } catch {
                owsFail("Restore failed. Will try again on next launch. Error: \(error)")
            }

            firstly(on: DispatchQueue.main) { () -> Guarantee<Void> in
                // A successful restoration means we've updated our database path.
                // Extensions will learn of this through NSUserDefaults KVO and exit ASAP
                self.databaseStorage.reloadDatabase()
            }.then(on: DispatchQueue.main) { () -> Guarantee<Void> in
                self.finalizeRestorationIfNecessary()
            }.done(on: DispatchQueue.main) {
                // After transfer our push token has changed, update it.
                //TODO:temptalk Need more details
                firstly {
                    SyncPushTokensJob.run(accountManager: SignalApp.shared().accountManager, preferences: Environment.shared.preferences, uploadOnlyIfStale: false)
                }.catch(on: DispatchQueue.global()) { error in
                    Logger.error("Error: \(error).")
                }
//                SignalApp.shared().showConversationSplitView()
            }

            stopTransfer(expectedSession: session)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerId: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerId: MCPeerID,
        with fileProgress: Progress
    ) {
        guard let snapshot = attemptSnapshot(expectedSession: session) else { return }

        switch snapshot.state {
        case .idle:
            guard resourceName == DeviceTransferService.manifestIdentifier else { return }
        case .outgoing:
            owsFailDebug("Unexpectedly received a file on old device \(resourceName)")
        case .incoming(let oldDevicePeerId, let manifest, let receivedFileIds, let skippedFileIds, _):
            guard peerId == oldDevicePeerId else {
                return owsFailDebug("Ignoring file from unexpected peer \(peerId)")
            }

            let nameComponents = resourceName.components(separatedBy: " ")

            guard let fileIdentifier = nameComponents.first, nameComponents.count == 2 else {
                return owsFailDebug("Received incorrectly formatted resourceName: \(resourceName)")
            }

            guard !receivedFileIds.contains(fileIdentifier) else { return }

            guard !skippedFileIds.contains(fileIdentifier) else { return }

            guard let file: DeviceTransferProtoFile = {
                switch fileIdentifier {
                case DeviceTransferService.databaseIdentifier:
                    return manifest.database?.database
                case DeviceTransferService.databaseWALIdentifier:
                    return manifest.database?.wal
                default:
                    return manifest.files.first(where: { $0.identifier == fileIdentifier })
                }
            }() else {
                return owsFailDebug("Received unexpected file on new device: \(fileIdentifier)")
            }

            _ = updateCurrentAttempt(expectedSession: session) { state, _ -> Bool in
                guard case .incoming(let currentPeerId, _, let currentReceivedIds, let currentSkippedIds, let currentProgress) = state,
                      currentPeerId == peerId,
                      !currentReceivedIds.contains(fileIdentifier),
                      !currentSkippedIds.contains(fileIdentifier) else { return false }
                currentProgress.addChild(fileProgress, withPendingUnitCount: Int64(file.estimatedSize))
                return true
            }
        }
    }

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerId: MCPeerID,
        at localURL: URL?,
        withError error: Swift.Error?
    ) {
        // Unlike `didReceive data:` this must NOT be dispatched off this thread: `localURL`
        // points at a temporary file that MultipeerConnectivity deletes as soon as this
        // method returns, so the file has to be hashed and moved before we hand back
        // control. Hash outside the service queue, then revalidate the attempt and perform
        // the final move plus state update in one atomic commit.
        guard let snapshot = attemptSnapshot(expectedSession: session) else { return }

        switch snapshot.state {
        case .idle:
            guard resourceName == DeviceTransferService.manifestIdentifier else { return }

            if let error = error {
                failTransfer(.connectionLost, "Failed to receive manifest \(error)", expectedSession: session)
            } else if let localURL = localURL {
                handleReceivedManifest(at: localURL, fromPeer: peerId, session: session)
            } else {
                failTransfer(.connectionLost, "Manifest completed with no URL or error", expectedSession: session)
            }
        case .outgoing:
            owsFailDebug("Unexpectedly received a file on old device \(resourceName)")
        case .incoming(let oldDevicePeerId, let manifest, let receivedFileIds, let skippedFileIds, _):
            guard peerId == oldDevicePeerId else {
                return owsFailDebug("Ignoring file from unexpected peer \(peerId)")
            }

            let nameComponents = resourceName.components(separatedBy: " ")

            guard let fileIdentifier = nameComponents.first, let fileHash = nameComponents.last, nameComponents.count == 2 else {
                return owsFailDebug("Received incorrectly formatted resourceName: \(resourceName)")
            }

            guard !receivedFileIds.contains(fileIdentifier) else { return }

            guard !skippedFileIds.contains(fileIdentifier) else { return }

            guard let file: DeviceTransferProtoFile = {
                switch fileIdentifier {
                case DeviceTransferService.databaseIdentifier:
                    return manifest.database?.database
                case DeviceTransferService.databaseWALIdentifier:
                    return manifest.database?.wal
                default:
                    return manifest.files.first(where: { $0.identifier == fileIdentifier })
                }
            }() else {
                return owsFailDebug("Received unexpected file on new device: \(fileIdentifier)")
            }

            if let error = error {
                failTransfer(.connectionLost, "Failed to receive file \(file.identifier) \(error)", expectedSession: session)
            } else if let localURL = localURL {
                guard let computedHash = try? Cryptography.computeSHA256DigestOfFile(at: localURL) else {
                    return failTransfer(.assertion, "Failed to compute hash for \(file.identifier)", expectedSession: session)
                }

                guard computedHash.hexadecimalString == fileHash else {
                    return failTransfer(.assertion, "Received file with incorrect hash \(file.identifier)", expectedSession: session)
                }

                guard computedHash != DeviceTransferService.missingFileHash else {
                    Logger.warn("Received notification of missing file: \(file.identifier), skipping.")
                    _ = updateCurrentAttempt(expectedSession: session) { state, _ -> Bool in
                        guard case .incoming(let currentPeerId, _, let currentReceivedIds, let currentSkippedIds, _) = state,
                              currentPeerId == peerId,
                              !currentReceivedIds.contains(file.identifier),
                              !currentSkippedIds.contains(file.identifier) else { return false }
                        state = state.appendingSkippedFileId(file.identifier)
                        return true
                    }
                    return
                }

                // Idempotent and not part of the atomic commit; keep it out of the lock.
                OWSFileSystem.ensureDirectoryExists(DeviceTransferService.pendingTransferFilesDirectory.path)

                do {
                    _ = try updateCurrentAttempt(expectedSession: session) { state, _ -> Bool in
                        guard case .incoming(let currentPeerId, _, let currentReceivedIds, let currentSkippedIds, _) = state,
                              currentPeerId == peerId,
                              !currentReceivedIds.contains(file.identifier),
                              !currentSkippedIds.contains(file.identifier) else { return false }

                        guard OWSFileSystem.moveFilePath(
                            localURL.path,
                            toFilePath: URL(
                                fileURLWithPath: file.identifier,
                                relativeTo: DeviceTransferService.pendingTransferFilesDirectory
                            ).path
                        ) else {
                            throw OWSAssertionError("Failed to move file into place \(file.identifier)")
                        }
                        state = state.appendingFileId(file.identifier)
                        return true
                    }
                } catch {
                    return failTransfer(.assertion, "Failed to commit file \(file.identifier): \(error)", expectedSession: session)
                }
            } else {
                failTransfer(.connectionLost, "File completed with no URL or error", expectedSession: session)
            }
        }
    }

    func session(
        _ session: MCSession,
        didReceiveCertificate certificates: [Any]?,
        fromPeer peerId: MCPeerID,
        certificateHandler: @escaping (Bool) -> Void
    ) {
        let snapshot = attemptSnapshot(expectedSession: session)

        // A certificate callback may arrive after an interrupted transfer has
        // already installed a fresh session. Reject the obsolete handshake, but
        // never fail the current transfer because of it.
        guard let snapshot else {
            certificateHandler(false)
            return
        }

        var certificateIsTrusted = false

        defer {
            certificateHandler(certificateIsTrusted)
            if !certificateIsTrusted {
                self.failTransfer(
                    .certificateMismatch,
                    "the received certificate did not match the expected certificate",
                    expectedSession: session
                )
            }
        }

        guard case .outgoing(let newDevicePeerId, let expectedCertificateHash, _, _, _) = snapshot.state else {
            // Accept all connections if we're not doing an outgoing transfer AND we aren't yet registered.
            // Registered devices can only ever perform outgoing transfers.
            certificateIsTrusted = !tsAccountManager.isRegistered()
            return
        }

        // Reject any connections from unexpected devices.
        guard peerId == newDevicePeerId else { return }

        // Verify the received certificate matches the expected certificate.
        guard let certificate = certificates?.first else {
            return owsFailDebug("new connection did not provide any certificate")
        }

        let certificateData = SecCertificateCopyData(certificate as! SecCertificate) as Data

        // Reject any connections where we can't compute the certificate hash
        guard let certificateHash = Cryptography.computeSHA256Digest(certificateData) else {
            return owsFailDebug("failed to calculate certificate hash")
        }

        // Reject any connections where the certificate doesn't match the expected certificate
        guard expectedCertificateHash.ows_constantTimeIsEqual(to: certificateHash) else {
            return owsFailDebug("connection from known peer \(peerId) using unexpected certificate")
        }

        certificateIsTrusted = true
    }
}
