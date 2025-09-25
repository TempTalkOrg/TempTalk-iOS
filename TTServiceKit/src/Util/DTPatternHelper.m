//
//  DTPatternHelper.m
//  TTMessaging
//
//  Created by hornet on 2021/12/2.
//

#import "DTPatternHelper.h"
#import "DTParamsBaseUtils.h"

NSString *const kFormatSchemaPattern = @"$FORMAT-SCHEMA";

@implementation DTPatternHelper

+ (BOOL)isAppUid:(NSString *)uid {
    
    if (!DTParamsUtils.validateString(uid)) {
        return NO;
    }
    
    NSString *uidRegex = @"^\\+\\d{11}$";
    NSPredicate *uidPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", uidRegex];
    return [uidPredicate evaluateWithObject:uid];
}

+ (BOOL)validateEmail:(NSString *)email {
    
    NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", @"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"];

    BOOL isValid = [emailPredicate evaluateWithObject:email];
    return isValid;
    
}

//邀请码
+ (BOOL)validateInvitedCode:(NSString *)invitedCode {
    NSString *invitedCodeRegex = @"^[a-zA-Z0-9]{32}$";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    return [invitedCodPredicate evaluateWithObject:invitedCode];
}

+ (BOOL)validateBChatInvitedCode:(NSString *)invitedCode {
    NSString *invitedCodeRegex = @"^[a-zA-Z0-9]{32}$";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    return [invitedCodPredicate evaluateWithObject:invitedCode];
}

//邀请码
+ (NSString *)verification:(NSString *)invitedCode {
    if(!DTParamsUtils.validateString(invitedCode)){
        return nil;
    }
    NSString *invitedCodeRegex = @"^\\d{1,6}";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:invitedCodeRegex
   options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:invitedCode options:0 range: NSMakeRange(0, [invitedCode length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               // 截取数据
               NSString *result = [invitedCode substringWithRange: resultRange];
               return result;
           }
       }
    return @"";
}

//vcode
+ (BOOL)validateVCode:(NSString *)vCode {
    NSString *vCodeRegex = @"^\\d{17}$";
    NSPredicate *vCodePredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", vCodeRegex];
    return [vCodePredicate evaluateWithObject:vCode];
}


//(76309750567/xx.x@google.com)  正则表达式在线校验  \([1-9]\d{4,10}[^\d]?.*?\) https://c.runoob.com/front-end/854/?optionGlobl=global
+ (NSString *)getForwardUidString:(NSString *)forwardMessage {
//       NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\([1-9][0-9]+."
//   options: NSRegularExpressionCaseInsensitive error:nil];
    
    if (!DTParamsUtils.validateString(forwardMessage)) {
        return @"";
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\([1-9]\\d{10}[^\\d]?.*?\\)"
options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:forwardMessage options:0 range: NSMakeRange(0, [forwardMessage length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               // 截取数据
               NSString *result = [forwardMessage substringWithRange: resultRange];
               return result;
           }
       }
    return @"";
}

+ (NSString *)getNumberString:(NSString *)forwardMessage {//从文本中获取纯数字
    if (!DTParamsUtils.validateString(forwardMessage)) {
        return @"";
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[1-9][0-9]{4,10}"
   options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:forwardMessage options:0 range: NSMakeRange(0, [forwardMessage length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               // 截取数据
               NSString *result = [forwardMessage substringWithRange: resultRange];
               return result;
           }
       }
    return @"";
}

//\(([1-9].+?)\)  获取转发消息中 Message from Peter H (Investment) (id/xx.x@google.com):小括号(id/xx.x@google.com)这个部分
+ (void)getForwardMessageSourceTextWith:(NSString *)forwardMessage withCallBack:(void(^)(NSRange)) callBack {
    if (!DTParamsUtils.validateString(forwardMessage)) {
        return;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\([1-9]\\d{10}[^\\d]?.*?\\)"
options: NSRegularExpressionCaseInsensitive error:nil];
    
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:forwardMessage options:0 range: NSMakeRange(0, [forwardMessage length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               if (callBack) {
                   callBack(resultRange);
               }
           }
       }
}

+ (void)getForwardMessageSourceTextWith:(NSString *)forwardMessage withCallBackCheckingResult:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack {
    if (!DTParamsUtils.validateString(forwardMessage)) {
        return;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\([1-9]\\d{10}[^\\d]?.*?\\)"
options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSArray<NSTextCheckingResult *> *checkingResultArr = [regex matchesInString:forwardMessage options:0 range:NSMakeRange(0, [forwardMessage length])];
           if(checkingResultArr && checkingResultArr.count){
               if (callBack) {
                   callBack(checkingResultArr);
               }
           }
       }
}

+ (void)getForwardMessageURLtWith:(NSString *)forwardMessage withCallBack:(void(^)(NSArray<NSTextCheckingResult *> *)) callBack {
    if (!DTParamsUtils.validateString(forwardMessage)) {
        return;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[a-zA-z]+://[^\\s]*"
                                                                           options: NSRegularExpressionCaseInsensitive error:nil];
    if (regex!=nil) {
        //           NSTextCheckingResult *firstMatch = [regex firstMatchInString:forwardMessage options:0 range: NSMakeRange(0, [forwardMessage length])];
        
        NSArray<NSTextCheckingResult *> * resultArr = [regex matchesInString:forwardMessage options:0 range:NSMakeRange(0, [forwardMessage length])];
        if(resultArr){
            if (callBack) {
                callBack(resultArr);
            }
        }
    }
}

+ (void)getUrlsFromString:(NSString *)string usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable, NSMatchingFlags, BOOL *))block {
    
    NSError *error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    [detector enumerateMatchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0, string.length) usingBlock:block];
}

