//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "Pastelog.h"
#import "Yelling-Swift.h"
#import "ThreadUtil.h"
#import "zlib.h"
#import <AFNetworking/AFHTTPSessionManager.h>
#import <SSZipArchive/SSZipArchive.h>
#import <TTMessaging/AttachmentSharing.h>
#import <TTMessaging/DebugLogger.h>
#import <TTMessaging/Environment.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/MimeTypeUtil.h>
//
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TSContactThread.h>
#import <SignalCoreKit/Threading.h>
#import <SignalCoreKit/Cryptography.h>
#import <TTServiceKit/DTCltlogAPI.h>
#import <TTMessaging/TTMessaging-Swift.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^UploadDebugLogsSuccess)(NSURL *url);
typedef void (^UploadDebugLogsFailure)(NSString *localizedErrorMessage);

typedef void (^UploadDebugZipLogsSuccess)(NSURL *url);
typedef void (^UploadDebugZipLogsFailure)(NSString *localizedErrorMessage);
typedef void (^CreateZipLogsSuccess)(NSString *logZipFilePath, NSString *logsZipName);
typedef void (^CreateZipLogsFail)(NSString *reason);

#pragma mark -

@class DebugLogUploader;

typedef void (^DebugLogUploadSuccess)(DebugLogUploader *uploader, NSURL *url);
typedef void (^DebugLogUploadFailure)(DebugLogUploader *uploader, NSError *error);

@interface DebugLogUploader : NSObject

@property (nonatomic) NSURL *fileUrl;
@property (nonatomic) NSString *mimeType;
@property (nonatomic, nullable) DebugLogUploadSuccess success;
@property (nonatomic, nullable) DebugLogUploadFailure failure;

@end

#pragma mark -

@implementation DebugLogUploader

- (void)dealloc
{
    DDLogVerbose(@"Dealloc: %@", self.logTag);
}

- (void)uploadFileWithURL:(NSURL *)fileUrl
                 mimeType:(NSString *)mimeType
                  success:(DebugLogUploadSuccess)success
                  failure:(DebugLogUploadFailure)failure
{
    OWSAssertDebug(fileUrl);
    OWSAssertDebug(mimeType.length > 0);
    OWSAssertDebug(success);
    OWSAssertDebug(failure);

    self.fileUrl = fileUrl;
    self.mimeType = mimeType;
    self.success = success;
    self.failure = failure;

    [self getUploadParameters];
}

