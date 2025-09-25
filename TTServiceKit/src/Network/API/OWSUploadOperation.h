//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOperation.h"

NS_ASSUME_NONNULL_BEGIN

@class TSOutgoingMessage;
@class YapDatabaseConnection;
@class TSAttachmentStream;
@class Contact;
@class SSKAES256Key;

extern NSString *const kAttachmentUploadProgressNotification;
extern NSString *const kAttachmentUploadProgressKey;
extern NSString *const kAttachmentUploadAttachmentIDKey;


@interface OWSUploadOperation : OWSOperation

@property (nullable, readonly) NSError *lastError;
@property (readonly) NSString *location;
@property (assign, nonatomic,readonly) BOOL isPutProfileSucess;
@property(nonatomic,strong) NSString *avatarString;


@property (nonatomic, copy) void (^successHandler)(void);
@property (nonatomic, copy) void (^rapidFileInfoBlock)(NSDictionary *info);
@property (nonatomic, copy) void (^failureHandler)(NSError *_Nonnull error);

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAttachmentId:(NSString *)attachmentId
                        recipientIds:(NSArray<NSString *> * _Nullable)recipientIds NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment;

- (instancetype)initWithAttachmentId:(NSString *)attachmentId
                        recipientIds:(NSArray<NSString *> * _Nullable)recipientIds
                allowDuplicateUpload:(BOOL)allowDuplicateUpload;

//- (void)syncrun;

- (void)syncrunWithProfileName:(NSString *)profileName profileKey:(SSKAES256Key*)profileKey;

- (void)uploadDebugLogRunSuccess:(void (^)(void))uploadSuccess
                   uploadFailure:(void (^)(NSError *error))uploadFailure;

@end

NS_ASSUME_NONNULL_END
