//
//  NSError+errorMessage.m
//  TTServiceKit
//
//  Created by hornet on 2022/10/20.
//

#import "NSError+errorMessage.h"
#import "DTBaseAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation NSError (errorMessage)
//仅处理限频
+ (NSString *)errorDesc:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse {
    int httpStatusCode = [error.httpStatusCode intValue];
    if (httpStatusCode == 413 || httpStatusCode == 429){
        return Localized(@"LOGIN_SUBIT_FAST", @"");
    }
    return [NSString stringWithFormat:@"%@",Localized(@"REQUEST_FAILED_TRY_AGAIN", @"")];
}
+ (NSString *)loginErrorDescByInviteCode:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse {
    if(error && errResponse){
        int httpStatusCode = [error.httpStatusCode intValue];
        NSInteger status = errResponse.status;
        if(httpStatusCode == 403 && status > 0 && ( status == 28 || status == 1)){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_MANY_ERROR_INVALID_CODE", @"")];
        }
        if(httpStatusCode == 403 && status > 0 && ( status == 27 )){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_MANY_ERROR_INVALID_CODE", @"")];
        }
    }
    return [self errorDesc:error errResponse:errResponse];
}

+ (NSString *)loginErrorDescByEmail:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse {
    if(error && errResponse){
        int httpStatusCode = [error.httpStatusCode intValue];
        NSInteger status = errResponse.status;
        if(httpStatusCode == 403 && status > 0 && ( status == 11 || status == 1)){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_INVALID_EMAIL", @"")];
        }

        if(httpStatusCode == 403 && status > 0 && ( status == 27 )){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_MANY_ERRORS", @"")];
        }
        
        if(httpStatusCode == 403 && status > 0 && ( status == 26 )){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_VER_OTP_FAILED", @"")];
        }
        
        if(httpStatusCode == 403 && status > 0 && ( status == 24 )){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_SUBIT_ALREADY_BIND", @"")];
        }
        if(httpStatusCode == 403 && status > 0 && ( status == 23 )){
            return [NSString stringWithFormat:@"%@",Localized(@"LOGIN_ACCOUNT_BINDED", @"")];
        }
    }
    return [self errorDesc:error errResponse:errResponse];
}

+ (NSString *)defaultErrorMessage {
     return [NSString stringWithFormat:@"%@",Localized(@"REQUEST_FAILED_TRY_AGAIN", @"")];
 }

@end
