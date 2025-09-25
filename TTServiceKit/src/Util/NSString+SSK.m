//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "NSString+SSK.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const MeetingAccoutPrefix_iOS = @"ios";
NSString *const MeetingAccoutPrefix_Mac = @"mac";
NSString *const MeetingAccoutPrefix_Web = @"web";
//NSString *const MeetingAccoutPrefix_Linux = @"linux";
NSString *const MeetingAccoutPrefix_Android = @"android";

#pragma mark -

@implementation NSString (SSK)

- (NSString *)filterAsE164
{
    const NSUInteger maxLength = 256;
    NSUInteger inputLength = MIN(maxLength, self.length);
    unichar inputChars[inputLength];
    [self getCharacters:(unichar *)inputChars range:NSMakeRange(0, inputLength)];

    unichar outputChars[inputLength];
    NSUInteger outputLength = 0;
    for (NSUInteger i = 0; i < inputLength; i++) {
        unichar c = inputChars[i];
        if (c >= '0' && c <= '9') {
            outputChars[outputLength++] = c;
        } else if (outputLength == 0 && c == '+') {
            outputChars[outputLength++] = c;
        }
    }

    return [NSString stringWithCharacters:outputChars length:outputLength];
}

- (NSString *)rtlSafeAppend:(NSString *)string {
    OWSAssertDebug(string);
    
    if (CurrentAppContext().isRTL) {
        return [string stringByAppendingString:self];
    } else {
        return [self stringByAppendingString:string];
    }
}

- (NSString *)substringBeforeRange:(NSRange)range
{
    return [self substringToIndex:range.location];
}

- (NSString *)substringAfterRange:(NSRange)range
{
    return [self substringFromIndex:range.location + range.length];
}

- (NSString *)stringByURLQueryEncode {
    // 移除不可见字符
    NSString *output = [self stringByReplacingOccurrencesOfString:@"\\p{C}" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, self.length)];
    NSCharacterSet *allowedCharacters = [[NSCharacterSet characterSetWithCharactersInString:@" !'();:@&=+$,/?%#[]|<>^~`"] invertedSet];
    output = [output stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];


//    NSMutableString *output = [NSMutableString string];
//    const unsigned char *source = (const unsigned char *)[self UTF8String];
//    int sourceLen = (int)strlen((const char *)source);
//    for (int i = 0; i < sourceLen; ++i) {
//        const unsigned char thisChar = source[i];
//        if (thisChar == ' '){
//            [output appendString:@"+"];
//        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
//                   (thisChar >= 'a' && thisChar <= 'z') ||
//                   (thisChar >= 'A' && thisChar <= 'Z') ||
//                   (thisChar >= '0' && thisChar <= '9')) {
//            [output appendFormat:@"%c", thisChar];
//        } else {
//            [output appendFormat:@"%%%02X", thisChar];
//        }
//    }
    return output;
}

- (NSString *)stringRemoveNumberPrefix_Plus {
    if (self && [self isKindOfClass:NSString.class] && [self hasPrefix:@"+"]) {
        NSString *tempString = [NSString stringWithString:self];
        
        tempString = [tempString substringFromIndex:1];
        return tempString;
    }
    
    return self;
}

+ (NSString *)stringRemoveNumberPrefix_Plus:(NSString *)originString {
    if (originString && [originString isKindOfClass:NSString.class] && [originString hasPrefix:@"+"]) {
        NSString *tempString = [NSString stringWithString:originString];
        
        tempString = [tempString substringFromIndex:1];
        return tempString;
    }
    
    return originString;
}

+ (NSString *)stringByAppendNumberPrefix_Plus:(NSString *)originString {
    if (originString && [originString isKindOfClass:NSString.class] && ![originString hasPrefix:@"+"]) {
        NSString *tempString = [NSString stringWithString:originString];
        
        tempString = [@"+" stringByAppendingString:tempString];
        return tempString;
    }
    
    return originString;
}

- (NSString *)removeBUMessage {
    NSError *error;
    __block NSString *resultString = self;
    NSRegularExpression *buPattern = [NSRegularExpression regularExpressionWithPattern:@"\\(.*\\).*" options:0 error:&error];
    
    NSArray<NSTextCheckingResult *> *results = [buPattern matchesInString:resultString options:NSMatchingReportCompletion range:NSMakeRange(0, resultString.length)];
    
    [results enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = obj.range;
        if (range.location != NSNotFound && range.length != NSNotFound) {
            resultString = [resultString stringByReplacingCharactersInRange:range withString:@""];
        }
    }];
    
    return resultString;
}

