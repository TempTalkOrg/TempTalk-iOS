//
//  DTGifFavoriteModels.swift
//  TTServiceKit
//
//  Cross-platform GIF favorites contract (see ~/Desktop/cross-platform-alignment.md §2).
//  Field names/types must stay identical across iOS / Android / Mac.
//

import Foundation

// MARK: - Snowflake ID JSON coding

// authorizeId is a 19-digit snowflake (> 2^53). JSON has a single number type, so
// double-based parsers (JS / Electron, Swift JSONSerialization) round large integers
// and drop the low digits. Encode it as a string on the wire; decode string -> Int64
// while tolerating legacy blobs that still stored a raw number.
private extension KeyedEncodingContainer {
    mutating func encodeSnowflake(_ value: Int64, forKey key: Key) throws {
        try encode(String(value), forKey: key)
    }
}

private extension KeyedDecodingContainer {
    func decodeSnowflake(forKey key: Key) throws -> Int64 {
        if let string = try? decode(String.self, forKey: key), let value = Int64(string) {
            return value
        }
        return try decode(Int64.self, forKey: key)
    }
}

// MARK: - Action

public enum FavoriteAction: String, Codable {
    case favorite
    case unfavorite
    case rewrap   // v2: update only wrappedFavKey (identity rotation, old key still available); no CAS
    case reset    // v2: server unpins+GCs all prior assets, then pins items; new keyId/blob/wrappedFavKey; no CAS
}

// MARK: - Transport (server-visible)

/// Plaintext file info the server uses to pin/unpin assets.
public struct FavoriteItemMeta: Codable {
    public let attachmentId: String
    public let authorizeId: Int64
    public let fileHash: String

    public init(attachmentId: String, authorizeId: Int64, fileHash: String) {
        self.attachmentId = attachmentId
        self.authorizeId = authorizeId
        self.fileHash = fileHash
    }

    private enum CodingKeys: String, CodingKey {
        case attachmentId, authorizeId, fileHash
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attachmentId = try c.decode(String.self, forKey: .attachmentId)
        authorizeId = try c.decodeSnowflake(forKey: .authorizeId)
        fileHash = try c.decode(String.self, forKey: .fileHash)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(attachmentId, forKey: .attachmentId)
        try c.encodeSnowflake(authorizeId, forKey: .authorizeId)
        try c.encode(fileHash, forKey: .fileHash)
    }
}

/// GET response / PUT echo. Server stores ciphertext + non-key metadata only (zero-knowledge).
public struct FavoritesResponse: Codable {
    public let encVersion: Int
    public let listVersion: Int64
    public let keyId: String?          // favKey fingerprint (not the key); nil = never created
    public let blob: String?           // Base64(AES-256-GCM(favKey, list)); nil = empty
    public let wrappedFavKey: String?  // v2: favKey wrapped by the ACI-derived KEK; nil = never created

    private enum CodingKeys: String, CodingKey {
        case encVersion, listVersion, keyId, blob, wrappedFavKey
    }

    // Tolerate a server that omits encVersion/listVersion (e.g. an empty / never-created list)
    // rather than failing the whole decode.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        encVersion = try c.decodeIfPresent(Int.self, forKey: .encVersion) ?? 1
        listVersion = try c.decodeIfPresent(Int64.self, forKey: .listVersion) ?? 0
        keyId = try c.decodeIfPresent(String.self, forKey: .keyId)
        blob = try c.decodeIfPresent(String.self, forKey: .blob)
        wrappedFavKey = try c.decodeIfPresent(String.self, forKey: .wrappedFavKey)
    }
}

/// PUT body. Only `favorite`/`unfavorite` carry listVersion (CAS) + keyId + blob + items;
/// `rewrap` carries only `wrappedFavKey`. nil optionals are omitted by JSONEncoder.
public struct FavoritesPutRequest: Codable {
    public let encVersion: Int
    public let action: FavoriteAction
    public let listVersion: Int64?
    public let keyId: String?
    public let blob: String?
    public let items: [FavoriteItemMeta]?
    public let wrappedFavKey: String?

    public init(encVersion: Int = 1,
                action: FavoriteAction,
                listVersion: Int64? = nil,
                keyId: String? = nil,
                blob: String? = nil,
                items: [FavoriteItemMeta]? = nil,
                wrappedFavKey: String? = nil) {
        self.encVersion = encVersion
        self.action = action
        self.listVersion = listVersion
        self.keyId = keyId
        self.blob = blob
        self.items = items
        self.wrappedFavKey = wrappedFavKey
    }
}

// MARK: - Plaintext list (client-only, lives inside the encrypted blob)

/// Account-level encrypted attachment pointer. bytes fields are Base64 strings in JSON.
public struct FavoriteAttachmentPointer: Codable {
    public let id: String
    public let authorizeId: Int64
    public let key: String         // attachment decryption key, Base64
    public let digest: String      // cipherHash, Base64
    public let fileHash: String    // record primary key (content identity)
    public let contentType: String
    public let width: Int
    public let height: Int
    public let size: Int           // plaintext byte count (for cross-platform padding trim)

    private enum CodingKeys: String, CodingKey {
        case id, authorizeId, key, digest, fileHash, contentType, width, height, size
    }

    public init(id: String, authorizeId: Int64, key: String, digest: String,
                fileHash: String, contentType: String = "image/webp",
                width: Int, height: Int, size: Int) {
        self.id = id
        self.authorizeId = authorizeId
        self.key = key
        self.digest = digest
        self.fileHash = fileHash
        self.contentType = contentType
        self.width = width
        self.height = height
        self.size = size
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        authorizeId = try c.decodeSnowflake(forKey: .authorizeId)
        key = try c.decode(String.self, forKey: .key)
        digest = try c.decode(String.self, forKey: .digest)
        fileHash = try c.decode(String.self, forKey: .fileHash)
        contentType = try c.decodeIfPresent(String.self, forKey: .contentType) ?? "image/webp"
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        size = try c.decodeIfPresent(Int.self, forKey: .size) ?? 0   // tolerate legacy blobs
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeSnowflake(authorizeId, forKey: .authorizeId)
        try c.encode(key, forKey: .key)
        try c.encode(digest, forKey: .digest)
        try c.encode(fileHash, forKey: .fileHash)
        try c.encode(contentType, forKey: .contentType)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(size, forKey: .size)
    }
}

public struct FavoriteRecord: Codable {
    public let attachment: FavoriteAttachmentPointer
    /// Descending sort key = listVersion at insert time (server-arbitrated, clock-free).
    public let addedListVersion: Int64

    public init(attachment: FavoriteAttachmentPointer, addedListVersion: Int64) {
        self.attachment = attachment
        self.addedListVersion = addedListVersion
    }
}

/// The whole favorites list — only confirmed entries (optimistic pending stays out of the blob).
public struct FavoriteListPlain: Codable {
    public var records: [FavoriteRecord]

    public init(records: [FavoriteRecord] = []) {
        self.records = records
    }
}
