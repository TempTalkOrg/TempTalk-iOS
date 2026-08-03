//
// Copyright 2024 Difft. All rights reserved.
//
// Persistent job record for a single GIF favorite mutation (add/remove).
// Uses `invisibleMessage` BLOB to store the serialized domain data and reuses the
// `threadId` column as the pending key (fileHash / temp key) for cheap dedup queries.
//

import Foundation
import GRDB

public final class DTGifFavoriteJobRecord: JobRecord {

    override public class var jobRecordType: JobRecordType { .gifFavoriteSend }

    // MARK: - Domain fields (decoded from invisibleMessage)

    /// Only `.favorite` / `.unfavorite` are ever scheduled here.
    public let op: FavoriteAction
    /// Optimistic pending key: temp key ("pending:<giphyId>") for a pre-upload panel add,
    /// or the real content fileHash for a message add / bump / unfavorite.
    public let fileHash: String
    /// Present when the pointer is already resolved (bump / already-on-server); nil otherwise.
    public let pointer: FavoriteAttachmentPointer?
    /// Local WebP awaiting upload (panel add) — also the loader's offline display fallback.
    public let localWebpPath: String?
    /// Message attachment uniqueId to re-resolve a server pointer from (message add).
    public let messageAttachmentId: String?
    /// GIPHY asset id for index relink / rollback (panel add / bump).
    public let giphyId: String?
    public let enqueuedAt: Int64

    // MARK: - Payload Codable (stored in invisibleMessage)

    private struct Payload: Codable {
        let op: FavoriteAction
        let fileHash: String
        let pointer: FavoriteAttachmentPointer?
        let localWebpPath: String?
        let messageAttachmentId: String?
        let giphyId: String?
        let enqueuedAt: Int64
    }

    // MARK: - Init (create new job)

    public init(
        op: FavoriteAction,
        fileHash: String,
        pointer: FavoriteAttachmentPointer? = nil,
        localWebpPath: String? = nil,
        messageAttachmentId: String? = nil,
        giphyId: String? = nil
    ) {
        self.op = op
        self.fileHash = fileHash
        self.pointer = pointer
        self.localWebpPath = localWebpPath
        self.messageAttachmentId = messageAttachmentId
        self.giphyId = giphyId
        self.enqueuedAt = Int64(NSDate.ows_millisecondTimeStamp())

        guard let payloadData = try? JSONEncoder().encode(Payload(
            op: op,
            fileHash: fileHash,
            pointer: pointer,
            localWebpPath: localWebpPath,
            messageAttachmentId: messageAttachmentId,
            giphyId: giphyId,
            enqueuedAt: enqueuedAt
        )) else {
            owsFail("Failed to encode DTGifFavoriteJobRecord payload")
        }

        // fileHash lives in `threadId` so duplicate pending jobs can be pruned with a column filter.
        super.init(
            failureCount: 0,
            status: .ready,
            invisibleMessage: payloadData,
            threadId: fileHash
        )
    }

    // MARK: - InheritableRecord (decode from DB)

    required init(inheritableDecoder decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let data = try container.decodeIfPresent(Data.self, forKey: .invisibleMessage) else {
            throw OWSGenericError("DTGifFavoriteJobRecord missing invisibleMessage")
        }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        self.op = p.op
        self.fileHash = p.fileHash
        self.pointer = p.pointer
        self.localWebpPath = p.localWebpPath
        self.messageAttachmentId = p.messageAttachmentId
        self.giphyId = p.giphyId
        self.enqueuedAt = p.enqueuedAt

        try super.init(inheritableDecoder: decoder)
    }
}
