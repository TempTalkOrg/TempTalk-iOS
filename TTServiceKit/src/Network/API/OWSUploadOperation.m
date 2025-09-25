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
#import <AFNetworking/AFURLSessionManager.h>
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
    
    // some oss servers require "Content-Type: Data" whoes value is MIME Type usually.
    // donot set this header maybe ok, so, just comment this.
    //[request setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];
    
    AFURLSessionManager *manager = [[AFURLSessionManager alloc]
                                    initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionUploadTask *uploadTask;
    uploadTask = [manager uploadTaskWithRequest:request
                                       fromData:attachmentData
                                       progress:^(NSProgress *_Nonnull uploadProgress) {
        [self fireNotificationWithProgress:uploadProgress.fractionCompleted];
    }
                              completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
        OWSAssertIsOnMainThread();
        if (error) {
            error.isRetryable = YES;
            [self reportError:error];
            if (completionHandler) {
                completionHandler(response,responseObject,error);
            }
            return;
        }
        
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
        if (!isValidResponse) {
            OWSLogError(@"%@ Unexpected server response: %d", self.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            invalidResponseError.isRetryable = YES;
            [self reportError:invalidResponseError];
            return;
        }
        
        OWSLogInfo(@"%@ Uploaded avatar: %p.", self.logTag, avatarStream.uniqueId);
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [avatarStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                                 block:^(TSAttachmentStream * instance) {
                instance.serverId = serverId;
                instance.isUploaded = YES;
            }];
            [transaction addAsyncCompletionOnMain:^{
                [self reportSuccess];
            }];
        });
        
        if (completionHandler) {
            completionHandler(response,responseObject,error);
        }
    }];
    
    [uploadTask resume];
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
                //上传传数据到本地服务器
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
    
    if (![attachmentStream isKindOfClass:[TSAttachmentStream class]]) {
        return;
    }
    
    if(self.attachment && [self.attachment isKindOfClass:TSAttachmentStream.class]){
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
    
    // 若附件的 encryptionKey 不为空（说明之前上传过），需要校验 encryptionKey 与当前文件的 hash 是否一致，如果不一致取消上传流程
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
            if(!DTParamsUtils.validateString(entity.attachmentId) ||
               !DTParamsUtils.validateString(entity.url)){
                OWSLogError(@"%@ checkFileExistsWithFileHash: attachmentId or url == nil", self.logTag);
                error.isRetryable = YES;
                [self reportError:error];
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
                dispatch_async([OWSDispatch attachmentsQueue], ^{
                    [self uploadWithUrl:entity.url
                       attachmentStream:attachmentStream
                         attachmentData:attachmentData
                                   eKey:eKey
                                hmacKey:hmacKey
                     serverAttachmentId:entity.attachmentId
                                success:^(NSData * digest){
                        [self reportToServerWithFileHash:[keyHash base64EncodedString]
                                            attachmentId:entity.attachmentId
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
                    error.isRetryable = YES;
                    [self reportError:error];
                    return;
                }
                
                [self reportToServerWithFileHash:[keyHash base64EncodedString]
                                    attachmentId:attachmentStream.serverAttachmentId
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
                          fileSize:(long long)fileSize
                            digest:(NSData *)digest
                        completion:(void(^)(DTFileDataEntity *entity))completion{
    
    
    [DTFileRequestHandler reportToServerWithFileHash:fileHash
                                          recipients:self.recipientIds
                                        attachmentId:attachmentId
                                            fileSize:fileSize
                                              digest:[[digest hexadecimalString] uppercaseString]
                                          completion:^(DTFileDataEntity * _Nullable entity, NSError * _Nullable error) {
        if(error || entity.authorizeIdToInt <= 0){
            OWSLogError(@"%@ reportToServer error: %@,entity.authorizeId = %lld", self.logTag, error, entity.authorizeIdToInt);
            if(self.reportRetryCount > 0){
                [self reportToServerWithFileHash:fileHash attachmentId:attachmentId fileSize:fileSize digest:digest completion:completion];
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

- (void)uploadWithUrl:(NSString *)url
     attachmentStream:(TSAttachmentStream *)attachmentStream
       attachmentData:(NSData *)attachmentData
                 eKey:(NSData *)eKey
              hmacKey:(NSData *)hmacKey
   serverAttachmentId:(NSString *)serverAttachmentId
           success:(void(^)(NSData *digest))success{
    
    NSData *encryptionKey;
    NSData *digest;
    NSData *encryptedAttachmentData = [SSKCryptography encryptAttachmentData:attachmentData eKey:eKey hmacKey:hmacKey outKey:&encryptionKey outDigest:&digest useMd5Hash:YES];
    
    NSError *error;
    if (!encryptedAttachmentData) {
        OWSFailDebug(@"%@ could not encrypt attachment data.", self.logTag);
        error = OWSErrorMakeFailedToSendOutgoingMessageError();
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"PUT";
    
    // some oss servers require "Content-Type: Data" whoes value is MIME Type usually.
    // maybe donot set this header is ok, so, just comment this.
    //[request setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];

    AFURLSessionManager *manager = [[AFURLSessionManager alloc]
        initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    NSURLSessionUploadTask *uploadTask;
    uploadTask = [manager uploadTaskWithRequest:request
        fromData:encryptedAttachmentData
        progress:^(NSProgress *_Nonnull uploadProgress) {
            [self fireNotificationWithProgress:uploadProgress.fractionCompleted];
        }
        completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
            OWSAssertIsOnMainThread();
            if (error) {
                OWSLogError(@"%@ upload network error: %@", self.logTag, error);
                error.isRetryable = YES;
                [self reportError:error];
                return;
            }

            NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
            BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
            if (!isValidResponse) {
                OWSLogError(@"%@ Unexpected server response: %d", self.logTag, (int)statusCode);
                NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
                invalidResponseError.isRetryable = YES;
                [self reportError:invalidResponseError];
                return;
            }

            OWSLogInfo(@"%@ Uploaded attachment: %p.", self.logTag, attachmentStream.uniqueId);

//            attachmentStream.serverId = serverId;
        
            AudioWaveform *waveform = nil;
            if (attachmentStream.isVoiceMessage) {
                NSError *writeError;
                [attachmentStream writeEncryptedData:encryptedAttachmentData error:&writeError];
                if (writeError) {
                    DDLogError(@"%@ send voice Failed writing voice stream with error: %@", self.logTag, writeError);
                    error.isRetryable = YES;
                    [self reportError:error];
                    return;
                }
                
                NSError *error;
                waveform = [AudioWaveformManagerImpl.shared audioWaveformSyncForAudioPath:[attachmentStream filePath] error:&error];
                OWSLogInfo(@"send voice get attachmentStream file path: %@", [attachmentStream filePath]);
                OWSLogInfo(@"send voice get attachmentStream file byteCount: %d", [attachmentStream byteCount]);
                if (error) {
                    OWSLogError(@"send voice draw error:%@.", error);
                    error.isRetryable = YES;
                    [self reportError:error];
                    return;
                }
                
            }
        
            
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                [attachmentStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                                     block:^(TSAttachmentStream * instance) {
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
        }];

    [uploadTask resume];
    
    
}

/*
- (void)uploadWithServerId:(UInt64)serverId
                  location:(NSString *)location
          attachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSLogDebug(@"%@ started uploading data for attachment: %@", self.logTag, self.attachmentId);
    NSError *error;
    NSData *attachmentData = [attachmentStream readDataFromFileWithError:&error];
    if (error) {
        OWSLogError(@"%@ Failed to read attachment data with error: %@", self.logTag, error);
        error.isRetryable = YES;
        [self reportError:error];
        return;
    }

    NSData *encryptionKey;
    NSData *digest;
    NSData *_Nullable encryptedAttachmentData =
        [Cryptography encryptAttachmentData:attachmentData outKey:&encryptionKey outDigest:&digest];
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
    
    // some oss servers require "Content-Type: Data" whoes value is MIME Type usually.
    // maybe donot set this header is ok, so, just comment this.
    //[request setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];

    AFURLSessionManager *manager = [[AFURLSessionManager alloc]
        initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

    NSURLSessionUploadTask *uploadTask;
    uploadTask = [manager uploadTaskWithRequest:request
        fromData:encryptedAttachmentData
        progress:^(NSProgress *_Nonnull uploadProgress) {
            [self fireNotificationWithProgress:uploadProgress.fractionCompleted];
        }
        completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
            OWSAssertIsOnMainThread();
            if (error) {
                error.isRetryable = YES;
                [self reportError:error];
                return;
            }

            NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
            BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
            if (!isValidResponse) {
                OWSLogError(@"%@ Unexpected server response: %d", self.logTag, (int)statusCode);
                NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
                invalidResponseError.isRetryable = YES;
                [self reportError:invalidResponseError];
                return;
            }

            OWSLogInfo(@"%@ Uploaded attachment: %p.", self.logTag, attachmentStream.uniqueId);
            attachmentStream.serverId = serverId;
            attachmentStream.isUploaded = YES;
            [attachmentStream saveAsyncWithCompletionBlock:^{
                [self reportSuccess];
            }];
        }];

    [uploadTask resume];
}

 */
 
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
    
    // some oss servers require "Content-Type: Data" whoes value is MIME Type usually.
    // donot set this header maybe ok, so, just comment this.
    //[request setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];
    
    AFURLSessionManager *manager = [[AFURLSessionManager alloc]
                                    initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    
    NSURLSessionUploadTask *uploadTask;
    uploadTask = [manager uploadTaskWithRequest:request
                                       fromData:attachmentData
                                       progress:^(NSProgress *_Nonnull uploadProgress) {
                                           [self fireNotificationWithProgress:uploadProgress.fractionCompleted];
                                       }
                              completionHandler:^(NSURLResponse *_Nonnull response, id _Nullable responseObject, NSError *_Nullable error) {
        OWSAssertIsOnMainThread();
        if (error) {
            
            !uploadFailure ?: uploadFailure(error);
            return;
        }
        
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        BOOL isValidResponse = (statusCode >= 200) && (statusCode < 400);
        if (!isValidResponse) {
            OWSLogError(@"%@ Unexpected server response: %d", self.logTag, (int)statusCode);
            NSError *invalidResponseError = OWSErrorMakeUnableToProcessServerResponseError();
            
            !uploadFailure ?: uploadFailure(invalidResponseError);
            return;
        }
        
        OWSLogInfo(@"%@ Uploaded debuglog files success: %@.", self.logTag, logStream.uniqueId);
        
        !uploadSuccess ?: uploadSuccess();
        
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [logStream anyUpdateAttachmentStreamWithTransaction:transaction
                                                          block:^(TSAttachmentStream * instance) {
                instance.serverId = serverId;
                instance.isUploaded = YES;
            }];
            [transaction addAsyncCompletionOnMain:^{
                [self reportSuccess];
            }];
            
        });
        
    }];
    
    [uploadTask resume];
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
