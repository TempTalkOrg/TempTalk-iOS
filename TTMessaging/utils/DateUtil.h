//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kBotTimeIntervalPattern;

@interface DateUtil : NSObject

+ (NSDateFormatter *)dateFormatter;
+ (NSDateFormatter *)monthAndDayFormatter;
+ (NSDateFormatter *)shortDayOfWeekFormatter;
+ (NSDateFormatter *)weekdayFormatter;
+ (NSDateFormatter *)normalLongFormatter;

+ (BOOL)dateIsOlderThanToday:(NSDate *)date;
+ (BOOL)dateIsOlderThanOneWeek:(NSDate *)date;
+ (BOOL)dateIsToday:(NSDate *)date;
+ (BOOL)dateIsThisYear:(NSDate *)date;
+ (BOOL)dateIsYesterday:(NSDate *)date;

+ (NSString *)formatPastTimestampRelativeToNow:(uint64_t)pastTimestamp
NS_SWIFT_NAME(formatPastTimestampRelativeToNow(_:));

+ (NSString *)formatTimestampShort:(uint64_t)timestamp;
+ (NSString *)formatDateShort:(NSDate *)date;
+ (NSString *)formatMessageTimestamp:(uint64_t)timestamp;

+ (NSString *)formatTimestampAsTime:(uint64_t)timestamp NS_SWIFT_NAME(formatTimestampAsTime(_:));
+ (NSString *)formatDateAsTime:(NSDate *)date NS_SWIFT_NAME(formatDateAsTime(_:));

+ (NSString *)formatTimestampAsDate:(uint64_t)timestamp NS_SWIFT_NAME(formatTimestampAsDate(_:));
+ (NSString *)formatDateAsDate:(NSDate *)date NS_SWIFT_NAME(formatDateAsDate(_:));

+ (NSString *)formatToMinuteHourDayWeekWithTimeInterval:(NSTimeInterval)timeInterval;

//+ (NSString *)formatDateForConversationDateBreaks:(NSDate *)date;

+ (BOOL)isTimestampFromLastHour:(uint64_t)timestamp NS_SWIFT_NAME(isTimestampFromLastHour(_:));

+ (BOOL)dateIsOlderThanYesterday:(NSDate *)date;

+ (NSString *)dueTimeStringFromMilliSeconds:(uint64_t)milliSeconds;
+ (NSString *)dueTimeStringFromMilliSeconds:(uint64_t)milliSeconds
                                  hasSecond:(BOOL)hasSecond;

+ (NSString *)dayFromInterval:(NSTimeInterval)timeInvarval
                     useToday:(BOOL)useToday;

+ (BOOL)isChinese;

@end

NS_ASSUME_NONNULL_END
