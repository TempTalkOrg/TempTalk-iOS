//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ShowGroupMembersViewController.h"
#import "TempTalk-Swift.h"
#import "SignalApp.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/BlockListUIUtils.h>
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/UIUtil.h>
#import <TTServiceKit/OWSBlockingManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupThread.h>

@import ContactsUI;

NS_ASSUME_NONNULL_BEGIN

@interface ShowGroupMembersViewController ()
<ContactsViewHelperDelegate,
ContactEditingDelegate,
OWSTableViewControllerDelegate>

@property (nonatomic, readonly) TSGroupThread *thread;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;

@property (nonatomic, nullable) NSSet<NSString *> *memberRecipientIds;

@end

#pragma mark -

@implementation ShowGroupMembersViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;

    [self observeNotifications];
    self.delegate = self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
}

- (void)configWithThread:(TSGroupThread *)thread
{

    _thread = thread;

    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMemberIds);

    self.memberRecipientIds = [NSSet setWithArray:self.thread.groupModel.groupMemberIds];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    OWSAssertDebug([self.navigationController isKindOfClass:[OWSNavigationController class]]);

    self.title = Localized(@"LIST_GROUP_MEMBERS_ACTION", @"title for show group members view");

    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 45;

    [self updateTableContents];
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSAssertDebug(self.thread);

    OWSTableContents *contents = [OWSTableContents new];

    __weak ShowGroupMembersViewController *weakSelf = self;
    OWSTableSection *membersSection = [OWSTableSection new];
    membersSection.headerTitle = Localized(@"LIST_GROUP_MEMBERS_PARTICIPANTS",
                                                   @"Title for the 'no longer verified' section of the 'group members' view.");
    
    OWSTableSection *moderatorsSection = [OWSTableSection new];
    moderatorsSection.headerTitle = Localized(@"LIST_GROUP_MEMBERS_MODERATORS",
                                                      @"Title for the 'no longer verified' section of the 'group members' view.");
    // Group Members

    // If there are "no longer verified" members of the group,
    // highlight them in a special section.
    NSArray<NSString *> *noLongerVerifiedRecipientIds = [self noLongerVerifiedRecipientIds];
    if (noLongerVerifiedRecipientIds.count > 0) {
        OWSTableSection *noLongerVerifiedSection = [OWSTableSection new];
        noLongerVerifiedSection.headerTitle = Localized(@"GROUP_MEMBERS_SECTION_TITLE_NO_LONGER_VERIFIED",
            @"Title for the 'no longer verified' section of the 'group members' view.");
        membersSection.headerTitle = Localized(
            @"GROUP_MEMBERS_SECTION_TITLE_MEMBERS", @"Title for the 'members' section of the 'group members' view.");
        [noLongerVerifiedSection
            addItem:[OWSTableItem disclosureItemWithText:Localized(@"GROUP_MEMBERS_RESET_NO_LONGER_VERIFIED",
                                                             @"Label for the button that clears all verification "
                                                             @"errors in the 'group members' view.")
                                         customRowHeight:UITableViewAutomaticDimension
                                             actionBlock:^{
                                                 [weakSelf offerResetAllNoLongerVerified];
                                             }]];
        [self addMembers:noLongerVerifiedRecipientIds toSection:noLongerVerifiedSection useVerifyAction:YES];
        [contents addSection:noLongerVerifiedSection];
    }
    NSMutableSet *memberRecipientIds = [self.memberRecipientIds mutableCopy];
    //    MODERATORS
    NSMutableArray *moderatorsArr = [NSMutableArray array];
    NSString *owerId = self.thread.groupModel.groupOwner;
    if (owerId && owerId.length) {
        [moderatorsArr addObject:owerId];
    }
    if (self.thread.groupModel.groupAdmin) {
        [self.thread.groupModel.groupAdmin enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj) {
                [moderatorsArr addObject:obj];
            }
        }];
    }
    
    NSMutableArray *membersArr = [NSMutableArray array];
    NSMutableArray *tmpArr = [memberRecipientIds.allObjects mutableCopy];
    for (NSString *receptId in moderatorsArr) {
        if ([tmpArr containsObject:receptId]) {
            [tmpArr removeObject:receptId];
        }
    }
    membersArr = tmpArr;
    [self addMembers:moderatorsArr toSection:moderatorsSection useVerifyAction:NO];
    [self addMembers:membersArr toSection:membersSection useVerifyAction:NO];
    if (moderatorsArr.count > 0) {
        [contents addSection:moderatorsSection];
    }
    if (membersArr.count >0) {
        [contents addSection:membersSection];
    }
    self.contents = contents;
}

