//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAnalytics.h"
#import "AppContext.h"
#import "OWSBackgroundTask.h"
//
#import "OWSQueues.h"
#import <CocoaLumberjack/CocoaLumberjack.h>
#import <Reachability/Reachability.h>
//
#import "DTCltlogAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "AppReadiness.h"

NS_ASSUME_NONNULL_BEGIN

#ifdef DEBUG

// TODO: Disable analytics for debug builds.
//#define NO_SIGNAL_ANALYTICS

#endif

NSString *const kOWSAnalytics_EventsCollection = @"kOWSAnalytics_EventsCollection";

// Percentage of analytics events to discard. 0 <= x <= 100.
const int kOWSAnalytics_DiscardFrequency = 0;

NSString *NSStringForOWSAnalyticsSeverity(OWSAnalyticsSeverity severity)
{
    switch (severity) {
        case OWSAnalyticsSeverityInfo:
            return @"Info";
        case OWSAnalyticsSeverityError:
            return @"Error";
        case OWSAnalyticsSeverityCritical:
            return @"Critical";
    }
}

@interface OWSAnalytics ()

@property (nonatomic, readonly) Reachability *reachability;

@property (atomic) BOOL hasRequestInFlight;

@property (nonatomic, strong) DTCltlogAPI *cltlogAPI;


@end

#pragma mark -

@implementation OWSAnalytics

- (DTCltlogAPI *)cltlogAPI{
    if(!_cltlogAPI){
        _cltlogAPI = [DTCltlogAPI new];
    }
    return _cltlogAPI;
}

+ (instancetype)sharedInstance
{
    static OWSAnalytics *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initDefault];
    });
    return instance;
}

- (instancetype)initDefault
{
    self = [super init];

    if (!self) {
        return self;
    }

    _reachability = [Reachability reachabilityForInternetConnection];
    
    _keyValueStore = [[SDSKeyValueStore alloc] initWithCollection:kOWSAnalytics_EventsCollection];

    [self observeNotifications];

    OWSSingletonAssert();

    return self;
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reachabilityChanged
{
    OWSAssertIsOnMainThread();
    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
        [self tryToSyncEvents];
    });
}

- (void)applicationDidBecomeActive
{
    OWSAssertIsOnMainThread();
    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
        [self tryToSyncEvents];
    });
}

- (void)tryToSyncEvents
{
    dispatch_async(self.serialQueue, ^{
        // Don't try to sync if:
        //
        // * There's no network available.
        // * There's already a sync request in flight.
        if (!self.reachability.isReachable) {
            DDLogVerbose(@"%@ Not reachable", self.logTag);
            return;
        }
        if (self.hasRequestInFlight) {
            return;
        }
        
        if (!TSAccountManager.isRegistered) {
            return;
        }

        __block NSString *firstEventKey = nil;
        __block NSDictionary *firstEventDictionary = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *readTransaction) {
            // Take any event. We don't need to deliver them in any particular order.
            [self.keyValueStore enumerateKeysWithTransaction:readTransaction
                                                       block:^(NSString * key, BOOL * stop) {
                firstEventKey = key;
                *stop = YES;
            }];
            if (!firstEventKey) {
                return;
            }
            
            firstEventDictionary = [self.keyValueStore getObjectForKey:firstEventKey transaction:readTransaction];
            OWSAssertDebug(firstEventDictionary);
            OWSAssertDebug([firstEventDictionary isKindOfClass:[NSDictionary class]]);
        }];

        if (firstEventDictionary) {
            [self sendEvent:firstEventDictionary eventKey:firstEventKey isCritical:NO];
        }
    });
}

- (void)sendEvent:(NSDictionary *)eventDictionary eventKey:(NSString *)eventKey isCritical:(BOOL)isCritical
{
    OWSAssertDebug(eventDictionary);
    OWSAssertDebug(eventKey);
    AssertOnDispatchQueue(self.serialQueue);

    if (isCritical) {
        [self submitEvent:eventDictionary
            eventKey:eventKey
            success:^{
                DDLogDebug(@"%@ sendEvent[critical] succeeded: %@", self.logTag, eventKey);
            }
            failure:^{
                DDLogError(@"%@ sendEvent[critical] failed: %@", self.logTag, eventKey);
            }];
    } else {
        self.hasRequestInFlight = YES;
        __block BOOL isComplete = NO;
        [self submitEvent:eventDictionary
            eventKey:eventKey
            success:^{
                if (isComplete) {
                    return;
                }
                isComplete = YES;
                DDLogDebug(@"%@ sendEvent succeeded: %@", self.logTag, eventKey);
                dispatch_async(self.serialQueue, ^{
                    self.hasRequestInFlight = NO;

                    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                        // Remove from queue.
                        [self.keyValueStore removeValueForKey:eventKey transaction:writeTransaction];
                    });

                    // Wait a second between network requests / retries.
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self tryToSyncEvents];
                        });
                });
            }
            failure:^{
                if (isComplete) {
                    return;
                }
                isComplete = YES;
                DDLogError(@"%@ sendEvent failed: %@", self.logTag, eventKey);
                dispatch_async(self.serialQueue, ^{
                    self.hasRequestInFlight = NO;

                    // Wait a second between network requests / retries.
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self tryToSyncEvents];
                        });
                });
            }];
    }
}