- (void)getUploadParameters
{
    __weak DebugLogUploader *weakSelf = self;

    NSURLSessionConfiguration *sessionConf = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    AFHTTPSessionManager *sessionManager =
        [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:sessionConf];
    sessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    NSString *urlString = @"https://difft.org/debuglogs/";
    [sessionManager GET:urlString
             parameters:nil
                headers:nil
               progress:nil
                success:^(NSURLSessionDataTask *task, id _Nullable responseObject) {
            DebugLogUploader *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }

            if (![responseObject isKindOfClass:[NSDictionary class]]) {
                DDLogError(@"%@ Invalid response: %@, %@", strongSelf.logTag, urlString, responseObject);
                [strongSelf
                    failWithError:OWSErrorWithCodeDescription(OWSErrorCodeDebugLogUploadFailed, @"Invalid response")];
                return;
            }
            NSString *uploadUrl = responseObject[@"url"];
            if (![uploadUrl isKindOfClass:[NSString class]] || uploadUrl.length < 1) {
                DDLogError(@"%@ Invalid response: %@, %@", strongSelf.logTag, urlString, responseObject);
                [strongSelf
                    failWithError:OWSErrorWithCodeDescription(OWSErrorCodeDebugLogUploadFailed, @"Invalid response")];
                return;
            }
            NSDictionary *fields = responseObject[@"fields"];
            if (![fields isKindOfClass:[NSDictionary class]] || fields.count < 1) {
                DDLogError(@"%@ Invalid response: %@, %@", strongSelf.logTag, urlString, responseObject);
                [strongSelf
                    failWithError:OWSErrorWithCodeDescription(OWSErrorCodeDebugLogUploadFailed, @"Invalid response")];
                return;
            }
            for (NSString *fieldName in fields) {
                NSString *fieldValue = fields[fieldName];
                if (![fieldName isKindOfClass:[NSString class]] || fieldName.length < 1
                    || ![fieldValue isKindOfClass:[NSString class]] || fieldValue.length < 1) {
                    DDLogError(@"%@ Invalid response: %@, %@", strongSelf.logTag, urlString, responseObject);
                    [strongSelf failWithError:OWSErrorWithCodeDescription(
                                                  OWSErrorCodeDebugLogUploadFailed, @"Invalid response")];
                    return;
                }
            }
            NSString *_Nullable uploadKey = fields[@"key"];
            if (![uploadKey isKindOfClass:[NSString class]] || uploadKey.length < 1) {
                DDLogError(@"%@ Invalid response: %@, %@", strongSelf.logTag, urlString, responseObject);
                [strongSelf
                    failWithError:OWSErrorWithCodeDescription(OWSErrorCodeDebugLogUploadFailed, @"Invalid response")];
                return;
            }
            
            // Add a file extension to the upload's key.
            NSString *fileExtension = strongSelf.fileUrl.lastPathComponent.pathExtension;
            if (fileExtension.length < 1) {
                DDLogError(@"%@ Invalid file url: %@, %@", strongSelf.logTag, urlString, responseObject);
                [strongSelf
                    failWithError:OWSErrorWithCodeDescription(OWSErrorCodeDebugLogUploadFailed, @"Invalid file url")];
                return;
            }
            uploadKey = [uploadKey stringByAppendingPathExtension:fileExtension];
            NSMutableDictionary *updatedFields = [fields mutableCopy];
            updatedFields[@"key"] = uploadKey;

            [strongSelf uploadFileWithUploadUrl:uploadUrl fields:updatedFields uploadKey:uploadKey];
        }
        failure:^(NSURLSessionDataTask *_Nullable task, NSError *error) {
            DDLogError(@"%@ failed: %@", weakSelf.logTag, urlString);
            [weakSelf failWithError:error];
        }];
}

- (void)uploadFileWithUploadUrl:(NSString *)uploadUrl fields:(NSDictionary *)fields uploadKey:(NSString *)uploadKey
{
    OWSAssertDebug(uploadUrl.length > 0);
    OWSAssertDebug(fields);
    OWSAssertDebug(uploadKey.length > 0);

    __weak DebugLogUploader *weakSelf = self;
    NSURLSessionConfiguration *sessionConf = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    AFHTTPSessionManager *sessionManager =
        [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:sessionConf];
    sessionManager.requestSerializer = [AFHTTPRequestSerializer serializer];
    sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [sessionManager POST:uploadUrl
              parameters:@{}
                 headers:nil
        constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            for (NSString *fieldName in fields) {
                NSString *fieldValue = fields[fieldName];
                [formData appendPartWithFormData:[fieldValue dataUsingEncoding:NSUTF8StringEncoding] name:fieldName];
            }
            [formData appendPartWithFormData:[weakSelf.mimeType dataUsingEncoding:NSUTF8StringEncoding]
                                        name:@"content-type"];

            NSError *error;
            BOOL success = [formData appendPartWithFileURL:weakSelf.fileUrl
                                                      name:@"file"
                                                  fileName:weakSelf.fileUrl.lastPathComponent
                                                  mimeType:weakSelf.mimeType
                                                     error:&error];
            if (!success || error) {
                DDLogError(@"%@ failed: %@, error: %@", weakSelf.logTag, uploadUrl, error);
            }
        }
        progress:nil
        success:^(NSURLSessionDataTask *task, id _Nullable responseObject) {
            DDLogVerbose(@"%@ Response: %@, %@", weakSelf.logTag, uploadUrl, responseObject);

            NSString *urlString = [NSString stringWithFormat:@"https://difft.org/debuglogs/%@", uploadKey];
            [self succeedWithUrl:[NSURL URLWithString:urlString]];
        }
        failure:^(NSURLSessionDataTask *_Nullable task, NSError *error) {
            DDLogError(@"%@ upload: %@ failed with error: %@", weakSelf.logTag, uploadUrl, error);
            [weakSelf failWithError:error];
        }];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;

    NSInteger statusCode = httpResponse.statusCode;
    // We'll accept any 2xx status code.
    NSInteger statusCodeClass = statusCode - (statusCode % 100);
    if (statusCodeClass != 200) {
        DDLogError(@"%@ statusCode: %zd, %zd", self.logTag, statusCode, statusCodeClass);
        DDLogError(@"%@ headers: %@", self.logTag, httpResponse.allHeaderFields);
        [self failWithError:[NSError errorWithDomain:@"PastelogKit"
                                                code:10001
                                            userInfo:@{ NSLocalizedDescriptionKey : @"Invalid response code." }]];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    [self failWithError:error];
}