- (void)addMembers:(NSArray<NSString *> *)recipientIds
          toSection:(OWSTableSection *)section
    useVerifyAction:(BOOL)useVerifyAction
{
    OWSAssertDebug(recipientIds);
    OWSAssertDebug(section);

    __weak ShowGroupMembersViewController *weakSelf = self;
    ContactsViewHelper *helper = self.contactsViewHelper;
    // Sort the group members using contacts manager.
    
    __block NSArray<NSString *> *sortedRecipientIds = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        
        sortedRecipientIds = [recipientIds sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull recipientIdA, id  _Nonnull recipientIdB) {
            SignalAccount *signalAccountA = [helper.contactsManager signalAccountForRecipientId:recipientIdA transaction:readTransaction];
            SignalAccount *signalAccountB = [helper.contactsManager signalAccountForRecipientId:recipientIdB transaction:readTransaction];
            return [helper.contactsManager compareSignalAccount:signalAccountA withSignalAccount:signalAccountB];
        }];
    }];
    
    TSGroupModel *groupModel = ((TSGroupThread *)self.thread).groupModel;
    NSString *groupOwnerID = groupModel.groupOwner;
    if (groupOwnerID) {
        NSMutableArray *mutableSortedRecipientIds = sortedRecipientIds.mutableCopy;
        if ([sortedRecipientIds containsObject:groupOwnerID]) {
            [mutableSortedRecipientIds removeObject:groupOwnerID];
            [mutableSortedRecipientIds insertObject:groupOwnerID atIndex:0];
        }
        sortedRecipientIds = mutableSortedRecipientIds.copy;
    }

    for (NSString *recipientId in sortedRecipientIds) {
        [section addItem:[OWSTableItem
                             itemWithCustomCellBlock:^{
                                 ShowGroupMembersViewController *strongSelf = weakSelf;
                                 OWSCAssertDebug(strongSelf);

                                 ContactTableViewCell *cell = [ContactTableViewCell new];
                                 SignalAccount *signalAccount = [helper signalAccountForRecipientId:recipientId];
            
                                 if (signalAccount) {
                                     cell.cellView.type = UserOfSelfIconTypeRealAvater;
                                     [cell configureWithThread:self.thread signalAccount:signalAccount contactsManager:helper.contactsManager];
                                 } else {
                                     cell.cellView.type = UserOfSelfIconTypeRealAvater;
                                     [cell configureWithThread:self.thread recipientId:recipientId contactsManager:helper.contactsManager];
                                 }

                                 return cell;
                             }
                             customRowHeight:70
                             actionBlock:^{
                                 if (useVerifyAction) {
                                     [weakSelf showSafetyNumberView:recipientId];
                                 } else {
                                     [weakSelf showContactInfoViewForRecipientId:recipientId];
                                 }
                             }]];
    }
}

- (void)offerResetAllNoLongerVerified
{
    OWSAssertIsOnMainThread();

    UIAlertController *actionSheetController = [UIAlertController
        alertControllerWithTitle:nil
                         message:Localized(@"GROUP_MEMBERS_RESET_NO_LONGER_VERIFIED_ALERT_MESSAGE",
                                     @"Label for the 'reset all no-longer-verified group members' confirmation alert.")
                  preferredStyle:UIAlertControllerStyleAlert];

    __weak ShowGroupMembersViewController *weakSelf = self;
    UIAlertAction *verifyAction = [UIAlertAction actionWithTitle:Localized(@"OK", nil)
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction *_Nonnull action) {
                                                             [weakSelf resetAllNoLongerVerified];
                                                         }];
    [actionSheetController addAction:verifyAction];
    [actionSheetController addAction:[OWSAlerts cancelAction]];

    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)resetAllNoLongerVerified
{
    OWSAssertIsOnMainThread();

    OWSIdentityManager *identityManger = [OWSIdentityManager sharedManager];
    NSArray<NSString *> *recipientIds = [self noLongerVerifiedRecipientIds];
    for (NSString *recipientId in recipientIds) {
        OWSVerificationState verificationState = [identityManger verificationStateForRecipientId:recipientId];
        if (verificationState == OWSVerificationStateNoLongerVerified) {
            NSData *identityKey = [identityManger identityKeyForRecipientId:recipientId];
            if (identityKey.length < 1) {
                OWSFailDebug(@"Missing identity key for: %@", recipientId);
                continue;
            }
            [identityManger setVerificationState:OWSVerificationStateDefault
                                     identityKey:identityKey
                                     recipientId:recipientId
                           isUserInitiatedChange:YES
                             isSendSystemMessage:NO];
        }
    }

    [self updateTableContents];
}

