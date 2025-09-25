//
//  NSString+timeFormat.m
//  TTServiceKit
//
//  Created by Kris.s on 2024/11/29.
//

#import "NSString+timeFormat.h"

@implementation NSString (timeFormat)

+ (NSString *)formatDurationSeconds:(uint32_t)durationSeconds useShortFormat:(BOOL)useShortFormat
{
    NSString *amountFormat;
    uint32_t duration;

    uint32_t secondsPerMinute = 60;
    uint32_t secondsPerHour = secondsPerMinute * 60;
    uint32_t secondsPerDay = secondsPerHour * 24;
    uint32_t secondsPerWeek = secondsPerDay * 7;

    if (durationSeconds < secondsPerMinute) { // XX Seconds
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SECONDS_SHORT_FORMAT", @"");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SECONDS", "");
        }

        duration = durationSeconds;
    } else if (durationSeconds < secondsPerMinute * 1.5) { // 1 Minute
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_MINUTES_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SINGLE_MINUTE", "");
        }
        duration = durationSeconds / secondsPerMinute;
    } else if (durationSeconds < secondsPerHour) { // Multiple Minutes
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_MINUTES_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_MINUTES", "");
        }

        duration = durationSeconds / secondsPerMinute;
    } else if (durationSeconds < secondsPerHour * 1.5) { // 1 Hour
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_HOURS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SINGLE_HOUR", "");
        }

        duration = durationSeconds / secondsPerHour;
    } else if (durationSeconds < secondsPerDay) { // Multiple Hours
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_HOURS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_HOURS", "");
        }

        duration = durationSeconds / secondsPerHour;
    } else if (durationSeconds < secondsPerDay * 1.5) { // 1 Day
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_DAYS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SINGLE_DAY", "");
        }

        duration = durationSeconds / secondsPerDay;
    } else if (durationSeconds < secondsPerWeek) { // Multiple Days
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_DAYS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_DAYS", "");
        }

        duration = durationSeconds / secondsPerDay;
    } else if (durationSeconds < secondsPerWeek * 1.5) { // 1 Week
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_WEEKS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_SINGLE_WEEK", "");
        }

        duration = durationSeconds / secondsPerWeek;
    } else { // Multiple weeks
        if (useShortFormat) {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_WEEKS_SHORT_FORMAT", "");
        } else {
            amountFormat = NSLocalizedString(@"TIME_AMOUNT_WEEKS", "");
        }

        duration = durationSeconds / secondsPerWeek;
    }

    return [NSString stringWithFormat:amountFormat,
                     [NSNumberFormatter localizedStringFromNumber:@(duration) numberStyle:NSNumberFormatterNoStyle]];
}

@end
