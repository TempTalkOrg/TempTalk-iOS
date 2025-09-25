//
//  DTFileDownloader.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import "DTFileDownloader.h"
#import "AFHTTPSessionManager.h"
#import "OWSError.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTFileDownloader ()

@property (nonatomic, strong) AFHTTPSessionManager *manager;

@end

@implementation DTFileDownloader

+ (instancetype)defaultDownloader{
    static DTFileDownloader *_defaultDownloader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _defaultDownloader = [DTFileDownloader new];
    });
    
    return _defaultDownloader;
}

- (instancetype)init{
    if(self = [super init]){
        self.manager = [AFHTTPSessionManager manager];
        _manager.requestSerializer     = [AFHTTPRequestSerializer serializer];

        // modified: remove header "Content-Type", because some oss storage do not support this header
        //           and add new header: "Accept: */*"
        //[manager.requestSerializer setValue:OWSMimeTypeApplicationOctetStream forHTTPHeaderField:@"Content-Type"];
        [_manager.requestSerializer setValue:@"*/*" forHTTPHeaderField:@"Accept"];
        [_manager.requestSerializer setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _manager.completionQueue    = dispatch_get_main_queue();
    }
    return self;
}

- (void)downloadFileWithUrl:(NSString *)url success:(void (^)(NSData * _Nonnull))successHandler failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failureHandler{
    __block NSURLSessionDataTask *task = nil;
    __block BOOL hasCheckedContentLength = NO;
    const long kMaxDownloadSize = 200 * 1024 * 1024; // 150->200
    task = [_manager GET:url
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

            if (progress.totalUnitCount > OWSMediaUtils.kMaxFileSizeGeneric || progress.completedUnitCount > kMaxDownloadSize) {
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
            
            // 取消验证 contentLength，阿里云服务器返回的没有这个字段
//            NSString *contentLength = headers[@"Content-Length"];
//            if (![contentLength isKindOfClass:[NSString class]]) {
//                DDLogError(@"%@ Attachment download missing or invalid content length.", self.logTag);
//                abortDownload();
//                return;
//            }
//
//
//            if (contentLength.longLongValue > kMaxDownloadSize) {
//                DDLogError(@"%@ Attachment download content length exceeds max download size.", self.logTag);
//                abortDownload();
//                return;
//            }
            
            // This response has a valid content length that is less
            // than our max download size.  Proceed with the download.
            hasCheckedContentLength = YES;
        }
        success:^(NSURLSessionDataTask *_Nonnull task, id _Nullable responseObject) {
            if (![responseObject isKindOfClass:[NSData class]]) {
                DDLogError(@"%@ Failed retrieval of attachment. Response had unexpected format.", self.logTag);
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(task, error);
            }
            successHandler((NSData *)responseObject);
        }
        failure:^(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error) {
            DDLogError(@"Failed to retrieve attachment with error: %@", error.description);
            return failureHandler(task, error);
        }];
}

@end
