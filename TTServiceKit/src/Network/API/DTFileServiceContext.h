//
//  DTFileServiceContext.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFileServiceContext : NSObject

@property (nonatomic, copy) NSString *authToken;

+ (instancetype)sharedInstance;

- (void)fetchAuthTokenWithSuccess:(void(^)(NSString *token))success
                          failure:(void(^)(NSError * _Nullable error))failure;

@end

NS_ASSUME_NONNULL_END