- (void)submitEvent:(NSDictionary *)eventDictionary
           eventKey:(NSString *)eventKey
            success:(void (^_Nonnull)(void))successBlock
            failure:(void (^_Nonnull)(void))failureBlock
{
    OWSAssertDebug(eventDictionary);
    OWSAssertDebug(eventKey);
    AssertOnDispatchQueue(self.serialQueue);

    OWSLogInfo(@"%@ submitting: %@", self.logTag, eventKey);

//    __block OWSBackgroundTask *backgroundTask =
//        [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__
//                                      completionBlock:^(BackgroundTaskState backgroundTaskState) {
//                                          if (backgroundTaskState == BackgroundTaskState_Success) {
//                                              successBlock();
//                                          } else {
//                                              failureBlock();
//                                          }
//                                      }];

    // Until we integrate with an analytics platform, behave as though all event delivery succeeds.
//    dispatch_async(self.serialQueue, ^{
//        backgroundTask = nil;
//    });
    
    __block OWSBackgroundTask *_Nullable backgroundTask = [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];
    
    AppReadinessRunNowOrWhenAppDidBecomeReadyAsync(^{
        [self.cltlogAPI sendRequestWithEventName:eventKey
                                          params:eventDictionary
                                         success:^(DTAPIMetaEntity * _Nonnull entity) {
            !successBlock ? : successBlock();
            backgroundTask = nil;
        } failure:^(NSError * _Nonnull error) {
            !failureBlock ? : failureBlock();
            backgroundTask = nil;
        }];
    });
}

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("org.whispersystems.analytics.serial", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

- (NSString *)operatingSystemVersionString
{
    static NSString *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion operatingSystemVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
        result = [NSString stringWithFormat:@"%zd.%zd.%zd",
                           (NSUInteger)operatingSystemVersion.majorVersion,
                           (NSUInteger)operatingSystemVersion.minorVersion,
                           (NSUInteger)operatingSystemVersion.patchVersion];
    });
    return result;
}

- (NSDictionary<NSString *, id> *)eventSuperProperties
{
    NSMutableDictionary<NSString *, id> *result = [NSMutableDictionary new];
    result[@"app_version"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    result[@"app_build"] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    result[@"platform"] = @"ios";
    result[@"ios_version"] = self.operatingSystemVersionString;
    return result;
}

- (long)orderOfMagnitudeOf:(long)value
{
    return [OWSAnalytics orderOfMagnitudeOf:value];
}

+ (long)orderOfMagnitudeOf:(long)value
{
    if (value <= 0) {
        return 0;
    }
    return (long)round(pow(10, floor(log10(value))));
}

- (void)addEvent:(NSString *)eventName severity:(OWSAnalyticsSeverity)severity properties:(NSDictionary *)properties
{
    OWSAssertDebug(eventName.length > 0);
    OWSAssertDebug(properties);

#ifndef NO_SIGNAL_ANALYTICS
    BOOL isError = severity == OWSAnalyticsSeverityError;
    BOOL isCritical = severity == OWSAnalyticsSeverityCritical;

    uint32_t discardValue = arc4random_uniform(101);
    if (!isError && !isCritical && discardValue < kOWSAnalytics_DiscardFrequency) {
        DDLogVerbose(@"Discarding event: %@", eventName);
        return;
    }
    
    if(severity == OWSAnalyticsSeverityInfo){
        return;
    }

    void (^addEvent)(void) = ^{
        // Add super properties.
        NSMutableDictionary *eventProperties = (properties ? [properties mutableCopy] : [NSMutableDictionary new]);
        [eventProperties addEntriesFromDictionary:self.eventSuperProperties];

        NSDictionary *eventDictionary = [eventProperties copy];
        OWSAssertDebug(eventDictionary);
        NSString *eventKey = [NSUUID UUID].UUIDString;
        DDLogDebug(@"%@ enqueuing event: %@", self.logTag, eventKey);

        if (isCritical) {
            // Critical events should not be serialized or enqueued - they should be submitted immediately.
            [self sendEvent:eventDictionary eventKey:eventName isCritical:YES];
        } else {
            // Add to queue. modify by felix, try to use async to avoid thread deadlock
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                
                const int kMaxQueuedEvents = 5000;
                if ([self.keyValueStore numberOfKeysWithTransaction:writeTransaction] > kMaxQueuedEvents) {
                    DDLogError(@"%@ Event queue overflow.", self.logTag);
                    return;
                }

                [self.keyValueStore setObject:eventDictionary key:eventName transaction:writeTransaction];
                
                [writeTransaction addAsyncCompletionOnMain:^{
                    if (CurrentAppContext().isMainAppAndActive) {
                        [self tryToSyncEvents];
                    }
                }];
                
            });
        }
    };

