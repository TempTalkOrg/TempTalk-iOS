//
//  DTGifFavoriteAssetLoader.swift
//  TTServiceKit
//
//  Resolves a favorite pointer to a decrypted GIF on disk:
//  getFileInfo (download URL) → download ciphertext → decrypt → cache file.
//  Mirrors the message attachment download path in OWSAttachmentsProcessor.
//

import Foundation

public enum DTGifFavoriteAssetError: Error {
    case invalidPointer
    case noDownloadUrl
    case downloadFailed(Error)
    case decryptFailed
}

@objc
public final class DTGifFavoriteAssetLoader: NSObject {

    @objc public static let shared = DTGifFavoriteAssetLoader()

    private static let folderName = "GifFavorites"
    /// Disk cache cap for decrypted favorite GIFs; oldest files are evicted past this.
    private static let maxCacheBytes: UInt64 = 100 * 1024 * 1024

    private let localStore = DTGifFavoriteLocalStore()

    private lazy var cacheDir: String = {
        let dir = (OWSFileSystem.cachesDirectoryPath() as NSString).appendingPathComponent(Self.folderName)
        _ = OWSFileSystem.ensureDirectoryExists(dir)
        return dir
    }()

    /// Durable (NON-purgeable) staging for a pre-upload panel favorite's bytes. The display cache
    /// lives in Caches, which iOS can purge before a slow/offline upload finishes — then the job's
    /// upload source vanishes and it fails forever. This dir is in the app-group container (like the
    /// DB), so a queued favorite survives until its job uploads it.
    private lazy var pendingUploadDir: String = {
        let dir = (OWSFileSystem.appSharedDataDirectoryPath() as NSString).appendingPathComponent("GifFavoritePendingUploads")
        _ = OWSFileSystem.ensureDirectoryExists(dir)
        return dir
    }()

    /// Decrypted GIF file URL for `pointer`. Returns the cached file on a hit,
    /// otherwise downloads + decrypts the account-level asset and caches it.
    public func localGifURL(for pointer: FavoriteAttachmentPointer) async throws -> URL {
        let fileURL = cacheFileURL(forFileHash: pointer.fileHash)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // Pending (pre-upload) favorite: no server asset yet (authorizeId stays 0 until the job
        // resolves it). Render from the local WebP the enqueue seeded so it shows offline.
        if pointer.authorizeId <= 0 {
            if let localPath = pendingLocalPath(forFileHash: pointer.fileHash),
               FileManager.default.fileExists(atPath: localPath),
               seedLocalAsset(fileHash: pointer.fileHash, sourcePath: localPath) != nil,
               FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
            throw DTGifFavoriteAssetError.invalidPointer
        }

        guard let key = Data(base64Encoded: pointer.key), !key.isEmpty else {
            throw DTGifFavoriteAssetError.invalidPointer
        }
        let digest = Data(base64Encoded: pointer.digest)

        let urls = try await fetchDownloadUrls(pointer: pointer)
        let cipher = try await download(urls: urls)
        // unpaddedSize 0 = return the full decrypted bytes untrimmed. These assets aren't
        // Signal-padded (shouldPad=NO), so this yields the exact WebP. `pointer.size` (plaintext
        // byte count) is carried on the wire for platforms that trim padding, but iOS needs no trim.
        let plaintext = try decrypt(cipher: cipher, key: key, digest: digest, unpaddedSize: 0)

        try plaintext.write(to: fileURL, options: .atomic)
        enforceCacheLimit()
        return fileURL
    }

