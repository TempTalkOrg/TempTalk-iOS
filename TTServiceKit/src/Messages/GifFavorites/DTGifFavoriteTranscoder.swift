//
//  DTGifFavoriteTranscoder.swift
//  TTServiceKit
//
//  Turns a downloaded message GIF attachment into an account-level favorite pointer.
//  Reuses the rapid (fileHash) path to pin the asset account-level and get its authorizeId
//  — bytes are already on the server, so this is normally a no-upload hash hit.
//

import Foundation

public enum DTGifFavoriteTranscodeError: Error {
    case missingKey
    case fileNotOnServer
    case invalidAuthorizeId
    case uploadFailed
}

@objc
public final class DTGifFavoriteTranscoder: NSObject {

    /// Serial queue that drives OWSUploadOperation.run for account-level favorite assets.
    private static let uploadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "DTGifFavoriteUpload"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// The content fileHash (rapid/dedup key) for a message attachment, computed locally with no
    /// network — matches the `keyHash` `makePointer(from:)` pins on, so an optimistic pending op and
    /// the eventual confirmed record share the same key.
    public static func fileHash(for stream: TSAttachmentStream) -> String? {
        let key = stream.encryptionKey
        guard !key.isEmpty else { return nil }
        return SSKCryptography.computeSHA256Digest(key)?.base64EncodedString()
    }

    /// Build a favorite pointer from an already-downloaded attachment stream.
    public static func makePointer(from stream: TSAttachmentStream) async throws -> FavoriteAttachmentPointer {
        let key = stream.encryptionKey
        guard !key.isEmpty,
              let keyHash = SSKCryptography.computeSHA256Digest(key)?.base64EncodedString() else {
            throw DTGifFavoriteTranscodeError.missingKey
        }

        // Account-level pin: authorize against self.
        // TODO(backend): confirm recipients scope for an account-level favorite pin.
        let recipients = [TSAccountManager.localNumber()].compactMap { $0 }

        let entity: DTFileDataEntity = try await withCheckedThrowingContinuation { continuation in
            DTFileRequestHandler.checkFileExists(withFileHash: keyHash, recipients: recipients) { entity, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let entity, entity.exists else {
                    continuation.resume(throwing: DTGifFavoriteTranscodeError.fileNotOnServer)
                    return
                }
                continuation.resume(returning: entity)
            }
        }

        guard entity.authorizeIdToInt > 0, !entity.attachmentId.isEmpty else {
            throw DTGifFavoriteTranscodeError.invalidAuthorizeId
        }

        let imageSize = stream.imageSize()
        let digestB64 = stream.digest?.base64EncodedString() ?? entity.cipherHash
        // TODO(cross-platform): §5.1 calls fileHash a "content identity"; here it's SHA256(key)
        //   (the rapid/dedup key the server pins on). Confirm with Android whether the record
        //   primary key should instead be SHA256(plaintext).
        return FavoriteAttachmentPointer(
            id: entity.attachmentId,
            authorizeId: Int64(entity.authorizeIdToInt),
            key: key.base64EncodedString(),
            digest: digestB64,
            fileHash: keyHash,
            contentType: OWSMimeTypeImageWebp,   // v2: favorites are stored/sent as WebP
            width: Int(imageSize.width),
            height: Int(imageSize.height),
            size: Int(stream.byteCount)          // plaintext byte count
        )
    }

    /// Build a favorite pointer from a local WebP file that is NOT yet on the server
    /// (e.g. a GIPHY rendition picked in the panel). Uploads it as an account-level
    /// asset first — encryption/key derivation happen inside OWSUploadOperation — then
    /// reuses the pointer path above. A no-op upload when the rapid hash already exists.
    public static func makePointer(uploadingWebpAt webpPath: String) async throws -> FavoriteAttachmentPointer {
        // Missing source is PERMANENT (retrying can't bring the file back) — throw a non-retryable
        // error so the job rolls back instead of looping forever. With the durable staging dir this
        // shouldn't happen, but it also clears any legacy items whose Caches source was already purged.
        guard FileManager.default.fileExists(atPath: webpPath) else {
            throw OWSGenericError("gif favorite upload source missing")
        }
        let dataSource = try DataSourcePath.dataSource(withFilePath: webpPath,
                                                       shouldDeleteOnDeallocation: false)
        let attrs = try FileManager.default.attributesOfItem(atPath: webpPath)
        let byteCount = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
        guard byteCount > 0 else {
            throw OWSGenericError("gif favorite upload source empty")
        }

        let stream = TSAttachmentStream(contentType: OWSMimeTypeImageWebp,
                                        byteCount: byteCount,
                                        sourceFilename: "favorite.webp",
                                        albumMessageId: nil,
                                        albumId: nil)
        guard stream.write(dataSource) else {
            throw DTGifFavoriteTranscodeError.uploadFailed
        }
        databaseStorage.write { tx in
            stream.anyInsert(transaction: tx)
        }

        // Account-level asset: pin against the local user (no conversation / no message sent).
        let recipients = [TSAccountManager.localNumber()].compactMap { $0 }

        // Drive OWSUploadOperation.run — the content-addressed rapid-transfer upload that registers
        // the file (fileHash = SHA256(SHA512(bytes))) via /v1/file, so it's retrievable by
        // fileHash/authorizeId. (syncrunForUploadOnly uses the avatar endpoint — wrong for this.)
        let operation = OWSUploadOperation(attachmentId: stream.uniqueId, recipientIds: recipients)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            operation.completionBlock = { continuation.resume() }
            Self.uploadQueue.addOperation(operation)
        }
        if let failingError = operation.failingError {
            throw failingError   // surface the real upload error (network / server), not a generic one
        }

        // Re-fetch: a successful run sets encryptionKey (= SHA512(bytes)) / digest / serverId.
        let uploaded: TSAttachmentStream? = databaseStorage.read { tx in
            TSAttachmentStream.anyFetchAttachmentStream(uniqueId: stream.uniqueId, transaction: tx)
        }
        guard let uploaded, uploaded.isUploaded, uploaded.serverId > 0, !uploaded.encryptionKey.isEmpty else {
            throw DTGifFavoriteTranscodeError.uploadFailed
        }
        return try await makePointer(from: uploaded)
    }
}