- (void)failWithError:(NSError *)error
{
    OWSAssertDebug(error);

    DDLogError(@"%@ %s %@", self.logTag, __PRETTY_FUNCTION__, error);

    DispatchMainThreadSafe(^{
        // Call the completions exactly once.
        if (self.failure) {
            self.failure(self, error);
        }
        self.success = nil;
        self.failure = nil;
    });
}

- (void)succeedWithUrl:(NSURL *)url
{
    OWSAssertDebug(url);

    DDLogVerbose(@"%@ %s %@", self.logTag, __PRETTY_FUNCTION__, url);

    DispatchMainThreadSafe(^{
        // Call the completions exactly once.
        if (self.success) {
            self.success(self, url);
        }
        self.success = nil;
        self.failure = nil;
    });
}

@end

#pragma mark -

@interface Pastelog () <UIAlertViewDelegate>

@property (nonatomic) UIAlertController *loadingAlert;

@property (nonatomic) DebugLogUploader *currentUploader;
@property (nonatomic, strong) DTCltlogAPI *cltlogAPI;

@end

#pragma mark -

@implementation Pastelog

+ (instancetype)sharedManager
{
    static Pastelog *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] initDefault];
    });
    return sharedMyManager;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

+ (void)submitLogsWithCompletion:(nullable SubmitDebugLogsCompletion)completionParam
{
    [self uploadLogsWithSuccess:^(NSURL *url) {
    
        DispatchMainThreadSafe(^{
            
            
            if (completionParam) {
                completionParam();
            }
            
            UIAlertController *alert = [UIAlertController
                                        alertControllerWithTitle:Localized(@"DEBUG_LOG_ALERT_TITLE", @"Title of the debug log alert.")
                                        message:nil
                                        preferredStyle:UIAlertControllerStyleAlert];
            
#ifdef DEBUG
            [alert
             addAction:[UIAlertAction actionWithTitle:Localized(@"DEBUG_LOG_ALERT_OPTION_SEND_TO_SELF",
                                                                        @"Label for the 'send to self' option of the debug log alert.")
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
                [Pastelog.sharedManager sendToSelf:url];
            }]];
            [alert addAction:[UIAlertAction
                              actionWithTitle:Localized(@"DEBUG_LOG_ALERT_OPTION_SEND_TO_LAST_THREAD",
                                                                @"Label for the 'send to last thread' option of the debug log alert.")
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {

                [Pastelog.sharedManager sendToMostRecentThread:url];
            }]];
#endif
            
            [alert addAction:[OWSAlerts doneAction]];
            UIViewController *presentingViewController
            = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
            [presentingViewController presentViewController:alert animated:NO completion:nil];
            
        });

    } failure:^(NSString * _Nonnull localizedErrorMessage) {
        DispatchMainThreadSafe(^{
            
            if (completionParam) {
                completionParam();
            }
            
            [Pastelog showFailureAlertWithMessage:localizedErrorMessage];
        });
    }];
}

