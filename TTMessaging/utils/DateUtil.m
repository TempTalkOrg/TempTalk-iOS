//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import "DateUtil.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <TTMessaging/TTMessaging-Swift.h>


NS_ASSUME_NONNULL_BEGIN

static NSString *const DATE_FORMAT_WEEKDAY = @"EEEE";
NSString *const kBotTimeIntervalPattern = @"\\$FORMAT-LOCAL-TIME\\{(\\d{10}?)\\}";

@implementation DateUtil

+ (NSDateFormatter *)dateFormatter {
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setTimeStyle:NSDateFormatterNoStyle];
    [formatter setDateStyle:NSDateFormatterShortStyle];
    return formatter;
}

+ (NSLocale *)userPerferLocale {
    if(Localize.isChineseLanguage){
        return [NSLocale localeWithLocaleIdentifier:@"zh_CN"];
    } else {
        return [NSLocale localeWithLocaleIdentifier:@"en_US"];
    }
}

+ (NSDateFormatter *)weekdayFormatter
{
    NSDateFormatter * formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setLocalizedDateFormatFromTemplate:DATE_FORMAT_WEEKDAY];
    return formatter;
}

+ (NSDateFormatter *)monthAndDayFormatter
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setLocalizedDateFormatFromTemplate:@"M/d"];
    return formatter;
}

+ (NSDateFormatter *)shortDayOfWeekFormatter
{
    NSDateFormatter *formatter;
    formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    formatter.dateFormat = @"E";
    return formatter;
}

+ (NSDateFormatter *)normalLongFormatter
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    if(Localize.isChineseLanguage){
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    } else {
        formatter.dateFormat = @"MMM d, yyyy HH:mm:ss";
    }
    return formatter;
}

+ (BOOL)dateIsOlderThanToday:(NSDate *)date
{
    return [self dateIsOlderThanToday:date now:[NSDate date]];
}

+ (BOOL)dateIsOlderThanToday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference > 0;
}

+ (BOOL)dateIsOlderThanYesterday:(NSDate *)date
{
    return [self dateIsOlderThanYesterday:date now:[NSDate date]];
}

+ (BOOL)dateIsOlderThanYesterday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference > 1;
}

+ (BOOL)dateIsOlderThanOneWeek:(NSDate *)date
{
    return [self dateIsOlderThanOneWeek:date now:[NSDate date]];
}

+ (BOOL)dateIsOlderThanOneWeek:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference > 6;
}

+ (BOOL)dateIsToday:(NSDate *)date
{
    return [self dateIsToday:date now:[NSDate date]];
}

+ (BOOL)dateIsToday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference == 0;
}

+ (BOOL)dateIsThisYear:(NSDate *)date
{
    return [self dateIsThisYear:date now:[NSDate date]];
}

+ (BOOL)dateIsThisYear:(NSDate *)date now:(NSDate *)now
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    return (
            [calendar component:NSCalendarUnitYear fromDate:date] == [calendar component:NSCalendarUnitYear fromDate:now]);
}

+ (BOOL)dateIsYesterday:(NSDate *)date
{
    return [self dateIsYesterday:date now:[NSDate date]];
}

+ (BOOL)dateIsYesterday:(NSDate *)date now:(NSDate *)now
{
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    return dayDifference == 1;
}

+ (NSString *)formatPastTimestampRelativeToNow:(uint64_t)pastTimestamp
{
    OWSCAssertDebug(pastTimestamp > 0);
    
    uint64_t nowTimestamp = [NSDate ows_millisecondTimeStamp];
    BOOL isFutureTimestamp = pastTimestamp >= nowTimestamp;
    
    NSDate *pastDate = [NSDate ows_dateWithMillisecondsSince1970:pastTimestamp];
    NSString *dateString;
    if (isFutureTimestamp || [self dateIsToday:pastDate]) {
        dateString = Localized(@"DATE_TODAY", @"The current day.");
    } else if ([self dateIsYesterday:pastDate]) {
        dateString = Localized(@"DATE_YESTERDAY", @"The day before today.");
    } else {
        dateString = [[self dateFormatter] stringFromDate:pastDate];
    }
    return [[dateString stringByAppendingString:@" "]
            stringByAppendingString:[[self timeFormatter] stringFromDate:pastDate]];
}

