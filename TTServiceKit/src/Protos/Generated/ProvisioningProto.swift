//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum ProvisioningProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - ProvisioningProtoProvisionEnvelope

@objc
public class ProvisioningProtoProvisionEnvelope: NSObject, Codable, NSSecureCoding {

    // MARK: - ProvisioningProtoProvisionEnvelopeBuilder

    @objc
    public static func builder() -> ProvisioningProtoProvisionEnvelopeBuilder {
        return ProvisioningProtoProvisionEnvelopeBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> ProvisioningProtoProvisionEnvelopeBuilder {
        let builder = ProvisioningProtoProvisionEnvelopeBuilder()
        if let _value = publicKey {
            builder.setPublicKey(_value)
        }
        if let _value = body {
            builder.setBody(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class ProvisioningProtoProvisionEnvelopeBuilder: NSObject {

        private var proto = ProvisioningProtos_ProvisionEnvelope()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPublicKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.publicKey = valueParam
        }

        public func setPublicKey(_ valueParam: Data) {
            proto.publicKey = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBody(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.body = valueParam
        }

        public func setBody(_ valueParam: Data) {
            proto.body = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> ProvisioningProtoProvisionEnvelope {
            return try ProvisioningProtoProvisionEnvelope(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try ProvisioningProtoProvisionEnvelope(proto).serializedData()
        }
    }

    fileprivate let proto: ProvisioningProtos_ProvisionEnvelope

    @objc
    public var publicKey: Data? {
        guard hasPublicKey else {
            return nil
        }
        return proto.publicKey
    }
    @objc
    public var hasPublicKey: Bool {
        return proto.hasPublicKey
    }

    @objc
    public var body: Data? {
        guard hasBody else {
            return nil
        }
        return proto.body
    }
    @objc
    public var hasBody: Bool {
        return proto.hasBody
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: ProvisioningProtos_ProvisionEnvelope) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try ProvisioningProtos_ProvisionEnvelope(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: ProvisioningProtos_ProvisionEnvelope) throws {
        // MARK: - Begin Validation Logic for ProvisioningProtoProvisionEnvelope -

        // MARK: - End Validation Logic for ProvisioningProtoProvisionEnvelope -

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

extension ProvisioningProtoProvisionEnvelope {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension ProvisioningProtoProvisionEnvelope.ProvisioningProtoProvisionEnvelopeBuilder {
    @objc
    public func buildIgnoringErrors() -> ProvisioningProtoProvisionEnvelope? {
        return try! self.build()
    }
}

#endif

// MARK: - ProvisioningProtoProvisionMessage

@objc
public class ProvisioningProtoProvisionMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - ProvisioningProtoProvisionMessageBuilder

    @objc
    public static func builder() -> ProvisioningProtoProvisionMessageBuilder {
        return ProvisioningProtoProvisionMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> ProvisioningProtoProvisionMessageBuilder {
        let builder = ProvisioningProtoProvisionMessageBuilder()
        if let _value = identityKeyPublic {
            builder.setIdentityKeyPublic(_value)
        }
        if let _value = identityKeyPrivate {
            builder.setIdentityKeyPrivate(_value)
        }
        if let _value = number {
            builder.setNumber(_value)
        }
        if let _value = provisioningCode {
            builder.setProvisioningCode(_value)
        }
        if let _value = userAgent {
            builder.setUserAgent(_value)
        }
        if let _value = profileKey {
            builder.setProfileKey(_value)
        }
        if hasReadReceipts {
            builder.setReadReceipts(readReceipts)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class ProvisioningProtoProvisionMessageBuilder: NSObject {

        private var proto = ProvisioningProtos_ProvisionMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setIdentityKeyPublic(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.identityKeyPublic = valueParam
        }

        public func setIdentityKeyPublic(_ valueParam: Data) {
            proto.identityKeyPublic = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setIdentityKeyPrivate(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.identityKeyPrivate = valueParam
        }

        public func setIdentityKeyPrivate(_ valueParam: Data) {
            proto.identityKeyPrivate = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNumber(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.number = valueParam
        }

        public func setNumber(_ valueParam: String) {
            proto.number = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setProvisioningCode(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.provisioningCode = valueParam
        }

        public func setProvisioningCode(_ valueParam: String) {
            proto.provisioningCode = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setUserAgent(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.userAgent = valueParam
        }

        public func setUserAgent(_ valueParam: String) {
            proto.userAgent = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setProfileKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.profileKey = valueParam
        }

        public func setProfileKey(_ valueParam: Data) {
            proto.profileKey = valueParam
        }

        @objc
        public func setReadReceipts(_ valueParam: Bool) {
            proto.readReceipts = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> ProvisioningProtoProvisionMessage {
            return try ProvisioningProtoProvisionMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try ProvisioningProtoProvisionMessage(proto).serializedData()
        }
    }

    fileprivate let proto: ProvisioningProtos_ProvisionMessage

    @objc
    public var identityKeyPublic: Data? {
        guard hasIdentityKeyPublic else {
            return nil
        }
        return proto.identityKeyPublic
    }
    @objc
    public var hasIdentityKeyPublic: Bool {
        return proto.hasIdentityKeyPublic
    }

    @objc
    public var identityKeyPrivate: Data? {
        guard hasIdentityKeyPrivate else {
            return nil
        }
        return proto.identityKeyPrivate
    }
    @objc
    public var hasIdentityKeyPrivate: Bool {
        return proto.hasIdentityKeyPrivate
    }

    @objc
    public var number: String? {
        guard hasNumber else {
            return nil
        }
        return proto.number
    }
    @objc
    public var hasNumber: Bool {
        return proto.hasNumber
    }

    @objc
    public var provisioningCode: String? {
        guard hasProvisioningCode else {
            return nil
        }
        return proto.provisioningCode
    }
    @objc
    public var hasProvisioningCode: Bool {
        return proto.hasProvisioningCode
    }

    @objc
    public var userAgent: String? {
        guard hasUserAgent else {
            return nil
        }
        return proto.userAgent
    }
    @objc
    public var hasUserAgent: Bool {
        return proto.hasUserAgent
    }

    @objc
    public var profileKey: Data? {
        guard hasProfileKey else {
            return nil
        }
        return proto.profileKey
    }
    @objc
    public var hasProfileKey: Bool {
        return proto.hasProfileKey
    }

    @objc
    public var readReceipts: Bool {
        return proto.readReceipts
    }
    @objc
    public var hasReadReceipts: Bool {
        return proto.hasReadReceipts
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: ProvisioningProtos_ProvisionMessage) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try ProvisioningProtos_ProvisionMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: ProvisioningProtos_ProvisionMessage) throws {
        // MARK: - Begin Validation Logic for ProvisioningProtoProvisionMessage -

        // MARK: - End Validation Logic for ProvisioningProtoProvisionMessage -

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

extension ProvisioningProtoProvisionMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension ProvisioningProtoProvisionMessage.ProvisioningProtoProvisionMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> ProvisioningProtoProvisionMessage? {
        return try! self.build()
    }
}

#endif
