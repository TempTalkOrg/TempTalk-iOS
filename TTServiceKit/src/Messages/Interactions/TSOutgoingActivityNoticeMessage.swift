import Foundation

@objcMembers
public class TSOutgoingActivityNoticeMessage: TSOutgoingMessage {

    private let sourceAuthorIdsValue: [String]
    private let messageCountValue: UInt32
    private let sourceConversation: DTForwardNoticeConversation
    private let combinedForwardModeValue: DTForwardNoticeCombinedForwardMode

    @objc
    public init(thread: TSThread,
                sourceAuthorIds: [String],
                messageCount: UInt32,
                sourceConversation: DTForwardNoticeConversation,
                combinedForwardMode: DTForwardNoticeCombinedForwardMode = .unknown) {
        self.sourceAuthorIdsValue = sourceAuthorIds
        self.messageCountValue = messageCount
        self.sourceConversation = sourceConversation
        self.combinedForwardModeValue = combinedForwardMode

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
        fatalError("TSOutgoingActivityNoticeMessage does not support NSCoding")
    }

    @objc
    public required init(dictionary dictionaryValue: [String : Any]!) throws {
        fatalError("TSOutgoingActivityNoticeMessage does not support dictionary init")
    }

    public override func shouldBeSaved() -> Bool { false }

    public override func shouldSyncTranscript() -> Bool {
        // Sync to other linked devices for 1:1 and Saved (note-to-self); group notices don't sync.
        sourceConversation.scope != .group
    }

    public override var isSilent: Bool { true }
    public override var messageState: TSOutgoingMessageState { .sent }

    public override func buildPlainTextData(_ recipient: SignalRecipient) -> Data? {
        do {
            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setActivityNotice(try buildActivityNoticeProto())
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[ActivityNotice] Failed to build outgoing content: \(error)")
            return nil
        }
    }

    @objc
    public func buildSyncPlainTextData(_ recipient: SignalRecipient) -> Data? {
        do {
            let syncMessageBuilder = DSKProtoSyncMessage.builder()
            syncMessageBuilder.setActivityNoticeSync(try buildActivityNoticeProto())

            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setSyncMessage(try syncMessageBuilder.build())
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[ActivityNotice] Failed to build sync content: \(error)")
            return nil
        }
    }

    private func buildActivityNoticeProto() throws -> DSKProtoMessageActivityNotice {
        let copyDataBuilder = DSKProtoCopyData.builder()
        copyDataBuilder.setSourceAuthorIds(sourceAuthorIdsValue)
        copyDataBuilder.setMessageCount(messageCountValue)
        if combinedForwardModeValue != .unknown {
            copyDataBuilder.setCombinedForwardMode(combinedForwardModeValue.protoValue)
        }

        let noticeBuilder = DSKProtoMessageActivityNotice.builder()
        noticeBuilder.setConversation(try sourceConversation.buildProto())
        noticeBuilder.setTypeData(.copyData(try copyDataBuilder.build()))
        return try noticeBuilder.build()
    }
}
