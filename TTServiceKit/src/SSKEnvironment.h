//
//  SSKEnvironment.h
//  TTServiceKit
//
//  Created by Felix on 2022/1/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//@class AccountManager;
@class OWSMessageFetcherJob;
@class OWSSignalService;
@class OWSMessageManager;
@class DTConversationPreviewManager;
@class SDSDatabaseStorage;
@class StorageCoordinator;
@class OWSMessageDecrypter;
@class OWSMessageSender;
@class OWSBlockingManager;
@class MessageProcessor;
@class ConversationPreviewProcessor;
@class OWSMessagePipelineSupervisor;

@class AccountServiceClient;
@class NetworkManager;
@class TSAccountManager;

@class StorageCoordinator;
@class SSKPreferences;
@class ModelReadCaches;

@class PhoneNumberUtil;

@class SocketManager;
@class WebSocketFactoryHybrid;

@protocol WebSocketFactory;
@protocol NotificationsProtocol;
@protocol ContactsManagerProtocol;

@interface SSKEnvironment : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, readonly, class) SSKEnvironment *shared;


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
                          phoneNumberUtil:(PhoneNumberUtil *)phoneNumberUtil;;

+ (void)setShared:(SSKEnvironment *)env;

+ (BOOL)hasShared;

@property (nonatomic, readonly) OWSMessageFetcherJob *messageFetcherJobRef;
@property (nonatomic, readonly) OWSMessageDecrypter *messageDecrypterRef;
@property (nonatomic, readonly) OWSMessageManager *messageManagerRef;
@property (nonatomic, readonly) DTConversationPreviewManager *conversationPreviewManagerRef;
@property (nonatomic, readonly) OWSSignalService *signalService;
@property (nonatomic, readonly) SDSDatabaseStorage *databaseStorageRef;
@property (nonatomic, readonly) StorageCoordinator *storageCoordinatorRef;
@property (nonatomic, readonly) OWSMessageSender *messageSenderRef;
@property (nonatomic, readonly) OWSBlockingManager *blockManagerRef;
@property (nonatomic, readonly) MessageProcessor *messageProcessorRef;
@property (nonatomic, readonly) ConversationPreviewProcessor *conversationProcessorRef;
@property (nonatomic, readonly) OWSMessagePipelineSupervisor *messagePipelineSupervisorRef;
@property (nonatomic, readonly) SSKPreferences *sskPreferencesRef;
@property (nonatomic, readonly) ModelReadCaches *modelReadCachesRef;
@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManagerRef;

//@property (nonatomic, readonly) AccountServiceClient *accountServiceClientRef;
@property (nonatomic, readonly) NetworkManager *networkManagerRef;
@property (nonatomic, readonly) TSAccountManager *tsAccountManagerRef;

@property (nonatomic, readonly) SocketManager *socketManagerRef;
@property (nonatomic, readonly) id<WebSocketFactory> webSocketFactoryRef;

// This property is configured after Environment is created.
@property (atomic, readwrite) id<NotificationsProtocol> notificationsManagerRef;
@property (nonatomic, readonly) PhoneNumberUtil *phoneNumberUtilRef;

@end

NS_ASSUME_NONNULL_END