// Returns a collection of the group members who are "no longer verified".
- (NSArray<NSString *> *)noLongerVerifiedRecipientIds
{
    NSMutableArray<NSString *> *result = [NSMutableArray new];
    for (NSString *recipientId in self.thread.recipientIdentifiers) {
        if ([[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId]
            == OWSVerificationStateNoLongerVerified) {
            [result addObject:recipientId];
        }
    }
    return [result copy];
}

- (void)didSelectRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);
    
    __weak ShowGroupMembersViewController *weakSelf = self;

    ContactsViewHelper *helper = self.contactsViewHelper;
    SignalAccount *signalAccount = [helper signalAccountForRecipientId:recipientId];

    UIAlertController *actionSheetController =
        [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *contactInfoTitle = signalAccount
        ? Localized(@"GROUP_MEMBERS_VIEW_CONTACT_INFO", @"Button label for the 'show contact info' button")
        : Localized(
              @"GROUP_MEMBERS_ADD_CONTACT_INFO", @"Button label to add information to an unknown contact");
    [actionSheetController addAction:[UIAlertAction actionWithTitle:contactInfoTitle
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *_Nonnull action) {
                                                                [weakSelf showContactInfoViewForRecipientId:recipientId];
                                                            }]];

    BOOL isBlocked;
    if (signalAccount) {
        isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
        if (isBlocked) {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_UNBLOCK_BUTTON",
                                                             @"Button label for the 'unblock' button")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showUnblockSignalAccountActionSheet:signalAccount
                                                                          fromViewController:weakSelf
                                                                             blockingManager:helper.blockingManager
                                                                             contactsManager:helper.contactsManager
                                                                             completionBlock:^(BOOL ignore) {
                                                                                 [weakSelf updateTableContents];
                                                                             }];
                                                 }]];
        } else {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_BLOCK_BUTTON",
                                                             @"Button label for the 'block' button")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showBlockSignalAccountActionSheet:signalAccount
                                                                        fromViewController:weakSelf
                                                                           blockingManager:helper.blockingManager
                                                                           contactsManager:helper.contactsManager
                                                                           completionBlock:^(BOOL ignore) {
                                                                               [weakSelf updateTableContents];
                                                                           }];
                                                 }]];
        }
    } else {
        isBlocked = [helper isRecipientIdBlocked:recipientId];
        if (isBlocked) {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_UNBLOCK_BUTTON",
                                                             @"Button label for the 'unblock' button")
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showUnblockPhoneNumberActionSheet:recipientId
                                                                        fromViewController:weakSelf
                                                                           blockingManager:helper.blockingManager
                                                                           contactsManager:helper.contactsManager
                                                                           completionBlock:^(BOOL ignore) {
                                                                               [weakSelf updateTableContents];
                                                                           }];
                                                 }]];
        } else {
            [actionSheetController
                addAction:[UIAlertAction actionWithTitle:Localized(@"BLOCK_LIST_BLOCK_BUTTON",
                                                             @"Button label for the 'block' button")
                                                   style:UIAlertActionStyleDestructive
                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                     [BlockListUIUtils
                                                         showBlockPhoneNumberActionSheet:recipientId
                                                                      fromViewController:weakSelf
                                                                         blockingManager:helper.blockingManager
                                                                         contactsManager:helper.contactsManager
                                                                         completionBlock:^(BOOL ignore) {
                                                                             [weakSelf updateTableContents];
                                                                         }];
                                                 }]];
        }
    }

    if (!isBlocked) {
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:Localized(@"GROUP_MEMBERS_SEND_MESSAGE",
                                                         @"Button label for the 'send message to group member' button")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *_Nonnull action) {
                                                 [weakSelf showConversationViewForRecipientId:recipientId];
                                             }]];
// modified: disable call in group.
//        [actionSheetController
//            addAction:[UIAlertAction actionWithTitle:Localized(@"GROUP_MEMBERS_CALL",
//                                                         @"Button label for the 'call group member' button")
//                                               style:UIAlertActionStyleDefault
//                                             handler:^(UIAlertAction *_Nonnull action) {
//                                                 [self callMember:recipientId];
//                                             }]];
        [actionSheetController
            addAction:[UIAlertAction actionWithTitle:Localized(@"VERIFY_PRIVACY",
                                                         @"Label for button or row which allows users to verify the "
                                                         @"safety number of another user.")
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *_Nonnull action) {
                                                 [weakSelf showSafetyNumberView:recipientId];
                                             }]];
    }

    [actionSheetController addAction:[OWSAlerts cancelAction]];

    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)showContactInfoViewForRecipientId:(NSString *)recipientId
{
    [self showProfileCardInfoWith:recipientId isFromSameThread:false isPresent:true];
}

- (void)showConversationViewForRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [SignalApp.sharedApp presentConversationForRecipientId:recipientId action:ConversationViewActionCompose];
}

- (void)callMember:(NSString *)recipientId
{
    [SignalApp.sharedApp presentConversationForRecipientId:recipientId action:ConversationViewActionAudioCall];
}

- (void)showSafetyNumberView:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    [FingerprintViewController presentFromViewController:self recipientId:recipientId];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return YES;
}

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    DDLogDebug(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - CNContactViewControllerDelegate

- (void)contactViewController:(CNContactViewController *)viewController
       didCompleteWithContact:(nullable CNContact *)contact
{
    DDLogDebug(@"%@ done editing contact.", self.logTag);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();

    [self updateTableContents];
}

@end

NS_ASSUME_NONNULL_END
