//
//  SSKEnvironment.m
//  TTServiceKit
//
//  Created by Felix on 2022/1/17.
//

#import "SSKEnvironment.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "OWSMessageManager.h"
#import "OWSSignalService.h"

static SSKEnvironment *sharedSSKEnvironment;

@interface SSKEnvironment ()

@property (nonatomic) OWSMessageFetcherJob *messageFetcherJob;
@property (nonatomic) OWSMessageDecrypter *messageDecrypterRef;
@property (nonatomic) OWSMessageManager *messageManagerRef;
@property (nonatomic) DTConversationPreviewManager *conversationPreviewManagerRef;
@property (nonatomic) OWSSignalService *signalService;
@property (nonatomic) SDSDatabaseStorage *databaseStorageRef;
@property (nonatomic) OWSMessageSender *messageSenderRef;
@property (nonatomic) OWSBlockingManager *blockManagerRef;
@property (nonatomic) OWSMessagePipelineSupervisor *messagePipelineSupervisorRef;

//@property (nonatomic) AccountServiceClient *accountServiceClientRef;
@property (nonatomic) NetworkManager *networkManagerRef;
@property (nonatomic) TSAccountManager *tsAccountManagerRef;

@property (nonatomic) ConversationPreviewProcessor *conversationProcessorRef;

@property (nonatomic) StorageCoordinator *storageCoordinatorRef;
@property (nonatomic) SSKPreferences *sskPreferencesRef;
@property (nonatomic) ModelReadCaches *modelReadCachesRef;
@property (nonatomic) id<ContactsManagerProtocol> contactsManagerRef;

@property (nonatomic) SocketManager *socketManagerRef;
@property (nonatomic) id<WebSocketFactory> webSocketFactoryRef;

@property (nonatomic) PhoneNumberUtil *phoneNumberUtilRef;

@end

@implementation SSKEnvironment

@synthesize notificationsManagerRef = _notificationsManagerRef;

- (instancetype)initWithMessageFetcherJob:(OWSMessageFetcherJob *)messageFetcherJob
                         messageDecrypter:(OWSMessageDecrypter *)messageDecrypter
                           messageManager:(OWSMessageManager *)messageManager
               conversationPreviewManager:(DTConversationPreviewManager *)conversationPreviewManager
                            signalService:(OWSSignalService *)signalService
                          databaseStorage:(SDSDatabaseStorage *)databaseStorage
                       storageCoordinator:(StorageCoordinator *)storageCoordinator
                          modelReadCaches:(ModelReadCaches *)modelReadCaches
                           sskPreferences:(SSKPreferences *)sskPreferences
                          contactsManager:(id<ContactsManagerProtocol>)contactsManager
                            messageSender:(OWSMessageSender *)messageSender
                             blockManager:(OWSBlockingManager *)blockManager
//                     accountServiceClient:(AccountServiceClient *)accountServiceClient
                           networkManager:(NetworkManager *)networkManager
                           accountManager:(TSAccountManager *)tsAccountManager
                         messageProcessor:(MessageProcessor *)messageProcessor
                    conversationProcessor:(ConversationPreviewProcessor *)conversationProcessor
                messagePipelineSupervisor:(OWSMessagePipelineSupervisor *)messagePipelineSupervisor
                            socketManager:(SocketManager *)socketManager
                         webSocketFactory:(WebSocketFactoryHybrid *)webSocketFactory
                          phoneNumberUtil:(PhoneNumberUtil *)phoneNumberUtil
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    OWSAssertDebug(messageFetcherJob);
    OWSAssertDebug(messageDecrypter);
    OWSAssertDebug(signalService);
    OWSAssertDebug(databaseStorage);
    OWSAssertDebug(modelReadCaches);
    OWSAssertDebug(storageCoordinator);
    OWSAssertDebug(messageSender);
    OWSAssertDebug(blockManager);
//    OWSAssertDebug(accountServiceClient);
    OWSAssertDebug(networkManager);
    OWSAssertDebug(tsAccountManager);
    OWSAssertDebug(messageProcessor);
    OWSAssertDebug(messagePipelineSupervisor);
    OWSAssertDebug(phoneNumberUtil);
    
    
    _messageFetcherJobRef = messageFetcherJob;
    _messageDecrypterRef = messageDecrypter;
    _messageManagerRef = messageManager;
    _conversationPreviewManagerRef = conversationPreviewManager;
    _signalService = signalService;
    _databaseStorageRef = databaseStorage;
    _messageSenderRef = messageSender;
    _blockManagerRef = blockManager;
    _messageProcessorRef = messageProcessor;
    _conversationProcessorRef = conversationProcessor;
    _messagePipelineSupervisorRef = messagePipelineSupervisor;
    
//    _accountServiceClientRef = accountServiceClient;
    _networkManagerRef = networkManager;
    _tsAccountManagerRef = tsAccountManager;
    
    //GRDB-kris--
    _storageCoordinatorRef = storageCoordinator;
    _sskPreferencesRef = sskPreferences;
    _modelReadCachesRef = modelReadCaches;
    _contactsManagerRef = contactsManager;
    //--
    _socketManagerRef = socketManager;
    _webSocketFactoryRef = webSocketFactory;
    _phoneNumberUtilRef = phoneNumberUtil;
    
    return self;
}

+ (instancetype)shared {
    OWSAssertDebug(sharedSSKEnvironment);

    return sharedSSKEnvironment;
}

+ (BOOL)hasShared {
    return sharedSSKEnvironment != nil;
}

+ (void)setShared:(SSKEnvironment *)env {
    OWSAssertDebug(env);
    OWSAssertDebug(!sharedSSKEnvironment || CurrentAppContext().isRunningTests);

    sharedSSKEnvironment = env;
}


#pragma mark - Mutable Accessors

- (id<NotificationsProtocol>)notificationsManagerRef
{
    @synchronized(self) {
        OWSAssertDebug(_notificationsManagerRef);

        return _notificationsManagerRef;
    }
}

- (void)setNotificationsManagerRef:(id<NotificationsProtocol>)notificationsManagerRef
{
    @synchronized(self) {
        OWSAssertDebug(notificationsManagerRef);
        OWSAssertDebug(!_notificationsManagerRef);

        _notificationsManagerRef = notificationsManagerRef;
    }
}

@end