- (void)createAndGetLogZipFilePath:(CreateZipLogsSuccess)createSuccess
                        createFail:(CreateZipLogsFail)createFail {
    // Phase 1. Make a local copy of all of the log files.
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateFormat:@"yyyy.MM.dd hh.mm.ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate new]];
    NSString *logsName = [[dateString stringByAppendingString:@" "] stringByAppendingString:NSUUID.UUID.UUIDString];
    NSString *logsZipName = [logsName stringByAppendingPathExtension:@"zip"];
    NSString *tempDirectory = NSTemporaryDirectory();
    NSString *zipFilePath =
        [tempDirectory stringByAppendingPathComponent:logsZipName];
    NSString *zipDirPath = [tempDirectory stringByAppendingPathComponent:logsName];
    [OWSFileSystem ensureDirectoryExists:zipDirPath];

    NSArray<NSString *> *logFilePaths = DebugLogger.shared.allLogFilePaths;
    if (logFilePaths.count < 1) {
        createFail(Localized(@"DEBUG_LOG_ALERT_NO_LOGS", @"Error indicating that no debug logs could be found."));
        return;
    }

    for (NSString *logFilePath in logFilePaths) {
        NSString *copyFilePath = [zipDirPath stringByAppendingPathComponent:logFilePath.lastPathComponent];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:logFilePath toPath:copyFilePath error:&error];
        if (error) {
            createFail(Localized(
                @"DEBUG_LOG_ALERT_COULD_NOT_COPY_LOGS", @"Error indicating that the debug logs could not be copied."));
            return;
        }
        [OWSFileSystem protectFileOrFolderAtPath:copyFilePath];
    }

    // Phase 2. Zip up the log files.
    BOOL zipSuccess = [SSZipArchive createZipFileAtPath:zipFilePath
                                withContentsOfDirectory:zipDirPath
                                    keepParentDirectory:YES
                                       compressionLevel:Z_DEFAULT_COMPRESSION
                                               password:nil
                                                    AES:NO
                                        progressHandler:nil];
    if (!zipSuccess) {
        createFail(Localized(
            @"DEBUG_LOG_ALERT_COULD_NOT_PACKAGE_LOGS", @"Error indicating that the debug logs could not be packaged."));
        return;
    }

    [OWSFileSystem protectFileOrFolderAtPath:zipFilePath];
    [OWSFileSystem deleteFile:zipDirPath];
    
    createSuccess(zipFilePath, logsZipName);
}

- (void)uploadZipLogFileSuccess:(void (^)(NSURL *_Nullable zipLogUrl))successBlock
                        failure:(void (^)(NSString *_Nullable localizedErrorMessage))failureBlock {
    // Ensure that we call the completions on the main thread.
    UploadDebugZipLogsSuccess success = ^(NSURL *url) {
        if (successBlock) {
            
            DispatchMainThreadSafe(^{
                successBlock(url);
            });
        }
    };
    UploadDebugZipLogsFailure failure = ^(NSString *localizedErrorMessage) {
        if (failureBlock) {
            
            DispatchMainThreadSafe(^{
                failureBlock(localizedErrorMessage);
            });
        }
    };
    
    [self createAndGetLogZipFilePath:^(NSString * _Nonnull logZipFilePath, NSString * _Nonnull logsZipName) {
        NSData *data = [[NSData alloc] initWithContentsOfFile:logZipFilePath];
        if (data) {
            
            [self uploadLogToService:logsZipName
                      logZipFilePath:logZipFilePath
                             logData:data
                             success:success
                             failure:failure];
        }
    } createFail:^(NSString * _Nonnull reason) {
        
        failure(reason);
    }];
}

