//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSUploadOperation.h"
#import "SSKCryptography.h"
#import "MIMETypeUtil.h"
#import "NSError+MessageSending.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSError.h"
#import "OWSOperation.h"
#import "OWSRequestFactory.h"
#import "TSAttachmentStream.h"
#import "TSAccountManager.h"
#import "Contact.h"
#import "NSObject+SignalYYModel.h"
#import "DTFileRequestHandler.h"
#import <SignalCoreKit/SignalCoreKit-Swift.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "OWSAttachmentsProcessor.h"

@class Environment;

NS_ASSUME_NONNULL_BEGIN

NSString *const kAttachmentUploadProgressNotification = @"kAttachmentUploadProgressNotification";
NSString *const kAttachmentUploadProgressKey = @"kAttachmentUploadProgressKey";
NSString *const kAttachmentUploadAttachmentIDKey = @"kAttachmentUploadAttachmentIDKey";


// Use a slightly non-zero value to ensure that the progress
// indicator shows up as quickly as possible.
static const CGFloat kAttachmentUploadProgressTheta = 0.001f;

@interface OWSUploadOperation ()

@property (readonly, nonatomic) NSString *attachmentId;
@property (readonly, nonatomic) NSArray<NSString *> *recipientIds;
@property (readonly, nonatomic) TSAttachmentStream *attachment;
@property NSString *location;
@property (assign, nonatomic) UInt64 serverId;

@property(nonatomic,strong) NSDictionary *allContactsMap;
@property(nonatomic,strong) SSKAES256Key *profileKey;

@property (assign, nonatomic) NSUInteger reportRetryCount;

@property (assign, nonatomic,readwrite) BOOL isPutProfileSucess;
@property(nonatomic,strong) dispatch_group_t group;

@property (assign, nonatomic,readwrite) BOOL allowDuplicateUpload;
@end

@implementation OWSUploadOperation

- (instancetype)initWithAttachmentId:(NSString *)attachmentId
                        recipientIds:(NSArray<NSString *> * _Nullable)recipientIds
{
    return [self initWithAttachmentId:attachmentId recipientIds:recipientIds allowDuplicateUpload:false];
}

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment
{
    self = [super init];
    if (!self) {
        return self;
    }
    self.isPutProfileSucess = false;
    self.remainingRetries = 4;
    self.reportRetryCount = 4;
    _attachmentId = @"1234567890";
    _attachment = attachment;
    self.allowDuplicateUpload = false;
    
    return self;
    
}

- (instancetype)initWithAttachmentId:(NSString *)attachmentId
                        recipientIds:(NSArray<NSString *> * _Nullable)recipientIds
                allowDuplicateUpload:(BOOL)allowDuplicateUpload
{
    self = [super init];
    if (!self) {
        return self;
    }
    self.avatarString = @"";
    self.remainingRetries = 4;
    self.reportRetryCount = 4;
    _attachmentId = attachmentId;
    _recipientIds = recipientIds;
    _attachment = nil;
    self.isPutProfileSucess = false;
    self.allowDuplicateUpload = allowDuplicateUpload;
    
    return self;
}

- (void)uploadAvatarWithServerId:(UInt64)serverId
                        location:(NSString *)location
                    avatarStream:(TSAttachmentStream *)avatarStream
               completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    OWSLogDebug(@"%@ started uploading data for avatar: %@", self.logTag, self.attachmentId);
    NSError *error;
    NSData *attachmentData = [avatarStream readDataFromFileWithError:&error];
    if (error) {
        OWSLogError(@"%@ Failed to read avatar data with error: %@", self.logTag, error);
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
            OWSLogError(@"%@ Unexpected server response: %d", weakSelf.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            invalidResponseError.isRetryable = YES;
            [weakSelf reportError:invalidResponseError];
            if (completionHandler) {
                completionHandler(nil, nil, invalidResponseError);
            }
            return;
        }

        OWSLogInfo(@"%@ Uploaded avatar: %p.", weakSelf.logTag, avatarStream.uniqueId);

        DatabaseStorageAsyncWrite(weakSelf.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [avatarStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                             block:^(TSAttachmentStream *instance) {
                instance.serverId = serverId;
                instance.isUploaded = YES;
            }];
            [transaction addAsyncCompletionOnMain:^{
                [weakSelf reportSuccess];
            }];
        });

        if (completionHandler) {
            completionHandler(nil, nil, nil);
        }
    }
                            progress:^(NSURLSessionTask *task, NSProgress *progress) {
        [weakSelf fireNotificationWithProgress:progress.fractionCompleted];
    }
                             failure:^(OWSHTTPErrorWrapper *errorWrapper) {
        NSError *err = errorWrapper.asNSError;
        err.isRetryable = YES;
        [weakSelf reportError:err];
        if (completionHandler) {
            completionHandler(nil, nil, err);
        }
    }];
}

