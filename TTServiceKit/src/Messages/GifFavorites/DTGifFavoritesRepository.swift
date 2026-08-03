//
//  DTGifFavoritesRepository.swift
//  TTServiceKit
//
//  GIF favorites business logic (v2, see ~/Desktop/design-v2-cross-platform.md):
//   - favKey is stable and wrapped by a KEK derived from the ACI identity private key
//     (wrappedFavKey stored on the server). Any logged-in device derives the KEK locally and
//     unwraps favKey — no peer dependency, no SyncMessage distribution, no recovery state machine.
//   - Optimistic local cache + pending queue (instant/offline; replays when possible).
//   - listVersion optimistic-lock CAS (status 9) for favorite/unfavorite; status 1 = permanent reject.
//   - fileHash dedup + 200-cap FIFO. Display & send both use WebP.
//

import Foundation
import CryptoKit

public enum FavoritesRepoError: Error {
    case masterKeyUnavailable   // ACI identity key not ready (rare) → op stays optimistically pending
    case favKeyUnwrapFailed     // wrappedFavKey present but KEK can't open it (stale masterKey → re-link)
    case encryptFailed
    case conflictRetriesExhausted
    case permanentlyRejected    // server invalid-param (status 1) → don't retry, roll back optimistic op
}

// Only a hard server rejection is terminal; everything else (offline, missing key, CAS churn) should
// stay pending and retry via the job runner's exponential backoff.
extension FavoritesRepoError: IsRetryableProvider {
    public var isRetryableProvider: Bool {
        switch self {
        case .permanentlyRejected:
            return false
        case .masterKeyUnavailable, .favKeyUnwrapFailed, .encryptFailed, .conflictRetriesExhausted:
            return true
        }
    }
}

@objc
public final class DTGifFavoritesRepository: NSObject {

    @objc public static let shared = DTGifFavoritesRepository()

    /// Posted (on main) whenever the local favorites display could have changed — lets an open
    /// favorites view refresh from cache regardless of when an async add/remove finally lands.
    @objc public static let favoritesDidChangeNotification = Notification.Name("DTGifFavoritesDidChangeNotification")

    public static let maxFavorites = 200
    private static let encVersion = 1
    private static let maxConflictRetries = 3
    // Envelope status codes (v2 §2.1).
    private static let statusInvalidParam = 1
    private static let statusConflict = 9

    // KEK derivation params — MUST be byte-identical across clients (v2 §3.2 / §7).
    private static let kekSalt = Data("tt-fav-kek-salt-v1".utf8)
    private static let kekInfo = Data("tt-fav-kek-v1".utf8)

    private let api = DTGifFavoritesAPI()
    private let crypto: GifFavoriteCryptoService = DTGifFavoriteCryptoServiceImpl()
    private let localStore = DTGifFavoriteLocalStore()

    // The stable favKey once obtained this session (unwrapped / first-built / reset). Kept so an
    // identity rotation can re-wrap it to the new KEK without needing the old KEK (§3.4 rewrap).
    // Atomic: read/written from concurrent async mutation paths and the identity-rotation callbacks.
    private let cachedFavKey = AtomicOptional<Data>(nil, lock: .sharedGlobal)

    // Identity-reset gate (§3.4): set ONLY by the identity layer when the primary device re-registers
    // with a NEW aci (old masterKey gone). Only then may an unwrap failure escalate to a destructive
    // reset — a decrypt failure alone (e.g. a KEK bug) must never wipe the list.
    private let identityStateStore = SDSKeyValueStore(collection: "DTGifFavoritesIdentityState")
    private static let resetPendingKey = "resetPendingForNewIdentity"

    // MARK: - Read

    /// Instant, offline snapshot from the local cache (no network). For fast tab open.
    public func cachedFavorites() -> [FavoriteRecord] {
        databaseStorage.read { tx in self.localStore.displayRecords(tx) }
    }

    /// Current favorites count (confirmed + pending) — drives the 200-cap confirmation (§4.3).
    public func favoritesCount() -> Int {
        cachedFavorites().count
    }

    /// Whether a GIPHY search result (by its asset id) is favorited on this device.
    public func isGiphyFavorited(_ giphyId: String) -> Bool {
        databaseStorage.read { tx in self.localStore.isGiphyFavorited(giphyId, tx) }
    }

    /// Whether an item (by content fileHash) is currently favorited on this device — lets a caller
    /// skip the 200-cap prompt for a repeat favorite, which only bumps and never grows the count.
    public func isFavorited(fileHash: String) -> Bool {
        databaseStorage.read { tx in self.localStore.pointer(forFileHash: fileHash, tx) != nil }
    }

