//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOperation.h"
#import "OWSUploadOperation.h"

NS_ASSUME_NONNULL_BEGIN

@class TSOutgoingMessage;
@class YapDatabaseConnection;
@class TSAttachmentStream;

@interface OWSUploadToOSSOperation : OWSOperation

@property (nullable, readonly) NSError *lastError;
@property (readonly) NSString *location;

@property (nonatomic, copy) void (^successHandler)(void);
@property (nonatomic, copy) void (^failureHandler)(NSError *_Nonnull error);

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithAttachmentId:(NSString *)attachmentId NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment;

- (void)syncrun;

@end

NS_ASSUME_NONNULL_END
