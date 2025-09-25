//
//  DTTranslateApi.m
//  Wea
//
//  Created by hornet on 2022/1/13.
//

#import "DTTranslateApi.h"
#import "TSAccountManager.h"
#import "DTServersConfig.h"
#import "TSMessage.h"
#import "DTCombinedForwardingMessage.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <objc/runtime.h>

@implementation DTTranslateSingleEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTTranslateEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

+ (NSValueTransformer *)dataJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:DTTranslateSingleEntity.class];
}

@end

#pragma mark - DTTranslateApi
@implementation DTTranslateApi

- (instancetype)init {
    self = [super init];
    if (self) {
        self.serverType = DTServerTypeTranslate;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/whisperX/transcribe";
}

- (void)sendRequestWithSourceLang:(nullable NSString *)sourceLang
                       targetLang:(DTTranslateMessageType)type
                         contents:(NSString *)contents
                           thread:(TSThread *)thread
                     attachmentId:(NSString *)attachmentId
                          success:(DTTranslateSuccessBlock)success
                          failure:(DTTranslateFailureBlock)failure {
    if (DTParamsUtils.validateString(attachmentId)) {
        
        __block TSAttachmentStream *attachmentStream;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *_Nonnull transaction) {
            attachmentStream = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:attachmentId transaction:transaction];
        }];
        
        if (![attachmentStream isVoiceMessage]) {
            return;
        }
        
        [OWSAttachmentsProcessor decryptVoiceAttachment:attachmentStream];
        
        OWSUploadOperation *uploadForwardingAttachmentOperation =
            [[OWSUploadOperation alloc] initWithAttachmentId:attachmentId
                                                recipientIds:@[@"speech2Text"]
                                        allowDuplicateUpload:true];
        uploadForwardingAttachmentOperation.failureHandler = ^(NSError *error) {
            OWSLogError(@"%@ upload attachment error", self.logTag);
            [attachmentStream removeVoicePlaintextFile];
            failure(error);
        };
        uploadForwardingAttachmentOperation.rapidFileInfoBlock = ^(NSDictionary * _Nonnull info) {
            [[DTTokenHelper sharedInstance] asyncFetchGlobalAuthTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
                if (error) {
                    OWSLogError(@"%@ get token error", self.logTag);
                    [attachmentStream removeVoicePlaintextFile];
                    failure(error);
                    return;
                }
                TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                                        method:[self requestMethod]
                                                    parameters:@{
                        @"authorizeId":info[@"authorizedId"],
                        @"key":[attachmentStream.encryptionKey base64EncodedString]
                }];
                request.authToken = token;
                request.serverType = DTServerTypeSpeech2Text;
                
                [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
                    NSError *error;
                    DTAPIMetaEntity *responseEntity = [MTLJSONAdapter modelOfClass:[DTAPIMetaEntity class] fromJSONDictionary:response.responseBodyJson error:&error];
                    DTTranslateSingleEntity *singleEntity = [[DTTranslateSingleEntity alloc] init];
                    NSArray *segments = responseEntity.data[@"segments"];
                    NSMutableString *resultText = [NSMutableString string];
                    for (NSDictionary *segment in segments) {
                        NSString *text = segment[@"text"];
                        if ([text isKindOfClass:[NSString class]]) {
                            [resultText appendString:text];
                        }
                    }
                    singleEntity.translatedText = resultText;
                    DTTranslateEntity *translateEntity = [[DTTranslateEntity alloc] init];
                    translateEntity.data = singleEntity;
                    if (!DTParamsUtils.validateString(resultText)) {
                        [DTToastHelper toastWithText:Localized(@"SPEECHTOTEXT_NO_TEXT_RECOGNIZE",@"") durationTime:2];
                    }
                    if (success) {
                        success(translateEntity);
                        [attachmentStream removeVoicePlaintextFile];
                    }
                } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
                    failure(error.asNSError);
                    [attachmentStream removeVoicePlaintextFile];
                }];
            }];
        };
        [uploadForwardingAttachmentOperation run];
        
    } else {
        // 文本消息
        Class translateTool = NSClassFromString(@"DTTransLateTool");
        if (translateTool) {
            // 创建 TopLayerBusiness 实例
            id translateInstance = [[translateTool alloc] init];
            // 获取方法选择器
            SEL selector = NSSelectorFromString(@"translateWithContent:type:callback:");
            if ([translateInstance respondsToSelector:selector]) {
                // 创建回调闭包
                void (^callback)(NSString *, DTTranslateMessageType) = ^(NSString *response, DTTranslateMessageType type) {
                    DTTranslateSingleEntity *singleEntity = [[DTTranslateSingleEntity alloc] init];
                    singleEntity.translatedText = response;
                    singleEntity.sourceLanguage = @"en-US"; //"zh-CN"
                    DTTranslateEntity *translateEntity = [[DTTranslateEntity alloc] init];
                    translateEntity.data = singleEntity;
                    if (success) {
                        success(translateEntity);
                    }
                };
                // 使用 NSInvocation 调用方法
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[translateInstance methodSignatureForSelector:selector]];
                [invocation setSelector:selector];
                [invocation setTarget:translateInstance];
                [invocation setArgument:&contents atIndex:2];
                [invocation setArgument:&type atIndex:3];
                [invocation setArgument:&callback atIndex:4];
                [invocation invoke];
            } else {
                OWSLogError(@"translateInstance does not respond to the selector");
            }
        } else {
            OWSLogError(@"DTTransLateTool class not found");
        }
    }
}

- (NSString *)transferTargetLangStringWithTranslateSettingType:(DTTranslateMessageType)type {
    switch (type) {
        case DTTranslateMessageTypeChinese:return @"zh-cn";
        case DTTranslateMessageTypeEnglish: return @"en";
        default:return nil;
    }
}

- (NSString *)getTargetTranferContents:(TSMessage *)message {
    NSString *contents = message.body;
    if (message.isSingleForward) {//表示单条转发的消息
        DTCombinedForwardingMessage *forwardingMessage = message.combinedForwardingMessage.subForwardingMessages.firstObject;
        contents = forwardingMessage.body;
    }
    return contents;
}

- (DTTranslateMsgSource)getMsgSource:(TSThread *)thread {
    if (thread.isGroupThread) {
        
        return DTTranslateMsgSourceGroup;
    } else if ([thread isKindOfClass:TSContactThread.class]) {
        TSContactThread *contactThread = (TSContactThread *)thread;
        
        BOOL containsBot = contactThread.recipientsContainsBot;
        if (containsBot) {
            
            NSString *recipientId = contactThread.contactIdentifier;
            NSArray *translateCacheBot = [DTBotConfig serverTranslateCacheBot];
            BOOL containsAnnocumentBot = [translateCacheBot containsObject:recipientId];
            
            if (containsAnnocumentBot) {
                
                return DTTranslateMsgSourceAnnouncement;
            } else {
                
                return DTTranslateMsgSourceNormalBot;
            }
        } else {
            
            return DTTranslateMsgSource1On1;
        }
    } else {
        
        return DTTranslateMsgSourceUnknown;
    }
}

@end
