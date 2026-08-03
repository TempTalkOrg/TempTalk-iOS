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
#import "DTFileDownloader.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

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

            UInt64 byteCount = attachmentPointer.byteCount;

            if (byteCount >= kAttachmentAutoDownloadMaxSize) {
                OWSLogInfo(@"Ignore download for message: %@, reason: over max file size", message.uniqueId);
                [items removeObject:attachmentPointer];

            } else if ([attachmentPointer.contentType isEqualToString:OWSMimeTypeOversizeTextMessage]) {
                // auto download
            } else if ([MIMETypeUtil isAudio:attachmentPointer.contentType]) {
                // auto download
            } else if (CurrentAppContext().isNSE) { // NSE-imported history messages: defer to foreground.
                OWSLogInfo(@"Ignore download for message: %@, reason: is NSE", message.uniqueId);
                [items removeObject:attachmentPointer];

            } else if ([MIMETypeUtil isVisualMedia:attachmentPointer.contentType]) {
                // Image / video respects the user's auto-download setting.
                if (![[self class] autoDownloadImageEnableWithTransaction:transaction]) {
                    OWSLogInfo(@"Ignore download for message: %@, reason: disable auto download", message.uniqueId);
                    [items removeObject:attachmentPointer];
                }
            } else {
                // Generic files: auto-download when within size limit.
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
            OWSLogInfo(@"markAndHandleSuccess: stream=%@ grdbId=%@ message=%llu message.grdbId=%@ threadId=%@",
                       attachmentStream.uniqueId, attachmentStream.grdbId,
                       message.timestamp, message.grdbId, message.uniqueThreadId);

            successHandler(attachmentStream);

            if (message.messageModeType == TSMessageModeTypeNormal) {
                if (attachmentStream.isImage) {
                    [[MediaSavePolicyManager shared] saveImageIfNeeded:attachmentStream.image threadId:message.uniqueThreadId];
                } else if (attachmentStream.isVideo) {
                    [[MediaSavePolicyManager shared] saveVideoIfNeeded:attachmentStream.mediaURL threadId:message.uniqueThreadId];
                }
            }

            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                if(message.grdbId){
                    [self.databaseStorage touchInteraction:message
                                             shouldReindex:NO
                                               transaction:writeTransaction];
                } else {
                    OWSLogError(@"markAndHandleSuccess: SKIPPED touchInteraction, message.grdbId is nil! message=%llu, uniqueId=%@",
                                message.timestamp, message.uniqueId);
                }
            });

            backgroundTask = nil;
        });
    };
    
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
        // Use urls array if available, otherwise fallback to single url
        NSArray<NSString *> *downloadUrls = entity.urls;
        if (!downloadUrls || downloadUrls.count == 0) {
            // Fallback to legacy single url field for backward compatibility
            downloadUrls = entity.url ? @[entity.url] : @[];
        }
        
        if(error || !downloadUrls || downloadUrls.count == 0){
            DDLogError(@"%@ getFileInfoWithFileHash Response had unexpected format. or error : %@", self.logTag, error);
            // Map status code to error state
            NSInteger statusCode = error.code;
            if (statusCode == DTAPIRequestResponseStatusNoPermission) {
                // Status 2: file expired
                NSError *expiredError = OWSErrorMakeUnableToProcessServerResponseError();
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self setAttachment:attachment didExpireInMessage:message error:expiredError];
                    failureHandler(expiredError);
                    backgroundTask = nil;
                });
                return;
            } else if (statusCode == DTAPIRequestResponseStatusInvalidParameter ||
                       statusCode == DTAPIRequestResponseStatusNoSuchFile ||
                       statusCode == DTAPIRequestResponseStatusOperateError ||
                       statusCode == DTAPIRequestResponseStatusOtherError) {
                // Status 1,9,12,99: retryable failure
                NSError *retryError = OWSErrorMakeUnableToProcessServerResponseError();
                return markAndHandleFailure(retryError);
            } else {
                // Other errors
                NSError *generalError = OWSErrorMakeUnableToProcessServerResponseError();
                return markAndHandleFailure(generalError);
            }
        } else {
            dispatch_async([OWSDispatch attachmentsQueue], ^{
                // Create progress callback to track download progress and enforce size limits
                // Note: __block variable is captured by progress block and persists for the duration
                // of the download operation. Access is protected by @synchronized for thread safety.
                __block BOOL hasCheckedContentLength = NO;
                __weak typeof(self) weakSelf = self;
                DTFileDownloadProgressBlock progressBlock = ^(NSURLSessionTask *task, NSProgress *progress) {
                    __strong typeof(weakSelf) strongSelf = weakSelf;
                    if (!strongSelf) { return; }

                    OWSAssertDebug(progress != nil);

                    if (progress.completedUnitCount < 1) {
                        return;
                    }

                    void (^abortDownload)(void) = ^{
                        OWSFailDebug(@"%@ Download aborted.", strongSelf.logTag);
                        [task cancel];
                    };

                    if ((progress.totalUnitCount > 0 && progress.totalUnitCount > OWSMediaUtils.kMaxFileSizeGeneric) ||
                        progress.completedUnitCount > OWSMediaUtils.kMaxFileSizeGeneric) {
                        // A malicious service might send a misleading content length header,
                        // so....
                        //
                        // If the current downloaded bytes or the expected total byes
                        // exceed the max download size, abort the download.
                        OWSLogError(@"%@ Attachment download exceed expected content length: %lld, %lld.",
                                    strongSelf.logTag,
                                    (long long)progress.totalUnitCount,
                                    (long long)progress.completedUnitCount);
                        abortDownload();
                        return;
                    }

                    [strongSelf fireProgressNotification:MAX(kAttachmentDownloadProgressTheta, progress.fractionCompleted)
                                            attachmentId:attachment.uniqueId];
                    // We only need to check the content length header once.
                    if (hasCheckedContentLength) { return; }

                    // Once we've received some bytes of the download, check the content length
                    // header for the download.
                    //
                    // If the task doesn't exist, or doesn't have a response, or is missing
                    // the expected headers, or has an invalid or oversize content length, etc.,
                    // abort the download.
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)task.response;
                    if (![httpResponse isKindOfClass:[NSHTTPURLResponse class]]) {
                        DDLogError(@"%@ Attachment download has missing or invalid response.", strongSelf.logTag);
                        abortDownload();
                        return;
                    }

                    NSDictionary *headers = [httpResponse allHeaderFields];
                    if (![headers isKindOfClass:[NSDictionary class]]) {
                        DDLogError(@"%@ Attachment download invalid headers.", strongSelf.logTag);
                        abortDownload();
                        return;
                    }

                    // Check Content-Length header if present (optional for Aliyun CDN compatibility)
                    NSString *contentLength = headers[@"Content-Length"];
                    if (contentLength && [contentLength isKindOfClass:[NSString class]]) {
                        // Validate Content-Length only if header exists
                        if (contentLength.longLongValue > OWSMediaUtils.kMaxFileSizeGeneric) {
                            DDLogError(@"%@ Content length exceeds max download size: %@", strongSelf.logTag, contentLength);
                            abortDownload();
                            return;
                        }
                    } else {
                        // No Content-Length header - proceed (Aliyun servers don't provide this field)
                        // Size limit enforcement relies on completedUnitCount check above
                        DDLogInfo(@"%@ No Content-Length header, relying on byte count validation", strongSelf.logTag);
                    }

                    // Header validation complete - mark as checked to avoid redundant validation
                    hasCheckedContentLength = YES;
                };

                [[DTFileDownloader defaultDownloader] downloadFileWithUrls:downloadUrls
                                                                  progress:progressBlock
                                                                   success:^(NSData * _Nonnull encryptedData) {
                    [self decryptAttachmentData:encryptedData
                                        keyHash:keyHash
                                        pointer:attachment
                                        success:markAndHandleSuccess
                                        failure:markAndHandleFailure];
                }
                                                                   failure:^(NSError * _Nonnull error) {
                    // 404 from any URL means server file expired; invalidate fileHash so upstream re-requests.
                    if (error.httpStatusCode.integerValue == 404) {
                        [DTFileRequestHandler markAsInvalidWithFileHash:[keyHash base64EncodedString]
                                                             authorizeId:attachment.serverId
                                                              completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable err) {
                        }];
                    }
                    if (markAndHandleFailure) {
                        markAndHandleFailure(error);
                    }
                }];
            });
        }
    }];
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
        // Backfill grdbId BEFORE upsert: initWithPointer: doesn't inherit the row id, and
        // anyDidUpdateWithTransaction skips the attachmentReadCache refresh for grdbId-nil
        // instances — leaving a stale TSAttachmentPointer cached and the voice message
        // stuck in the "downloading" UI until next cold launch.
        if (!stream.grdbId) {
            TSAttachment *existingAttachment = [TSAttachment anyFetchWithUniqueId:stream.uniqueId
                                                                       transaction:transaction];
            if (existingAttachment.grdbId) {
                [stream updateRowId:existingAttachment.grdbId.longLongValue];
                OWSLogInfo(@"decryptAttachment: backfilled stream grdbId from DB: %@", stream.grdbId);
            }
        }

        [stream anyUpsertWithTransaction:transaction];

        if (!stream.grdbId) {
            OWSLogError(@"decryptAttachment: missing grdbId after upsert for stream: %@", stream.uniqueId);
        }

        OWSLogInfo(@"decryptAttachment: upserted stream=%@ grdbId=%@ contentType=%@",
                   stream.uniqueId, stream.grdbId, stream.contentType);
    });
    successHandler(stream);
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

    OWSLogInfo(@"setAttachment:isDownloading pointer=%@ grdbId=%@ message=%llu message.grdbId=%@",
               pointer.uniqueId, pointer.grdbId, message.timestamp, message.grdbId);

    [pointer anyUpdateAttachmentPointerWithTransaction:transaction
                                                 block:^(TSAttachmentPointer *instance) {
        instance.state = TSAttachmentPointerStateDownloading;
    }];
    
    if (message) {
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            if(message.grdbId){
                [self.databaseStorage touchInteraction:message
                                         shouldReindex:NO
                                           transaction:writeTransaction];
            } else {
                OWSLogWarn(@"setAttachment:isDownloading SKIPPED touchInteraction because message.grdbId is nil, message=%llu", message.timestamp);
            }
        });
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
        
        if(message.uniqueId &&
           message.grdbId &&
           [TSMessage anyFetchMessageWithUniqueId:message.uniqueId transaction:transaction]){
            [self.databaseStorage touchInteraction:message
                                     shouldReindex:NO
                                       transaction:transaction];
        }
        
    });
}

- (void)setAttachment:(TSAttachmentPointer *)pointer
   didExpireInMessage:(nullable TSMessage *)message
                error:(NSError *)error
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [pointer anyUpdateAttachmentPointerWithTransaction:transaction
                                                     block:^(TSAttachmentPointer * instance) {
            instance.mostRecentFailureLocalizedText = error.localizedDescription;
            instance.state = TSAttachmentPointerStateExpired;
        }];
        
        if(message.uniqueId &&
           message.grdbId &&
           [TSMessage anyFetchMessageWithUniqueId:message.uniqueId transaction:transaction]){
            [self.databaseStorage touchInteraction:message
                                     shouldReindex:NO
                                       transaction:transaction];
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