    /// Fetch + decrypt the latest server list, refresh the confirmed cache, return the merged view.
    /// Pending ops are committed by their own jobs (not flushed here); orphaned pending is picked up
    /// by `DTGifFavoriteSendManager.reconcile()` on launch / reconnect.
    /// Throws `masterKeyUnavailable`/`favKeyUnwrapFailed` only in rare identity-key edge cases.
    @discardableResult
    public func loadFavorites() async throws -> [FavoriteRecord] {
        let server = try await api.getFavorites()
        switch try resolveFavKey(server: server) {
        case .ready(let favKey, _):
            let confirmed = confirmedRecords(server: server, favKey: favKey)
            databaseStorage.write { tx in self.localStore.replaceConfirmed(confirmed, tx) }
            Logger.info("[GifFav] load: unwrap OK — \(confirmed.count) confirmed (listVersion=\(server.listVersion)), no write")
        case .needsReset(let favKey, let keyId, let wrapped):
            // Primary + dead identity → reset on panel open (§3.4), seeding with any pending adds.
            Logger.info("[GifFav] load: new-identity reset triggered")
            try await performReset(favKey: favKey, keyId: keyId, wrapped: wrapped,
                                   seedAdds: pendingAddPointers(), baseListVersion: server.listVersion)
        case .firstBuild:
            databaseStorage.write { tx in self.localStore.replaceConfirmed([], tx) }
            Logger.info("[GifFav] load: first build (no server list yet)")
        case .unreadable:
            // Stale/rotating masterKey (current KEK can't open the wrap). Keep the cached list —
            // never wipe on a decrypt failure (§3.4 / §7-8); recovers via rewrap or identity reset.
            Logger.error("[GifFav] favorites unreadable — keeping cached list, not wiping")
        }
        postDidChange()
        return cachedFavorites()
    }

    private func pendingAddPointers() -> [FavoriteAttachmentPointer] {
        databaseStorage.read { tx in self.localStore.pendingOps(tx) }
            .filter { $0.action == .favorite }.compactMap { $0.pointer }
            // Skip pre-upload placeholders (authorizeId 0) — their jobs resolve + commit them later.
            .filter { $0.authorizeId > 0 }
    }

    /// PUT action=reset: server unpins+GCs the prior (dead) list, then pins the seed. Establishes a
    /// fresh favKey/keyId/wrappedFavKey under the current identity. No CAS (integer replacement).
    private func performReset(favKey: Data, keyId: String, wrapped: String,
                              seedAdds: [FavoriteAttachmentPointer], baseListVersion: Int64) async throws {
        var seed = seedAdds
        if seed.count > Self.maxFavorites { seed = Array(seed.suffix(Self.maxFavorites)) }
        let addedVersion = baseListVersion + 1
        let records = seed.map { FavoriteRecord(attachment: $0, addedListVersion: addedVersion) }
        let items = seed.map { FavoriteItemMeta(attachmentId: $0.id, authorizeId: $0.authorizeId, fileHash: $0.fileHash) }
        let blob = try encrypt(list: FavoriteListPlain(records: records), favKey: favKey)
        _ = try await api.putFavorites(FavoritesPutRequest(action: .reset, keyId: keyId,
                                                           blob: blob, items: items, wrappedFavKey: wrapped))
        Logger.info("[GifFav] reset committed — seeded \(records.count), server unpins+GCs old attachments")
        cachedFavKey.set(favKey)
        databaseStorage.write { tx in
            self.localStore.replaceConfirmed(records, tx)
            self.localStore.clearAllPending(tx)   // whole prior list superseded
        }
        clearResetForNewIdentityFlag()
        postDidChange()
    }

    /// The stored pointer for a favorited item (confirmed or pending) — lets the manager re-enqueue a
    /// bump-to-top without re-uploading. nil if it isn't favorited on this device.
    public func resolvedPointer(forFileHash fileHash: String) -> FavoriteAttachmentPointer? {
        databaseStorage.read { tx in self.localStore.pointer(forFileHash: fileHash, tx) }
    }

    // MARK: - Single-op commit (one job ↔ one op)

    /// Commit exactly one favorite — CAS against the server list, isolated from other pending ops.
    /// On success the op's pending entry is cleared and it lands in `confirmed` (see `commit`).
    public func commitFavorite(_ pointer: FavoriteAttachmentPointer) async throws {
        try await commit(action: .favorite, addPointers: [pointer], removeHashes: [])
    }

    /// Commit exactly one unfavorite — isolated from other pending ops.
    public func commitUnfavorite(fileHash: String) async throws {
        try await commit(action: .unfavorite, addPointers: [], removeHashes: [fileHash])
    }

