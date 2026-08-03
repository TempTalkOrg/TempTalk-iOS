//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSUploadToOSSOperation.h"
#import "SSKCryptography.h"
#import "MIMETypeUtil.h"
#import "NSError+MessageSending.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSError.h"
#import "OWSOperation.h"
#import "OWSRequestFactory.h"
#import "TSAttachmentStream.h"
#import <SignalCoreKit/SignalCoreKit-Swift.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN


// Use a slightly non-zero value to ensure that the progress
// indicator shows up as quickly as possible.
static const CGFloat kAttachmentUploadProgressTheta = 0.001f;

@interface OWSUploadToOSSOperation ()

@property (readonly, nonatomic) NSString *attachmentId;
@property (readonly, nonatomic) TSAttachmentStream *attachment;

@property NSString *location;

@end

@implementation OWSUploadToOSSOperation

- (instancetype)initWithAttachmentId:(NSString *)attachmentId {
    self = [super init];
    if (!self) {
        return self;
    }

    self.remainingRetries = 2;
    _attachmentId = attachmentId;
    _attachment = nil;

    return self;
}

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment
{
    self = [super init];
    if (!self) {
        return self;
    }

    self.remainingRetries = 2;
    _attachment = attachment;

    return self;
}

// Retry only transient failures (transport errors, 5xx); fail fast on 4xx.
- (BOOL)shouldRetryUploadForError:(NSError *)error
{
    NSNumber *statusCode = error.httpStatusCode;
    if (statusCode != nil) {
        // Don't retry 4xx; retry everything else (5xx, etc.).
        return !(statusCode.integerValue >= 400 && statusCode.integerValue <= 499);
    }
    // No HTTP status = transport error: retry.
    return YES;
}

- (void)uploadAvatarWithServerId:(UInt64)serverId
                  location:(NSString *)location
          avatarStream:(TSAttachmentStream *)avatarStream
{
    DDLogDebug(@"%@ started uploading data for avatar: %@", self.logTag, self.attachmentId);
    NSError *error;
    NSData *attachmentData = [avatarStream readDataFromFileWithError:&error];
    if (error) {
        DDLogError(@"%@ Failed to read avatar data with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:location]];
    request.HTTPMethod = @"PUT";
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)attachmentData.length]
   forHTTPHeaderField:@"Content-Length"];

    OWSURLSession *urlSession = OWSSignalService.sharedInstance.urlSessionForNoneService;

    __weak typeof(self) weakSelf = self;
    [urlSession performUploadRequest:request
                                data:attachmentData
                             success:^(id<HTTPResponse> response) {
        NSInteger statusCode = response.responseStatusCode;
        BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
        if (!isValidResponse) {
            DDLogError(@"%@ Unexpected server response: %d", weakSelf.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            // Retry 5xx only; don't retry 4xx.
            invalidResponseError.isRetryable = (statusCode >= 500);
            [weakSelf reportError:invalidResponseError];
            return;
        }

        DDLogInfo(@"%@ Uploaded avatar: %p.", weakSelf.logTag, avatarStream.uniqueId);
        avatarStream.serverId = serverId;
        avatarStream.isUploaded = YES;
        DatabaseStorageAsyncWrite(weakSelf.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [avatarStream anyInsertWithTransaction:transaction];
            [transaction addAsyncCompletionOnMain:^{
                [weakSelf reportSuccess];
            }];
        });
    }
                            progress:^(NSURLSessionTask *task, NSProgress *progress) {
        [weakSelf fireNotificationWithProgress:progress.fractionCompleted];
    }
                             failure:^(OWSHTTPErrorWrapper *errorWrapper) {
        NSError *err = errorWrapper.asNSError;
        err.isRetryable = [weakSelf shouldRetryUploadForError:err];
        [weakSelf reportError:err];
    }];
}

- (void)syncrun
{
    __block TSAttachmentStream *attachmentStream;
    
    if(self.attachment){
        attachmentStream = self.attachment;
    }
    
    if (!attachmentStream) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotLoadAttachment]);
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        // Not finding local attachment is a terminal failure.
        error.isRetryable = NO;
        [self reportError:error];
        return;
    }
    
    if (attachmentStream.isUploaded) {
        DDLogDebug(@"%@ Attachment previously uploaded.", self.logTag);
        [self reportSuccess];
        return;
    }
    
    [self fireNotificationWithProgress:0];
    
    DDLogDebug(@"%@ alloc attachment: %@", self.logTag, self.attachmentId);
    
    // firstly, request the uploading url for the avatar from server.
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    TSRequest *request = [OWSRequestFactory profileAvatarUploadUrlRequest:nil];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            dispatch_group_leave(group);
            OWSLogError(@"unexpected response from server: %@", responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            error.isRetryable = YES;
            [self reportError:error];
            return;
        }
        
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        UInt64 serverId = ((NSDecimalNumber *)[responseDict objectForKey:@"id"]).unsignedLongLongValue;
        NSString *location = [responseDict objectForKey:@"location"];
        
        self.location = location;
        dispatch_group_leave(group);
        
        // just upload the avatar to the server.
        [self uploadAvatarWithServerId:serverId location:location avatarStream:attachmentStream];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        dispatch_group_leave(group);
        
        NSError *error = errorWrapper.asNSError;
        DDLogError(@"%@ Failed to allocate attachment with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    return;
}

