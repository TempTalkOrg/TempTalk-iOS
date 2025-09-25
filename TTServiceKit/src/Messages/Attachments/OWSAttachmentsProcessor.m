//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAttachmentsProcessor.h"
#import "AppContext.h"
#import "SSKCryptography.h"
#import "MIMETypeUtil.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSBackgroundTask.h"
#import "OWSError.h"
#import "OWSRequestFactory.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSGroupThread.h"
#import "TSInfoMessage.h"
#import "TSMessage.h"
#import "TSThread.h"
#import "DTFileRequestHandler.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTPinnedMessage.h"
#import <AFNetworking/AFHTTPSessionManager.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kAttachmentDownloadProgressNotification = @"kAttachmentDownloadProgressNotification";
NSString *const kAttachmentDownloadProgressKey = @"kAttachmentDownloadProgressKey";
NSString *const kAttachmentDownloadAttachmentIDKey = @"kAttachmentDownloadAttachmentIDKey";

NSString *const kAttachmentDownloadCollection = @"kAttachmentDownloadCollection";
NSString *const kAttachmentAutoDownloadKey = @"kAttachmentAutoDownloadKey";

// Use a slightly non-zero value to ensure that the progress
// indicator shows up as quickly as possible.
static const CGFloat kAttachmentDownloadProgressTheta = 0.001f;

@interface OWSAttachmentsProcessor ()

@end

@implementation OWSAttachmentsProcessor

- (instancetype)initWithAttachmentPointer:(TSAttachmentPointer *)attachmentPointer
{
    self = [super init];
    if (!self) {
        return self;
    }

    _attachmentPointers = @[ attachmentPointer ];
    _attachmentIds = @[ attachmentPointer.uniqueId ];

    return self;
}

- (instancetype)initWithAttachmentPointers:(NSArray<TSAttachmentPointer *> *)attachmentPointers
                             transaction:(SDSAnyWriteTransaction *)transaction
{
    self = [super init];
    if (!self) {
        return self;
    }

    NSMutableArray<NSString *> *attachmentIds = [NSMutableArray new];

    for (TSAttachmentPointer *pointer in attachmentPointers) {
        [attachmentIds addObject:pointer.uniqueId];
        [pointer anyUpsertWithTransaction:transaction];
    }

    _attachmentIds = [attachmentIds copy];
    _attachmentPointers = [attachmentPointers copy];

    return self;
}

// PERF: Remove this and use a pre-existing dbConnection
- (void)fetchAttachmentsForMessage:(nullable TSMessage *)message
                     forceDownload:(BOOL)forceDownload
                           success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                           failure:(void (^)(NSError *error))failureHandler
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self fetchAttachmentsForMessage:message
                           forceDownload:forceDownload
                             transaction:transaction
                                 success:successHandler
                                 failure:failureHandler];
    });
}

- (void)fetchAttachmentsForMessage:(nullable TSMessage *)message
                     forceDownload:(BOOL)forceDownload
                       transaction:(SDSAnyWriteTransaction *)transaction
                           success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                           failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(transaction);
    
    NSMutableArray *items = self.attachmentPointers.mutableCopy;
    
    if(!forceDownload){
        for (TSAttachmentPointer *attachmentPointer in items) {
            UInt32 byteCount = attachmentPointer.byteCount;
            
            if (byteCount >= kAttachmentAutoDownloadMaxSize) {
                OWSLogInfo(@"Ignore download for message: %@, reason: over max file size", message.uniqueId);
                [items removeObject:attachmentPointer];
                
            } else if ([MIMETypeUtil isAudio:attachmentPointer.contentType]) {
                // auto download
            } else if (CurrentAppContext().isNSE) { // 如果是 NSE 入库的消息，不自动下载, 历史消息
                OWSLogInfo(@"Ignore download for message: %@, reason: is NSE", message.uniqueId);
                [items removeObject:attachmentPointer];
                
            } else if (![[self class] autoDownloadImageEnableWithTransaction:transaction]) {
                OWSLogInfo(@"Ignore download for message: %@, reason: disable auto download", message.uniqueId);
                [items removeObject:attachmentPointer];
                
            } else if (![MIMETypeUtil isVisualMedia:attachmentPointer.contentType]) {
                OWSLogInfo(@"Ignore download for message: %@, reason: invalid media type", message.uniqueId);
                [items removeObject:attachmentPointer];
                
            } else {
                // auto download
            }
        }
    }
    
    for (TSAttachmentPointer *attachmentPointer in items.copy) {
        [self retrieveAttachment:attachmentPointer
                         message:message
                     transaction:transaction
                         success:successHandler failure:failureHandler];
    }
}