- (void)syncrunWithProfileName:(NSString *)profileName profileKey:(SSKAES256Key*)profileKey {
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
        OWSLogDebug(@"%@ Attachment previously uploaded.", self.logTag);
        [self reportSuccess];
        return;
    }
    
    [self fireNotificationWithProgress:0];
    
    OWSLogDebug(@"%@ alloc attachment: %@", self.logTag, self.attachmentId);
    
    // firstly, request the uploading url for the avatar from server.
    self.group = dispatch_group_create();
    dispatch_group_enter(self.group);
    TSRequest *request = [OWSRequestFactory profileAvatarUploadUrlRequest:nil];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        OWSLogInfo(@"profile -> profileAvatarUploadUrlRequest");
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            dispatch_group_leave(self.group);
            OWSLogError(@"%@ unexpected response from server: %@", self.logTag, responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            error.isRetryable = YES;
            [self reportError:error];
            return;
        }
        
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        UInt64 serverId = ((NSDecimalNumber *)[responseDict objectForKey:@"id"]).unsignedLongLongValue;
        self.serverId = serverId;
        NSString *location = [responseDict objectForKey:@"location"];
        self.location = location;
        // just upload the avatar to the server.
        [self uploadAvatarWithServerId:serverId location:location avatarStream:attachmentStream completionHandler:^(NSURLResponse * _Nonnull response, id  _Nonnull responseObject, NSError * _Nonnull error) {
            OWSLogInfo(@"profile -> uploadAvatarWithServerId:%@",response);
            if (!error){
                // Upload data to server
                self.isPutProfileSucess = false;
                [self putV1ProfileWithResponse:response error:error avatarStream:attachmentStream profileName:profileName profileKey:profileKey];
            }else {
                dispatch_group_leave(self.group);
            }
        }];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        dispatch_group_leave(self.group);
        
        NSError *error = errorWrapper.asNSError;
        OWSLogError(@"%@ Failed to allocate attachment with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
    }];
    
    dispatch_group_wait(self.group, DISPATCH_TIME_FOREVER);
    return;
}

- (void)syncrunForUploadOnlyWithSuccess:(void (^)(NSString *attachmentId, NSString *location))successBlock
                                 failure:(void (^)(NSError *error))failureBlock {
    __block TSAttachmentStream *attachmentStream;
    if (self.attachment) {
        attachmentStream = self.attachment;
    }

    if (!attachmentStream) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotLoadAttachment]);
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = NO;
        if (failureBlock) {
            failureBlock(error);
        }
        return;
    }

    if (attachmentStream.isUploaded) {
        OWSLogInfo(@"%@ attachment previously uploaded.", self.logTag);
        if (successBlock) {
            successBlock([NSString stringWithFormat:@"%llu", self.serverId], self.location ?: @"");
        }
        return;
    }

    [self fireNotificationWithProgress:0];

    self.group = dispatch_group_create();
    dispatch_group_enter(self.group);

    TSRequest *request = [OWSRequestFactory profileAvatarUploadUrlRequest:nil];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ unexpected response from server: %@", self.logTag, responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            error.isRetryable = YES;
            if (failureBlock) {
                failureBlock(error);
            }
            dispatch_group_leave(self.group);
            return;
        }

        NSDictionary *responseDict = (NSDictionary *)responseObject;
        UInt64 serverId = ((NSDecimalNumber *)[responseDict objectForKey:@"id"]).unsignedLongLongValue;
        self.serverId = serverId;
        NSString *location = [responseDict objectForKey:@"location"];
        self.location = location;

        [self uploadAvatarWithServerId:serverId
                              location:location
                           avatarStream:attachmentStream
                      completionHandler:^(NSURLResponse * _Nonnull uploadResp,
                                          id  _Nonnull uploadObj,
                                          NSError * _Nonnull uploadError) {
            if (!uploadError) {
                NSString *attachmentId = [NSString stringWithFormat:@"%llu", serverId];
                if (successBlock) {
                    successBlock(attachmentId, location ?: @"");
                }
            } else {
                OWSLogError(@"%@ upload attachment failed: %@", self.logTag, uploadError);
                if (failureBlock) {
                    failureBlock(uploadError);
                }
            }
            dispatch_group_leave(self.group);
        }];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        OWSLogError(@"%@ Failed to allocate attachment with error: %@", self.logTag, error);
        error.isRetryable = YES;
        if (failureBlock) {
            failureBlock(error);
        }
        dispatch_group_leave(self.group);
    }];

    dispatch_group_wait(self.group, DISPATCH_TIME_FOREVER);
}

