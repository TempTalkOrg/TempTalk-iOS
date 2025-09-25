//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum IOSProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - IOSProtoBackupSnapshotBackupEntityType

@objc
public enum IOSProtoBackupSnapshotBackupEntityType: Int32 {
    case unknown = 0
    case migration = 1
    case thread = 2
    case interaction = 3
    case attachment = 4
}

private func IOSProtoBackupSnapshotBackupEntityTypeWrap(_ value: IOSProtos_BackupSnapshot.BackupEntity.TypeEnum) -> IOSProtoBackupSnapshotBackupEntityType {
    switch value {
    case .unknown: return .unknown
    case .migration: return .migration
    case .thread: return .thread
    case .interaction: return .interaction
    case .attachment: return .attachment
    }
}

private func IOSProtoBackupSnapshotBackupEntityTypeUnwrap(_ value: IOSProtoBackupSnapshotBackupEntityType) -> IOSProtos_BackupSnapshot.BackupEntity.TypeEnum {
    switch value {
    case .unknown: return .unknown
    case .migration: return .migration
    case .thread: return .thread
    case .interaction: return .interaction
    case .attachment: return .attachment
    }
}

// MARK: - IOSProtoBackupSnapshotBackupEntity

@objc
public class IOSProtoBackupSnapshotBackupEntity: NSObject, Codable, NSSecureCoding {

    // MARK: - IOSProtoBackupSnapshotBackupEntityBuilder

    @objc
    public static func builder() -> IOSProtoBackupSnapshotBackupEntityBuilder {
        return IOSProtoBackupSnapshotBackupEntityBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> IOSProtoBackupSnapshotBackupEntityBuilder {
        let builder = IOSProtoBackupSnapshotBackupEntityBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = entityData {
            builder.setEntityData(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class IOSProtoBackupSnapshotBackupEntityBuilder: NSObject {

        private var proto = IOSProtos_BackupSnapshot.BackupEntity()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: IOSProtoBackupSnapshotBackupEntityType) {
            proto.type = IOSProtoBackupSnapshotBackupEntityTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setEntityData(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.entityData = valueParam
        }

        public func setEntityData(_ valueParam: Data) {
            proto.entityData = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> IOSProtoBackupSnapshotBackupEntity {
            return try IOSProtoBackupSnapshotBackupEntity(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try IOSProtoBackupSnapshotBackupEntity(proto).serializedData()
        }
    }

    fileprivate let proto: IOSProtos_BackupSnapshot.BackupEntity

    public var type: IOSProtoBackupSnapshotBackupEntityType? {
        guard hasType else {
            return nil
        }
        return IOSProtoBackupSnapshotBackupEntityTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: IOSProtoBackupSnapshotBackupEntityType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: BackupEntity.type.")
        }
        return IOSProtoBackupSnapshotBackupEntityTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var entityData: Data? {
        guard hasEntityData else {
            return nil
        }
        return proto.entityData
    }
    @objc
    public var hasEntityData: Bool {
        return proto.hasEntityData
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: IOSProtos_BackupSnapshot.BackupEntity) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try IOSProtos_BackupSnapshot.BackupEntity(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: IOSProtos_BackupSnapshot.BackupEntity) throws {
        // MARK: - Begin Validation Logic for IOSProtoBackupSnapshotBackupEntity -

        // MARK: - End Validation Logic for IOSProtoBackupSnapshotBackupEntity -

        self.init(proto: proto)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public static var supportsSecureCoding: Bool { true }

    public required convenience init?(coder: NSCoder) {
        guard let serializedData = coder.decodeData() else { return nil }
        do {
            try self.init(serializedData: serializedData)
        } catch {
            owsFailDebug("Failed to decode serialized data \(error)")
            return nil
        }
    }

    public func encode(with coder: NSCoder) {
        do {
            coder.encode(try serializedData())
        } catch {
            owsFailDebug("Failed to encode serialized data \(error)")
        }
    }

    @objc
    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if TESTABLE_BUILD

extension IOSProtoBackupSnapshotBackupEntity {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension IOSProtoBackupSnapshotBackupEntity.IOSProtoBackupSnapshotBackupEntityBuilder {
    @objc
    public func buildIgnoringErrors() -> IOSProtoBackupSnapshotBackupEntity? {
        return try! self.build()
    }
}

#endif

// MARK: - IOSProtoBackupSnapshot

@objc
public class IOSProtoBackupSnapshot: NSObject, Codable, NSSecureCoding {

    // MARK: - IOSProtoBackupSnapshotBuilder

    @objc
    public static func builder() -> IOSProtoBackupSnapshotBuilder {
        return IOSProtoBackupSnapshotBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> IOSProtoBackupSnapshotBuilder {
        let builder = IOSProtoBackupSnapshotBuilder()
        builder.setEntity(entity)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class IOSProtoBackupSnapshotBuilder: NSObject {

        private var proto = IOSProtos_BackupSnapshot()

        @objc
        fileprivate override init() {}

        @objc
        public func addEntity(_ valueParam: IOSProtoBackupSnapshotBackupEntity) {
            proto.entity.append(valueParam.proto)
        }

        @objc
        public func setEntity(_ wrappedItems: [IOSProtoBackupSnapshotBackupEntity]) {
            proto.entity = wrappedItems.map { $0.proto }
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> IOSProtoBackupSnapshot {
            return try IOSProtoBackupSnapshot(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try IOSProtoBackupSnapshot(proto).serializedData()
        }
    }

    fileprivate let proto: IOSProtos_BackupSnapshot

    @objc
    public let entity: [IOSProtoBackupSnapshotBackupEntity]

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: IOSProtos_BackupSnapshot,
                 entity: [IOSProtoBackupSnapshotBackupEntity]) {
        self.proto = proto
        self.entity = entity
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try IOSProtos_BackupSnapshot(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: IOSProtos_BackupSnapshot) throws {
        var entity: [IOSProtoBackupSnapshotBackupEntity] = []
        entity = try proto.entity.map { try IOSProtoBackupSnapshotBackupEntity($0) }

        // MARK: - Begin Validation Logic for IOSProtoBackupSnapshot -

        // MARK: - End Validation Logic for IOSProtoBackupSnapshot -

        self.init(proto: proto,
                  entity: entity)
    }

    public required convenience init(from decoder: Swift.Decoder) throws {
        let singleValueContainer = try decoder.singleValueContainer()
        let serializedData = try singleValueContainer.decode(Data.self)
        try self.init(serializedData: serializedData)
    }
    public func encode(to encoder: Swift.Encoder) throws {
        var singleValueContainer = encoder.singleValueContainer()
        try singleValueContainer.encode(try serializedData())
    }

    public static var supportsSecureCoding: Bool { true }

    public required convenience init?(coder: NSCoder) {
        guard let serializedData = coder.decodeData() else { return nil }
        do {
            try self.init(serializedData: serializedData)
        } catch {
            owsFailDebug("Failed to decode serialized data \(error)")
            return nil
        }
    }

    public func encode(with coder: NSCoder) {
        do {
            coder.encode(try serializedData())
        } catch {
            owsFailDebug("Failed to encode serialized data \(error)")
        }
    }

    @objc
    public override var debugDescription: String {
        return "\(proto)"
    }
}

#if TESTABLE_BUILD

extension IOSProtoBackupSnapshot {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension IOSProtoBackupSnapshot.IOSProtoBackupSnapshotBuilder {
    @objc
    public func buildIgnoringErrors() -> IOSProtoBackupSnapshot? {
        return try! self.build()
    }
}

#endif
