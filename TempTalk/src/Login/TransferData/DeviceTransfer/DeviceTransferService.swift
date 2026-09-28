//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB
import MultipeerConnectivity
import Network
import TTServiceKit
import UIKit

protocol DeviceTransferServiceObserver: AnyObject {
    func deviceTransferServiceDiscoveredNewDevice(peerId: MCPeerID, discoveryInfo: [String: String]?)

    func deviceTransferServiceDidStartTransfer(progress: Progress)
    func deviceTransferServiceDidEndTransfer(error: DeviceTransferService.Error?)
}

///
/// The following service is used to facilitate users in transferring their account from
/// an old device (OD) to a new device (ND) using MultipeerConnectivity. The general steps
/// of the process follow the following flow:
///
/// 1) As you begin setting up a new device (ND), you are asked if you want to transfer data
///    from an old device (OD). This happens *after* the SMS code and reg lock pin are provided,
///    but (importantly) before the service replaces your old account. Accounts are identified
///    by the service as being eligible for transfer by setting the "transfer" capability.
/// 2) In order to notify potential ODs on the network, the ND will begin advertising a
///    “transfer service” using Bonjour. Nearby ODs will be readily browsing for this service,
///     but not establishing any connections until the user takes action. The ND will actively
///     attempt to connect to any other “transfer service” it finds. MC will under-the-hood
///     determine whether it’s best to use peer-to-peer Wi-Fi, Bluetooth, or infrastructure Wi-Fi
/// 3) In order to prepare for a session from the OD, the ND will generate an RSA 2048 private
///    key and self-signed public certificate (used for DTLS). It will then present a QR code
///    that contains:
///      a. The transfer version, so we can eliminate the need for a lot of backwards compatibility
///      b. The MC Peer identifier (an opaque blob of data that represents the ND, that the
///         OD can use to determine what device to connect to)
///      c. A sha256 hash of the public certificate, so we can verify we're connected to
///         the appropriate ND
///      d. A mode flag indicating whether we're expecting to transfer from a primary device
///         or a linked device.
/// 4) On your OD, you will accept the prompt in the Signal app to enter transfer mode.
///    A QR scanner will be presented to you.
/// 5) When the OD scans the QR code presented on the ND, it will:
///      a. Attempt to open an encrypted (DTLS) session with the specified MC session identifier
///      b. Validate the certificate for the connection exactly matches the certificate scanned from the ND
///      c. Start locally behaving as if it is unregistered, without actually unregistering from the
///         service (to prevent two devices registered with the same number)
///      d. Send a manifest to the ND that outlines a list of all the files it should expect, including:
///          i. The SQLCipher DB key
///          ii. The sqlite database file (with no additional encryption beyond SQLCipher)
///          iii. All attachment files stored on the device
///          iv. The user preference dictionary (user defaults)
///      e. Start transferring all the files to the new device
///  6) When all data has been transferred successfully,
///      a. the OD will:
///          i. Flag that it was transferred, it will now remain unregistered regardless of what
///             happens on the ND.
///          ii. Send a "done" message to the ND, to notify that it thinks it's done
///          iii. Wait for a "done" message from the ND – if received, all local data will be deleted.
///      b. the ND will, upon receipt of the "done" message:
///          i. Verify all data that was expected to be received was received
///          ii. Mark itself as pending restore
///          iii. Notify the ND that it is "done" and it's safe to self-destruct
///          iv. Move all the received files into place, set the new database key, etc.
///          v. Hot-swap the new database into place and present the conversation list
///
@objc
class DeviceTransferService: NSObject {

    static let appSharedDataDirectory = URL(fileURLWithPath: OWSFileSystem.appSharedDataDirectoryPath())
    static let pendingTransferDirectory = URL(fileURLWithPath: "transfer", isDirectory: true, relativeTo: appSharedDataDirectory)
    static let pendingTransferFilesDirectory = URL(fileURLWithPath: "files", isDirectory: true, relativeTo: pendingTransferDirectory)

    static let manifestIdentifier = "manifest"
    static let databaseIdentifier = "database"
    static let databaseWALIdentifier = "database-wal"

    static let missingFileData = "Missing File".data(using: .utf8)!
    static let missingFileHash = Cryptography.computeSHA256Digest(missingFileData)!

    // This must also be updated in the info.plist
    private static let newDeviceServiceIdentifier = "cht-new-device"
    /// iOS exposes no local-network authorization status. Persist whether the receiver has
    /// completed one decision so later inactive transitions cannot imitate its first prompt.
    private static let receiverLocalNetworkPermissionResolvedKey =
        "DeviceTransfer.receiverLocalNetworkPermissionResolved"

    private final class AttemptContext {
        let id = UUID()
        var state: TransferState
        let session: MCSession
        let identity: SecIdentity
        var advertiser: MCNearbyServiceAdvertiser?
        /// Set once an invitation has been accepted, so a second concurrent invitation
        /// cannot attach another peer. Kept separate from `advertiser` because the
        /// advertiser must stay alive until teardown — dropping the only strong reference
        /// deallocates it (its delegate is weak) and implicitly stops advertising while
        /// the MCSession handshake is still in flight.
        var hasAcceptedInvitation = false
        var sendTask: Task<Void, Never>?

        init(
            state: TransferState,
            session: MCSession,
            identity: SecIdentity,
            advertiser: MCNearbyServiceAdvertiser? = nil
        ) {
            self.state = state
            self.session = session
            self.identity = identity
            self.advertiser = advertiser
        }
    }

    private final class LocalNetworkProbeContext {
        let id: UUID
        let browser: NWBrowser
        var isPolicyDenied = false
        var shouldReturnReceiverOnDenial: Bool
        /// Set only when Multipeer itself failed with a permission error. A granted
        /// `NWBrowser` probe then restarts that transport without replacing the QR attempt.
        var transportNeedsRestart: Bool

