//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const NSNotificationNameIsCensorshipCircumventionActiveDidChange;

@class OWSPrimaryStorage;
@class TSAccountManager;

@interface OWSSignalService : NSObject

+ (instancetype)sharedInstance;

- (instancetype)init NS_UNAVAILABLE;

#pragma mark - Censorship Circumvention

@property (atomic, readonly) BOOL isCensorshipCircumventionActive;
@property (atomic, readonly) BOOL hasCensoredPhoneNumber;
@property (atomic) BOOL isCensorshipCircumventionManuallyActivated;
@property (atomic, nullable) NSString *manualCensorshipCircumventionCountryCode;

@end

NS_ASSUME_NONNULL_END