//    if ([self shouldReportAsync:severity]) {
        dispatch_async(self.serialQueue, addEvent);
//    } else {
//        dispatch_sync(self.serialQueue, addEvent);
//    }
#endif
}

+ (void)logEvent:(NSString *)eventName
        severity:(OWSAnalyticsSeverity)severity
      parameters:(nullable NSDictionary *)parameters
        location:(const char *)location
            line:(int)line
{
    [[self sharedInstance] logEvent:eventName severity:severity parameters:parameters location:location line:line];
}

- (void)logEvent:(NSString *)eventName
        severity:(OWSAnalyticsSeverity)severity
      parameters:(nullable NSDictionary *)parameters
        location:(const char *)location
            line:(int)line
{
    DDLogFlag logFlag;
    switch (severity) {
        case OWSAnalyticsSeverityInfo:
            logFlag = DDLogFlagInfo;
            break;
        case OWSAnalyticsSeverityError:
            logFlag = DDLogFlagError;
            break;
        case OWSAnalyticsSeverityCritical:
            logFlag = DDLogFlagError;
            break;
        default:
            OWSFailDebug(@"Unknown severity.");
            logFlag = DDLogFlagDebug;
            break;
    }

    // Log the event.
    NSString *logString = [NSString stringWithFormat:@"%s:%d %@", location, line, eventName];
    if (!parameters) {
        LOG_MAYBE([self shouldReportAsync:severity], LOG_LEVEL_DEF, logFlag, 0, nil, location, @"%@", logString);
    } else {
        LOG_MAYBE([self shouldReportAsync:severity],
            LOG_LEVEL_DEF,
            logFlag,
            0,
            nil,
            location,
            @"%@ %@",
            logString,
            parameters);
    }
    if (![self shouldReportAsync:severity]) {
        [DDLog flushLog];
    }

    NSMutableDictionary *eventProperties = (parameters ? [parameters mutableCopy] : [NSMutableDictionary new]);
    eventProperties[@"event_location"] = [NSString stringWithFormat:@"%s:%d", location, line];
    
    if (CurrentAppContext().isNSE && severity == OWSAnalyticsSeverityCritical) {
        severity = OWSAnalyticsSeverityError;
    }
    [self addEvent:eventName severity:severity properties:eventProperties];
}

- (BOOL)shouldReportAsync:(OWSAnalyticsSeverity)severity
{
    return severity != OWSAnalyticsSeverityCritical;
}

#pragma mark - Logging

+ (void)appLaunchDidBegin
{
    [self.sharedInstance appLaunchDidBegin];
}

- (void)appLaunchDidBegin
{
    OWSProdInfo([OWSAnalyticsEvents appLaunch]);
}

#pragma mark - app

+ (void)reportAppStatus:(NSDictionary *)appData
                success:(void (^_Nonnull)(void))successBlock
                failure:(void (^_Nonnull)(void))failureBlock {
    [self.sharedInstance reportAppStatus:appData success:successBlock failure:failureBlock];
}

- (void)reportAppStatus:(NSDictionary *)appData
                success:(void (^_Nonnull)(void))successBlock
                failure:(void (^_Nonnull)(void))failureBlock {
    dispatch_async(self.serialQueue, ^{
        NSString *eventKey = OWSAnalyticsEvents.appStatusAnalytics;
        [self submitEvent:appData eventKey:eventKey success:^{
            !successBlock ?:successBlock();
        } failure:^{
            !failureBlock ?:failureBlock();
        }];
    });
}

@end

NS_ASSUME_NONNULL_END
