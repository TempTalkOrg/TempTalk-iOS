//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import MultipeerConnectivity

extension DeviceTransferService {
    enum Error: Swift.Error {
        case advertisingFailed
        case assertion
        case cancel
        case backgroundedDevice
        case certificateMismatch
        case connectionLost
        case localNetworkPermissionDenied
        case localNetworkPermissionDeniedAfterSystemPrompt
        case modeMismatch
        /// The receiving device cannot fit the incoming transfer.
        case notEnoughSpace
        /// This device cannot fit the snapshot it has to make of its own database.
        case notEnoughSpaceOnThisDevice
        case unsupportedVersion

        /// Only `.assertion` means "this should have been impossible". Every other case is
        /// an expected outcome the user can hit, so it must never trip a debug assertion.
        var isProgrammerError: Bool {
            if case .assertion = self { return true }
            return false
        }

        var message: String {
            switch self {
            case .advertisingFailed, .assertion, .connectionLost:
                return "DEVICE_TRANSFER_ERROR_GENERIC".localized
            case .cancel:
                return ""
            case .backgroundedDevice:
                return "DEVICE_TRANSFER_ERROR_BACKGROUNDED_DEVICE".localized
            case .certificateMismatch:
                return "DEVICE_TRANSFER_ERROR_CERTIFICATE_MISMATCH".localized
            case .localNetworkPermissionDenied, .localNetworkPermissionDeniedAfterSystemPrompt:
                return DeviceTransferUI.localNetworkPermissionMessage
            case .modeMismatch:
                return "DEVICE_TRANSFER_ERROR_MODE_MISMATCH_PRIMARY".localized
            case .notEnoughSpace:
                return "DEVICE_TRANSFER_ERROR_NOT_ENOUGH_SPACE".localized
            case .notEnoughSpaceOnThisDevice:
                return "DEVICE_TRANSFER_ERROR_NOT_ENOUGH_SPACE_THIS_DEVICE".localized
            case .unsupportedVersion:
                return "DEVICE_TRANSFER_ERROR_UNSUPPORTED_VERSION".localized
            }
        }
    }

    enum TransferState {
        case idle
        case incoming(
            oldDevicePeerId: MCPeerID,
            manifest: DeviceTransferProtoManifest,
            receivedFileIds: [String],
            skippedFileIds: [String],
            progress: Progress
        )
        case outgoing(
            newDevicePeerId: MCPeerID,
            newDeviceCertificateHash: Data,
            manifest: DeviceTransferProtoManifest,
            transferredFileIds: [String],
            progress: Progress
        )

        func appendingFileId(_ fileId: String) -> TransferState {
            switch self {
            case .incoming(let oldDevicePeerId, let manifest, let receivedFileIds, let skippedFileIds, let progress):
                return .incoming(
                    oldDevicePeerId: oldDevicePeerId,
                    manifest: manifest,
                    receivedFileIds: receivedFileIds + [fileId],
                    skippedFileIds: skippedFileIds,
                    progress: progress
                )
            case .outgoing(let newDevicePeerId, let newDeviceCertificateHash, let manifest, let transferredFileIds, let progress):
                return .outgoing(
                    newDevicePeerId: newDevicePeerId,
                    newDeviceCertificateHash: newDeviceCertificateHash,
                    manifest: manifest,
                    transferredFileIds: transferredFileIds + [fileId],
                    progress: progress
                )
            case .idle:
                owsFailDebug("unexpectedly tried to append file while idle")
                return .idle
            }
        }

        func appendingSkippedFileId(_ fileId: String) -> TransferState {
            switch self {
            case .incoming(let oldDevicePeerId, let manifest, let receivedFileIds, let skippedFileIds, let progress):
                return .incoming(
                    oldDevicePeerId: oldDevicePeerId,
                    manifest: manifest,
                    receivedFileIds: receivedFileIds,
                    skippedFileIds: skippedFileIds + [fileId],
                    progress: progress
                )
            case .outgoing(let newDevicePeerId, let newDeviceCertificateHash, let manifest, let transferredFileIds, let progress):
                owsFailDebug("unexpectedly tried to append a skipped file on outgoing")
                return .outgoing(
                    newDevicePeerId: newDevicePeerId,
                    newDeviceCertificateHash: newDeviceCertificateHash,
                    manifest: manifest,
                    transferredFileIds: transferredFileIds,
                    progress: progress
                )
            case .idle:
                owsFailDebug("unexpectedly tried to append a skipped file while idle")
                return .idle
            }
        }
    }

    enum TransferMode: String {
        case linked
        case primary
    }
}
