//
//  DTTranslateOpreation.m
//  TTServiceKit
//
//  Created by hornet on 2022/3/30.
//

#import "DTTranslateOpreation.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSOutgoingMessage.h"
#import "DTCombinedForwardingMessage.h"
#import "DTTranslateApi.h"
//
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSAttachmentStream.h"
#import "MIMETypeUtil.h"
#import "OWSAttachmentsProcessor.h"
#import "TSAttachmentPointer.h"
#import "NSError+MessageSending.h"

@interface DTTranslateOpreation ()

@property (nonatomic, strong) TSThread *thread;
@property (nonatomic, strong) TSMessage *message;
@property (nonatomic, strong) DTTranslateMessage *translateMessage;
@property (nonatomic, strong) NSString *contents;
@property (nonatomic, assign) DTTranslateMessageType translateSettingType;
@property (nonatomic, strong) DTTranslateEntity * _Nonnull entity;

@end

@implementation DTTranslateOpreation
- (instancetype)initWithThread:(TSThread *)thread message:(TSMessage *)message {
    self = [super init];
    if (self) {
        _thread = thread;
        _message = message;
        self.remainingRetries = 3;
        self.translateSettingType = (DTTranslateMessageType)[self.thread.translateSettingType intValue];
        self.contents = [self.translateApi getTargetTranferContents:self.message];
        self.qualityOfService = NSQualityOfServiceDefault;
        self.queuePriority = NSOperationQueuePriorityNormal;
    }
    return self;
}

- (void)run {
    [self startRequest];
}
- (void)startRequest {
    self.translateMessage = [DTTranslateMessage new];
    
//    OWSLogInfo(@"startRequest:::: messageTimestamp %llu",self.message.timestampForSorting);
    
    OWSLogDebug(@"[Translate] -2- start operation message:%llu", self.message.timestampForSorting);
    
    @weakify(self);
    [self.translateApi sendRequestWithSourceLang:nil
                                      targetLang:self.translateSettingType
                                        contents:self.contents
                                          thread:self.thread
                                    attachmentId:self.message.attachmentIds.firstObject
                                         success:^(DTTranslateEntity * _Nonnull entity) {
        @strongify(self);
        self.entity = entity;
        __block TSMessage *tmpMessage = nil;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
            tmpMessage = [TSMessage anyFetchMessageWithUniqueId:self.message.uniqueId transaction:transaction];
        }];
        if (tmpMessage.translateMessage) {
            self.translateMessage = tmpMessage.translateMessage;
        }
        if ([tmpMessage isKindOfClass:TSIncomingMessage.class] || [tmpMessage isKindOfClass:TSOutgoingMessage.class]) {
            DTTranslateSingleEntity *translateSingleEntity;
            if (entity && entity.data) {
                translateSingleEntity = entity.data;
            }
            if (translateSingleEntity) {
                [self reportSuccess];
            } else {
                NSError *error = [NSError errorWithDomain:@"DTTranslateOpreation domain" code:000000 userInfo:nil];
                error.isRetryable = YES;
                [self reportError:error];
            }
        }else{
            NSError *error = [NSError errorWithDomain:@"DTTranslateOpreation domain" code:000000 userInfo:nil];
            error.isRetryable = NO;
            error.isFatal = YES;
            [self reportError:error];
            return;
        }
    } failure:^(NSError * _Nonnull error) {
        @strongify(self);
        error.isRetryable = YES;
        [self reportError:error];
    }];
}

- (void)didFailWithError:(NSError *)error {
    self.translateMessage.translatedState = @(DTTranslateMessageStateTypeFailed);
    self.translateMessage.translateTipMessage = Localized(@"TRANSLATE_TIP_MESSAGE_FAILED", @"");
    self.translateMessage.translatedType = @(self.translateSettingType);
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                
        [self.message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
            messageCopy.translateMessage = self.translateMessage;
        }];
    });
}

- (void)didSucceed {
    //过滤掉同种语言 或则翻译结果是同一个的情况
    DTTranslateSingleEntity *translateSingleEntity;
    if (self.entity && self.entity.data) {
        translateSingleEntity = self.entity.data;
    }
    if ([self.contents isEqualToString:translateSingleEntity.translatedText]) {
        self.translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
        self.translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            [self.message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
                messageCopy.translateMessage = self.translateMessage;
            }];
        });
        return;
    }
    self.translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
    switch (self.translateSettingType) {
        case DTTranslateMessageTypeOriginal:self.translateMessage.translatedType = @(self.translateSettingType);break;
            
        case DTTranslateMessageTypeEnglish:{
            self.translateMessage.translatedType = @(self.translateSettingType);
            self.translateMessage.tranEngLishResult = translateSingleEntity.translatedText;
        }
            break;
        case DTTranslateMessageTypeChinese:{
            self.translateMessage.translatedType = @(self.translateSettingType);
            self.translateMessage.tranChinseResult = translateSingleEntity.translatedText;
        }
            break;
        default:
            self.translateMessage.translatedType = @(self.translateSettingType);
            break;
    }
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        [self.message anyUpdateMessageWithTransaction:writeTransaction block:^(TSMessage * _Nonnull messageCopy) {
            messageCopy.translateMessage = self.translateMessage;
        }];
    });
}

- (DTTranslateApi *)translateApi {
    
    return [DTTranslateProcessor sharedInstance].translateApi;
}

@end