        init(
            id: UUID = UUID(),
            browser: NWBrowser,
            shouldReturnReceiverOnDenial: Bool = false,
            transportNeedsRestart: Bool = false
        ) {
            self.id = id
            self.browser = browser
            self.shouldReturnReceiverOnDenial = shouldReturnReceiverOnDenial
            self.transportNeedsRestart = transportNeedsRestart
        }
    }

    struct AttemptSnapshot {
        let id: UUID
        let state: TransferState
        let session: MCSession
    }

    private struct AttemptTeardown {
        let id: UUID
        let state: TransferState
        let session: MCSession
        let advertiser: MCNearbyServiceAdvertiser?
        let sendTask: Task<Void, Never>?
    }

    private let serialQueue = DispatchQueue(label: "DeviceTransferService")
    private let localNetworkProbeQueue = DispatchQueue(label: "DeviceTransferService.LocalNetworkProbe")
    private var currentAttempt: AttemptContext?
    private var outgoingPreparationId: UUID?
    private var localNetworkProbe: LocalNetworkProbeContext?

    var transferState: TransferState {
        serialQueue.sync { currentAttempt?.state ?? .idle }
    }

    var session: MCSession? {
        serialQueue.sync { currentAttempt?.session }
    }

    func attemptSnapshot(expectedSession: MCSession? = nil) -> AttemptSnapshot? {
        serialQueue.sync {
            guard let attempt = currentAttempt else { return nil }
            if let expectedSession, attempt.session !== expectedSession { return nil }
            return AttemptSnapshot(id: attempt.id, state: attempt.state, session: attempt.session)
        }
    }

    func isCurrentAttempt(session: MCSession) -> Bool {
        serialQueue.sync { currentAttempt?.session === session }
    }

    private var currentAttemptId: UUID? {
        serialQueue.sync { currentAttempt?.id }
    }
    private(set) lazy var peerId = MCPeerID(displayName: UUID().uuidString)

    private var newDeviceServiceBrowser: MCNearbyServiceBrowser?

    private func makeNewDeviceServiceBrowser() -> MCNearbyServiceBrowser {
        let browser = MCNearbyServiceBrowser(
            peer: peerId,
            serviceType: DeviceTransferService.newDeviceServiceIdentifier
        )
        browser.delegate = self
        return browser
    }

