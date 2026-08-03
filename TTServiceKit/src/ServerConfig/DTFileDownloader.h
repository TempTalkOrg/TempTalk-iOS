//
//  DTFileDownloader.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Progress callback for streaming downloads. Invoked once after the first
/// byte of data is received and again on each subsequent chunk. Caller may
/// inspect `task.response` for headers and call `[task cancel]` to abort.
typedef void (^DTFileDownloadProgressBlock)(NSURLSessionTask * _Nonnull task, NSProgress * _Nonnull progress);

@interface DTFileDownloader : NSObject

+ (instancetype)defaultDownloader;

/// Single-URL download convenience. Calls `downloadFileWithUrls:` internally.
- (void)downloadFileWithUrl:(NSString *)url
                     success:(void (^)(NSData *data))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

/// Multi-URL sequential fallback download. URLs are tried in order until one
/// succeeds; each non-HTTPS URL is rejected. Optional `progressHandler` is
/// invoked from a delegate queue once data starts flowing.
- (void)downloadFileWithUrls:(NSArray<NSString *> *)urls
                     progress:(nullable DTFileDownloadProgressBlock)progressHandler
                      success:(void (^)(NSData *data))successHandler
                      failure:(void (^)(NSError *error))failureHandler;

/// Rebuild the download session so it adopts the current self-hosted proxy routing.
/// The session freezes its `connectionProxyDictionary` when the underlying URLSession is
/// created, so toggling the proxy leaves the cached session routing to the stopped local
/// proxy port — call this on any proxy change, otherwise only an app restart recovers it.
- (void)refreshDownloadSession;

@end

NS_ASSUME_NONNULL_END
