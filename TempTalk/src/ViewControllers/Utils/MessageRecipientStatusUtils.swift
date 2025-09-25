//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

@objc public enum MessageReceiptStatus: Int {
    case uploading
    case sending
    case sent
    case delivered
    case read
    case failed
    case skipped
}

@objc
public class MessageRecipientStatusUtils: NSObject {
    // MARK: Initializers

    @available(*, unavailable, message:"do not instantiate this class.")
    private override init() {
    }

    // This method is per-recipient.
    @objc
    public class func recipientStatus(outgoingMessage: TSOutgoingMessage,
            recipientState: TSOutgoingMessageRecipientState) -> MessageReceiptStatus {
        let (messageReceiptStatus, _, _) = recipientStatusAndStatusMessage(outgoingMessage: outgoingMessage,
                                                                             recipientState: recipientState)
        return messageReceiptStatus
    }

    // This method is per-recipient.
    @objc
    public class func shortStatusMessage(outgoingMessage: TSOutgoingMessage,
        recipientState: TSOutgoingMessageRecipientState) -> String {
        let (_, shortStatusMessage, _) = recipientStatusAndStatusMessage(outgoingMessage: outgoingMessage,
                                                                         recipientState: recipientState)
        return shortStatusMessage
    }

    // This method is per-recipient.
    @objc
    public class func longStatusMessage(outgoingMessage: TSOutgoingMessage,
        recipientState: TSOutgoingMessageRecipientState) -> String {
        let (_, _, longStatusMessage) = recipientStatusAndStatusMessage(outgoingMessage: outgoingMessage,
                                                                        recipientState: recipientState)
        return longStatusMessage
    }

    // This method is per-recipient.
    class func recipientStatusAndStatusMessage(outgoingMessage: TSOutgoingMessage,
        recipientState: TSOutgoingMessageRecipientState) -> (status: MessageReceiptStatus, shortStatusMessage: String, longStatusMessage: String) {

        switch recipientState.state {
        case .failed:
            let shortStatusMessage = Localized("MESSAGE_STATUS_FAILED_SHORT", comment: "status message for failed messages")
            let longStatusMessage = Localized("MESSAGE_STATUS_FAILED", comment: "status message for failed messages")
            return (status:.failed, shortStatusMessage:shortStatusMessage, longStatusMessage:longStatusMessage)
        case .sending:
            if outgoingMessage.hasAttachments() {
                assert(outgoingMessage.messageState == .sending)

                let statusMessage = Localized("MESSAGE_STATUS_UPLOADING",
                                                      comment: "status message while attachment is uploading")
                return (status:.uploading, shortStatusMessage:statusMessage, longStatusMessage:statusMessage)
            } else {
                assert(outgoingMessage.messageState == .sending)

                let statusMessage = Localized("MESSAGE_STATUS_SENDING",
                                                      comment: "message status while message is sending.")
                return (status:.sending, shortStatusMessage:statusMessage, longStatusMessage:statusMessage)
            }
        case .sent:
            if let readTimestamp = recipientState.readTimestamp {
                let timestampString = DateUtil.formatPastTimestampRelativeToNow(readTimestamp.uint64Value)
                let shortStatusMessage = timestampString
                let longStatusMessage = Localized("MESSAGE_STATUS_READ", comment: "status message for read messages").rtlSafeAppend(" ")
                    .rtlSafeAppend(timestampString)
                return (status:.read, shortStatusMessage:shortStatusMessage, longStatusMessage:longStatusMessage)
            }
            if let deliveryTimestamp = recipientState.deliveryTimestamp {
                let timestampString = DateUtil.formatPastTimestampRelativeToNow(deliveryTimestamp.uint64Value)
                let shortStatusMessage = timestampString
                let longStatusMessage = Localized("MESSAGE_STATUS_DELIVERED",
                                                          comment: "message status for message delivered to their recipient.").rtlSafeAppend(" ")
                    .rtlSafeAppend(timestampString)
                return (status:.delivered, shortStatusMessage:shortStatusMessage, longStatusMessage:longStatusMessage)
            }
            let statusMessage =
                Localized("MESSAGE_STATUS_SENT",
                                  comment: "status message for sent messages")
            return (status:.sent, shortStatusMessage:statusMessage, longStatusMessage:statusMessage)
        case .skipped:
            let statusMessage = Localized("MESSAGE_STATUS_RECIPIENT_SKIPPED",
                                                  comment: "message status if message delivery to a recipient is skipped. We skip delivering group messages to users who have left the group or unregistered their Signal account.")
            return (status:.skipped, shortStatusMessage:statusMessage, longStatusMessage:statusMessage)
        }
    }
    
    internal class func receiptStatusAndMessage(outgoingMessage: TSOutgoingMessage, thread: TSThread = TSGroupThread.init()) -> (status: MessageReceiptStatus, message: String) {

        switch outgoingMessage.messageState {
        case .failed:
            // Use the "long" version of this message here.
            return (.failed, Localized("MESSAGE_STATUS_FAILED", comment: "status message for failed messages"))
        case .sending:
            if outgoingMessage.hasAttachments() {
                return (.uploading, Localized("MESSAGE_STATUS_UPLOADING",
                                         comment: "status message while attachment is uploading"))
            } else {
                return (.sending, Localized("MESSAGE_STATUS_SENDING",
                                         comment: "message status while message is sending."))
            }
        case .sent:
            // TODO: check felix 2022-11-29
            if outgoingMessage.readRecipientIds().count > 0 || (thread.isWithoutReadRecipt()) {
                return (.read, Localized("MESSAGE_STATUS_READ", comment: "status message for read messages"))
            }
            if outgoingMessage.wasDeliveredToAnyRecipient {
                return (.delivered, Localized("MESSAGE_STATUS_DELIVERED",
                                         comment: "message status for message delivered to their recipient."))
            }
            return (.sent, Localized("MESSAGE_STATUS_SENT",
                                     comment: "status message for sent messages"))
        default:
            owsFailDebug("\(self.logTag) Message has unexpected status: \(outgoingMessage.messageState).")
            return (.sent, Localized("MESSAGE_STATUS_SENT",
                                     comment: "status message for sent messages"))
        }
    }

    // This method is per-message.
    @objc
    public class func receiptMessage(outgoingMessage: TSOutgoingMessage) -> String {
        let (_, message ) = receiptStatusAndMessage(outgoingMessage: outgoingMessage)
        return message
    }

    // This method is per-message.
    @objc
    public class func recipientStatus(outgoingMessage: TSOutgoingMessage) -> MessageReceiptStatus {
        let (status, _ ) = receiptStatusAndMessage(outgoingMessage: outgoingMessage)
        return status
    }
    
    @objc
    public class func recipientStatus(outgoingMessage: TSOutgoingMessage, thread: TSThread = TSGroupThread.init(), transaction: SDSAnyReadTransaction) -> MessageReceiptStatus {
//        guard let thread = outgoingMessage.thread(with: transaction) else {
//            let (status, _ ) = receiptStatusAndMessage(outgoingMessage: outgoingMessage)
//            return status
//        }
        
        let (status, _ ) = receiptStatusAndMessage(outgoingMessage: outgoingMessage, thread: thread)
        return status
    }

    @objc
    public class func description(forMessageReceiptStatus value: MessageReceiptStatus) -> String {
        switch(value) {
        case .read:
            return "read"
        case .uploading:
            return "uploading"
        case .delivered:
            return "delivered"
        case .sent:
            return "sent"
        case .sending:
            return "sending"
        case .failed:
            return "failed"
        case .skipped:
            return "skipped"
        }
    }
}
