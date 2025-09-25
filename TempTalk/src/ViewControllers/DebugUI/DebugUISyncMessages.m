//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DebugUISyncMessages.h"
#import "DebugUIContacts.h"
#import "OWSTableViewController.h"
#import "TempTalk-Swift.h"
#import "ThreadUtil.h"
//#import <AxolotlKit/PreKeyBundle.h>
#import <SignalCoreKit/Randomness.h>
#import <TTMessaging/Environment.h>
//#import <TTServiceKit/OWSBatchMessageProcessor.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/OWSDisappearingConfigurationUpdateInfoMessage.h>
#import <TTServiceKit/OWSDisappearingMessagesConfiguration.h>
////#import <TTServiceKit/OWSPrimaryStorage+SessionStore.h>
#import <TTServiceKit/OWSReadReceiptManager.h>
#import <TTServiceKit/OWSSyncConfigurationMessage.h>
#import <TTServiceKit/OWSSyncContactsMessage.h>
#import <TTServiceKit/OWSSyncGroupsMessage.h>
//#import <TTServiceKit/OWSSyncGroupsRequestMessage.h>
#import <TTServiceKit/OWSVerificationStateChangeMessage.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/TSIncomingMessage.h>
//#import <TTServiceKit/TSInvalidIdentityKeyReceivingErrorMessage.h>
#import <TTServiceKit/TSThread.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DebugUISyncMessages

#pragma mark - Factory Methods

/*
- (NSString *)name
{
    return @"Sync Messages";
}

- (nullable OWSTableSection *)sectionForThread:(nullable TSThread *)thread
{
    NSArray<OWSTableItem *> *items = @[
        [OWSTableItem itemWithTitle:@"Send Contacts Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendContactsSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Groups Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendGroupSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Blocklist Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendBlockListSyncMessage];
                        }],
        [OWSTableItem itemWithTitle:@"Send Configuration Sync Message"
                        actionBlock:^{
                            [DebugUISyncMessages sendConfigurationSyncMessage];
                        }],
    ];
    return [OWSTableSection sectionWithTitle:self.name items:items];
}

+ (OWSMessageSender *)messageSender
{
    return Environment.shared.messageSender;
}

+ (OWSContactsManager *)contactsManager
{
    return Environment.shared.contactsManager;
}

+ (OWSIdentityManager *)identityManager
{
    return [OWSIdentityManager sharedManager];
}

+ (OWSBlockingManager *)blockingManager
{
    return [OWSBlockingManager sharedManager];
}

+ (OWSProfileManager *)profileManager
{
    return [OWSProfileManager sharedManager];
}

+ (YapDatabaseConnection *)dbConnection
{
    return [OWSPrimaryStorage.sharedManager newDatabaseConnection];
}

+ (void)sendContactsSyncMessage
{
    OWSSyncContactsMessage *syncContactsMessage =
        [[OWSSyncContactsMessage alloc] initWithSignalAccounts:self.contactsManager.signalAccounts
                                               identityManager:self.identityManager
                                                profileManager:self.profileManager];
    __block id <DataSource> dataSource;
    [self.dbConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *_Nonnull transaction) {
        NSError *error;
        dataSource = [DataSourcePath
                       dataSourceWritingSyncMessageData:[syncContactsMessage
                                                         buildPlainTextAttachmentDataWithTransaction:transaction] error:&error];
        if (error) {
            OWSLogError(@"%@", error);
        }
    }];

    [self.messageSender enqueueTemporaryAttachment:dataSource
        contentType:OWSMimeTypeApplicationOctetStream
        inMessage:syncContactsMessage
        success:^{
            OWSLogInfo(@"%@ Successfully sent Contacts response syncMessage.", self.logTag);
        }
        failure:^(NSError *error) {
            OWSLogError(@"%@ Failed to send Contacts response syncMessage with error: %@", self.logTag, error);
        }];
}

+ (void)sendGroupSyncMessage
{
    OWSSyncGroupsMessage *syncGroupsMessage = [[OWSSyncGroupsMessage alloc] init];
    __block id <DataSource> dataSource;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        NSError *error;
        dataSource = [DataSourcePath
            dataSourceWritingSyncMessageData:[syncGroupsMessage buildPlainTextAttachmentDataWithTransaction:transaction] error:&error];
        if (error) {
            OWSLogError(@"%@", error);
        }
    }];
    [self.messageSender enqueueTemporaryAttachment:dataSource
        contentType:OWSMimeTypeApplicationOctetStream
        inMessage:syncGroupsMessage
        success:^{
            OWSLogInfo(@"%@ Successfully sent Groups response syncMessage.", self.logTag);
        }
        failure:^(NSError *error) {
            OWSLogError(@"%@ Failed to send Groups response syncMessage with error: %@", self.logTag, error);
        }];
}

+ (void)sendBlockListSyncMessage
{
    [self.blockingManager syncBlockedPhoneNumbers];
}

+ (void)sendConfigurationSyncMessage
{
    __block BOOL areReadReceiptsEnabled;
    [self.dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        areReadReceiptsEnabled =
            [[OWSReadReceiptManager sharedManager] areReadReceiptsEnabledWithTransaction:transaction];
    }];

    OWSSyncConfigurationMessage *syncConfigurationMessage =
        [[OWSSyncConfigurationMessage alloc] initWithReadReceiptsEnabled:areReadReceiptsEnabled];
    [self.messageSender enqueueMessage:syncConfigurationMessage
        success:^{
            OWSLogInfo(@"%@ Successfully sent Configuration response syncMessage.", self.logTag);
        }
        failure:^(NSError *error) {
            DDLogError(@"%@ Failed to send Configuration response syncMessage with error: %@", self.logTag, error);
        }];
}
*/

@end

NS_ASSUME_NONNULL_END
