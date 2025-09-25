//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "TSRequest.h"
#import "TSAccountManager.h"
#import "TSConstants.h"
#import "DTParamsBaseUtils.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation TSRequest

@synthesize authUsername = _authUsername;
@synthesize authPassword = _authPassword;

- (id)initWithURL:(NSURL *)URL {
    OWSAssertDebug(URL);
    self = [super initWithURL:URL
                  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
              timeoutInterval:textSecureHTTPTimeOut];
    self.retryCount = HTTPRequestRetryCount;
    
    if (!self) {
        return nil;
    }

    _parameters = @{};
    self.shouldHaveAuthorizationHeaders = YES;

    return self;
}

- (instancetype)init
{
    OWSRaiseException(NSInternalInconsistencyException, @"You must use the initWithURL: method");
    return nil;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

- (instancetype)initWithURL:(NSURL *)URL
                cachePolicy:(NSURLRequestCachePolicy)cachePolicy
            timeoutInterval:(NSTimeInterval)timeoutInterval
{
    OWSRaiseException(NSInternalInconsistencyException, @"You must use the initWithURL method");
    return nil;
}

- (instancetype)initWithURL:(NSURL *)URL
                     method:(NSString *)method
                 parameters:(nullable NSDictionary<NSString *, id> *)parameters
{
    OWSAssertDebug(URL);
    OWSAssertDebug(method.length > 0);
//    OWSAssertDebug(parameters);

    self = [super initWithURL:URL
                  cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
              timeoutInterval:textSecureHTTPTimeOut];
    if (!self) {
        return nil;
    }

    _parameters = parameters ?: @{};
    [self setHTTPMethod:method];
    self.shouldHaveAuthorizationHeaders = YES;

    return self;
}

+ (instancetype)requestWithUrl:(NSURL *)url
                        method:(NSString *)method
                    parameters:(nullable NSDictionary<NSString *, id> *)parameters
{
    NSString *absoluteString = [url.absoluteString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *finalURL = [NSURL URLWithString:absoluteString];
    
    return [[TSRequest alloc] initWithURL:finalURL method:method parameters:parameters];
}

#pragma mark - Authorization

- (void)setAuthUsername:(nullable NSString *)authUsername
{
    OWSAssertDebug(self.shouldHaveAuthorizationHeaders);
    
    @synchronized(self) {
        _authUsername = authUsername;
    }
}

- (void)setAuthPassword:(nullable NSString *)authPassword
{
    OWSAssertDebug(self.shouldHaveAuthorizationHeaders);
    
    @synchronized(self) {
        _authPassword = authPassword;
    }
}

- (nullable NSString *)authUsername
{
    OWSAssertDebug(self.shouldHaveAuthorizationHeaders);
    
    @synchronized(self) {
        NSString *_Nullable result = (_authUsername ?: self.tsAccountManager.localNumber);
        if (result.length < 1) {
            OWSLogVerbose(@"%@", self.debugDescription);
        }
//        OWSAssertDebug(result.length > 0);
        return result;
    }
}

- (nullable NSString *)authPassword
{
    OWSAssertDebug(self.shouldHaveAuthorizationHeaders);
    
    @synchronized(self) {
        NSString *_Nullable result = (_authPassword ?: self.tsAccountManager.serverAuthToken);
        if (result.length < 1) {
            OWSLogVerbose(@"%@", self.debugDescription);
        }
//        OWSAssertDebug(result.length > 0);
        return result;
    }
}

- (NSString *)description {
    if (self.shouldRedactUrlInLogs) {
        return [NSString stringWithFormat:@"{ %@: [REDACTED] }", self.HTTPMethod];
    } else {
        return [NSString stringWithFormat:@"{ %@: %@ }", self.HTTPMethod, self.URL];
    }
}


@end