+ (NSString *)formatTimestampShort:(uint64_t)timestamp
{
    return [self formatDateShort:[NSDate ows_dateWithMillisecondsSince1970:timestamp]];
}

+ (NSString *)formatDateShort:(NSDate *)date
{
    OWSAssertDebug(date);
    
    NSDate *now = [NSDate date];
    NSInteger dayDifference = [self daysFromFirstDate:date toSecondDate:now];
    BOOL dateIsOlderThanToday = dayDifference > 0;
    BOOL dateIsOlderThanOneWeek = dayDifference > 6;
    
    NSString *dateTimeString;
    if (![DateUtil dateIsThisYear:date]) {
        dateTimeString = [[DateUtil dateFormatter] stringFromDate:date];
    } else if (dateIsOlderThanOneWeek) {
        dateTimeString = [[DateUtil monthAndDayFormatter] stringFromDate:date];
    } else if (dateIsOlderThanToday) {
        dateTimeString = [[DateUtil shortDayOfWeekFormatter] stringFromDate:date];
    } else {
        dateTimeString = [DateUtil formatMessageTimestampForCVC:date.ows_millisecondsSince1970 shouldUseLongFormat:NO];
    }
    
    return dateTimeString;
}

+ (NSString *)formatMessageTimestamp:(uint64_t)timestamp
{
    NSDate *date = [NSDate ows_dateWithMillisecondsSince1970:timestamp];
    uint64_t nowTimestamp = [NSDate ows_millisecondTimeStamp];
    NSDate *nowDate = [NSDate ows_dateWithMillisecondsSince1970:nowTimestamp];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // Note: we are careful to treat "future" dates as "now".
    NSInteger yearsDiff = [self yearsFromFirstDate:date toSecondDate:nowDate];
    NSInteger daysDiff = [self daysFromFirstDate:date toSecondDate:nowDate];
    NSInteger minutesDiff
    = MAX(0, [[calendar components:NSCalendarUnitMinute fromDate:date toDate:nowDate options:0] minute]);
    NSInteger hoursDiff
    = MAX(0, [[calendar components:NSCalendarUnitHour fromDate:date toDate:nowDate options:0] hour]);
    
    NSString *result;
    if (yearsDiff > 0) {
        // "Long date" + locale-specific "short" time format.
        NSString *dayOfWeek = [self.otherYearMessageFormatter stringFromDate:date];
        NSString *formattedTime = [[self timeFormatter] stringFromDate:date];
        result = [[dayOfWeek rtlSafeAppend:@" "] rtlSafeAppend:formattedTime];
    } else if (daysDiff > 0) {
        // "Short date" + locale-specific "short" time format.
        NSString *dayOfWeek = [self.thisYearMessageFormatter stringFromDate:date];
        NSString *formattedTime = [[self timeFormatter] stringFromDate:date];
        result = [[dayOfWeek rtlSafeAppend:@" "] rtlSafeAppend:formattedTime];
    } else if (minutesDiff < 1) {
        result = Localized(@"DATE_NOW", @"The present; the current time.");
    } else if (hoursDiff < 1) {
        NSString *minutesString = [OWSFormat formatInt:(int)minutesDiff];
        result = [NSString stringWithFormat:Localized(@"DATE_MINUTES_AGO_FORMAT",
                                                              @"Format string for a relative time, expressed as a certain number of "
                                                              @"minutes in the past. Embeds {{The number of minutes}}."),
                  minutesString];
    } else {
        result = [DateUtil formatMessageTimestampForCVC:timestamp shouldUseLongFormat:NO];
    }
    return result;
}

+ (NSString *)formatTimestampAsTime:(uint64_t)timestamp
{
    return [self formatDateAsTime:[NSDate ows_dateWithMillisecondsSince1970:timestamp]];
}

+ (NSString *)formatDateAsTime:(NSDate *)date
{
    OWSAssertDebug(date);
    
    NSString *dateTimeString = [[DateUtil timeFormatter] stringFromDate:date];
    return dateTimeString;
}