    /// LRU eviction: if the cache dir exceeds `maxCacheBytes`, delete oldest files
    /// (by modification date) until back under the cap. Best-effort, never throws.
    private func enforceCacheLimit() {
        let dirURL = URL(fileURLWithPath: cacheDir)
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dirURL, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
            return
        }
        var entries: [(url: URL, size: UInt64, modified: Date)] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize, let modified = values.contentModificationDate else {
                return nil
            }
            return (url, UInt64(size), modified)
        }
        var total = entries.reduce(UInt64(0)) { $0 + $1.size }
        guard total > Self.maxCacheBytes else { return }

        entries.sort { $0.modified < $1.modified }  // oldest first
        for entry in entries {
            guard total > Self.maxCacheBytes else { break }
            if (try? FileManager.default.removeItem(at: entry.url)) != nil {
                total -= entry.size
            }
        }
    }

    // MARK: - Local seeding (pre-upload display)

    /// Copy a local WebP/GIF into the cache under `fileHash` so a pending (not-yet-uploaded)
    /// favorite renders instantly with no network. Returns the destination path (existing or new),
    /// or nil if the copy failed. Best-effort.
    @discardableResult
    public func seedLocalAsset(fileHash: String, sourcePath: String) -> String? {
        let dest = cacheFileURL(forFileHash: fileHash)
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }
        // Copy to a sibling temp path then atomically rename, so a crash mid-copy can't leave a
        // truncated file that the existence-only hit path would later serve as valid.
        let tmp = URL(fileURLWithPath: cacheDir).appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: tmp.path)
            try FileManager.default.moveItem(at: tmp, to: dest)
            return dest.path
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            Logger.error("[GifFav] seed local asset failed: \(error)")
            return nil
        }
    }

    /// Remove a cached asset (used when rolling back a permanently-failed favorite).
    public func removeCachedAsset(fileHash: String) {
        try? FileManager.default.removeItem(at: cacheFileURL(forFileHash: fileHash))
    }

    /// Durable staging copy of a panel favorite's bytes for its upload job (survives Caches purge).
    /// Returns the durable path, or nil on failure. Atomic (copy → rename).
    public func stagePendingUpload(fileHash: String, sourcePath: String) -> String? {
        let dest = (pendingUploadDir as NSString).appendingPathComponent("\(Self.safeName(fileHash)).webp")
        if FileManager.default.fileExists(atPath: dest) { return dest }
        let tmp = (pendingUploadDir as NSString).appendingPathComponent(UUID().uuidString + ".tmp")
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: tmp)
            try FileManager.default.moveItem(atPath: tmp, toPath: dest)
            return dest
        } catch {
            try? FileManager.default.removeItem(atPath: tmp)
            Logger.error("[GifFav] stage pending upload failed: \(error)")
            return nil
        }
    }

    /// Delete the durable upload staging file once its job commits / rolls back / is cancelled.
    public func removePendingUpload(fileHash: String) {
        let dest = (pendingUploadDir as NSString).appendingPathComponent("\(Self.safeName(fileHash)).webp")
        try? FileManager.default.removeItem(atPath: dest)
    }

    private func pendingLocalPath(forFileHash fileHash: String) -> String? {
        databaseStorage.read { tx in self.localStore.localWebpPath(forFileHash: fileHash, tx) }
    }

    // MARK: - Steps

    private func fetchDownloadUrls(pointer: FavoriteAttachmentPointer) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            // Account-level favorite: no group scope.
            DTFileRequestHandler.getFileInfo(withFileHash: pointer.fileHash,
                                             authorizeId: UInt64(pointer.authorizeId),
                                             gid: "") { entity, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var urls = entity?.urls ?? []
                if urls.isEmpty, let single = entity?.url, !single.isEmpty {
                    urls = [single]
                }
                guard !urls.isEmpty else {
                    continuation.resume(throwing: DTGifFavoriteAssetError.noDownloadUrl)
                    return
                }
                continuation.resume(returning: urls)
            }
        }
    }

    private func download(urls: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DTFileDownloader.default().downloadFile(withUrls: urls, progress: nil) { data in
                continuation.resume(returning: data)
            } failure: { error in
                continuation.resume(throwing: DTGifFavoriteAssetError.downloadFailed(error))
            }
        }
    }

    private func decrypt(cipher: Data, key: Data, digest: Data?, unpaddedSize: UInt32) throws -> Data {
        // Algorithm (md5 vs sha256) is inferred from digest length inside SSKCryptography.
        guard let plaintext = try? SSKCryptography.decryptAttachment(cipher,
                                                                     withKey: key,
                                                                     digest: digest,
                                                                     useMd5Hash: true,
                                                                     unpaddedSize: unpaddedSize) else {
            throw DTGifFavoriteAssetError.decryptFailed
        }
        return plaintext
    }

    // MARK: - Cache path

    private func cacheFileURL(forFileHash fileHash: String) -> URL {
        let path = (cacheDir as NSString).appendingPathComponent("\(Self.safeName(fileHash)).gif")
        return URL(fileURLWithPath: path)
    }

    /// fileHash is Base64 (may contain '/', '+', '='), or a pending temp key ("pending:<giphyId>");
    /// make it filesystem-safe.
    private static func safeName(_ fileHash: String) -> String {
        fileHash
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: ":", with: "_")
    }
}