- (void)uploadLogToService:(NSString *_Nullable)logFileName
            logZipFilePath:(NSString *)logZipFilePath
                   logData:(NSData *_Nullable)logData
                   success:(void (^)(NSURL *_Nullable zipLogUrl))successBlock
                   failure:(void (^)(NSString *_Nullable localizedErrorMessage))failureBlock
{
    OWSAssertDebug(successBlock);
    OWSAssertDebug(failureBlock);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // 1 encrypt data
        NSData *encryptedLogData = [self encryptData:logData];
        
        // 2 request upload url from server, and then upload it.
        TSAttachmentStream *attachmentStream =
        [[TSAttachmentStream alloc] initWithContentType:OWSMimeTypeApplicationZip
                                              byteCount:(UInt32)encryptedLogData.length
                                         sourceFilename:logFileName
                                         albumMessageId:nil
                                                albumId:nil];
        
        id <DataSource> _Nullable dataSource = [DataSourceValue dataSourceWithData:encryptedLogData fileExtension:@"zip"];

        NSString *fileSize = [OWSFormat formatFileSize:dataSource.dataLength];
        OWSLogInfo(@"upload debuglog size:%@.", fileSize);
        
        if (![attachmentStream writeDataSource:dataSource]) {
            OWSProdError([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
            failureBlock([OWSAnalyticsEvents messageSenderErrorCouldNotWriteAttachment]);
        }
        
        //[attachmentStream save];
        
        OWSUploadOperation *uploadAttachmentOperation =
            [[OWSUploadOperation alloc] initWithAttachment:attachmentStream];
        
        [uploadAttachmentOperation uploadDebugLogRunSuccess:^{
            
            NSURL *locationURL = [NSURL URLWithString:uploadAttachmentOperation.location];
            NSString *keyString = [OWSProfileManager.sharedManager.localProfileKey.keyData base64EncodedString];
            
            NSDictionary *logInfoDict = @{@"is_logkey_info": @(YES),
                                          @"key": keyString?:@"",
                                          @"log_filepath": uploadAttachmentOperation.location?:@""};
            [self.cltlogAPI sendRequestWithEventName:@"debuglog"
                                              params:logInfoDict
                                             success:^(DTAPIMetaEntity * _Nonnull entity) {
                
                successBlock(locationURL);
                [OWSFileSystem deleteFileIfExists:logZipFilePath];
            } failure:^(NSError * _Nonnull error) {
                
                failureBlock(error.localizedDescription);
                [OWSFileSystem deleteFileIfExists:logZipFilePath];
            }];
        } uploadFailure:^(NSError * _Nonnull error) {
            
            failureBlock(error.localizedDescription);
            [OWSFileSystem deleteFileIfExists:logZipFilePath];
        }];
    });
}

#pragma mark - Profile Encryption

- (nullable NSData *)encryptData:(nullable NSData *)data
{
    return [self encryptProfileData:data profileKey:OWSProfileManager.sharedManager.localProfileKey];
}

- (nullable NSData *)encryptProfileData:(nullable NSData *)encryptedData profileKey:(SSKAES256Key *)profileKey
{
    OWSAssertDebug(profileKey.keyData.length == kAES256_KeyByteLength);

    if (!encryptedData) {
        return nil;
    }

    return [SSKCryptography encryptAESGCMWithData:encryptedData key:profileKey];
}

+ (void)uploadLogsWithSuccess:(nullable UploadDebugZipLogsSuccess)success failure:(nullable UploadDebugZipLogsFailure)failure
{
    OWSAssertDebug(success);

//    [[self sharedManager] uploadLogsWithSuccess:success
//                                        failure:^(NSString *localizedErrorMessage) {
//                                            [Pastelog showFailureAlertWithMessage:localizedErrorMessage];
//                                        }];
    
    [[self sharedManager] uploadZipLogFileSuccess:success
                                          failure:failure];
}