- (void)putV1ProfileWithResponse:(NSURLResponse *)response
                           error:(NSError *)error
                    avatarStream:(TSAttachmentStream *)avatarStream
                     profileName:(NSString *)profileName
                      profileKey:(SSKAES256Key*)profileKey {
    NSString *profileKeyString = [profileKey.keyData base64EncodedString];
    NSString *attachmentIdString = [NSString stringWithFormat:@"%llu",self.serverId];
    NSDictionary *avatar = @{@"attachmentId":attachmentIdString,@"encAlgo":@"AESGCM256",@"encKey":profileKeyString?:@""};
    
    NSString *avatarJson = [avatar signal_modelToJSONString];
    NSDictionary *parms = @{};
    if (!profileName && avatarJson.length) {
        parms = @{@"avatar":avatarJson};
    } else if (!profileName && !avatarJson){
        parms = @{};
    } else if (profileName.length && avatarJson.length) {
        parms = @{@"avatar":avatarJson,@"name":profileName};
    } else if (profileName && profileName.length == 0 && avatarJson.length){
        parms = @{@"name":@"",@"avatar":avatarJson};
    } else if (profileName && profileName.length == 0 && !avatarJson.length) {
        parms = @{@"name":@""};
    } else if (profileName.length && !avatarJson.length) {
        parms = @{@"name":profileName};
    }
    
    OWSLogInfo(@"putV1ProfileWithParams: \n %@",parms);
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (DTParamsUtils.validateDictionary(responseObject)) {
            NSNumber *status = (NSNumber *)responseObject[@"status"];
            
            if (DTParamsUtils.validateNumber(status) && [status intValue] == 0) {
                self.isPutProfileSucess = true;
                self.avatarString = avatarJson;
            } else {
                self.avatarString = @"";
                self.isPutProfileSucess = false;
            }
        } else {
            self.avatarString = @"";
            self.isPutProfileSucess = false;
        }
        
        dispatch_group_leave(self.group);
        OWSLogDebug(@"profile -> putV1ProfileWithParams:%@ errmsg:%@",responseObject,error.description);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        self.isPutProfileSucess = false;
        self.avatarString = @"";
        dispatch_group_leave(self.group);
    }];
}