+ (NSString *)formatTimestampAsDate:(uint64_t)timestamp
{
    return [self formatDateAsDate:[NSDate ows_dateWithMillisecondsSince1970:timestamp]];
}

+ (NSString *)formatDateAsDate:(NSDate *)date
{
    OWSAssertDebug(date);
    
    NSString *dateTimeString;
    
    NSInteger yearsDiff = [self yearsFromFirstDate:date toSecondDate:[NSDate new]];
    if (yearsDiff > 0) {
        dateTimeString = [[DateUtil otherYearMessageFormatter] stringFromDate:date];
    } else {
        dateTimeString = [[DateUtil thisYearMessageFormatter] stringFromDate:date];
    }
    
    return dateTimeString;
}

+ (NSDateFormatter *)otherYearMessageFormatter
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setLocalizedDateFormatFromTemplate:@"MMM d, yyyy"];
    
    return formatter;
}

+ (NSDateFormatter *)thisYearMessageFormatter
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setLocalizedDateFormatFromTemplate:@"MMM d"];
    return formatter;
}

+ (NSDateFormatter *)thisWeekMessageFormatterShort
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setDateFormat:@"E"];
    return formatter;
}

+ (NSDateFormatter *)thisWeekMessageFormatterLong
{
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter = [NSDateFormatter new];
    [formatter setLocale:[self userPerferLocale]];
    [formatter setDateFormat:@"EEEE"];
    
    return formatter;
}

+ (BOOL)isTimestampFromLastHour:(uint64_t)timestamp
{
    NSDate *date = [NSDate ows_dateWithMillisecondsSince1970:timestamp];
    uint64_t nowTimestamp = [NSDate ows_millisecondTimeStamp];
    NSDate *nowDate = [NSDate ows_dateWithMillisecondsSince1970:nowTimestamp];
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSInteger hoursDiff
    = MAX(0, [[calendar components:NSCalendarUnitHour fromDate:date toDate:nowDate options:0] hour]);
    return hoursDiff < 1;
}

+ (NSString *)formatToMinuteHourDayWeekWithTimeInterval:(NSTimeInterval)timeInterval{
    
    NSString *localizedStringKey = nil;
    NSTimeInterval count = 0;
    if(timeInterval > kWeekInterval){
        localizedStringKey = @"TIME_AMOUNT_WEEKS";
        count = timeInterval/kWeekInterval;
        if(count == 1){
            localizedStringKey = @"TIME_AMOUNT_SINGLE_WEEK";
        }
    }else if(timeInterval > kDayInterval){
        localizedStringKey = @"TIME_AMOUNT_DAYS";
        count = timeInterval/kDayInterval;
        if(count == 1){
            localizedStringKey = @"TIME_AMOUNT_SINGLE_DAY";
        }
    }else if (timeInterval > kHourInterval){
        
        localizedStringKey = @"TIME_AMOUNT_HOURS";
        count = timeInterval/kHourInterval;
        if(count == 1){
            localizedStringKey = @"TIME_AMOUNT_SINGLE_HOUR";
        }
    }else if (timeInterval > kMinuteInterval){
        
        localizedStringKey = @"TIME_AMOUNT_MINUTES";
        count = timeInterval/kMinuteInterval;
        if(count == 1){
            localizedStringKey = @"TIME_AMOUNT_SINGLE_MINUTE";
        }
    }else{
        localizedStringKey = @"TIME_AMOUNT_SECONDS";
        count = timeInterval/kSecondInterval;
    }
    
    return [NSString stringWithFormat:Localized(localizedStringKey,@""), [NSString stringWithFormat:@"%.f",count]];;
    
}

+ (NSString *)dueTimeStringFromMilliSeconds:(uint64_t)milliSeconds {
    
    return [self.class dueTimeStringFromMilliSeconds:milliSeconds hasSecond:NO];
}