/*
- (void)uploadLogsWithSuccess:(nullable UploadDebugLogsSuccess)successParam failure:(UploadDebugLogsFailure)failureParam
{
    OWSAssertDebug(successParam);
    OWSAssertDebug(failureParam);

    // Ensure that we call the completions on the main thread.
    UploadDebugLogsSuccess success = ^(NSURL *url) {
        if (successParam) {
            DispatchMainThreadSafe(^{
                successParam(url);
            });
        }
    };
    UploadDebugLogsFailure failure = ^(NSString *localizedErrorMessage) {
        DispatchMainThreadSafe(^{
            failureParam(localizedErrorMessage);
        });
    };

    // Phase 1. Make a local copy of all of the log files.
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    [dateFormatter setDateFormat:@"yyyy.MM.dd hh.mm.ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate new]];
    NSString *logsName = [[dateString stringByAppendingString:@" "] stringByAppendingString:NSUUID.UUID.UUIDString];
    NSString *tempDirectory = NSTemporaryDirectory();
    NSString *zipFilePath =
        [tempDirectory stringByAppendingPathComponent:[logsName stringByAppendingPathExtension:@"zip"]];
    NSString *zipDirPath = [tempDirectory stringByAppendingPathComponent:logsName];
    [OWSFileSystem ensureDirectoryExists:zipDirPath];

    NSArray<NSString *> *logFilePaths = DebugLogger.shared.allLogFilePaths;
    if (logFilePaths.count < 1) {
        failure(Localized(@"DEBUG_LOG_ALERT_NO_LOGS", @"Error indicating that no debug logs could be found."));
        return;
    }

    for (NSString *logFilePath in logFilePaths) {
        NSString *copyFilePath = [zipDirPath stringByAppendingPathComponent:logFilePath.lastPathComponent];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:logFilePath toPath:copyFilePath error:&error];
        if (error) {
            failure(Localized(
                @"DEBUG_LOG_ALERT_COULD_NOT_COPY_LOGS", @"Error indicating that the debug logs could not be copied."));
            return;
        }
        [OWSFileSystem protectFileOrFolderAtPath:copyFilePath];
    }

    // Phase 2. Zip up the log files.
    BOOL zipSuccess = [SSZipArchive createZipFileAtPath:zipFilePath
                                withContentsOfDirectory:zipDirPath
                                    keepParentDirectory:YES
                                       compressionLevel:Z_DEFAULT_COMPRESSION
                                               password:nil
                                                    AES:NO
                                        progressHandler:nil];
    if (!zipSuccess) {
        failure(Localized(
            @"DEBUG_LOG_ALERT_COULD_NOT_PACKAGE_LOGS", @"Error indicating that the debug logs could not be packaged."));
        return;
    }

    [OWSFileSystem protectFileOrFolderAtPath:zipFilePath];
    [OWSFileSystem deleteFile:zipDirPath];

    // Phase 3. Upload the log files.

    @weakify(self);
    self.currentUploader = [DebugLogUploader new];
    [self.currentUploader uploadFileWithURL:[NSURL fileURLWithPath:zipFilePath]
                                   mimeType:OWSMimeTypeApplicationZip
                                    success:^(DebugLogUploader *uploader, NSURL *url) {
        @strongify(self);
        if (uploader != self.currentUploader) {
            // Ignore events from obsolete uploaders.
            return;
        }
        [OWSFileSystem deleteFile:zipFilePath];
        success(url);
    }
                                    failure:^(DebugLogUploader *uploader, NSError *error) {
        @strongify(self);
        if (uploader != self.currentUploader) {
            // Ignore events from obsolete uploaders.
            return;
        }
        [OWSFileSystem deleteFile:zipFilePath];
        failure(Localized(@"DEBUG_LOG_ALERT_ERROR_UPLOADING_LOG", @"Error indicating that a debug log could not be uploaded."));
    }];
}
 */

