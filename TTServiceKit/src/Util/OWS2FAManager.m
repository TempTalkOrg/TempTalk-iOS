//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWS2FAManager.h"
#import "NSNotificationCenter+OWS.h"
#import "OWSRequestFactory.h"
//
//
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const NSNotificationName_2FAStateDidChange = @"NSNotificationName_2FAStateDidChange";

NSString *const kOWS2FAManager_Collection = @"kOWS2FAManager_Collection";
NSString *const kOWS2FAManager_LastSuccessfulReminderDateKey = @"kOWS2FAManager_LastSuccessfulReminderDateKey";
NSString *const kOWS2FAManager_PinCode = @"kOWS2FAManager_PinCode";
NSString *const kOWS2FAManager_RepetitionInterval = @"kOWS2FAManager_RepetitionInterval";

const NSUInteger kHourSecs = 60 * 60;
const NSUInteger kDaySecs = kHourSecs * 24;

@interface OWS2FAManager ()

@end

#pragma mark -

@implementation OWS2FAManager

+ (SDSKeyValueStore *)keyValueStore
{
    return [[SDSKeyValueStore alloc] initWithCollection:kOWS2FAManager_Collection];
}

+ (instancetype)sharedManager
{
    static OWS2FAManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}


- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

- (nullable NSString *)pinCode
{
    __block NSString *pinCode = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        pinCode = [OWS2FAManager.keyValueStore getString:kOWS2FAManager_PinCode transaction:readTransaction];
    }];
    
    return pinCode;
}

- (BOOL)is2FAEnabled
{
    return self.pinCode != nil;
}

- (void)set2FANotEnabled
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        
        [OWS2FAManager.keyValueStore removeValueForKey:kOWS2FAManager_PinCode transaction:writeTransaction];
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationName_2FAStateDidChange
                                                                 object:nil
                                                               userInfo:nil];
    });
}

- (void)mark2FAAsEnabledWithPin:(NSString *)pin
{
    OWSAssertDebug(pin.length > 0);

    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        
        [OWS2FAManager.keyValueStore setObject:pin key:kOWS2FAManager_PinCode transaction:writeTransaction];
        // Schedule next reminder relative to now
        self.lastSuccessfulReminderDate = [NSDate new];
        
        [[NSNotificationCenter defaultCenter] postNotificationNameAsync:NSNotificationName_2FAStateDidChange
                                                                 object:nil
                                                               userInfo:nil];
    });
}

- (void)requestEnable2FAWithPin:(NSString *)pin
                        success:(nullable OWS2FASuccess)success
                        failure:(nullable OWS2FAFailure)failure
{
    OWSAssertDebug(pin.length > 0);
    OWSAssertDebug(success);
    OWSAssertDebug(failure);

    TSRequest *request = [OWSRequestFactory enable2FARequestWithPin:pin];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSAssertIsOnMainThread();
        
        [self mark2FAAsEnabledWithPin:pin];
        
        if (success) {
            success();
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        OWSAssertIsOnMainThread();
        
        NSError *error = errorWrapper.asNSError;
        if (failure) {
            failure(error);
        }
    }];
}

- (void)disable2FAWithSuccess:(nullable OWS2FASuccess)success failure:(nullable OWS2FAFailure)failure
{
    TSRequest *request = [OWSRequestFactory disable2FARequest];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSAssertIsOnMainThread();
        
        [self set2FANotEnabled];
        
        if (success) {
            success();
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        OWSAssertIsOnMainThread();
        
        NSError *error = errorWrapper.asNSError;
        if (failure) {
            failure(error);
        }
    }];
}


#pragma mark - Reminders

- (nullable NSDate *)lastSuccessfulReminderDate
{
    __block NSDate *reminderDate = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        reminderDate = [OWS2FAManager.keyValueStore getDate:kOWS2FAManager_LastSuccessfulReminderDateKey transaction:readTransaction];

    }];
    
    return reminderDate;
}

- (void)setLastSuccessfulReminderDate:(nullable NSDate *)date
{
    OWSLogDebug(@"%@ Seting setLastSuccessfulReminderDate:%@", self.logTag, date);
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [OWS2FAManager.keyValueStore setDate:date key:kOWS2FAManager_LastSuccessfulReminderDateKey transaction:writeTransaction];
    });
}

- (BOOL)isDueForReminder
{
    if (!self.is2FAEnabled) {
        return NO;
    }

    return self.nextReminderDate.timeIntervalSinceNow < 0;
}

- (NSDate *)nextReminderDate
{
    NSDate *lastSuccessfulReminderDate = self.lastSuccessfulReminderDate ?: [NSDate distantPast];

    return [lastSuccessfulReminderDate dateByAddingTimeInterval:self.repetitionInterval];
}

- (NSArray<NSNumber *> *)allRepetitionIntervals
{
    // Keep sorted monotonically increasing.
    return @[
        @(6 * kHourSecs),
        @(12 * kHourSecs),
        @(1 * kDaySecs),
        @(3 * kDaySecs),
        @(7 * kDaySecs),
    ];
}

- (double)defaultRepetitionInterval
{
    return self.allRepetitionIntervals.firstObject.doubleValue;
}

- (NSTimeInterval)repetitionInterval
{
    __block NSNumber *repetition = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        repetition = [OWS2FAManager.keyValueStore getObjectForKey:kOWS2FAManager_RepetitionInterval transaction:readTransaction];
    }];

    return repetition.floatValue;
}

- (void)updateRepetitionIntervalWithWasSuccessful:(BOOL)wasSuccessful
{
    if (wasSuccessful) {
        self.lastSuccessfulReminderDate = [NSDate new];
    }

    NSTimeInterval oldInterval = self.repetitionInterval;
    NSTimeInterval newInterval = [self adjustRepetitionInterval:oldInterval wasSuccessful:wasSuccessful];

    DDLogInfo(@"%@ %@ guess. Updating repetition interval: %f -> %f",
        self.logTag,
        (wasSuccessful ? @"successful" : @"failed"),
        oldInterval,
        newInterval);
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        
        [OWS2FAManager.keyValueStore setObject:@(newInterval) key:kOWS2FAManager_RepetitionInterval transaction:writeTransaction];
        
    });
}

- (NSTimeInterval)adjustRepetitionInterval:(NSTimeInterval)oldInterval wasSuccessful:(BOOL)wasSuccessful
{
    NSArray<NSNumber *> *allIntervals = self.allRepetitionIntervals;

    NSUInteger oldIndex =
        [allIntervals indexOfObjectPassingTest:^BOOL(NSNumber *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            return oldInterval <= (NSTimeInterval)obj.doubleValue;
        }];

    NSUInteger newIndex;
    if (wasSuccessful) {
        newIndex = oldIndex + 1;
    } else {
        // prevent overflow
        newIndex = oldIndex <= 0 ? 0 : oldIndex - 1;
    }

    // clamp to be valid
    newIndex = MAX(0, MIN(allIntervals.count - 1, newIndex));

    NSTimeInterval newInterval = allIntervals[newIndex].doubleValue;
    return newInterval;
}

- (void)setDefaultRepetitionInterval
{
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        
        [OWS2FAManager.keyValueStore setObject:@(self.defaultRepetitionInterval) key:kOWS2FAManager_RepetitionInterval transaction:writeTransaction];
        
    });
}

@end

NS_ASSUME_NONNULL_END