- (void)uploadDebugLogRunSuccess:(void (^)(void))uploadSuccess
                   uploadFailure:(void (^)(NSError *error))uploadFailure
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
        OWSLogDebug(@"%@ debuglog Attachment previously uploaded.", self.logTag);
        [self reportSuccess];
        return;
    }
    
    [self fireNotificationWithProgress:0];
    
    OWSLogDebug(@"%@ alloc debuglog attachment: %@", self.logTag, self.attachmentId);
    
    // firstly, request the uploading url for the log from server.
    TSRequest *request = [OWSRequestFactory allocDebugLogAttachmentRequest];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            OWSLogError(@"%@ unexpected response from server: %@", self.logTag, responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            !uploadFailure ?: uploadFailure(error);
            return;
        }
        
        NSDictionary *responseDict = (NSDictionary *)responseObject;
        UInt64 serverId = ((NSDecimalNumber *)[responseDict objectForKey:@"id"]).unsignedLongLongValue;
        NSString *location = [responseDict objectForKey:@"location"];
        
        self.location = location;
        
        // just upload the log to the server.
        [self uploadLogFileServerId:serverId
                           location:location
                          logStream:attachmentStream
                      uploadSuccess:uploadSuccess
                      uploadFailure:uploadFailure];
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        OWSLogError(@"%@ Failed to allocate attachment with error: %@", self.logTag, error);

        !uploadFailure ?: uploadFailure(error);
    }];
}