- (void)retrieveAttachment:(TSAttachmentPointer *)attachment
                   message:(nullable TSMessage *)message
               transaction:(SDSAnyWriteTransaction *)transaction
                   success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                   failure:(void (^)(NSError *error))failureHandler
{
    OWSAssertDebug(transaction);

    __block OWSBackgroundTask *backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

    [self setAttachment:attachment isDownloadingInMessage:message transaction:transaction];

    void (^markAndHandleFailure)(NSError *) = ^(NSError *error) {
        // Ensure enclosing transaction is complete.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self setAttachment:attachment didFailInMessage:message error:error];
            failureHandler(error);

            backgroundTask = nil;
            
            OWSLogInfo(@"Download attachment failed for message: %@, error: %@", message.uniqueId, error.localizedDescription);
        });
    };

    void (^markAndHandleSuccess)(TSAttachmentStream *attachmentStream) = ^(TSAttachmentStream *attachmentStream) {
        // Ensure enclosing transaction is complete.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            /// 成功的回调
            successHandler(attachmentStream);
            /// 自动保存图片
            if (message.messageModeType == TSMessageModeTypeNormal) {
                // 机密消息不仅行自动保存
                if (attachmentStream.isImage) {
                    // 如果是图片
                    [[MediaSavePolicyManager shared] saveImageIfNeeded:attachmentStream.image];
                } else if (attachmentStream.isVideo) {
                    // 如果是视频
                    [[MediaSavePolicyManager shared] saveVideoIfNeeded:attachmentStream.mediaURL];
                }
            }

            if (message.isPinnedMessage) {
                [[NSNotificationCenter defaultCenter] postNotificationNameAsync:AnyPinnedMessageFinder.touchPinnedMessageNotification object:nil];
            } else {
                
                DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
//                    [message anyReloadWithTransaction:writeTransaction];
                    if(message.grdbId){
                        [self.databaseStorage touchInteraction:message
                                                 shouldReindex:NO
                                                   transaction:writeTransaction];
                    }
                });
            
            }

            backgroundTask = nil;
        });
    };

//    if (attachment.serverId < 100) {
//        DDLogError(@"%@ Suspicious attachment id: %llu", self.logTag, (unsigned long long)attachment.serverId);
//    }
    
    NSString *gid = nil;
    if (message.isPinnedMessage) {
        TSGroupThread *groupThread = (TSGroupThread *)message.threadWithSneakyTransaction;
        gid = [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
    }
    
    NSData *keyHash = [SSKCryptography computeSHA256Digest:attachment.encryptionKey];
    
    [DTFileRequestHandler getFileInfoWithFileHash:[keyHash base64EncodedString]
                                      authorizeId:attachment.serverId
                                              gid:gid
                                       completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        if(error || !DTParamsUtils.validateString(entity.url)){
            DDLogError(@"%@ getFileInfoWithFileHash Response had unexpected format. or error : %@", self.logTag, error);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return markAndHandleFailure(error);
        }else{
            dispatch_async([OWSDispatch attachmentsQueue], ^{
                [self downloadFromLocation:entity.url
                    pointer:attachment
                    success:^(NSData *_Nonnull encryptedData) {
                    [self decryptAttachmentData:encryptedData
                                        keyHash:(NSData *)keyHash
                                        pointer:attachment
                                        success:markAndHandleSuccess
                                        failure:markAndHandleFailure];
                    }
                    failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
//                        if (attachment.serverId < 100) {
//                            // This looks like the symptom of the "frequent 404
//                            // downloading attachments with low server ids".
//                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
//                            NSInteger statusCode = [httpResponse statusCode];
//                            OWSFailDebug(@"%@ %d Failure with suspicious attachment id: %llu, %@",
//                                self.logTag,
//                                (int)statusCode,
//                                (unsigned long long)attachment.serverId,
//                                error);
//                        }
                        if([task.response respondsToSelector:@selector(statusCode)] && ((NSHTTPURLResponse *)task.response).statusCode == 404){
                            
                            [DTFileRequestHandler markAsInvalidWithFileHash:[keyHash base64EncodedString]
                                                                authorizeId:attachment.serverId
                                                                 completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
                            }];
                        }
                        if (markAndHandleFailure) {
                            markAndHandleFailure(error);
                        }
                    }];
            });
        }
    }];
    
    /*
    
    TSRequest *request =
        [OWSRequestFactory attachmentRequestWithAttachmentId:attachment.serverId relay:attachment.relay];

    [self.networkManager makeRequest:request
        success:^(NSURLSessionDataTask *task, id responseObject) {
            if (![responseObject isKindOfClass:[NSDictionary class]]) {
                DDLogError(@"%@ Failed retrieval of attachment. Response had unexpected format.", self.logTag);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return markAndHandleFailure(error);
            }
            NSString *location = [(NSDictionary *)responseObject objectForKey:@"location"];
            if (!location) {
                DDLogError(@"%@ Failed retrieval of attachment. Response had no location.", self.logTag);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return markAndHandleFailure(error);
            }

            dispatch_async([OWSDispatch attachmentsQueue], ^{
                [self downloadFromLocation:location
                    pointer:attachment
                    success:^(NSData *_Nonnull encryptedData) {
                        [self decryptAttachmentData:encryptedData
                                            pointer:attachment
                                            success:markAndHandleSuccess
                                            failure:markAndHandleFailure];
                    }
                    failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
                        if (attachment.serverId < 100) {
                            // This looks like the symptom of the "frequent 404
                            // downloading attachments with low server ids".
                            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
                            NSInteger statusCode = [httpResponse statusCode];
                            OWSFailDebug(@"%@ %d Failure with suspicious attachment id: %llu, %@",
                                self.logTag,
                                (int)statusCode,
                                (unsigned long long)attachment.serverId,
                                error);
                        }
                        if (markAndHandleFailure) {
                            markAndHandleFailure(error);
                        }
                    }];
            });
        }
        failure:^(NSURLSessionDataTask *task, NSError *error) {
            if (!error.isNetworkConnectivityFailure) {
                OWSProdError([OWSAnalyticsEvents errorAttachmentRequestFailed]);
            }
            DDLogError(@"Failed retrieval of attachment with error: %@", error);
            if (attachment.serverId < 100) {
                // This _shouldn't_ be the symptom of the "frequent 404
                // downloading attachments with low server ids".
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
                NSInteger statusCode = [httpResponse statusCode];
                OWSFailDebug(@"%@ %d Failure with suspicious attachment id: %llu, %@",
                    self.logTag,
                    (int)statusCode,
                    (unsigned long long)attachment.serverId,
                    error);
            }
            return markAndHandleFailure(error);
        }];
     */
}