    // MARK: - CAS commit

    private func commit(action: FavoriteAction, addPointers: [FavoriteAttachmentPointer], removeHashes: [String]) async throws {
        var attempt = 0
        while true {
            attempt += 1
            let server = try await api.getFavorites()

            // Resolve favKey against server state (v2 §3.4).
            let favKey: Data, keyId: String
            var baseRecords: [FavoriteRecord]
            var wrappedToSend: String?   // sent on first build + reset
            var isReset = false
            switch try resolveFavKey(server: server) {
            case .ready(let k, let kid):
                favKey = k; keyId = kid
                baseRecords = confirmedRecords(server: server, favKey: k)
            case .firstBuild(let k, let kid, let w):
                favKey = k; keyId = kid; baseRecords = []; wrappedToSend = w
            case .needsReset(let k, let kid, let w):
                favKey = k; keyId = kid; baseRecords = []; wrappedToSend = w; isReset = true
            case .unreadable:
                throw FavoritesRepoError.favKeyUnwrapFailed   // unwrap failed w/o reset signal (stale masterKey/KEK) — keep pending
            }

            var records = baseRecords
            var items: [FavoriteItemMeta]
            let committedHashes: Set<String>

            switch action {
            case .favorite:
                let newAddedVersion = server.listVersion + 1
                var byHash = Dictionary(records.map { ($0.attachment.fileHash, $0) }, uniquingKeysWith: { existing, _ in existing })
                // A repeat favorite of an existing item isn't skipped — it's bumped to the newest
                // addedListVersion so it moves to the top (dedup, then move-to-front).
                for pointer in addPointers {
                    byHash[pointer.fileHash] = FavoriteRecord(attachment: pointer, addedListVersion: newAddedVersion)
                }
                records = Array(byHash.values).sorted { $0.addedListVersion < $1.addedListVersion }
                if records.count > Self.maxFavorites {
                    let dropped = records.count - Self.maxFavorites
                    records.removeFirst(dropped)  // FIFO: drop oldest
                    Logger.info("[GifFav] over 200 cap — FIFO evicted \(dropped) oldest")
                }
                items = addPointers.map { FavoriteItemMeta(attachmentId: $0.id, authorizeId: $0.authorizeId, fileHash: $0.fileHash) }
                committedHashes = Set(addPointers.map { $0.fileHash })

            case .unfavorite:
                let toRemove = Set(removeHashes)
                let removedRecords = records.filter { toRemove.contains($0.attachment.fileHash) }
                records.removeAll { toRemove.contains($0.attachment.fileHash) }
                items = removedRecords.map { FavoriteItemMeta(attachmentId: $0.attachment.id, authorizeId: $0.attachment.authorizeId, fileHash: $0.attachment.fileHash) }
                committedHashes = toRemove

            case .rewrap, .reset:
                return  // not driven through commit(); reset is auto-derived below
            }

            // Nothing for the server to act on (e.g. unfavorite against a dead/empty list): settle locally.
            guard !items.isEmpty else {
                databaseStorage.write { tx in
                    self.localStore.replaceConfirmed(records, tx)
                    self.localStore.clearPending(fileHashes: committedHashes, tx)
                }
                Logger.info("[GifFav] \(action) settled locally — nothing to PUT")
                return
            }

            // A dead-identity list turns the write into a reset (new key, no CAS, server unpins+GCs old).
            let putAction: FavoriteAction = isReset ? .reset : action
            let blob = try encrypt(list: FavoriteListPlain(records: records), favKey: favKey)
            let put = FavoritesPutRequest(action: putAction,
                                          listVersion: isReset ? nil : server.listVersion,
                                          keyId: keyId,
                                          blob: blob,
                                          items: items,
                                          wrappedFavKey: wrappedToSend)
            do {
                _ = try await api.putFavorites(put)
                cachedFavKey.set(favKey)   // now the server's confirmed favKey
                // Once the server holds a wrap under the CURRENT identity (first build or reset), the
                // new-identity gate has done its job — clear it so a later unwrap failure can't reset.
                if wrappedToSend != nil { clearResetForNewIdentityFlag() }
                databaseStorage.write { tx in
                    self.localStore.replaceConfirmed(records, tx)
                    self.localStore.clearPending(fileHashes: committedHashes, tx)
                }
                Logger.info("[GifFav] committed \(putAction) — \(records.count) records (base listVersion=\(server.listVersion))")
                postDidChange()
                return
            } catch let FavoritesAPIError.server(status, reason) {
                Logger.error("[GifFav] PUT favorites rejected: status=\(status) reason=\(reason)")
                if status == Self.statusConflict {
                    guard attempt < Self.maxConflictRetries else {
                        throw FavoritesRepoError.conflictRetriesExhausted
                    }
                    Logger.info("[GifFav] CAS conflict, re-fetch & replay (attempt \(attempt))")
                    continue
                }
                if status == Self.statusInvalidParam {
                    // Permanent rejection → surface it so the job runner silently rolls back this op
                    // (remove pending + unlink giphy + drop seeded cache).
                    throw FavoritesRepoError.permanentlyRejected
                }
                throw FavoritesAPIError.server(status: status, reason: reason)
            }
        }
    }