- (void)run
{
    __block TSAttachmentStream *attachmentStream;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
        attachmentStream = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:self.attachmentId transaction:transaction];
    }];
    
    // Fetch can transiently miss a freshly-inserted attachment. Fall back to the in-memory one;
    // if still missing, report a terminal error below. Never return silently here, or the
    // operation stays Executing forever and blocks the per-thread serial send queue.
    if (![attachmentStream isKindOfClass:[TSAttachmentStream class]]) {
        attachmentStream = nil;
    }

    if (!attachmentStream && [self.attachment isKindOfClass:[TSAttachmentStream class]]) {
        attachmentStream = (TSAttachmentStream *)self.attachment;
    }

    if (!attachmentStream) {
        OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotLoadAttachment]);
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        // Not finding local attachment is a terminal failure.
        error.isRetryable = NO;
        [self reportError:error];
        return;
    }

    if (attachmentStream.isUploaded && attachmentStream.serverId > 0 && !self.allowDuplicateUpload) {
        OWSLogDebug(@"%@ Attachment previously uploaded.", self.logTag);
        [self reportSuccess];
        return;
    }
    
    [self fireNotificationWithProgress:0];

    OWSLogDebug(@"%@ alloc attachment: %@", self.logTag, self.attachmentId);
    
    NSError *error;
    NSData *attachmentData = [attachmentStream readDataFromFileWithError:&error];
    if (error) {
        OWSLogError(@"%@ Failed to read attachment data with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }
    
    if(attachmentData.length > OWSMediaUtils.kMaxFileSizeGeneric || attachmentData.length == 0){
        OWSLogError(@"%@ Attachment upload exceed expected content length:%ld , limite:%ld", self.logTag, attachmentData.length, OWSMediaUtils.kMaxFileSizeGeneric);
        NSError *error = OWSErrorAttachmentExceedsLimitError();
        error.isRetryable = NO;
        [self reportError:error];
        return;
    }
    
    // If encryptionKey exists (previously uploaded), verify it matches the current file hash; cancel upload on mismatch.
    NSData *originKey = [SSKCryptography computeSHA512Digest:attachmentData];
    if (attachmentStream.encryptionKey && attachmentStream.encryptionKey.length > 0) {
        NSString *fileHash = [originKey base64EncodedString];
        NSString *remoteHash = [attachmentStream.encryptionKey base64EncodedString];
        if (![fileHash isEqualToString:remoteHash]) {
            NSError *error = OWSErrorCheckAttachmentError(@"the hash of forwarding file is not equal to hash of file on server");
            [self reportError:error];
            return;
        }
    }
    
    NSData *eKey = [originKey subdataWithRange:NSMakeRange(0, 32)];
    NSData *hmacKey = [originKey subdataWithRange:NSMakeRange(32, 32)];
    NSData *keyHash = [SSKCryptography computeSHA256Digest:originKey];
    
    [DTFileRequestHandler checkFileExistsWithFileHash:[keyHash base64EncodedString]
                                           recipients:self.recipientIds
                                           completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        if (error) {
            OWSLogError(@"%@ checkFileExistsWithFileHash with error: %@", self.logTag, error);
            error.isRetryable = YES;
            [self reportError:error];
            return;
        }
        
        if(entity.exists &&
           DTParamsUtils.validateString(entity.cipherHash) &&
           DTParamsUtils.validateString(entity.attachmentId) &&
           entity.authorizeIdToInt > 0){
            //
            [self fireNotificationWithProgress:1.0];
            [self successWithAttachmentStream:attachmentStream serverId:entity.authorizeIdToInt originKey:originKey cipherHash:entity.cipherHash];
            if(self.rapidFileInfoBlock){
                NSMutableDictionary *info = @{}.mutableCopy;
                info[@"rapidHash"] = [keyHash base64EncodedString];
                info[@"authorizedId"] = entity.authorizeId;
                self.rapidFileInfoBlock(info.copy);
            }
            
        }else{
            // Server may return multiple URLs (urls array) or single URL (url field)
            NSArray<NSString *> *uploadUrls = entity.urls;
            if (!uploadUrls.count) {
                uploadUrls = DTParamsUtils.validateString(entity.url) ? @[entity.url] : @[];
            }

            if(!DTParamsUtils.validateString(entity.attachmentId) || uploadUrls.count == 0){
                OWSLogError(@"%@ checkFileExistsWithFileHash: attachmentId or urls == nil", self.logTag);
                NSError *missingInfoError = OWSErrorMakeFailedToSendOutgoingMessageError();
                missingInfoError.isRetryable = YES;
                [self reportError:missingInfoError];
                return;
            }
            
            void (^reportToServerCompletion)(DTFileDataEntity *entity) = ^(DTFileDataEntity *entity){
                
                if(self.rapidFileInfoBlock){
                    NSMutableDictionary *info = @{}.mutableCopy;
                    info[@"rapidHash"] = [keyHash base64EncodedString];
                    info[@"authorizedId"] = entity.authorizeId;
                    self.rapidFileInfoBlock(info.copy);
                }
                
                if(entity.exists &&
                   DTParamsUtils.validateString(entity.cipherHash) &&
                   DTParamsUtils.validateString(entity.attachmentId) &&
                   entity.authorizeIdToInt > 0){
                    [self fireNotificationWithProgress:1.0];
                    [self successWithAttachmentStream:attachmentStream serverId:entity.authorizeIdToInt originKey:originKey cipherHash:entity.cipherHash];
                }else{
                    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                        [attachmentStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                                             block:^(TSAttachmentStream * instance) {
                            instance.serverId = entity.authorizeIdToInt;
                        }];
                        [transaction addAsyncCompletionOnMain:^{
                            [self reportSuccess];
                        }];
                    });
                }
            };
            
            //upload
            if(!(attachmentStream.isUploaded &&
                DTParamsUtils.validateString(attachmentStream.serverAttachmentId))){
                // Use urls array if available, otherwise fallback to single url
                dispatch_async([OWSDispatch attachmentsQueue], ^{
                    NSArray<NSString *> *uploadUrls = entity.urls;
                    if (!uploadUrls || uploadUrls.count == 0) {
                        // Fallback to legacy single url field for backward compatibility
                        uploadUrls = entity.url ? @[entity.url] : @[];
                    }
                    
                    [self uploadWithUrls:uploadUrls
                        attachmentStream:attachmentStream
                          attachmentData:attachmentData
                                    eKey:eKey
                                 hmacKey:hmacKey
                      serverAttachmentId:entity.attachmentId
                                 success:^(NSData * digest){
                        [self reportToServerWithFileHash:[keyHash base64EncodedString]
                                            attachmentId:entity.attachmentId
                                          attachmentType:attachmentStream.isVoiceMessage ? 1 : 0
                                                fileSize:attachmentStream.encryptedDatalength
                                                  digest:digest completion:^(DTFileDataEntity *entity) {
                            reportToServerCompletion(entity);
                        }];
                    }];
                });
            }else{
                
                if(!attachmentStream.digest.length ||
                   attachmentStream.encryptedDatalength <= 0){
                    attachmentStream.isUploaded = NO;
                    OWSLogError(@"%@ attachmentStream.digest or encryptedDatalength == nil", self.logTag);
                    NSError *invalidStreamError = OWSErrorMakeFailedToSendOutgoingMessageError();
                    invalidStreamError.isRetryable = YES;
                    [self reportError:invalidStreamError];
                    return;
                }
                
                [self reportToServerWithFileHash:[keyHash base64EncodedString]
                                    attachmentId:attachmentStream.serverAttachmentId
                                  attachmentType:attachmentStream.isVoiceMessage ? 1 : 0
                                        fileSize:attachmentStream.encryptedDatalength
                                          digest:attachmentStream.digest
                                      completion:^(DTFileDataEntity *entity) {
                    reportToServerCompletion(entity);
                }];
            }
        }
    }];
}

