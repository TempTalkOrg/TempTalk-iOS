//
//  DTFileDownloader.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFileDownloader : NSObject

+ (instancetype)defaultDownloader;

- (void)downloadFileWithUrl:(NSString *)url
                     success:(void (^)(NSData *data))successHandler
                    failure:(void (^)(NSURLSessionDataTask *_Nullable task, NSError *_Nonnull error))failureHandler;

@end

NS_ASSUME_NONNULL_END
