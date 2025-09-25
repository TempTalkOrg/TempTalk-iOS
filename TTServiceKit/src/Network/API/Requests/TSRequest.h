//
//  Copyright (c) 2022 wea Systems. All rights reserved.
//

#import "TSConstants.h"
NS_ASSUME_NONNULL_BEGIN

@interface TSRequest : NSMutableURLRequest

@property (nonatomic) BOOL useResponseBodyJson;
@property (nonatomic) BOOL isUDRequest;
@property (nonatomic) BOOL shouldHaveAuthorizationHeaders;
@property (nonatomic) BOOL shouldRedactUrlInLogs;
@property (nonatomic) NSUInteger retryCount;

@property (nonatomic) NSDictionary *parameters;
// TODO: refactor Network
@property (atomic, nullable) NSString *authUsername;
@property (atomic, nullable) NSString *authPassword;
@property (nonatomic, copy, nullable) NSString *authToken;

@property (nonatomic, strong) NSSet <NSString *> *HTTPMethodsEncodingParametersInURI;
@property (nonatomic, strong) NSMutableArray *availableUrls;

@property (nonatomic, assign) DTServerType serverType;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)URL;

- (instancetype)initWithURL:(NSURL *)URL
                cachePolicy:(NSURLRequestCachePolicy)cachePolicy
            timeoutInterval:(NSTimeInterval)timeoutInterval NS_UNAVAILABLE;

- (instancetype)initWithURL:(NSURL *)URL
                     method:(NSString *)method
                 parameters:(nullable NSDictionary<NSString *, id> *)parameters;

+ (instancetype)requestWithUrl:(NSURL *)url
                        method:(NSString *)method
                    parameters:(nullable NSDictionary<NSString *, id> *)parameters;

@end

NS_ASSUME_NONNULL_END
