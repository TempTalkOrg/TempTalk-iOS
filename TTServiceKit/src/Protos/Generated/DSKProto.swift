//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import SwiftProtobuf

// WARNING: This code is generated. Only edit within the markers.

public enum DSKProtoError: Error {
    case invalidProtobuf(description: String)
}

// MARK: - DSKProtoConversationMsgInfo

@objc
public class DSKProtoConversationMsgInfo: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoConversationMsgInfoBuilder

    @objc
    public static func builder() -> DSKProtoConversationMsgInfoBuilder {
        return DSKProtoConversationMsgInfoBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoConversationMsgInfoBuilder {
        let builder = DSKProtoConversationMsgInfoBuilder()
        if let _value = conversationPreview {
            builder.setConversationPreview(_value)
        }
        if hasOldestMsgSid {
            builder.setOldestMsgSid(oldestMsgSid)
        }
        if hasOldestMsgNsID {
            builder.setOldestMsgNsID(oldestMsgNsID)
        }
        if hasLastestMsgSid {
            builder.setLastestMsgSid(lastestMsgSid)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoConversationMsgInfoBuilder: NSObject {

        private var proto = DifftServiceProtos_ConversationMsgInfo()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationPreview(_ valueParam: DSKProtoConversationPreview?) {
            guard let valueParam = valueParam else { return }
            proto.conversationPreview = valueParam.proto
        }

        public func setConversationPreview(_ valueParam: DSKProtoConversationPreview) {
            proto.conversationPreview = valueParam.proto
        }

        @objc
        public func setOldestMsgSid(_ valueParam: UInt64) {
            proto.oldestMsgSid = valueParam
        }

        @objc
        public func setOldestMsgNsID(_ valueParam: UInt64) {
            proto.oldestMsgNsID = valueParam
        }

        @objc
        public func setLastestMsgSid(_ valueParam: UInt64) {
            proto.lastestMsgSid = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoConversationMsgInfo {
            return try DSKProtoConversationMsgInfo(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoConversationMsgInfo(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ConversationMsgInfo

    @objc
    public let conversationPreview: DSKProtoConversationPreview?

    @objc
    public var oldestMsgSid: UInt64 {
        return proto.oldestMsgSid
    }
    @objc
    public var hasOldestMsgSid: Bool {
        return proto.hasOldestMsgSid
    }

    @objc
    public var oldestMsgNsID: UInt64 {
        return proto.oldestMsgNsID
    }
    @objc
    public var hasOldestMsgNsID: Bool {
        return proto.hasOldestMsgNsID
    }

    @objc
    public var lastestMsgSid: UInt64 {
        return proto.lastestMsgSid
    }
    @objc
    public var hasLastestMsgSid: Bool {
        return proto.hasLastestMsgSid
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ConversationMsgInfo,
                 conversationPreview: DSKProtoConversationPreview?) {
        self.proto = proto
        self.conversationPreview = conversationPreview
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ConversationMsgInfo(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ConversationMsgInfo) throws {
        var conversationPreview: DSKProtoConversationPreview?
        if proto.hasConversationPreview {
            conversationPreview = try DSKProtoConversationPreview(proto.conversationPreview)
        }

        // MARK: - Begin Validation Logic for DSKProtoConversationMsgInfo -

        // MARK: - End Validation Logic for DSKProtoConversationMsgInfo -

        self.init(proto: proto,
                  conversationPreview: conversationPreview)
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

extension DSKProtoConversationMsgInfo {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoConversationMsgInfo.DSKProtoConversationMsgInfoBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoConversationMsgInfo? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoConversationPreview

@objc
public class DSKProtoConversationPreview: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoConversationPreviewBuilder

    @objc
    public static func builder() -> DSKProtoConversationPreviewBuilder {
        return DSKProtoConversationPreviewBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoConversationPreviewBuilder {
        let builder = DSKProtoConversationPreviewBuilder()
        if let _value = conversationID {
            builder.setConversationID(_value)
        }
        if let _value = readPosition {
            builder.setReadPosition(_value)
        }
        if hasUnreadCorrection {
            builder.setUnreadCorrection(unreadCorrection)
        }
        if let _value = lastestMsg {
            builder.setLastestMsg(_value)
        }
        builder.setOnePageMsgs(onePageMsgs)
        if hasLastestMsgNsID {
            builder.setLastestMsgNsID(lastestMsgNsID)
        }
        if hasMaxOutgoingNsID {
            builder.setMaxOutgoingNsID(maxOutgoingNsID)
        }
        if hasMaxOutgoingSid {
            builder.setMaxOutgoingSid(maxOutgoingSid)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoConversationPreviewBuilder: NSObject {

        private var proto = DifftServiceProtos_ConversationPreview()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationID(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversationID = valueParam.proto
        }

        public func setConversationID(_ valueParam: DSKProtoConversationId) {
            proto.conversationID = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReadPosition(_ valueParam: DSKProtoReadPosition?) {
            guard let valueParam = valueParam else { return }
            proto.readPosition = valueParam.proto
        }

        public func setReadPosition(_ valueParam: DSKProtoReadPosition) {
            proto.readPosition = valueParam.proto
        }

        @objc
        public func setUnreadCorrection(_ valueParam: UInt32) {
            proto.unreadCorrection = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLastestMsg(_ valueParam: DSKProtoEnvelope?) {
            guard let valueParam = valueParam else { return }
            proto.lastestMsg = valueParam.proto
        }

        public func setLastestMsg(_ valueParam: DSKProtoEnvelope) {
            proto.lastestMsg = valueParam.proto
        }

        @objc
        public func addOnePageMsgs(_ valueParam: DSKProtoEnvelope) {
            proto.onePageMsgs.append(valueParam.proto)
        }

        @objc
        public func setOnePageMsgs(_ wrappedItems: [DSKProtoEnvelope]) {
            proto.onePageMsgs = wrappedItems.map { $0.proto }
        }

        @objc
        public func setLastestMsgNsID(_ valueParam: UInt64) {
            proto.lastestMsgNsID = valueParam
        }

        @objc
        public func setMaxOutgoingNsID(_ valueParam: UInt64) {
            proto.maxOutgoingNsID = valueParam
        }

        @objc
        public func setMaxOutgoingSid(_ valueParam: UInt64) {
            proto.maxOutgoingSid = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoConversationPreview {
            return try DSKProtoConversationPreview(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoConversationPreview(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ConversationPreview

    @objc
    public let conversationID: DSKProtoConversationId?

    @objc
    public let readPosition: DSKProtoReadPosition?

    @objc
    public let lastestMsg: DSKProtoEnvelope?

    @objc
    public let onePageMsgs: [DSKProtoEnvelope]

    @objc
    public var unreadCorrection: UInt32 {
        return proto.unreadCorrection
    }
    @objc
    public var hasUnreadCorrection: Bool {
        return proto.hasUnreadCorrection
    }

    @objc
    public var lastestMsgNsID: UInt64 {
        return proto.lastestMsgNsID
    }
    @objc
    public var hasLastestMsgNsID: Bool {
        return proto.hasLastestMsgNsID
    }

    @objc
    public var maxOutgoingNsID: UInt64 {
        return proto.maxOutgoingNsID
    }
    @objc
    public var hasMaxOutgoingNsID: Bool {
        return proto.hasMaxOutgoingNsID
    }

    @objc
    public var maxOutgoingSid: UInt64 {
        return proto.maxOutgoingSid
    }
    @objc
    public var hasMaxOutgoingSid: Bool {
        return proto.hasMaxOutgoingSid
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ConversationPreview,
                 conversationID: DSKProtoConversationId?,
                 readPosition: DSKProtoReadPosition?,
                 lastestMsg: DSKProtoEnvelope?,
                 onePageMsgs: [DSKProtoEnvelope]) {
        self.proto = proto
        self.conversationID = conversationID
        self.readPosition = readPosition
        self.lastestMsg = lastestMsg
        self.onePageMsgs = onePageMsgs
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ConversationPreview(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ConversationPreview) throws {
        var conversationID: DSKProtoConversationId?
        if proto.hasConversationID {
            conversationID = try DSKProtoConversationId(proto.conversationID)
        }

        var readPosition: DSKProtoReadPosition?
        if proto.hasReadPosition {
            readPosition = try DSKProtoReadPosition(proto.readPosition)
        }

        var lastestMsg: DSKProtoEnvelope?
        if proto.hasLastestMsg {
            lastestMsg = try DSKProtoEnvelope(proto.lastestMsg)
        }

        var onePageMsgs: [DSKProtoEnvelope] = []
        onePageMsgs = try proto.onePageMsgs.map { try DSKProtoEnvelope($0) }

        // MARK: - Begin Validation Logic for DSKProtoConversationPreview -

        // MARK: - End Validation Logic for DSKProtoConversationPreview -

        self.init(proto: proto,
                  conversationID: conversationID,
                  readPosition: readPosition,
                  lastestMsg: lastestMsg,
                  onePageMsgs: onePageMsgs)
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

extension DSKProtoConversationPreview {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoConversationPreview.DSKProtoConversationPreviewBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoConversationPreview? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoConversationId

@objc
public class DSKProtoConversationId: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoConversationIdBuilder

    @objc
    public static func builder() -> DSKProtoConversationIdBuilder {
        return DSKProtoConversationIdBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoConversationIdBuilder {
        let builder = DSKProtoConversationIdBuilder()
        if let _value = number {
            builder.setNumber(_value)
        }
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoConversationIdBuilder: NSObject {

        private var proto = DifftServiceProtos_ConversationId()

        @objc
        fileprivate override init() {}

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
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoConversationId {
            return try DSKProtoConversationId(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoConversationId(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ConversationId

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
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ConversationId) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ConversationId(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ConversationId) throws {
        // MARK: - Begin Validation Logic for DSKProtoConversationId -

        // MARK: - End Validation Logic for DSKProtoConversationId -

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

extension DSKProtoConversationId {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoConversationId.DSKProtoConversationIdBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoConversationId? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoEnvelopeType

@objc
public enum DSKProtoEnvelopeType: Int32 {
    case unknown = 0
    case ciphertext = 1
    case keyExchange = 2
    case prekeyBundle = 3
    case receipt = 5
    case notify = 6
    case plaintext = 7
    case etoee = 8
}

private func DSKProtoEnvelopeTypeWrap(_ value: DifftServiceProtos_Envelope.TypeEnum) -> DSKProtoEnvelopeType {
    switch value {
    case .unknown: return .unknown
    case .ciphertext: return .ciphertext
    case .keyExchange: return .keyExchange
    case .prekeyBundle: return .prekeyBundle
    case .receipt: return .receipt
    case .notify: return .notify
    case .plaintext: return .plaintext
    case .etoee: return .etoee
    }
}

private func DSKProtoEnvelopeTypeUnwrap(_ value: DSKProtoEnvelopeType) -> DifftServiceProtos_Envelope.TypeEnum {
    switch value {
    case .unknown: return .unknown
    case .ciphertext: return .ciphertext
    case .keyExchange: return .keyExchange
    case .prekeyBundle: return .prekeyBundle
    case .receipt: return .receipt
    case .notify: return .notify
    case .plaintext: return .plaintext
    case .etoee: return .etoee
    }
}

// MARK: - DSKProtoEnvelopeMsgType

@objc
public enum DSKProtoEnvelopeMsgType: Int32 {
    case msgUnknown = 0
    case msgNormal = 1
    case msgSync = 2
    case msgReadReceipt = 3
    case msgSyncReadReceipt = 4
    case msgDeliveryReceipt = 5
    case msgNotify = 6
    case msgRecall = 7
    case msgRecalled = 8
    case msgSyncPreviewable = 9
    case msgClientNotify = 10
    case msgScheduleNormal = 11
    case msgEncCall = 12
}

private func DSKProtoEnvelopeMsgTypeWrap(_ value: DifftServiceProtos_Envelope.MsgType) -> DSKProtoEnvelopeMsgType {
    switch value {
    case .msgUnknown: return .msgUnknown
    case .msgNormal: return .msgNormal
    case .msgSync: return .msgSync
    case .msgReadReceipt: return .msgReadReceipt
    case .msgSyncReadReceipt: return .msgSyncReadReceipt
    case .msgDeliveryReceipt: return .msgDeliveryReceipt
    case .msgNotify: return .msgNotify
    case .msgRecall: return .msgRecall
    case .msgRecalled: return .msgRecalled
    case .msgSyncPreviewable: return .msgSyncPreviewable
    case .msgClientNotify: return .msgClientNotify
    case .msgScheduleNormal: return .msgScheduleNormal
    case .msgEncCall: return .msgEncCall
    }
}

private func DSKProtoEnvelopeMsgTypeUnwrap(_ value: DSKProtoEnvelopeMsgType) -> DifftServiceProtos_Envelope.MsgType {
    switch value {
    case .msgUnknown: return .msgUnknown
    case .msgNormal: return .msgNormal
    case .msgSync: return .msgSync
    case .msgReadReceipt: return .msgReadReceipt
    case .msgSyncReadReceipt: return .msgSyncReadReceipt
    case .msgDeliveryReceipt: return .msgDeliveryReceipt
    case .msgNotify: return .msgNotify
    case .msgRecall: return .msgRecall
    case .msgRecalled: return .msgRecalled
    case .msgSyncPreviewable: return .msgSyncPreviewable
    case .msgClientNotify: return .msgClientNotify
    case .msgScheduleNormal: return .msgScheduleNormal
    case .msgEncCall: return .msgEncCall
    }
}

// MARK: - DSKProtoEnvelopeCriticalLevel

@objc
public enum DSKProtoEnvelopeCriticalLevel: Int32 {
    case levelUnknown = 0
    case levelCritical = 1000
}

private func DSKProtoEnvelopeCriticalLevelWrap(_ value: DifftServiceProtos_Envelope.CriticalLevel) -> DSKProtoEnvelopeCriticalLevel {
    switch value {
    case .levelUnknown: return .levelUnknown
    case .levelCritical: return .levelCritical
    }
}

private func DSKProtoEnvelopeCriticalLevelUnwrap(_ value: DSKProtoEnvelopeCriticalLevel) -> DifftServiceProtos_Envelope.CriticalLevel {
    switch value {
    case .levelUnknown: return .levelUnknown
    case .levelCritical: return .levelCritical
    }
}

// MARK: - DSKProtoEnvelope

@objc
public class DSKProtoEnvelope: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoEnvelopeBuilder

    @objc
    public static func builder() -> DSKProtoEnvelopeBuilder {
        return DSKProtoEnvelopeBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoEnvelopeBuilder {
        let builder = DSKProtoEnvelopeBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = source {
            builder.setSource(_value)
        }
        if hasSourceDevice {
            builder.setSourceDevice(sourceDevice)
        }
        if let _value = relay {
            builder.setRelay(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = legacyMessage {
            builder.setLegacyMessage(_value)
        }
        if let _value = content {
            builder.setContent(_value)
        }
        if hasLastestMsgFlag {
            builder.setLastestMsgFlag(lastestMsgFlag)
        }
        if hasSequenceID {
            builder.setSequenceID(sequenceID)
        }
        if hasSystemShowTimestamp {
            builder.setSystemShowTimestamp(systemShowTimestamp)
        }
        if let _value = msgType {
            builder.setMsgType(_value)
        }
        if hasNotifySequenceID {
            builder.setNotifySequenceID(notifySequenceID)
        }
        if let _value = identityKey {
            builder.setIdentityKey(_value)
        }
        if let _value = peerContext {
            builder.setPeerContext(_value)
        }
        if let _value = msgExtra {
            builder.setMsgExtra(_value)
        }
        if let _value = criticalLevel {
            builder.setCriticalLevel(_value)
        }
        if hasPushTimestamp {
            builder.setPushTimestamp(pushTimestamp)
        }
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoEnvelopeBuilder: NSObject {

        private var proto = DifftServiceProtos_Envelope()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoEnvelopeType) {
            proto.type = DSKProtoEnvelopeTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam
        }

        public func setSource(_ valueParam: String) {
            proto.source = valueParam
        }

        @objc
        public func setSourceDevice(_ valueParam: UInt32) {
            proto.sourceDevice = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRelay(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.relay = valueParam
        }

        public func setRelay(_ valueParam: String) {
            proto.relay = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLegacyMessage(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.legacyMessage = valueParam
        }

        public func setLegacyMessage(_ valueParam: Data) {
            proto.legacyMessage = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContent(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.content = valueParam
        }

        public func setContent(_ valueParam: Data) {
            proto.content = valueParam
        }

        @objc
        public func setLastestMsgFlag(_ valueParam: Bool) {
            proto.lastestMsgFlag = valueParam
        }

        @objc
        public func setSequenceID(_ valueParam: UInt64) {
            proto.sequenceID = valueParam
        }

        @objc
        public func setSystemShowTimestamp(_ valueParam: UInt64) {
            proto.systemShowTimestamp = valueParam
        }

        @objc
        public func setMsgType(_ valueParam: DSKProtoEnvelopeMsgType) {
            proto.msgType = DSKProtoEnvelopeMsgTypeUnwrap(valueParam)
        }

        @objc
        public func setNotifySequenceID(_ valueParam: UInt64) {
            proto.notifySequenceID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setIdentityKey(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.identityKey = valueParam
        }

        public func setIdentityKey(_ valueParam: String) {
            proto.identityKey = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPeerContext(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.peerContext = valueParam
        }

        public func setPeerContext(_ valueParam: String) {
            proto.peerContext = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMsgExtra(_ valueParam: DSKProtoMsgExtra?) {
            guard let valueParam = valueParam else { return }
            proto.msgExtra = valueParam.proto
        }

        public func setMsgExtra(_ valueParam: DSKProtoMsgExtra) {
            proto.msgExtra = valueParam.proto
        }

        @objc
        public func setCriticalLevel(_ valueParam: DSKProtoEnvelopeCriticalLevel) {
            proto.criticalLevel = DSKProtoEnvelopeCriticalLevelUnwrap(valueParam)
        }

        @objc
        public func setPushTimestamp(_ valueParam: UInt64) {
            proto.pushTimestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoEnvelope {
            return try DSKProtoEnvelope(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoEnvelope(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_Envelope

    @objc
    public let msgExtra: DSKProtoMsgExtra?

    public var type: DSKProtoEnvelopeType? {
        guard hasType else {
            return nil
        }
        return DSKProtoEnvelopeTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoEnvelopeType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Envelope.type.")
        }
        return DSKProtoEnvelopeTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var source: String? {
        guard hasSource else {
            return nil
        }
        return proto.source
    }
    @objc
    public var hasSource: Bool {
        return proto.hasSource
    }

    @objc
    public var sourceDevice: UInt32 {
        return proto.sourceDevice
    }
    @objc
    public var hasSourceDevice: Bool {
        return proto.hasSourceDevice
    }

    @objc
    public var relay: String? {
        guard hasRelay else {
            return nil
        }
        return proto.relay
    }
    @objc
    public var hasRelay: Bool {
        return proto.hasRelay
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var legacyMessage: Data? {
        guard hasLegacyMessage else {
            return nil
        }
        return proto.legacyMessage
    }
    @objc
    public var hasLegacyMessage: Bool {
        return proto.hasLegacyMessage
    }

    @objc
    public var content: Data? {
        guard hasContent else {
            return nil
        }
        return proto.content
    }
    @objc
    public var hasContent: Bool {
        return proto.hasContent
    }

    @objc
    public var lastestMsgFlag: Bool {
        return proto.lastestMsgFlag
    }
    @objc
    public var hasLastestMsgFlag: Bool {
        return proto.hasLastestMsgFlag
    }

    @objc
    public var sequenceID: UInt64 {
        return proto.sequenceID
    }
    @objc
    public var hasSequenceID: Bool {
        return proto.hasSequenceID
    }

    @objc
    public var systemShowTimestamp: UInt64 {
        return proto.systemShowTimestamp
    }
    @objc
    public var hasSystemShowTimestamp: Bool {
        return proto.hasSystemShowTimestamp
    }

    public var msgType: DSKProtoEnvelopeMsgType? {
        guard hasMsgType else {
            return nil
        }
        return DSKProtoEnvelopeMsgTypeWrap(proto.msgType)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedMsgType: DSKProtoEnvelopeMsgType {
        if !hasMsgType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Envelope.msgType.")
        }
        return DSKProtoEnvelopeMsgTypeWrap(proto.msgType)
    }
    @objc
    public var hasMsgType: Bool {
        return proto.hasMsgType
    }

    @objc
    public var notifySequenceID: UInt64 {
        return proto.notifySequenceID
    }
    @objc
    public var hasNotifySequenceID: Bool {
        return proto.hasNotifySequenceID
    }

    @objc
    public var identityKey: String? {
        guard hasIdentityKey else {
            return nil
        }
        return proto.identityKey
    }
    @objc
    public var hasIdentityKey: Bool {
        return proto.hasIdentityKey
    }

    @objc
    public var peerContext: String? {
        guard hasPeerContext else {
            return nil
        }
        return proto.peerContext
    }
    @objc
    public var hasPeerContext: Bool {
        return proto.hasPeerContext
    }

    public var criticalLevel: DSKProtoEnvelopeCriticalLevel? {
        guard hasCriticalLevel else {
            return nil
        }
        return DSKProtoEnvelopeCriticalLevelWrap(proto.criticalLevel)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedCriticalLevel: DSKProtoEnvelopeCriticalLevel {
        if !hasCriticalLevel {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Envelope.criticalLevel.")
        }
        return DSKProtoEnvelopeCriticalLevelWrap(proto.criticalLevel)
    }
    @objc
    public var hasCriticalLevel: Bool {
        return proto.hasCriticalLevel
    }

    @objc
    public var pushTimestamp: UInt64 {
        return proto.pushTimestamp
    }
    @objc
    public var hasPushTimestamp: Bool {
        return proto.hasPushTimestamp
    }

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_Envelope,
                 msgExtra: DSKProtoMsgExtra?) {
        self.proto = proto
        self.msgExtra = msgExtra
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_Envelope(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_Envelope) throws {
        var msgExtra: DSKProtoMsgExtra?
        if proto.hasMsgExtra {
            msgExtra = try DSKProtoMsgExtra(proto.msgExtra)
        }

        // MARK: - Begin Validation Logic for DSKProtoEnvelope -

        // MARK: - End Validation Logic for DSKProtoEnvelope -

        self.init(proto: proto,
                  msgExtra: msgExtra)
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

extension DSKProtoEnvelope {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoEnvelope.DSKProtoEnvelopeBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoEnvelope? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoContent

@objc
public class DSKProtoContent: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoContentBuilder

    @objc
    public static func builder() -> DSKProtoContentBuilder {
        return DSKProtoContentBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoContentBuilder {
        let builder = DSKProtoContentBuilder()
        if let _value = dataMessage {
            builder.setDataMessage(_value)
        }
        if let _value = syncMessage {
            builder.setSyncMessage(_value)
        }
        if let _value = nullMessage {
            builder.setNullMessage(_value)
        }
        if let _value = receiptMessage {
            builder.setReceiptMessage(_value)
        }
        if let _value = typingMessage {
            builder.setTypingMessage(_value)
        }
        if let _value = notifyMessage {
            builder.setNotifyMessage(_value)
        }
        if let _value = callMessage {
            builder.setCallMessage(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoContentBuilder: NSObject {

        private var proto = DifftServiceProtos_Content()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setDataMessage(_ valueParam: DSKProtoDataMessage?) {
            guard let valueParam = valueParam else { return }
            proto.dataMessage = valueParam.proto
        }

        public func setDataMessage(_ valueParam: DSKProtoDataMessage) {
            proto.dataMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSyncMessage(_ valueParam: DSKProtoSyncMessage?) {
            guard let valueParam = valueParam else { return }
            proto.syncMessage = valueParam.proto
        }

        public func setSyncMessage(_ valueParam: DSKProtoSyncMessage) {
            proto.syncMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNullMessage(_ valueParam: DSKProtoNullMessage?) {
            guard let valueParam = valueParam else { return }
            proto.nullMessage = valueParam.proto
        }

        public func setNullMessage(_ valueParam: DSKProtoNullMessage) {
            proto.nullMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReceiptMessage(_ valueParam: DSKProtoReceiptMessage?) {
            guard let valueParam = valueParam else { return }
            proto.receiptMessage = valueParam.proto
        }

        public func setReceiptMessage(_ valueParam: DSKProtoReceiptMessage) {
            proto.receiptMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTypingMessage(_ valueParam: DSKProtoTypingMessage?) {
            guard let valueParam = valueParam else { return }
            proto.typingMessage = valueParam.proto
        }

        public func setTypingMessage(_ valueParam: DSKProtoTypingMessage) {
            proto.typingMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNotifyMessage(_ valueParam: DSKProtoNotifyMessage?) {
            guard let valueParam = valueParam else { return }
            proto.notifyMessage = valueParam.proto
        }

        public func setNotifyMessage(_ valueParam: DSKProtoNotifyMessage) {
            proto.notifyMessage = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCallMessage(_ valueParam: DSKProtoCallMessage?) {
            guard let valueParam = valueParam else { return }
            proto.callMessage = valueParam.proto
        }

        public func setCallMessage(_ valueParam: DSKProtoCallMessage) {
            proto.callMessage = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoContent {
            return try DSKProtoContent(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoContent(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_Content

    @objc
    public let dataMessage: DSKProtoDataMessage?

    @objc
    public let syncMessage: DSKProtoSyncMessage?

    @objc
    public let nullMessage: DSKProtoNullMessage?

    @objc
    public let receiptMessage: DSKProtoReceiptMessage?

    @objc
    public let typingMessage: DSKProtoTypingMessage?

    @objc
    public let notifyMessage: DSKProtoNotifyMessage?

    @objc
    public let callMessage: DSKProtoCallMessage?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_Content,
                 dataMessage: DSKProtoDataMessage?,
                 syncMessage: DSKProtoSyncMessage?,
                 nullMessage: DSKProtoNullMessage?,
                 receiptMessage: DSKProtoReceiptMessage?,
                 typingMessage: DSKProtoTypingMessage?,
                 notifyMessage: DSKProtoNotifyMessage?,
                 callMessage: DSKProtoCallMessage?) {
        self.proto = proto
        self.dataMessage = dataMessage
        self.syncMessage = syncMessage
        self.nullMessage = nullMessage
        self.receiptMessage = receiptMessage
        self.typingMessage = typingMessage
        self.notifyMessage = notifyMessage
        self.callMessage = callMessage
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_Content(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_Content) throws {
        var dataMessage: DSKProtoDataMessage?
        if proto.hasDataMessage {
            dataMessage = try DSKProtoDataMessage(proto.dataMessage)
        }

        var syncMessage: DSKProtoSyncMessage?
        if proto.hasSyncMessage {
            syncMessage = try DSKProtoSyncMessage(proto.syncMessage)
        }

        var nullMessage: DSKProtoNullMessage?
        if proto.hasNullMessage {
            nullMessage = try DSKProtoNullMessage(proto.nullMessage)
        }

        var receiptMessage: DSKProtoReceiptMessage?
        if proto.hasReceiptMessage {
            receiptMessage = try DSKProtoReceiptMessage(proto.receiptMessage)
        }

        var typingMessage: DSKProtoTypingMessage?
        if proto.hasTypingMessage {
            typingMessage = try DSKProtoTypingMessage(proto.typingMessage)
        }

        var notifyMessage: DSKProtoNotifyMessage?
        if proto.hasNotifyMessage {
            notifyMessage = try DSKProtoNotifyMessage(proto.notifyMessage)
        }

        var callMessage: DSKProtoCallMessage?
        if proto.hasCallMessage {
            callMessage = try DSKProtoCallMessage(proto.callMessage)
        }

        // MARK: - Begin Validation Logic for DSKProtoContent -

        // MARK: - End Validation Logic for DSKProtoContent -

        self.init(proto: proto,
                  dataMessage: dataMessage,
                  syncMessage: syncMessage,
                  nullMessage: nullMessage,
                  receiptMessage: receiptMessage,
                  typingMessage: typingMessage,
                  notifyMessage: notifyMessage,
                  callMessage: callMessage)
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

extension DSKProtoContent {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoContent.DSKProtoContentBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoContent? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessageCalling

@objc
public class DSKProtoCallMessageCalling: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageCallingBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageCallingBuilder {
        return DSKProtoCallMessageCallingBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageCallingBuilder {
        let builder = DSKProtoCallMessageCallingBuilder()
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = conversationID {
            builder.setConversationID(_value)
        }
        if let _value = roomName {
            builder.setRoomName(_value)
        }
        if let _value = caller {
            builder.setCaller(_value)
        }
        if let _value = emk {
            builder.setEmk(_value)
        }
        if let _value = publicKey {
            builder.setPublicKey(_value)
        }
        if hasCreateCallMsg {
            builder.setCreateCallMsg(createCallMsg)
        }
        if let _value = controlType {
            builder.setControlType(_value)
        }
        builder.setCallees(callees)
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageCallingBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage.Calling()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationID(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversationID = valueParam.proto
        }

        public func setConversationID(_ valueParam: DSKProtoConversationId) {
            proto.conversationID = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomName = valueParam
        }

        public func setRoomName(_ valueParam: String) {
            proto.roomName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCaller(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.caller = valueParam
        }

        public func setCaller(_ valueParam: String) {
            proto.caller = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setEmk(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.emk = valueParam
        }

        public func setEmk(_ valueParam: Data) {
            proto.emk = valueParam
        }

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
        public func setCreateCallMsg(_ valueParam: Bool) {
            proto.createCallMsg = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setControlType(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.controlType = valueParam
        }

        public func setControlType(_ valueParam: String) {
            proto.controlType = valueParam
        }

        @objc
        public func addCallees(_ valueParam: String) {
            proto.callees.append(valueParam)
        }

        @objc
        public func setCallees(_ wrappedItems: [String]) {
            proto.callees = wrappedItems
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessageCalling {
            return try DSKProtoCallMessageCalling(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessageCalling(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage.Calling

    @objc
    public let conversationID: DSKProtoConversationId?

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    @objc
    public var roomName: String? {
        guard hasRoomName else {
            return nil
        }
        return proto.roomName
    }
    @objc
    public var hasRoomName: Bool {
        return proto.hasRoomName
    }

    @objc
    public var caller: String? {
        guard hasCaller else {
            return nil
        }
        return proto.caller
    }
    @objc
    public var hasCaller: Bool {
        return proto.hasCaller
    }

    @objc
    public var emk: Data? {
        guard hasEmk else {
            return nil
        }
        return proto.emk
    }
    @objc
    public var hasEmk: Bool {
        return proto.hasEmk
    }

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
    public var createCallMsg: Bool {
        return proto.createCallMsg
    }
    @objc
    public var hasCreateCallMsg: Bool {
        return proto.hasCreateCallMsg
    }

    @objc
    public var controlType: String? {
        guard hasControlType else {
            return nil
        }
        return proto.controlType
    }
    @objc
    public var hasControlType: Bool {
        return proto.hasControlType
    }

    @objc
    public var callees: [String] {
        return proto.callees
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage.Calling,
                 conversationID: DSKProtoConversationId?) {
        self.proto = proto
        self.conversationID = conversationID
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage.Calling(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage.Calling) throws {
        var conversationID: DSKProtoConversationId?
        if proto.hasConversationID {
            conversationID = try DSKProtoConversationId(proto.conversationID)
        }

        // MARK: - Begin Validation Logic for DSKProtoCallMessageCalling -

        // MARK: - End Validation Logic for DSKProtoCallMessageCalling -

        self.init(proto: proto,
                  conversationID: conversationID)
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

extension DSKProtoCallMessageCalling {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessageCalling.DSKProtoCallMessageCallingBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessageCalling? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessageJoined

@objc
public class DSKProtoCallMessageJoined: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageJoinedBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageJoinedBuilder {
        return DSKProtoCallMessageJoinedBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageJoinedBuilder {
        let builder = DSKProtoCallMessageJoinedBuilder()
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageJoinedBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage.Joined()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessageJoined {
            return try DSKProtoCallMessageJoined(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessageJoined(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage.Joined

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage.Joined) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage.Joined(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage.Joined) throws {
        // MARK: - Begin Validation Logic for DSKProtoCallMessageJoined -

        // MARK: - End Validation Logic for DSKProtoCallMessageJoined -

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

extension DSKProtoCallMessageJoined {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessageJoined.DSKProtoCallMessageJoinedBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessageJoined? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessageCancel

@objc
public class DSKProtoCallMessageCancel: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageCancelBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageCancelBuilder {
        return DSKProtoCallMessageCancelBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageCancelBuilder {
        let builder = DSKProtoCallMessageCancelBuilder()
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageCancelBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage.Cancel()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessageCancel {
            return try DSKProtoCallMessageCancel(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessageCancel(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage.Cancel

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage.Cancel) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage.Cancel(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage.Cancel) throws {
        // MARK: - Begin Validation Logic for DSKProtoCallMessageCancel -

        // MARK: - End Validation Logic for DSKProtoCallMessageCancel -

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

extension DSKProtoCallMessageCancel {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessageCancel.DSKProtoCallMessageCancelBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessageCancel? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessageReject

@objc
public class DSKProtoCallMessageReject: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageRejectBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageRejectBuilder {
        return DSKProtoCallMessageRejectBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageRejectBuilder {
        let builder = DSKProtoCallMessageRejectBuilder()
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageRejectBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage.Reject()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessageReject {
            return try DSKProtoCallMessageReject(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessageReject(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage.Reject

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage.Reject) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage.Reject(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage.Reject) throws {
        // MARK: - Begin Validation Logic for DSKProtoCallMessageReject -

        // MARK: - End Validation Logic for DSKProtoCallMessageReject -

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

extension DSKProtoCallMessageReject {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessageReject.DSKProtoCallMessageRejectBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessageReject? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessageHangup

@objc
public class DSKProtoCallMessageHangup: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageHangupBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageHangupBuilder {
        return DSKProtoCallMessageHangupBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageHangupBuilder {
        let builder = DSKProtoCallMessageHangupBuilder()
        if let _value = roomID {
            builder.setRoomID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageHangupBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage.Hangup()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRoomID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.roomID = valueParam
        }

        public func setRoomID(_ valueParam: String) {
            proto.roomID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessageHangup {
            return try DSKProtoCallMessageHangup(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessageHangup(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage.Hangup

    @objc
    public var roomID: String? {
        guard hasRoomID else {
            return nil
        }
        return proto.roomID
    }
    @objc
    public var hasRoomID: Bool {
        return proto.hasRoomID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage.Hangup) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage.Hangup(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage.Hangup) throws {
        // MARK: - Begin Validation Logic for DSKProtoCallMessageHangup -

        // MARK: - End Validation Logic for DSKProtoCallMessageHangup -

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

extension DSKProtoCallMessageHangup {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessageHangup.DSKProtoCallMessageHangupBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessageHangup? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCallMessage

@objc
public class DSKProtoCallMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCallMessageBuilder

    @objc
    public static func builder() -> DSKProtoCallMessageBuilder {
        return DSKProtoCallMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCallMessageBuilder {
        let builder = DSKProtoCallMessageBuilder()
        if let _value = calling {
            builder.setCalling(_value)
        }
        if let _value = joined {
            builder.setJoined(_value)
        }
        if let _value = cancel {
            builder.setCancel(_value)
        }
        if let _value = reject {
            builder.setReject(_value)
        }
        if let _value = hangup {
            builder.setHangup(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCallMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_CallMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCalling(_ valueParam: DSKProtoCallMessageCalling?) {
            guard let valueParam = valueParam else { return }
            proto.calling = valueParam.proto
        }

        public func setCalling(_ valueParam: DSKProtoCallMessageCalling) {
            proto.calling = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setJoined(_ valueParam: DSKProtoCallMessageJoined?) {
            guard let valueParam = valueParam else { return }
            proto.joined = valueParam.proto
        }

        public func setJoined(_ valueParam: DSKProtoCallMessageJoined) {
            proto.joined = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCancel(_ valueParam: DSKProtoCallMessageCancel?) {
            guard let valueParam = valueParam else { return }
            proto.cancel = valueParam.proto
        }

        public func setCancel(_ valueParam: DSKProtoCallMessageCancel) {
            proto.cancel = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReject(_ valueParam: DSKProtoCallMessageReject?) {
            guard let valueParam = valueParam else { return }
            proto.reject = valueParam.proto
        }

        public func setReject(_ valueParam: DSKProtoCallMessageReject) {
            proto.reject = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setHangup(_ valueParam: DSKProtoCallMessageHangup?) {
            guard let valueParam = valueParam else { return }
            proto.hangup = valueParam.proto
        }

        public func setHangup(_ valueParam: DSKProtoCallMessageHangup) {
            proto.hangup = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCallMessage {
            return try DSKProtoCallMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCallMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_CallMessage

    @objc
    public let calling: DSKProtoCallMessageCalling?

    @objc
    public let joined: DSKProtoCallMessageJoined?

    @objc
    public let cancel: DSKProtoCallMessageCancel?

    @objc
    public let reject: DSKProtoCallMessageReject?

    @objc
    public let hangup: DSKProtoCallMessageHangup?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_CallMessage,
                 calling: DSKProtoCallMessageCalling?,
                 joined: DSKProtoCallMessageJoined?,
                 cancel: DSKProtoCallMessageCancel?,
                 reject: DSKProtoCallMessageReject?,
                 hangup: DSKProtoCallMessageHangup?) {
        self.proto = proto
        self.calling = calling
        self.joined = joined
        self.cancel = cancel
        self.reject = reject
        self.hangup = hangup
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_CallMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_CallMessage) throws {
        var calling: DSKProtoCallMessageCalling?
        if proto.hasCalling {
            calling = try DSKProtoCallMessageCalling(proto.calling)
        }

        var joined: DSKProtoCallMessageJoined?
        if proto.hasJoined {
            joined = try DSKProtoCallMessageJoined(proto.joined)
        }

        var cancel: DSKProtoCallMessageCancel?
        if proto.hasCancel {
            cancel = try DSKProtoCallMessageCancel(proto.cancel)
        }

        var reject: DSKProtoCallMessageReject?
        if proto.hasReject {
            reject = try DSKProtoCallMessageReject(proto.reject)
        }

        var hangup: DSKProtoCallMessageHangup?
        if proto.hasHangup {
            hangup = try DSKProtoCallMessageHangup(proto.hangup)
        }

        // MARK: - Begin Validation Logic for DSKProtoCallMessage -

        // MARK: - End Validation Logic for DSKProtoCallMessage -

        self.init(proto: proto,
                  calling: calling,
                  joined: joined,
                  cancel: cancel,
                  reject: reject,
                  hangup: hangup)
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

extension DSKProtoCallMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCallMessage.DSKProtoCallMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCallMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoMsgExtra

@objc
public class DSKProtoMsgExtra: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoMsgExtraBuilder

    @objc
    public static func builder() -> DSKProtoMsgExtraBuilder {
        return DSKProtoMsgExtraBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoMsgExtraBuilder {
        let builder = DSKProtoMsgExtraBuilder()
        if let _value = latestCard {
            builder.setLatestCard(_value)
        }
        if let _value = conversationID {
            builder.setConversationID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoMsgExtraBuilder: NSObject {

        private var proto = DifftServiceProtos_MsgExtra()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLatestCard(_ valueParam: DSKProtoCard?) {
            guard let valueParam = valueParam else { return }
            proto.latestCard = valueParam.proto
        }

        public func setLatestCard(_ valueParam: DSKProtoCard) {
            proto.latestCard = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationID(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversationID = valueParam.proto
        }

        public func setConversationID(_ valueParam: DSKProtoConversationId) {
            proto.conversationID = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoMsgExtra {
            return try DSKProtoMsgExtra(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoMsgExtra(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_MsgExtra

    @objc
    public let latestCard: DSKProtoCard?

    @objc
    public let conversationID: DSKProtoConversationId?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_MsgExtra,
                 latestCard: DSKProtoCard?,
                 conversationID: DSKProtoConversationId?) {
        self.proto = proto
        self.latestCard = latestCard
        self.conversationID = conversationID
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_MsgExtra(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_MsgExtra) throws {
        var latestCard: DSKProtoCard?
        if proto.hasLatestCard {
            latestCard = try DSKProtoCard(proto.latestCard)
        }

        var conversationID: DSKProtoConversationId?
        if proto.hasConversationID {
            conversationID = try DSKProtoConversationId(proto.conversationID)
        }

        // MARK: - Begin Validation Logic for DSKProtoMsgExtra -

        // MARK: - End Validation Logic for DSKProtoMsgExtra -

        self.init(proto: proto,
                  latestCard: latestCard,
                  conversationID: conversationID)
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

extension DSKProtoMsgExtra {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoMsgExtra.DSKProtoMsgExtraBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoMsgExtra? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoCardType

@objc
public enum DSKProtoCardType: Int32 {
    case insert = 0
    case update = 1
}

private func DSKProtoCardTypeWrap(_ value: DifftServiceProtos_Card.TypeEnum) -> DSKProtoCardType {
    switch value {
    case .insert: return .insert
    case .update: return .update
    }
}

private func DSKProtoCardTypeUnwrap(_ value: DSKProtoCardType) -> DifftServiceProtos_Card.TypeEnum {
    switch value {
    case .insert: return .insert
    case .update: return .update
    }
}

// MARK: - DSKProtoCardContentType

@objc
public enum DSKProtoCardContentType: Int32 {
    case markdown = 0
    case adaptivecard = 1
}

private func DSKProtoCardContentTypeWrap(_ value: DifftServiceProtos_Card.ContentType) -> DSKProtoCardContentType {
    switch value {
    case .markdown: return .markdown
    case .adaptivecard: return .adaptivecard
    }
}

private func DSKProtoCardContentTypeUnwrap(_ value: DSKProtoCardContentType) -> DifftServiceProtos_Card.ContentType {
    switch value {
    case .markdown: return .markdown
    case .adaptivecard: return .adaptivecard
    }
}

// MARK: - DSKProtoCard

@objc
public class DSKProtoCard: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoCardBuilder

    @objc
    public static func builder() -> DSKProtoCardBuilder {
        return DSKProtoCardBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoCardBuilder {
        let builder = DSKProtoCardBuilder()
        if let _value = appID {
            builder.setAppID(_value)
        }
        if let _value = cardID {
            builder.setCardID(_value)
        }
        if hasVersion {
            builder.setVersion(version)
        }
        if let _value = creator {
            builder.setCreator(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = content {
            builder.setContent(_value)
        }
        if hasContentType {
            builder.setContentType(contentType)
        }
        if hasType {
            builder.setType(type)
        }
        if hasFixedWidth {
            builder.setFixedWidth(fixedWidth)
        }
        if hasHeight {
            builder.setHeight(height)
        }
        if let _value = uniqueID {
            builder.setUniqueID(_value)
        }
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = conversationID {
            builder.setConversationID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoCardBuilder: NSObject {

        private var proto = DifftServiceProtos_Card()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAppID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.appID = valueParam
        }

        public func setAppID(_ valueParam: String) {
            proto.appID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCardID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.cardID = valueParam
        }

        public func setCardID(_ valueParam: String) {
            proto.cardID = valueParam
        }

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCreator(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.creator = valueParam
        }

        public func setCreator(_ valueParam: String) {
            proto.creator = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContent(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.content = valueParam
        }

        public func setContent(_ valueParam: String) {
            proto.content = valueParam
        }

        @objc
        public func setContentType(_ valueParam: UInt32) {
            proto.contentType = valueParam
        }

        @objc
        public func setType(_ valueParam: UInt32) {
            proto.type = valueParam
        }

        @objc
        public func setFixedWidth(_ valueParam: Bool) {
            proto.fixedWidth = valueParam
        }

        @objc
        public func setHeight(_ valueParam: UInt32) {
            proto.height = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setUniqueID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.uniqueID = valueParam
        }

        public func setUniqueID(_ valueParam: String) {
            proto.uniqueID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam
        }

        public func setSource(_ valueParam: String) {
            proto.source = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.conversationID = valueParam
        }

        public func setConversationID(_ valueParam: String) {
            proto.conversationID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoCard {
            return try DSKProtoCard(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoCard(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_Card

    @objc
    public var appID: String? {
        guard hasAppID else {
            return nil
        }
        return proto.appID
    }
    @objc
    public var hasAppID: Bool {
        return proto.hasAppID
    }

    @objc
    public var cardID: String? {
        guard hasCardID else {
            return nil
        }
        return proto.cardID
    }
    @objc
    public var hasCardID: Bool {
        return proto.hasCardID
    }

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    @objc
    public var creator: String? {
        guard hasCreator else {
            return nil
        }
        return proto.creator
    }
    @objc
    public var hasCreator: Bool {
        return proto.hasCreator
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var content: String? {
        guard hasContent else {
            return nil
        }
        return proto.content
    }
    @objc
    public var hasContent: Bool {
        return proto.hasContent
    }

    @objc
    public var contentType: UInt32 {
        return proto.contentType
    }
    @objc
    public var hasContentType: Bool {
        return proto.hasContentType
    }

    @objc
    public var type: UInt32 {
        return proto.type
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var fixedWidth: Bool {
        return proto.fixedWidth
    }
    @objc
    public var hasFixedWidth: Bool {
        return proto.hasFixedWidth
    }

    @objc
    public var height: UInt32 {
        return proto.height
    }
    @objc
    public var hasHeight: Bool {
        return proto.hasHeight
    }

    @objc
    public var uniqueID: String? {
        guard hasUniqueID else {
            return nil
        }
        return proto.uniqueID
    }
    @objc
    public var hasUniqueID: Bool {
        return proto.hasUniqueID
    }

    @objc
    public var source: String? {
        guard hasSource else {
            return nil
        }
        return proto.source
    }
    @objc
    public var hasSource: Bool {
        return proto.hasSource
    }

    @objc
    public var conversationID: String? {
        guard hasConversationID else {
            return nil
        }
        return proto.conversationID
    }
    @objc
    public var hasConversationID: Bool {
        return proto.hasConversationID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_Card) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_Card(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_Card) throws {
        // MARK: - Begin Validation Logic for DSKProtoCard -

        // MARK: - End Validation Logic for DSKProtoCard -

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

extension DSKProtoCard {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoCard.DSKProtoCardBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoCard? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoRapidFile

@objc
public class DSKProtoRapidFile: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoRapidFileBuilder

    @objc
    public static func builder() -> DSKProtoRapidFileBuilder {
        return DSKProtoRapidFileBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoRapidFileBuilder {
        let builder = DSKProtoRapidFileBuilder()
        if let _value = rapidHash {
            builder.setRapidHash(_value)
        }
        if let _value = authorizedID {
            builder.setAuthorizedID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoRapidFileBuilder: NSObject {

        private var proto = DifftServiceProtos_RapidFile()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRapidHash(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.rapidHash = valueParam
        }

        public func setRapidHash(_ valueParam: String) {
            proto.rapidHash = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAuthorizedID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.authorizedID = valueParam
        }

        public func setAuthorizedID(_ valueParam: String) {
            proto.authorizedID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoRapidFile {
            return try DSKProtoRapidFile(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoRapidFile(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_RapidFile

    @objc
    public var rapidHash: String? {
        guard hasRapidHash else {
            return nil
        }
        return proto.rapidHash
    }
    @objc
    public var hasRapidHash: Bool {
        return proto.hasRapidHash
    }

    @objc
    public var authorizedID: String? {
        guard hasAuthorizedID else {
            return nil
        }
        return proto.authorizedID
    }
    @objc
    public var hasAuthorizedID: Bool {
        return proto.hasAuthorizedID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_RapidFile) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_RapidFile(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_RapidFile) throws {
        // MARK: - Begin Validation Logic for DSKProtoRapidFile -

        // MARK: - End Validation Logic for DSKProtoRapidFile -

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

extension DSKProtoRapidFile {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoRapidFile.DSKProtoRapidFileBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoRapidFile? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoRealSource

@objc
public class DSKProtoRealSource: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoRealSourceBuilder

    @objc
    public static func builder() -> DSKProtoRealSourceBuilder {
        return DSKProtoRealSourceBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoRealSourceBuilder {
        let builder = DSKProtoRealSourceBuilder()
        if let _value = source {
            builder.setSource(_value)
        }
        if hasSourceDevice {
            builder.setSourceDevice(sourceDevice)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if hasServerTimestamp {
            builder.setServerTimestamp(serverTimestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoRealSourceBuilder: NSObject {

        private var proto = DifftServiceProtos_RealSource()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam
        }

        public func setSource(_ valueParam: String) {
            proto.source = valueParam
        }

        @objc
        public func setSourceDevice(_ valueParam: UInt32) {
            proto.sourceDevice = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        public func setServerTimestamp(_ valueParam: UInt64) {
            proto.serverTimestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoRealSource {
            return try DSKProtoRealSource(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoRealSource(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_RealSource

    @objc
    public var source: String? {
        guard hasSource else {
            return nil
        }
        return proto.source
    }
    @objc
    public var hasSource: Bool {
        return proto.hasSource
    }

    @objc
    public var sourceDevice: UInt32 {
        return proto.sourceDevice
    }
    @objc
    public var hasSourceDevice: Bool {
        return proto.hasSourceDevice
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var serverTimestamp: UInt64 {
        return proto.serverTimestamp
    }
    @objc
    public var hasServerTimestamp: Bool {
        return proto.hasServerTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_RealSource) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_RealSource(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_RealSource) throws {
        // MARK: - Begin Validation Logic for DSKProtoRealSource -

        // MARK: - End Validation Logic for DSKProtoRealSource -

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

extension DSKProtoRealSource {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoRealSource.DSKProtoRealSourceBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoRealSource? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoTopicContextMarkContent

@objc
public class DSKProtoTopicContextMarkContent: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoTopicContextMarkContentBuilder

    @objc
    public static func builder() -> DSKProtoTopicContextMarkContentBuilder {
        return DSKProtoTopicContextMarkContentBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoTopicContextMarkContentBuilder {
        let builder = DSKProtoTopicContextMarkContentBuilder()
        if let _value = mark {
            builder.setMark(_value)
        }
        if hasSequenceID {
            builder.setSequenceID(sequenceID)
        }
        if hasServerTimestamp {
            builder.setServerTimestamp(serverTimestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoTopicContextMarkContentBuilder: NSObject {

        private var proto = DifftServiceProtos_TopicContext.MarkContent()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMark(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.mark = valueParam
        }

        public func setMark(_ valueParam: String) {
            proto.mark = valueParam
        }

        @objc
        public func setSequenceID(_ valueParam: UInt64) {
            proto.sequenceID = valueParam
        }

        @objc
        public func setServerTimestamp(_ valueParam: UInt64) {
            proto.serverTimestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoTopicContextMarkContent {
            return try DSKProtoTopicContextMarkContent(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoTopicContextMarkContent(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_TopicContext.MarkContent

    @objc
    public var mark: String? {
        guard hasMark else {
            return nil
        }
        return proto.mark
    }
    @objc
    public var hasMark: Bool {
        return proto.hasMark
    }

    @objc
    public var sequenceID: UInt64 {
        return proto.sequenceID
    }
    @objc
    public var hasSequenceID: Bool {
        return proto.hasSequenceID
    }

    @objc
    public var serverTimestamp: UInt64 {
        return proto.serverTimestamp
    }
    @objc
    public var hasServerTimestamp: Bool {
        return proto.hasServerTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_TopicContext.MarkContent) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_TopicContext.MarkContent(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_TopicContext.MarkContent) throws {
        // MARK: - Begin Validation Logic for DSKProtoTopicContextMarkContent -

        // MARK: - End Validation Logic for DSKProtoTopicContextMarkContent -

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

extension DSKProtoTopicContextMarkContent {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoTopicContextMarkContent.DSKProtoTopicContextMarkContentBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoTopicContextMarkContent? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoTopicContextType

@objc
public enum DSKProtoTopicContextType: Int32 {
    case user = 0
    case message = 1
}

private func DSKProtoTopicContextTypeWrap(_ value: DifftServiceProtos_TopicContext.TypeEnum) -> DSKProtoTopicContextType {
    switch value {
    case .user: return .user
    case .message: return .message
    }
}

private func DSKProtoTopicContextTypeUnwrap(_ value: DSKProtoTopicContextType) -> DifftServiceProtos_TopicContext.TypeEnum {
    switch value {
    case .user: return .user
    case .message: return .message
    }
}

// MARK: - DSKProtoTopicContextSupportType

@objc
public enum DSKProtoTopicContextSupportType: Int32 {
    case normal = 0
    case support = 1
}

private func DSKProtoTopicContextSupportTypeWrap(_ value: DifftServiceProtos_TopicContext.SupportType) -> DSKProtoTopicContextSupportType {
    switch value {
    case .normal: return .normal
    case .support: return .support
    }
}

private func DSKProtoTopicContextSupportTypeUnwrap(_ value: DSKProtoTopicContextSupportType) -> DifftServiceProtos_TopicContext.SupportType {
    switch value {
    case .normal: return .normal
    case .support: return .support
    }
}

// MARK: - DSKProtoTopicContext

@objc
public class DSKProtoTopicContext: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoTopicContextBuilder

    @objc
    public static func builder() -> DSKProtoTopicContextBuilder {
        return DSKProtoTopicContextBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoTopicContextBuilder {
        let builder = DSKProtoTopicContextBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = supportType {
            builder.setSupportType(_value)
        }
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = sourceBrief {
            builder.setSourceBrief(_value)
        }
        if let _value = sourceDisplayName {
            builder.setSourceDisplayName(_value)
        }
        if hasReplyToUser {
            builder.setReplyToUser(replyToUser)
        }
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if let _value = groupName {
            builder.setGroupName(_value)
        }
        if let _value = botID {
            builder.setBotID(_value)
        }
        if let _value = topicID {
            builder.setTopicID(_value)
        }
        if let _value = content {
            builder.setContent(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoTopicContextBuilder: NSObject {

        private var proto = DifftServiceProtos_TopicContext()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoTopicContextType) {
            proto.type = DSKProtoTopicContextTypeUnwrap(valueParam)
        }

        @objc
        public func setSupportType(_ valueParam: DSKProtoTopicContextSupportType) {
            proto.supportType = DSKProtoTopicContextSupportTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSourceBrief(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.sourceBrief = valueParam
        }

        public func setSourceBrief(_ valueParam: String) {
            proto.sourceBrief = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSourceDisplayName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.sourceDisplayName = valueParam
        }

        public func setSourceDisplayName(_ valueParam: String) {
            proto.sourceDisplayName = valueParam
        }

        @objc
        public func setReplyToUser(_ valueParam: Bool) {
            proto.replyToUser = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.groupName = valueParam
        }

        public func setGroupName(_ valueParam: String) {
            proto.groupName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBotID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.botID = valueParam
        }

        public func setBotID(_ valueParam: String) {
            proto.botID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.topicID = valueParam
        }

        public func setTopicID(_ valueParam: String) {
            proto.topicID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContent(_ valueParam: DSKProtoTopicContextMarkContent?) {
            guard let valueParam = valueParam else { return }
            proto.content = valueParam.proto
        }

        public func setContent(_ valueParam: DSKProtoTopicContextMarkContent) {
            proto.content = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoTopicContext {
            return try DSKProtoTopicContext(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoTopicContext(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_TopicContext

    @objc
    public let source: DSKProtoRealSource?

    @objc
    public let content: DSKProtoTopicContextMarkContent?

    public var type: DSKProtoTopicContextType? {
        guard hasType else {
            return nil
        }
        return DSKProtoTopicContextTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoTopicContextType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: TopicContext.type.")
        }
        return DSKProtoTopicContextTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    public var supportType: DSKProtoTopicContextSupportType? {
        guard hasSupportType else {
            return nil
        }
        return DSKProtoTopicContextSupportTypeWrap(proto.supportType)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedSupportType: DSKProtoTopicContextSupportType {
        if !hasSupportType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: TopicContext.supportType.")
        }
        return DSKProtoTopicContextSupportTypeWrap(proto.supportType)
    }
    @objc
    public var hasSupportType: Bool {
        return proto.hasSupportType
    }

    @objc
    public var sourceBrief: String? {
        guard hasSourceBrief else {
            return nil
        }
        return proto.sourceBrief
    }
    @objc
    public var hasSourceBrief: Bool {
        return proto.hasSourceBrief
    }

    @objc
    public var sourceDisplayName: String? {
        guard hasSourceDisplayName else {
            return nil
        }
        return proto.sourceDisplayName
    }
    @objc
    public var hasSourceDisplayName: Bool {
        return proto.hasSourceDisplayName
    }

    @objc
    public var replyToUser: Bool {
        return proto.replyToUser
    }
    @objc
    public var hasReplyToUser: Bool {
        return proto.hasReplyToUser
    }

    @objc
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    @objc
    public var groupName: String? {
        guard hasGroupName else {
            return nil
        }
        return proto.groupName
    }
    @objc
    public var hasGroupName: Bool {
        return proto.hasGroupName
    }

    @objc
    public var botID: String? {
        guard hasBotID else {
            return nil
        }
        return proto.botID
    }
    @objc
    public var hasBotID: Bool {
        return proto.hasBotID
    }

    @objc
    public var topicID: String? {
        guard hasTopicID else {
            return nil
        }
        return proto.topicID
    }
    @objc
    public var hasTopicID: Bool {
        return proto.hasTopicID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_TopicContext,
                 source: DSKProtoRealSource?,
                 content: DSKProtoTopicContextMarkContent?) {
        self.proto = proto
        self.source = source
        self.content = content
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_TopicContext(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_TopicContext) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        var content: DSKProtoTopicContextMarkContent?
        if proto.hasContent {
            content = try DSKProtoTopicContextMarkContent(proto.content)
        }

        // MARK: - Begin Validation Logic for DSKProtoTopicContext -

        // MARK: - End Validation Logic for DSKProtoTopicContext -

        self.init(proto: proto,
                  source: source,
                  content: content)
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

extension DSKProtoTopicContext {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoTopicContext.DSKProtoTopicContextBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoTopicContext? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageQuoteQuotedAttachmentFlags

@objc
public enum DSKProtoDataMessageQuoteQuotedAttachmentFlags: Int32 {
    case voiceMessage = 1
}

private func DSKProtoDataMessageQuoteQuotedAttachmentFlagsWrap(_ value: DifftServiceProtos_DataMessage.Quote.QuotedAttachment.Flags) -> DSKProtoDataMessageQuoteQuotedAttachmentFlags {
    switch value {
    case .voiceMessage: return .voiceMessage
    }
}

private func DSKProtoDataMessageQuoteQuotedAttachmentFlagsUnwrap(_ value: DSKProtoDataMessageQuoteQuotedAttachmentFlags) -> DifftServiceProtos_DataMessage.Quote.QuotedAttachment.Flags {
    switch value {
    case .voiceMessage: return .voiceMessage
    }
}

// MARK: - DSKProtoDataMessageQuoteQuotedAttachment

@objc
public class DSKProtoDataMessageQuoteQuotedAttachment: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageQuoteQuotedAttachmentBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageQuoteQuotedAttachmentBuilder {
        return DSKProtoDataMessageQuoteQuotedAttachmentBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageQuoteQuotedAttachmentBuilder {
        let builder = DSKProtoDataMessageQuoteQuotedAttachmentBuilder()
        if let _value = contentType {
            builder.setContentType(_value)
        }
        if let _value = fileName {
            builder.setFileName(_value)
        }
        if let _value = thumbnail {
            builder.setThumbnail(_value)
        }
        if hasFlags {
            builder.setFlags(flags)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageQuoteQuotedAttachmentBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Quote.QuotedAttachment()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContentType(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.contentType = valueParam
        }

        public func setContentType(_ valueParam: String) {
            proto.contentType = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setFileName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.fileName = valueParam
        }

        public func setFileName(_ valueParam: String) {
            proto.fileName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setThumbnail(_ valueParam: DSKProtoAttachmentPointer?) {
            guard let valueParam = valueParam else { return }
            proto.thumbnail = valueParam.proto
        }

        public func setThumbnail(_ valueParam: DSKProtoAttachmentPointer) {
            proto.thumbnail = valueParam.proto
        }

        @objc
        public func setFlags(_ valueParam: UInt32) {
            proto.flags = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageQuoteQuotedAttachment {
            return try DSKProtoDataMessageQuoteQuotedAttachment(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageQuoteQuotedAttachment(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Quote.QuotedAttachment

    @objc
    public let thumbnail: DSKProtoAttachmentPointer?

    @objc
    public var contentType: String? {
        guard hasContentType else {
            return nil
        }
        return proto.contentType
    }
    @objc
    public var hasContentType: Bool {
        return proto.hasContentType
    }

    @objc
    public var fileName: String? {
        guard hasFileName else {
            return nil
        }
        return proto.fileName
    }
    @objc
    public var hasFileName: Bool {
        return proto.hasFileName
    }

    @objc
    public var flags: UInt32 {
        return proto.flags
    }
    @objc
    public var hasFlags: Bool {
        return proto.hasFlags
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Quote.QuotedAttachment,
                 thumbnail: DSKProtoAttachmentPointer?) {
        self.proto = proto
        self.thumbnail = thumbnail
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Quote.QuotedAttachment(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Quote.QuotedAttachment) throws {
        var thumbnail: DSKProtoAttachmentPointer?
        if proto.hasThumbnail {
            thumbnail = try DSKProtoAttachmentPointer(proto.thumbnail)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageQuoteQuotedAttachment -

        // MARK: - End Validation Logic for DSKProtoDataMessageQuoteQuotedAttachment -

        self.init(proto: proto,
                  thumbnail: thumbnail)
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

extension DSKProtoDataMessageQuoteQuotedAttachment {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageQuoteQuotedAttachment.DSKProtoDataMessageQuoteQuotedAttachmentBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageQuoteQuotedAttachment? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageQuote

@objc
public class DSKProtoDataMessageQuote: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageQuoteBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageQuoteBuilder {
        return DSKProtoDataMessageQuoteBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageQuoteBuilder {
        let builder = DSKProtoDataMessageQuoteBuilder()
        if hasID {
            builder.setId(id)
        }
        if let _value = author {
            builder.setAuthor(_value)
        }
        if let _value = text {
            builder.setText(_value)
        }
        builder.setAttachments(attachments)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageQuoteBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Quote()

        @objc
        fileprivate override init() {}

        @objc
        public func setId(_ valueParam: UInt64) {
            proto.id = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAuthor(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.author = valueParam
        }

        public func setAuthor(_ valueParam: String) {
            proto.author = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setText(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.text = valueParam
        }

        public func setText(_ valueParam: String) {
            proto.text = valueParam
        }

        @objc
        public func addAttachments(_ valueParam: DSKProtoDataMessageQuoteQuotedAttachment) {
            proto.attachments.append(valueParam.proto)
        }

        @objc
        public func setAttachments(_ wrappedItems: [DSKProtoDataMessageQuoteQuotedAttachment]) {
            proto.attachments = wrappedItems.map { $0.proto }
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageQuote {
            return try DSKProtoDataMessageQuote(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageQuote(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Quote

    @objc
    public let attachments: [DSKProtoDataMessageQuoteQuotedAttachment]

    @objc
    public var id: UInt64 {
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    @objc
    public var author: String? {
        guard hasAuthor else {
            return nil
        }
        return proto.author
    }
    @objc
    public var hasAuthor: Bool {
        return proto.hasAuthor
    }

    @objc
    public var text: String? {
        guard hasText else {
            return nil
        }
        return proto.text
    }
    @objc
    public var hasText: Bool {
        return proto.hasText
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Quote,
                 attachments: [DSKProtoDataMessageQuoteQuotedAttachment]) {
        self.proto = proto
        self.attachments = attachments
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Quote(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Quote) throws {
        var attachments: [DSKProtoDataMessageQuoteQuotedAttachment] = []
        attachments = try proto.attachments.map { try DSKProtoDataMessageQuoteQuotedAttachment($0) }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageQuote -

        // MARK: - End Validation Logic for DSKProtoDataMessageQuote -

        self.init(proto: proto,
                  attachments: attachments)
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

extension DSKProtoDataMessageQuote {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageQuote.DSKProtoDataMessageQuoteBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageQuote? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageForwardType

@objc
public enum DSKProtoDataMessageForwardType: Int32 {
    case normal = 0
    case eof = 1
}

private func DSKProtoDataMessageForwardTypeWrap(_ value: DifftServiceProtos_DataMessage.Forward.TypeEnum) -> DSKProtoDataMessageForwardType {
    switch value {
    case .normal: return .normal
    case .eof: return .eof
    }
}

private func DSKProtoDataMessageForwardTypeUnwrap(_ value: DSKProtoDataMessageForwardType) -> DifftServiceProtos_DataMessage.Forward.TypeEnum {
    switch value {
    case .normal: return .normal
    case .eof: return .eof
    }
}

// MARK: - DSKProtoDataMessageForward

@objc
public class DSKProtoDataMessageForward: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageForwardBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageForwardBuilder {
        return DSKProtoDataMessageForwardBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageForwardBuilder {
        let builder = DSKProtoDataMessageForwardBuilder()
        if hasID {
            builder.setId(id)
        }
        if hasType {
            builder.setType(type)
        }
        if hasIsFromGroup {
            builder.setIsFromGroup(isFromGroup)
        }
        if let _value = author {
            builder.setAuthor(_value)
        }
        if let _value = text {
            builder.setText(_value)
        }
        builder.setAttachments(attachments)
        builder.setForwards(forwards)
        if let _value = card {
            builder.setCard(_value)
        }
        builder.setMentions(mentions)
        if hasServerTimestamp {
            builder.setServerTimestamp(serverTimestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageForwardBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Forward()

        @objc
        fileprivate override init() {}

        @objc
        public func setId(_ valueParam: UInt64) {
            proto.id = valueParam
        }

        @objc
        public func setType(_ valueParam: UInt32) {
            proto.type = valueParam
        }

        @objc
        public func setIsFromGroup(_ valueParam: Bool) {
            proto.isFromGroup = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAuthor(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.author = valueParam
        }

        public func setAuthor(_ valueParam: String) {
            proto.author = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setText(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.text = valueParam
        }

        public func setText(_ valueParam: String) {
            proto.text = valueParam
        }

        @objc
        public func addAttachments(_ valueParam: DSKProtoAttachmentPointer) {
            proto.attachments.append(valueParam.proto)
        }

        @objc
        public func setAttachments(_ wrappedItems: [DSKProtoAttachmentPointer]) {
            proto.attachments = wrappedItems.map { $0.proto }
        }

        @objc
        public func addForwards(_ valueParam: DSKProtoDataMessageForward) {
            proto.forwards.append(valueParam.proto)
        }

        @objc
        public func setForwards(_ wrappedItems: [DSKProtoDataMessageForward]) {
            proto.forwards = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCard(_ valueParam: DSKProtoCard?) {
            guard let valueParam = valueParam else { return }
            proto.card = valueParam.proto
        }

        public func setCard(_ valueParam: DSKProtoCard) {
            proto.card = valueParam.proto
        }

        @objc
        public func addMentions(_ valueParam: DSKProtoDataMessageMention) {
            proto.mentions.append(valueParam.proto)
        }

        @objc
        public func setMentions(_ wrappedItems: [DSKProtoDataMessageMention]) {
            proto.mentions = wrappedItems.map { $0.proto }
        }

        @objc
        public func setServerTimestamp(_ valueParam: UInt64) {
            proto.serverTimestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageForward {
            return try DSKProtoDataMessageForward(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageForward(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Forward

    @objc
    public let attachments: [DSKProtoAttachmentPointer]

    @objc
    public let forwards: [DSKProtoDataMessageForward]

    @objc
    public let card: DSKProtoCard?

    @objc
    public let mentions: [DSKProtoDataMessageMention]

    @objc
    public var id: UInt64 {
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    @objc
    public var type: UInt32 {
        return proto.type
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var isFromGroup: Bool {
        return proto.isFromGroup
    }
    @objc
    public var hasIsFromGroup: Bool {
        return proto.hasIsFromGroup
    }

    @objc
    public var author: String? {
        guard hasAuthor else {
            return nil
        }
        return proto.author
    }
    @objc
    public var hasAuthor: Bool {
        return proto.hasAuthor
    }

    @objc
    public var text: String? {
        guard hasText else {
            return nil
        }
        return proto.text
    }
    @objc
    public var hasText: Bool {
        return proto.hasText
    }

    @objc
    public var serverTimestamp: UInt64 {
        return proto.serverTimestamp
    }
    @objc
    public var hasServerTimestamp: Bool {
        return proto.hasServerTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Forward,
                 attachments: [DSKProtoAttachmentPointer],
                 forwards: [DSKProtoDataMessageForward],
                 card: DSKProtoCard?,
                 mentions: [DSKProtoDataMessageMention]) {
        self.proto = proto
        self.attachments = attachments
        self.forwards = forwards
        self.card = card
        self.mentions = mentions
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Forward(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Forward) throws {
        var attachments: [DSKProtoAttachmentPointer] = []
        attachments = try proto.attachments.map { try DSKProtoAttachmentPointer($0) }

        var forwards: [DSKProtoDataMessageForward] = []
        forwards = try proto.forwards.map { try DSKProtoDataMessageForward($0) }

        var card: DSKProtoCard?
        if proto.hasCard {
            card = try DSKProtoCard(proto.card)
        }

        var mentions: [DSKProtoDataMessageMention] = []
        mentions = try proto.mentions.map { try DSKProtoDataMessageMention($0) }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageForward -

        // MARK: - End Validation Logic for DSKProtoDataMessageForward -

        self.init(proto: proto,
                  attachments: attachments,
                  forwards: forwards,
                  card: card,
                  mentions: mentions)
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

extension DSKProtoDataMessageForward {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageForward.DSKProtoDataMessageForwardBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageForward? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageForwardContext

@objc
public class DSKProtoDataMessageForwardContext: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageForwardContextBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageForwardContextBuilder {
        return DSKProtoDataMessageForwardContextBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageForwardContextBuilder {
        let builder = DSKProtoDataMessageForwardContextBuilder()
        builder.setForwards(forwards)
        builder.setRapidFiles(rapidFiles)
        if hasIsFromGroup {
            builder.setIsFromGroup(isFromGroup)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageForwardContextBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.ForwardContext()

        @objc
        fileprivate override init() {}

        @objc
        public func addForwards(_ valueParam: DSKProtoDataMessageForward) {
            proto.forwards.append(valueParam.proto)
        }

        @objc
        public func setForwards(_ wrappedItems: [DSKProtoDataMessageForward]) {
            proto.forwards = wrappedItems.map { $0.proto }
        }

        @objc
        public func addRapidFiles(_ valueParam: DSKProtoRapidFile) {
            proto.rapidFiles.append(valueParam.proto)
        }

        @objc
        public func setRapidFiles(_ wrappedItems: [DSKProtoRapidFile]) {
            proto.rapidFiles = wrappedItems.map { $0.proto }
        }

        @objc
        public func setIsFromGroup(_ valueParam: Bool) {
            proto.isFromGroup = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageForwardContext {
            return try DSKProtoDataMessageForwardContext(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageForwardContext(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.ForwardContext

    @objc
    public let forwards: [DSKProtoDataMessageForward]

    @objc
    public let rapidFiles: [DSKProtoRapidFile]

    @objc
    public var isFromGroup: Bool {
        return proto.isFromGroup
    }
    @objc
    public var hasIsFromGroup: Bool {
        return proto.hasIsFromGroup
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.ForwardContext,
                 forwards: [DSKProtoDataMessageForward],
                 rapidFiles: [DSKProtoRapidFile]) {
        self.proto = proto
        self.forwards = forwards
        self.rapidFiles = rapidFiles
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.ForwardContext(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.ForwardContext) throws {
        var forwards: [DSKProtoDataMessageForward] = []
        forwards = try proto.forwards.map { try DSKProtoDataMessageForward($0) }

        var rapidFiles: [DSKProtoRapidFile] = []
        rapidFiles = try proto.rapidFiles.map { try DSKProtoRapidFile($0) }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageForwardContext -

        // MARK: - End Validation Logic for DSKProtoDataMessageForwardContext -

        self.init(proto: proto,
                  forwards: forwards,
                  rapidFiles: rapidFiles)
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

extension DSKProtoDataMessageForwardContext {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageForwardContext.DSKProtoDataMessageForwardContextBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageForwardContext? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContactName

@objc
public class DSKProtoDataMessageContactName: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactNameBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactNameBuilder {
        return DSKProtoDataMessageContactNameBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactNameBuilder {
        let builder = DSKProtoDataMessageContactNameBuilder()
        if let _value = givenName {
            builder.setGivenName(_value)
        }
        if let _value = familyName {
            builder.setFamilyName(_value)
        }
        if let _value = prefix {
            builder.setPrefix(_value)
        }
        if let _value = suffix {
            builder.setSuffix(_value)
        }
        if let _value = middleName {
            builder.setMiddleName(_value)
        }
        if let _value = displayName {
            builder.setDisplayName(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactNameBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact.Name()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGivenName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.givenName = valueParam
        }

        public func setGivenName(_ valueParam: String) {
            proto.givenName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setFamilyName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.familyName = valueParam
        }

        public func setFamilyName(_ valueParam: String) {
            proto.familyName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPrefix(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.prefix = valueParam
        }

        public func setPrefix(_ valueParam: String) {
            proto.prefix = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSuffix(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.suffix = valueParam
        }

        public func setSuffix(_ valueParam: String) {
            proto.suffix = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMiddleName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.middleName = valueParam
        }

        public func setMiddleName(_ valueParam: String) {
            proto.middleName = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setDisplayName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.displayName = valueParam
        }

        public func setDisplayName(_ valueParam: String) {
            proto.displayName = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContactName {
            return try DSKProtoDataMessageContactName(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContactName(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact.Name

    @objc
    public var givenName: String? {
        guard hasGivenName else {
            return nil
        }
        return proto.givenName
    }
    @objc
    public var hasGivenName: Bool {
        return proto.hasGivenName
    }

    @objc
    public var familyName: String? {
        guard hasFamilyName else {
            return nil
        }
        return proto.familyName
    }
    @objc
    public var hasFamilyName: Bool {
        return proto.hasFamilyName
    }

    @objc
    public var prefix: String? {
        guard hasPrefix else {
            return nil
        }
        return proto.prefix
    }
    @objc
    public var hasPrefix: Bool {
        return proto.hasPrefix
    }

    @objc
    public var suffix: String? {
        guard hasSuffix else {
            return nil
        }
        return proto.suffix
    }
    @objc
    public var hasSuffix: Bool {
        return proto.hasSuffix
    }

    @objc
    public var middleName: String? {
        guard hasMiddleName else {
            return nil
        }
        return proto.middleName
    }
    @objc
    public var hasMiddleName: Bool {
        return proto.hasMiddleName
    }

    @objc
    public var displayName: String? {
        guard hasDisplayName else {
            return nil
        }
        return proto.displayName
    }
    @objc
    public var hasDisplayName: Bool {
        return proto.hasDisplayName
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact.Name) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact.Name(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact.Name) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageContactName -

        // MARK: - End Validation Logic for DSKProtoDataMessageContactName -

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

extension DSKProtoDataMessageContactName {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContactName.DSKProtoDataMessageContactNameBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContactName? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContactPhoneType

@objc
public enum DSKProtoDataMessageContactPhoneType: Int32 {
    case home = 1
    case mobile = 2
    case work = 3
    case custom = 4
}

private func DSKProtoDataMessageContactPhoneTypeWrap(_ value: DifftServiceProtos_DataMessage.Contact.Phone.TypeEnum) -> DSKProtoDataMessageContactPhoneType {
    switch value {
    case .home: return .home
    case .mobile: return .mobile
    case .work: return .work
    case .custom: return .custom
    }
}

private func DSKProtoDataMessageContactPhoneTypeUnwrap(_ value: DSKProtoDataMessageContactPhoneType) -> DifftServiceProtos_DataMessage.Contact.Phone.TypeEnum {
    switch value {
    case .home: return .home
    case .mobile: return .mobile
    case .work: return .work
    case .custom: return .custom
    }
}

// MARK: - DSKProtoDataMessageContactPhone

@objc
public class DSKProtoDataMessageContactPhone: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactPhoneBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactPhoneBuilder {
        return DSKProtoDataMessageContactPhoneBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactPhoneBuilder {
        let builder = DSKProtoDataMessageContactPhoneBuilder()
        if let _value = value {
            builder.setValue(_value)
        }
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = label {
            builder.setLabel(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactPhoneBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact.Phone()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setValue(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.value = valueParam
        }

        public func setValue(_ valueParam: String) {
            proto.value = valueParam
        }

        @objc
        public func setType(_ valueParam: DSKProtoDataMessageContactPhoneType) {
            proto.type = DSKProtoDataMessageContactPhoneTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLabel(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.label = valueParam
        }

        public func setLabel(_ valueParam: String) {
            proto.label = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContactPhone {
            return try DSKProtoDataMessageContactPhone(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContactPhone(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact.Phone

    @objc
    public var value: String? {
        guard hasValue else {
            return nil
        }
        return proto.value
    }
    @objc
    public var hasValue: Bool {
        return proto.hasValue
    }

    public var type: DSKProtoDataMessageContactPhoneType? {
        guard hasType else {
            return nil
        }
        return DSKProtoDataMessageContactPhoneTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoDataMessageContactPhoneType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Phone.type.")
        }
        return DSKProtoDataMessageContactPhoneTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var label: String? {
        guard hasLabel else {
            return nil
        }
        return proto.label
    }
    @objc
    public var hasLabel: Bool {
        return proto.hasLabel
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact.Phone) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact.Phone(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact.Phone) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageContactPhone -

        // MARK: - End Validation Logic for DSKProtoDataMessageContactPhone -

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

extension DSKProtoDataMessageContactPhone {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContactPhone.DSKProtoDataMessageContactPhoneBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContactPhone? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContactEmailType

@objc
public enum DSKProtoDataMessageContactEmailType: Int32 {
    case home = 1
    case mobile = 2
    case work = 3
    case custom = 4
}

private func DSKProtoDataMessageContactEmailTypeWrap(_ value: DifftServiceProtos_DataMessage.Contact.Email.TypeEnum) -> DSKProtoDataMessageContactEmailType {
    switch value {
    case .home: return .home
    case .mobile: return .mobile
    case .work: return .work
    case .custom: return .custom
    }
}

private func DSKProtoDataMessageContactEmailTypeUnwrap(_ value: DSKProtoDataMessageContactEmailType) -> DifftServiceProtos_DataMessage.Contact.Email.TypeEnum {
    switch value {
    case .home: return .home
    case .mobile: return .mobile
    case .work: return .work
    case .custom: return .custom
    }
}

// MARK: - DSKProtoDataMessageContactEmail

@objc
public class DSKProtoDataMessageContactEmail: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactEmailBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactEmailBuilder {
        return DSKProtoDataMessageContactEmailBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactEmailBuilder {
        let builder = DSKProtoDataMessageContactEmailBuilder()
        if let _value = value {
            builder.setValue(_value)
        }
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = label {
            builder.setLabel(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactEmailBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact.Email()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setValue(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.value = valueParam
        }

        public func setValue(_ valueParam: String) {
            proto.value = valueParam
        }

        @objc
        public func setType(_ valueParam: DSKProtoDataMessageContactEmailType) {
            proto.type = DSKProtoDataMessageContactEmailTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLabel(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.label = valueParam
        }

        public func setLabel(_ valueParam: String) {
            proto.label = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContactEmail {
            return try DSKProtoDataMessageContactEmail(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContactEmail(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact.Email

    @objc
    public var value: String? {
        guard hasValue else {
            return nil
        }
        return proto.value
    }
    @objc
    public var hasValue: Bool {
        return proto.hasValue
    }

    public var type: DSKProtoDataMessageContactEmailType? {
        guard hasType else {
            return nil
        }
        return DSKProtoDataMessageContactEmailTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoDataMessageContactEmailType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Email.type.")
        }
        return DSKProtoDataMessageContactEmailTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var label: String? {
        guard hasLabel else {
            return nil
        }
        return proto.label
    }
    @objc
    public var hasLabel: Bool {
        return proto.hasLabel
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact.Email) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact.Email(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact.Email) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageContactEmail -

        // MARK: - End Validation Logic for DSKProtoDataMessageContactEmail -

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

extension DSKProtoDataMessageContactEmail {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContactEmail.DSKProtoDataMessageContactEmailBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContactEmail? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContactPostalAddressType

@objc
public enum DSKProtoDataMessageContactPostalAddressType: Int32 {
    case home = 1
    case work = 2
    case custom = 3
}

private func DSKProtoDataMessageContactPostalAddressTypeWrap(_ value: DifftServiceProtos_DataMessage.Contact.PostalAddress.TypeEnum) -> DSKProtoDataMessageContactPostalAddressType {
    switch value {
    case .home: return .home
    case .work: return .work
    case .custom: return .custom
    }
}

private func DSKProtoDataMessageContactPostalAddressTypeUnwrap(_ value: DSKProtoDataMessageContactPostalAddressType) -> DifftServiceProtos_DataMessage.Contact.PostalAddress.TypeEnum {
    switch value {
    case .home: return .home
    case .work: return .work
    case .custom: return .custom
    }
}

// MARK: - DSKProtoDataMessageContactPostalAddress

@objc
public class DSKProtoDataMessageContactPostalAddress: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactPostalAddressBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactPostalAddressBuilder {
        return DSKProtoDataMessageContactPostalAddressBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactPostalAddressBuilder {
        let builder = DSKProtoDataMessageContactPostalAddressBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = label {
            builder.setLabel(_value)
        }
        if let _value = street {
            builder.setStreet(_value)
        }
        if let _value = pobox {
            builder.setPobox(_value)
        }
        if let _value = neighborhood {
            builder.setNeighborhood(_value)
        }
        if let _value = city {
            builder.setCity(_value)
        }
        if let _value = region {
            builder.setRegion(_value)
        }
        if let _value = postcode {
            builder.setPostcode(_value)
        }
        if let _value = country {
            builder.setCountry(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactPostalAddressBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact.PostalAddress()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoDataMessageContactPostalAddressType) {
            proto.type = DSKProtoDataMessageContactPostalAddressTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setLabel(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.label = valueParam
        }

        public func setLabel(_ valueParam: String) {
            proto.label = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setStreet(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.street = valueParam
        }

        public func setStreet(_ valueParam: String) {
            proto.street = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPobox(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.pobox = valueParam
        }

        public func setPobox(_ valueParam: String) {
            proto.pobox = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNeighborhood(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.neighborhood = valueParam
        }

        public func setNeighborhood(_ valueParam: String) {
            proto.neighborhood = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCity(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.city = valueParam
        }

        public func setCity(_ valueParam: String) {
            proto.city = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRegion(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.region = valueParam
        }

        public func setRegion(_ valueParam: String) {
            proto.region = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPostcode(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.postcode = valueParam
        }

        public func setPostcode(_ valueParam: String) {
            proto.postcode = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCountry(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.country = valueParam
        }

        public func setCountry(_ valueParam: String) {
            proto.country = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContactPostalAddress {
            return try DSKProtoDataMessageContactPostalAddress(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContactPostalAddress(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact.PostalAddress

    public var type: DSKProtoDataMessageContactPostalAddressType? {
        guard hasType else {
            return nil
        }
        return DSKProtoDataMessageContactPostalAddressTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoDataMessageContactPostalAddressType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: PostalAddress.type.")
        }
        return DSKProtoDataMessageContactPostalAddressTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var label: String? {
        guard hasLabel else {
            return nil
        }
        return proto.label
    }
    @objc
    public var hasLabel: Bool {
        return proto.hasLabel
    }

    @objc
    public var street: String? {
        guard hasStreet else {
            return nil
        }
        return proto.street
    }
    @objc
    public var hasStreet: Bool {
        return proto.hasStreet
    }

    @objc
    public var pobox: String? {
        guard hasPobox else {
            return nil
        }
        return proto.pobox
    }
    @objc
    public var hasPobox: Bool {
        return proto.hasPobox
    }

    @objc
    public var neighborhood: String? {
        guard hasNeighborhood else {
            return nil
        }
        return proto.neighborhood
    }
    @objc
    public var hasNeighborhood: Bool {
        return proto.hasNeighborhood
    }

    @objc
    public var city: String? {
        guard hasCity else {
            return nil
        }
        return proto.city
    }
    @objc
    public var hasCity: Bool {
        return proto.hasCity
    }

    @objc
    public var region: String? {
        guard hasRegion else {
            return nil
        }
        return proto.region
    }
    @objc
    public var hasRegion: Bool {
        return proto.hasRegion
    }

    @objc
    public var postcode: String? {
        guard hasPostcode else {
            return nil
        }
        return proto.postcode
    }
    @objc
    public var hasPostcode: Bool {
        return proto.hasPostcode
    }

    @objc
    public var country: String? {
        guard hasCountry else {
            return nil
        }
        return proto.country
    }
    @objc
    public var hasCountry: Bool {
        return proto.hasCountry
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact.PostalAddress) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact.PostalAddress(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact.PostalAddress) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageContactPostalAddress -

        // MARK: - End Validation Logic for DSKProtoDataMessageContactPostalAddress -

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

extension DSKProtoDataMessageContactPostalAddress {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContactPostalAddress.DSKProtoDataMessageContactPostalAddressBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContactPostalAddress? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContactAvatar

@objc
public class DSKProtoDataMessageContactAvatar: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactAvatarBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactAvatarBuilder {
        return DSKProtoDataMessageContactAvatarBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactAvatarBuilder {
        let builder = DSKProtoDataMessageContactAvatarBuilder()
        if let _value = avatar {
            builder.setAvatar(_value)
        }
        if hasIsProfile {
            builder.setIsProfile(isProfile)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactAvatarBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact.Avatar()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAvatar(_ valueParam: DSKProtoAttachmentPointer?) {
            guard let valueParam = valueParam else { return }
            proto.avatar = valueParam.proto
        }

        public func setAvatar(_ valueParam: DSKProtoAttachmentPointer) {
            proto.avatar = valueParam.proto
        }

        @objc
        public func setIsProfile(_ valueParam: Bool) {
            proto.isProfile = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContactAvatar {
            return try DSKProtoDataMessageContactAvatar(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContactAvatar(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact.Avatar

    @objc
    public let avatar: DSKProtoAttachmentPointer?

    @objc
    public var isProfile: Bool {
        return proto.isProfile
    }
    @objc
    public var hasIsProfile: Bool {
        return proto.hasIsProfile
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact.Avatar,
                 avatar: DSKProtoAttachmentPointer?) {
        self.proto = proto
        self.avatar = avatar
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact.Avatar(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact.Avatar) throws {
        var avatar: DSKProtoAttachmentPointer?
        if proto.hasAvatar {
            avatar = try DSKProtoAttachmentPointer(proto.avatar)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageContactAvatar -

        // MARK: - End Validation Logic for DSKProtoDataMessageContactAvatar -

        self.init(proto: proto,
                  avatar: avatar)
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

extension DSKProtoDataMessageContactAvatar {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContactAvatar.DSKProtoDataMessageContactAvatarBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContactAvatar? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageContact

@objc
public class DSKProtoDataMessageContact: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageContactBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageContactBuilder {
        return DSKProtoDataMessageContactBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageContactBuilder {
        let builder = DSKProtoDataMessageContactBuilder()
        if let _value = name {
            builder.setName(_value)
        }
        builder.setNumber(number)
        builder.setEmail(email)
        builder.setAddress(address)
        if let _value = avatar {
            builder.setAvatar(_value)
        }
        if let _value = organization {
            builder.setOrganization(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageContactBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Contact()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: DSKProtoDataMessageContactName?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam.proto
        }

        public func setName(_ valueParam: DSKProtoDataMessageContactName) {
            proto.name = valueParam.proto
        }

        @objc
        public func addNumber(_ valueParam: DSKProtoDataMessageContactPhone) {
            proto.number.append(valueParam.proto)
        }

        @objc
        public func setNumber(_ wrappedItems: [DSKProtoDataMessageContactPhone]) {
            proto.number = wrappedItems.map { $0.proto }
        }

        @objc
        public func addEmail(_ valueParam: DSKProtoDataMessageContactEmail) {
            proto.email.append(valueParam.proto)
        }

        @objc
        public func setEmail(_ wrappedItems: [DSKProtoDataMessageContactEmail]) {
            proto.email = wrappedItems.map { $0.proto }
        }

        @objc
        public func addAddress(_ valueParam: DSKProtoDataMessageContactPostalAddress) {
            proto.address.append(valueParam.proto)
        }

        @objc
        public func setAddress(_ wrappedItems: [DSKProtoDataMessageContactPostalAddress]) {
            proto.address = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAvatar(_ valueParam: DSKProtoDataMessageContactAvatar?) {
            guard let valueParam = valueParam else { return }
            proto.avatar = valueParam.proto
        }

        public func setAvatar(_ valueParam: DSKProtoDataMessageContactAvatar) {
            proto.avatar = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setOrganization(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.organization = valueParam
        }

        public func setOrganization(_ valueParam: String) {
            proto.organization = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageContact {
            return try DSKProtoDataMessageContact(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageContact(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Contact

    @objc
    public let name: DSKProtoDataMessageContactName?

    @objc
    public let number: [DSKProtoDataMessageContactPhone]

    @objc
    public let email: [DSKProtoDataMessageContactEmail]

    @objc
    public let address: [DSKProtoDataMessageContactPostalAddress]

    @objc
    public let avatar: DSKProtoDataMessageContactAvatar?

    @objc
    public var organization: String? {
        guard hasOrganization else {
            return nil
        }
        return proto.organization
    }
    @objc
    public var hasOrganization: Bool {
        return proto.hasOrganization
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Contact,
                 name: DSKProtoDataMessageContactName?,
                 number: [DSKProtoDataMessageContactPhone],
                 email: [DSKProtoDataMessageContactEmail],
                 address: [DSKProtoDataMessageContactPostalAddress],
                 avatar: DSKProtoDataMessageContactAvatar?) {
        self.proto = proto
        self.name = name
        self.number = number
        self.email = email
        self.address = address
        self.avatar = avatar
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Contact(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Contact) throws {
        var name: DSKProtoDataMessageContactName?
        if proto.hasName {
            name = try DSKProtoDataMessageContactName(proto.name)
        }

        var number: [DSKProtoDataMessageContactPhone] = []
        number = try proto.number.map { try DSKProtoDataMessageContactPhone($0) }

        var email: [DSKProtoDataMessageContactEmail] = []
        email = try proto.email.map { try DSKProtoDataMessageContactEmail($0) }

        var address: [DSKProtoDataMessageContactPostalAddress] = []
        address = try proto.address.map { try DSKProtoDataMessageContactPostalAddress($0) }

        var avatar: DSKProtoDataMessageContactAvatar?
        if proto.hasAvatar {
            avatar = try DSKProtoDataMessageContactAvatar(proto.avatar)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageContact -

        // MARK: - End Validation Logic for DSKProtoDataMessageContact -

        self.init(proto: proto,
                  name: name,
                  number: number,
                  email: email,
                  address: address,
                  avatar: avatar)
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

extension DSKProtoDataMessageContact {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageContact.DSKProtoDataMessageContactBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageContact? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageRecall

@objc
public class DSKProtoDataMessageRecall: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageRecallBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageRecallBuilder {
        return DSKProtoDataMessageRecallBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageRecallBuilder {
        let builder = DSKProtoDataMessageRecallBuilder()
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageRecallBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Recall()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageRecall {
            return try DSKProtoDataMessageRecall(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageRecall(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Recall

    @objc
    public let source: DSKProtoRealSource?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Recall,
                 source: DSKProtoRealSource?) {
        self.proto = proto
        self.source = source
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Recall(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Recall) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageRecall -

        // MARK: - End Validation Logic for DSKProtoDataMessageRecall -

        self.init(proto: proto,
                  source: source)
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

extension DSKProtoDataMessageRecall {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageRecall.DSKProtoDataMessageRecallBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageRecall? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageScreenShot

@objc
public class DSKProtoDataMessageScreenShot: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageScreenShotBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageScreenShotBuilder {
        return DSKProtoDataMessageScreenShotBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageScreenShotBuilder {
        let builder = DSKProtoDataMessageScreenShotBuilder()
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageScreenShotBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.ScreenShot()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageScreenShot {
            return try DSKProtoDataMessageScreenShot(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageScreenShot(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.ScreenShot

    @objc
    public let source: DSKProtoRealSource?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.ScreenShot,
                 source: DSKProtoRealSource?) {
        self.proto = proto
        self.source = source
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.ScreenShot(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.ScreenShot) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageScreenShot -

        // MARK: - End Validation Logic for DSKProtoDataMessageScreenShot -

        self.init(proto: proto,
                  source: source)
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

extension DSKProtoDataMessageScreenShot {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageScreenShot.DSKProtoDataMessageScreenShotBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageScreenShot? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageTaskPriority

@objc
public enum DSKProtoDataMessageTaskPriority: Int32 {
    case p0 = 1
    case p1 = 2
    case p2 = 3
}

private func DSKProtoDataMessageTaskPriorityWrap(_ value: DifftServiceProtos_DataMessage.Task.Priority) -> DSKProtoDataMessageTaskPriority {
    switch value {
    case .p0: return .p0
    case .p1: return .p1
    case .p2: return .p2
    }
}

private func DSKProtoDataMessageTaskPriorityUnwrap(_ value: DSKProtoDataMessageTaskPriority) -> DifftServiceProtos_DataMessage.Task.Priority {
    switch value {
    case .p0: return .p0
    case .p1: return .p1
    case .p2: return .p2
    }
}

// MARK: - DSKProtoDataMessageTaskStatus

@objc
public enum DSKProtoDataMessageTaskStatus: Int32 {
    case initial = 1
    case rejected = 11
    case completed = 12
    case canceled = 13
}

private func DSKProtoDataMessageTaskStatusWrap(_ value: DifftServiceProtos_DataMessage.Task.Status) -> DSKProtoDataMessageTaskStatus {
    switch value {
    case .initial: return .initial
    case .rejected: return .rejected
    case .completed: return .completed
    case .canceled: return .canceled
    }
}

private func DSKProtoDataMessageTaskStatusUnwrap(_ value: DSKProtoDataMessageTaskStatus) -> DifftServiceProtos_DataMessage.Task.Status {
    switch value {
    case .initial: return .initial
    case .rejected: return .rejected
    case .completed: return .completed
    case .canceled: return .canceled
    }
}

// MARK: - DSKProtoDataMessageTask

@objc
public class DSKProtoDataMessageTask: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageTaskBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageTaskBuilder {
        return DSKProtoDataMessageTaskBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageTaskBuilder {
        let builder = DSKProtoDataMessageTaskBuilder()
        if let _value = taskID {
            builder.setTaskID(_value)
        }
        if hasVersion {
            builder.setVersion(version)
        }
        if let _value = creator {
            builder.setCreator(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = name {
            builder.setName(_value)
        }
        if let _value = notes {
            builder.setNotes(_value)
        }
        builder.setAssignees(assignees)
        if hasDueTime {
            builder.setDueTime(dueTime)
        }
        if hasPriority {
            builder.setPriority(priority)
        }
        builder.setFollowers(followers)
        if hasStatus {
            builder.setStatus(status)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageTaskBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Task()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTaskID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.taskID = valueParam
        }

        public func setTaskID(_ valueParam: String) {
            proto.taskID = valueParam
        }

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCreator(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.creator = valueParam
        }

        public func setCreator(_ valueParam: String) {
            proto.creator = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNotes(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.notes = valueParam
        }

        public func setNotes(_ valueParam: String) {
            proto.notes = valueParam
        }

        @objc
        public func addAssignees(_ valueParam: String) {
            proto.assignees.append(valueParam)
        }

        @objc
        public func setAssignees(_ wrappedItems: [String]) {
            proto.assignees = wrappedItems
        }

        @objc
        public func setDueTime(_ valueParam: UInt64) {
            proto.dueTime = valueParam
        }

        @objc
        public func setPriority(_ valueParam: UInt32) {
            proto.priority = valueParam
        }

        @objc
        public func addFollowers(_ valueParam: String) {
            proto.followers.append(valueParam)
        }

        @objc
        public func setFollowers(_ wrappedItems: [String]) {
            proto.followers = wrappedItems
        }

        @objc
        public func setStatus(_ valueParam: UInt32) {
            proto.status = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageTask {
            return try DSKProtoDataMessageTask(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageTask(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Task

    @objc
    public var taskID: String? {
        guard hasTaskID else {
            return nil
        }
        return proto.taskID
    }
    @objc
    public var hasTaskID: Bool {
        return proto.hasTaskID
    }

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    @objc
    public var creator: String? {
        guard hasCreator else {
            return nil
        }
        return proto.creator
    }
    @objc
    public var hasCreator: Bool {
        return proto.hasCreator
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    @objc
    public var notes: String? {
        guard hasNotes else {
            return nil
        }
        return proto.notes
    }
    @objc
    public var hasNotes: Bool {
        return proto.hasNotes
    }

    @objc
    public var assignees: [String] {
        return proto.assignees
    }

    @objc
    public var dueTime: UInt64 {
        return proto.dueTime
    }
    @objc
    public var hasDueTime: Bool {
        return proto.hasDueTime
    }

    @objc
    public var priority: UInt32 {
        return proto.priority
    }
    @objc
    public var hasPriority: Bool {
        return proto.hasPriority
    }

    @objc
    public var followers: [String] {
        return proto.followers
    }

    @objc
    public var status: UInt32 {
        return proto.status
    }
    @objc
    public var hasStatus: Bool {
        return proto.hasStatus
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Task) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Task(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Task) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageTask -

        // MARK: - End Validation Logic for DSKProtoDataMessageTask -

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

extension DSKProtoDataMessageTask {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageTask.DSKProtoDataMessageTaskBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageTask? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageVoteOption

@objc
public class DSKProtoDataMessageVoteOption: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageVoteOptionBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageVoteOptionBuilder {
        return DSKProtoDataMessageVoteOptionBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageVoteOptionBuilder {
        let builder = DSKProtoDataMessageVoteOptionBuilder()
        if hasID {
            builder.setId(id)
        }
        if let _value = name {
            builder.setName(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageVoteOptionBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Vote.Option()

        @objc
        fileprivate override init() {}

        @objc
        public func setId(_ valueParam: UInt32) {
            proto.id = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageVoteOption {
            return try DSKProtoDataMessageVoteOption(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageVoteOption(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Vote.Option

    @objc
    public var id: UInt32 {
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    @objc
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Vote.Option) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Vote.Option(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Vote.Option) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageVoteOption -

        // MARK: - End Validation Logic for DSKProtoDataMessageVoteOption -

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

extension DSKProtoDataMessageVoteOption {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageVoteOption.DSKProtoDataMessageVoteOptionBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageVoteOption? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageVoteStatus

@objc
public enum DSKProtoDataMessageVoteStatus: Int32 {
    case initial = 1
    case closed = 2
}

private func DSKProtoDataMessageVoteStatusWrap(_ value: DifftServiceProtos_DataMessage.Vote.Status) -> DSKProtoDataMessageVoteStatus {
    switch value {
    case .initial: return .initial
    case .closed: return .closed
    }
}

private func DSKProtoDataMessageVoteStatusUnwrap(_ value: DSKProtoDataMessageVoteStatus) -> DifftServiceProtos_DataMessage.Vote.Status {
    switch value {
    case .initial: return .initial
    case .closed: return .closed
    }
}

// MARK: - DSKProtoDataMessageVote

@objc
public class DSKProtoDataMessageVote: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageVoteBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageVoteBuilder {
        return DSKProtoDataMessageVoteBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageVoteBuilder {
        let builder = DSKProtoDataMessageVoteBuilder()
        if let _value = voteID {
            builder.setVoteID(_value)
        }
        if hasVersion {
            builder.setVersion(version)
        }
        if let _value = creator {
            builder.setCreator(_value)
        }
        if let _value = name {
            builder.setName(_value)
        }
        builder.setOptions(options)
        if hasMultiple {
            builder.setMultiple(multiple)
        }
        if hasDueTime {
            builder.setDueTime(dueTime)
        }
        if hasStatus {
            builder.setStatus(status)
        }
        if hasAnonymous {
            builder.setAnonymous(anonymous)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageVoteBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Vote()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setVoteID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.voteID = valueParam
        }

        public func setVoteID(_ valueParam: String) {
            proto.voteID = valueParam
        }

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCreator(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.creator = valueParam
        }

        public func setCreator(_ valueParam: String) {
            proto.creator = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        @objc
        public func addOptions(_ valueParam: DSKProtoDataMessageVoteOption) {
            proto.options.append(valueParam.proto)
        }

        @objc
        public func setOptions(_ wrappedItems: [DSKProtoDataMessageVoteOption]) {
            proto.options = wrappedItems.map { $0.proto }
        }

        @objc
        public func setMultiple(_ valueParam: Bool) {
            proto.multiple = valueParam
        }

        @objc
        public func setDueTime(_ valueParam: UInt64) {
            proto.dueTime = valueParam
        }

        @objc
        public func setStatus(_ valueParam: UInt32) {
            proto.status = valueParam
        }

        @objc
        public func setAnonymous(_ valueParam: UInt32) {
            proto.anonymous = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageVote {
            return try DSKProtoDataMessageVote(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageVote(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Vote

    @objc
    public let options: [DSKProtoDataMessageVoteOption]

    @objc
    public var voteID: String? {
        guard hasVoteID else {
            return nil
        }
        return proto.voteID
    }
    @objc
    public var hasVoteID: Bool {
        return proto.hasVoteID
    }

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    @objc
    public var creator: String? {
        guard hasCreator else {
            return nil
        }
        return proto.creator
    }
    @objc
    public var hasCreator: Bool {
        return proto.hasCreator
    }

    @objc
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    @objc
    public var multiple: Bool {
        return proto.multiple
    }
    @objc
    public var hasMultiple: Bool {
        return proto.hasMultiple
    }

    @objc
    public var dueTime: UInt64 {
        return proto.dueTime
    }
    @objc
    public var hasDueTime: Bool {
        return proto.hasDueTime
    }

    @objc
    public var status: UInt32 {
        return proto.status
    }
    @objc
    public var hasStatus: Bool {
        return proto.hasStatus
    }

    @objc
    public var anonymous: UInt32 {
        return proto.anonymous
    }
    @objc
    public var hasAnonymous: Bool {
        return proto.hasAnonymous
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Vote,
                 options: [DSKProtoDataMessageVoteOption]) {
        self.proto = proto
        self.options = options
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Vote(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Vote) throws {
        var options: [DSKProtoDataMessageVoteOption] = []
        options = try proto.options.map { try DSKProtoDataMessageVoteOption($0) }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageVote -

        // MARK: - End Validation Logic for DSKProtoDataMessageVote -

        self.init(proto: proto,
                  options: options)
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

extension DSKProtoDataMessageVote {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageVote.DSKProtoDataMessageVoteBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageVote? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageReaction

@objc
public class DSKProtoDataMessageReaction: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageReactionBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageReactionBuilder {
        return DSKProtoDataMessageReactionBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageReactionBuilder {
        let builder = DSKProtoDataMessageReactionBuilder()
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = emoji {
            builder.setEmoji(_value)
        }
        if hasRemove {
            builder.setRemove(remove)
        }
        if hasOriginTimestamp {
            builder.setOriginTimestamp(originTimestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageReactionBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Reaction()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setEmoji(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.emoji = valueParam
        }

        public func setEmoji(_ valueParam: String) {
            proto.emoji = valueParam
        }

        @objc
        public func setRemove(_ valueParam: Bool) {
            proto.remove = valueParam
        }

        @objc
        public func setOriginTimestamp(_ valueParam: UInt64) {
            proto.originTimestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageReaction {
            return try DSKProtoDataMessageReaction(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageReaction(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Reaction

    @objc
    public let source: DSKProtoRealSource?

    @objc
    public var emoji: String? {
        guard hasEmoji else {
            return nil
        }
        return proto.emoji
    }
    @objc
    public var hasEmoji: Bool {
        return proto.hasEmoji
    }

    @objc
    public var remove: Bool {
        return proto.remove
    }
    @objc
    public var hasRemove: Bool {
        return proto.hasRemove
    }

    @objc
    public var originTimestamp: UInt64 {
        return proto.originTimestamp
    }
    @objc
    public var hasOriginTimestamp: Bool {
        return proto.hasOriginTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Reaction,
                 source: DSKProtoRealSource?) {
        self.proto = proto
        self.source = source
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Reaction(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Reaction) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageReaction -

        // MARK: - End Validation Logic for DSKProtoDataMessageReaction -

        self.init(proto: proto,
                  source: source)
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

extension DSKProtoDataMessageReaction {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageReaction.DSKProtoDataMessageReactionBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageReaction? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageMentionType

@objc
public enum DSKProtoDataMessageMentionType: Int32 {
    case `internal` = 0
    case external = 1
}

private func DSKProtoDataMessageMentionTypeWrap(_ value: DifftServiceProtos_DataMessage.Mention.TypeEnum) -> DSKProtoDataMessageMentionType {
    switch value {
    case .internal: return .internal
    case .external: return .external
    }
}

private func DSKProtoDataMessageMentionTypeUnwrap(_ value: DSKProtoDataMessageMentionType) -> DifftServiceProtos_DataMessage.Mention.TypeEnum {
    switch value {
    case .internal: return .internal
    case .external: return .external
    }
}

// MARK: - DSKProtoDataMessageMention

@objc
public class DSKProtoDataMessageMention: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageMentionBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageMentionBuilder {
        return DSKProtoDataMessageMentionBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageMentionBuilder {
        let builder = DSKProtoDataMessageMentionBuilder()
        if hasStart {
            builder.setStart(start)
        }
        if hasLength {
            builder.setLength(length)
        }
        if let _value = uid {
            builder.setUid(_value)
        }
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageMentionBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.Mention()

        @objc
        fileprivate override init() {}

        @objc
        public func setStart(_ valueParam: UInt32) {
            proto.start = valueParam
        }

        @objc
        public func setLength(_ valueParam: UInt32) {
            proto.length = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setUid(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.uid = valueParam
        }

        public func setUid(_ valueParam: String) {
            proto.uid = valueParam
        }

        @objc
        public func setType(_ valueParam: DSKProtoDataMessageMentionType) {
            proto.type = DSKProtoDataMessageMentionTypeUnwrap(valueParam)
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageMention {
            return try DSKProtoDataMessageMention(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageMention(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.Mention

    @objc
    public var start: UInt32 {
        return proto.start
    }
    @objc
    public var hasStart: Bool {
        return proto.hasStart
    }

    @objc
    public var length: UInt32 {
        return proto.length
    }
    @objc
    public var hasLength: Bool {
        return proto.hasLength
    }

    @objc
    public var uid: String? {
        guard hasUid else {
            return nil
        }
        return proto.uid
    }
    @objc
    public var hasUid: Bool {
        return proto.hasUid
    }

    public var type: DSKProtoDataMessageMentionType? {
        guard hasType else {
            return nil
        }
        return DSKProtoDataMessageMentionTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoDataMessageMentionType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Mention.type.")
        }
        return DSKProtoDataMessageMentionTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.Mention) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.Mention(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.Mention) throws {
        // MARK: - Begin Validation Logic for DSKProtoDataMessageMention -

        // MARK: - End Validation Logic for DSKProtoDataMessageMention -

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

extension DSKProtoDataMessageMention {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageMention.DSKProtoDataMessageMentionBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageMention? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageBotContextType

@objc
public enum DSKProtoDataMessageBotContextType: Int32 {
    case support = 1
    case announcement = 2
}

private func DSKProtoDataMessageBotContextTypeWrap(_ value: DifftServiceProtos_DataMessage.BotContext.TypeEnum) -> DSKProtoDataMessageBotContextType {
    switch value {
    case .support: return .support
    case .announcement: return .announcement
    }
}

private func DSKProtoDataMessageBotContextTypeUnwrap(_ value: DSKProtoDataMessageBotContextType) -> DifftServiceProtos_DataMessage.BotContext.TypeEnum {
    switch value {
    case .support: return .support
    case .announcement: return .announcement
    }
}

// MARK: - DSKProtoDataMessageBotContext

@objc
public class DSKProtoDataMessageBotContext: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageBotContextBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageBotContextBuilder {
        return DSKProtoDataMessageBotContextBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageBotContextBuilder {
        let builder = DSKProtoDataMessageBotContextBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = source {
            builder.setSource(_value)
        }
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if let _value = header {
            builder.setHeader(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageBotContextBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.BotContext()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoDataMessageBotContextType) {
            proto.type = DSKProtoDataMessageBotContextTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setHeader(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.header = valueParam
        }

        public func setHeader(_ valueParam: String) {
            proto.header = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageBotContext {
            return try DSKProtoDataMessageBotContext(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageBotContext(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.BotContext

    @objc
    public let source: DSKProtoRealSource?

    public var type: DSKProtoDataMessageBotContextType? {
        guard hasType else {
            return nil
        }
        return DSKProtoDataMessageBotContextTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoDataMessageBotContextType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: BotContext.type.")
        }
        return DSKProtoDataMessageBotContextTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    @objc
    public var header: String? {
        guard hasHeader else {
            return nil
        }
        return proto.header
    }
    @objc
    public var hasHeader: Bool {
        return proto.hasHeader
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.BotContext,
                 source: DSKProtoRealSource?) {
        self.proto = proto
        self.source = source
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.BotContext(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.BotContext) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageBotContext -

        // MARK: - End Validation Logic for DSKProtoDataMessageBotContext -

        self.init(proto: proto,
                  source: source)
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

extension DSKProtoDataMessageBotContext {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageBotContext.DSKProtoDataMessageBotContextBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageBotContext? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageThreadContext

@objc
public class DSKProtoDataMessageThreadContext: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageThreadContextBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageThreadContextBuilder {
        return DSKProtoDataMessageThreadContextBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageThreadContextBuilder {
        let builder = DSKProtoDataMessageThreadContextBuilder()
        if let _value = source {
            builder.setSource(_value)
        }
        if hasReplyToUser {
            builder.setReplyToUser(replyToUser)
        }
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if let _value = botID {
            builder.setBotID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageThreadContextBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage.ThreadContext()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.source = valueParam.proto
        }

        public func setSource(_ valueParam: DSKProtoRealSource) {
            proto.source = valueParam.proto
        }

        @objc
        public func setReplyToUser(_ valueParam: Bool) {
            proto.replyToUser = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBotID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.botID = valueParam
        }

        public func setBotID(_ valueParam: String) {
            proto.botID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessageThreadContext {
            return try DSKProtoDataMessageThreadContext(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessageThreadContext(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage.ThreadContext

    @objc
    public let source: DSKProtoRealSource?

    @objc
    public var replyToUser: Bool {
        return proto.replyToUser
    }
    @objc
    public var hasReplyToUser: Bool {
        return proto.hasReplyToUser
    }

    @objc
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    @objc
    public var botID: String? {
        guard hasBotID else {
            return nil
        }
        return proto.botID
    }
    @objc
    public var hasBotID: Bool {
        return proto.hasBotID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage.ThreadContext,
                 source: DSKProtoRealSource?) {
        self.proto = proto
        self.source = source
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage.ThreadContext(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage.ThreadContext) throws {
        var source: DSKProtoRealSource?
        if proto.hasSource {
            source = try DSKProtoRealSource(proto.source)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessageThreadContext -

        // MARK: - End Validation Logic for DSKProtoDataMessageThreadContext -

        self.init(proto: proto,
                  source: source)
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

extension DSKProtoDataMessageThreadContext {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessageThreadContext.DSKProtoDataMessageThreadContextBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessageThreadContext? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoDataMessageFlags

@objc
public enum DSKProtoDataMessageFlags: Int32 {
    case endSession = 1
    case expirationTimerUpdate = 2
    case profileKeyUpdate = 4
}

private func DSKProtoDataMessageFlagsWrap(_ value: DifftServiceProtos_DataMessage.Flags) -> DSKProtoDataMessageFlags {
    switch value {
    case .endSession: return .endSession
    case .expirationTimerUpdate: return .expirationTimerUpdate
    case .profileKeyUpdate: return .profileKeyUpdate
    }
}

private func DSKProtoDataMessageFlagsUnwrap(_ value: DSKProtoDataMessageFlags) -> DifftServiceProtos_DataMessage.Flags {
    switch value {
    case .endSession: return .endSession
    case .expirationTimerUpdate: return .expirationTimerUpdate
    case .profileKeyUpdate: return .profileKeyUpdate
    }
}

// MARK: - DSKProtoDataMessageProtocolVersion

@objc
public enum DSKProtoDataMessageProtocolVersion: Int32 {
    case initial = 0
    case forward = 1
    case contact = 2
    case recall = 3
    case task = 4
    case vote = 5
    case reaction = 6
    case card = 7
    case confide = 8
    case screenShot = 9
    case verify = 10
}

private func DSKProtoDataMessageProtocolVersionWrap(_ value: DifftServiceProtos_DataMessage.ProtocolVersion) -> DSKProtoDataMessageProtocolVersion {
    switch value {
    case .initial: return .initial
    case .forward: return .forward
    case .contact: return .contact
    case .recall: return .recall
    case .task: return .task
    case .vote: return .vote
    case .reaction: return .reaction
    case .card: return .card
    case .confide: return .confide
    case .screenShot: return .screenShot
    case .verify: return .verify
    }
}

private func DSKProtoDataMessageProtocolVersionUnwrap(_ value: DSKProtoDataMessageProtocolVersion) -> DifftServiceProtos_DataMessage.ProtocolVersion {
    switch value {
    case .initial: return .initial
    case .forward: return .forward
    case .contact: return .contact
    case .recall: return .recall
    case .task: return .task
    case .vote: return .vote
    case .reaction: return .reaction
    case .card: return .card
    case .confide: return .confide
    case .screenShot: return .screenShot
    case .verify: return .verify
    }
}

// MARK: - DSKProtoDataMessageMessageMode

@objc
public enum DSKProtoDataMessageMessageMode: Int32 {
    case normal = 0
    case confidential = 1
}

private func DSKProtoDataMessageMessageModeWrap(_ value: DifftServiceProtos_DataMessage.MessageMode) -> DSKProtoDataMessageMessageMode {
    switch value {
    case .normal: return .normal
    case .confidential: return .confidential
    }
}

private func DSKProtoDataMessageMessageModeUnwrap(_ value: DSKProtoDataMessageMessageMode) -> DifftServiceProtos_DataMessage.MessageMode {
    switch value {
    case .normal: return .normal
    case .confidential: return .confidential
    }
}

// MARK: - DSKProtoDataMessage

@objc
public class DSKProtoDataMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoDataMessageBuilder

    @objc
    public static func builder() -> DSKProtoDataMessageBuilder {
        return DSKProtoDataMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoDataMessageBuilder {
        let builder = DSKProtoDataMessageBuilder()
        if let _value = body {
            builder.setBody(_value)
        }
        builder.setAttachments(attachments)
        if let _value = group {
            builder.setGroup(_value)
        }
        if hasFlags {
            builder.setFlags(flags)
        }
        if hasExpireTimer {
            builder.setExpireTimer(expireTimer)
        }
        if let _value = profileKey {
            builder.setProfileKey(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = quote {
            builder.setQuote(_value)
        }
        if let _value = atPersons {
            builder.setAtPersons(_value)
        }
        if let _value = forwardContext {
            builder.setForwardContext(_value)
        }
        if hasRequiredProtocolVersion {
            builder.setRequiredProtocolVersion(requiredProtocolVersion)
        }
        builder.setContact(contact)
        if let _value = recall {
            builder.setRecall(_value)
        }
        if let _value = task {
            builder.setTask(_value)
        }
        if let _value = vote {
            builder.setVote(_value)
        }
        if let _value = botContext {
            builder.setBotContext(_value)
        }
        if let _value = threadContext {
            builder.setThreadContext(_value)
        }
        if let _value = topicContext {
            builder.setTopicContext(_value)
        }
        if let _value = reaction {
            builder.setReaction(_value)
        }
        if let _value = card {
            builder.setCard(_value)
        }
        builder.setMentions(mentions)
        if hasMessageMode {
            builder.setMessageMode(messageMode)
        }
        if let _value = screenShot {
            builder.setScreenShot(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoDataMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_DataMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBody(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.body = valueParam
        }

        public func setBody(_ valueParam: String) {
            proto.body = valueParam
        }

        @objc
        public func addAttachments(_ valueParam: DSKProtoAttachmentPointer) {
            proto.attachments.append(valueParam.proto)
        }

        @objc
        public func setAttachments(_ wrappedItems: [DSKProtoAttachmentPointer]) {
            proto.attachments = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroup(_ valueParam: DSKProtoGroupContext?) {
            guard let valueParam = valueParam else { return }
            proto.group = valueParam.proto
        }

        public func setGroup(_ valueParam: DSKProtoGroupContext) {
            proto.group = valueParam.proto
        }

        @objc
        public func setFlags(_ valueParam: UInt32) {
            proto.flags = valueParam
        }

        @objc
        public func setExpireTimer(_ valueParam: UInt32) {
            proto.expireTimer = valueParam
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
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setQuote(_ valueParam: DSKProtoDataMessageQuote?) {
            guard let valueParam = valueParam else { return }
            proto.quote = valueParam.proto
        }

        public func setQuote(_ valueParam: DSKProtoDataMessageQuote) {
            proto.quote = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAtPersons(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.atPersons = valueParam
        }

        public func setAtPersons(_ valueParam: String) {
            proto.atPersons = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setForwardContext(_ valueParam: DSKProtoDataMessageForwardContext?) {
            guard let valueParam = valueParam else { return }
            proto.forwardContext = valueParam.proto
        }

        public func setForwardContext(_ valueParam: DSKProtoDataMessageForwardContext) {
            proto.forwardContext = valueParam.proto
        }

        @objc
        public func setRequiredProtocolVersion(_ valueParam: UInt32) {
            proto.requiredProtocolVersion = valueParam
        }

        @objc
        public func addContact(_ valueParam: DSKProtoDataMessageContact) {
            proto.contact.append(valueParam.proto)
        }

        @objc
        public func setContact(_ wrappedItems: [DSKProtoDataMessageContact]) {
            proto.contact = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRecall(_ valueParam: DSKProtoDataMessageRecall?) {
            guard let valueParam = valueParam else { return }
            proto.recall = valueParam.proto
        }

        public func setRecall(_ valueParam: DSKProtoDataMessageRecall) {
            proto.recall = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTask(_ valueParam: DSKProtoDataMessageTask?) {
            guard let valueParam = valueParam else { return }
            proto.task = valueParam.proto
        }

        public func setTask(_ valueParam: DSKProtoDataMessageTask) {
            proto.task = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setVote(_ valueParam: DSKProtoDataMessageVote?) {
            guard let valueParam = valueParam else { return }
            proto.vote = valueParam.proto
        }

        public func setVote(_ valueParam: DSKProtoDataMessageVote) {
            proto.vote = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBotContext(_ valueParam: DSKProtoDataMessageBotContext?) {
            guard let valueParam = valueParam else { return }
            proto.botContext = valueParam.proto
        }

        public func setBotContext(_ valueParam: DSKProtoDataMessageBotContext) {
            proto.botContext = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setThreadContext(_ valueParam: DSKProtoDataMessageThreadContext?) {
            guard let valueParam = valueParam else { return }
            proto.threadContext = valueParam.proto
        }

        public func setThreadContext(_ valueParam: DSKProtoDataMessageThreadContext) {
            proto.threadContext = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicContext(_ valueParam: DSKProtoTopicContext?) {
            guard let valueParam = valueParam else { return }
            proto.topicContext = valueParam.proto
        }

        public func setTopicContext(_ valueParam: DSKProtoTopicContext) {
            proto.topicContext = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReaction(_ valueParam: DSKProtoDataMessageReaction?) {
            guard let valueParam = valueParam else { return }
            proto.reaction = valueParam.proto
        }

        public func setReaction(_ valueParam: DSKProtoDataMessageReaction) {
            proto.reaction = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setCard(_ valueParam: DSKProtoCard?) {
            guard let valueParam = valueParam else { return }
            proto.card = valueParam.proto
        }

        public func setCard(_ valueParam: DSKProtoCard) {
            proto.card = valueParam.proto
        }

        @objc
        public func addMentions(_ valueParam: DSKProtoDataMessageMention) {
            proto.mentions.append(valueParam.proto)
        }

        @objc
        public func setMentions(_ wrappedItems: [DSKProtoDataMessageMention]) {
            proto.mentions = wrappedItems.map { $0.proto }
        }

        @objc
        public func setMessageMode(_ valueParam: UInt32) {
            proto.messageMode = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setScreenShot(_ valueParam: DSKProtoDataMessageScreenShot?) {
            guard let valueParam = valueParam else { return }
            proto.screenShot = valueParam.proto
        }

        public func setScreenShot(_ valueParam: DSKProtoDataMessageScreenShot) {
            proto.screenShot = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoDataMessage {
            return try DSKProtoDataMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoDataMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_DataMessage

    @objc
    public let attachments: [DSKProtoAttachmentPointer]

    @objc
    public let group: DSKProtoGroupContext?

    @objc
    public let quote: DSKProtoDataMessageQuote?

    @objc
    public let forwardContext: DSKProtoDataMessageForwardContext?

    @objc
    public let contact: [DSKProtoDataMessageContact]

    @objc
    public let recall: DSKProtoDataMessageRecall?

    @objc
    public let task: DSKProtoDataMessageTask?

    @objc
    public let vote: DSKProtoDataMessageVote?

    @objc
    public let botContext: DSKProtoDataMessageBotContext?

    @objc
    public let threadContext: DSKProtoDataMessageThreadContext?

    @objc
    public let topicContext: DSKProtoTopicContext?

    @objc
    public let reaction: DSKProtoDataMessageReaction?

    @objc
    public let card: DSKProtoCard?

    @objc
    public let mentions: [DSKProtoDataMessageMention]

    @objc
    public let screenShot: DSKProtoDataMessageScreenShot?

    @objc
    public var body: String? {
        guard hasBody else {
            return nil
        }
        return proto.body
    }
    @objc
    public var hasBody: Bool {
        return proto.hasBody
    }

    @objc
    public var flags: UInt32 {
        return proto.flags
    }
    @objc
    public var hasFlags: Bool {
        return proto.hasFlags
    }

    @objc
    public var expireTimer: UInt32 {
        return proto.expireTimer
    }
    @objc
    public var hasExpireTimer: Bool {
        return proto.hasExpireTimer
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
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var atPersons: String? {
        guard hasAtPersons else {
            return nil
        }
        return proto.atPersons
    }
    @objc
    public var hasAtPersons: Bool {
        return proto.hasAtPersons
    }

    @objc
    public var requiredProtocolVersion: UInt32 {
        return proto.requiredProtocolVersion
    }
    @objc
    public var hasRequiredProtocolVersion: Bool {
        return proto.hasRequiredProtocolVersion
    }

    @objc
    public var messageMode: UInt32 {
        return proto.messageMode
    }
    @objc
    public var hasMessageMode: Bool {
        return proto.hasMessageMode
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_DataMessage,
                 attachments: [DSKProtoAttachmentPointer],
                 group: DSKProtoGroupContext?,
                 quote: DSKProtoDataMessageQuote?,
                 forwardContext: DSKProtoDataMessageForwardContext?,
                 contact: [DSKProtoDataMessageContact],
                 recall: DSKProtoDataMessageRecall?,
                 task: DSKProtoDataMessageTask?,
                 vote: DSKProtoDataMessageVote?,
                 botContext: DSKProtoDataMessageBotContext?,
                 threadContext: DSKProtoDataMessageThreadContext?,
                 topicContext: DSKProtoTopicContext?,
                 reaction: DSKProtoDataMessageReaction?,
                 card: DSKProtoCard?,
                 mentions: [DSKProtoDataMessageMention],
                 screenShot: DSKProtoDataMessageScreenShot?) {
        self.proto = proto
        self.attachments = attachments
        self.group = group
        self.quote = quote
        self.forwardContext = forwardContext
        self.contact = contact
        self.recall = recall
        self.task = task
        self.vote = vote
        self.botContext = botContext
        self.threadContext = threadContext
        self.topicContext = topicContext
        self.reaction = reaction
        self.card = card
        self.mentions = mentions
        self.screenShot = screenShot
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_DataMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_DataMessage) throws {
        var attachments: [DSKProtoAttachmentPointer] = []
        attachments = try proto.attachments.map { try DSKProtoAttachmentPointer($0) }

        var group: DSKProtoGroupContext?
        if proto.hasGroup {
            group = try DSKProtoGroupContext(proto.group)
        }

        var quote: DSKProtoDataMessageQuote?
        if proto.hasQuote {
            quote = try DSKProtoDataMessageQuote(proto.quote)
        }

        var forwardContext: DSKProtoDataMessageForwardContext?
        if proto.hasForwardContext {
            forwardContext = try DSKProtoDataMessageForwardContext(proto.forwardContext)
        }

        var contact: [DSKProtoDataMessageContact] = []
        contact = try proto.contact.map { try DSKProtoDataMessageContact($0) }

        var recall: DSKProtoDataMessageRecall?
        if proto.hasRecall {
            recall = try DSKProtoDataMessageRecall(proto.recall)
        }

        var task: DSKProtoDataMessageTask?
        if proto.hasTask {
            task = try DSKProtoDataMessageTask(proto.task)
        }

        var vote: DSKProtoDataMessageVote?
        if proto.hasVote {
            vote = try DSKProtoDataMessageVote(proto.vote)
        }

        var botContext: DSKProtoDataMessageBotContext?
        if proto.hasBotContext {
            botContext = try DSKProtoDataMessageBotContext(proto.botContext)
        }

        var threadContext: DSKProtoDataMessageThreadContext?
        if proto.hasThreadContext {
            threadContext = try DSKProtoDataMessageThreadContext(proto.threadContext)
        }

        var topicContext: DSKProtoTopicContext?
        if proto.hasTopicContext {
            topicContext = try DSKProtoTopicContext(proto.topicContext)
        }

        var reaction: DSKProtoDataMessageReaction?
        if proto.hasReaction {
            reaction = try DSKProtoDataMessageReaction(proto.reaction)
        }

        var card: DSKProtoCard?
        if proto.hasCard {
            card = try DSKProtoCard(proto.card)
        }

        var mentions: [DSKProtoDataMessageMention] = []
        mentions = try proto.mentions.map { try DSKProtoDataMessageMention($0) }

        var screenShot: DSKProtoDataMessageScreenShot?
        if proto.hasScreenShot {
            screenShot = try DSKProtoDataMessageScreenShot(proto.screenShot)
        }

        // MARK: - Begin Validation Logic for DSKProtoDataMessage -

        // MARK: - End Validation Logic for DSKProtoDataMessage -

        self.init(proto: proto,
                  attachments: attachments,
                  group: group,
                  quote: quote,
                  forwardContext: forwardContext,
                  contact: contact,
                  recall: recall,
                  task: task,
                  vote: vote,
                  botContext: botContext,
                  threadContext: threadContext,
                  topicContext: topicContext,
                  reaction: reaction,
                  card: card,
                  mentions: mentions,
                  screenShot: screenShot)
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

extension DSKProtoDataMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoDataMessage.DSKProtoDataMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoDataMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoNullMessage

@objc
public class DSKProtoNullMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoNullMessageBuilder

    @objc
    public static func builder() -> DSKProtoNullMessageBuilder {
        return DSKProtoNullMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoNullMessageBuilder {
        let builder = DSKProtoNullMessageBuilder()
        if let _value = padding {
            builder.setPadding(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoNullMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_NullMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPadding(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.padding = valueParam
        }

        public func setPadding(_ valueParam: Data) {
            proto.padding = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoNullMessage {
            return try DSKProtoNullMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoNullMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_NullMessage

    @objc
    public var padding: Data? {
        guard hasPadding else {
            return nil
        }
        return proto.padding
    }
    @objc
    public var hasPadding: Bool {
        return proto.hasPadding
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_NullMessage) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_NullMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_NullMessage) throws {
        // MARK: - Begin Validation Logic for DSKProtoNullMessage -

        // MARK: - End Validation Logic for DSKProtoNullMessage -

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

extension DSKProtoNullMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoNullMessage.DSKProtoNullMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoNullMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoReceiptMessageType

@objc
public enum DSKProtoReceiptMessageType: Int32 {
    case delivery = 0
    case read = 1
}

private func DSKProtoReceiptMessageTypeWrap(_ value: DifftServiceProtos_ReceiptMessage.TypeEnum) -> DSKProtoReceiptMessageType {
    switch value {
    case .delivery: return .delivery
    case .read: return .read
    }
}

private func DSKProtoReceiptMessageTypeUnwrap(_ value: DSKProtoReceiptMessageType) -> DifftServiceProtos_ReceiptMessage.TypeEnum {
    switch value {
    case .delivery: return .delivery
    case .read: return .read
    }
}

// MARK: - DSKProtoReceiptMessage

@objc
public class DSKProtoReceiptMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoReceiptMessageBuilder

    @objc
    public static func builder() -> DSKProtoReceiptMessageBuilder {
        return DSKProtoReceiptMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoReceiptMessageBuilder {
        let builder = DSKProtoReceiptMessageBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        builder.setTimestamp(timestamp)
        if let _value = readPosition {
            builder.setReadPosition(_value)
        }
        if hasMessageMode {
            builder.setMessageMode(messageMode)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoReceiptMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_ReceiptMessage()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoReceiptMessageType) {
            proto.type = DSKProtoReceiptMessageTypeUnwrap(valueParam)
        }

        @objc
        public func addTimestamp(_ valueParam: UInt64) {
            proto.timestamp.append(valueParam)
        }

        @objc
        public func setTimestamp(_ wrappedItems: [UInt64]) {
            proto.timestamp = wrappedItems
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReadPosition(_ valueParam: DSKProtoReadPosition?) {
            guard let valueParam = valueParam else { return }
            proto.readPosition = valueParam.proto
        }

        public func setReadPosition(_ valueParam: DSKProtoReadPosition) {
            proto.readPosition = valueParam.proto
        }

        @objc
        public func setMessageMode(_ valueParam: UInt32) {
            proto.messageMode = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoReceiptMessage {
            return try DSKProtoReceiptMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoReceiptMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ReceiptMessage

    @objc
    public let readPosition: DSKProtoReadPosition?

    public var type: DSKProtoReceiptMessageType? {
        guard hasType else {
            return nil
        }
        return DSKProtoReceiptMessageTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoReceiptMessageType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: ReceiptMessage.type.")
        }
        return DSKProtoReceiptMessageTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var timestamp: [UInt64] {
        return proto.timestamp
    }

    @objc
    public var messageMode: UInt32 {
        return proto.messageMode
    }
    @objc
    public var hasMessageMode: Bool {
        return proto.hasMessageMode
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ReceiptMessage,
                 readPosition: DSKProtoReadPosition?) {
        self.proto = proto
        self.readPosition = readPosition
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ReceiptMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ReceiptMessage) throws {
        var readPosition: DSKProtoReadPosition?
        if proto.hasReadPosition {
            readPosition = try DSKProtoReadPosition(proto.readPosition)
        }

        // MARK: - Begin Validation Logic for DSKProtoReceiptMessage -

        // MARK: - End Validation Logic for DSKProtoReceiptMessage -

        self.init(proto: proto,
                  readPosition: readPosition)
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

extension DSKProtoReceiptMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoReceiptMessage.DSKProtoReceiptMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoReceiptMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoTopicMark

@objc
public class DSKProtoTopicMark: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoTopicMarkBuilder

    @objc
    public static func builder() -> DSKProtoTopicMarkBuilder {
        return DSKProtoTopicMarkBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoTopicMarkBuilder {
        let builder = DSKProtoTopicMarkBuilder()
        if let _value = conversation {
            builder.setConversation(_value)
        }
        if let _value = topicID {
            builder.setTopicID(_value)
        }
        if let _value = mark {
            builder.setMark(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoTopicMarkBuilder: NSObject {

        private var proto = DifftServiceProtos_TopicMark()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversation(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversation = valueParam.proto
        }

        public func setConversation(_ valueParam: DSKProtoConversationId) {
            proto.conversation = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.topicID = valueParam
        }

        public func setTopicID(_ valueParam: String) {
            proto.topicID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMark(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.mark = valueParam
        }

        public func setMark(_ valueParam: String) {
            proto.mark = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoTopicMark {
            return try DSKProtoTopicMark(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoTopicMark(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_TopicMark

    @objc
    public let conversation: DSKProtoConversationId?

    @objc
    public var topicID: String? {
        guard hasTopicID else {
            return nil
        }
        return proto.topicID
    }
    @objc
    public var hasTopicID: Bool {
        return proto.hasTopicID
    }

    @objc
    public var mark: String? {
        guard hasMark else {
            return nil
        }
        return proto.mark
    }
    @objc
    public var hasMark: Bool {
        return proto.hasMark
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_TopicMark,
                 conversation: DSKProtoConversationId?) {
        self.proto = proto
        self.conversation = conversation
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_TopicMark(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_TopicMark) throws {
        var conversation: DSKProtoConversationId?
        if proto.hasConversation {
            conversation = try DSKProtoConversationId(proto.conversation)
        }

        // MARK: - Begin Validation Logic for DSKProtoTopicMark -

        // MARK: - End Validation Logic for DSKProtoTopicMark -

        self.init(proto: proto,
                  conversation: conversation)
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

extension DSKProtoTopicMark {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoTopicMark.DSKProtoTopicMarkBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoTopicMark? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoTopicActionActionType

@objc
public enum DSKProtoTopicActionActionType: Int32 {
    case remove = 1
    case add = 2
    case move = 3
}

private func DSKProtoTopicActionActionTypeWrap(_ value: DifftServiceProtos_TopicAction.ActionType) -> DSKProtoTopicActionActionType {
    switch value {
    case .remove: return .remove
    case .add: return .add
    case .move: return .move
    }
}

private func DSKProtoTopicActionActionTypeUnwrap(_ value: DSKProtoTopicActionActionType) -> DifftServiceProtos_TopicAction.ActionType {
    switch value {
    case .remove: return .remove
    case .add: return .add
    case .move: return .move
    }
}

// MARK: - DSKProtoTopicAction

@objc
public class DSKProtoTopicAction: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoTopicActionBuilder

    @objc
    public static func builder() -> DSKProtoTopicActionBuilder {
        return DSKProtoTopicActionBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoTopicActionBuilder {
        let builder = DSKProtoTopicActionBuilder()
        if let _value = actionType {
            builder.setActionType(_value)
        }
        if let _value = conversationID {
            builder.setConversationID(_value)
        }
        if let _value = targetContext {
            builder.setTargetContext(_value)
        }
        if let _value = sourceTopicID {
            builder.setSourceTopicID(_value)
        }
        if let _value = realSource {
            builder.setRealSource(_value)
        }
        if let _value = targetRealSource {
            builder.setTargetRealSource(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoTopicActionBuilder: NSObject {

        private var proto = DifftServiceProtos_TopicAction()

        @objc
        fileprivate override init() {}

        @objc
        public func setActionType(_ valueParam: DSKProtoTopicActionActionType) {
            proto.actionType = DSKProtoTopicActionActionTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationID(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversationID = valueParam.proto
        }

        public func setConversationID(_ valueParam: DSKProtoConversationId) {
            proto.conversationID = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTargetContext(_ valueParam: DSKProtoTopicContext?) {
            guard let valueParam = valueParam else { return }
            proto.targetContext = valueParam.proto
        }

        public func setTargetContext(_ valueParam: DSKProtoTopicContext) {
            proto.targetContext = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSourceTopicID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.sourceTopicID = valueParam
        }

        public func setSourceTopicID(_ valueParam: String) {
            proto.sourceTopicID = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRealSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.realSource = valueParam.proto
        }

        public func setRealSource(_ valueParam: DSKProtoRealSource) {
            proto.realSource = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTargetRealSource(_ valueParam: DSKProtoRealSource?) {
            guard let valueParam = valueParam else { return }
            proto.targetRealSource = valueParam.proto
        }

        public func setTargetRealSource(_ valueParam: DSKProtoRealSource) {
            proto.targetRealSource = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoTopicAction {
            return try DSKProtoTopicAction(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoTopicAction(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_TopicAction

    @objc
    public let conversationID: DSKProtoConversationId?

    @objc
    public let targetContext: DSKProtoTopicContext?

    @objc
    public let realSource: DSKProtoRealSource?

    @objc
    public let targetRealSource: DSKProtoRealSource?

    public var actionType: DSKProtoTopicActionActionType? {
        guard hasActionType else {
            return nil
        }
        return DSKProtoTopicActionActionTypeWrap(proto.actionType)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedActionType: DSKProtoTopicActionActionType {
        if !hasActionType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: TopicAction.actionType.")
        }
        return DSKProtoTopicActionActionTypeWrap(proto.actionType)
    }
    @objc
    public var hasActionType: Bool {
        return proto.hasActionType
    }

    @objc
    public var sourceTopicID: String? {
        guard hasSourceTopicID else {
            return nil
        }
        return proto.sourceTopicID
    }
    @objc
    public var hasSourceTopicID: Bool {
        return proto.hasSourceTopicID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_TopicAction,
                 conversationID: DSKProtoConversationId?,
                 targetContext: DSKProtoTopicContext?,
                 realSource: DSKProtoRealSource?,
                 targetRealSource: DSKProtoRealSource?) {
        self.proto = proto
        self.conversationID = conversationID
        self.targetContext = targetContext
        self.realSource = realSource
        self.targetRealSource = targetRealSource
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_TopicAction(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_TopicAction) throws {
        var conversationID: DSKProtoConversationId?
        if proto.hasConversationID {
            conversationID = try DSKProtoConversationId(proto.conversationID)
        }

        var targetContext: DSKProtoTopicContext?
        if proto.hasTargetContext {
            targetContext = try DSKProtoTopicContext(proto.targetContext)
        }

        var realSource: DSKProtoRealSource?
        if proto.hasRealSource {
            realSource = try DSKProtoRealSource(proto.realSource)
        }

        var targetRealSource: DSKProtoRealSource?
        if proto.hasTargetRealSource {
            targetRealSource = try DSKProtoRealSource(proto.targetRealSource)
        }

        // MARK: - Begin Validation Logic for DSKProtoTopicAction -

        // MARK: - End Validation Logic for DSKProtoTopicAction -

        self.init(proto: proto,
                  conversationID: conversationID,
                  targetContext: targetContext,
                  realSource: realSource,
                  targetRealSource: targetRealSource)
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

extension DSKProtoTopicAction {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoTopicAction.DSKProtoTopicActionBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoTopicAction? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoNotifyMessage

@objc
public class DSKProtoNotifyMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoNotifyMessageBuilder

    @objc
    public static func builder() -> DSKProtoNotifyMessageBuilder {
        return DSKProtoNotifyMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoNotifyMessageBuilder {
        let builder = DSKProtoNotifyMessageBuilder()
        if let _value = topicMark {
            builder.setTopicMark(_value)
        }
        if let _value = topicAction {
            builder.setTopicAction(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoNotifyMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_NotifyMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicMark(_ valueParam: DSKProtoTopicMark?) {
            guard let valueParam = valueParam else { return }
            proto.topicMark = valueParam.proto
        }

        public func setTopicMark(_ valueParam: DSKProtoTopicMark) {
            proto.topicMark = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicAction(_ valueParam: DSKProtoTopicAction?) {
            guard let valueParam = valueParam else { return }
            proto.topicAction = valueParam.proto
        }

        public func setTopicAction(_ valueParam: DSKProtoTopicAction) {
            proto.topicAction = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoNotifyMessage {
            return try DSKProtoNotifyMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoNotifyMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_NotifyMessage

    @objc
    public let topicMark: DSKProtoTopicMark?

    @objc
    public let topicAction: DSKProtoTopicAction?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_NotifyMessage,
                 topicMark: DSKProtoTopicMark?,
                 topicAction: DSKProtoTopicAction?) {
        self.proto = proto
        self.topicMark = topicMark
        self.topicAction = topicAction
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_NotifyMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_NotifyMessage) throws {
        var topicMark: DSKProtoTopicMark?
        if proto.hasTopicMark {
            topicMark = try DSKProtoTopicMark(proto.topicMark)
        }

        var topicAction: DSKProtoTopicAction?
        if proto.hasTopicAction {
            topicAction = try DSKProtoTopicAction(proto.topicAction)
        }

        // MARK: - Begin Validation Logic for DSKProtoNotifyMessage -

        // MARK: - End Validation Logic for DSKProtoNotifyMessage -

        self.init(proto: proto,
                  topicMark: topicMark,
                  topicAction: topicAction)
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

extension DSKProtoNotifyMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoNotifyMessage.DSKProtoNotifyMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoNotifyMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoReadPosition

@objc
public class DSKProtoReadPosition: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoReadPositionBuilder

    @objc
    public static func builder() -> DSKProtoReadPositionBuilder {
        return DSKProtoReadPositionBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoReadPositionBuilder {
        let builder = DSKProtoReadPositionBuilder()
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if hasReadAt {
            builder.setReadAt(readAt)
        }
        if hasMaxServerTime {
            builder.setMaxServerTime(maxServerTime)
        }
        if hasMaxNotifySequenceID {
            builder.setMaxNotifySequenceID(maxNotifySequenceID)
        }
        if hasMaxSequenceID {
            builder.setMaxSequenceID(maxSequenceID)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoReadPositionBuilder: NSObject {

        private var proto = DifftServiceProtos_ReadPosition()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        @objc
        public func setReadAt(_ valueParam: UInt64) {
            proto.readAt = valueParam
        }

        @objc
        public func setMaxServerTime(_ valueParam: UInt64) {
            proto.maxServerTime = valueParam
        }

        @objc
        public func setMaxNotifySequenceID(_ valueParam: UInt64) {
            proto.maxNotifySequenceID = valueParam
        }

        @objc
        public func setMaxSequenceID(_ valueParam: UInt64) {
            proto.maxSequenceID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoReadPosition {
            return try DSKProtoReadPosition(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoReadPosition(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ReadPosition

    @objc
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    @objc
    public var readAt: UInt64 {
        return proto.readAt
    }
    @objc
    public var hasReadAt: Bool {
        return proto.hasReadAt
    }

    @objc
    public var maxServerTime: UInt64 {
        return proto.maxServerTime
    }
    @objc
    public var hasMaxServerTime: Bool {
        return proto.hasMaxServerTime
    }

    @objc
    public var maxNotifySequenceID: UInt64 {
        return proto.maxNotifySequenceID
    }
    @objc
    public var hasMaxNotifySequenceID: Bool {
        return proto.hasMaxNotifySequenceID
    }

    @objc
    public var maxSequenceID: UInt64 {
        return proto.maxSequenceID
    }
    @objc
    public var hasMaxSequenceID: Bool {
        return proto.hasMaxSequenceID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ReadPosition) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ReadPosition(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ReadPosition) throws {
        // MARK: - Begin Validation Logic for DSKProtoReadPosition -

        // MARK: - End Validation Logic for DSKProtoReadPosition -

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

extension DSKProtoReadPosition {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoReadPosition.DSKProtoReadPositionBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoReadPosition? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoTypingMessageAction

@objc
public enum DSKProtoTypingMessageAction: Int32 {
    case started = 0
    case stopped = 1
}

private func DSKProtoTypingMessageActionWrap(_ value: DifftServiceProtos_TypingMessage.Action) -> DSKProtoTypingMessageAction {
    switch value {
    case .started: return .started
    case .stopped: return .stopped
    }
}

private func DSKProtoTypingMessageActionUnwrap(_ value: DSKProtoTypingMessageAction) -> DifftServiceProtos_TypingMessage.Action {
    switch value {
    case .started: return .started
    case .stopped: return .stopped
    }
}

// MARK: - DSKProtoTypingMessage

@objc
public class DSKProtoTypingMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoTypingMessageBuilder

    @objc
    public static func builder() -> DSKProtoTypingMessageBuilder {
        return DSKProtoTypingMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoTypingMessageBuilder {
        let builder = DSKProtoTypingMessageBuilder()
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = action {
            builder.setAction(_value)
        }
        if let _value = groupID {
            builder.setGroupID(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoTypingMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_TypingMessage()

        @objc
        fileprivate override init() {}

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        public func setAction(_ valueParam: DSKProtoTypingMessageAction) {
            proto.action = DSKProtoTypingMessageActionUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroupID(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.groupID = valueParam
        }

        public func setGroupID(_ valueParam: Data) {
            proto.groupID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoTypingMessage {
            return try DSKProtoTypingMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoTypingMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_TypingMessage

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    public var action: DSKProtoTypingMessageAction? {
        guard hasAction else {
            return nil
        }
        return DSKProtoTypingMessageActionWrap(proto.action)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedAction: DSKProtoTypingMessageAction {
        if !hasAction {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: TypingMessage.action.")
        }
        return DSKProtoTypingMessageActionWrap(proto.action)
    }
    @objc
    public var hasAction: Bool {
        return proto.hasAction
    }

    @objc
    public var groupID: Data? {
        guard hasGroupID else {
            return nil
        }
        return proto.groupID
    }
    @objc
    public var hasGroupID: Bool {
        return proto.hasGroupID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_TypingMessage) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_TypingMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_TypingMessage) throws {
        // MARK: - Begin Validation Logic for DSKProtoTypingMessage -

        // MARK: - End Validation Logic for DSKProtoTypingMessage -

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

extension DSKProtoTypingMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoTypingMessage.DSKProtoTypingMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoTypingMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoVerifiedState

@objc
public enum DSKProtoVerifiedState: Int32 {
    case `default` = 0
    case verified = 1
    case unverified = 2
}

private func DSKProtoVerifiedStateWrap(_ value: DifftServiceProtos_Verified.State) -> DSKProtoVerifiedState {
    switch value {
    case .default: return .default
    case .verified: return .verified
    case .unverified: return .unverified
    }
}

private func DSKProtoVerifiedStateUnwrap(_ value: DSKProtoVerifiedState) -> DifftServiceProtos_Verified.State {
    switch value {
    case .default: return .default
    case .verified: return .verified
    case .unverified: return .unverified
    }
}

// MARK: - DSKProtoVerified

@objc
public class DSKProtoVerified: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoVerifiedBuilder

    @objc
    public static func builder() -> DSKProtoVerifiedBuilder {
        return DSKProtoVerifiedBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoVerifiedBuilder {
        let builder = DSKProtoVerifiedBuilder()
        if let _value = destination {
            builder.setDestination(_value)
        }
        if let _value = identityKey {
            builder.setIdentityKey(_value)
        }
        if let _value = state {
            builder.setState(_value)
        }
        if let _value = nullMessage {
            builder.setNullMessage(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoVerifiedBuilder: NSObject {

        private var proto = DifftServiceProtos_Verified()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setDestination(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.destination = valueParam
        }

        public func setDestination(_ valueParam: String) {
            proto.destination = valueParam
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

        @objc
        public func setState(_ valueParam: DSKProtoVerifiedState) {
            proto.state = DSKProtoVerifiedStateUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setNullMessage(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.nullMessage = valueParam
        }

        public func setNullMessage(_ valueParam: Data) {
            proto.nullMessage = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoVerified {
            return try DSKProtoVerified(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoVerified(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_Verified

    @objc
    public var destination: String? {
        guard hasDestination else {
            return nil
        }
        return proto.destination
    }
    @objc
    public var hasDestination: Bool {
        return proto.hasDestination
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

    public var state: DSKProtoVerifiedState? {
        guard hasState else {
            return nil
        }
        return DSKProtoVerifiedStateWrap(proto.state)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedState: DSKProtoVerifiedState {
        if !hasState {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Verified.state.")
        }
        return DSKProtoVerifiedStateWrap(proto.state)
    }
    @objc
    public var hasState: Bool {
        return proto.hasState
    }

    @objc
    public var nullMessage: Data? {
        guard hasNullMessage else {
            return nil
        }
        return proto.nullMessage
    }
    @objc
    public var hasNullMessage: Bool {
        return proto.hasNullMessage
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_Verified) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_Verified(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_Verified) throws {
        // MARK: - Begin Validation Logic for DSKProtoVerified -

        // MARK: - End Validation Logic for DSKProtoVerified -

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

extension DSKProtoVerified {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoVerified.DSKProtoVerifiedBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoVerified? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageSent

@objc
public class DSKProtoSyncMessageSent: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageSentBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageSentBuilder {
        return DSKProtoSyncMessageSentBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageSentBuilder {
        let builder = DSKProtoSyncMessageSentBuilder()
        if let _value = destination {
            builder.setDestination(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = message {
            builder.setMessage(_value)
        }
        if hasExpirationStartTimestamp {
            builder.setExpirationStartTimestamp(expirationStartTimestamp)
        }
        builder.setRapidFiles(rapidFiles)
        if hasServerTimestamp {
            builder.setServerTimestamp(serverTimestamp)
        }
        if hasSequenceID {
            builder.setSequenceID(sequenceID)
        }
        if hasNotifySequenceID {
            builder.setNotifySequenceID(notifySequenceID)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageSentBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Sent()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setDestination(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.destination = valueParam
        }

        public func setDestination(_ valueParam: String) {
            proto.destination = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMessage(_ valueParam: DSKProtoDataMessage?) {
            guard let valueParam = valueParam else { return }
            proto.message = valueParam.proto
        }

        public func setMessage(_ valueParam: DSKProtoDataMessage) {
            proto.message = valueParam.proto
        }

        @objc
        public func setExpirationStartTimestamp(_ valueParam: UInt64) {
            proto.expirationStartTimestamp = valueParam
        }

        @objc
        public func addRapidFiles(_ valueParam: DSKProtoRapidFile) {
            proto.rapidFiles.append(valueParam.proto)
        }

        @objc
        public func setRapidFiles(_ wrappedItems: [DSKProtoRapidFile]) {
            proto.rapidFiles = wrappedItems.map { $0.proto }
        }

        @objc
        public func setServerTimestamp(_ valueParam: UInt64) {
            proto.serverTimestamp = valueParam
        }

        @objc
        public func setSequenceID(_ valueParam: UInt64) {
            proto.sequenceID = valueParam
        }

        @objc
        public func setNotifySequenceID(_ valueParam: UInt64) {
            proto.notifySequenceID = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageSent {
            return try DSKProtoSyncMessageSent(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageSent(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Sent

    @objc
    public let message: DSKProtoDataMessage?

    @objc
    public let rapidFiles: [DSKProtoRapidFile]

    @objc
    public var destination: String? {
        guard hasDestination else {
            return nil
        }
        return proto.destination
    }
    @objc
    public var hasDestination: Bool {
        return proto.hasDestination
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var expirationStartTimestamp: UInt64 {
        return proto.expirationStartTimestamp
    }
    @objc
    public var hasExpirationStartTimestamp: Bool {
        return proto.hasExpirationStartTimestamp
    }

    @objc
    public var serverTimestamp: UInt64 {
        return proto.serverTimestamp
    }
    @objc
    public var hasServerTimestamp: Bool {
        return proto.hasServerTimestamp
    }

    @objc
    public var sequenceID: UInt64 {
        return proto.sequenceID
    }
    @objc
    public var hasSequenceID: Bool {
        return proto.hasSequenceID
    }

    @objc
    public var notifySequenceID: UInt64 {
        return proto.notifySequenceID
    }
    @objc
    public var hasNotifySequenceID: Bool {
        return proto.hasNotifySequenceID
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Sent,
                 message: DSKProtoDataMessage?,
                 rapidFiles: [DSKProtoRapidFile]) {
        self.proto = proto
        self.message = message
        self.rapidFiles = rapidFiles
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Sent(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Sent) throws {
        var message: DSKProtoDataMessage?
        if proto.hasMessage {
            message = try DSKProtoDataMessage(proto.message)
        }

        var rapidFiles: [DSKProtoRapidFile] = []
        rapidFiles = try proto.rapidFiles.map { try DSKProtoRapidFile($0) }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageSent -

        // MARK: - End Validation Logic for DSKProtoSyncMessageSent -

        self.init(proto: proto,
                  message: message,
                  rapidFiles: rapidFiles)
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

extension DSKProtoSyncMessageSent {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageSent.DSKProtoSyncMessageSentBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageSent? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageContacts

@objc
public class DSKProtoSyncMessageContacts: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageContactsBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageContactsBuilder {
        return DSKProtoSyncMessageContactsBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageContactsBuilder {
        let builder = DSKProtoSyncMessageContactsBuilder()
        if let _value = blob {
            builder.setBlob(_value)
        }
        if hasIsComplete {
            builder.setIsComplete(isComplete)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageContactsBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Contacts()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBlob(_ valueParam: DSKProtoAttachmentPointer?) {
            guard let valueParam = valueParam else { return }
            proto.blob = valueParam.proto
        }

        public func setBlob(_ valueParam: DSKProtoAttachmentPointer) {
            proto.blob = valueParam.proto
        }

        @objc
        public func setIsComplete(_ valueParam: Bool) {
            proto.isComplete = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageContacts {
            return try DSKProtoSyncMessageContacts(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageContacts(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Contacts

    @objc
    public let blob: DSKProtoAttachmentPointer?

    @objc
    public var isComplete: Bool {
        return proto.isComplete
    }
    @objc
    public var hasIsComplete: Bool {
        return proto.hasIsComplete
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Contacts,
                 blob: DSKProtoAttachmentPointer?) {
        self.proto = proto
        self.blob = blob
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Contacts(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Contacts) throws {
        var blob: DSKProtoAttachmentPointer?
        if proto.hasBlob {
            blob = try DSKProtoAttachmentPointer(proto.blob)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageContacts -

        // MARK: - End Validation Logic for DSKProtoSyncMessageContacts -

        self.init(proto: proto,
                  blob: blob)
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

extension DSKProtoSyncMessageContacts {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageContacts.DSKProtoSyncMessageContactsBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageContacts? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageGroups

@objc
public class DSKProtoSyncMessageGroups: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageGroupsBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageGroupsBuilder {
        return DSKProtoSyncMessageGroupsBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageGroupsBuilder {
        let builder = DSKProtoSyncMessageGroupsBuilder()
        if let _value = blob {
            builder.setBlob(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageGroupsBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Groups()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBlob(_ valueParam: DSKProtoAttachmentPointer?) {
            guard let valueParam = valueParam else { return }
            proto.blob = valueParam.proto
        }

        public func setBlob(_ valueParam: DSKProtoAttachmentPointer) {
            proto.blob = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageGroups {
            return try DSKProtoSyncMessageGroups(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageGroups(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Groups

    @objc
    public let blob: DSKProtoAttachmentPointer?

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Groups,
                 blob: DSKProtoAttachmentPointer?) {
        self.proto = proto
        self.blob = blob
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Groups(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Groups) throws {
        var blob: DSKProtoAttachmentPointer?
        if proto.hasBlob {
            blob = try DSKProtoAttachmentPointer(proto.blob)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageGroups -

        // MARK: - End Validation Logic for DSKProtoSyncMessageGroups -

        self.init(proto: proto,
                  blob: blob)
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

extension DSKProtoSyncMessageGroups {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageGroups.DSKProtoSyncMessageGroupsBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageGroups? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageBlocked

@objc
public class DSKProtoSyncMessageBlocked: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageBlockedBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageBlockedBuilder {
        return DSKProtoSyncMessageBlockedBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageBlockedBuilder {
        let builder = DSKProtoSyncMessageBlockedBuilder()
        builder.setNumbers(numbers)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageBlockedBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Blocked()

        @objc
        fileprivate override init() {}

        @objc
        public func addNumbers(_ valueParam: String) {
            proto.numbers.append(valueParam)
        }

        @objc
        public func setNumbers(_ wrappedItems: [String]) {
            proto.numbers = wrappedItems
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageBlocked {
            return try DSKProtoSyncMessageBlocked(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageBlocked(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Blocked

    @objc
    public var numbers: [String] {
        return proto.numbers
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Blocked) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Blocked(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Blocked) throws {
        // MARK: - Begin Validation Logic for DSKProtoSyncMessageBlocked -

        // MARK: - End Validation Logic for DSKProtoSyncMessageBlocked -

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

extension DSKProtoSyncMessageBlocked {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageBlocked.DSKProtoSyncMessageBlockedBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageBlocked? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageRequestType

@objc
public enum DSKProtoSyncMessageRequestType: Int32 {
    case unknown = 0
    case contacts = 1
    case groups = 2
    case blocked = 3
    case configuration = 4
}

private func DSKProtoSyncMessageRequestTypeWrap(_ value: DifftServiceProtos_SyncMessage.Request.TypeEnum) -> DSKProtoSyncMessageRequestType {
    switch value {
    case .unknown: return .unknown
    case .contacts: return .contacts
    case .groups: return .groups
    case .blocked: return .blocked
    case .configuration: return .configuration
    }
}

private func DSKProtoSyncMessageRequestTypeUnwrap(_ value: DSKProtoSyncMessageRequestType) -> DifftServiceProtos_SyncMessage.Request.TypeEnum {
    switch value {
    case .unknown: return .unknown
    case .contacts: return .contacts
    case .groups: return .groups
    case .blocked: return .blocked
    case .configuration: return .configuration
    }
}

// MARK: - DSKProtoSyncMessageRequest

@objc
public class DSKProtoSyncMessageRequest: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageRequestBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageRequestBuilder {
        return DSKProtoSyncMessageRequestBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageRequestBuilder {
        let builder = DSKProtoSyncMessageRequestBuilder()
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageRequestBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Request()

        @objc
        fileprivate override init() {}

        @objc
        public func setType(_ valueParam: DSKProtoSyncMessageRequestType) {
            proto.type = DSKProtoSyncMessageRequestTypeUnwrap(valueParam)
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageRequest {
            return try DSKProtoSyncMessageRequest(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageRequest(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Request

    public var type: DSKProtoSyncMessageRequestType? {
        guard hasType else {
            return nil
        }
        return DSKProtoSyncMessageRequestTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoSyncMessageRequestType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: Request.type.")
        }
        return DSKProtoSyncMessageRequestTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Request) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Request(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Request) throws {
        // MARK: - Begin Validation Logic for DSKProtoSyncMessageRequest -

        // MARK: - End Validation Logic for DSKProtoSyncMessageRequest -

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

extension DSKProtoSyncMessageRequest {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageRequest.DSKProtoSyncMessageRequestBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageRequest? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageRead

@objc
public class DSKProtoSyncMessageRead: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageReadBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageReadBuilder {
        return DSKProtoSyncMessageReadBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageReadBuilder {
        let builder = DSKProtoSyncMessageReadBuilder()
        if let _value = sender {
            builder.setSender(_value)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = readPosition {
            builder.setReadPosition(_value)
        }
        if hasMessageMode {
            builder.setMessageMode(messageMode)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageReadBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Read()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSender(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.sender = valueParam
        }

        public func setSender(_ valueParam: String) {
            proto.sender = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setReadPosition(_ valueParam: DSKProtoReadPosition?) {
            guard let valueParam = valueParam else { return }
            proto.readPosition = valueParam.proto
        }

        public func setReadPosition(_ valueParam: DSKProtoReadPosition) {
            proto.readPosition = valueParam.proto
        }

        @objc
        public func setMessageMode(_ valueParam: UInt32) {
            proto.messageMode = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageRead {
            return try DSKProtoSyncMessageRead(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageRead(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Read

    @objc
    public let readPosition: DSKProtoReadPosition?

    @objc
    public var sender: String? {
        guard hasSender else {
            return nil
        }
        return proto.sender
    }
    @objc
    public var hasSender: Bool {
        return proto.hasSender
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    @objc
    public var messageMode: UInt32 {
        return proto.messageMode
    }
    @objc
    public var hasMessageMode: Bool {
        return proto.hasMessageMode
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Read,
                 readPosition: DSKProtoReadPosition?) {
        self.proto = proto
        self.readPosition = readPosition
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Read(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Read) throws {
        var readPosition: DSKProtoReadPosition?
        if proto.hasReadPosition {
            readPosition = try DSKProtoReadPosition(proto.readPosition)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageRead -

        // MARK: - End Validation Logic for DSKProtoSyncMessageRead -

        self.init(proto: proto,
                  readPosition: readPosition)
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

extension DSKProtoSyncMessageRead {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageRead.DSKProtoSyncMessageReadBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageRead? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageConfiguration

@objc
public class DSKProtoSyncMessageConfiguration: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageConfigurationBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageConfigurationBuilder {
        return DSKProtoSyncMessageConfigurationBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageConfigurationBuilder {
        let builder = DSKProtoSyncMessageConfigurationBuilder()
        if hasReadReceipts {
            builder.setReadReceipts(readReceipts)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageConfigurationBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Configuration()

        @objc
        fileprivate override init() {}

        @objc
        public func setReadReceipts(_ valueParam: Bool) {
            proto.readReceipts = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageConfiguration {
            return try DSKProtoSyncMessageConfiguration(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageConfiguration(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Configuration

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

    private init(proto: DifftServiceProtos_SyncMessage.Configuration) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Configuration(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Configuration) throws {
        // MARK: - Begin Validation Logic for DSKProtoSyncMessageConfiguration -

        // MARK: - End Validation Logic for DSKProtoSyncMessageConfiguration -

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

extension DSKProtoSyncMessageConfiguration {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageConfiguration.DSKProtoSyncMessageConfigurationBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageConfiguration? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageTaskType

@objc
public enum DSKProtoSyncMessageTaskType: Int32 {
    case read = 0
}

private func DSKProtoSyncMessageTaskTypeWrap(_ value: DifftServiceProtos_SyncMessage.Task.TypeEnum) -> DSKProtoSyncMessageTaskType {
    switch value {
    case .read: return .read
    }
}

private func DSKProtoSyncMessageTaskTypeUnwrap(_ value: DSKProtoSyncMessageTaskType) -> DifftServiceProtos_SyncMessage.Task.TypeEnum {
    switch value {
    case .read: return .read
    }
}

// MARK: - DSKProtoSyncMessageTask

@objc
public class DSKProtoSyncMessageTask: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageTaskBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageTaskBuilder {
        return DSKProtoSyncMessageTaskBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageTaskBuilder {
        let builder = DSKProtoSyncMessageTaskBuilder()
        if let _value = taskID {
            builder.setTaskID(_value)
        }
        if hasVersion {
            builder.setVersion(version)
        }
        if hasType {
            builder.setType(type)
        }
        if hasTimestamp {
            builder.setTimestamp(timestamp)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageTaskBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.Task()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTaskID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.taskID = valueParam
        }

        public func setTaskID(_ valueParam: String) {
            proto.taskID = valueParam
        }

        @objc
        public func setVersion(_ valueParam: UInt32) {
            proto.version = valueParam
        }

        @objc
        public func setType(_ valueParam: UInt32) {
            proto.type = valueParam
        }

        @objc
        public func setTimestamp(_ valueParam: UInt64) {
            proto.timestamp = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageTask {
            return try DSKProtoSyncMessageTask(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageTask(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.Task

    @objc
    public var taskID: String? {
        guard hasTaskID else {
            return nil
        }
        return proto.taskID
    }
    @objc
    public var hasTaskID: Bool {
        return proto.hasTaskID
    }

    @objc
    public var version: UInt32 {
        return proto.version
    }
    @objc
    public var hasVersion: Bool {
        return proto.hasVersion
    }

    @objc
    public var type: UInt32 {
        return proto.type
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var timestamp: UInt64 {
        return proto.timestamp
    }
    @objc
    public var hasTimestamp: Bool {
        return proto.hasTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.Task) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.Task(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.Task) throws {
        // MARK: - Begin Validation Logic for DSKProtoSyncMessageTask -

        // MARK: - End Validation Logic for DSKProtoSyncMessageTask -

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

extension DSKProtoSyncMessageTask {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageTask.DSKProtoSyncMessageTaskBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageTask? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageMarkTopicAsTrackFlag

@objc
public enum DSKProtoSyncMessageMarkTopicAsTrackFlag: Int32 {
    case track = 1
    case untrack = 2
}

private func DSKProtoSyncMessageMarkTopicAsTrackFlagWrap(_ value: DifftServiceProtos_SyncMessage.MarkTopicAsTrack.Flag) -> DSKProtoSyncMessageMarkTopicAsTrackFlag {
    switch value {
    case .track: return .track
    case .untrack: return .untrack
    }
}

private func DSKProtoSyncMessageMarkTopicAsTrackFlagUnwrap(_ value: DSKProtoSyncMessageMarkTopicAsTrackFlag) -> DifftServiceProtos_SyncMessage.MarkTopicAsTrack.Flag {
    switch value {
    case .track: return .track
    case .untrack: return .untrack
    }
}

// MARK: - DSKProtoSyncMessageMarkTopicAsTrack

@objc
public class DSKProtoSyncMessageMarkTopicAsTrack: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageMarkTopicAsTrackBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageMarkTopicAsTrackBuilder {
        return DSKProtoSyncMessageMarkTopicAsTrackBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageMarkTopicAsTrackBuilder {
        let builder = DSKProtoSyncMessageMarkTopicAsTrackBuilder()
        if let _value = conversation {
            builder.setConversation(_value)
        }
        if let _value = topicID {
            builder.setTopicID(_value)
        }
        if let _value = flag {
            builder.setFlag(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageMarkTopicAsTrackBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.MarkTopicAsTrack()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversation(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversation = valueParam.proto
        }

        public func setConversation(_ valueParam: DSKProtoConversationId) {
            proto.conversation = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicID(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.topicID = valueParam
        }

        public func setTopicID(_ valueParam: String) {
            proto.topicID = valueParam
        }

        @objc
        public func setFlag(_ valueParam: DSKProtoSyncMessageMarkTopicAsTrackFlag) {
            proto.flag = DSKProtoSyncMessageMarkTopicAsTrackFlagUnwrap(valueParam)
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageMarkTopicAsTrack {
            return try DSKProtoSyncMessageMarkTopicAsTrack(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageMarkTopicAsTrack(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.MarkTopicAsTrack

    @objc
    public let conversation: DSKProtoConversationId?

    @objc
    public var topicID: String? {
        guard hasTopicID else {
            return nil
        }
        return proto.topicID
    }
    @objc
    public var hasTopicID: Bool {
        return proto.hasTopicID
    }

    public var flag: DSKProtoSyncMessageMarkTopicAsTrackFlag? {
        guard hasFlag else {
            return nil
        }
        return DSKProtoSyncMessageMarkTopicAsTrackFlagWrap(proto.flag)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedFlag: DSKProtoSyncMessageMarkTopicAsTrackFlag {
        if !hasFlag {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: MarkTopicAsTrack.flag.")
        }
        return DSKProtoSyncMessageMarkTopicAsTrackFlagWrap(proto.flag)
    }
    @objc
    public var hasFlag: Bool {
        return proto.hasFlag
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.MarkTopicAsTrack,
                 conversation: DSKProtoConversationId?) {
        self.proto = proto
        self.conversation = conversation
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.MarkTopicAsTrack(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.MarkTopicAsTrack) throws {
        var conversation: DSKProtoConversationId?
        if proto.hasConversation {
            conversation = try DSKProtoConversationId(proto.conversation)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageMarkTopicAsTrack -

        // MARK: - End Validation Logic for DSKProtoSyncMessageMarkTopicAsTrack -

        self.init(proto: proto,
                  conversation: conversation)
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

extension DSKProtoSyncMessageMarkTopicAsTrack {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageMarkTopicAsTrack.DSKProtoSyncMessageMarkTopicAsTrackBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageMarkTopicAsTrack? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageMarkAsUnreadFlag

@objc
public enum DSKProtoSyncMessageMarkAsUnreadFlag: Int32 {
    case clear = 0
    case unread = 1
    case read = 2
}

private func DSKProtoSyncMessageMarkAsUnreadFlagWrap(_ value: DifftServiceProtos_SyncMessage.MarkAsUnread.Flag) -> DSKProtoSyncMessageMarkAsUnreadFlag {
    switch value {
    case .clear: return .clear
    case .unread: return .unread
    case .read: return .read
    }
}

private func DSKProtoSyncMessageMarkAsUnreadFlagUnwrap(_ value: DSKProtoSyncMessageMarkAsUnreadFlag) -> DifftServiceProtos_SyncMessage.MarkAsUnread.Flag {
    switch value {
    case .clear: return .clear
    case .unread: return .unread
    case .read: return .read
    }
}

// MARK: - DSKProtoSyncMessageMarkAsUnread

@objc
public class DSKProtoSyncMessageMarkAsUnread: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageMarkAsUnreadBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageMarkAsUnreadBuilder {
        return DSKProtoSyncMessageMarkAsUnreadBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageMarkAsUnreadBuilder {
        let builder = DSKProtoSyncMessageMarkAsUnreadBuilder()
        if let _value = conversation {
            builder.setConversation(_value)
        }
        if let _value = flag {
            builder.setFlag(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageMarkAsUnreadBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.MarkAsUnread()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversation(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversation = valueParam.proto
        }

        public func setConversation(_ valueParam: DSKProtoConversationId) {
            proto.conversation = valueParam.proto
        }

        @objc
        public func setFlag(_ valueParam: DSKProtoSyncMessageMarkAsUnreadFlag) {
            proto.flag = DSKProtoSyncMessageMarkAsUnreadFlagUnwrap(valueParam)
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageMarkAsUnread {
            return try DSKProtoSyncMessageMarkAsUnread(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageMarkAsUnread(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.MarkAsUnread

    @objc
    public let conversation: DSKProtoConversationId?

    public var flag: DSKProtoSyncMessageMarkAsUnreadFlag? {
        guard hasFlag else {
            return nil
        }
        return DSKProtoSyncMessageMarkAsUnreadFlagWrap(proto.flag)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedFlag: DSKProtoSyncMessageMarkAsUnreadFlag {
        if !hasFlag {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: MarkAsUnread.flag.")
        }
        return DSKProtoSyncMessageMarkAsUnreadFlagWrap(proto.flag)
    }
    @objc
    public var hasFlag: Bool {
        return proto.hasFlag
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.MarkAsUnread,
                 conversation: DSKProtoConversationId?) {
        self.proto = proto
        self.conversation = conversation
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.MarkAsUnread(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.MarkAsUnread) throws {
        var conversation: DSKProtoConversationId?
        if proto.hasConversation {
            conversation = try DSKProtoConversationId(proto.conversation)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageMarkAsUnread -

        // MARK: - End Validation Logic for DSKProtoSyncMessageMarkAsUnread -

        self.init(proto: proto,
                  conversation: conversation)
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

extension DSKProtoSyncMessageMarkAsUnread {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageMarkAsUnread.DSKProtoSyncMessageMarkAsUnreadBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageMarkAsUnread? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessageConversationArchiveFlag

@objc
public enum DSKProtoSyncMessageConversationArchiveFlag: Int32 {
    case unarchive = 0
    case archive = 1
}

private func DSKProtoSyncMessageConversationArchiveFlagWrap(_ value: DifftServiceProtos_SyncMessage.ConversationArchive.Flag) -> DSKProtoSyncMessageConversationArchiveFlag {
    switch value {
    case .unarchive: return .unarchive
    case .archive: return .archive
    }
}

private func DSKProtoSyncMessageConversationArchiveFlagUnwrap(_ value: DSKProtoSyncMessageConversationArchiveFlag) -> DifftServiceProtos_SyncMessage.ConversationArchive.Flag {
    switch value {
    case .unarchive: return .unarchive
    case .archive: return .archive
    }
}

// MARK: - DSKProtoSyncMessageConversationArchive

@objc
public class DSKProtoSyncMessageConversationArchive: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageConversationArchiveBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageConversationArchiveBuilder {
        return DSKProtoSyncMessageConversationArchiveBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageConversationArchiveBuilder {
        let builder = DSKProtoSyncMessageConversationArchiveBuilder()
        if let _value = conversation {
            builder.setConversation(_value)
        }
        if let _value = flag {
            builder.setFlag(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageConversationArchiveBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage.ConversationArchive()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversation(_ valueParam: DSKProtoConversationId?) {
            guard let valueParam = valueParam else { return }
            proto.conversation = valueParam.proto
        }

        public func setConversation(_ valueParam: DSKProtoConversationId) {
            proto.conversation = valueParam.proto
        }

        @objc
        public func setFlag(_ valueParam: DSKProtoSyncMessageConversationArchiveFlag) {
            proto.flag = DSKProtoSyncMessageConversationArchiveFlagUnwrap(valueParam)
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessageConversationArchive {
            return try DSKProtoSyncMessageConversationArchive(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessageConversationArchive(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage.ConversationArchive

    @objc
    public let conversation: DSKProtoConversationId?

    public var flag: DSKProtoSyncMessageConversationArchiveFlag? {
        guard hasFlag else {
            return nil
        }
        return DSKProtoSyncMessageConversationArchiveFlagWrap(proto.flag)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedFlag: DSKProtoSyncMessageConversationArchiveFlag {
        if !hasFlag {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: ConversationArchive.flag.")
        }
        return DSKProtoSyncMessageConversationArchiveFlagWrap(proto.flag)
    }
    @objc
    public var hasFlag: Bool {
        return proto.hasFlag
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage.ConversationArchive,
                 conversation: DSKProtoConversationId?) {
        self.proto = proto
        self.conversation = conversation
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage.ConversationArchive(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage.ConversationArchive) throws {
        var conversation: DSKProtoConversationId?
        if proto.hasConversation {
            conversation = try DSKProtoConversationId(proto.conversation)
        }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessageConversationArchive -

        // MARK: - End Validation Logic for DSKProtoSyncMessageConversationArchive -

        self.init(proto: proto,
                  conversation: conversation)
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

extension DSKProtoSyncMessageConversationArchive {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessageConversationArchive.DSKProtoSyncMessageConversationArchiveBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessageConversationArchive? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoSyncMessage

@objc
public class DSKProtoSyncMessage: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoSyncMessageBuilder

    @objc
    public static func builder() -> DSKProtoSyncMessageBuilder {
        return DSKProtoSyncMessageBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoSyncMessageBuilder {
        let builder = DSKProtoSyncMessageBuilder()
        if let _value = sent {
            builder.setSent(_value)
        }
        if let _value = contacts {
            builder.setContacts(_value)
        }
        if let _value = groups {
            builder.setGroups(_value)
        }
        if let _value = request {
            builder.setRequest(_value)
        }
        builder.setRead(read)
        if let _value = blocked {
            builder.setBlocked(_value)
        }
        if let _value = verified {
            builder.setVerified(_value)
        }
        if let _value = configuration {
            builder.setConfiguration(_value)
        }
        if let _value = padding {
            builder.setPadding(_value)
        }
        builder.setTasks(tasks)
        if let _value = markAsUnread {
            builder.setMarkAsUnread(_value)
        }
        if let _value = conversationArchive {
            builder.setConversationArchive(_value)
        }
        if let _value = markTopicAsTrack {
            builder.setMarkTopicAsTrack(_value)
        }
        if let _value = topicMark {
            builder.setTopicMark(_value)
        }
        if let _value = topicAction {
            builder.setTopicAction(_value)
        }
        if hasServerTimestamp {
            builder.setServerTimestamp(serverTimestamp)
        }
        builder.setCriticalRead(criticalRead)
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoSyncMessageBuilder: NSObject {

        private var proto = DifftServiceProtos_SyncMessage()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setSent(_ valueParam: DSKProtoSyncMessageSent?) {
            guard let valueParam = valueParam else { return }
            proto.sent = valueParam.proto
        }

        public func setSent(_ valueParam: DSKProtoSyncMessageSent) {
            proto.sent = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContacts(_ valueParam: DSKProtoSyncMessageContacts?) {
            guard let valueParam = valueParam else { return }
            proto.contacts = valueParam.proto
        }

        public func setContacts(_ valueParam: DSKProtoSyncMessageContacts) {
            proto.contacts = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setGroups(_ valueParam: DSKProtoSyncMessageGroups?) {
            guard let valueParam = valueParam else { return }
            proto.groups = valueParam.proto
        }

        public func setGroups(_ valueParam: DSKProtoSyncMessageGroups) {
            proto.groups = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setRequest(_ valueParam: DSKProtoSyncMessageRequest?) {
            guard let valueParam = valueParam else { return }
            proto.request = valueParam.proto
        }

        public func setRequest(_ valueParam: DSKProtoSyncMessageRequest) {
            proto.request = valueParam.proto
        }

        @objc
        public func addRead(_ valueParam: DSKProtoSyncMessageRead) {
            proto.read.append(valueParam.proto)
        }

        @objc
        public func setRead(_ wrappedItems: [DSKProtoSyncMessageRead]) {
            proto.read = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setBlocked(_ valueParam: DSKProtoSyncMessageBlocked?) {
            guard let valueParam = valueParam else { return }
            proto.blocked = valueParam.proto
        }

        public func setBlocked(_ valueParam: DSKProtoSyncMessageBlocked) {
            proto.blocked = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setVerified(_ valueParam: DSKProtoVerified?) {
            guard let valueParam = valueParam else { return }
            proto.verified = valueParam.proto
        }

        public func setVerified(_ valueParam: DSKProtoVerified) {
            proto.verified = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConfiguration(_ valueParam: DSKProtoSyncMessageConfiguration?) {
            guard let valueParam = valueParam else { return }
            proto.configuration = valueParam.proto
        }

        public func setConfiguration(_ valueParam: DSKProtoSyncMessageConfiguration) {
            proto.configuration = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setPadding(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.padding = valueParam
        }

        public func setPadding(_ valueParam: Data) {
            proto.padding = valueParam
        }

        @objc
        public func addTasks(_ valueParam: DSKProtoSyncMessageTask) {
            proto.tasks.append(valueParam.proto)
        }

        @objc
        public func setTasks(_ wrappedItems: [DSKProtoSyncMessageTask]) {
            proto.tasks = wrappedItems.map { $0.proto }
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMarkAsUnread(_ valueParam: DSKProtoSyncMessageMarkAsUnread?) {
            guard let valueParam = valueParam else { return }
            proto.markAsUnread = valueParam.proto
        }

        public func setMarkAsUnread(_ valueParam: DSKProtoSyncMessageMarkAsUnread) {
            proto.markAsUnread = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setConversationArchive(_ valueParam: DSKProtoSyncMessageConversationArchive?) {
            guard let valueParam = valueParam else { return }
            proto.conversationArchive = valueParam.proto
        }

        public func setConversationArchive(_ valueParam: DSKProtoSyncMessageConversationArchive) {
            proto.conversationArchive = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setMarkTopicAsTrack(_ valueParam: DSKProtoSyncMessageMarkTopicAsTrack?) {
            guard let valueParam = valueParam else { return }
            proto.markTopicAsTrack = valueParam.proto
        }

        public func setMarkTopicAsTrack(_ valueParam: DSKProtoSyncMessageMarkTopicAsTrack) {
            proto.markTopicAsTrack = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicMark(_ valueParam: DSKProtoTopicMark?) {
            guard let valueParam = valueParam else { return }
            proto.topicMark = valueParam.proto
        }

        public func setTopicMark(_ valueParam: DSKProtoTopicMark) {
            proto.topicMark = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setTopicAction(_ valueParam: DSKProtoTopicAction?) {
            guard let valueParam = valueParam else { return }
            proto.topicAction = valueParam.proto
        }

        public func setTopicAction(_ valueParam: DSKProtoTopicAction) {
            proto.topicAction = valueParam.proto
        }

        @objc
        public func setServerTimestamp(_ valueParam: UInt64) {
            proto.serverTimestamp = valueParam
        }

        @objc
        public func addCriticalRead(_ valueParam: DSKProtoSyncMessageRead) {
            proto.criticalRead.append(valueParam.proto)
        }

        @objc
        public func setCriticalRead(_ wrappedItems: [DSKProtoSyncMessageRead]) {
            proto.criticalRead = wrappedItems.map { $0.proto }
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoSyncMessage {
            return try DSKProtoSyncMessage(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoSyncMessage(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_SyncMessage

    @objc
    public let sent: DSKProtoSyncMessageSent?

    @objc
    public let contacts: DSKProtoSyncMessageContacts?

    @objc
    public let groups: DSKProtoSyncMessageGroups?

    @objc
    public let request: DSKProtoSyncMessageRequest?

    @objc
    public let read: [DSKProtoSyncMessageRead]

    @objc
    public let blocked: DSKProtoSyncMessageBlocked?

    @objc
    public let verified: DSKProtoVerified?

    @objc
    public let configuration: DSKProtoSyncMessageConfiguration?

    @objc
    public let tasks: [DSKProtoSyncMessageTask]

    @objc
    public let markAsUnread: DSKProtoSyncMessageMarkAsUnread?

    @objc
    public let conversationArchive: DSKProtoSyncMessageConversationArchive?

    @objc
    public let markTopicAsTrack: DSKProtoSyncMessageMarkTopicAsTrack?

    @objc
    public let topicMark: DSKProtoTopicMark?

    @objc
    public let topicAction: DSKProtoTopicAction?

    @objc
    public let criticalRead: [DSKProtoSyncMessageRead]

    @objc
    public var padding: Data? {
        guard hasPadding else {
            return nil
        }
        return proto.padding
    }
    @objc
    public var hasPadding: Bool {
        return proto.hasPadding
    }

    @objc
    public var serverTimestamp: UInt64 {
        return proto.serverTimestamp
    }
    @objc
    public var hasServerTimestamp: Bool {
        return proto.hasServerTimestamp
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_SyncMessage,
                 sent: DSKProtoSyncMessageSent?,
                 contacts: DSKProtoSyncMessageContacts?,
                 groups: DSKProtoSyncMessageGroups?,
                 request: DSKProtoSyncMessageRequest?,
                 read: [DSKProtoSyncMessageRead],
                 blocked: DSKProtoSyncMessageBlocked?,
                 verified: DSKProtoVerified?,
                 configuration: DSKProtoSyncMessageConfiguration?,
                 tasks: [DSKProtoSyncMessageTask],
                 markAsUnread: DSKProtoSyncMessageMarkAsUnread?,
                 conversationArchive: DSKProtoSyncMessageConversationArchive?,
                 markTopicAsTrack: DSKProtoSyncMessageMarkTopicAsTrack?,
                 topicMark: DSKProtoTopicMark?,
                 topicAction: DSKProtoTopicAction?,
                 criticalRead: [DSKProtoSyncMessageRead]) {
        self.proto = proto
        self.sent = sent
        self.contacts = contacts
        self.groups = groups
        self.request = request
        self.read = read
        self.blocked = blocked
        self.verified = verified
        self.configuration = configuration
        self.tasks = tasks
        self.markAsUnread = markAsUnread
        self.conversationArchive = conversationArchive
        self.markTopicAsTrack = markTopicAsTrack
        self.topicMark = topicMark
        self.topicAction = topicAction
        self.criticalRead = criticalRead
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_SyncMessage(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_SyncMessage) throws {
        var sent: DSKProtoSyncMessageSent?
        if proto.hasSent {
            sent = try DSKProtoSyncMessageSent(proto.sent)
        }

        var contacts: DSKProtoSyncMessageContacts?
        if proto.hasContacts {
            contacts = try DSKProtoSyncMessageContacts(proto.contacts)
        }

        var groups: DSKProtoSyncMessageGroups?
        if proto.hasGroups {
            groups = try DSKProtoSyncMessageGroups(proto.groups)
        }

        var request: DSKProtoSyncMessageRequest?
        if proto.hasRequest {
            request = try DSKProtoSyncMessageRequest(proto.request)
        }

        var read: [DSKProtoSyncMessageRead] = []
        read = try proto.read.map { try DSKProtoSyncMessageRead($0) }

        var blocked: DSKProtoSyncMessageBlocked?
        if proto.hasBlocked {
            blocked = try DSKProtoSyncMessageBlocked(proto.blocked)
        }

        var verified: DSKProtoVerified?
        if proto.hasVerified {
            verified = try DSKProtoVerified(proto.verified)
        }

        var configuration: DSKProtoSyncMessageConfiguration?
        if proto.hasConfiguration {
            configuration = try DSKProtoSyncMessageConfiguration(proto.configuration)
        }

        var tasks: [DSKProtoSyncMessageTask] = []
        tasks = try proto.tasks.map { try DSKProtoSyncMessageTask($0) }

        var markAsUnread: DSKProtoSyncMessageMarkAsUnread?
        if proto.hasMarkAsUnread {
            markAsUnread = try DSKProtoSyncMessageMarkAsUnread(proto.markAsUnread)
        }

        var conversationArchive: DSKProtoSyncMessageConversationArchive?
        if proto.hasConversationArchive {
            conversationArchive = try DSKProtoSyncMessageConversationArchive(proto.conversationArchive)
        }

        var markTopicAsTrack: DSKProtoSyncMessageMarkTopicAsTrack?
        if proto.hasMarkTopicAsTrack {
            markTopicAsTrack = try DSKProtoSyncMessageMarkTopicAsTrack(proto.markTopicAsTrack)
        }

        var topicMark: DSKProtoTopicMark?
        if proto.hasTopicMark {
            topicMark = try DSKProtoTopicMark(proto.topicMark)
        }

        var topicAction: DSKProtoTopicAction?
        if proto.hasTopicAction {
            topicAction = try DSKProtoTopicAction(proto.topicAction)
        }

        var criticalRead: [DSKProtoSyncMessageRead] = []
        criticalRead = try proto.criticalRead.map { try DSKProtoSyncMessageRead($0) }

        // MARK: - Begin Validation Logic for DSKProtoSyncMessage -

        // MARK: - End Validation Logic for DSKProtoSyncMessage -

        self.init(proto: proto,
                  sent: sent,
                  contacts: contacts,
                  groups: groups,
                  request: request,
                  read: read,
                  blocked: blocked,
                  verified: verified,
                  configuration: configuration,
                  tasks: tasks,
                  markAsUnread: markAsUnread,
                  conversationArchive: conversationArchive,
                  markTopicAsTrack: markTopicAsTrack,
                  topicMark: topicMark,
                  topicAction: topicAction,
                  criticalRead: criticalRead)
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

extension DSKProtoSyncMessage {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoSyncMessage.DSKProtoSyncMessageBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoSyncMessage? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoAttachmentPointerFlags

@objc
public enum DSKProtoAttachmentPointerFlags: Int32 {
    case voiceMessage = 1
}

private func DSKProtoAttachmentPointerFlagsWrap(_ value: DifftServiceProtos_AttachmentPointer.Flags) -> DSKProtoAttachmentPointerFlags {
    switch value {
    case .voiceMessage: return .voiceMessage
    }
}

private func DSKProtoAttachmentPointerFlagsUnwrap(_ value: DSKProtoAttachmentPointerFlags) -> DifftServiceProtos_AttachmentPointer.Flags {
    switch value {
    case .voiceMessage: return .voiceMessage
    }
}

// MARK: - DSKProtoAttachmentPointer

@objc
public class DSKProtoAttachmentPointer: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoAttachmentPointerBuilder

    @objc
    public static func builder() -> DSKProtoAttachmentPointerBuilder {
        return DSKProtoAttachmentPointerBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoAttachmentPointerBuilder {
        let builder = DSKProtoAttachmentPointerBuilder()
        if hasID {
            builder.setId(id)
        }
        if let _value = contentType {
            builder.setContentType(_value)
        }
        if let _value = key {
            builder.setKey(_value)
        }
        if hasSize {
            builder.setSize(size)
        }
        if let _value = thumbnail {
            builder.setThumbnail(_value)
        }
        if let _value = digest {
            builder.setDigest(_value)
        }
        if let _value = fileName {
            builder.setFileName(_value)
        }
        if hasFlags {
            builder.setFlags(flags)
        }
        if hasWidth {
            builder.setWidth(width)
        }
        if hasHeight {
            builder.setHeight(height)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoAttachmentPointerBuilder: NSObject {

        private var proto = DifftServiceProtos_AttachmentPointer()

        @objc
        fileprivate override init() {}

        @objc
        public func setId(_ valueParam: UInt64) {
            proto.id = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContentType(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.contentType = valueParam
        }

        public func setContentType(_ valueParam: String) {
            proto.contentType = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setKey(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.key = valueParam
        }

        public func setKey(_ valueParam: Data) {
            proto.key = valueParam
        }

        @objc
        public func setSize(_ valueParam: UInt32) {
            proto.size = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setThumbnail(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.thumbnail = valueParam
        }

        public func setThumbnail(_ valueParam: Data) {
            proto.thumbnail = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setDigest(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.digest = valueParam
        }

        public func setDigest(_ valueParam: Data) {
            proto.digest = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setFileName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.fileName = valueParam
        }

        public func setFileName(_ valueParam: String) {
            proto.fileName = valueParam
        }

        @objc
        public func setFlags(_ valueParam: UInt32) {
            proto.flags = valueParam
        }

        @objc
        public func setWidth(_ valueParam: UInt32) {
            proto.width = valueParam
        }

        @objc
        public func setHeight(_ valueParam: UInt32) {
            proto.height = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoAttachmentPointer {
            return try DSKProtoAttachmentPointer(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoAttachmentPointer(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_AttachmentPointer

    @objc
    public var id: UInt64 {
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    @objc
    public var contentType: String? {
        guard hasContentType else {
            return nil
        }
        return proto.contentType
    }
    @objc
    public var hasContentType: Bool {
        return proto.hasContentType
    }

    @objc
    public var key: Data? {
        guard hasKey else {
            return nil
        }
        return proto.key
    }
    @objc
    public var hasKey: Bool {
        return proto.hasKey
    }

    @objc
    public var size: UInt32 {
        return proto.size
    }
    @objc
    public var hasSize: Bool {
        return proto.hasSize
    }

    @objc
    public var thumbnail: Data? {
        guard hasThumbnail else {
            return nil
        }
        return proto.thumbnail
    }
    @objc
    public var hasThumbnail: Bool {
        return proto.hasThumbnail
    }

    @objc
    public var digest: Data? {
        guard hasDigest else {
            return nil
        }
        return proto.digest
    }
    @objc
    public var hasDigest: Bool {
        return proto.hasDigest
    }

    @objc
    public var fileName: String? {
        guard hasFileName else {
            return nil
        }
        return proto.fileName
    }
    @objc
    public var hasFileName: Bool {
        return proto.hasFileName
    }

    @objc
    public var flags: UInt32 {
        return proto.flags
    }
    @objc
    public var hasFlags: Bool {
        return proto.hasFlags
    }

    @objc
    public var width: UInt32 {
        return proto.width
    }
    @objc
    public var hasWidth: Bool {
        return proto.hasWidth
    }

    @objc
    public var height: UInt32 {
        return proto.height
    }
    @objc
    public var hasHeight: Bool {
        return proto.hasHeight
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_AttachmentPointer) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_AttachmentPointer(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_AttachmentPointer) throws {
        // MARK: - Begin Validation Logic for DSKProtoAttachmentPointer -

        // MARK: - End Validation Logic for DSKProtoAttachmentPointer -

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

extension DSKProtoAttachmentPointer {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoAttachmentPointer.DSKProtoAttachmentPointerBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoAttachmentPointer? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoGroupContextType

@objc
public enum DSKProtoGroupContextType: Int32 {
    case unknown = 0
    case update = 1
    case deliver = 2
    case quit = 3
    case requestInfo = 4
}

private func DSKProtoGroupContextTypeWrap(_ value: DifftServiceProtos_GroupContext.TypeEnum) -> DSKProtoGroupContextType {
    switch value {
    case .unknown: return .unknown
    case .update: return .update
    case .deliver: return .deliver
    case .quit: return .quit
    case .requestInfo: return .requestInfo
    }
}

private func DSKProtoGroupContextTypeUnwrap(_ value: DSKProtoGroupContextType) -> DifftServiceProtos_GroupContext.TypeEnum {
    switch value {
    case .unknown: return .unknown
    case .update: return .update
    case .deliver: return .deliver
    case .quit: return .quit
    case .requestInfo: return .requestInfo
    }
}

// MARK: - DSKProtoGroupContext

@objc
public class DSKProtoGroupContext: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoGroupContextBuilder

    @objc
    public static func builder() -> DSKProtoGroupContextBuilder {
        return DSKProtoGroupContextBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoGroupContextBuilder {
        let builder = DSKProtoGroupContextBuilder()
        if let _value = id {
            builder.setId(_value)
        }
        if let _value = type {
            builder.setType(_value)
        }
        if let _value = name {
            builder.setName(_value)
        }
        builder.setMembers(members)
        if let _value = avatar {
            builder.setAvatar(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoGroupContextBuilder: NSObject {

        private var proto = DifftServiceProtos_GroupContext()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setId(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.id = valueParam
        }

        public func setId(_ valueParam: Data) {
            proto.id = valueParam
        }

        @objc
        public func setType(_ valueParam: DSKProtoGroupContextType) {
            proto.type = DSKProtoGroupContextTypeUnwrap(valueParam)
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        @objc
        public func addMembers(_ valueParam: String) {
            proto.members.append(valueParam)
        }

        @objc
        public func setMembers(_ wrappedItems: [String]) {
            proto.members = wrappedItems
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAvatar(_ valueParam: DSKProtoAttachmentPointer?) {
            guard let valueParam = valueParam else { return }
            proto.avatar = valueParam.proto
        }

        public func setAvatar(_ valueParam: DSKProtoAttachmentPointer) {
            proto.avatar = valueParam.proto
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoGroupContext {
            return try DSKProtoGroupContext(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoGroupContext(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_GroupContext

    @objc
    public let avatar: DSKProtoAttachmentPointer?

    @objc
    public var id: Data? {
        guard hasID else {
            return nil
        }
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    public var type: DSKProtoGroupContextType? {
        guard hasType else {
            return nil
        }
        return DSKProtoGroupContextTypeWrap(proto.type)
    }
    // This "unwrapped" accessor should only be used if the "has value" accessor has already been checked.
    @objc
    public var unwrappedType: DSKProtoGroupContextType {
        if !hasType {
            // TODO: We could make this a crashing assert.
            owsFailDebug("Unsafe unwrap of missing optional: GroupContext.type.")
        }
        return DSKProtoGroupContextTypeWrap(proto.type)
    }
    @objc
    public var hasType: Bool {
        return proto.hasType
    }

    @objc
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    @objc
    public var members: [String] {
        return proto.members
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_GroupContext,
                 avatar: DSKProtoAttachmentPointer?) {
        self.proto = proto
        self.avatar = avatar
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_GroupContext(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_GroupContext) throws {
        var avatar: DSKProtoAttachmentPointer?
        if proto.hasAvatar {
            avatar = try DSKProtoAttachmentPointer(proto.avatar)
        }

        // MARK: - Begin Validation Logic for DSKProtoGroupContext -

        // MARK: - End Validation Logic for DSKProtoGroupContext -

        self.init(proto: proto,
                  avatar: avatar)
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

extension DSKProtoGroupContext {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoGroupContext.DSKProtoGroupContextBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoGroupContext? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoContactDetailsAvatar

@objc
public class DSKProtoContactDetailsAvatar: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoContactDetailsAvatarBuilder

    @objc
    public static func builder() -> DSKProtoContactDetailsAvatarBuilder {
        return DSKProtoContactDetailsAvatarBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoContactDetailsAvatarBuilder {
        let builder = DSKProtoContactDetailsAvatarBuilder()
        if let _value = contentType {
            builder.setContentType(_value)
        }
        if hasLength {
            builder.setLength(length)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoContactDetailsAvatarBuilder: NSObject {

        private var proto = DifftServiceProtos_ContactDetails.Avatar()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContentType(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.contentType = valueParam
        }

        public func setContentType(_ valueParam: String) {
            proto.contentType = valueParam
        }

        @objc
        public func setLength(_ valueParam: UInt32) {
            proto.length = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoContactDetailsAvatar {
            return try DSKProtoContactDetailsAvatar(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoContactDetailsAvatar(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ContactDetails.Avatar

    @objc
    public var contentType: String? {
        guard hasContentType else {
            return nil
        }
        return proto.contentType
    }
    @objc
    public var hasContentType: Bool {
        return proto.hasContentType
    }

    @objc
    public var length: UInt32 {
        return proto.length
    }
    @objc
    public var hasLength: Bool {
        return proto.hasLength
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ContactDetails.Avatar) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ContactDetails.Avatar(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ContactDetails.Avatar) throws {
        // MARK: - Begin Validation Logic for DSKProtoContactDetailsAvatar -

        // MARK: - End Validation Logic for DSKProtoContactDetailsAvatar -

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

extension DSKProtoContactDetailsAvatar {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoContactDetailsAvatar.DSKProtoContactDetailsAvatarBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoContactDetailsAvatar? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoContactDetails

@objc
public class DSKProtoContactDetails: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoContactDetailsBuilder

    @objc
    public static func builder() -> DSKProtoContactDetailsBuilder {
        return DSKProtoContactDetailsBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoContactDetailsBuilder {
        let builder = DSKProtoContactDetailsBuilder()
        if let _value = number {
            builder.setNumber(_value)
        }
        if let _value = name {
            builder.setName(_value)
        }
        if let _value = avatar {
            builder.setAvatar(_value)
        }
        if let _value = color {
            builder.setColor(_value)
        }
        if let _value = verified {
            builder.setVerified(_value)
        }
        if let _value = profileKey {
            builder.setProfileKey(_value)
        }
        if hasBlocked {
            builder.setBlocked(blocked)
        }
        if hasExpireTimer {
            builder.setExpireTimer(expireTimer)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoContactDetailsBuilder: NSObject {

        private var proto = DifftServiceProtos_ContactDetails()

        @objc
        fileprivate override init() {}

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
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAvatar(_ valueParam: DSKProtoContactDetailsAvatar?) {
            guard let valueParam = valueParam else { return }
            proto.avatar = valueParam.proto
        }

        public func setAvatar(_ valueParam: DSKProtoContactDetailsAvatar) {
            proto.avatar = valueParam.proto
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setColor(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.color = valueParam
        }

        public func setColor(_ valueParam: String) {
            proto.color = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setVerified(_ valueParam: DSKProtoVerified?) {
            guard let valueParam = valueParam else { return }
            proto.verified = valueParam.proto
        }

        public func setVerified(_ valueParam: DSKProtoVerified) {
            proto.verified = valueParam.proto
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
        public func setBlocked(_ valueParam: Bool) {
            proto.blocked = valueParam
        }

        @objc
        public func setExpireTimer(_ valueParam: UInt32) {
            proto.expireTimer = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoContactDetails {
            return try DSKProtoContactDetails(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoContactDetails(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_ContactDetails

    @objc
    public let avatar: DSKProtoContactDetailsAvatar?

    @objc
    public let verified: DSKProtoVerified?

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
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    @objc
    public var color: String? {
        guard hasColor else {
            return nil
        }
        return proto.color
    }
    @objc
    public var hasColor: Bool {
        return proto.hasColor
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
    public var blocked: Bool {
        return proto.blocked
    }
    @objc
    public var hasBlocked: Bool {
        return proto.hasBlocked
    }

    @objc
    public var expireTimer: UInt32 {
        return proto.expireTimer
    }
    @objc
    public var hasExpireTimer: Bool {
        return proto.hasExpireTimer
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_ContactDetails,
                 avatar: DSKProtoContactDetailsAvatar?,
                 verified: DSKProtoVerified?) {
        self.proto = proto
        self.avatar = avatar
        self.verified = verified
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_ContactDetails(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_ContactDetails) throws {
        var avatar: DSKProtoContactDetailsAvatar?
        if proto.hasAvatar {
            avatar = try DSKProtoContactDetailsAvatar(proto.avatar)
        }

        var verified: DSKProtoVerified?
        if proto.hasVerified {
            verified = try DSKProtoVerified(proto.verified)
        }

        // MARK: - Begin Validation Logic for DSKProtoContactDetails -

        // MARK: - End Validation Logic for DSKProtoContactDetails -

        self.init(proto: proto,
                  avatar: avatar,
                  verified: verified)
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

extension DSKProtoContactDetails {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoContactDetails.DSKProtoContactDetailsBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoContactDetails? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoGroupDetailsAvatar

@objc
public class DSKProtoGroupDetailsAvatar: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoGroupDetailsAvatarBuilder

    @objc
    public static func builder() -> DSKProtoGroupDetailsAvatarBuilder {
        return DSKProtoGroupDetailsAvatarBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoGroupDetailsAvatarBuilder {
        let builder = DSKProtoGroupDetailsAvatarBuilder()
        if let _value = contentType {
            builder.setContentType(_value)
        }
        if hasLength {
            builder.setLength(length)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoGroupDetailsAvatarBuilder: NSObject {

        private var proto = DifftServiceProtos_GroupDetails.Avatar()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setContentType(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.contentType = valueParam
        }

        public func setContentType(_ valueParam: String) {
            proto.contentType = valueParam
        }

        @objc
        public func setLength(_ valueParam: UInt32) {
            proto.length = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoGroupDetailsAvatar {
            return try DSKProtoGroupDetailsAvatar(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoGroupDetailsAvatar(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_GroupDetails.Avatar

    @objc
    public var contentType: String? {
        guard hasContentType else {
            return nil
        }
        return proto.contentType
    }
    @objc
    public var hasContentType: Bool {
        return proto.hasContentType
    }

    @objc
    public var length: UInt32 {
        return proto.length
    }
    @objc
    public var hasLength: Bool {
        return proto.hasLength
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_GroupDetails.Avatar) {
        self.proto = proto
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_GroupDetails.Avatar(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_GroupDetails.Avatar) throws {
        // MARK: - Begin Validation Logic for DSKProtoGroupDetailsAvatar -

        // MARK: - End Validation Logic for DSKProtoGroupDetailsAvatar -

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

extension DSKProtoGroupDetailsAvatar {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoGroupDetailsAvatar.DSKProtoGroupDetailsAvatarBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoGroupDetailsAvatar? {
        return try! self.build()
    }
}

#endif

// MARK: - DSKProtoGroupDetails

@objc
public class DSKProtoGroupDetails: NSObject, Codable, NSSecureCoding {

    // MARK: - DSKProtoGroupDetailsBuilder

    @objc
    public static func builder() -> DSKProtoGroupDetailsBuilder {
        return DSKProtoGroupDetailsBuilder()
    }

    // asBuilder() constructs a builder that reflects the proto's contents.
    @objc
    public func asBuilder() -> DSKProtoGroupDetailsBuilder {
        let builder = DSKProtoGroupDetailsBuilder()
        if let _value = id {
            builder.setId(_value)
        }
        if let _value = name {
            builder.setName(_value)
        }
        builder.setMembers(members)
        if let _value = avatar {
            builder.setAvatar(_value)
        }
        if hasActive {
            builder.setActive(active)
        }
        if hasExpireTimer {
            builder.setExpireTimer(expireTimer)
        }
        if let _value = color {
            builder.setColor(_value)
        }
        if let _value = unknownFields {
            builder.setUnknownFields(_value)
        }
        return builder
    }

    @objc
    public class DSKProtoGroupDetailsBuilder: NSObject {

        private var proto = DifftServiceProtos_GroupDetails()

        @objc
        fileprivate override init() {}

        @objc
        @available(swift, obsoleted: 1.0)
        public func setId(_ valueParam: Data?) {
            guard let valueParam = valueParam else { return }
            proto.id = valueParam
        }

        public func setId(_ valueParam: Data) {
            proto.id = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setName(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.name = valueParam
        }

        public func setName(_ valueParam: String) {
            proto.name = valueParam
        }

        @objc
        public func addMembers(_ valueParam: String) {
            proto.members.append(valueParam)
        }

        @objc
        public func setMembers(_ wrappedItems: [String]) {
            proto.members = wrappedItems
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setAvatar(_ valueParam: DSKProtoGroupDetailsAvatar?) {
            guard let valueParam = valueParam else { return }
            proto.avatar = valueParam.proto
        }

        public func setAvatar(_ valueParam: DSKProtoGroupDetailsAvatar) {
            proto.avatar = valueParam.proto
        }

        @objc
        public func setActive(_ valueParam: Bool) {
            proto.active = valueParam
        }

        @objc
        public func setExpireTimer(_ valueParam: UInt32) {
            proto.expireTimer = valueParam
        }

        @objc
        @available(swift, obsoleted: 1.0)
        public func setColor(_ valueParam: String?) {
            guard let valueParam = valueParam else { return }
            proto.color = valueParam
        }

        public func setColor(_ valueParam: String) {
            proto.color = valueParam
        }

        public func setUnknownFields(_ unknownFields: SwiftProtobuf.UnknownStorage) {
            proto.unknownFields = unknownFields
        }

        @objc
        public func build() throws -> DSKProtoGroupDetails {
            return try DSKProtoGroupDetails(proto)
        }

        @objc
        public func buildSerializedData() throws -> Data {
            return try DSKProtoGroupDetails(proto).serializedData()
        }
    }

    fileprivate let proto: DifftServiceProtos_GroupDetails

    @objc
    public let avatar: DSKProtoGroupDetailsAvatar?

    @objc
    public var id: Data? {
        guard hasID else {
            return nil
        }
        return proto.id
    }
    @objc
    public var hasID: Bool {
        return proto.hasID
    }

    @objc
    public var name: String? {
        guard hasName else {
            return nil
        }
        return proto.name
    }
    @objc
    public var hasName: Bool {
        return proto.hasName
    }

    @objc
    public var members: [String] {
        return proto.members
    }

    @objc
    public var active: Bool {
        return proto.active
    }
    @objc
    public var hasActive: Bool {
        return proto.hasActive
    }

    @objc
    public var expireTimer: UInt32 {
        return proto.expireTimer
    }
    @objc
    public var hasExpireTimer: Bool {
        return proto.hasExpireTimer
    }

    @objc
    public var color: String? {
        guard hasColor else {
            return nil
        }
        return proto.color
    }
    @objc
    public var hasColor: Bool {
        return proto.hasColor
    }

    public var hasUnknownFields: Bool {
        return !proto.unknownFields.data.isEmpty
    }
    public var unknownFields: SwiftProtobuf.UnknownStorage? {
        guard hasUnknownFields else { return nil }
        return proto.unknownFields
    }

    private init(proto: DifftServiceProtos_GroupDetails,
                 avatar: DSKProtoGroupDetailsAvatar?) {
        self.proto = proto
        self.avatar = avatar
    }

    @objc
    public func serializedData() throws -> Data {
        return try self.proto.serializedData()
    }

    @objc
    public convenience init(serializedData: Data) throws {
        let proto = try DifftServiceProtos_GroupDetails(serializedData: serializedData)
        try self.init(proto)
    }

    fileprivate convenience init(_ proto: DifftServiceProtos_GroupDetails) throws {
        var avatar: DSKProtoGroupDetailsAvatar?
        if proto.hasAvatar {
            avatar = try DSKProtoGroupDetailsAvatar(proto.avatar)
        }

        // MARK: - Begin Validation Logic for DSKProtoGroupDetails -

        // MARK: - End Validation Logic for DSKProtoGroupDetails -

        self.init(proto: proto,
                  avatar: avatar)
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

extension DSKProtoGroupDetails {
    @objc
    public func serializedDataIgnoringErrors() -> Data? {
        return try! self.serializedData()
    }
}

extension DSKProtoGroupDetails.DSKProtoGroupDetailsBuilder {
    @objc
    public func buildIgnoringErrors() -> DSKProtoGroupDetails? {
        return try! self.build()
    }
}

#endif
