//
//  DTGifFavoriteLocalStore.swift
//  TTServiceKit
//
//  Local persistence for the GIF favorites list (design §6.2):
//   - `confirmed`: the last decrypted server list — for instant / offline tab open.
//   - `pending`:   optimistic add/remove ops not yet committed to the server
//                  (favKey missing or PUT deferred), replayed once a key arrives.
//  The list is small (≤200), so the whole state is one JSON blob in a KeyValueStore
//  (no dedicated table / SDSRecordType needed).
//

import Foundation

// MARK: - Pending op

/// A local favorite mutation awaiting server commit.
public struct PendingFavoriteOp: Codable {
    public let action: FavoriteAction
    public let fileHash: String
    public let pointer: FavoriteAttachmentPointer?   // present for `.favorite`
    public let pendingSince: Int64                   // ms epoch; also the sort key (newest first)
    /// Local-only WebP/GIF path for a not-yet-uploaded favorite — lets the asset loader render it
    /// offline before the upload lands. Never encoded into the server blob (pending stays out of it).
    public let localWebpPath: String?

    public init(action: FavoriteAction, fileHash: String, pointer: FavoriteAttachmentPointer?,
                pendingSince: Int64, localWebpPath: String? = nil) {
        self.action = action
        self.fileHash = fileHash
        self.pointer = pointer
        self.pendingSince = pendingSince
        self.localWebpPath = localWebpPath
    }
}

// MARK: - Persisted state

struct LocalFavoritesState: Codable {
    var confirmed: [FavoriteRecord]        // last decrypted server list
    var pending: [PendingFavoriteOp]       // local delta not yet on the server
    // Local-only convenience index (not in the encrypted blob): maps a GIPHY asset id to the
    // fileHash it was stored under, so the panel can tell whether a search result is favorited
    // (favorites are keyed by fileHash, which isn't known until the asset is uploaded).
    var giphyIndex: [String: String]

    init(confirmed: [FavoriteRecord] = [], pending: [PendingFavoriteOp] = [], giphyIndex: [String: String] = [:]) {
        self.confirmed = confirmed
        self.pending = pending
        self.giphyIndex = giphyIndex
    }

    enum CodingKeys: String, CodingKey { case confirmed, pending, giphyIndex }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        confirmed = try c.decodeIfPresent([FavoriteRecord].self, forKey: .confirmed) ?? []
        pending = try c.decodeIfPresent([PendingFavoriteOp].self, forKey: .pending) ?? []
        giphyIndex = try c.decodeIfPresent([String: String].self, forKey: .giphyIndex) ?? [:]
    }
}

// MARK: - Store

public final class DTGifFavoriteLocalStore {

    private static let stateKey = "state"
    private let kv = SDSKeyValueStore(collection: "DTGifFavoriteLocalStore")

    public init() {}

    // MARK: Display

    /// What the favorites tab shows: confirmed ∪ pendingAdd − pendingRemove, newest first.
    public func displayRecords(_ tx: SDSAnyReadTransaction) -> [FavoriteRecord] {
        Self.merge(read(tx))
    }

    static func merge(_ state: LocalFavoritesState) -> [FavoriteRecord] {
        let removedHashes = Set(state.pending.filter { $0.action == .unfavorite }.map { $0.fileHash })
        let pendingAdds = state.pending.filter { $0.action == .favorite }
        let addedHashes = Set(pendingAdds.compactMap { $0.pointer?.fileHash })

        // Drop confirmed rows that are pending-removed or superseded by a pending add.
        var records = state.confirmed.filter {
            !removedHashes.contains($0.attachment.fileHash) && !addedHashes.contains($0.attachment.fileHash)
        }
        // `addedListVersion` doubles as the sort key. Pending adds reuse pendingSince (epoch-ms) for it,
        // which is always far larger than any server listVersion (a small monotonic counter), so pending
        // rows stay on top. Invariant holds only while listVersion is a counter, not an epoch timestamp.
        records.append(contentsOf: pendingAdds.compactMap { op in
            op.pointer.map { FavoriteRecord(attachment: $0, addedListVersion: op.pendingSince) }
        })
        return records.sorted { $0.addedListVersion > $1.addedListVersion }
    }

    // MARK: Confirmed (server-synced)

    /// Replace the confirmed set wholesale after a successful decrypt; leaves pending intact.
    public func replaceConfirmed(_ records: [FavoriteRecord], _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        state.confirmed = records
        write(state, tx)
    }

    // MARK: Pending queue

    /// Optimistically enqueue a favorite. Cancels any prior pending op on the same content, then
    /// always enqueues — even if already confirmed — so a repeat favorite bumps the item to the top
    /// (merge drops the confirmed row and re-adds it at `now`, the newest sort key).
    public func enqueueAdd(_ pointer: FavoriteAttachmentPointer, localWebpPath: String? = nil, now: Int64, _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        state.pending.removeAll { $0.fileHash == pointer.fileHash }
        state.pending.append(PendingFavoriteOp(action: .favorite,
                                               fileHash: pointer.fileHash,
                                               pointer: pointer,
                                               pendingSince: now,
                                               localWebpPath: localWebpPath))
        write(state, tx)
    }

    /// Move an existing pending favorite to the top (re-favorite of a not-yet-committed item) by
    /// refreshing its sort key — without creating a new op or a duplicate job. No-op if not pending.
    public func bumpPending(fileHash: String, now: Int64, _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        guard let idx = state.pending.firstIndex(where: { $0.fileHash == fileHash && $0.action == .favorite }) else { return }
        let op = state.pending[idx]
        state.pending[idx] = PendingFavoriteOp(action: .favorite, fileHash: op.fileHash,
                                               pointer: op.pointer, pendingSince: now, localWebpPath: op.localWebpPath)
        write(state, tx)
    }