    // MARK: - Master-key rotation (v2 §3.3D)

    /// Re-wrap the stable favKey with the current KEK and PUT `rewrap` (no CAS). Called right after the
    /// primary device rotates its identity, with favKey recovered under the old key beforehand (via
    /// `prepareFavKeyForIdentityRotation`) so the list survives to the new identity (§3.4 rewrap).
    /// If favKey couldn't be recovered (prepare hit a network error / nothing cached), the old KEK is
    /// now gone and the server list is unrecoverable → arm a reset so the next panel open rebuilds it,
    /// instead of stranding it as permanently `.unreadable` (§3.4: no old key → reset).
    @objc
    public func rewrapFavKeyAfterIdentityRotation() {
        guard let favKey = cachedFavKey.get() else {
            Logger.error("[GifFav] rotation rewrap has no favKey — arming reset to self-heal")
            markFavoritesResetForNewIdentity()
            return
        }
        Task { await self.rewrapFavKey(oldFavKey: favKey) }
    }

    /// - Parameter oldFavKey: the stable favKey (recovered before the identity rotated / cached).
    ///   After rotation the current KEK can no longer unwrap the old server wrap, so the caller
    ///   supplies the favKey directly. Only the primary device rewraps (§3.1).
    public func rewrapFavKey(oldFavKey: Data) async {
        do {
            guard let kek = deriveKEK(), let rewrapped = crypto.wrapFavKey(oldFavKey, kek: kek) else {
                Logger.info("[GifFav] rewrap skipped (no KEK)")
                return
            }
            _ = try await api.putFavorites(FavoritesPutRequest(action: .rewrap, wrappedFavKey: rewrapped))
            Logger.info("[GifFav] favKey rewrapped to current identity")
        } catch {
            Logger.error("[GifFav] rewrap failed: \(error)")
        }
    }

    /// Recover the stable favKey under the CURRENT (about-to-be-replaced) identity's KEK and cache it,
    /// so the rewrap right after an identity rotation has favKey in hand even if the favorites panel was
    /// never opened this session (§3.4 rewrap: old KEK unwraps favKey → new KEK re-wraps). Call this
    /// BEFORE storing the new identity key, while the old key is still current. Best-effort; no-op if
    /// already cached or the account has no list.
    public func prepareFavKeyForIdentityRotation() async {
        guard cachedFavKey.get() == nil else { return }
        do {
            let server = try await api.getFavorites()
            guard let wrapped = server.wrappedFavKey, let kek = deriveKEK(),
                  let favKey = crypto.unwrapFavKey(wrapped, kek: kek) else { return }
            cachedFavKey.set(favKey)
            Logger.info("[GifFav] favKey recovered under old identity for pending rewrap")
        } catch {
            Logger.error("[GifFav] prepare favKey for rotation failed: \(error)")
        }
    }

    // MARK: - Identity re-registration (v2 §3.4 reset gate)

    /// Called by the identity layer the moment the primary device re-registers with a NEW aci (active
    /// logout → re-login, or an identity-key reset with no old key in hand). Authorizes the next
    /// unwrap-failure to reset the now-unreadable server list, instead of wiping on any decrypt failure.
    /// Cleared once the reset lands; harmless if the account had no list (firstBuild path never resets).
    @objc
    public func markFavoritesResetForNewIdentity() {
        databaseStorage.write { tx in
            self.identityStateStore.setBool(true, key: Self.resetPendingKey, transaction: tx)
        }
        Logger.info("[GifFav] armed reset for new identity")
    }

    private var isResetForNewIdentityPending: Bool {
        databaseStorage.read { tx in
            self.identityStateStore.getBool(Self.resetPendingKey, defaultValue: false, transaction: tx)
        }
    }

    private func clearResetForNewIdentityFlag() {
        databaseStorage.write { tx in
            self.identityStateStore.setBool(false, key: Self.resetPendingKey, transaction: tx)
        }
    }

