//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AppSetup.h"
#import "Environment.h"
#import "Release.h"
#import "VersionMigrations.h"
//#import <AxolotlKit/SessionCipher.h>
//
#import <TTMessaging/OWSProfileManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/OWSBackgroundTask.h>
//
#import <TTServiceKit/TextSecureKitEnv.h>
#import <TTServiceKit/SSKEnvironment.h>
#import <TTServiceKit/StorageCoordinator.h>
#import <TTServiceKit/OWSMessageManager.h>
#import <TTServiceKit/DTConversationPreviewManager.h>
#import <SignalCoreKit/Threading.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AppSetup

+ (void)setupEnvironmentWithAppSpecificSingletonBlock:(dispatch_block_t)appSpecificSingletonBlock
                                  migrationCompletion:(dispatch_block_t)migrationCompletion
{
    OWSAssertDebug(appSpecificSingletonBlock);
    OWSAssertDebug(migrationCompletion);
    
    [self suppressUnsatisfiableConstraintLogging];

    __block OWSBackgroundTask *_Nullable backgroundTask =
        [OWSBackgroundTask backgroundTaskWithLabelStr:__PRETTY_FUNCTION__];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Order matters here.
        [[OWSBackgroundTaskManager sharedManager] observeNotifications];
        
        StorageCoordinator *storageCoordinator = [StorageCoordinator new];
        ModelReadCaches *modelReadCaches =
            [[ModelReadCaches alloc] initWithModelReadCacheFactory:[ModelReadCacheFactory new]];
        SSKPreferences *sskPreferences = [SSKPreferences new];
        OWSContactsManager *contactsManager = [OWSContactsManager new];
        SDSDatabaseStorage *databaseStorage = storageCoordinator.nonGlobalDatabaseStorage;

        // AFNetworking (via CFNetworking) spools it's attachments to NSTemporaryDirectory().
        // If you receive a media message while the device is locked, the download will fail if the temporary directory
        // is NSFileProtectionComplete
        BOOL success;
        NSString *temporaryDirectory = NSTemporaryDirectory();
        success = [OWSFileSystem ensureDirectoryExists:temporaryDirectory];
        OWSAssert(success);
        success = [OWSFileSystem protectFileOrFolderAtPath:temporaryDirectory
                                        fileProtectionType:NSFileProtectionCompleteUntilFirstUserAuthentication];
        OWSAssert(success);
        
//        OWSContactsManager *contactsManager = [OWSContactsManager new];
        ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];
                
        OWSMessageSender *messageSender = [[OWSMessageSender alloc] initWithContactsManager:contactsManager
                                                                           contactsUpdater:contactsUpdater];
        
        [Environment setShared:[[Environment alloc] initWithContactsManager:contactsManager
                                                             contactsUpdater:contactsUpdater]];
        
        TextSecureKitEnv *sharedEnv = [[TextSecureKitEnv alloc] initWithContactsManager:contactsManager
                                                                          messageSender:messageSender
                                                                         profileManager:OWSProfileManager.sharedManager];
        [TextSecureKitEnv setSharedEnv:sharedEnv];
        
        OWSMessageFetcherJob *messageFetcher = [OWSMessageFetcherJob new];
        OWSMessageDecrypter *messageDecrypter = [OWSMessageDecrypter new];
        OWSMessageManager *messageManager = [OWSMessageManager sharedManager];
        DTConversationPreviewManager *conversationPreviewManager = [DTConversationPreviewManager sharedManager];
        OWSSignalService * signalService = [OWSSignalService sharedInstance];
        
        OWSBlockingManager *blockManager = [OWSBlockingManager sharedManager];
        MessageProcessor *messageProcessor = [MessageProcessor new];
        ConversationPreviewProcessor *conversationProcessor = [ConversationPreviewProcessor new];
        OWSMessagePipelineSupervisor *messagePipelineSupervisor = [OWSMessagePipelineSupervisor createStandardSupervisor];
        NetworkManager *networkManager = [NetworkManager sharedInstance];
        TSAccountManager *accountManager = [TSAccountManager sharedInstance];
        
        SocketManager *socketManager = [[SocketManager alloc] init];
        WebSocketFactoryHybrid *webSocketFactory = [WebSocketFactoryHybrid new];
        
        PhoneNumberUtil *phoneNumberUtil = [PhoneNumberUtil new];
        
        SSKEnvironment *sskEnvironment = [[SSKEnvironment alloc] initWithMessageFetcherJob:messageFetcher
                                                                          messageDecrypter:messageDecrypter
                                                                            messageManager:messageManager
                                                                conversationPreviewManager:conversationPreviewManager
                                                                             signalService:signalService
                                                                           databaseStorage:databaseStorage
                                                                        storageCoordinator:storageCoordinator
                                                                           modelReadCaches:modelReadCaches
                                                                            sskPreferences:sskPreferences
                                                                           contactsManager:contactsManager
                                                                             messageSender:messageSender
                                                                              blockManager:blockManager
//                                                                      accountServiceClient:accountServiceClient
                                                                            networkManager:networkManager
                                                                            accountManager:accountManager
                                                                          messageProcessor:messageProcessor
                                                                     conversationProcessor:conversationProcessor
                                                                 messagePipelineSupervisor:messagePipelineSupervisor
                                                                             socketManager:socketManager
                                                                          webSocketFactory:webSocketFactory
                                                                           phoneNumberUtil:phoneNumberUtil];
        
        [SSKEnvironment setShared:sskEnvironment];
        

                
        !appSpecificSingletonBlock ? : appSpecificSingletonBlock();

        // Register renamed classes.
        //MARK GRDB need to focus on
        [NSKeyedUnarchiver setClass:[OWSUserProfile class] forClassName:[OWSUserProfile collection]];
