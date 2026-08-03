//
//  DTGroupAvatarUpdateProcessor.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/29.
//

#import "DTGroupAvatarUpdateProcessor.h"
#import "TSAttachmentStream.h"
#import "TSAttachmentPointer.h"
#import "TSOutgoingMessage.h"
#import "OWSError.h"
#import "OWSUploadToOSSOperation.h"
//
#import "OWSAttachmentsProcessor.h"
#import "DTUpdateGroupInfoAPI.h"
#import "TSGroupThread.h"
#import "DTGroupNotifyEntity.h"
#import "OWSError.h"
#import "OWSDispatch.h"
#import "OWSAttachmentsProcessor.h"
#import "SSKCryptography.h"
#import "NSNotificationCenter+OWS.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTGroupAvatarUpdateProcessor ()

@property (nonatomic, strong) NSOperationQueue *uploadQueue;

@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;

@end

@implementation DTGroupAvatarUpdateProcessor

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI{
    if(!_updateGroupInfoAPI){
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}

-(instancetype)initWithGroupThread:(TSGroupThread * _Nullable)groupThread{
    if(self = [super init]){
        self.uploadQueue = [[NSOperationQueue alloc] init];
        [self.uploadQueue setMaxConcurrentOperationCount:1];
        self.groupThread = groupThread;
    }
    return self;;
}

- (instancetype)init{
    if(self = [super init]){
        self.uploadQueue = [[NSOperationQueue alloc] init];
        [self.uploadQueue setMaxConcurrentOperationCount:1];
    }
    return self;
}

- (void)uploadAttachment:(id <DataSource>)dataSource
             contentType:(NSString *)contentType
          sourceFilename:(nullable NSString *)sourceFilename
                 success:(void (^)(NSString * _Nullable))successHandler
                 failure:(void (^)(NSError *error))failureHandler {

    TSAttachmentStream *attachmentStream =
        [[TSAttachmentStream alloc] initWithContentType:contentType
                                              byteCount:(UInt64)dataSource.dataLength
                                         sourceFilename:sourceFilename
                                         albumMessageId:nil
                                                albumId:nil];

    if (![attachmentStream writeDataSource:dataSource]) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
        NSError *error = OWSErrorMakeWriteAttachmentDataError();
        return failureHandler(error);
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [attachmentStream anyInsertWithTransaction:transaction];
        });

        OWSUploadToOSSOperation *uploadAttachmentOperation =
            [[OWSUploadToOSSOperation alloc] initWithAttachmentId:attachmentStream.uniqueId];
        [uploadAttachmentOperation setSuccessHandler:^{
            __block TSAttachmentStream *attachment = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                attachment = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:attachmentStream.uniqueId transaction:transaction];
            }];
            if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
                OWSLogError(@"Unexpected type for attachment builder: %@", attachment);
                if (failureHandler) {
                    failureHandler(OWSErrorMakeWriteAttachmentDataError());
                }
                return;
            }
            if (successHandler) {
                successHandler([self buildJsonStringWithAttachmentStream:attachment]);
            }
        }];
        uploadAttachmentOperation.failureHandler = failureHandler;
        // Latest-wins: cancel any prior in-flight upload so this one isn't queued behind it.
        [self.uploadQueue cancelAllOperations];
        [self.uploadQueue addOperation:uploadAttachmentOperation];
    });
}



