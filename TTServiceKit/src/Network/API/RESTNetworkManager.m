//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "RESTNetworkManager.h"
#import "OWSQueues.h"
#import "TSRequest.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <SignalCoreKit/NSDate+OWS.h>

NS_ASSUME_NONNULL_BEGIN

// Session managers are stateful (e.g. the headers in the requestSerializer).
// Concurrent requests can interfere with each other. Therefore we use a pool
// do not re-use a session manager until its request succeeds or fails.
@interface OWSSessionManagerPool : NSObject

@property (nonatomic) NSMutableArray<RESTSessionManager *> *pool;
@property (atomic, nullable) NSDate *lastDiscardDate;

@end

#pragma mark -

@implementation OWSSessionManagerPool

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    self.pool = [NSMutableArray new];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(isCensorshipCircumventionActiveDidChange)
                                               name:NSNotificationNameIsCensorshipCircumventionActiveDidChange
                                             object:nil];

    // Proxy on/off/address change: pooled sessions froze the proxy dict at build time, so discard
    // them at once (otherwise a stale proxy route lingers until the 5-min TTL expires).
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(proxyConfigurationDidChange)
                                               name:ProxyManager.proxyConfigurationDidChangeNotificationName
                                             object:nil];

    return self;
}

- (void)isCensorshipCircumventionActiveDidChange
{
    OWSAssertIsOnMainThread();

    self.lastDiscardDate = [NSDate new];
}

- (void)proxyConfigurationDidChange
{
    OWSAssertIsOnMainThread();

    self.lastDiscardDate = [NSDate new];
    OWSLogInfo(@"[Proxy] REST session pool discarded (proxy changed)");
}

- (RESTSessionManager *)get
{
    AssertOnDispatchQueue(NetworkManagerQueue());

    // Iterate over the pool, discarding expired session managers
    // until we find a unexpired session manager in the pool or
    // drain the pool and create a new session manager.
    while (YES) {
        RESTSessionManager *_Nullable sessionManager = [self.pool lastObject];
        if (sessionManager == nil) {
            // Pool is drained; make a new session manager.
            return [RESTSessionManager new];
        }
        OWSAssertDebug(sessionManager != nil);
        [self.pool removeLastObject];
        if ([self shouldDiscardSessionManager:sessionManager]) {
            // Discard.
            continue;
        }
        return sessionManager;
    }
}

- (void)returnToPool:(RESTSessionManager *)sessionManager
{
    AssertOnDispatchQueue(NetworkManagerQueue());
    
    OWSAssertDebug(sessionManager);
    const NSUInteger kMaxPoolSize = CurrentAppContext().isNSE ? 5 : 32;
    if (self.pool.count >= kMaxPoolSize || [self shouldDiscardSessionManager:sessionManager]) {
        // Discard.
        return;
    }
    [self.pool addObject:sessionManager];
}

- (BOOL)shouldDiscardSessionManager:(RESTSessionManager *)sessionManager
{
    NSDate *_Nullable lastDiscardDate = self.lastDiscardDate;
    if (lastDiscardDate != nil &&
        [lastDiscardDate isAfterDate:sessionManager.createdDate]) {
        return YES;
    }
    return fabs(sessionManager.createdDate.timeIntervalSinceNow) > self.maxSessionManagerAge;
}

- (NSTimeInterval)maxSessionManagerAge
{
    // Throw away session managers every 5 minutes.
    return 5 * kMinuteInterval;
}

@end

#pragma mark -

@interface RESTNetworkManager ()

// These properties should only be accessed on serialQueue.
@property (atomic, readonly) OWSSessionManagerPool *udSessionManagerPool;
@property (atomic, readonly) OWSSessionManagerPool *nonUdSessionManagerPool;

@end

#pragma mark -

@implementation RESTNetworkManager

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _udSessionManagerPool = [OWSSessionManagerPool new];
    _nonUdSessionManagerPool = [OWSSessionManagerPool new];
    
    OWSSingletonAssert();
    
    return self;
}

#pragma mark Manager Methods

- (void)makeRequest:(TSRequest *)request
    completionQueue:(dispatch_queue_t)completionQueue
            success:(RESTNetworkManagerSuccess)success
            failure:(RESTNetworkManagerFailure)failure
{
    OWSAssertDebug(request);
    OWSAssertDebug(success);
    OWSAssertDebug(failure);
    
    dispatch_async(NetworkManagerQueue(), ^{
        [self makeRequestSync:request completionQueue:completionQueue success:success failure:failure];
    });
}