+ (NSString *)dueTimeStringFromMilliSeconds:(uint64_t)milliSeconds
                                  hasSecond:(BOOL)hasSecond {
    
    NSDate *dueDate = [NSDate ows_dateWithMillisecondsSince1970:milliSeconds];
    
    NSDateFormatter *monthFormatter = [NSDateFormatter new];
    if (self.isChinese) {
        monthFormatter.dateFormat = @"M月d日";
    } else {
        monthFormatter.dateFormat = @"MMM d";
    }
    NSString *monthString = [monthFormatter stringFromDate:dueDate];
    
    NSDateFormatter *weekFormatter = [NSDateFormatter new];
    if (self.isChinese) {
        weekFormatter.weekdaySymbols = @[@"周日", @"周一", @"周二", @"周三", @"周四", @"周五", @"周六"];
        weekFormatter.dateFormat = @"(EEEE)";
    } else {
        weekFormatter.dateFormat = @"EEE";
    }
    NSString *weekString = [weekFormatter stringFromDate:dueDate];
    
    NSCalendar *gregorianCalendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    if ([gregorianCalendar isDateInToday:dueDate]) {
        weekString = Localized(@"LIGHT_TASK_DUE_TIME_TODAY", @"");
    } else if ([gregorianCalendar isDateInTomorrow:dueDate]) {
        weekString = Localized(@"LIGHT_TASK_DUE_TIME_TOMORROW", @"");
    } else if ([gregorianCalendar isDateInYesterday:dueDate]) {
        weekString = Localized(@"LIGHT_TASK_DUE_TIME_YESTERDAY", @"");
    }
    
    NSDateFormatter *HMFormatter = [NSDateFormatter new];
    HMFormatter.dateFormat = hasSecond ? @"HH:mm:ss" : @"HH:mm";
    NSString *HMString = [HMFormatter stringFromDate:dueDate];
    
    NSString *fullDateString = nil;
    
    NSDateComponents *cmp1 = [gregorianCalendar components:NSCalendarUnitYear fromDate:dueDate];
    NSDateComponents *cmp2 = [gregorianCalendar components:NSCalendarUnitYear fromDate:[NSDate date]];
    if (cmp1.year != cmp2.year) {
        NSDateFormatter *yearFormatter = [NSDateFormatter new];
        if (self.isChinese) {
            yearFormatter.dateFormat = @"yyyy年M月d日 HH:mm";
        } else {
            yearFormatter.dateFormat = @"MMM d, yyyy, HH:mm";
        }
        fullDateString = [yearFormatter stringFromDate:dueDate];
    } else {
        if (self.isChinese) {
            fullDateString = [NSString stringWithFormat:@"%@ %@ %@", monthString, weekString, HMString];
        } else {
            fullDateString = [NSString stringWithFormat:@"%@, %@, %@", weekString, monthString, HMString];
        }
    }
    
    return milliSeconds > 0 ? fullDateString : @"";
}

+ (NSString *)dayFromInterval:(NSTimeInterval)timeInvarval 
                     useToday:(BOOL)useToday {
                
    if (timeInvarval <=0) return @"--";
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timeInvarval];
    
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
  
    if (useToday) {
        if ([calendar isDateInToday:date]) {
            return @"Today";
        } else if ([calendar isDateInTomorrow:date]) {
            return @"Tomorrow";
        }
    }

    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"EEE, MMM d";
    [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    
    return [formatter stringFromDate:date];
}

+ (BOOL)isChinese {
//    NSString *preferredLanguage = [[NSLocale preferredLanguages] firstObject];
//    return [preferredLanguage isEqualToString:@"zh-Hant"] ||
//    [preferredLanguage hasPrefix:@"zh-Hant"] ||
//    [preferredLanguage hasPrefix:@"yue-Hant"] ||
//    [preferredLanguage isEqualToString:@"zh-HK"] ||
//    [preferredLanguage isEqualToString:@"zh-TW"]||
//    [preferredLanguage isEqualToString:@"zh-Hans"] ||
//    [preferredLanguage hasPrefix:@"yue-Hans"] ||
//    [preferredLanguage hasPrefix:@"zh-Hans"];
    return Localize.isChineseLanguage;
}

@end

NS_ASSUME_NONNULL_END