- (void)run
{
    // Retries re-enter run() via runAnyQueuedRetry, bypassing main()'s cancel check,
    // so honor cancellation here to stop retrying and free the queue promptly.
    if (self.isCancelled) {
        [self reportCancelled];
        return;
    }
    __block TSAttachmentStream *attachmentStream;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
        attachmentStream = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:self.attachmentId
                                                           transaction:transaction];
    }];
    
    if(self.attachment){
        attachmentStream = self.attachment;
    }

    if (!attachmentStream) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotLoadAttachment]);
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        // Not finding local attachment is a terminal failure.
        error.isRetryable = NO;
        [self reportError:error];
        return;
    }

    if (attachmentStream.isUploaded) {
        DDLogDebug(@"%@ Attachment previously uploaded.", self.logTag);
        [self reportSuccess];
        return;
    }
    
    [self fireNotificationWithProgress:0];

    OWSLogDebug(@"%@ alloc attachment: %@", self.logTag, self.attachmentId);
    TSRequest *request = [OWSRequestFactory allocAttachmentRequest];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ unexpected response from server: %@", self.logTag, responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            error.isRetryable = YES;
            [self reportError:error];
            return;
        }
        
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        UInt64 serverId = ((NSDecimalNumber *)[responseDict objectForKey:@"id"]).unsignedLongLongValue;
        NSString *location = [responseDict objectForKey:@"location"];
        
        self.location = location;
        
        dispatch_async([OWSDispatch attachmentsQueue], ^{
            [self uploadWithServerId:serverId location:location attachmentStream:attachmentStream];
        });
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        OWSLogError(@"Failed to allocate attachment with error: %@", error);
        error.isRetryable = YES;
        [self reportError:error];
    }];
}

- (void)uploadWithServerId:(UInt64)serverId
                  location:(NSString *)location
          attachmentStream:(TSAttachmentStream *)attachmentStream
{
    DDLogDebug(@"%@ started uploading data for attachment: %@", self.logTag, self.attachmentId);
    NSError *error;
    NSData *attachmentData = [attachmentStream readDataFromFileWithError:&error];
    if (error) {
        DDLogError(@"%@ Failed to read attachment data with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }

    NSData *encryptionKey;
    NSData *digest;
    
    NSData *_Nullable encryptedAttachmentData =
        [SSKCryptography encryptAttachmentData:attachmentData eKey:nil hmacKey:nil outKey:&encryptionKey outDigest:&digest useMd5Hash:NO];
    
    if (!encryptedAttachmentData) {
        OWSFailDebug(@"%@ could not encrypt attachment data.", self.logTag);
        error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }
    attachmentStream.encryptionKey = encryptionKey;
    attachmentStream.digest = digest;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:location]];
    request.HTTPMethod = @"PUT";
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)encryptedAttachmentData.length]
   forHTTPHeaderField:@"Content-Length"];

    OWSURLSession *urlSession = OWSSignalService.sharedInstance.urlSessionForNoneService;

    __weak typeof(self) weakSelf = self;
    [urlSession performUploadRequest:request
                                data:encryptedAttachmentData
                             success:^(id<HTTPResponse> response) {
        NSInteger statusCode = response.responseStatusCode;
        BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
        if (!isValidResponse) {
            DDLogError(@"%@ Unexpected server response: %d", weakSelf.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            // Retry 5xx only; don't retry 4xx.
            invalidResponseError.isRetryable = (statusCode >= 500);
            [weakSelf reportError:invalidResponseError];
            return;
        }

        DDLogInfo(@"%@ Uploaded attachment: %p.", weakSelf.logTag, attachmentStream.uniqueId);
        attachmentStream.serverId = serverId;
        attachmentStream.isUploaded = YES;
        DatabaseStorageAsyncWrite(weakSelf.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [attachmentStream anyInsertWithTransaction:transaction];
            [transaction addAsyncCompletionOnMain:^{
                [weakSelf reportSuccess];
            }];
        });
    }
                            progress:^(NSURLSessionTask *task, NSProgress *progress) {
        [weakSelf fireNotificationWithProgress:progress.fractionCompleted];
    }
                             failure:^(OWSHTTPErrorWrapper *errorWrapper) {
        NSError *err = errorWrapper.asNSError;
        err.isRetryable = [weakSelf shouldRetryUploadForError:err];
        [weakSelf reportError:err];
    }];
}

- (void)fireNotificationWithProgress:(CGFloat)aProgress
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

    CGFloat progress = MAX(kAttachmentUploadProgressTheta, aProgress);
    [notificationCenter postNotificationNameAsync:kAttachmentUploadProgressNotification
                                           object:nil
                                         userInfo:@{
                                             kAttachmentUploadProgressKey : @(progress),
                                             kAttachmentUploadAttachmentIDKey : self.attachmentId
                                         }];
}

- (void)didSucceed
{
    if(self.successHandler){
        self.successHandler();
    }
}

- (void)didFailWithError:(NSError *)error
{
    if(self.failureHandler){
        self.failureHandler(error);
    }
}

@end

NS_ASSUME_NONNULL_END
