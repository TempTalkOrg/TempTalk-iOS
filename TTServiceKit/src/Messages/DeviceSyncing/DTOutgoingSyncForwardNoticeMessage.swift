import Foundation

@objcMembers
public class DTOutgoingSyncForwardNoticeMessage: OWSOutgoingSyncMessage {

    private let sceneValue: DTForwardNoticeScene
    private let sourceAuthorIdsValue: [String]
    private let messageCountValue: UInt32
    private let sourceConversation: DTForwardNoticeConversation
    private let targetThread: TSThread

    @objc
    public init(thread: TSThread,
                scene: DTForwardNoticeScene,
                sourceAuthorIds: [String],
                messageCount: UInt32,
                sourceConversation: DTForwardNoticeConversation) {
        self.targetThread = thread
        self.sceneValue = scene
        self.sourceAuthorIdsValue = sourceAuthorIds
        self.messageCountValue = messageCount
        self.sourceConversation = sourceConversation
        super.init(syncMessageWithTimestamp: NSDate.ows_millisecondTimeStamp())
    }

    @objc
    public required init!(coder: NSCoder) {
        fatalError("DTOutgoingSyncForwardNoticeMessage does not support NSCoding")
    }

    @objc
    public required init(dictionary dictionaryValue: [String : Any]!) throws {
        fatalError("DTOutgoingSyncForwardNoticeMessage does not support dictionary init")
    }

    public override var uniqueThreadId: String {
        targetThread.uniqueId
    }

    public override func buildPlainTextData(_ recipient: SignalRecipient) -> Data? {
        do {
            let noticeBuilder = DSKProtoForwardNoticeMessage.builder()
            noticeBuilder.setScene(sceneValue.protoValue)
            noticeBuilder.setSourceAuthorIds(sourceAuthorIdsValue)
            noticeBuilder.setMessageCount(messageCountValue)
            noticeBuilder.setConversation(try sourceConversation.buildProto())

            let syncMessageBuilder = DSKProtoSyncMessage.builder()
            syncMessageBuilder.setForwardNoticeSync(try noticeBuilder.build())

            let contentBuilder = DSKProtoContent.builder()
            contentBuilder.setSyncMessage(try syncMessageBuilder.build())
            return try contentBuilder.buildSerializedData()
        } catch {
            owsFailDebug("[ForwardNotice] Failed to build sync content: \(error)")
            return nil
        }
    }
}