- (void)makeRequestSync:(TSRequest *)request
        completionQueue:(dispatch_queue_t)completionQueue
                success:(RESTNetworkManagerSuccess)successParam
                failure:(RESTNetworkManagerFailure)failureParam
{
    OWSAssertDebug(request);
    OWSAssertDebug(successParam);
    OWSAssertDebug(failureParam);
    
    BOOL isUDRequest = request.isUDRequest;
    NSString *label = (isUDRequest ? @"UD request" : @"Non-UD request");
    if (isUDRequest) {
        OWSAssert(!request.shouldHaveAuthorizationHeaders);
    }
    OWSLogInfo(@"Making %@: %@", label, request);
    
    OWSSessionManagerPool *sessionManagerPool
    = (isUDRequest ? self.udSessionManagerPool : self.nonUdSessionManagerPool);
    RESTSessionManager *sessionManager = [sessionManagerPool get];
    
    RESTNetworkManagerSuccess success = ^(id<HTTPResponse> response) {
#if TESTABLE_BUILD
//        if (SSKDebugFlags.logCurlOnSuccess) {
            [HTTPUtils logCurlForURLRequest:request];
//        }
#endif
        dispatch_async(NetworkManagerQueue(), ^{
            [sessionManagerPool returnToPool:sessionManager];
        });

        dispatch_async(completionQueue, ^{
//            OWSLogInfo(@"%@ succeeded (%ld) : %@", label, response.responseStatusCode, request);

            if (request.canUseAuth && request.shouldHaveAuthorizationHeaders) {
                [RESTNetworkManager.tsAccountManager setIsDeregistered:NO];
            }

            // Record LastHost on successful main-service HTTP (complements WS tracking)
            NSString *successHost = sessionManager.baseUrlHost;
            if (successHost.length > 0 &&
                [[DTServerUrlManager sharedManager] containsHost:successHost serverType:DTServToTypeChat]) {
                [[DTLastSuccessfulHostManager shared] saveLastSuccessfulHost:successHost
                                                                 serverType:DTServToTypeChat];
            }

            successParam(response);
            
            [OutageDetection.shared reportConnectionSuccess];
        });
    };
    RESTNetworkManagerFailure failure = ^(OWSHTTPErrorWrapper *errorWrapper) {
        dispatch_async(NetworkManagerQueue(), ^{
            [sessionManagerPool returnToPool:sessionManager];
        });

        [RESTNetworkManager
            handleNetworkFailure:^(OWSHTTPErrorWrapper *errorWrapper) {
                dispatch_async(completionQueue, ^{
                    
                    // Switch domain on abnormal status (<100 or >=500, incl. 0 = no response).
                    // Only act if the failed host belongs to the chat pool.
                    NSString *failedHost = sessionManager.baseUrlHost;
                    NSInteger statusCode = errorWrapper.asNSError.httpStatusCode.integerValue;
                    BOOL shouldSwitchDomain = (statusCode < 100 || statusCode >= 500);
                    if (shouldSwitchDomain &&
                        [[DTServerUrlManager sharedManager] containsHost:failedHost serverType:DTServToTypeChat]) {

                        [[DTServerUrlManager sharedManager] markAsInvalidWithUrl:failedHost serverType:DTServToTypeChat];

                        NSArray *serverUrls = [[DTServerUrlManager sharedManager] getTheServerUrlsWithServerType:DTServToTypeChat];
                        if (serverUrls.count) {
                            TSConstants.mainServiceHost = serverUrls.firstObject;
                            OWSLogInfo(@"[DomainSwitch] HTTP switch from %@ to %@ (status: %ld)", failedHost, serverUrls.firstObject, (long)statusCode);
                        }
                    }
                    
                    // force upgrade
                    if (errorWrapper.asNSError.httpStatusCode.integerValue == 450) {
                        [[ATAppUpdater sharedUpdater] showForceUpdateWithoutVerifyVersion];
                    }
                    
                    failureParam(errorWrapper);
                });
            }
                         request:request
                    errorWrapper:errorWrapper];
    };
    
    [sessionManager performRequest:request
                           success:success
                           failure:failure];
}

+ (void)handleNetworkFailure:(RESTNetworkManagerFailure)failureBlock
                     request:(TSRequest *)request
                errorWrapper:(OWSHTTPErrorWrapper *)errorWrapper
{
    OWSAssertDebug(failureBlock);
    OWSAssertDebug(request);
    OWSAssertDebug(errorWrapper);
    
    failureBlock(errorWrapper);
}

@end

NS_ASSUME_NONNULL_END
