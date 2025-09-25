//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kAttachmentDownloadProgressNotification;
extern NSString *const kAttachmentDownloadProgressKey;
extern NSString *const kAttachmentDownloadAttachmentIDKey;

@class OWSPrimaryStorage;
@class DSKProtoAttachmentPointer;
@class TSAttachmentPointer;
@class TSAttachmentStream;
@class TSMessage;
@class TSThread;
@class SDSAnyWriteTransaction;

/**
 * Given incoming attachment protos, determines which we support.
 * It can download those that we support and notifies threads when it receives unsupported attachments.
 */
@interface OWSAttachmentsProcessor : NSObject

@property (nonatomic, readonly) NSArray<NSString *> *attachmentIds;
@property (nonatomic, readonly) NSArray<TSAttachmentPointer *> *attachmentPointers;
@property (nonatomic, readonly) BOOL hasSupportedAttachments;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAttachmentPointers:(NSArray<TSAttachmentPointer *> *)attachmentPointers
                             transaction:(SDSAnyWriteTransaction *)transaction NS_DESIGNATED_INITIALIZER;

/*
 * Retry fetching failed attachment download
 */
- (instancetype)initWithAttachmentPointer:(TSAttachmentPointer *)attachmentPointer NS_DESIGNATED_INITIALIZER;


/// 下载消息中的附件
/// - Parameters:
///   - message: owner message
///   - forceDownload: 强制下载
///   - successHandler: 成功回调
///   - failureHandler: 失败回调
- (void)fetchAttachmentsForMessage:(nullable TSMessage *)message
                     forceDownload:(BOOL)forceDownload
                           success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                           failure:(void (^)(NSError *error))failureHandler;

- (void)fetchAttachmentsForMessage:(nullable TSMessage *)message
                     forceDownload:(BOOL)forceDownload
                       transaction:(SDSAnyWriteTransaction *)transaction
                           success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                           failure:(void (^)(NSError *error))failureHandler;

+ (BOOL)autoDownloadImageEnable;
+ (void)changeAutoDownloadImageValue:(BOOL)newValue;
+ (void)decryptVoiceAttachment:(TSAttachmentStream *)attachment;

@end

NS_ASSUME_NONNULL_END
