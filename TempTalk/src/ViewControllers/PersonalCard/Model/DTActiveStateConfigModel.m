//
//  DTActiveStateConfigModel.m
//  Wea
//
//  Created by user on 2022/8/23.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTActiveStateConfigModel.h"
#import <TTServiceKit/Localize_Swift.h>

@interface DTActiveStateConfigModel()

@property (nonatomic, strong) NSString *displayTitle;

@end

@implementation DTActiveStateConfigModel

- (void)setMintues:(NSNumber *)mintues {
    _mintues = mintues;
    self.displayTitle = [self dateDimensionString:mintues];
}

- (NSString *)dateDimensionString:(NSNumber *)timeNumber {
    int hourNum = (int)[timeNumber integerValue]/60;
    if (hourNum == 0) {
        if ([timeNumber intValue] == 1) {
            return [NSString stringWithFormat:@"%@ %@",timeNumber,Localized(@"PERSON_CARD_STATE_MINUTE", @"Title for user state")];
        }else {
            return [NSString stringWithFormat:@"%@ %@",timeNumber,Localized(@"PERSON_CARD_STATE_MINUTES", @"Title for user state")];
        }
    }
    if (hourNum > 0 && hourNum <24) {
        if (hourNum == 1) {
            return [NSString stringWithFormat:@"%d %@",hourNum,Localized(@"PERSON_CARD_STATE_HOUR", @"Title for user state")];
        }else {
            return [NSString stringWithFormat:@"%d %@",hourNum,Localized(@"PERSON_CARD_STATE_HOURS", @"Title for user state")];
        }
    }
    int dayNum = hourNum/24;
    if (hourNum >= 24) {
        if (dayNum == 1) {
            return [NSString stringWithFormat:@"%d %@",dayNum,Localized(@"PERSON_CARD_STATE_DAY", @"Title for user state")];
        }else {
            return [NSString stringWithFormat:@"%d %@",dayNum,Localized(@"PERSON_CARD_STATE_DAYS", @"Title for user state")];
        }
    }
    return @"";
}
@end