+ (void)showFailureAlertWithMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:Localized(@"DEBUG_LOG_ALERT_ERROR_UPLOADING_LOG",
                                     @"Title of the alert shown for failures while uploading debug logs.")
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:Localized(@"OK", @"")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    UIViewController *presentingViewController = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
    [presentingViewController presentViewController:alert animated:NO completion:nil];
}

#pragma mark Logs submission

- (void)submitEmail:(NSURL *)url
{
    NSString *emailAddress = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LOGS_EMAIL"];

    NSString *body = [NSString stringWithFormat:@"Log URL: %@ \n Tell us about the issue: ", url];
    NSString *escapedBody =
        [body stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *urlString =
        [NSString stringWithFormat:@"mailto:%@?subject=iOS%%20Debug%%20Log&body=%@", emailAddress, escapedBody];

    [UIApplication.sharedApplication openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:^(BOOL success) {
        
    }];
}

- (void)prepareRedirection:(NSURL *)url completion:(SubmitDebugLogsCompletion)completion
{
    OWSAssertDebug(completion);

    [DTSecurePasteboard setString:url.absoluteString];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:Localized(@"DEBUG_LOG_GITHUB_ISSUE_ALERT_TITLE",
                                                        @"Title of the alert before redirecting to GitHub Issues.")
                                            message:Localized(@"DEBUG_LOG_GITHUB_ISSUE_ALERT_MESSAGE",
                                                        @"Message of the alert before redirecting to GitHub Issues.")
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction
                      actionWithTitle:Localized(@"OK", @"")
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *action) {
        [UIApplication.sharedApplication
         openURL:[NSURL URLWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"LOGS_URL"]]
         options:@{}
         completionHandler:^(BOOL success) {
            completion();
        }];
    }]];
    UIViewController *presentingViewController = UIApplication.sharedApplication.frontmostViewControllerIgnoringAlerts;
    [presentingViewController presentViewController:alert animated:NO completion:nil];
}

- (void)sendToSelf:(NSURL *)url
{
    if (![TSAccountManager isRegistered]) {
        return;
    }
    NSString *recipientId = [TSAccountManager localNumber];
    OWSMessageSender *messageSender = Environment.shared.messageSender;

    DispatchMainThreadSafe(^{
        __block TSThread *thread = nil;
        
        DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            thread = [TSContactThread getOrCreateThreadWithContactId:recipientId transaction:transaction];
        });
        [ThreadUtil sendMessageWithText:url.absoluteString
                              atPersons:nil
                               mentions:nil
                               inThread:thread
                       quotedReplyModel:nil
                          messageSender:messageSender];
    });

    // Also copy to pasteboard.
    [DTSecurePasteboard setString:url.absoluteString];
}

- (void)sendToMostRecentThread:(NSURL *)url
{
    /*
    if (![TSAccountManager isRegistered]) {
        return;
    }

    __block TSThread *thread = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        thread = [[transaction ext:TSThreadDatabaseViewExtensionName] firstObjectInGroup:TSInboxGroup];
    }];
    DispatchMainThreadSafe(^{
        if (thread) {
            OWSMessageSender *messageSender = Environment.shared.messageSender;
            [ThreadUtil sendMessageWithText:url.absoluteString
                                  atPersons:nil
                                   mentions:nil
                                   inThread:thread
                           quotedReplyModel:nil
                              messageSender:messageSender];
        } else {
            [Pastelog showFailureAlertWithMessage:@"Could not find last thread."];
        }
    });

    // Also copy to pasteboard.
    [[UIPasteboard generalPasteboard] setString:url.absoluteString];
     */
}

- (DTCltlogAPI *)cltlogAPI{
    if(!_cltlogAPI){
        _cltlogAPI = [DTCltlogAPI new];
    }
    return _cltlogAPI;
}

@end

NS_ASSUME_NONNULL_END