+ (void)decryptVoiceAttachment:(TSAttachmentStream *)attachment
{
    
    if (!attachment.isVoiceMessage) {
        DDLogInfo(@"%@ is not a voice message.", self.logTag);
        return;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:attachment.filePath]) {
        DDLogInfo(@"%@ plaintext voice message exists.", self.logTag);
        return;
    }
    
    NSError *error;
    NSData *encryptedData = [attachment readEncryptedDataFromFileWithError:&error];
    if (error) {
        OWSLogError(@"%@ Failed to read voice attachment data with error: %@", self.logTag, error);
        return;
    }
    
    NSError *decryptError;
    NSData *_Nullable plaintext = [SSKCryptography decryptAttachment:encryptedData
                                                             withKey:attachment.encryptionKey
                                                           digest:attachment.digest
                                                       useMd5Hash:YES
                                                     unpaddedSize:attachment.byteCount
                                                            error:&decryptError];
    NSError *writeError;
    [attachment writeData:plaintext error:&writeError];
    if (writeError) {
        DDLogError(@"%@ Failed writing voice attachment with error: %@", self.logTag, writeError);
    }
}


- (void)decryptAttachmentData:(NSData *)cipherText
                      keyHash:(NSData *)keyHash
                      pointer:(TSAttachmentPointer *)attachment
                      success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                      failure:(void (^)(NSError *error))failureHandler
{
    
    NSError *decryptError;
    NSData *_Nullable plaintext = [SSKCryptography decryptAttachment:cipherText
                                                          withKey:attachment.encryptionKey
                                                           digest:attachment.digest
                                                       useMd5Hash:YES
                                                     unpaddedSize:attachment.byteCount
                                                            error:&decryptError];

    if (decryptError) {
        DDLogError(@"%@ failed to decrypt with error: %@", self.logTag, decryptError);
        failureHandler(decryptError);
        [DTFileRequestHandler markAsInvalidWithFileHash:[keyHash base64EncodedString]
                                            authorizeId:attachment.serverId
                                             completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        }];
        return;
    }

    if (!plaintext) {
        NSError *error = OWSErrorWithCodeDescription(OWSErrorCodeFailedToDecryptMessage, Localized(@"ERROR_MESSAGE_INVALID_MESSAGE", @""));
        failureHandler(error);
        [DTFileRequestHandler markAsInvalidWithFileHash:[keyHash base64EncodedString]
                                            authorizeId:attachment.serverId
                                             completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        }];
        return;
    }
    
    NSData *originKey = [SSKCryptography computeSHA512Digest:plaintext];
    if(![originKey isEqualToData:attachment.encryptionKey]){
        NSError *error = OWSErrorWithCodeDescription(OWSErrorCodeFailedToDecryptMessage, Localized(@"ERROR_MESSAGE_INVALID_MESSAGE", @""));
        failureHandler(error);
        [DTFileRequestHandler markAsInvalidWithFileHash:[keyHash base64EncodedString]
                                            authorizeId:attachment.serverId
                                             completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        }];
        return;
    }

    TSAttachmentStream *stream = [[TSAttachmentStream alloc] initWithPointer:attachment albumMessageId:attachment.albumMessageId albumId:attachment.albumId];

    NSError *writeError;
    [stream writeData:plaintext error:&writeError];
    if (writeError) {
        DDLogError(@"%@ Failed writing attachment stream with error: %@", self.logTag, writeError);
        failureHandler(writeError);
        return;
    }
    
    if (attachment.isVoiceMessage) {
        [stream writeEncryptedData:cipherText error:&writeError];
        if (writeError) {
            DDLogError(@"%@ Failed writing voice stream with error: %@", self.logTag, writeError);
            failureHandler(writeError);
            return;
        }
        
        NSError *error;
        AudioWaveform *waveform = [AudioWaveformManagerImpl.shared audioWaveformSyncForAudioPath:[stream filePath] error:&error];
        OWSLogInfo(@"get attachmentStream file path: %@", [stream filePath]);
        OWSLogInfo(@"get attachmentStream file byteCount: %d", [stream byteCount]);
        if (error) {
            OWSLogError(@"voice draw error:%@.", error);
            failureHandler(error);
            return;
        }
        stream.decibelSamples = waveform.decibelSamples;
        stream.cachedAudioDurationSeconds = @([AudioWaveformManagerImpl.shared audioDurationFrom:stream.filePath]);
        [stream removeVoicePlaintextFile];
    }
    

    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [stream anyUpsertWithTransaction:transaction];
    });
    successHandler(stream);
}

