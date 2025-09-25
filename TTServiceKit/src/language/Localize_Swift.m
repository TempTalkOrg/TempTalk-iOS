//
//  Localize_Swift.m
//  TTServiceKit
//
//  Created by hornet on 2023/8/30.
//

#import "Localize_Swift.h"
#import <Foundation/Foundation.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
NSString *const LCLLanguageChangeNotification = @"LCLLanguageChangeNotification";
NSString * Localized(NSString *string, NSString *comment) {
    return [Localize localized:string];
}
