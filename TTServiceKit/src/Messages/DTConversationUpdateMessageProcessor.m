//
//  DTConversationUpdateMessageProcessor.m
//  TTServiceKit
//
//  Created by hornet on 2022/6/23.
//

#import "DTConversationUpdateMessageProcessor.h"
#import "TSAccountManager.h"
#import "TSThread.h"
#import "DTChatFolderManager.h"
#import "DTGetConversationApi.h"
#import "DTConversationSettingHelper.h"
#import "OWSDevice.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTFetchThreadConfigAPI.h"

NSString *const kConversationUpdateFromSocketMessageNotification = @"kConversationUpdateFromSocketMessageNotification";
NSString *const DTConversationSharingConfigurationChangeNotification = @"kDTconversationSharingConfigurationChangeNotification";

@interface DTConversationUpdateMessageProcessor()

@end


@implementation DTConversationUpdateMessageProcessor
- (void)handleConversationUpdateMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                     display:(BOOL)display
                           conversationNotifyEntity:(DTConversationNotifyEntity *)conversationNotifyEntity
                                        transaction:(SDSAnyWriteTransaction *)transaction {
    //主要用于跨设备的mute状态同步  mac操作->同步给其他设备会通过socket通道的通知触达
    if (conversationNotifyEntity && [conversationNotifyEntity.source isEqualToString:[TSAccountManager sharedInstance].localNumber]) {
        if (conversationNotifyEntity.sourceDeviceId  == [OWSDevice currentDeviceId]) {
            return;
        }
        
        DTConversationEntity *conversationEntity = conversationNotifyEntity.conversation;
        if (!conversationEntity) {
            return;
        }
        
        TSThread *thread = [DTChatFolderManager getOrCreateThreadWithThreadId:conversationEntity.conversation transaction:transaction];
        //跨版本--本地的版本比远端的版本大 丢掉这次推送过来的信息 直接使用最新的mute信息
        if (thread.conversationEntity && thread.conversationEntity.version - conversationEntity.version > 0) {
            //丢弃
        } else if (thread.conversationEntity && conversationEntity.version - thread.conversationEntity.version > 1) {
            //远端的版本比本地的版本大 丢掉这次推送过来的信息 拉取最新的mute信息
            [self requestMuteStatusWithConversationId:conversationEntity.conversation];
        } else if (!thread.conversationEntity && conversationEntity.version > 1) { //跨版本 丢掉这次推送过来的信息 直接拉最新的mute信息
            [self requestMuteStatusWithConversationId:conversationEntity.conversation];
        } else {//走正常保存的逻辑 //同步数据库 刷新页面
            [self saveConversationSettingForThread:thread changeType:conversationNotifyEntity.changeType conversationEntity:conversationEntity trasation:transaction];
        }
    } else {
        OWSLogInfo(@"[DTConversationUpdateMessageProcessor class] ---> conversationNotifyEntity: %@, conversationNotifyEntity.source: %@, localNumber:%@",conversationNotifyEntity, conversationNotifyEntity.source, [TSAccountManager sharedInstance].localNumber);
    }
}

- (void)saveConversationSettingForThread:(TSThread *)thread
                              changeType:(int) changeType
                      conversationEntity:(DTConversationEntity*)conversationEntity
                               trasation:(SDSAnyWriteTransaction *) transaction {
    
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {

        [thread anyUpdateWithTransaction:writeTransaction
                                   block:^(TSThread * instance) {
            instance.conversationEntity = conversationEntity;
            
            [[DataUpdateUtil shared] updateConversationWithThread:instance
                                                       expireTime:conversationEntity.messageExpiry
                                               messageClearAnchor:@(conversationEntity.messageClearAnchor)];
        }];
        
        if([thread isKindOfClass:[TSContactThread class]] && changeType == 2){
            TSContactThread *contactThread = (TSContactThread *)thread;
            SignalAccount *account = [SignalAccount anyFetchWithUniqueId:contactThread.contactIdentifier transaction:writeTransaction];
            if(!account){ OWSLogInfo(@"[DTConversationUpdateMessageProcessor class] account = nil");}
            Contact *contact = account.contact;
            if(!DTParamsUtils.validateString(conversationEntity.remark)){return;}
            NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:contact.remark receptid:contactThread.contactIdentifier];
            if(![contact.remark isEqualToString:remark]){
                contact.remark = remark;
                account.contact = contact;
                id<ContactsManagerProtocol> contactsManager = [TextSecureKitEnv sharedEnv].contactsManager;
                [contactsManager updateSignalAccountWithRecipientId:account.recipientId withNewSignalAccount:account withTransaction:writeTransaction];
            }
        }
        
        [writeTransaction addAsyncCompletionOnMain:^{
            ///changeType 暂时不做细分。0表示mute 1 表示 block
            [[NSNotificationCenter defaultCenter] postNotificationName:kConversationUpdateFromSocketMessageNotification object:nil];
        }];
    });
}

- (void)requestMuteStatusWithConversationId:(NSString *)conversationId {
    if (!conversationId || !conversationId.length) { return;}
    [[DTConversationSettingHelper sharedInstance] requestConversationSettingAndSaveResultWithConversationId:conversationId];
}

- (DTFetchThreadConfigAPI *)fetchThreadConfigAPI {
    if(!_fetchThreadConfigAPI){
        _fetchThreadConfigAPI = [[DTFetchThreadConfigAPI alloc] init];
    }
    return _fetchThreadConfigAPI;
}
@end