- (void)updateWithAttachment:(id <DataSource>)dataSource
                 contentType:(NSString *)contentType
              sourceFilename:(nullable NSString *)sourceFilename
                     success:(void (^)(DTAPIMetaEntity * _Nonnull entity))successHandler
                     failure:(void (^)(NSError *error))failureHandler{

    TSAttachmentStream *attachmentStream =
        [[TSAttachmentStream alloc] initWithContentType:contentType
                                              byteCount:(UInt64)dataSource.dataLength
                                         sourceFilename:sourceFilename
                                         albumMessageId:nil
                                                albumId:nil];

    if (![attachmentStream writeDataSource:dataSource]) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
        NSError *error = OWSErrorMakeWriteAttachmentDataError();
        return failureHandler(error);
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [attachmentStream anyInsertWithTransaction:transaction];
        });

        OWSUploadToOSSOperation *uploadAttachmentOperation =
            [[OWSUploadToOSSOperation alloc] initWithAttachmentId:attachmentStream.uniqueId];
        [uploadAttachmentOperation setSuccessHandler:^{
            __block TSAttachmentStream *attachment = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
                attachment = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:attachmentStream.uniqueId transaction:transaction];
            }];
            if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
                OWSLogError(@"Unexpected type for attachment builder: %@", attachment);
                return;
            }

            NSString *avatarJson = [self buildJsonStringWithAttachmentStream:attachment];
            NSDictionary *parameter;

            // Encrypted group: encrypt avatar JSON
            if (self.groupThread.groupModel.isEncryptedGroup) {
                DTGroupCryptoManager *cryptoManager = DTGroupCryptoManager.shared;
                __block NSString *encryptedAvatar = nil;
                [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                    encryptedAvatar = [cryptoManager encryptGroupAvatarWithGid:self.groupThread.serverThreadId
                                                                  plainAvatar:avatarJson
                                                                  transaction:transaction];
                }];
                if (encryptedAvatar) {
                    parameter = @{@"encryptedAvatar": encryptedAvatar};
                } else {
                    failureHandler([NSError errorWithDomain:@"GroupCrypto" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to encrypt group avatar"}]);
                    return;
                }
            } else {
                parameter = @{@"avatar": avatarJson};
            }

            [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:self.groupThread.serverThreadId updateInfo:parameter
                                                        success:^(DTAPIMetaEntity * _Nonnull entity) {
                successHandler(entity);

            } failure:^(NSError * _Nonnull error) {
                OWSLogError(@"update group avatar failed, gid: %@, error: %@", self.groupThread.serverThreadId, error);
                failureHandler(error);
            }];
        }];
        uploadAttachmentOperation.failureHandler = failureHandler;
        [self.uploadQueue addOperation:uploadAttachmentOperation];
    });
}

- (NSString *)buildJsonStringWithAttachmentStream:(TSAttachmentStream *)attachmentStream{
    
    NSMutableDictionary *avatarInfo = @{}.mutableCopy;
    avatarInfo[@"serverId"] = [NSString stringWithFormat:@"%llu",attachmentStream.serverId];
    if(attachmentStream.encryptionKey.length){
        avatarInfo[@"encryptionKey"] = [attachmentStream.encryptionKey base64EncodedString];
    }
    if(attachmentStream.digest.length){
        avatarInfo[@"digest"] = [attachmentStream.digest base64EncodedString];
    }
    avatarInfo[@"byteCount"] = [NSString stringWithFormat:@"%llu", attachmentStream.byteCount];
    avatarInfo[@"contentType"] = attachmentStream.contentType;
    avatarInfo[@"sourceFilename"] = attachmentStream.sourceFilename;
    avatarInfo[@"attachmentType"] = @(attachmentStream.attachmentType);
    
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:avatarInfo.copy options:NSJSONWritingPrettyPrinted error:&jsonError];
    if(!jsonData.length || jsonError){
        DDLogError(@"buildJson data error0");
        return @"";
    }
    
    NSString *dataString = [jsonData base64EncodedString];
    
    if(!DTParamsUtils.validateString(dataString)) return nil;
    
    NSData *resultData = [NSJSONSerialization dataWithJSONObject:@{@"data":dataString} options:NSJSONWritingPrettyPrinted error:&jsonError];
    if(!resultData.length || jsonError){
        DDLogError(@"buildJson data error1");
        return @"";
    }
    dataString = [[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding];
    
    
    return dataString;
    
}