- (void)reportToServerWithFileHash:(NSString *)fileHash
                      attachmentId:(NSString *)attachmentId
                    attachmentType:(NSInteger)attachmentType
                          fileSize:(long long)fileSize
                            digest:(NSData *)digest
                        completion:(void(^)(DTFileDataEntity *entity))completion{
    
    
    [DTFileRequestHandler reportToServerWithFileHash:fileHash
                                          recipients:self.recipientIds
                                        attachmentId:attachmentId
                                      attachmentType:attachmentType
                                            fileSize:fileSize
                                              digest:[[digest hexadecimalString] uppercaseString]
                                          completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        if(error || entity.authorizeIdToInt <= 0){
            OWSLogError(@"%@ reportToServer error: %@,entity.authorizeId = %lld", self.logTag, error, entity.authorizeIdToInt);
            if(self.reportRetryCount > 0){
                [self reportToServerWithFileHash:fileHash
                                    attachmentId:attachmentId
                                  attachmentType:attachmentType
                                        fileSize:fileSize
                                          digest:digest
                                      completion:completion];
                self.reportRetryCount --;
            }else{
                OWSLogError(@"%@ reportToServer 4 times error: %@, entity.authorizeId = %lld", self.logTag, error, entity.authorizeIdToInt);
                error.isRetryable = NO;
                [self reportError:error];
            }
            
        }else{
            completion(entity);
        }
        
    }];
    
}

- (void)successWithAttachmentStream:(TSAttachmentStream *)attachmentStream
                           serverId:(UInt64)serverId
                          originKey:(NSData *)originKey
                         cipherHash:(NSString *)cipherHash{
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [attachmentStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                             block:^(TSAttachmentStream * instance) {
            instance.encryptionKey = originKey;
            instance.digest = [NSData dataFromHexString:cipherHash];
            instance.isUploaded = YES;
            instance.serverId = serverId;
        }];
        [transaction addAsyncCompletionOnMain:^{
            [self reportSuccess];
        }];
    });
    
}

- (BOOL)isSecureURL:(NSString *)urlString {
    if (!urlString || urlString.length == 0) {
        return NO;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url || !url.scheme) {
        return NO;
    }

    return [url.scheme.lowercaseString isEqualToString:@"https"];
}

- (void)uploadWithUrl:(NSString *)url
     attachmentStream:(TSAttachmentStream *)attachmentStream
       attachmentData:(NSData *)attachmentData
                 eKey:(NSData *)eKey
              hmacKey:(NSData *)hmacKey
   serverAttachmentId:(NSString *)serverAttachmentId
              success:(void(^)(NSData *digest))success {
    // Legacy method - convert single URL to array and call new method
    NSArray *urls = url.length > 0 ? @[url] : @[];
    [self uploadWithUrls:urls
        attachmentStream:attachmentStream
          attachmentData:attachmentData
                    eKey:eKey
                 hmacKey:hmacKey
      serverAttachmentId:serverAttachmentId
                 success:success];
}