// MARK: meeting

+ (NSString *)transforUserAccountToCallNumber:(NSString *)userAccount {
    NSString *callNumber = userAccount;
    if ([userAccount hasPrefix:MeetingAccoutPrefix_iOS] ||
        [userAccount hasPrefix:MeetingAccoutPrefix_Mac]) {
        callNumber = [userAccount substringFromIndex:3];
        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
    } else if ([userAccount hasPrefix:MeetingAccoutPrefix_Android]) {
        callNumber = [userAccount substringFromIndex:7];
        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
    } else if ([userAccount hasPrefix:MeetingAccoutPrefix_Web]) {
        callNumber = userAccount;
    }
//    else if ([userAccount hasPrefix:MeetingAccoutPrefix_Linux]) {
//        callNumber = [userAccount substringFromIndex:5];
//        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
//    }
    
    return callNumber;
}

- (NSString *)transforUserAccountToCallNumber {
    NSString *callNumber = self;
    if ([self hasPrefix:MeetingAccoutPrefix_iOS] ||
        [self hasPrefix:MeetingAccoutPrefix_Mac]) {
        callNumber = [self substringFromIndex:3];
        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
    } else if ([self hasPrefix:MeetingAccoutPrefix_Android]) {
        callNumber = [self substringFromIndex:7];
        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
    } else if ([self hasPrefix:MeetingAccoutPrefix_Web]) {
        callNumber = self;
    }
//    else if ([self hasPrefix:MeetingAccoutPrefix_Linux]) {
//        callNumber = [self substringFromIndex:5];
//        callNumber = [NSString stringWithFormat:@"+%@", callNumber];
//    }
    
    return callNumber;
}

- (NSArray <NSString *> *)transforCallNumberToUserAccounts {
    
    NSString *uidWithoutPrefixPlus = [NSString stringRemoveNumberPrefix_Plus:self];
    NSString *iosAccount = [MeetingAccoutPrefix_iOS stringByAppendingString:uidWithoutPrefixPlus];
    NSString *macAccount = [MeetingAccoutPrefix_Mac stringByAppendingString:uidWithoutPrefixPlus];;
    NSString *androidAccount = [MeetingAccoutPrefix_Android stringByAppendingString:uidWithoutPrefixPlus];
    
    return @[iosAccount, macAccount, androidAccount];
}

- (NSString *)transforToIOSAccount {
    
    NSString *uidWithoutPrefixPlus = [NSString stringRemoveNumberPrefix_Plus:self];
    return [MeetingAccoutPrefix_iOS stringByAppendingString:uidWithoutPrefixPlus];
}

+ (NSArray <NSString *> *)findOthersideAccountByAccount:(NSString *)account {
    
    if ([account hasPrefix:MeetingAccoutPrefix_Web]) {
        return @[];
    }
    
    NSString *callNumber = [account transforUserAccountToCallNumber];
    NSMutableArray <NSString *> *otherSideAccounts = [callNumber transforCallNumberToUserAccounts].mutableCopy;
    [otherSideAccounts removeObject:account];
        
    return otherSideAccounts.copy;
}

- (NSArray <NSString *> *)findOthersideAccountByAccount {
    
    return [NSString findOthersideAccountByAccount:self];
}

- (NSString *)getWebUserName {
    
    OWSAssertDebug([self hasPrefix:MeetingAccoutPrefix_Web]);
    NSArray <NSString *> *separatedId = [self componentsSeparatedByString:@"-"];
    NSString *webUserName = self;
    if (separatedId.count == 3) {
        webUserName = [[separatedId objectAtIndex:1] stringByAppendingFormat:@"(%@)", MeetingAccoutPrefix_Web];
    }
    
    return webUserName;
}

- (NSComparisonResult)compareWithVersion:(NSString *)aVersionString {
    return  [self compare:aVersionString options:NSNumericSearch];
}

- (BOOL)isNewerThanVersion:(NSString *)aVersionString {
    return  [self compareWithVersion:aVersionString] == NSOrderedDescending;
}

- (BOOL)isOlderThanVersion:(NSString *)aVersionString {
    return  [self compareWithVersion:aVersionString] == NSOrderedAscending;
}

- (BOOL)isSameToVersion:(NSString *)aVersionString {
    return  [self compareWithVersion:aVersionString] == NSOrderedSame;
}

- (NSString *)composedCharacterStringWithRange:(NSRange)range {
    NSRange targetRange = [self rangeOfComposedCharacterSequencesForRange:range];
    return [self substringWithRange:targetRange];
}

@end

NS_ASSUME_NONNULL_END