//        [NSKeyedUnarchiver setClass:[OWSDatabaseMigration class] forClassName:[OWSDatabaseMigration collection]];

        
        // Prevent device from sleeping during migrations.
        // This protects long migrations (e.g. the YDB-to-GRDB migration)
        // from the iOS 13 background crash.
        //
        // We can use any object.
        NSObject *sleepBlockObject = [NSObject new];
        [DeviceSleepManager.shared addBlockWithBlockObject:sleepBlockObject];
        
        dispatch_block_t completionBlock = ^{
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                if (AppSetup.shouldTruncateGrdbWal) {
                    // Try to truncate GRDB WAL before any readers or writers are
                    // active.
                    NSError *_Nullable error;
                    [databaseStorage.grdbStorage syncTruncatingCheckpointAndReturnError:&error];
                    if (error != nil) {
                        OWSFailDebug(@"Failed to truncate database: %@", error);
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [storageCoordinator markStorageSetupAsComplete];

                    // Don't start database migrations until storage is ready.
                    [VersionMigrations performUpdateCheckWithCompletion:^() {
                        OWSAssertIsOnMainThread();

                        [DeviceSleepManager.shared removeBlockWithBlockObject:sleepBlockObject];

                        //MARK GRDB need to focus on
//                        [SSKEnvironment.shared warmCaches];
                        migrationCompletion();

                        OWSAssertDebug(backgroundTask);
                        backgroundTask = nil;
                    }];
                });

                // Do this after we've let the main thread know that storage setup is complete.
                if (SSKDebugFlags.internalLogging) {
                    [SDSKeyValueStore logCollectionStatistics];
                }
                
            });
        };
        
        completionBlock();
    });
}

+ (void)suppressUnsatisfiableConstraintLogging
{
    [CurrentAppContext().appUserDefaults setValue:@(SSKDebugFlags.internalLogging)
                                             forKey:@"_UIConstraintBasedLayoutLogUnsatisfiable"];
}

+ (BOOL)shouldTruncateGrdbWal
{
    if (!CurrentAppContext().isMainApp) {
        return NO;
    }
    if (CurrentAppContext().mainApplicationStateOnLaunch == UIApplicationStateBackground) {
        return NO;
    }
    return YES;
}

@end

NS_ASSUME_NONNULL_END