- (TSAttachmentPointer *)buildAttachmentStreamWithJsonString:(NSString *)jsonString{
    
    if(!DTParamsUtils.validateString(jsonString)) return nil;
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *info = nil;
    NSError *jsonError;
    if(jsonData){
        info = [NSJSONSerialization JSONObjectWithData:jsonData
                                               options:NSJSONReadingMutableContainers
                                                 error:&jsonError];
    }
    
    if(jsonError) return nil;
    
    NSString *dataString = info[@"data"];
    if(!DTParamsUtils.validateString(dataString)) return nil;
    
    jsonData = [NSData dataFromBase64String:dataString];
    if(!jsonData.length) return nil;
    info = [NSJSONSerialization JSONObjectWithData:jsonData
                                           options:NSJSONReadingMutableContainers
                                             error:&jsonError];
    if(jsonError) return nil;
    
    
    if(!DTParamsUtils.validateString(info[@"encryptionKey"]) ||
       !DTParamsUtils.validateString(info[@"digest"])){
        return nil;
    }

    TSAttachmentPointer * pointer = [[TSAttachmentPointer alloc] initWithServerId:[info[@"serverId"] longLongValue]
                                                                              key:[NSData dataFromBase64String:info[@"encryptionKey"]]
                                                                           digest:[NSData dataFromBase64String:info[@"digest"]]
                                                                        byteCount:[info[@"byteCount"] intValue]
                                                                      contentType:info[@"contentType"]
                                                                            relay:@""
                                                                   sourceFilename:info[@"sourceFilename"]
                                                                   attachmentType:[info[@"attachmentType"] intValue]
                                                                   albumMessageId:nil
                                                                          albumId:nil];
    return pointer;
    
}

- (void)handleReceivedGroupAvatarUpdateWithAvatarUpdate:(NSString *)avatar
                                                success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                                                failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(avatar);
//    OWSAssertDebug(self.groupThread);
    
    
    TSAttachmentPointer *pointer = [self buildAttachmentStreamWithJsonString:avatar];
    if(!pointer){
        DDLogInfo(@"update avatar data error");
        OWSProdError(@"update avatar data error");
        if(failureHandler){
            failureHandler([NSError errorWithDomain:@"GroupAvatarError" code:1001 userInfo:nil]);
        }
        return;
    }
    
    TSRequest *request =
        [OWSRequestFactory attachmentRequestWithAttachmentId:pointer.serverId relay:@""];

    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            DDLogError(@"%@ Failed retrieval of attachment. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            failureHandler(error);
            return;
        }
        NSString *location = [(NSDictionary *)responseObject objectForKey:@"location"];
        if (!location) {
            DDLogError(@"%@ Failed retrieval of attachment. Response had no location.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            failureHandler(error);
            return;
        }
        
        dispatch_async([OWSDispatch attachmentsQueue], ^{
            [self downloadFromLocation:location
                               pointer:pointer
                               success:^(NSData *_Nonnull encryptedData) {
                [self decryptAttachmentData:encryptedData
                                    pointer:pointer
                                    success:successHandler
                                    failure:failureHandler];
            }
                               failure:^(NSError *_Nonnull error) {
                if (pointer.serverId < 100) {
                    // This looks like the symptom of the "frequent 404
                    // downloading attachments with low server ids".
                    NSNumber *statusCode = error.httpStatusCode;
                    OWSFailDebug(@"%@ %@ Failure with suspicious attachment id: %llu, %@",
                                 self.logTag,
                                 statusCode,
                                 (unsigned long long)pointer.serverId,
                                 error);
                }
                failureHandler(error);
            }];
        });
    } failure:^(OWSHTTPErrorWrapper * _Nonnull wrapperError) {
        NSError *error = wrapperError.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
        }
        DDLogError(@"Failed retrieval of attachment with error: %@", error);
        
        
        if (pointer.serverId < 100) {
            // This _shouldn't_ be the symptom of the "frequent 404
            // downloading attachments with low server ids".
            NSNumber *statusCode = error.httpStatusCode;
            OWSFailDebug(@"%@ %@ Failure with suspicious attachment id: %llu, %@",
                         self.logTag,
                         statusCode,
                         (unsigned long long)pointer.serverId,
                         error);
        }
        failureHandler(error);
    }];
}