- (void)uploadWithUrls:(NSArray<NSString *> *)urls
      attachmentStream:(TSAttachmentStream *)attachmentStream
        attachmentData:(NSData *)attachmentData
                  eKey:(NSData *)eKey
               hmacKey:(NSData *)hmacKey
    serverAttachmentId:(NSString *)serverAttachmentId
               success:(void(^)(NSData *digest))success {
    
    if (!urls || urls.count == 0) {
        OWSLogError(@"%@ No upload URLs provided", self.logTag);
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }

    NSData *encryptionKey;
    NSData *digest;
    NSData *encryptedAttachmentData = [SSKCryptography encryptAttachmentData:attachmentData
                                                                         eKey:eKey
                                                                      hmacKey:hmacKey
                                                                       outKey:&encryptionKey
                                                                    outDigest:&digest
                                                                   useMd5Hash:YES];
    NSError *error;
    if (!encryptedAttachmentData) {
        OWSFailDebug(@"%@ could not encrypt attachment data.", self.logTag);
        error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }

    // Create error accumulator for tracking all failures
    __block NSMutableArray *urlErrors = [NSMutableArray array];
    
    // Try uploading with fallback mechanism
    [self attemptUploadWithUrls:urls
                       urlIndex:0
                      urlErrors:urlErrors
               attachmentStream:attachmentStream
        encryptedAttachmentData:encryptedAttachmentData
                  encryptionKey:encryptionKey
                         digest:digest
             serverAttachmentId:serverAttachmentId
                        success:success];
}

