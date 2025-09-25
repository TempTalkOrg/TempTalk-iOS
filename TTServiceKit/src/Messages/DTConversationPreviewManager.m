//
//  DTConversationPreviewManager.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/8/8.
//

#import "DTConversationPreviewManager.h"
#import "DTParamsBaseUtils.h"
#import "TSContactThread.h"
#import "TSGroupThread.h"
#import "TSMessageReadPosition.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "NSDate+OWS.h"
#import "DTConversationPriorityAPI.h"
#import <TTServiceKit/AppReadiness.h>

@interface DTConversationPreviewManager ()

@property (nonatomic, strong) DTConversationPriorityAPI *conversationPriorityAPI;

@end

@implementation DTConversationPreviewManager

- (instancetype)init{
    if(self = [super init]){
        self.needReportConversation = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActive:)
                                                     name:OWSApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

+ (instancetype)sharedManager
{
    static DTConversationPreviewManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (DTConversationPriorityAPI *)conversationPriorityAPI{
    if(!_conversationPriorityAPI){
        _conversationPriorityAPI = [DTConversationPriorityAPI new];
    }
    return _conversationPriorityAPI;
}

- (void)processConversationPreviewProto:(DSKProtoConversationPreview *)conversationPreviewProto
                            transaction:(SDSAnyWriteTransaction *)writeTransaction{
    
    if (!conversationPreviewProto.conversationID){
        OWSProdError(@"conversationId is empty.")
        return;
    }
    
    DSKProtoConversationId *conversationId = conversationPreviewProto.conversationID;
    TSThread *thread = nil;
    if(conversationId.hasNumber && DTParamsUtils.validateString(conversationId.number)){
        thread = [TSContactThread getOrCreateThreadWithContactId:conversationId.number transaction:writeTransaction];
    }else if(conversationId.hasGroupID && conversationId.groupID && conversationId.groupID.length){
        
        // TODO: 服务端统一 proto 里的 groupId 格式
        if (conversationId.groupID.length == 36) {
            NSString *serverIdString = [[NSString alloc] initWithData:conversationId.groupID encoding:NSUTF8StringEncoding];
            NSData *localGroupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:serverIdString];
            thread = [TSGroupThread getOrCreateThreadWithGroupId:localGroupId transaction:writeTransaction];
        } else {
            thread = [TSGroupThread getOrCreateThreadWithGroupId:conversationId.groupID transaction:writeTransaction];
        }
    }else{
        OWSProdError(@"number and groupId are empty.")
        return;
    }
    
    if (![thread isKindOfClass:TSThread.class]) {
        OWSProdError(@"thread type error.")
        return;
    }
    
    DTReadPositionEntity *readPosition = nil;
    if(conversationPreviewProto.readPosition){
        readPosition = [DTReadPositionEntity readPostionEntityWithProto:conversationPreviewProto.readPosition];
        if(readPosition.maxServerTime <=0 || readPosition.readAt <= 0) {
            readPosition = nil;
            OWSProdError(@"conversationPreview, invalid readPosition: maxServerTime or readAt <= 0!")
        }
    }
    
    if(readPosition){
        OWSLogInfo(@"conversation preview sendReadRecipet:%@", readPosition);
        [OWSReadReceiptManager.sharedManager updateSelfReadPositionEntity:readPosition
                                                                   thread:thread
                                                              transaction:writeTransaction];
    }
    
    
    if(conversationPreviewProto.lastestMsg){
        
        NSError *error;
        DSKProtoContent *content = [[DSKProtoContent alloc] initWithSerializedData:conversationPreviewProto.lastestMsg.content error:&error];
        
        if (!error && content.callMessage == nil) {
            EnvelopeSource envelopeSource = EnvelopeSourceWebsocketConversationIdentified;
            DSKProtoEnvelopeBuilder *lastestMsgBuilder = conversationPreviewProto.lastestMsg.asBuilder;
            lastestMsgBuilder.lastestMsgFlag = YES;
            NSData *encryptedEnvelopeData = [lastestMsgBuilder buildSerializedDataAndReturnError:nil];
            
            [self.messageProcessor processEncryptedEnvelopeData:encryptedEnvelopeData
                                        serverDeliveryTimestamp:[NSDate ows_millisecondTimeStamp]
                                                 envelopeSource:envelopeSource
                                             hotDataDestination:nil
                                                 hotdataMsgFlag:YES
                                                    transaction:writeTransaction
                                                     completion:^(NSError * _Nullable error) {
                if(error){
                    OWSProdError(@"process lastestMsg error.")
                }
            }];
        } else {
            
            OWSLogWarn(@"ignore call message or serialErrir: %@.", error);
        }
    }
}

- (void)setCurrentThread:(TSThread *)currentThread{
    _currentThread = currentThread;
    [self reportConversationWithThread:currentThread];
}

- (void)reportConversationWithThread:(nullable TSThread *)thread{
    
    if(self.needReportConversation){
        NSDictionary *conversationInfo = [self getConversationInfoWithThread:thread];
        
        if (conversationInfo) {
            
            [self.conversationPriorityAPI sendRequestWithParams:conversationInfo
                                                        success:^(DTAPIMetaEntity * _Nonnull entity) {
                OWSLogInfo(@"report conversation(%@) success.", conversationInfo);
            } failure:^(NSError * _Nonnull error) {
                OWSProdError(@"repor conversation error.")
            }];
        }
    }
}

- (NSDictionary *)getConversationInfoWithThread:(TSThread *)thread{
    
    if(!thread) return nil;
    
    NSMutableDictionary *conversationInfo = @{}.mutableCopy;
    if(thread.isGroupThread && DTParamsUtils.validateString(thread.serverThreadId)){
        conversationInfo[@"gid"] = thread.serverThreadId;
    }else if(DTParamsUtils.validateString(thread.contactIdentifier)){
        conversationInfo[@"number"] = thread.contactIdentifier;
    }
    return conversationInfo.copy;
}


- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    AppReadinessRunNowOrWhenAppDidBecomeReadySync(^{
        if ([TSAccountManager isRegistered]) {
            
            [self reportConversationWithThread:self.currentThread];
        }
    });
}

@end