- (void)downloadFromLocation:(NSString *)location
                     pointer:(TSAttachmentPointer *)pointer
                     success:(void (^)(NSData *encryptedData))successHandler
                     failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error))failureHandler
{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer     = [AFHTTPRequestSerializer serializer];

    // modified: remove header "Content-Type", because some oss storage do not support this header
    //           and add new header: "Accept: */*"
    //[manager.requestSerializer setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    manager.completionQueue    = dispatch_get_main_queue();

    // TODO stream this download rather than storing the entire blob.
    __block NSURLSessionDataTask *task = nil;
    __block BOOL hasCheckedContentLength = NO;
    task = [manager GET:location
             parameters:nil
                headers:nil
               progress:^(NSProgress *_Nonnull progress) {
            OWSAssertDebug(progress != nil);
            
            // Don't do anything until we've received at least one byte of data.
            if (progress.completedUnitCount < 1) {
                return;
            }

            void (^abortDownload)(void) = ^{
                OWSFailDebug(@"%@ Download aborted.", self.logTag);
                [task cancel];
            };

            if (progress.totalUnitCount > OWSMediaUtils.kMaxFileSizeGeneric || progress.completedUnitCount > OWSMediaUtils.kMaxFileSizeGeneric) {
                // A malicious service might send a misleading content length header,
                // so....
                //
                // If the current downloaded bytes or the expected total byes
                // exceed the max download size, abort the download.
                DDLogError(@"%@ Attachment download exceed expected content length: %lld, %lld.",
                    self.logTag,
                    (long long)progress.totalUnitCount,
                    (long long)progress.completedUnitCount);
                abortDownload();
                return;
            }

            [self fireProgressNotification:MAX(kAttachmentDownloadProgressTheta, progress.fractionCompleted)
                              attachmentId:pointer.uniqueId];

            // We only need to check the content length header once.
            if (hasCheckedContentLength) {
                return;
            }
            
            // Once we've received some bytes of the download, check the content length
            // header for the download.
            //
            // If the task doesn't exist, or doesn't have a response, or is missing
            // the expected headers, or has an invalid or oversize content length, etc.,
            // abort the download.
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
            if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                DDLogError(@"%@ Attachment download has missing or invalid response.", self.logTag);
                abortDownload();
                return;
            }
            
            NSDictionary *headers = [httpResponse allHeaderFields];
            if (![headers isKindOfClass:[NSDictionary class]]) {
                DDLogError(@"%@ Attachment download invalid headers.", self.logTag);
                abortDownload();
                return;
            }
            
            
            NSString *contentLength = headers[@"Content-Length"];
            if (![contentLength isKindOfClass:[NSString class]]) {
                DDLogError(@"%@ Attachment download missing or invalid content length.", self.logTag);
                abortDownload();
                return;
            }
            
            
            if (contentLength.longLongValue > OWSMediaUtils.kMaxFileSizeGeneric) {
                DDLogError(@"%@ Attachment download content length exceeds max download size.", self.logTag);
                abortDownload();
                return;
            }
            
            // This response has a valid content length that is less
            // than our max download size.  Proceed with the download.
            hasCheckedContentLength = YES;
        }
        success:^(NSURLSessionDataTask *_Nonnull task, id _Nullable responseObject) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (![responseObject isKindOfClass:[NSData class]]) {
                    DDLogError(@"%@ Failed retrieval of attachment. Response had unexpected format.", self.logTag);
                    NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                    return failureHandler(task, error);
                }
                successHandler((NSData *)responseObject);
            });
        }
        failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                DDLogError(@"Failed to retrieve attachment with error: %@", error.description);
                return failureHandler(task, error);
            });
        }];
}