    private func makeNewDeviceServiceAdvertiser() -> MCNearbyServiceAdvertiser {
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerId, discoveryInfo: nil,
            serviceType: DeviceTransferService.newDeviceServiceIdentifier
        )
        advertiser.delegate = self
        return advertiser
    }

    // MARK: -

    override init() {
        super.init()

        SwiftSingletons.register(self)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: .OWSApplicationDidEnterBackground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActiveForLocalNetworkProbe),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActiveForLocalNetworkProbe),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    // MARK: - New Device

    func startAcceptingTransfersFromOldDevices(mode: TransferMode) throws -> URL {
        guard case .idle = transferState else {
            throw OWSAssertionError("Attempted to replace an active device-transfer receiver")
        }

        // A QR code owns its complete transport attempt. Tear down the previous
        // idle receiver synchronously before creating a fresh identity, session,
        // and advertiser for the next QR code.
        stopTransfer()

        // Create an identity to use for our TLS sessions, the old device
        // will verify this identity via the QR code
        let identity = try SelfSignedIdentity.create(name: "IncomingDeviceTransfer", validForDays: 1)

        let session = MCSession(peer: peerId, securityIdentity: [identity], encryptionPreference: .required)
        session.delegate = self
        let advertiser = makeNewDeviceServiceAdvertiser()

        let attempt = AttemptContext(
            state: .idle,
            session: session,
            identity: identity,
            advertiser: advertiser
        )
        serialQueue.sync { currentAttempt = attempt }
        startLocalNetworkPermissionProbe(probeId: attempt.id)
        advertiser.startAdvertisingPeer()

        do {
            let transferURL = try urlForTransfer(mode: mode, identity: identity)
            Logger.info(
                "[DeviceTransfer][NewDevice] Receiver ready and QR payload generated; " +
                "attemptId=\(attempt.id), peer=\(peerId.displayName)"
            )
            return transferURL
        } catch {
            let nsError = error as NSError
            Logger.error(
                "[DeviceTransfer][NewDevice] Failed to generate QR payload; " +
                "domain=\(nsError.domain), code=\(nsError.code), " +
                "description=\(nsError.localizedDescription)"
            )
            stopTransfer(expectedSession: session)
            throw error
        }
    }

    func stopAcceptingTransfersFromOldDevices() {
        let advertiser = serialQueue.sync { () -> MCNearbyServiceAdvertiser? in
            guard let attempt = currentAttempt else { return nil }
            let advertiser = attempt.advertiser
            attempt.advertiser = nil
            return advertiser
        }
        advertiser?.stopAdvertisingPeer()
    }

    func cancelTransferFromOldDevice() {
        AssertIsOnMainThread()

        guard let snapshot = attemptSnapshot() else { return }
        switch snapshot.state {
        case .incoming:
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: .cancel) }
            stopTransfer(expectedSession: snapshot.session)
        case .idle:
            // The receiver intentionally remains idle while displaying its QR
            // code. Cancelling that screen must still tear down its advertiser
            // and session.
            stopTransfer(expectedSession: snapshot.session)
        case .outgoing:
            return
        }
    }

    // MARK: - Local Network Permission

    private func startLocalNetworkPermissionProbe(
        probeId: UUID = UUID(),
        shouldReturnReceiverOnDenial: Bool = false,
        transportNeedsRestart: Bool = false
    ) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_\(Self.newDeviceServiceIdentifier)._tcp", domain: nil),
            using: parameters
        )
        let context = LocalNetworkProbeContext(
            id: probeId,
            browser: browser,
            shouldReturnReceiverOnDenial: shouldReturnReceiverOnDenial,
            transportNeedsRestart: transportNeedsRestart
        )
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let browser else { return }
            self?.handleLocalNetworkProbeState(state, probeId: probeId, expectedBrowser: browser)
        }

        let previousProbe = serialQueue.sync { () -> LocalNetworkProbeContext? in
            let previousProbe = localNetworkProbe
            localNetworkProbe = context
            return previousProbe
        }
        previousProbe?.browser.cancel()
        browser.start(queue: localNetworkProbeQueue)
    }

    private func stopLocalNetworkPermissionProbe(expectedProbeId: UUID? = nil) {
        let probe = serialQueue.sync { () -> LocalNetworkProbeContext? in
            guard let probe = localNetworkProbe else { return nil }
            if let expectedProbeId, probe.id != expectedProbeId { return nil }
            localNetworkProbe = nil
            return probe
        }
        probe?.browser.cancel()
    }

    private func handleLocalNetworkProbeState(
        _ state: NWBrowser.State,
        probeId: UUID,
        expectedBrowser: NWBrowser
    ) {
        let isPolicyDenied = state.isLocalNetworkPolicyDenied

        let probeUpdate = serialQueue.sync { () -> (shouldConfirmDenial: Bool, shouldRestartTransport: Bool) in
            guard let probe = localNetworkProbe,
                  probe.id == probeId,
                  probe.browser === expectedBrowser else { return (false, false) }
            probe.isPolicyDenied = isPolicyDenied
            if case .ready = state {
                probe.shouldReturnReceiverOnDenial = false
                if currentAttempt?.id == probeId {
                    UserDefaults.standard.set(true, forKey: Self.receiverLocalNetworkPermissionResolvedKey)
                }
                return (false, probe.transportNeedsRestart)
            }
            return (isPolicyDenied, false)
        }
        if probeUpdate.shouldRestartTransport {
            restartLocalNetworkTransport(probeId: probeId, expectedBrowser: expectedBrowser)
        }
        if probeUpdate.shouldConfirmDenial {
            scheduleLocalNetworkDenialConfirmation(probeId: probeId, expectedBrowser: expectedBrowser)
        }
    }

    private func restartLocalNetworkTransport(probeId: UUID, expectedBrowser: NWBrowser) {
        DispatchMainThreadSafe {
            let transport = self.serialQueue.sync {
                () -> (advertiser: MCNearbyServiceAdvertiser?, browser: MCNearbyServiceBrowser?) in
                guard let probe = self.localNetworkProbe,
                      probe.id == probeId,
                      probe.browser === expectedBrowser,
                      probe.transportNeedsRestart else { return (nil, nil) }

                let advertiser: MCNearbyServiceAdvertiser?
                let browser: MCNearbyServiceBrowser?
                if let attempt = self.currentAttempt, attempt.id == probeId {
                    advertiser = attempt.advertiser
                    browser = nil
                } else {
                    advertiser = nil
                    browser = self.newDeviceServiceBrowser
                }
                guard advertiser != nil || browser != nil else { return (nil, nil) }
                probe.transportNeedsRestart = false
                return (advertiser, browser)
            }

            transport.advertiser?.startAdvertisingPeer()
            transport.browser?.startBrowsingForPeers()
        }
    }

    private func scheduleLocalNetworkDenialConfirmation(probeId: UUID, expectedBrowser: NWBrowser) {
        // When permission is undetermined, the system can report PolicyDenied while its own
        // authorization sheet is still visible. Wait until the app is active and give a granted
        // NWBrowser time to move to .ready before presenting our Settings guidance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard UIApplication.shared.applicationState == .active else { return }
            self?.reportLocalNetworkDenialIfNeeded(probeId: probeId, expectedBrowser: expectedBrowser)
        }
    }

    func localNetworkOperationDidReportPermissionDenied(
        expectedBrowser: MCNearbyServiceBrowser? = nil,
        expectedAdvertiser: MCNearbyServiceAdvertiser? = nil
    ) {
        let probe = serialQueue.sync { () -> LocalNetworkProbeContext? in
            if let expectedBrowser, newDeviceServiceBrowser !== expectedBrowser { return nil }
            if let expectedAdvertiser, currentAttempt?.advertiser !== expectedAdvertiser { return nil }
            guard let probe = localNetworkProbe else { return nil }
            probe.isPolicyDenied = true
            probe.transportNeedsRestart = true
            return probe
        }
        guard let probe else { return }
        scheduleLocalNetworkDenialConfirmation(probeId: probe.id, expectedBrowser: probe.browser)
    }

    @objc
    private func applicationWillResignActiveForLocalNetworkProbe() {
        serialQueue.sync {
            guard let probe = localNetworkProbe,
                  let attempt = currentAttempt,
                  attempt.id == probe.id,
                  case .idle = attempt.state else { return }
            if case .ready = probe.browser.state { return }
            guard !UserDefaults.standard.bool(forKey: Self.receiverLocalNetworkPermissionResolvedKey) else {
                return
            }
            probe.shouldReturnReceiverOnDenial = true
        }
    }

    @objc
    private func applicationDidBecomeActiveForLocalNetworkProbe() {
        let probeSnapshot = serialQueue.sync {
            localNetworkProbe.map {
                ($0.id, $0.shouldReturnReceiverOnDenial, $0.transportNeedsRestart)
            }
        }
        guard let (probeId, shouldReturnReceiverOnDenial, transportNeedsRestart) = probeSnapshot else {
            return
        }
        startLocalNetworkPermissionProbe(
            probeId: probeId,
            shouldReturnReceiverOnDenial: shouldReturnReceiverOnDenial,
            transportNeedsRestart: transportNeedsRestart
        )
    }

    private func reportLocalNetworkDenialIfNeeded(probeId: UUID, expectedBrowser: NWBrowser) {
        AssertIsOnMainThread()

        let denial = serialQueue.sync {
            () -> (
                probe: LocalNetworkProbeContext,
                session: MCSession?,
                browser: MCNearbyServiceBrowser?,
                shouldReturnReceiver: Bool
            )? in
            guard let probe = localNetworkProbe,
                  probe.id == probeId,
                  probe.browser === expectedBrowser,
                  probe.isPolicyDenied,
                  probe.browser.state.isLocalNetworkPolicyDenied else { return nil }

            let session: MCSession?
            let browser: MCNearbyServiceBrowser?
            if let attempt = currentAttempt, attempt.id == probeId {
                session = attempt.session
                browser = nil
            } else {
                session = nil
                browser = newDeviceServiceBrowser
            }
            guard session != nil || browser != nil else { return nil }
            let shouldReturnReceiver: Bool
            if session != nil {
                let permissionWasAlreadyResolved = UserDefaults.standard.bool(
                    forKey: Self.receiverLocalNetworkPermissionResolvedKey
                )
                UserDefaults.standard.set(true, forKey: Self.receiverLocalNetworkPermissionResolvedKey)
                shouldReturnReceiver = probe.shouldReturnReceiverOnDenial && !permissionWasAlreadyResolved
            } else {
                shouldReturnReceiver = false
            }
            localNetworkProbe = nil
            return (probe, session, browser, shouldReturnReceiver)
        }
        guard let denial else { return }

        denial.probe.browser.cancel()
        let reason = "Bonjour permission probe is waiting with PolicyDenied (-65570)"
        Logger.error("[DeviceTransfer] \(reason)")

        let transferError: Error = denial.shouldReturnReceiver
            ? .localNetworkPermissionDeniedAfterSystemPrompt
            : .localNetworkPermissionDenied
        if let session = denial.session {
            failTransfer(transferError, reason, expectedSession: session)
        } else if let browser = denial.browser {
            browserDidFailToStart(
                browser,
                transferError: transferError,
                reason: reason
            )
        }
    }

    // MARK: - Old Device

    func startListeningForNewDevices() {
        // Give each discovery lifecycle its own browser identity. Delegate callbacks can be
        // delivered after stopBrowsingForPeers(), so a late failure must be distinguishable
        // from a failure belonging to the currently visible flow.
        let browser = makeNewDeviceServiceBrowser()
        let previousBrowser = serialQueue.sync { () -> MCNearbyServiceBrowser? in
            let previousBrowser = newDeviceServiceBrowser
            newDeviceServiceBrowser = browser
            return previousBrowser
        }
        previousBrowser?.stopBrowsingForPeers()
        startLocalNetworkPermissionProbe()
        browser.startBrowsingForPeers()
    }

    func stopListeningForNewDevices() {
        let browser = serialQueue.sync { () -> MCNearbyServiceBrowser? in
            defer { newDeviceServiceBrowser = nil }
            return newDeviceServiceBrowser
        }
        browser?.stopBrowsingForPeers()
        stopLocalNetworkPermissionProbe()
    }

    func isCurrentBrowser(_ browser: MCNearbyServiceBrowser) -> Bool {
        serialQueue.sync { newDeviceServiceBrowser === browser }
    }

    func browserDidFailToStart(_ browser: MCNearbyServiceBrowser, transferError: Error, reason: String) {
        let (wasActiveBrowser, activeSession) = serialQueue.sync { () -> (Bool, MCSession?) in
            guard newDeviceServiceBrowser === browser else { return (false, nil) }
            newDeviceServiceBrowser = nil
            return (true, currentAttempt?.session)
        }
        guard wasActiveBrowser else {
            Logger.info("[DeviceTransfer][OldDevice] Ignoring failure from stale browser; \(reason)")
            return
        }

        browser.stopBrowsingForPeers()
        stopLocalNetworkPermissionProbe()
        if let activeSession {
            failTransfer(transferError, reason, expectedSession: activeSession, stopBrowser: false)
        } else {
            Logger.error("[DeviceTransfer][OldDevice] \(reason)")
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: transferError) }
        }
    }

    func transferAccountToNewDevice(with peerId: MCPeerID, certificateHash: Data) throws {
        guard let browser = serialQueue.sync(execute: { newDeviceServiceBrowser }) else {
            throw OWSAssertionError("Attempted to transfer without an active device browser")
        }

        // Never stop the browser here: it is the same browser instance that discovered
        // `peerId`, and `invitePeer` below can only reach peers found while browsing.
        stopTransfer(stopBrowser: false)
        let preparationId = UUID()
        serialQueue.sync { outgoingPreparationId = preparationId }

        // Marking the transfer as "in progress" does a few things, most notably it:
        //   * prevents any WAL checkpoints while the transfer is in progress
        //   * causes the device to behave is if it's not registered
        tsAccountManager.isTransferInProgress = true

        defer {
            // If we failed to start the transfer, clear the transfer in progress flag
            let preparationWasCleared = serialQueue.sync { () -> Bool in
                guard outgoingPreparationId == preparationId else { return false }
                outgoingPreparationId = nil
                return true
            }
            if preparationWasCleared { tsAccountManager.isTransferInProgress = false }
        }

        let manifest = try buildManifest()
        let progress = Progress(totalUnitCount: Int64(manifest.estimatedTotalSize))

        // We don't actually need to generate an identity for the old device, the new device
        // doesn't verify this information. We do it anyway, for consistency.
        let identity = try SelfSignedIdentity.create(name: "OutgoingDeviceTransfer", validForDays: 1)

        let session = MCSession(peer: self.peerId, securityIdentity: [identity], encryptionPreference: .required)
        session.delegate = self
        let state = TransferState.outgoing(
            newDevicePeerId: peerId,
            newDeviceCertificateHash: certificateHash,
            manifest: manifest,
            transferredFileIds: [],
            progress: progress
        )
        let attempt = AttemptContext(state: state, session: session, identity: identity)
        let installed = serialQueue.sync { () -> Bool in
            guard
                outgoingPreparationId == preparationId,
                currentAttempt == nil,
                newDeviceServiceBrowser === browser
            else { return false }
            outgoingPreparationId = nil
            currentAttempt = attempt
            return true
        }
        guard installed else {
            session.disconnect()
            throw CancellationError()
        }
        deviceSleepManager.addBlock(blockObject: session)

        Logger.info(
            "[DeviceTransfer][OldDevice] Inviting new device; " +
            "remotePeer=\(peerId.displayName), timeout=30, " +
            "estimatedBytes=\(manifest.estimatedTotalSize), files=\(manifest.files.count), " +
            "attemptId=\(attempt.id), hasSession=true"
        )
        browser.invitePeer(peerId, to: session, withContext: nil, timeout: 30)
    }

    func cancelTransferToNewDevice() {
        guard let snapshot = attemptSnapshot(), case .outgoing = snapshot.state else { return }

        notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: .cancel) }

        stopTransfer(expectedSession: snapshot.session)
    }

    // MARK: - Observation

    private var observers = [Weak<DeviceTransferServiceObserver>]()
    func addObserver(_ observer: DeviceTransferServiceObserver) {
        observers.append(Weak(value: observer))
    }

    func removeObserver(_ observer: DeviceTransferServiceObserver) {
        observers.removeAll { return $0.value === observer }
    }

    func notifyObservers(_ block: @escaping (DeviceTransferServiceObserver) -> Void) {
        DispatchMainThreadSafe {
            self.observers.compactMap { $0.value }.forEach { block($0) }
        }
    }

    // MARK: -

    func updateCurrentAttempt<T>(
        expectedSession: MCSession,
        _ block: (inout TransferState, UUID) throws -> T
    ) rethrows -> T? {
        try serialQueue.sync(execute: {
            guard let attempt = currentAttempt, attempt.session === expectedSession else { return nil }
            return try block(&attempt.state, attempt.id)
        })
    }

    func invitationSnapshot(for advertiser: MCNearbyServiceAdvertiser) -> AttemptSnapshot? {
        serialQueue.sync {
            guard let attempt = currentAttempt, attempt.advertiser === advertiser else { return nil }
            // Claim the invitation atomically so two concurrent callbacks cannot both attach
            // peers to the same QR attempt. The advertiser itself stays owned by the attempt
            // and is stopped at teardown; releasing it here would deallocate it mid-handshake.
            guard !attempt.hasAcceptedInvitation else { return nil }
            attempt.hasAcceptedInvitation = true
            return AttemptSnapshot(id: attempt.id, state: attempt.state, session: attempt.session)
        }
    }

    func replaceSendTask(_ task: Task<Void, Never>, expectedSession: MCSession) -> Bool {
        let previousTask: Task<Void, Never>? = serialQueue.sync {
            guard let attempt = currentAttempt, attempt.session === expectedSession else { return nil }
            let previousTask = attempt.sendTask
            attempt.sendTask = task
            return previousTask
        }
        previousTask?.cancel()
        return isCurrentAttempt(session: expectedSession)
    }

    func failTransfer(
        _ error: Error,
        _ reason: String,
        expectedSession: MCSession? = nil,
        expectedAdvertiser: MCNearbyServiceAdvertiser? = nil,
        stopBrowser: Bool = true
    ) {
        // Keep expected-attempt validation, detachment, teardown, and observer delivery in one
        // main-queue block. If UI navigation installs a retry before this callback is handled,
        // the expected session/advertiser check rejects the stale failure without touching the
        // replacement attempt or delivering an obsolete alert. This is intentionally async
        // off-main: disconnecting synchronously from inside MCSession's delegate callback can
        // re-enter the framework or deadlock its private queue.
        let finishFailure = {
            let (teardown, cancelledPreparation) = self.takeCurrentAttemptForTeardown(
                expectedSession: expectedSession,
                expectedAdvertiser: expectedAdvertiser
            )
            if (expectedSession != nil || expectedAdvertiser != nil), teardown == nil {
                return
            }

            Logger.error(
                "[DeviceTransfer] Transfer failed; " +
                "attemptId=\(teardown?.id.uuidString ?? "none"), reason=\(reason)"
            )
            // Expected outcomes (peer disconnected, backgrounded, out of space, ...) reach
            // this method too. Only actual invariant failures should assert in debug builds.
            if error.isProgrammerError {
                owsFailDebug(reason)
            }

            self.teardownAttempt(
                teardown,
                cancelledPreparation: cancelledPreparation,
                stopBrowser: stopBrowser
            )
            self.notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: error) }
        }

        if Thread.isMainThread {
            finishFailure()
        } else {
            DispatchQueue.main.async(execute: finishFailure)
        }
    }

    /// - Parameter stopBrowser: pass `false` when the caller is about to invite a peer with
    ///   the shared browser. Discovered peers are only invitable while browsing, so tearing
    ///   a stale attempt down must not take the browser with it.
    func stopTransfer(expectedSession: MCSession? = nil, stopBrowser: Bool = true) {
        let (teardown, cancelledPreparation) = takeCurrentAttemptForTeardown(expectedSession: expectedSession)
        if expectedSession != nil, teardown == nil { return }
        let finishStop = {
            self.teardownAttempt(
                teardown,
                cancelledPreparation: cancelledPreparation,
                stopBrowser: stopBrowser && expectedSession == nil
            )
        }

        if Thread.isMainThread {
            finishStop()
        } else {
            // Unlike failure callbacks, callers use stopTransfer as an ordering barrier before
            // installing a retry attempt. Preserve that synchronous contract while keeping all
            // framework teardown on main.
            DispatchQueue.main.sync(execute: finishStop)
        }
    }

    private func takeCurrentAttemptForTeardown(
        expectedSession: MCSession? = nil,
        expectedAdvertiser: MCNearbyServiceAdvertiser? = nil
    ) -> (AttemptTeardown?, Bool) {
        serialQueue.sync {
            let cancelledPreparation = expectedSession == nil && expectedAdvertiser == nil && outgoingPreparationId != nil
            guard let attempt = currentAttempt else {
                if expectedSession == nil, expectedAdvertiser == nil { outgoingPreparationId = nil }
                return (nil, cancelledPreparation)
            }
            if let expectedSession, attempt.session !== expectedSession { return (nil, false) }
            if let expectedAdvertiser, attempt.advertiser !== expectedAdvertiser { return (nil, false) }

            currentAttempt = nil
            if expectedSession == nil, expectedAdvertiser == nil { outgoingPreparationId = nil }
            return (AttemptTeardown(
                id: attempt.id,
                state: attempt.state,
                session: attempt.session,
                advertiser: attempt.advertiser,
                sendTask: attempt.sendTask
            ), cancelledPreparation)
        }
    }

    private func teardownAttempt(
        _ teardown: AttemptTeardown?,
        cancelledPreparation: Bool,
        stopBrowser: Bool
    ) {
        AssertIsOnMainThread()

        teardown?.sendTask?.cancel()
        if let teardown {
            switch teardown.state {
            case .idle, .incoming:
                // The receiver probe uses its attempt ID. A delayed teardown must never
                // cancel a probe already installed for a replacement QR attempt.
                stopLocalNetworkPermissionProbe(expectedProbeId: teardown.id)
            case .outgoing:
                break
            }
        }
        if stopBrowser { stopListeningForNewDevices() }
        teardown?.advertiser?.stopAdvertisingPeer()
        teardown?.session.disconnect()
        if let session = teardown?.session { deviceSleepManager.removeBlock(blockObject: session) }

        // It is possible that we get here because the app was backgrounded
        // after a failed launch. In that case, `tsAccountManager` will not be
        // available, and setting this will crash. It'd probably be safe to more
        // simply return in the .idle case above since none of the values being
        // reset should have values if we are idle, but I am scared of it.
        if let teardown, case .idle = teardown.state {} else if teardown != nil || cancelledPreparation {
            tsAccountManager.isTransferInProgress = false
        }

        stopThroughputCalculation(
            expectedAttemptId: teardown?.id,
            onlyIfNoCurrentAttempt: teardown == nil
        )
    }

    // MARK: -

    @objc
    func didEnterBackground() {
        let snapshot = attemptSnapshot()
        guard let snapshot else {
            stopTransfer()
            return
        }
        switch snapshot.state {
        case .idle:
            // The receiver stays idle while its QR code waits for a manifest. `stopTransfer()`
            // below drops that code's advertiser and identity, so the code on screen becomes
            // unusable. Tell the screen, or it keeps displaying a dead QR code with no
            // indication that it can no longer be scanned.
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: .backgroundedDevice) }
        case .incoming(let oldDevicePeerId, _, _, _, _):
            // Signal commit 74780ac0f0: MCSession will disconnect in the
            // background, so tell the peer why before tearing down the attempt.
            try? sendBackgroundAppMessage(to: oldDevicePeerId, session: snapshot.session)
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: .backgroundedDevice) }
        case .outgoing(let newDevicePeerId, _, _, _, _):
            try? sendBackgroundAppMessage(to: newDevicePeerId, session: snapshot.session)
            notifyObservers { $0.deviceTransferServiceDidEndTransfer(error: .backgroundedDevice) }
        }

        stopTransfer(expectedSession: snapshot.session)
    }

    // MARK: - Sending

    func sendTransferPayload(session: MCSession) {
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.sendManifest(session: session)
                try await self.sendAllFilesTask(session: session)
            } catch is CancellationError {
            } catch {
                // A completion from a cancelled transfer may arrive after a retry has
                // installed a new session. Never let old work fail the new transfer.
                guard self.isCurrentAttempt(session: session) else { return }
                // MCSession calls translate their NSError at the boundary into
                // `.connectionLost`. Any remaining untyped error came from local preparation,
                // hashing, snapshotting, or another invariant and remains an assertion.
                self.failTransfer(
                    (error as? DeviceTransferService.Error) ?? .assertion,
                    "\(error)",
                    expectedSession: session
                )
            }
        }
        guard replaceSendTask(task, expectedSession: session) else { task.cancel(); return }
    }

    private struct DatabaseTransferCopy {
        let file: DeviceTransferProtoFile
        let url: URL
    }

    @MainActor
    private func sendAllFilesTask(session: MCSession) async throws {
        try Task.checkCancellation()
        guard let snapshot = attemptSnapshot(expectedSession: session) else { throw CancellationError() }
        guard case .outgoing(let newDevicePeerId, _, let manifest, _, _) = snapshot.state else {
            throw OWSAssertionError("Attempted to send files while no transfer in progress")
        }

        guard let database = manifest.database else {
            throw OWSAssertionError("Manifest unexpectedly missing database")
        }

        Logger.info(
            "[DeviceTransfer][OldDevice] Preparing data file queue; " +
            "estimatedBytes=\(manifest.estimatedTotalSize), dataFiles=\(manifest.files.count), " +
            "databaseBytes=\(database.database.estimatedSize), walBytes=\(database.wal.estimatedSize), " +
            "connectedPeers=\(session.connectedPeers.count)"
        )

        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
            taskGroup.addTask {
                let copies: [DatabaseTransferCopy] = try await self.databaseStorage.awaitableWrite { transaction in
                    // MultipeerConnectivity can stall indefinitely when asked to send an
                    // empty file. Force a real WAL write before taking the database snapshot,
                    // matching Signal's current transfer implementation. The temporary value is removed
                    // in the same transaction, so no transfer-only state remains in the DB.
                    let store = SDSKeyValueStore(collection: "DeviceTransferWAL")
                    store.setData(
                        Randomness.generateRandomBytes(32),
                        key: "MustBeNonEmpty",
                        transaction: transaction.asSDSWrite
                    )
                    store.removeValue(forKey: "MustBeNonEmpty", transaction: transaction.asSDSWrite)

                    // `sqlite3_db_cacheflush` returns SQLITE_BUSY and flushes nothing while a
                    // cursor still pins a page, which leaves exactly the empty WAL this block
                    // exists to prevent. Fail loudly instead of stalling the peer at 0%.
                    try GRDBDatabaseStorageAdapter.flushDatabaseCache(transaction.database)

                    try Self.verifyEnoughSpaceForDatabaseSnapshot(files: [database.database, database.wal])

                    return try [database.database, database.wal].map(Self.makeDatabaseTransferCopy)
                }
                defer {
                    for copy in copies {
                        try? OWSFileSystem.deleteFile(url: copy.url)
                    }
                }

                for copy in copies {
                    try Task.checkCancellation()
                    try await DeviceTransferOperation(
                        session: session,
                        file: copy.file,
                        sourceURL: copy.url
                    ).run()
                }
            }

            for (index, file) in manifest.files.enumerated() {
                if index >= 10 {
                    // Match Signal: keep at most ten attachment tasks in flight.
                    try await taskGroup.next()
                }
                taskGroup.addTask {
                    try await DeviceTransferOperation(session: session, file: file).run()
                }
            }

            try await taskGroup.waitForAll()
        }

        try Task.checkCancellation()
        guard isCurrentAttempt(session: session) else { throw CancellationError() }
        Logger.info("[DeviceTransfer][OldDevice] All data file operations completed; sending done message")
        if !DebugFlags.deviceTransferThrowAway {
            tsAccountManager.wasTransferred = true
        }
        do {
            try sendDoneMessage(to: newDevicePeerId, session: session)
        } catch {
            throw DeviceTransferService.Error.connectionLost
        }
    }

    private static func makeDatabaseTransferCopy(
        databaseFile: DeviceTransferProtoFile
    ) throws -> DatabaseTransferCopy {
        let sourceURL = URL(
            fileURLWithPath: databaseFile.relativePath,
            relativeTo: DeviceTransferService.appSharedDataDirectory
        )
        guard OWSFileSystem.fileOrFolderExists(url: sourceURL) else {
            throw OWSAssertionError("Mandatory database file is missing for transfer")
        }

        let copyURL = OWSFileSystem.temporaryFileUrl(fileExtension: sourceURL.pathExtension)
        try FileManager.default.copyItem(at: sourceURL, to: copyURL)

        // MultipeerConnectivity stalls indefinitely on an empty file rather than failing, so
        // never let one reach the send queue.
        guard let copiedSize = OWSFileSystem.fileSize(of: copyURL)?.uint64Value, copiedSize > 0 else {
            try? OWSFileSystem.deleteFile(url: copyURL)
            throw OWSAssertionError("Database snapshot \(databaseFile.identifier) is unexpectedly empty")
        }

        return DatabaseTransferCopy(file: databaseFile, url: copyURL)
    }

    /// Snapshotting copies the database so the write transaction can be released before the
    /// slow transfer starts, which costs its size again on disk. Check for that headroom up
    /// front so a full disk reports "not enough space" instead of failing opaquely mid-copy.
    private static func verifyEnoughSpaceForDatabaseSnapshot(files: [DeviceTransferProtoFile]) throws {
        let requiredBytes = files.reduce(UInt64(0)) { $0 + $1.estimatedSize }

        guard let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(
            forPath: DeviceTransferService.appSharedDataDirectory.path
        ), let freeSpaceInBytes = fileSystemAttributes[.systemFreeSize] as? UInt64 else {
            throw OWSAssertionError("Failed to calculate available disk space for database snapshot")
        }

        guard freeSpaceInBytes > requiredBytes else {
            Logger.error(
                "[DeviceTransfer][OldDevice] Not enough space for database snapshot; " +
                "freeBytes=\(freeSpaceInBytes), requiredBytes=\(requiredBytes)"
            )
            throw DeviceTransferService.Error.notEnoughSpaceOnThisDevice
        }
    }

    static let doneMessage = "Transfer Complete".data(using: .utf8)!
    func sendDoneMessage(to peerId: MCPeerID, session expectedSession: MCSession? = nil) throws {
        guard let session = expectedSession ?? session else {
            throw OWSAssertionError("attempted to send done message without an available session")
        }

        try session.send(DeviceTransferService.doneMessage, toPeers: [peerId], with: .reliable)
    }

    static let backgroundAppMessage = "App backgrounded".data(using: .utf8)!
    func sendBackgroundAppMessage(to peerId: MCPeerID, session expectedSession: MCSession? = nil) throws {
        guard let session = expectedSession ?? session else {
            throw OWSAssertionError("attempted to send backgrounded message without an available session")
        }

        try session.send(DeviceTransferService.backgroundAppMessage, toPeers: [peerId], with: .unreliable)
    }

    // MARK: - Throughput

    private var previouslyCompletedBytes: Double = 0
    private var lastWholeNumberProgress = 0
    private var throughputTimer: Timer?
    private var throughputAttemptId: UUID?
    func startThroughputCalculation(expectedSession: MCSession? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.startThroughputCalculation(expectedSession: expectedSession) }
            return
        }

        stopThroughputCalculation()

        guard let snapshot = attemptSnapshot(expectedSession: expectedSession) else { return }
        guard let progress: Progress = {
            switch snapshot.state {
            case .incoming(_, _, _, _, let progress):
                return progress
            case .outgoing(_, _, _, _, let progress):
                return progress
            case .idle:
                owsFailDebug("Can't start throughput calculation while idle")
                return nil
            }
        }() else {
            return owsFailDebug("Can't start throughput calculations without progress")
        }

        throughputAttemptId = snapshot.id
        previouslyCompletedBytes = Double(progress.totalUnitCount) * progress.fractionCompleted
        throughputTimer = WeakTimer.scheduledTimer(timeInterval: 1, target: self, userInfo: nil, repeats: true) { _ in
            guard self.currentAttemptId == snapshot.id else {
                self.stopThroughputCalculation(expectedAttemptId: snapshot.id)
                return
            }
            let completedBytes = Double(progress.totalUnitCount) * progress.fractionCompleted
            let bytesOverLastSecond = completedBytes - self.previouslyCompletedBytes
            let remainingBytes = Double(progress.totalUnitCount) - completedBytes
            self.previouslyCompletedBytes = completedBytes

            if let averageThroughput = progress.throughput {
                // Give more weight to the existing average than the new value
                // to "smooth" changes in throughput and estimated time remaining.
                let newAverageThroughput = 0.2 * Double(bytesOverLastSecond) + 0.8 * Double(averageThroughput)
                progress.throughput = Int(newAverageThroughput)
                progress.estimatedTimeRemaining = remainingBytes / newAverageThroughput
            } else {
                progress.throughput = Int(bytesOverLastSecond)
                progress.estimatedTimeRemaining = remainingBytes / TimeInterval(bytesOverLastSecond)
            }

            self.logProgress(progress, remainingBytes: remainingBytes)
        }
        throughputTimer?.fire()
    }

    private func logProgress(_ progress: Progress, remainingBytes: Double) {
        let currentWholeNumberProgress = Int(progress.fractionCompleted * 100)
        let percentChange = currentWholeNumberProgress - lastWholeNumberProgress

        defer { lastWholeNumberProgress = currentWholeNumberProgress }

        // Determine how frequently to log progress updates. If in verbose mode, we log
        // every 1%. Otherwise, every 10%.
        guard percentChange >= (DebugFlags.deviceTransferVerboseProgressLogging ? 1 : 10) else { return }

        var progressLog = String(format: "Transfer progress %d%%", currentWholeNumberProgress)

        var remainingNumber = remainingBytes
        var remainingUnits = "b"
        if remainingNumber / 1024 >= 1 {
            remainingNumber /= 1024
            remainingUnits = "Kb"
        }
        if remainingNumber / 1024 >= 1 {
            remainingNumber /= 1024
            remainingUnits = "Mb"
        }
        if remainingNumber / 1024 >= 1 {
            remainingNumber /= 1024
            remainingUnits = "Gb"
        }

        progressLog += String(format: " / %0.2f %@ remaining", remainingNumber, remainingUnits)

        if let throughput = progress.throughput {
            var transferSpeed = Double(throughput) / 1024
            var transferUnits = "Kbps"
            if transferSpeed / 1024 >= 1 {
                transferSpeed /= 1024
                transferUnits = "Mbps"
            }

            progressLog += String(format: " / %0.2f %@", transferSpeed, transferUnits)
        }

        if let estimatedTime = progress.estimatedTimeRemaining, estimatedTime.isFinite {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .full
            formatter.maximumUnitCount = 2
            formatter.includesApproximationPhrase = true
            formatter.includesTimeRemainingPhrase = true

            let formattedString = formatter.string(from: estimatedTime)!

            progressLog += " / \(formattedString)"
        }

        Logger.info(progressLog)
    }

    func stopThroughputCalculation(
        expectedAttemptId: UUID? = nil,
        onlyIfNoCurrentAttempt: Bool = false
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.stopThroughputCalculation(
                    expectedAttemptId: expectedAttemptId,
                    onlyIfNoCurrentAttempt: onlyIfNoCurrentAttempt
                )
            }
            return
        }
        if onlyIfNoCurrentAttempt, currentAttemptId != nil { return }
        if let expectedAttemptId, throughputAttemptId != expectedAttemptId { return }
        throughputTimer?.invalidate()
        throughputTimer = nil
        throughputAttemptId = nil
        previouslyCompletedBytes = 0
        lastWholeNumberProgress = 0
    }
}

private extension NWError {
    var isLocalNetworkPolicyDenied: Bool {
        guard case .dns(let code) = self else { return false }
        return Int(code) == -65_570
    }
}

private extension NWBrowser.State {
    var isLocalNetworkPolicyDenied: Bool {
        switch self {
        case .waiting(let error), .failed(let error):
            return error.isLocalNetworkPolicyDenied
        case .setup, .ready, .cancelled:
            return false
        @unknown default:
            return false
        }
    }
}
