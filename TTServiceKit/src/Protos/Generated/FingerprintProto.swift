//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum FingerprintProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - FingerprintProtoLogicalFingerprint

@objc
public class FingerprintProtoLogicalFingerprint: NSObject, Codable, NSSecureCoding {

    // MARK: - FingerprintProtoLogicalFingerprintBuilder

    @objc
    public static func builder() -> FingerprintProtoLogicalFingerprintBuilder {
        return FingerprintProtoLogicalFingerprintBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> FingerprintProtoLogicalFingerprintBuilder {
        let builder = FingerprintProtoLogicalFingerprintBuilder()
        if let _value = identityData {
            builder.setIdentityData(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class FingerprintProtoLogicalFingerprintBuilder: NSObject {

        private var proto = FingerprintProtos_LogicalFingerprint()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setIdentityData(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.identityData = valueParam
        }

        public func setIdentityData(_ valueParam: Data) {
            proto.identityData = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> FingerprintProtoLogicalFingerprint {
            return try FingerprintProtoLogicalFingerprint(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try FingerprintProtoLogicalFingerprint(proto).serializedData()
        }
    }

    fileprivate let proto: FingerprintProtos_LogicalFingerprint

    @objc
    public var identityData: Data? {
        guard hasIdentityData else {
            return nil
        }
        return proto.identityData
    }
    @objc
    public var hasIdentityData: Bool {
        return proto.hasIdentityData
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: FingerprintProtos_LogicalFingerprint) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try FingerprintProtos_LogicalFingerprint(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: FingerprintProtos_LogicalFingerprint) throws {
        // MARK: - Begin Validation Logic for FingerprintProtoLogicalFingerprint -

        // MARK: - End Validation Logic for FingerprintProtoLogicalFingerprint -

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

extension FingerprintProtoLogicalFingerprint {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension FingerprintProtoLogicalFingerprint.FingerprintProtoLogicalFingerprintBuilder {
    @objc
    public func buildIgnoringErrors() -> FingerprintProtoLogicalFingerprint? {
        return try! self.build()
    }
}

#endif

// MARK: - FingerprintProtoLogicalFingerprints

@objc
public class FingerprintProtoLogicalFingerprints: NSObject, Codable, NSSecureCoding {

    // MARK: - FingerprintProtoLogicalFingerprintsBuilder

    @objc
    public static func builder() -> FingerprintProtoLogicalFingerprintsBuilder {
        return FingerprintProtoLogicalFingerprintsBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> FingerprintProtoLogicalFingerprintsBuilder {
        let builder = FingerprintProtoLogicalFingerprintsBuilder()
        if hasVersion {
            builder.setVersion(version)
        }
        if let _value = localFingerprint {
            builder.setLocalFingerprint(_value)
        }
        if let _value = remoteFingerprint {
            builder.setRemoteFingerprint(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class FingerprintProtoLogicalFingerprintsBuilder: NSObject {

        private var proto = FingerprintProtos_LogicalFingerprints()

        @objc
        fileprivate override init() {}

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLocalFingerprint(_ valueParam: FingerprintProtoLogicalFingerprint?) {
            guard let valueParam = valueParam else { return }
            proto.localFingerprint = valueParam.proto
        }

        public func setLocalFingerprint(_ valueParam: FingerprintProtoLogicalFingerprint) {
            proto.localFingerprint = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRemoteFingerprint(_ valueParam: FingerprintProtoLogicalFingerprint?) {
            guard let valueParam = valueParam else { return }
            proto.remoteFingerprint = valueParam.proto
        }

        public func setRemoteFingerprint(_ valueParam: FingerprintProtoLogicalFingerprint) {
            proto.remoteFingerprint = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> FingerprintProtoLogicalFingerprints {
            return try FingerprintProtoLogicalFingerprints(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try FingerprintProtoLogicalFingerprints(proto).serializedData()
        }
    }

    fileprivate let proto: FingerprintProtos_LogicalFingerprints

    @objc
    public let localFingerprint: FingerprintProtoLogicalFingerprint?

    @objc
    public let remoteFingerprint: FingerprintProtoLogicalFingerprint?

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: FingerprintProtos_LogicalFingerprints,
                 localFingerprint: FingerprintProtoLogicalFingerprint?,
                 remoteFingerprint: FingerprintProtoLogicalFingerprint?) {
        self.proto = proto
        self.localFingerprint = localFingerprint
        self.remoteFingerprint = remoteFingerprint
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try FingerprintProtos_LogicalFingerprints(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: FingerprintProtos_LogicalFingerprints) throws {
        var localFingerprint: FingerprintProtoLogicalFingerprint?
        if proto.hasLocalFingerprint {
            localFingerprint = try FingerprintProtoLogicalFingerprint(proto.localFingerprint)
        }

        var remoteFingerprint: FingerprintProtoLogicalFingerprint?
        if proto.hasRemoteFingerprint {
            remoteFingerprint = try FingerprintProtoLogicalFingerprint(proto.remoteFingerprint)
        }

        // MARK: - Begin Validation Logic for FingerprintProtoLogicalFingerprints -

        // MARK: - End Validation Logic for FingerprintProtoLogicalFingerprints -

        self.init(proto: proto,
                  localFingerprint: localFingerprint,
                  remoteFingerprint: remoteFingerprint)
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

extension FingerprintProtoLogicalFingerprints {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension FingerprintProtoLogicalFingerprints.FingerprintProtoLogicalFingerprintsBuilder {
    @objc
    public func buildIgnoringErrors() -> FingerprintProtoLogicalFingerprints? {
        return try! self.build()
    }
}

#endif
