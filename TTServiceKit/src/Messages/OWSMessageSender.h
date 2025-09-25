//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DataSource.h"
#import "ContactsManagerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

///超长文本转附件阀值
extern const NSUInteger kOversizeTextMessageSizeThreshold;
///最大翻译的字符长度
extern const NSUInteger kOversizeTextMessageSizelength;
///超长文本body长度
extern const NSUInteger kOversizeTextMessageBodyLength;

@class ContactsUpdater;
@class OWSUploadingService;
@class SignalRecipient;
@class TSOutgoingMessage;
@class TSThread;
@class TSMessage;

@protocol ContactsManagerProtocol;

/**
 * Useful for when you *sometimes* want to retry before giving up and calling the failure handler
 * but *sometimes* we don't want to retry when we know it's a terminal failure, so we allow the
 * caller to indicate this with isRetryable=NO.
 */
typedef void (^RetryableFailureHandler)(NSError *_Nonnull error);

// Message send error handling is slightly different for contact and group messages.
//
// For example, If one member of a group deletes their account, the group should
// ignore errors when trying to send messages to this ex-member.

#pragma mark -

NS_SWIFT_NAME(MessageSender)
@interface OWSMessageSender : NSObject {

@protected

    // For subclassing in tests
    OWSUploadingService *_uploadingService;
    ContactsUpdater *_contactsUpdater;
}

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithContactsManager:(id<ContactsManagerProtocol>)contactsManager
                       contactsUpdater:(ContactsUpdater *)contactsUpdater;

/**
 * Send and resend text messages or resend messages with existing attachments.
 * If you haven't yet created the attachment, see the ` enqueueAttachment:` variants.
 */
// TODO: make transaction nonnull and remove `sendMessage:success:failure`
- (void)enqueueMessage:(TSOutgoingMessage *)message
               success:(void (^)(void))successHandler
               failure:(void (^)(NSError *error))failureHandler;

/**
 * Takes care of allocating and uploading the attachment, then sends the message.
 * Only necessary to call once. If sending fails, retry with `sendMessage:`.
 */
- (void)enqueueAttachment:(id <DataSource>)dataSource
              contentType:(NSString *)contentType
           sourceFilename:(nullable NSString *)sourceFilename
                inMessage:(TSOutgoingMessage *)message
   preSendMessageCallBack:(nullable void (^)(TSOutgoingMessage *))preSendMessageCallBack
                  success:(void (^)(void))successHandler
                  failure:(void (^)(NSError *error))failureHandler;
/**
 * Same as ` enqueueAttachment:`, but deletes the local copy of the attachment after sending.
 * Used for sending sync request data, not for user visible attachments.
 */
- (void)enqueueTemporaryAttachment:(id <DataSource>)dataSource
                       contentType:(NSString *)contentType
                         inMessage:(TSOutgoingMessage *)outgoingMessage
                           success:(void (^)(void))successHandler
                           failure:(void (^)(NSError *error))failureHandler;

/// 处理不同team消息被禁止发送的情况
/// @param recipient 收件人
/// @param message 消息
/// @param thread  ***
//- (void)forbiddenRecipient:(SignalRecipient *)recipient
//                      message:(TSOutgoingMessage *)message
//                    thread:(TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
