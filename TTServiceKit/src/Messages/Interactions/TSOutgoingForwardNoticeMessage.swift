import Foundation

@objc
public enum DTForwardNoticeScene: UInt32 {
    case single = 1
    case oneByOne = 2
    case combined = 3
    case saveToNotes = 4

    public var protoValue: DSKProtoForwardNoticeMessageForwardScene {
        switch self {
        case .single:
            return .single
        case .oneByOne:
            return .oneByOne
        case .combined:
            return .combined
        case .saveToNotes:
            return .saveToNotes
        }
    }
}

@objc
public enum DTForwardNoticeConversationScope: Int {
    case group
    case oneOnOne
    case noteToSelf
}

@objcMembers
public final class DTForwardNoticeConversation: NSObject {
    public let scope: DTForwardNoticeConversationScope
    public let number: String?
    public let groupId: Data?

    @objc
    public init(scope: DTForwardNoticeConversationScope, number: String?, groupId: Data?) {
        self.scope = scope
        self.number = number
        self.groupId = groupId
    }

    @objc
    public static func group(groupId: Data) -> DTForwardNoticeConversation {
        DTForwardNoticeConversation(scope: .group, number: nil, groupId: groupId)
    }

    @objc
    public static func oneOnOne(number: String) -> DTForwardNoticeConversation {
        DTForwardNoticeConversation(scope: .oneOnOne, number: number, groupId: nil)
    }

    @objc
    public static func noteToSelf(localNumber: String) -> DTForwardNoticeConversation {
        DTForwardNoticeConversation(scope: .noteToSelf, number: localNumber, groupId: nil)
    }

    func buildProto() throws -> DSKProtoConversationId {
        let builder = DSKProtoConversationId.builder()
        if let groupId { builder.setGroupID(groupId) }
        if let number, !number.isEmpty { builder.setNumber(number) }
        return try builder.build()
    }
}

@objcMembers
public class TSOutgoingForwardNoticeMessage: TSOutgoingMessage {

    private let sceneValue: DTForwardNoticeScene
    private let sourceAuthorIdsValue: [String]
    private let messageCountValue: UInt32
    private let sourceConversation: DTForwardNoticeConversation

    @objc
    public init(thread: TSThread,
                scene: DTForwardNoticeScene,
                sourceAuthorIds: [String],
                messageCount: UInt32,
                sourceConversation: DTForwardNoticeConversation) {
        self.sceneValue = scene
        self.sourceAuthorIdsValue = sourceAuthorIds
        self.messageCountValue = messageCount
        self.sourceConversation = sourceConversation

        super.init(outgoingMessageWithTimestamp: NSDate.ows_millisecondTimeStamp(),
                   in: thread,
                   messageBody: nil,
                   atPersons: nil,
                   mentions: nil,
                   attachmentIds: NSMutableArray(),
                   expiresInSeconds: 0,
                   expireStartedAt: 0,
                   isVoiceMessage: false,
                   groupMetaMessage: .messageUnspecified,
                   quotedMessage: nil,
                   forwardingMessage: nil,
                   contactShare: nil)
    }

    @objc
    public required init!(coder: NSCoder) {
        fatalError("TSOutgoingForwardNoticeMessage does not support NSCoding")
    }

    @objc
    public required init(dictionary dictionaryValue: [String : Any]!) throws {
        fatalError("TSOutgoingForwardNoticeMessage does not support dictionary init")
    }

    public override func shouldBeSaved() -> Bool { false }

    public override func shouldSyncTranscript() -> Bool {
        sourceConversation.scope == .oneOnOne
    }

    public override var isSilent: Bool { true }
    public override var messageState: TSOutgoingMessageState { .sent }

    public override func buildPlainTextData(_ recipient: SignalRecipient) -> Data? {
        do {
            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setForwardNotice(try buildForwardNoticeProto())
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[ForwardNotice] Failed to build outgoing content: \(error)")
            return nil
        }
    }

    @objc
    public func buildSyncPlainTextData(_ recipient: SignalRecipient) -> Data? {
        do {
            let syncMessageBuilder = DSKProtoSyncMessage.builder()
            syncMessageBuilder.setForwardNoticeSync(try buildForwardNoticeProto())

            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setSyncMessage(try syncMessageBuilder.build())
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[ForwardNotice] Failed to build sync content: \(error)")
            return nil
        }
    }

    private func buildForwardNoticeProto() throws -> DSKProtoForwardNoticeMessage {
        let noticeBuilder = DSKProtoForwardNoticeMessage.builder()
        noticeBuilder.setScene(sceneValue.protoValue)
        noticeBuilder.setSourceAuthorIds(sourceAuthorIdsValue)
        noticeBuilder.setMessageCount(messageCountValue)
        noticeBuilder.setConversation(try sourceConversation.buildProto())
        return try noticeBuilder.build()
    }
}
