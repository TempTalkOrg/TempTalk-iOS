//
//  TSThreadPermissionHelper.m
//  TTServiceKit
//
//  Created by hornet on 2022/9/30.
//

#import "TSThreadPermissionHelper.h"
#import "TSThread.h"
#import "DTToastHelper.h"
#import <TTServiceKit/Localize_Swift.h>

@implementation TSThreadPermissionHelper
+ (BOOL)checkCanSpeakAndToastTipMessage:(TSThread *)thread {
    if(![thread isHavePermissioncanSpeak]){
        [DTToastHelper toastWithText:Localized(@"TOAST_ONLY_MODETATORS_CAN_SPEAK", @"") durationTime:3.0];
        return false;
    } else {
        return true;
    }
}
@end