- (void)attemptUploadWithUrls:(NSArray<NSString *> *)urls
                      urlIndex:(NSUInteger)urlIndex
                     urlErrors:(NSMutableArray<NSError *> *)urlErrors
              attachmentStream:(TSAttachmentStream *)attachmentStream
       encryptedAttachmentData:(NSData *)encryptedAttachmentData
                 encryptionKey:(NSData *)encryptionKey
                        digest:(NSData *)digest
            serverAttachmentId:(NSString *)serverAttachmentId
                       success:(void(^)(NSData *digest))success {
    
    // Check if operation was cancelled before attempting upload
    if (self.isCancelled) {
        OWSLogInfo(@"%@ Upload operation cancelled, aborting URL attempts", self.logTag);
        return;
    }

    if (urlIndex >= urls.count) {
        // Log all accumulated errors for debugging
        OWSLogError(@"%@ All upload URLs failed. Errors:", self.logTag);
        for (NSUInteger i = 0; i < urlErrors.count; i++) {
            OWSLogError(@"  URL %lu: %@", (unsigned long)(i + 1), urlErrors[i]);
        }
        
        NSError *error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }

    NSString *url = urls[urlIndex];

    // Validate URL is HTTPS for security
    if (![self isSecureURL:url]) {
        NSError *urlError = [NSError errorWithDomain:@"OWSUploadOperation"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Non-HTTPS URL rejected"}];
        [urlErrors addObject:urlError];
        
        OWSLogError(@"%@ Rejecting non-HTTPS URL %lu: %@",
                    self.logTag, (unsigned long)(urlIndex + 1), url);
        // Try next URL
        [self attemptUploadWithUrls:urls
                           urlIndex:urlIndex + 1
                          urlErrors:urlErrors
                   attachmentStream:attachmentStream
            encryptedAttachmentData:encryptedAttachmentData
                      encryptionKey:encryptionKey
                             digest:digest
                 serverAttachmentId:serverAttachmentId
                            success:success];
        return;
    }

    OWSLogInfo(@"%@ Attempting upload to URL %lu/%lu: %@",
               self.logTag, (unsigned long)(urlIndex + 1), (unsigned long)urls.count, url);

    // Create NSMutableURLRequest directly for file upload
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"PUT";
    // Set required headers
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
            NSError *statusError = [NSError errorWithDomain:@"OWSUploadOperation"
                                                       code:statusCode
                                                   userInfo:@{NSLocalizedDescriptionKey:
                                                                  [NSString stringWithFormat:@"HTTP %ld", (long)statusCode]}];
            [urlErrors addObject:statusError];
            
            OWSLogError(@"%@ URL %lu failed with status: %ld",
                        weakSelf.logTag, (unsigned long)(urlIndex + 1), (long)statusCode);
            
            // Try next URL
            [weakSelf attemptUploadWithUrls:urls
                                   urlIndex:urlIndex + 1
                                  urlErrors:urlErrors
                           attachmentStream:attachmentStream
                    encryptedAttachmentData:encryptedAttachmentData
                              encryptionKey:encryptionKey
                                     digest:digest
                         serverAttachmentId:serverAttachmentId
                                    success:success];
            return;
        }

        OWSLogInfo(@"%@ Successfully uploaded attachment to URL %lu: %@",
                   weakSelf.logTag, (unsigned long)(urlIndex + 1), attachmentStream.uniqueId);

        AudioWaveform *waveform = nil;
        if (attachmentStream.isVoiceMessage) {
            NSError *writeError;
            [attachmentStream writeEncryptedData:encryptedAttachmentData error:&writeError];
            if (writeError) {
                DDLogError(@"%@ send voice Failed writing voice stream with error: %@",
                           weakSelf.logTag, writeError);
                writeError.isRetryable = YES;
                [weakSelf reportError:writeError];
                return;
            }

            NSError *waveformError;
            waveform = [AudioWaveformManagerImpl.shared audioWaveformSyncForAudioPath:[attachmentStream filePath] error:&waveformError];
            OWSLogInfo(@"send voice get attachmentStream file path: %@", [attachmentStream filePath]);
            OWSLogInfo(@"send voice get attachmentStream file byteCount: %llu", [attachmentStream byteCount]);
            if (waveformError) {
                OWSLogError(@"send voice draw error:%@.", waveformError);
                waveformError.isRetryable = YES;
                [weakSelf reportError:waveformError];
                return;
            }
        }

        DatabaseStorageAsyncWrite(weakSelf.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [attachmentStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                                 block:^(TSAttachmentStream *instance) {
                instance.encryptionKey = encryptionKey;
                instance.digest = digest;
                instance.encryptedDatalength = encryptedAttachmentData.length;
                instance.isUploaded = YES;
                instance.serverAttachmentId = serverAttachmentId;
                if (instance.isVoiceMessage) {
                    instance.decibelSamples = waveform.decibelSamples;
                    instance.cachedAudioDurationSeconds = @([AudioWaveformManagerImpl.shared audioDurationFrom:attachmentStream.filePath]);
                }
            }];
            [transaction addAsyncCompletionOnMain:^{
                success(digest);
                [attachmentStream removeVoicePlaintextFile];
            }];
        });
    }
                            progress:^(NSURLSessionTask *task, NSProgress *progress) {
        [weakSelf fireNotificationWithProgress:progress.fractionCompleted];
    }
                             failure:^(OWSHTTPErrorWrapper *errorWrapper) {
        NSError *err = errorWrapper.asNSError;
        [urlErrors addObject:err];
        OWSLogError(@"%@ URL %lu upload error: %@",
                    weakSelf.logTag, (unsigned long)(urlIndex + 1), err);
        // Try next URL
        [weakSelf attemptUploadWithUrls:urls
                               urlIndex:urlIndex + 1
                              urlErrors:urlErrors
                       attachmentStream:attachmentStream
                encryptedAttachmentData:encryptedAttachmentData
                          encryptionKey:encryptionKey
                                 digest:digest
                     serverAttachmentId:serverAttachmentId
                                success:success];
    }];
}

- (void)uploadLogFileServerId:(UInt64)serverId
                     location:(NSString *)location
                    logStream:(TSAttachmentStream *)logStream
                uploadSuccess:(void (^)(void))uploadSuccess
                uploadFailure:(void (^)(NSError *error))uploadFailure
{
    OWSLogDebug(@"%@ started uploading debuglog files: %@", self.logTag, logStream.uniqueId);
    NSError *error;
    NSData *attachmentData = [logStream readDataFromFileWithError:&error];
    if (error) {
        OWSLogError(@"%@ Failed to upload debuglog file with error: %@", self.logTag, error);
        
        uploadFailure(error);
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
            OWSLogError(@"%@ Unexpected server response: %d", weakSelf.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            
            !uploadFailure ?: uploadFailure(invalidResponseError);
            return;
        }

        OWSLogInfo(@"%@ Uploaded debuglog files success: %@.", weakSelf.logTag, logStream.uniqueId);

        !uploadSuccess ?: uploadSuccess();

        DatabaseStorageAsyncWrite(weakSelf.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [logStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                          block:^(TSAttachmentStream *instance) {
                instance.serverId = serverId;
                instance.isUploaded = YES;
            }];
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
        !uploadFailure ?: uploadFailure(err);
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