    /// Swap a pending favorite's placeholder pointer for the resolved (uploaded/checked) one,
    /// preserving its sort position. The fileHash key may change (temp key → real content hash),
    /// so the GIPHY index is relinked to the resolved fileHash.
    /// Returns false when neither the placeholder nor the resolved key is still a pending favorite —
    /// i.e. the user unfavorited while the upload/resolve was in flight, so the op must NOT be
    /// resurrected. Accepting the resolved key too keeps a relaunch-after-swap idempotent.
    @discardableResult
    public func resolvePendingFavorite(placeholderFileHash: String,
                                       resolved: FavoriteAttachmentPointer,
                                       giphyId: String?,
                                       _ tx: SDSAnyWriteTransaction) -> Bool {
        var state = read(tx)
        let placeholder = state.pending.first { $0.fileHash == placeholderFileHash && $0.action == .favorite }
        let already = state.pending.first { $0.fileHash == resolved.fileHash && $0.action == .favorite }
        guard let since = (placeholder ?? already)?.pendingSince else { return false }
        state.pending.removeAll { $0.fileHash == placeholderFileHash || $0.fileHash == resolved.fileHash }
        state.pending.append(PendingFavoriteOp(action: .favorite,
                                               fileHash: resolved.fileHash,
                                               pointer: resolved,
                                               pendingSince: since))
        if placeholderFileHash != resolved.fileHash {
            state.giphyIndex = state.giphyIndex.filter { $0.value != placeholderFileHash }
        }
        if let giphyId { state.giphyIndex[giphyId] = resolved.fileHash }
        write(state, tx)
        return true
    }

    /// Optimistically enqueue an unfavorite. A pending add + remove cancels out; a remove is
    /// only queued for the server when the content is actually confirmed there.
    public func enqueueRemove(fileHash: String, now: Int64, _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        let hadPendingAdd = state.pending.contains { $0.fileHash == fileHash && $0.action == .favorite }
        state.pending.removeAll { $0.fileHash == fileHash }
        if !hadPendingAdd, state.confirmed.contains(where: { $0.attachment.fileHash == fileHash }) {
            state.pending.append(PendingFavoriteOp(action: .unfavorite,
                                                   fileHash: fileHash,
                                                   pointer: nil,
                                                   pendingSince: now))
        }
        write(state, tx)
    }

    public func pendingOps(_ tx: SDSAnyReadTransaction) -> [PendingFavoriteOp] {
        read(tx).pending
    }

    /// Drop pending ops that have been committed to the server.
    public func clearPending(fileHashes: Set<String>, _ tx: SDSAnyWriteTransaction) {
        guard !fileHashes.isEmpty else { return }
        var state = read(tx)
        state.pending.removeAll { fileHashes.contains($0.fileHash) }
        write(state, tx)
    }

    /// Drop all pending ops (used on reset: the whole prior list is superseded).
    public func clearAllPending(_ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        guard !state.pending.isEmpty else { return }
        state.pending = []
        write(state, tx)
    }

    // MARK: GIPHY id index (local-only)

    public func isGiphyFavorited(_ giphyId: String, _ tx: SDSAnyReadTransaction) -> Bool {
        read(tx).giphyIndex[giphyId] != nil
    }

    /// The fileHash a GIPHY asset was stored under, if favorited on this device.
    public func fileHash(forGiphy giphyId: String, _ tx: SDSAnyReadTransaction) -> String? {
        read(tx).giphyIndex[giphyId]
    }

    /// The GIPHY asset id currently mapped to `fileHash` (reverse of the index) — lets a rollback
    /// restore the link that an optimistic unfavorite removed.
    public func giphyId(forFileHash fileHash: String, _ tx: SDSAnyReadTransaction) -> String? {
        read(tx).giphyIndex.first { $0.value == fileHash }?.key
    }

    /// The stored pointer for a favorited fileHash (confirmed or still pending) — for re-ordering
    /// an existing favorite without re-uploading.
    public func pointer(forFileHash fileHash: String, _ tx: SDSAnyReadTransaction) -> FavoriteAttachmentPointer? {
        let state = read(tx)
        if let record = state.confirmed.first(where: { $0.attachment.fileHash == fileHash }) {
            return record.attachment
        }
        return state.pending.first(where: { $0.fileHash == fileHash && $0.action == .favorite })?.pointer
    }

    /// The local WebP/GIF path for a pending (not-yet-uploaded) favorite, for offline display.
    public func localWebpPath(forFileHash fileHash: String, _ tx: SDSAnyReadTransaction) -> String? {
        read(tx).pending.first { $0.fileHash == fileHash && $0.action == .favorite }?.localWebpPath
    }

    public func linkGiphy(_ giphyId: String, fileHash: String, _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        state.giphyIndex[giphyId] = fileHash
        write(state, tx)
    }

    public func unlinkGiphy(fileHash: String, _ tx: SDSAnyWriteTransaction) {
        var state = read(tx)
        state.giphyIndex = state.giphyIndex.filter { $0.value != fileHash }
        write(state, tx)
    }

    // MARK: - Raw state

    private func read(_ tx: SDSAnyReadTransaction) -> LocalFavoritesState {
        guard let data = kv.getData(Self.stateKey, transaction: tx),
              let state = try? JSONDecoder().decode(LocalFavoritesState.self, from: data) else {
            return LocalFavoritesState()
        }
        return state
    }

    private func write(_ state: LocalFavoritesState, _ tx: SDSAnyWriteTransaction) {
        guard let data = try? JSONEncoder().encode(state) else {
            owsFailDebug("[GifFav] failed to encode local favorites state")
            return
        }
        kv.setData(data, key: Self.stateKey, transaction: tx)
    }
}
