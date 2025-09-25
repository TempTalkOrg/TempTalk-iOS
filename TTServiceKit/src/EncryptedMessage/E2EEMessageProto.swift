//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum E2EEMessageProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - E2EEMessageProtoContent

@objc
public class E2EEMessageProtoContent: NSObject, Codable, NSSecureCoding {

    // MARK: - E2EEMessageProtoContentBuilder

    @objc
    public static func builder() -> E2EEMessageProtoContentBuilder {
        return E2EEMessageProtoContentBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> E2EEMessageProtoContentBuilder {
        let builder = E2EEMessageProtoContentBuilder()
        if hasVersion {
            builder.setVersion(version)
        }
        if let _value = cipherText {
            builder.setCipherText(_value)
        }
        if let _value = signedEkey {
            builder.setSignedEkey(_value)
        }
        if let _value = eKey {
            builder.setEKey(_value)
        }
        if let _value = identityKey {
            builder.setIdentityKey(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class E2EEMessageProtoContentBuilder: NSObject {

        private var proto = E2EEMessageProtos_Content()

        @objc
        fileprivate override init() {}

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCipherText(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.cipherText = valueParam
        }

        public func setCipherText(_ valueParam: Data) {
            proto.cipherText = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSignedEkey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.signedEkey = valueParam
        }

        public func setSignedEkey(_ valueParam: Data) {
            proto.signedEkey = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setEKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.eKey = valueParam
        }

        public func setEKey(_ valueParam: Data) {
            proto.eKey = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setIdentityKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.identityKey = valueParam
        }

        public func setIdentityKey(_ valueParam: Data) {
            proto.identityKey = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> E2EEMessageProtoContent {
            return try E2EEMessageProtoContent(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try E2EEMessageProtoContent(proto).serializedData()
        }
    }

    fileprivate let proto: E2EEMessageProtos_Content

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    @objc
    public var cipherText: Data? {
        guard hasCipherText else {
            return nil
        }
        return proto.cipherText
    }
    @objc
    public var hasCipherText: Bool {
        return proto.hasCipherText
    }

    @objc
    public var signedEkey: Data? {
        guard hasSignedEkey else {
            return nil
        }
        return proto.signedEkey
    }
    @objc
    public var hasSignedEkey: Bool {
        return proto.hasSignedEkey
    }

    @objc
    public var eKey: Data? {
        guard hasEKey else {
            return nil
        }
        return proto.eKey
    }
    @objc
    public var hasEKey: Bool {
        return proto.hasEKey
    }

    @objc
    public var identityKey: Data? {
        guard hasIdentityKey else {
            return nil
        }
        return proto.identityKey
    }
    @objc
    public var hasIdentityKey: Bool {
        return proto.hasIdentityKey
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: E2EEMessageProtos_Content) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try E2EEMessageProtos_Content(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: E2EEMessageProtos_Content) throws {
        // MARK: - Begin Validation Logic for E2EEMessageProtoContent -

        // MARK: - End Validation Logic for E2EEMessageProtoContent -

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

extension E2EEMessageProtoContent {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension E2EEMessageProtoContent.E2EEMessageProtoContentBuilder {
    @objc
    public func buildIgnoringErrors() -> E2EEMessageProtoContent? {
        return try! self.build()
    }
}

#endif
