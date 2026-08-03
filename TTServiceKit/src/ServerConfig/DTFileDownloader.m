//
//  DTFileDownloader.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import "DTFileDownloader.h"
#import "OWSError.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTFileDownloader ()

// atomic: refreshDownloadSession may reassign this from a background self-heal queue while a
// download reads it on another queue — atomic keeps the pointer read/write from tearing.
@property (atomic, strong) OWSURLSession *downloadSession;

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
        self.downloadSession = OWSSignalService.sharedInstance.urlSessionForNoneService;
    }
    return self;
}

- (void)refreshDownloadSession{
    // Swap in a session built with the current proxy routing so future downloads take the new
    // route. A download already in flight keeps the old session alive (its URLSession delegate
    // self-retains until the task finishes) and completes/fails on the old route — only the next
    // download picks up the change. That's enough: the bug being fixed is future calls stranded
    // on a dead loopback port, which this clears without an app restart.
    self.downloadSession = OWSSignalService.sharedInstance.urlSessionForNoneService;
    OWSLogInfo(@"[Proxy] download session rebuilt for current routing");
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

- (void)downloadFileWithUrl:(NSString *)location
                    success:(void (^)(NSData * _Nonnull))successHandler
                    failure:(void (^)(NSError * _Nonnull))failureHandler{
    [self downloadFileWithUrls:location ? @[location] : @[]
                      progress:nil
                       success:successHandler
                       failure:failureHandler];
}

- (void)downloadFileWithUrls:(NSArray<NSString *> *)locations
                     progress:(nullable DTFileDownloadProgressBlock)progressHandler
                      success:(void (^)(NSData * _Nonnull))successHandler
                      failure:(void (^)(NSError * _Nonnull))failureHandler{
    // Use urls array if available, otherwise fallback to single location
    if (!locations || locations.count == 0) {
        OWSLogError(@"%@ No download URLs provided", self.logTag);
        NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
        return failureHandler(error);
    }

    __block NSMutableArray *urlErrors = [NSMutableArray array];

    [self attemptDownloadWithUrls:locations
                         urlIndex:0
                        urlErrors:urlErrors
                         progress:progressHandler
                          success:successHandler
                          failure:failureHandler];
}

- (void)attemptDownloadWithUrls:(NSArray<NSString *> *)locations
                       urlIndex:(NSUInteger)urlIndex
                      urlErrors:(NSMutableArray *)urlErrors
                       progress:(nullable DTFileDownloadProgressBlock)progressHandler
                        success:(void (^)(NSData * _Nonnull))successHandler
                        failure:(void (^)(NSError * _Nonnull))failureHandler{

    if (urlIndex >= locations.count) {
        // Log all accumulated errors for debugging
        OWSLogError(@"%@ All download URLs failed. Errors:", self.logTag);
        for (NSUInteger i = 0; i < urlErrors.count; i++) {
            OWSLogError(@"  URL %lu: %@", (unsigned long)(i + 1), urlErrors[i]);
        }
        
        NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
        return failureHandler(error);
    }

    NSString *location = locations[urlIndex];

    // Validate URL is HTTPS for security
    if (![self isSecureURL:location]) {
        NSError *urlError = [NSError errorWithDomain:@"DTFileDownloader"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Non-HTTPS URL rejected"}];
        [urlErrors addObject:urlError];

        OWSLogError(@"%@ Rejecting non-HTTPS URL %lu: %@", self.logTag, (unsigned long)(urlIndex + 1), location);
        [self attemptDownloadWithUrls:locations
                             urlIndex:urlIndex + 1
                            urlErrors:urlErrors
                             progress:progressHandler
                              success:successHandler
                              failure:failureHandler];
        return;
    }

    OWSLogInfo(@"%@ Attempting download from URL %lu/%lu: %@", self.logTag, (unsigned long)(urlIndex + 1), (unsigned long)locations.count, location);

    NSURL *url = [NSURL URLWithString:location];
    TSRequest *request = [TSRequest requestWithUrl:url method:@"GET" parameters:nil];

    __weak typeof(self) weakSelf = self;
    [self.downloadSession performDownloadRequest:request success:^(OWSUrlDownloadResponse * _Nonnull response) {

        NSData *responseData = [NSData dataWithContentsOfURL:response.downloadUrl];

        if (![responseData isKindOfClass:[NSData class]]) {
            NSError *responseError = [NSError errorWithDomain:@"DTFileDownloader"
                                                          code:1002
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Invalid response format"}];
            [urlErrors addObject:responseError];

            OWSLogError(@"%@ URL %lu failed: Invalid response format", weakSelf.logTag, (unsigned long)(urlIndex + 1));

            [weakSelf attemptDownloadWithUrls:locations
                                     urlIndex:urlIndex + 1
                                    urlErrors:urlErrors
                                     progress:progressHandler
                                      success:successHandler
                                      failure:failureHandler];
            return;
        }

        OWSLogInfo(@"%@ Successfully downloaded from URL %lu", weakSelf.logTag, (unsigned long)(urlIndex + 1));
        
        successHandler(responseData);
    } progress:^(NSURLSessionTask * _Nonnull task, NSProgress * _Nonnull progress) {
        // Don't do anything until we've received at least one byte of data.
        if (progress.completedUnitCount < 1) {
            return;
        }

        // Call the progress handler if provided
        // The handler is responsible for:
        // - Progress notifications
        // - Size limit enforcement
        // - Content-Length validation
        // - Aborting downloads when necessary
        if (progressHandler) {
            progressHandler(task, progress);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        [urlErrors addObject:error];

        OWSLogError(@"%@ URL %lu: Failed to retrieve attachment with error: %@", weakSelf.logTag, (unsigned long)(urlIndex + 1), error.description);

        [weakSelf attemptDownloadWithUrls:locations
                                 urlIndex:urlIndex + 1
                                urlErrors:urlErrors
                                 progress:progressHandler
                                  success:successHandler
                                  failure:failureHandler];
    }];
}

@end