    // MARK: - Crypto glue

    /// Outcome of resolving favKey against the server state (v2 §3.4).
    private enum FavKeyResolution {
        case ready(favKey: Data, keyId: String)                          // unwrapped an existing list
        case firstBuild(favKey: Data, keyId: String, wrapped: String)    // account never created one
        case needsReset(favKey: Data, keyId: String, wrapped: String)    // primary re-registered (new aci) → rebuild
        case unreadable                                                  // can't unwrap yet (stale/rotating key) → keep data
    }

    private func resolveFavKey(server: FavoritesResponse) throws -> FavKeyResolution {
        guard let kek = deriveKEK() else { throw FavoritesRepoError.masterKeyUnavailable }
        if let keyId = server.keyId, let wrapped = server.wrappedFavKey {
            if let favKey = crypto.unwrapFavKey(wrapped, kek: kek) {
                cachedFavKey.set(favKey)                             // choke point: remember for a future identity rotation
                return .ready(favKey: favKey, keyId: keyId)          // unwrap OK — normal case, write nothing extra
            }
            // Current KEK can't open the wrap → it was made by a previous identity generation.
            // §3.4 / §7-8: a decrypt failure alone must NOT wipe data. A destructive reset is gated on an
            // identity-layer signal (primary re-registered with a new aci). Absent it, treat as a stale/
            // rotating masterKey — keep the list and fail loud, so a KEK bug surfaces instead of deleting.
            guard isResetForNewIdentityPending else {
                Logger.error("[GifFav] favKey unwrap failed with no identity-reset signal — keeping list (masterKey stale?)")
                return .unreadable
            }
            // Primary + confirmed new identity → rebuild under a fresh favKey (§3.4 reset).
            let favKey = crypto.generateFavKey()
            guard let newWrapped = crypto.wrapFavKey(favKey, kek: kek) else { throw FavoritesRepoError.encryptFailed }
            Logger.info("[GifFav] new-identity reset: rebuilding favorites under a fresh favKey")
            return .needsReset(favKey: favKey, keyId: Self.fingerprint(favKey), wrapped: newWrapped)
        }
        // First build on this account: generate favKey + wrap it.
        let favKey = crypto.generateFavKey()
        guard let wrapped = crypto.wrapFavKey(favKey, kek: kek) else { throw FavoritesRepoError.encryptFailed }
        return .firstBuild(favKey: favKey, keyId: Self.fingerprint(favKey), wrapped: wrapped)
    }

    private func confirmedRecords(server: FavoritesResponse, favKey: Data) -> [FavoriteRecord] {
        guard let blob = server.blob, !blob.isEmpty,
              let data = crypto.decryptList(favKey: favKey, blob: blob),
              let list = try? JSONDecoder().decode(FavoriteListPlain.self, from: data) else {
            return []
        }
        return list.records
    }

    private func encrypt(list: FavoriteListPlain, favKey: Data) throws -> String {
        let data = try JSONEncoder().encode(list)
        guard let blob = crypto.encryptList(favKey: favKey, plaintext: data) else {
            throw FavoritesRepoError.encryptFailed
        }
        return blob
    }

    // MARK: - KEK

    /// KEK = HKDF-SHA256(IKM = ACI identity private key 32B, salt, info) (v2 §3.2).
    /// nil when the identity key isn't available yet (rare).
    /// ⚠️ IKM bytes + HKDF params must match Android/Mac byte-for-byte (§7 must-pin).
    private func deriveKEK() -> Data? {
        guard let raw = OWSIdentityManager.shared().identityKeyPair()?.privateKey, raw.count == 32 else {
            return nil
        }
        // Curve25519 clamp — all three ends apply this to the raw scalar before HKDF (v2 final).
        var ikm = [UInt8](raw)
        ikm[0] &= 0xF8
        ikm[31] &= 0x7F
        ikm[31] |= 0x40
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(ikm)),
            salt: Self.kekSalt,
            info: Self.kekInfo,
            outputByteCount: 32)
        return derived.withUnsafeBytes { Data($0) }
    }

    /// favKey fingerprint = Base64(SHA-256(favKey)[0..7]) (v2 §3.2). Stable while favKey is stable.
    private static func fingerprint(_ favKey: Data) -> String {
        Data(SHA256.hash(data: favKey).prefix(8)).base64EncodedString()
    }

    private func postDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.favoritesDidChangeNotification, object: nil)
        }
    }

    /// Public trigger for a favorites-display refresh (used by the job runner on rollback).
    @objc
    public func postFavoritesDidChange() {
        postDidChange()
    }
}
