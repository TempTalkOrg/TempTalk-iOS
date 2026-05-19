import Foundation

@objc
public class TSOutgoingGroupKeyMessage: TSOutgoingMessage {

    private let groupIdValue: Data
    private let groupRootKeyValue: Data

    @objc
    public init(thread: TSThread, groupId: Data, groupRootKey: Data) {
        self.groupIdValue = groupId
        self.groupRootKeyValue = groupRootKey
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
        fatalError("TSOutgoingGroupKeyMessage does not support NSCoding")
    }

    @objc
    public required init(dictionary dictionaryValue: [String: Any]!) throws {
        fatalError("TSOutgoingGroupKeyMessage does not support dictionary init")
    }

    public override func shouldBeSaved() -> Bool { false }
    public override func shouldSyncTranscript() -> Bool { false }
    public override var isSilent: Bool { true }
    public override var messageState: TSOutgoingMessageState { .sent }

    public override func buildPlainTextData(_ recipient: SignalRecipient) -> Data? {
        let groupKeyBuilder = DSKProtoGroupKeyMessage.builder()
        groupKeyBuilder.setGroupID(groupIdValue)
        groupKeyBuilder.setGroupRootKey(groupRootKeyValue)

        do {
            let groupKeyMessage = try groupKeyBuilder.build()
            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setGroupKeyMessage(groupKeyMessage)
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[GroupCrypto] Failed to build GroupKeyMessage: \(error)")
            return nil
        }
    }
}