- (void)fireProgressNotification:(CGFloat)progress attachmentId:(NSString *)attachmentId
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter postNotificationNameAsync:kAttachmentDownloadProgressNotification
                                           object:nil
                                         userInfo:@{
                                             kAttachmentDownloadProgressKey : @(progress),
                                             kAttachmentDownloadAttachmentIDKey : attachmentId
                                         }];
}

- (void)setAttachment:(TSAttachmentPointer *)pointer
    isDownloadingInMessage:(nullable TSMessage *)message
               transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(transaction);

    pointer.state = TSAttachmentPointerStateDownloading;
    [pointer anyInsertWithTransaction:transaction];
    
    if (message) {
        if (message.isPinnedMessage) {
            [[NSNotificationCenter defaultCenter] postNotificationNameAsync:AnyPinnedMessageFinder.touchPinnedMessageNotification object:nil];
        } else {
            
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                if(message.grdbId){
                    [self.databaseStorage touchInteraction:message
                                             shouldReindex:NO
                                               transaction:writeTransaction];
                }
            });
        }
    }
     
}

- (void)setAttachment:(TSAttachmentPointer *)pointer
     didFailInMessage:(nullable TSMessage *)message
                error:(NSError *)error
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [pointer anyUpdateAttachmentPointerWithTransaction:transaction
                                                     block:^(TSAttachmentPointer * instance) {
            instance.mostRecentFailureLocalizedText = error.localizedDescription;
            instance.state = TSAttachmentPointerStateFailed;
        }];
        
        if (message.isPinnedMessage) {
            [[NSNotificationCenter defaultCenter] postNotificationNameAsync:AnyPinnedMessageFinder.touchPinnedMessageNotification object:nil];
        } else {
            if(message.uniqueId &&
               message.grdbId &&
               [TSMessage anyFetchMessageWithUniqueId:message.uniqueId transaction:transaction]){
                [self.databaseStorage touchInteraction:message
                                         shouldReindex:NO
                                           transaction:transaction];
            }
        }
        
    });
}

- (BOOL)hasSupportedAttachments
{
    return self.attachmentPointers.count > 0;
}

#pragma mark - auto download image

+ (SDSKeyValueStore *)keyValueStore
{
    return [[SDSKeyValueStore alloc] initWithCollection:kAttachmentDownloadCollection];
}

+ (BOOL)autoDownloadImageEnable
{
    __block BOOL enable = YES;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        enable = [self autoDownloadImageEnableWithTransaction:transaction];
    }];
    return enable;
}

+ (BOOL)autoDownloadImageEnableWithTransaction:(SDSAnyReadTransaction *)transaction
{
    BOOL enable  = [self.keyValueStore getBool:kAttachmentAutoDownloadKey defaultValue:YES transaction:transaction];
    return enable;
}

+ (void)changeAutoDownloadImageValue:(BOOL)newValue
{
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.keyValueStore setBool:newValue key:kAttachmentAutoDownloadKey transaction:transaction];
    });
}


@end

NS_ASSUME_NONNULL_END