+ (void)matchResultFormString:(NSString *)string
                      pattern:(NSString *)pattern
                   usingBlock:(void (NS_NOESCAPE ^)(NSTextCheckingResult * _Nullable, NSMatchingFlags, BOOL *))block {
    if (!DTParamsUtils.validateString(string) || !DTParamsUtils.validateString(pattern)) {
        return;
    }
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:nil];
    if (!regex) {
        return;
    }
    [regex enumerateMatchesInString:string
                            options:NSMatchingReportProgress
                              range:NSMakeRange(0, string.length)
                         usingBlock:block];
}

+ (NSArray<NSTextCheckingResult *> *)matchResultFormString:(NSString *)string
                      pattern:(NSString *)pattern {
    if (!DTParamsUtils.validateString(string) || !DTParamsUtils.validateString(pattern)) {
        return @[];
    }
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionIgnoreMetacharacters error:nil];
    if (!regex) {
        return @[];
    }
    return [regex matchesInString:string
                          options:NSMatchingReportProgress
                            range:NSMakeRange(0, string.length)];
}

//验证输入框中的
+ (NSString *)verificationTextInputNumerWithPlus:(NSString *)phoneNumer {
    if(!DTParamsUtils.validateString(phoneNumer)){
        return nil;
    }
    NSString *invitedCodeRegex = @"^\\+[1-9]\\d{2,14}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:invitedCodeRegex
   options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:phoneNumer options:0 range: NSMakeRange(0, [phoneNumer length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               // 截取数据
               NSString *result = [phoneNumer substringWithRange: resultRange];
               return result;
           }
       }
    return @"";
}

//验证输入框中的
+ (NSString *)verificationTextInputNumer:(NSString *)phoneNumer {
    if(!DTParamsUtils.validateString(phoneNumer)){
        return nil;
    }
    NSString *invitedCodeRegex = @"^[1-9]\\d{2,14}$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:invitedCodeRegex
   options: NSRegularExpressionCaseInsensitive error:nil];
       if(regex!=nil){
           NSTextCheckingResult *firstMatch = [regex firstMatchInString:phoneNumer options:0 range: NSMakeRange(0, [phoneNumer length])];
           if(firstMatch){
               NSRange resultRange = [firstMatch rangeAtIndex: 0];
               // 截取数据
               NSString *result = [phoneNumer substringWithRange: resultRange];
               return result;
           }
       }
    return @"";
}

+ (BOOL)validateSecurityChativeInvitedURL:(NSString *)url {
//    ^https://chative\.com/.+\?i=[a-zA-Z0-9_-]{8,32}&p=[a-zA-Z0-9_-]{30,60}&c=[a-zA-Z0-9_-]{8}.*
    NSString *invitedCodeRegex = @"^https://chative\\.com/.+\?a=pi&pi=[a-zA-Z0-9_-]{8,32}&p=[a-zA-Z0-9_-]{30,60}&c=[a-zA-Z0-9_-]{8}.*";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    return [invitedCodPredicate evaluateWithObject:url];
}

+ (BOOL)validateChativeInvitedCode:(NSString *)invitedCode {
    NSString *invitedCodeRegex = @"^(CHATIVE)\?[0-9a-zA-Z]{8,32}$";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    return [invitedCodPredicate evaluateWithObject:invitedCode];
}

+ (BOOL)validatePeroidChativeInvitedURL:(NSString *)url {
    NSString *invitedCodeRegex = @"^https://chative\\.com/.+\?a=pi&pi=[0-9a-zA-Z_-]{8,32}.*";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    return [invitedCodPredicate evaluateWithObject:url];
}

+ (BOOL)validateTempTalkInvitedURL:(NSString *)url {
    NSString *invitedCodeRegex = @"^https:\\/\\/temptalk\\.app\\/u(?:\\/[^?#]*)?(\\?[^#]*)?(&?pi=[A-Za-z0-9]+)(#[^#]*)?$";
    NSPredicate *invitedCodPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex];
    
    NSString *invitedCodeRegex_temp = @"^https:\\/\\/chative\\.com\\/u(?:\\/[^?#]*)?(\\?[^#]*)?(&?pi=[A-Za-z0-9]+)(#[^#]*)?$";
    NSPredicate *invitedCodPredicate_temp = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex_temp];
    
    NSString *invitedCodeRegex_test = @"^https:\\/\\/test\\.temptalk\\.app\\/u(?:\\/[^?#]*)?(\\?[^#]*)?(&?pi=[A-Za-z0-9]+)(#[^#]*)?$";
    NSPredicate *invitedCodPredicate_test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", invitedCodeRegex_test];
    
    return [invitedCodPredicate evaluateWithObject:url] ||
    [invitedCodPredicate_test evaluateWithObject:url] ||
    [invitedCodPredicate_temp evaluateWithObject:url];
}

@end