- (void)downloadFromLocation:(NSString *)location
                     pointer:(TSAttachmentPointer *)pointer
                     success:(void (^)(NSData *encryptedData))successHandler
                     failure:(void (^)(NSError *_Nonnull error))failureHandler
{
    NSURL *url = [NSURL URLWithString:location];
    TSRequest *request = [TSRequest requestWithUrl:url method:@"GET" parameters:nil];
    // We want to avoid large downloads from a compromised or buggy service.
    const long kMaxDownloadSize = 150 * 1024 * 1024;
    // TODO stream this download rather than storing the entire blob.
    __block BOOL hasCheckedContentLength = NO;

    [OWSSignalService.sharedInstance.urlSessionForNoneService performDownloadRequest:request completeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) success:^(OWSUrlDownloadResponse * _Nonnull response) {

        NSData *responseData = [NSData dataWithContentsOfURL:response.downloadUrl];
        if (![responseData isKindOfClass:[NSData class]]) {
            OWSLogError(@"%@ Failed retrieval of attachment. Response had unexpected format.", self.logTag);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        successHandler(responseData);
    } progress:^(NSURLSessionTask * _Nonnull task, NSProgress * _Nonnull progress) {

        // Don't do anything until we've received at least one byte of data.
        if (progress.completedUnitCount < 1) {
            return;
        }

        void (^abortDownload)(void) = ^{
            OWSFailDebug(@"%@ Download aborted.", self.logTag);
            [task cancel];
        };

        if ((progress.totalUnitCount > 0 && (progress.totalUnitCount > kMaxDownloadSize)) ||
            progress.completedUnitCount > kMaxDownloadSize) {
            OWSLogError(@"%@ Attachment download exceed expected content length: %lld, %lld.",
                self.logTag,
                (long long)progress.totalUnitCount,
                (long long)progress.completedUnitCount);
            abortDownload();
            return;
        }

        [self fireProgressNotification:MAX(0.001f, progress.fractionCompleted)
                          attachmentId:pointer.uniqueId];

        // We only need to check the content length header once.
        if (hasCheckedContentLength) {
            return;
        }

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
        if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
            OWSLogError(@"%@ Attachment download has missing or invalid response.", self.logTag);
            abortDownload();
            return;
        }

        NSDictionary *headers = [httpResponse allHeaderFields];
        if (![headers isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ Attachment download invalid headers.", self.logTag);
            abortDownload();
            return;
        }

        // Aliyun OSS may omit Content-Length; rely on completedUnitCount for size limit.
        NSString *contentLength = headers[@"Content-Length"];
        if ([contentLength isKindOfClass:[NSString class]] &&
            contentLength.longLongValue > kMaxDownloadSize) {
            OWSLogError(@"%@ Attachment download content length exceeds max download size: %@", self.logTag, contentLength);
            abortDownload();
            return;
        }

        hasCheckedContentLength = YES;
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        OWSLogError(@"Failed to retrieve attachment with error: %@", error.description);
        return failureHandler(error.asNSError);
    }];
}

- (void)fireProgressNotification:(CGFloat)progress attachmentId:(NSString *)attachmentId
{
    if(!DTParamsUtils.validateString(attachmentId)){
        return;
    }
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter postNotificationNameAsync:kAttachmentDownloadProgressNotification
                                           object:nil
                                         userInfo:@{
                                             kAttachmentDownloadProgressKey : @(progress),
                                             kAttachmentDownloadAttachmentIDKey : attachmentId
                                         }];
}

- (void)decryptAttachmentData:(NSData *)cipherText
                      pointer:(TSAttachmentPointer *)attachment
                      success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                      failure:(void (^)(NSError *error))failureHandler
{
    NSError *decryptError;
    NSData *_Nullable plaintext = [SSKCryptography decryptAttachment:cipherText
                                                          withKey:attachment.encryptionKey
                                                           digest:attachment.digest
                                                       useMd5Hash:NO
                                                     unpaddedSize:attachment.byteCount
                                                            error:&decryptError];

    if (decryptError) {
        DDLogError(@"%@ failed to decrypt with error: %@", self.logTag, decryptError);
        failureHandler(decryptError);
        return;
    }

    if (!plaintext) {
        NSError *error = OWSErrorWithCodeDescription(OWSErrorCodeFailedToDecryptMessage, Localized(@"ERROR_MESSAGE_INVALID_MESSAGE", @""));
        failureHandler(error);
        return;
    }

    TSAttachmentStream *stream = [[TSAttachmentStream alloc] initWithPointer:attachment albumMessageId:nil albumId:nil];

    NSError *writeError;
    [stream writeData:plaintext error:&writeError];
    if (writeError) {
        DDLogError(@"%@ Failed writing attachment stream with error: %@", self.logTag, writeError);
        failureHandler(writeError);
        return;
    }

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [stream anyUpsertWithTransaction:transaction];
    });
    successHandler(stream);
}

@end
