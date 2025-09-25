//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewController.h"
#import "AppDelegate.h"
#import "BlockListUIUtils.h"
#import "BlockListViewController.h"
#import "ContactsViewHelper.h"
#import "ConversationCollectionView.h"
#import "ConversationInputTextView.h"
#import "ConversationInputToolbar.h"
#import "ConversationScrollButton.h"
#import "ConversationViewCell.h"
#import "ConversationViewItem.h"
#import "ConversationViewLayout.h"
#import "DebugUITableViewController.h"
#import "FingerprintViewController.h"
#import "NSAttributedString+OWS.h"
#import "NewGroupViewController.h"
#import "OWSAudioPlayer.h"
//#import "OWSContactOffersCell.h"
#import "OWSConversationSettingsViewController.h"
#import "OWSConversationSettingsViewDelegate.h"
#import "OWSDisappearingMessagesJob.h"
#import "OWSMath.h"
#import "OWSMessageCell.h"
#import "OWSSystemMessageCell.h"
#import "ChooseAtMembersViewController.h"
#import "Wea-Swift.h"
#import "SignalKeyingStorage.h"
#import "TSAttachmentPointer.h"
#import "TSCall.h"
#import "TSContactThread.h"
#import "TSDatabaseView.h"
#import "TSErrorMessage.h"
#import "TSGroupThread.h"
#import "TSIncomingMessage.h"
#import "TSInfoMessage.h"
#import "TSInvalidIdentityKeyErrorMessage.h"
#import "UIFont+OWS.h"
#import "UIViewController+Permissions.h"
#import "ViewControllerUtils.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <SignalMessaging/SignalMessaging-Swift.h>
#import <SignalMessaging/UIColor+OWS.h>
#import <SignalMessaging/DateUtil.h>
#import <SignalMessaging/Environment.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalMessaging/OWSContactOffersInteraction.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/OWSFormat.h>
#import <SignalMessaging/OWSNavigationController.h>
#import <SignalMessaging/OWSUnreadIndicator.h>
#import <SignalMessaging/OWSUserProfile.h>
#import <SignalMessaging/UIUtil.h>
#import <SignalMessaging/UIViewController+OWS.h>
#import <SignalServiceKit/Contact.h>
#import <SignalServiceKit/ContactsUpdater.h>
#import <SignalServiceKit/MimeTypeUtil.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalServiceKit/NSTimer+OWS.h>
#import <SignalServiceKit/OWSAddToContactsOfferMessage.h>
#import <SignalServiceKit/OWSAddToProfileWhitelistOfferMessage.h>
#import <SignalServiceKit/OWSAttachmentsProcessor.h>
#import <SignalServiceKit/OWSBlockingManager.h>
#import <SignalServiceKit/OWSDisappearingMessagesConfiguration.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/OWSMessageManager.h>
#import <SignalServiceKit/OWSMessageSender.h>
#import <SignalServiceKit/OWSMessageUtils.h>
#import <SignalServiceKit/OWSReadReceiptManager.h>
#import <SignalServiceKit/OWSVerificationStateChangeMessage.h>
#import <SignalServiceKit/SignalRecipient.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/TSGroupModel.h>
#import <SignalServiceKit/TSInvalidIdentityKeyReceivingErrorMessage.h>
#import <SignalServiceKit/TSNetworkManager.h>
#import <SignalServiceKit/TSQuotedMessage.h>
#import <SignalCoreKit/Threading.h>
#import <SignalServiceKit/DTSUserStateManager.h>
#import <YapDatabase/YapDatabase.h>
#import <YapDatabase/YapDatabaseAutoView.h>
#import <YapDatabase/YapDatabaseViewChange.h>
#import <YapDatabase/YapDatabaseViewConnection.h>
#import "DTMultiCallManager.h"
#import "DTDisappearanceTimeIntervalConfig.h"
#import "DTUpgradeToANewGroupAPI.h"
#import "SVProgressHUD.h"
#import "DTGetGroupInfoAPI.h"
#import <SignalServiceKit/DTGroupUpdateMessageProcessor.h>
#import <SignalServiceKit/DTParamsBaseUtils.h>
#import <SignalServiceKit/DTToastHelper.h>
#import "DTPersonnalCardController.h"
#import "DTForwardMessageHelper.h"
#import "ConversationViewController+ForwardMessage.h"
#import "ConversationViewController+Task.h"
#import "ConversationViewController+Pin.h"
#import "DTPreviewViewController.h"
#import <SignalServiceKit/DTRecallConfig.h>
#import "DTTaskMessageEntity.h"
#import "DTLightTaskController.h"
#import "DTLightTaskEntity.h"
#import "DTTasksViewController.h"
#import <SignalServiceKit/DTTranslateMessage.h>
#import <SignalServiceKit/DTTranslateApi.h>
#import "DTVoteViewController.h"
#import "DTVoteNowApi.h"
#import "ConversationViewController+Thread.h"
#import "DTThreadHeadView.h"
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import "ConversationViewController+Translate.h"
#import "DTMessageDetailViewController.h"
#import "DTTaskConfig.h"
#import "DTVoteListViewController.h"

extern const NSUInteger kOversizeTextMessageSizelength;
extern NSString *const kUpdateVoteInfoNotification;
@import Photos;

NS_ASSUME_NONNULL_BEGIN

// Always load up to n messages when user arrives.
//
// The smaller this number is, the faster the conversation can display.
// To test, shrink you accessability font as much as possible, then count how many 1-line system info messages (our shortest cells) can
// fit on screen at a time on an iPhoneX
//
// PERF: we could do less messages on shorter (older, slower) devices
// PERF: we could cache the cell height, since some messages will be much taller.
static const int kYapDatabasePageSize = 25;

// Never show more than n messages in conversation view when user arrives.
static const int kConversationInitialMaxRangeSize = 300;

// Never show more than n messages in conversation view at a time.
static const int kYapDatabaseRangeMaxLength = 25000;

static const int kYapDatabaseRangeMinLength = 0;

static const CGFloat kLoadMoreHeaderHeight = 60.f;
static const CGFloat kArchiveNoticeHeaderHeight = 15.f;
static const CGFloat kThreshold = 50.f;

#pragma mark -

@interface ConversationViewController () <AttachmentApprovalViewControllerDelegate,
ContactShareApprovalViewControllerDelegate,
AVAudioPlayerDelegate,
ContactEditingDelegate,
ContactsPickerDelegate,
ContactShareViewHelperDelegate,
ContactsViewHelperDelegate,
DisappearingTimerConfigurationViewDelegate,
OWSConversationSettingsViewDelegate,
ConversationHeaderViewDelegate,
ConversationViewLayoutDelegate,
ConversationViewCellDelegate,
ConversationInputTextViewDelegate,
MessageActionsDelegate,
MenuActionsViewControllerDelegate,
OWSMessageBubbleViewDelegate,
UICollectionViewDelegate,
UICollectionViewDataSource,
//    UIDocumentMenuDelegate,
UIDocumentPickerDelegate,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate,
UITextViewDelegate,
ConversationCollectionViewDelegate,
ConversationInputToolbarDelegate,
GifPickerViewControllerDelegate,
ChooseAtMembersViewControllerDelegate,
DTSUserStateProtocol,
UIDocumentInteractionControllerDelegate>

@property (nonatomic) TSThread *thread;
@property (nonatomic, readonly) AudioActivity *voiceNoteAudioActivity;
@property (nonatomic, readonly) NSTimeInterval viewControllerCreatedAt;

// These two properties must be updated in lockstep.
//
// * The first (required) step is to update uiDatabaseConnection using beginLongLivedReadTransaction.
// * The second (required) step is to update messageMappings.
// * The third (optional) step is to update the messageMappings range using
//   updateMessageMappingRangeOptions.
// * The fourth (optional) step is to update the view items using reloadViewItems.
// * The steps must be done in strict order.
// * If we do any of the steps, we must do all of the required steps.
// * We can't use messageMappings or viewItems after the first step until we've
//   done the last step; i.e.. we can't do any layout, since that uses the view
//   items which haven't been updated yet.
// * If the first and/or second steps changes the set of messages
//   their ordering and/or their state, we must do the third and fourth steps.
// * If we do the third step, we must call resetContentAndLayout afterward.
//@property (nonatomic, readonly) YapDatabaseConnection *uiDatabaseConnection;
@property (nonatomic) YapDatabaseViewMappings *messageMappings;
//@property (nonatomic) YapDatabaseViewMappings *unReplyMappings;
@property (nonatomic) NSMutableArray *unReplyMessageArr;

@property (nonatomic, readonly) ConversationInputToolbar *inputToolbar;
//@property (nonatomic, readonly) ConversationCollectionView *collectionView;
@property (nonatomic, readonly) ConversationViewLayout *layout;
@property (nonatomic, readonly) ConversationStyle *conversationStyle;

@property (nonatomic) NSArray<ConversationViewItem *> *viewItems;
@property (nonatomic) NSMutableDictionary<NSString *, ConversationViewItem *> *viewItemCache;

@property (nonatomic, nullable) AVAudioRecorder *audioRecorder;
@property (nonatomic, nullable) OWSAudioPlayer *audioAttachmentPlayer;
@property (nonatomic, nullable) NSUUID *voiceMessageUUID;

@property (nonatomic, nullable) NSTimer *readTimer;
@property (nonatomic) NSCache *cellMediaCache;
@property (nonatomic) ConversationHeaderView *headerView;
@property (nonatomic, nullable) UIView *bannerView;
@property (nonatomic, nullable) OWSDisappearingMessagesConfiguration *disappearingMessagesConfiguration;

// Back Button Unread Count
@property (nonatomic, readonly) UIView *backButtonUnreadCountView;
@property (nonatomic, readonly) UILabel *backButtonUnreadCountLabel;
@property (nonatomic, readonly) NSUInteger backButtonUnreadCount;

@property (nonatomic) NSUInteger lastRangeLength;
@property (nonatomic) NSUInteger lastRangeOffset;
@property (nonatomic) NSUInteger loadNewerPageCount;
@property (nonatomic) NSUInteger loadOlderPageCount;
@property (nonatomic) ConversationViewAction actionOnOpen;
@property (nonatomic, nullable) NSString *focusMessageIdOnOpen;

@property (nonatomic) BOOL peek;

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) ContactsUpdater *contactsUpdater;

@property (nonatomic, readonly) TSNetworkManager *networkManager;
@property (nonatomic, readonly) OWSBlockingManager *blockingManager;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;

@property (nonatomic) BOOL userHasScrolled;
@property (nonatomic, nullable) NSDate *lastMessageSentDate;

@property (nonatomic, nullable) ThreadDynamicInteractions *dynamicInteractions;
@property (nonatomic) BOOL hasClearedUnreadMessagesIndicator;
@property (nonatomic) BOOL showLoadMoreHeader;
@property (nonatomic) BOOL showLoadMoreFooter;
@property (nonatomic) UILabel *loadMoreHeader;
@property (nonatomic) UILabel *archiveNoticeHeader;
@property (nonatomic) uint64_t lastVisibleTimestamp;

@property (nonatomic) BOOL isUserScrolling;

@property (nonatomic) NSLayoutConstraint *scrollDownButtonButtomConstraint;
@property (nonatomic) NSArray <NSLayoutConstraint *> *collectionViewEdges;

@property (nonatomic) ConversationScrollButton *scrollDownButton;
#ifdef DEBUG
@property (nonatomic) ConversationScrollButton *scrollUpButton;
#endif

@property (nonatomic) BOOL isViewCompletelyAppeared;
@property (nonatomic) BOOL isViewVisible;
@property (nonatomic) BOOL shouldObserveDBModifications;
@property (nonatomic) BOOL viewHasEverAppeared;
@property (nonatomic) BOOL hasUnreadMessages;
@property (nonatomic) BOOL isPickingMediaAsDocument;
@property (nonatomic, nullable) NSNumber *previousLastTimestamp;
@property (nonatomic, nullable) NSNumber *viewHorizonTimestamp;
@property (nonatomic) ContactShareViewHelper *contactShareViewHelper;
@property (nonatomic) NSTimer *reloadTimer;
@property (nonatomic, nullable) NSDate *lastReloadDate;
@property (nonatomic, nullable) NSDate *collapseCutoffDate;

@property (nonatomic, weak) ChooseAtMembersViewController *atVC;
@property (nonatomic, strong) DTUpgradeToANewGroupAPI *upgradeToANewGroupAPI;
@property (nonatomic, strong) DTGetGroupInfoAPI *getGroupInfoAPI;
@property (nonatomic, strong) DFPhotoBrowserHelper *photoBrowser;
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;

@property (nonatomic, strong) DTGroupUpdateMessageProcessor *groupUpdateMessageProcessor;
@property (nonatomic, strong) NSMutableDictionary *conversationTagInfo;
@property (nonatomic, strong) NSIndexPath *updateIndexPath;

@property (nonatomic,assign) BOOL viewDidAppear;

@property (nonatomic, strong) UIDocumentInteractionController *documentController;

@property (nonatomic, assign) BOOL isMultiSelectMode;
@property(nonatomic,strong) DTTranslateApi *translateApi;
@property(nonatomic,strong) NSDictionary *voteInfo;
@property(nonatomic,strong) DTVoteNowApi *voteNowApi;
@property(nonatomic,strong) SignalAccount *signalAccount;
@property(nonatomic,strong) DTThreadHeadView *threadHeadView;

@property (nonatomic, copy) NSString *serverGroupId;
@property (nonatomic,strong) DTUpdateUnreplyProcessor *unreplyProcessor;
@end

#pragma mark -

@implementation ConversationViewController

- (NSMutableDictionary *)conversationTagInfo
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = @{}.mutableCopy;
    });
    
    return sharedInstance;
}


- (DTUpgradeToANewGroupAPI *)upgradeToANewGroupAPI{
    if(!_upgradeToANewGroupAPI){
        _upgradeToANewGroupAPI = [DTUpgradeToANewGroupAPI new];
    }
    return _upgradeToANewGroupAPI;
}

- (DTGetGroupInfoAPI *)getGroupInfoAPI{
    if(!_getGroupInfoAPI){
        _getGroupInfoAPI = [DTGetGroupInfoAPI new];
    }
    return _getGroupInfoAPI;
}

- (DTGroupUpdateMessageProcessor *)groupUpdateMessageProcessor{
    if(!_groupUpdateMessageProcessor){
        _groupUpdateMessageProcessor = [DTGroupUpdateMessageProcessor new];
    }
    return _groupUpdateMessageProcessor;
}

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
    _viewDidAppear = false;
    _viewControllerCreatedAt = CACurrentMediaTime();
    _contactsManager = [Environment current].contactsManager;
    _contactsUpdater = [Environment current].contactsUpdater;
    _messageSender = [Environment current].messageSender;
    _networkManager = [TSNetworkManager sharedManager];
    _blockingManager = [OWSBlockingManager sharedManager];
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _contactShareViewHelper = [[ContactShareViewHelper alloc] initWithContactsManager:self.contactsManager];
    _contactShareViewHelper.delegate = self;
    _updateIndexPath = nil;
    self.conversationViewMode = ConversationViewMode_Main;
    NSString *audioActivityDescription = [NSString stringWithFormat:@"%@ voice note", self.logTag];
    _voiceNoteAudioActivity = [[AudioActivity alloc] initWithAudioDescription:audioActivityDescription];
}

- (void)addNotificationListeners
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(blockedPhoneNumbersDidChange:)
                                                 name:kNSNotificationName_BlockedPhoneNumbersDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowManagerCallDidChange:)
                                                 name:OWSWindowManagerCallDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangePreferredContentSize:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uiDatabaseDidUpdateExternally:)
                                                 name:OWSUIDatabaseConnectionDidUpdateExternallyNotification
                                               object:self.databaseStorage.yapPrimaryStorage.dbNotificationObject];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uiDatabaseWillUpdate:)
                                                 name:OWSUIDatabaseConnectionWillUpdateNotification
                                               object:self.databaseStorage.yapPrimaryStorage.dbNotificationObject];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(uiDatabaseDidUpdate:)
                                                 name:OWSUIDatabaseConnectionDidUpdateNotification
                                               object:self.databaseStorage.yapPrimaryStorage.dbNotificationObject];
    //    [[NSNotificationCenter defaultCenter] addObserver:self
    //                                             selector:@selector(yapDatabaseModifiedCrossProcess:)
    //                                                 name:SDSDatabaseStorage.didReceiveCrossProcessNotification
    //                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:OWSApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:OWSApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:OWSApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cancelReadTimer)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(otherUsersProfileDidChange:)
                                                 name:kNSNotificationName_OtherUsersProfileDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(profileWhitelistDidChange:)
                                                 name:kNSNotificationName_ProfileWhitelistDidChange
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(signalAccountsDidChange:)
                                                 name:OWSContactsManagerSignalAccountsDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrame:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateVoteInfo:)
                                                 name:kUpdateVoteInfoNotification
                                               object:nil];
    
}

- (BOOL)isGroupConversation
{
    OWSAssertDebug(self.thread);
    
    return self.thread.isGroupThread;
}

- (void)signalAccountsDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    if(!self.thread.isLargeGroupThread){
        [self ensureDynamicInteractions];
    }
    
    [self updateNavigationTitle];
    [self updateNavigationBarSubtitleLabel];
}

- (void)updateVoteInfo:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    self.voteInfo = info;
}

- (void)otherUsersProfileDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    NSString *recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    OWSAssertDebug(recipientId.length > 0);
    if (recipientId.length > 0 && [self.thread.recipientIdentifiers containsObject:recipientId]) {
        if ([self.thread isKindOfClass:[TSContactThread class]]) {
            // update title with profile name
            [self updateNavigationTitle];
        }
        
        if (self.isGroupConversation) {
            // Reload all cells if this is a group conversation,
            // since we may need to update the sender names on the messages.
            [self resetContentAndLayout];
        }
    }
}

- (void)profileWhitelistDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    // If profile whitelist just changed, we may want to hide a profile whitelist offer.
    NSString *_Nullable recipientId = notification.userInfo[kNSNotificationKey_ProfileRecipientId];
    NSData *_Nullable groupId = notification.userInfo[kNSNotificationKey_ProfileGroupId];
    if (recipientId.length > 0 && [self.thread.recipientIdentifiers containsObject:recipientId]) {
        [self ensureDynamicInteractions];
    } else if (groupId.length > 0 && self.thread.isGroupThread) {
        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        if ([groupThread.groupModel.groupId isEqualToData:groupId]) {
            [self ensureDynamicInteractions];
            [self ensureBannerState];
        }
    }
}

- (void)blockedPhoneNumbersDidChange:(id)notification
{
    OWSAssertIsOnMainThread();
    
    [self ensureBannerState];
}

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    [self updateNavigationBarSubtitleLabel];
    [self ensureBannerState];
}

- (void)peekSetup
{
    _peek = YES;
    self.actionOnOpen = ConversationViewActionNone;
}

- (void)popped
{
    _peek = NO;
    [self hideInputIfNeeded];
}

- (void)configureForThread:(TSThread *)thread
                    action:(ConversationViewAction)action
            focusMessageId:(nullable NSString *)focusMessageId
                 viewModel:(ConversationViewMode) viewMode {
    self.conversationViewMode = viewMode;
    [self configureForThread:thread action:action focusMessageId:focusMessageId];
}

- (void)configureForThread:(TSThread *)thread
                    action:(ConversationViewAction)action
            focusMessageId:(nullable NSString *)focusMessageId
{
    OWSAssertDebug(thread);
    
    _thread = thread;
    self.actionOnOpen = action;
    self.focusMessageIdOnOpen = focusMessageId;
    _cellMediaCache = [NSCache new];
    // Cache the cell media for ~24 cells.
    self.cellMediaCache.countLimit = 24;
    _conversationStyle = [[ConversationStyle alloc] initWithThread:thread];
    
    // We need to update the "unread indicator" _before_ we determine the initial range
    // size, since it depends on where the unread indicator is placed.
    self.lastRangeLength = 0;
    [self ensureDynamicInteractions];
    [self.databaseStorage.yapPrimaryStorage updateUIDatabaseConnectionToLatest];
    if (thread.uniqueId.length > 0 && self.conversationViewMode == ConversationViewMode_Main) {
        self.messageMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[ [self getCurrentGrouping] ]
                                                                          view:[self getDatabaseViewExtensionName]];
    } else if (thread.uniqueId.length > 0 && self.conversationViewMode == ConversationViewMode_Thread && self.botViewItem.interaction){
        TSMessage *interactionMsg = (TSMessage *)self.botViewItem.interaction;
        if (interactionMsg.threadContextID.length) {
            self.messageMappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[ [self getCurrentGrouping] ]
                                                                              view:[self getDatabaseViewExtensionName]];
        }
        
    } else {
        OWSFailDebug(@"uniqueId unexpectedly empty for thread: %@", thread);
        self.messageMappings =
        [[YapDatabaseViewMappings alloc] initWithGroups:@[] view:[self getDatabaseViewExtensionName]];
        return;
    }
    // Cells' appearance can depend on adjacent cells in both directions.
    [self.messageMappings setCellDrawingDependencyOffsets:[NSSet setWithArray:@[
        @(-1),
        @(+1),
    ]]
                                                 forGroup:self.thread.uniqueId];
    
    // We need to impose the range restrictions on the mappings immediately to avoid
    // doing a great deal of unnecessary work and causing a perf hotspot.
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [self.messageMappings updateWithTransaction:transaction];
    }];
    [self updateMessageMappingRangeOptions];
    [self resetContentAndLayout];
    [self updateShouldObserveDBModifications];
    
    self.reloadTimer = [NSTimer weakScheduledTimerWithTimeInterval:1.f
                                                            target:self
                                                          selector:@selector(reloadTimerDidFire)
                                                          userInfo:nil
                                                           repeats:YES];
}

- (void)dealloc
{
    [self.reloadTimer invalidate];
    [[DTSUserStateManager sharedManager] removeDelegate:self];
}

- (void)reloadTimerDidFire
{
    OWSAssertIsOnMainThread();
    
    if (self.isUserScrolling || !self.isViewCompletelyAppeared || !self.isViewVisible
        || !self.shouldObserveDBModifications || !self.viewHasEverAppeared) {
        return;
    }
    
    NSDate *now = [NSDate new];
    if (self.lastReloadDate) {
        NSTimeInterval timeSinceLastReload = [now timeIntervalSinceDate:self.lastReloadDate];
        const NSTimeInterval kReloadFrequency = 60.f;
        if (timeSinceLastReload < kReloadFrequency) {
            return;
        }
    }
    
    DDLogVerbose(@"%@ reloading conversation view contents.", self.logTag);
    [self resetContentAndLayout];
}

- (BOOL)userLeftGroup
{
    if (![_thread isKindOfClass:[TSGroupThread class]]) {
        return NO;
    }
    
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    return ![groupThread.groupModel.groupMemberIds containsObject:[TSAccountManager localNumber]];
}

- (void)hideInputIfNeeded
{
    if (_peek) {
        self.inputToolbar.hidden = YES;
        [self dismissKeyBoard];
        return;
    }
    
    if (self.userLeftGroup) {
        self.inputToolbar.hidden = YES; // user has requested they leave the group. further sends disallowed
        [self dismissKeyBoard];
    } else {
        self.inputToolbar.hidden = NO;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[DTSUserStateManager sharedManager]addDelegate:self];
    [self createContents];
    [self checkReplyModelForBot];
    [self registerCellClasses];
    
    [self createConversationScrollButtons];
    [self createHeaderViews];
    
    /*
     if (@available(iOS 11, *)) {
     self.navigationController.navigationBar.translucent = NO;
     } else {
     // On iOS9/10 the default back button is too wide, so we use a custom back button. This doesn't animate nicely
     // with interactive transitions, but has the appropriate width.
     [self createBackButton];
     }
     */
    [self addNotificationListeners];
    [self loadDraftInCompose];
    
    //    [self removeDisappearingMessage];
    
    if(self.thread.isGroupThread){
        [self getGroupInfo:(TSGroupThread *)self.thread];
    }
    [[OWSProfileManager sharedManager] userAddedThreadToProfileWhitelist:self.thread success:^{
        [self ensureBannerState];
    }];
    
    if (self.conversationViewMode == ConversationViewMode_Thread) {
        [self setUpNavbarItem];
    } else {
        if (self.isGroupConversation) {
            [self resetPinnedMappingsAnimated:NO];
        }
    }
    
    //    [self updateAllThreadMessgeFilteringWithVersionTag:@"1"];
    //    [self updateUnreplyThreadFilteringWithVersionTag:@"1"];
    [self.databaseStorage.yapPrimaryStorage touchDbAsync];
}

- (void)setUpNavbarItem {
    if (self.navigationController.presentingViewController) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(dismissConversationButtonClick:)];
    }
    
}

- (void)dismissConversationButtonClick:(UIButton *)sender {
    [self.view endEditing:YES];
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)removeDisappearingMessage{
    
    NSMutableArray *interactionsWillRemoved = @[].mutableCopy;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:[self getDatabaseViewExtensionName]];
        NSUInteger count = [viewTransaction numberOfItemsInGroup:[self getCurrentGrouping]];
        for (NSUInteger row = 0; row < count; row++) {
            TSInteraction *interaction =
            [viewTransaction objectAtIndex:row inGroup:self.thread.uniqueId];
            if([interaction isKindOfClass:[OWSDisappearingConfigurationUpdateInfoMessage class]]){
                [interactionsWillRemoved addObject:interaction];
            }
        }
    }];
    [interactionsWillRemoved makeObjectsPerformSelector:@selector(remove)];
}
- (void)loadView
{
    [super loadView];
    
    // make sure toolbar extends below iPhoneX home button.
    self.view.backgroundColor = Theme.toolbarBackgroundColor;
}

- (void)applyTheme {
    [super applyTheme];
    
    self.view.backgroundColor = Theme.toolbarBackgroundColor;
    self.collectionView.backgroundColor = Theme.backgroundColor;
    
    [self.headerView applyTheme];
    if (self.navigationItem.rightBarButtonItems.count > 0) {
        [self updateBarButtonItems];
    }
    [self updateNavigationTitle];
    [self updateNavigationBarSubtitleLabel];
    [self.inputToolbar applyTheme];
    [self.forwardToolbar applyTheme];
    [self.pinView applyTheme];
    
    [self resetContentAndLayout];
}

- (void)createContents
{
    OWSAssertDebug(self.conversationStyle);
    
    _layout = [[ConversationViewLayout alloc] initWithConversationStyle:self.conversationStyle
                                                   uiDatabaseConnection:self.uiDatabaseConnection];
    self.conversationStyle.viewWidth = self.view.width;
    
    self.layout.delegate = self;
    // We use the root view bounds as the initial frame for the collection
    // view so that its contents can be laid out immediately.
    _collectionView =
    [[ConversationCollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:self.layout];
    self.collectionView.layoutDelegate = self;
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.showsVerticalScrollIndicator = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.allowsSelection = NO;
    self.collectionView.backgroundColor = Theme.backgroundColor;
    [self.view addSubview:self.collectionView];
    self.collectionViewEdges = [self.collectionView autoPinEdgesToSuperviewEdges];
    
    [self.collectionView applyScrollViewInsetsFix];
    
    BOOL isNote = [self.thread.contactIdentifier isEqualToString:[TSAccountManager localNumber]];
    DTInputToolbarType toolbarType = DTInputToolbarTypeGroup;
    if (!self.thread.isGroupThread) {
        if (self.thread.contactIdentifier.length <= 6) {
            toolbarType = DTInputToolbarTypeBot;
        } else {
            toolbarType = isNote ? DTInputToolbarTypeNote : DTInputToolbarTypeContact;
        }
    }else {
        if (self.conversationViewMode == ConversationViewMode_Thread) {
            toolbarType = DTInputToolbarTypeGroupThread;
        }
    }
    _inputToolbar = [[ConversationInputToolbar alloc] initWithConversationStyle:self.conversationStyle withType:toolbarType];
    
    self.inputToolbar.inputToolbarDelegate = self;
    self.inputToolbar.inputTextViewDelegate = self;
    BOOL isTranslateOpen = self.thread.translateSettingType.integerValue != 0;
    if (!isNote) {
        [self.inputToolbar setTranslateOpen:isTranslateOpen];
    }
    
    self.loadMoreHeader = [UILabel new];
    self.loadMoreHeader.text = NSLocalizedString(@"CONVERSATION_VIEW_LOADING_MORE_MESSAGES",
                                                 @"Indicates that the app is loading more messages in this conversation.");
    self.loadMoreHeader.textColor = [UIColor ows_materialBlueColor];
    self.loadMoreHeader.textAlignment = NSTextAlignmentCenter;
    self.loadMoreHeader.font = [UIFont ows_mediumFontWithSize:16.f];
    [self.collectionView addSubview:self.loadMoreHeader];
    
    [self.loadMoreHeader autoPinWidthToWidthOf:self.view];
    [self.loadMoreHeader autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [self.loadMoreHeader autoAlignAxisToSuperviewAxis:(ALAxisVertical)];
    [self.loadMoreHeader autoSetDimension:ALDimensionHeight toSize:kLoadMoreHeaderHeight];
    
    if (![self.thread.contactIdentifier isEqualToString:[TSAccountManager localNumber]]) {
        
        UILabel *archiveNotice = [UILabel new];
        archiveNotice.hidden = YES;
        archiveNotice.textAlignment = NSTextAlignmentCenter;
        archiveNotice.font = UIFont.ows_dynamicTypeCaption1Font;
        archiveNotice.textColor = [UIColor ows_lightGray01Color];
        [self.collectionView addSubview:archiveNotice];
        [archiveNotice autoAlignAxisToSuperviewAxis:(ALAxisVertical)];
        [archiveNotice autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
        [archiveNotice autoSetDimension:ALDimensionHeight toSize:kArchiveNoticeHeaderHeight];
        self.archiveNoticeHeader = archiveNotice;
    }
}

- (BOOL)becomeFirstResponder
{
    DDLogDebug(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
    DDLogDebug(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    return [super resignFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (nullable UIView *)inputAccessoryView
{
    self.inputToolbar.alpha = self.isMultiSelectMode ? 0 : 1;
    return self.inputToolbar;
}

- (void)registerCellClasses
{
    [self.collectionView registerClass:[OWSSystemMessageCell class]
            forCellWithReuseIdentifier:[OWSSystemMessageCell cellReuseIdentifier]];
    [self.collectionView registerClass:[OWSMessageCell class]
            forCellWithReuseIdentifier:[OWSMessageCell cellReuseIdentifier]];
    [self.collectionView registerClass:[ConversationViewCell class]
            forCellWithReuseIdentifier:[ConversationViewCell unknownCellReuserIdentifier]];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self startReadTimer];
    [self updateCellsVisible];
    [self.databaseStorage.yapPrimaryStorage touchDbAsync];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self updateCellsVisible];
    if (self.hasClearedUnreadMessagesIndicator) {
        self.hasClearedUnreadMessagesIndicator = NO;
        [self.dynamicInteractions clearUnreadIndicatorState];
    }
    [self.cellMediaCache removeAllObjects];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self updateShouldObserveDBModifications];
    //    [self cancelVoiceMemo];
    self.isUserScrolling = NO;
    [self saveDraft];
    [self markVisibleMessagesAsRead];
    [self.cellMediaCache removeAllObjects];
    [self cancelReadTimer];
    [self dismissPresentedViewControllerIfNecessary];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self updateShouldObserveDBModifications];
    [self startReadTimer];
}

- (void)dismissPresentedViewControllerIfNecessary
{
    UIViewController *_Nullable presentedViewController = self.presentedViewController;
    if (!presentedViewController) {
        DDLogDebug(@"%@ presentedViewController was nil", self.logTag);
        return;
    }
    
    if ([presentedViewController isKindOfClass:[UIAlertController class]]) {
        DDLogDebug(@"%@ dismissing presentedViewController: %@", self.logTag, presentedViewController);
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    
    if ([presentedViewController isKindOfClass:[UIImagePickerController class]]) {
        DDLogDebug(@"%@ dismissing presentedViewController: %@", self.logTag, presentedViewController);
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    DDLogDebug(@"%@ viewWillAppear", self.logTag);
    
    [self ensureBannerState];
    
    [super viewWillAppear:animated];
    
    // We need to recheck on every appearance, since the user may have left the group in the settings VC,
    // or on another device.
    [self hideInputIfNeeded];
    
    self.isViewVisible = YES;
    
    // We should have already requested contact access at this point, so this should be a no-op
    // unless it ever becomes possible to load this VC without going via the HomeViewController.
    // forbid to read system contacts.
    //[self.contactsManager requestSystemContactsOnce];
    
    [self updateDisappearingMessagesConfiguration];
    
    [self updateBarButtonItems];
    [self updateNavigationTitle];
    [self updateNavigationBarSubtitleLabel];
    
    // We want to set the initial scroll state the first time we enter the view.
    if (!self.viewHasEverAppeared) {
        [self scrollToDefaultPosition];
    }
    
    [self updateLastVisibleTimestamp];
    
    if (!self.viewHasEverAppeared) {
        NSTimeInterval appearenceDuration = CACurrentMediaTime() - self.viewControllerCreatedAt;
        DDLogVerbose(@"%@ First viewWillAppear took: %.2fms", self.logTag, appearenceDuration * 1000);
    }
}

- (NSIndexPath *_Nullable)indexPathOfUnreadMessagesIndicator
{
    NSInteger row = 0;
    for (ConversationViewItem *viewItem in self.viewItems) {
        if (viewItem.unreadIndicator) {
            return [NSIndexPath indexPathForRow:row inSection:0];
        }
        row++;
    }
    return nil;
}

- (NSIndexPath *_Nullable)indexPathOfMessageOnOpen
{
    OWSAssertDebug(self.focusMessageIdOnOpen);
    //    OWSAssertDebug(self.dynamicInteractions.focusMessagePosition);
    
    //    if (!self.dynamicInteractions.focusMessagePosition) {
    //        // This might happen if the focus message has disappeared
    //        // before this view could appear.
    //        OWSLogError(@"%@ focus message has unknown position.", self.logTag);
    //        return nil;
    //    }
    //    NSUInteger focusMessagePosition = self.dynamicInteractions.focusMessagePosition.unsignedIntegerValue;
    //    if (focusMessagePosition >= self.viewItems.count) {
    //        // This might happen if the focus message is outside the maximum
    //        // valid load window size for this view.
    //        OWSLogError(@"%@ focus message has invalid position.", self.logTag);
    //        return nil;
    //    }
    //    NSInteger row = (NSInteger)((self.viewItems.count - 1) - focusMessagePosition);
    return [NSIndexPath indexPathForRow:2 inSection:0];
}

- (void)scrollToDefaultPosition
{
    if (self.isUserScrolling) {
        return;
    }
    
    NSIndexPath *_Nullable indexPath = nil;
    if (self.focusMessageIdOnOpen) {
        indexPath = [self indexPathOfMessageOnOpen];
    }
    
    if (!indexPath) {
        indexPath = [self indexPathOfUnreadMessagesIndicator];
    }
    
    if (indexPath) {
        if (indexPath.section == 0 && indexPath.item == 0) {
            [self.collectionView setContentOffset:CGPointZero animated:NO];
        } else {
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionTop
                                                animated:NO];
        }
    } else {
        [self scrollToBottomAnimated:NO];
    }
}

- (void)scrollToUnreadIndicatorAnimated
{
    if (self.isUserScrolling) {
        return;
    }
    
    NSIndexPath *_Nullable indexPath = [self indexPathOfUnreadMessagesIndicator];
    if (indexPath) {
        if (indexPath.section == 0 && indexPath.item == 0) {
            [self.collectionView setContentOffset:CGPointZero animated:YES];
        } else {
            [self.collectionView scrollToItemAtIndexPath:indexPath
                                        atScrollPosition:UICollectionViewScrollPositionTop
                                                animated:YES];
        }
    }
}

- (void)resetContentAndLayout
{
    // Avoid layout corrupt issues and out-of-date message subtitles.
    self.lastReloadDate = [NSDate new];
    self.collapseCutoffDate = [NSDate new];
    
    // refresh step 4-4 reloadViewItems
    [self reloadViewItems];
    
    [self.collectionView.collectionViewLayout invalidateLayout];
    [UIView performWithoutAnimation:^{
        [self.collectionView reloadData];
    }];
}

- (void)UserHasScrolled:(BOOL)userHasScrolled
{
    _userHasScrolled = userHasScrolled;
    
    [self ensureBannerState];
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

- (void)ensureBannerState
{
    // This method should be called rarely, so it's simplest to discard and
    // rebuild the indicator view every time.
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;
    
    if (self.userHasScrolled) {
        return;
    }
    
    NSArray<NSString *> *noLongerVerifiedRecipientIds = [self noLongerVerifiedRecipientIds];
    
    if (noLongerVerifiedRecipientIds.count > 0) {
        NSString *message;
        if (noLongerVerifiedRecipientIds.count > 1) {
            message = NSLocalizedString(@"MESSAGES_VIEW_N_MEMBERS_NO_LONGER_VERIFIED",
                                        @"Indicates that more than one member of this group conversation is no longer verified.");
        } else {
            NSString *recipientId = [noLongerVerifiedRecipientIds firstObject];
            NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:recipientId];
            NSString *format
            = (self.isGroupConversation ? NSLocalizedString(@"MESSAGES_VIEW_1_MEMBER_NO_LONGER_VERIFIED_FORMAT",
                                                            @"Indicates that one member of this group conversation is no longer "
                                                            @"verified. Embeds {{user's name or phone number}}.")
               : NSLocalizedString(@"MESSAGES_VIEW_CONTACT_NO_LONGER_VERIFIED_FORMAT",
                                   @"Indicates that this 1:1 conversation is no longer verified. Embeds "
                                   @"{{user's name or phone number}}."));
            message = [NSString stringWithFormat:format, displayName];
        }
        
        [self resetVerificationStateToDefault];
        //        [self createBannerWithTitle:message
        //                        bannerColor:[UIColor ows_destructiveRedColor]
        //                        tapSelector:@selector(noLongerVerifiedBannerViewWasTapped:)];
        return;
    }
    
    NSString *blockStateMessage = nil;
    if ([self isBlockedContactConversation]) {
        blockStateMessage = NSLocalizedString(
                                              @"MESSAGES_VIEW_CONTACT_BLOCKED", @"Indicates that this 1:1 conversation has been blocked.");
    } else if (self.isGroupConversation) {
        int blockedGroupMemberCount = [self blockedGroupMemberCount];
        if (blockedGroupMemberCount == 1) {
            blockStateMessage = NSLocalizedString(@"MESSAGES_VIEW_GROUP_1_MEMBER_BLOCKED",
                                                  @"Indicates that a single member of this group has been blocked.");
        } else if (blockedGroupMemberCount > 1) {
            blockStateMessage =
            [NSString stringWithFormat:NSLocalizedString(@"MESSAGES_VIEW_GROUP_N_MEMBERS_BLOCKED_FORMAT",
                                                         @"Indicates that some members of this group has been blocked. Embeds "
                                                         @"{{the number of blocked users in this group}}."),
             [OWSFormat formatInt:blockedGroupMemberCount]];
        }
    }
    
    if (blockStateMessage) {
        [self createBannerWithTitle:blockStateMessage
                        bannerColor:[UIColor ows_destructiveRedColor]
                        tapSelector:@selector(blockBannerViewWasTapped:)];
        return;
    }
    
    //    if ([ThreadUtil shouldShowGroupProfileBannerInThread:self.thread blockingManager:self.blockingManager]) {
    //        dispatch_async(dispatch_get_main_queue(), ^{
    //            [[OWSProfileManager sharedManager] userAddedThreadToProfileWhitelist:self.thread success:^{
    //                  [self ensureBannerState];
    //              }];
    //        });
    //        return;
    //    }
    
}

- (void)createBannerWithTitle:(NSString *)title bannerColor:(UIColor *)bannerColor tapSelector:(SEL)tapSelector
{
    OWSAssertDebug(title.length > 0);
    OWSAssertDebug(bannerColor);
    
    UIView *bannerView = [UIView containerView];
    bannerView.backgroundColor = bannerColor;
    bannerView.layer.cornerRadius = 2.5f;
    
    // Use a shadow to "pop" the indicator above the other views.
    bannerView.layer.shadowColor = [UIColor blackColor].CGColor;
    bannerView.layer.shadowOffset = CGSizeMake(2, 3);
    bannerView.layer.shadowRadius = 2.f;
    bannerView.layer.shadowOpacity = 0.35f;
    
    UILabel *label = [UILabel new];
    label.font = [UIFont ows_mediumFontWithSize:14.f];
    label.text = title;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.textAlignment = NSTextAlignmentCenter;
    
    UIImage *closeIcon = [UIImage imageNamed:@"banner_close"];
    UIImageView *closeButton = [[UIImageView alloc] initWithImage:closeIcon];
    [bannerView addSubview:closeButton];
    const CGFloat kBannerCloseButtonPadding = 8.f;
    [closeButton autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:kBannerCloseButtonPadding];
    [closeButton autoPinTrailingToSuperviewMarginWithInset:kBannerCloseButtonPadding];
    [closeButton autoSetDimension:ALDimensionWidth toSize:closeIcon.size.width];
    [closeButton autoSetDimension:ALDimensionHeight toSize:closeIcon.size.height];
    
    [bannerView addSubview:label];
    [label autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5];
    [label autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:5];
    const CGFloat kBannerHPadding = 15.f;
    [label autoPinLeadingToSuperviewMarginWithInset:kBannerHPadding];
    const CGFloat kBannerHSpacing = 10.f;
    [closeButton autoPinLeadingToTrailingEdgeOfView:label offset:kBannerHSpacing];
    
    [bannerView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:tapSelector]];
    
    [self.view addSubview:bannerView];
    [bannerView autoPinToTopLayoutGuideOfViewController:self withInset:10];
    [bannerView autoHCenterInSuperview];
    
    CGFloat labelDesiredWidth = [label sizeThatFits:CGSizeZero].width;
    CGFloat bannerDesiredWidth
    = (labelDesiredWidth + kBannerHPadding + kBannerHSpacing + closeIcon.size.width + kBannerCloseButtonPadding);
    const CGFloat kMinBannerHMargin = 20.f;
    if (bannerDesiredWidth + kMinBannerHMargin * 2.f >= self.view.width) {
        [bannerView autoPinWidthToSuperviewWithMargin:kMinBannerHMargin];
    }
    
    [self.view layoutSubviews];
    
    self.bannerView = bannerView;
}

- (void)blockBannerViewWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    if ([self isBlockedContactConversation]) {
        // If this a blocked 1:1 conversation, offer to unblock the user.
        [self showUnblockContactUI:nil];
    } else if (self.isGroupConversation) {
        // If this a group conversation with at least one blocked member,
        // Show the block list view.
        int blockedGroupMemberCount = [self blockedGroupMemberCount];
        if (blockedGroupMemberCount > 0) {
            BlockListViewController *vc = [[BlockListViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

- (void)groupProfileWhitelistBannerWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    
    [self presentAddThreadToProfileWhitelistWithSuccess:^{
        [self ensureBannerState];
    }];
}

- (void)noLongerVerifiedBannerViewWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        NSArray<NSString *> *noLongerVerifiedRecipientIds = [self noLongerVerifiedRecipientIds];
        if (noLongerVerifiedRecipientIds.count < 1) {
            return;
        }
        BOOL hasMultiple = noLongerVerifiedRecipientIds.count > 1;
        
        UIAlertController *actionSheetController =
        [UIAlertController alertControllerWithTitle:nil
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];
        
        __weak ConversationViewController *weakSelf = self;
        UIAlertAction *verifyAction = [UIAlertAction
                                       actionWithTitle:(hasMultiple ? NSLocalizedString(@"VERIFY_PRIVACY_MULTIPLE",
                                                                                        @"Label for button or row which allows users to verify the safety "
                                                                                        @"numbers of multiple users.")
                                                        : NSLocalizedString(@"VERIFY_PRIVACY",
                                                                            @"Label for button or row which allows users to verify the safety "
                                                                            @"number of another user."))
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action) {
            [weakSelf showNoLongerVerifiedUI];
        }];
        [actionSheetController addAction:verifyAction];
        
        UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:CommonStrings.dismissButton
                                                                style:UIAlertActionStyleCancel
                                                              handler:^(UIAlertAction *action) {
            [weakSelf resetVerificationStateToDefault];
        }];
        [actionSheetController addAction:dismissAction];
        
        [self dismissKeyBoard];
        [self presentViewController:actionSheetController animated:YES completion:nil];
    }
}

- (void)resetVerificationStateToDefault
{
    OWSAssertIsOnMainThread();
    
    NSArray<NSString *> *noLongerVerifiedRecipientIds = [self noLongerVerifiedRecipientIds];
    for (NSString *recipientId in noLongerVerifiedRecipientIds) {
        OWSAssertDebug(recipientId.length > 0);
        
        OWSRecipientIdentity *_Nullable recipientIdentity =
        [[OWSIdentityManager sharedManager] recipientIdentityForRecipientId:recipientId];
        OWSAssertDebug(recipientIdentity);
        
        NSData *identityKey = recipientIdentity.identityKey;
        OWSAssertDebug(identityKey.length > 0);
        if (identityKey.length < 1) {
            continue;
        }
        
        [OWSIdentityManager.sharedManager setVerificationState:OWSVerificationStateDefault
                                                   identityKey:identityKey
                                                   recipientId:recipientId
                                         isUserInitiatedChange:YES
                                           isSendSystemMessage:NO];
    }
}

- (void)showUnblockContactUI:(nullable BlockActionCompletionBlock)completionBlock
{
    OWSAssertDebug([self.thread isKindOfClass:[TSContactThread class]]);
    
    self.userHasScrolled = NO;
    
    // To avoid "noisy" animations (hiding the keyboard before showing
    // the action sheet, re-showing it after), hide the keyboard before
    // showing the "unblock" action sheet.
    //
    // Unblocking is a rare interaction, so it's okay to leave the keyboard
    // hidden.
    [self dismissKeyBoard];
    
    NSString *contactIdentifier = ((TSContactThread *)self.thread).contactIdentifier;
    [BlockListUIUtils showUnblockPhoneNumberActionSheet:contactIdentifier
                                     fromViewController:self
                                        blockingManager:_blockingManager
                                        contactsManager:_contactsManager
                                        completionBlock:completionBlock];
}

- (BOOL)isBlockedContactConversation
{
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        return NO;
    }
    NSString *contactIdentifier = ((TSContactThread *)self.thread).contactIdentifier;
    return [[_blockingManager blockedPhoneNumbers] containsObject:contactIdentifier];
}

- (int)blockedGroupMemberCount
{
    OWSAssertDebug(self.isGroupConversation);
    OWSAssertDebug([self.thread isKindOfClass:[TSGroupThread class]]);
    
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    int blockedMemberCount = 0;
    NSArray<NSString *> *blockedPhoneNumbers = [_blockingManager blockedPhoneNumbers];
    for (NSString *contactIdentifier in groupThread.groupModel.groupMemberIds) {
        if ([blockedPhoneNumbers containsObject:contactIdentifier]) {
            blockedMemberCount++;
        }
    }
    return blockedMemberCount;
}

- (void)startReadTimer
{
    [self.readTimer invalidate];
    self.readTimer = [NSTimer weakScheduledTimerWithTimeInterval:3.f
                                                          target:self
                                                        selector:@selector(readTimerDidFire)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)readTimerDidFire
{
    [self markVisibleMessagesAsRead];
}

- (void)cancelReadTimer
{
    [self.readTimer invalidate];
    self.readTimer = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _viewDidAppear = true;
    
    if(!self.thread.isLargeGroupThread){
        [ProfileFetcherJob runWithThread:self.thread networkManager:self.networkManager];
    }
    
    [self markVisibleMessagesAsRead];
    [self startReadTimer];
    [self updateBackButtonUnreadCount];
    [self autoLoadMoreIfNecessary];
    
    switch (self.actionOnOpen) {
        case ConversationViewActionNone:
            break;
        case ConversationViewActionCompose:
            [self popKeyBoard];
            break;
        case ConversationViewActionAudioCall:
            [self startAudioCall];
            break;
        case ConversationViewActionVideoCall:
            [self startVideoCall];
            break;
    }
    
    // Clear the "on open" state after the view has been presented.
    self.actionOnOpen = ConversationViewActionNone;
    self.focusMessageIdOnOpen = nil;
    
    self.isViewCompletelyAppeared = YES;
    self.viewHasEverAppeared = YES;
    
    // HACK: Because the inputToolbar is the inputAccessoryView, we make some special considertations WRT it's firstResponder status.
    //
    // When a view controller is presented, it is first responder. However if we resign first responder
    // and the view re-appears, without being presented, the inputToolbar can become invisible.
    // e.g. specifically works around the scenario:
    // - Present this VC
    // - Longpress on a message to show edit menu, which entails making the pressed view the first responder.
    // - Begin presenting another view, e.g. swipe-left for details or swipe-right to go back, but quit part way, so that you remain on the conversation view
    // - toolbar will be not be visible unless we reaquire first responder.
    if (!self.isFirstResponder) {
        
        // We don't have to worry about the input toolbar being visible if the inputToolbar.textView is first responder
        // In fact doing so would unnecessarily dismiss the keyboard which is probably not desirable and at least
        // a distracting animation.
        if (!self.inputToolbar.isInputTextViewFirstResponder) {
            DDLogDebug(@"%@ reclaiming first responder to ensure toolbar is shown.", self.logTag);
            [self becomeFirstResponder];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCellsUserState];
    });
    [self performTranlateMessageWithDelayTime:1];
    
}
// `viewWillDisappear` is called whenever the view *starts* to disappear,
// but, as is the case with the "pan left for message details view" gesture,
// this can be canceled. As such, we shouldn't tear down anything expensive
// until `viewDidDisappear`.
- (void)viewWillDisappear:(BOOL)animated
{
    DDLogDebug(@"%@ viewWillDisappear", self.logTag);
    
    [super viewWillDisappear:animated];
    
    self.isViewCompletelyAppeared = NO;
    [self saveDraft];
    [[OWSWindowManager sharedManager] hideMenuActionsWindow];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.userHasScrolled = NO;
    self.isViewVisible = NO;
    
    [self.audioAttachmentPlayer stop];
    self.audioAttachmentPlayer = nil;
    
    [self cancelReadTimer];
    [self markVisibleMessagesAsRead];
    //    [self cancelVoiceMemo];
    [self.cellMediaCache removeAllObjects];
    
    self.isUserScrolling = NO;
}

#pragma mark - Initiliazers

- (void)updateNavigationTitle
{
    NSAttributedString *name = [self getNavgationTitle];
    if (self.conversationViewMode == ConversationViewMode_Main) {
        self.headerView.attributedTitle = name;
    }
}

- (NSAttributedString *)getNavgationTitle {
    
    
    NSAttributedString *name;
    if (self.thread.isGroupThread) {
        
        NSUInteger members = self.thread.recipientIdentifiers.count + 1;
        if (self.thread.name.length == 0) {
            
            name = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@(%ld)" ,[MessageStrings newGroupDefaultTitle], (long)members]];
        } else {
            name = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@(%ld)" ,self.thread.name, (long)members]];
        }
    } else {
        OWSAssertDebug(self.thread.contactIdentifier);
        
        if ([self.thread.contactIdentifier isEqualToString:[TSAccountManager localNumber]]) {
            
            name = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"LOCAL_ACCOUNT_DISPLAYNAME", @"")];
        } else {
            
            name =
            [self.contactsManager attributedContactOrProfileNameForPhoneIdentifier:self.thread.contactIdentifier
                                                                       primaryFont:self.headerView.titlePrimaryFont
                                                                     secondaryFont:self.headerView.titleSecondaryFont];
        }
    }
    
    if ([name isEqualToAttributedString:self.headerView.attributedTitle]) {
        return self.headerView.attributedTitle;
    }
    return name;
}

- (void)createHeaderViews
{
    _backButtonUnreadCountView = [UIView new];
    _backButtonUnreadCountView.layer.cornerRadius = self.unreadCountViewDiameter / 2;
    _backButtonUnreadCountView.backgroundColor = [UIColor redColor];
    _backButtonUnreadCountView.hidden = YES;
    _backButtonUnreadCountView.userInteractionEnabled = NO;
    
    _backButtonUnreadCountLabel = [UILabel new];
    _backButtonUnreadCountLabel.backgroundColor = [UIColor clearColor];
    _backButtonUnreadCountLabel.textColor = [UIColor whiteColor];
    _backButtonUnreadCountLabel.font = [UIFont systemFontOfSize:11];
    _backButtonUnreadCountLabel.textAlignment = NSTextAlignmentCenter;
    
    ConversationHeaderView *headerView =
    [[ConversationHeaderView alloc] initWithThread:self.thread contactsManager:self.contactsManager];
    self.headerView = headerView;
    
    headerView.delegate = self;
    
    
    if (self.conversationViewMode == ConversationViewMode_Thread) {
        if ([self.botViewItem.interaction isKindOfClass:TSMessage.class]) {
            TSMessage *currentMessage =  (TSMessage *)self.botViewItem.interaction;
            self.navigationItem.titleView = self.threadHeadView;
            self.threadHeadView.titleLabel.text = [self configureQuotedAuthorLabelWithAuthorId:currentMessage.botContext ? currentMessage.botContext.source.source : currentMessage.threadContext.source.source withGroupid:currentMessage.botContext.groupId?:currentMessage.threadContext.groupId];
        }
    }else{
        self.navigationItem.titleView = headerView;
    }
    
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGRect headerFrame = CGRectMake(0, 0, screenSize.width, 44);
    headerView.frame = headerFrame;
    
    
#ifdef USE_DEBUG_UI
    [headerView addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
                                      initWithTarget:self
                                      action:@selector(navigationTitleLongPressed:)]];
#endif
    
    [self updateNavigationTitle];
    [self updateNavigationBarSubtitleLabel];
}

- (NSString *)configureQuotedAuthorLabelWithAuthorId:(NSString *)authorId withGroupid:(nullable NSData *)groupid {
    
    if (!authorId) {
        return nil;
    }
    
    NSString *_Nullable localNumber = [TSAccountManager localNumber];
    NSString *quotedAuthorText = nil;
    if ([localNumber isEqualToString:authorId]) {
        quotedAuthorText = NSLocalizedString(@"CONVERSATION_TITLE_TO_SELF", "ConversationViewController title for placing call button");
        quotedAuthorText = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"CONVERSATION_TITLE_TO", "ConversationViewController title for placing call button"),quotedAuthorText];
    } else {
        if (groupid && groupid.length) {
            OWSContactsManager *contactsManager = Environment.current.contactsManager;
            NSString *quotedAuthor = [contactsManager contactOrProfileNameForPhoneIdentifier:authorId];
            quotedAuthorText = [NSString stringWithFormat:@"%@ %@/%@",NSLocalizedString(@"CONVERSATION_TITLE_TO", "ConversationViewController title for placing call button"),NSLocalizedString(@"CONVERSATION_TITLE_SOURCE_FROM_GROUP", "ConversationViewController title for placing call button"),quotedAuthor];
        }else{
            OWSContactsManager *contactsManager = Environment.current.contactsManager;
            NSString *quotedAuthor = [contactsManager contactOrProfileNameForPhoneIdentifier:authorId].ows_stripped;
            
            quotedAuthorText = [NSString stringWithFormat:@"%@ %@",NSLocalizedString(@"CONVERSATION_TITLE_TO", "ConversationViewController title for placing call button"),quotedAuthor];
        }
    }
    return quotedAuthorText;
}



- (CGFloat)unreadCountViewDiameter
{
    return 16;
}

- (void)createBackButton
{
    UIBarButtonItem *backItem = [self createOWSBackButton];
    if (backItem.customView) {
        // This method gets called multiple times, so it's important we re-layout the unread badge
        // with respect to the new backItem.
        [backItem.customView addSubview:_backButtonUnreadCountView];
        // TODO: The back button assets are assymetrical.  There are strong reasons
        // to use spacing in the assets to manipulate the size and positioning of
        // bar button items, but it means we'll probably need separate RTL and LTR
        // flavors of these assets.
        [_backButtonUnreadCountView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:-6];
        [_backButtonUnreadCountView autoPinLeadingToSuperviewMarginWithInset:1];
        [_backButtonUnreadCountView autoSetDimension:ALDimensionHeight toSize:self.unreadCountViewDiameter];
        // We set a min width, but we will also pin to our subview label, so we can grow to accommodate multiple digits.
        [_backButtonUnreadCountView autoSetDimension:ALDimensionWidth
                                              toSize:self.unreadCountViewDiameter
                                            relation:NSLayoutRelationGreaterThanOrEqual];
        
        [_backButtonUnreadCountView addSubview:_backButtonUnreadCountLabel];
        [_backButtonUnreadCountLabel autoPinWidthToSuperviewWithMargin:4];
        [_backButtonUnreadCountLabel autoPinHeightToSuperview];
        
        // Initialize newly created unread count badge to accurately reflect the current unread count.
        [self updateBackButtonUnreadCount];
    }
    
    self.navigationItem.leftBarButtonItem = backItem;
}

- (void)windowManagerCallDidChange:(NSNotification *)notification
{
    [self updateBarButtonItems];
}

- (void)updateBarButtonItems
{
    
    if (self.userLeftGroup || self.conversationViewMode == ConversationViewMode_Thread) {
        self.navigationItem.rightBarButtonItems = @[];
        return;
    }
    
    const CGFloat kBarButtonSize = 44;
    NSMutableArray<UIBarButtonItem *> *barButtons = [NSMutableArray new];
    
    UIButton *moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [[UIImage imageNamed:@"ic_navbar_info"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    moreButton.tintColor = Theme.primaryIconColor;
    UIEdgeInsets imageEdgeInsets = UIEdgeInsetsZero;
    [moreButton setImage:image forState:UIControlStateNormal];
    
    imageEdgeInsets.left = round((kBarButtonSize - image.size.width) * 0.5f);
    imageEdgeInsets.right = round((kBarButtonSize - (image.size.width + imageEdgeInsets.left)) * 0.5f);
    imageEdgeInsets.top = round((kBarButtonSize - image.size.height) * 0.5f);
    imageEdgeInsets.bottom = round(kBarButtonSize - (image.size.height + imageEdgeInsets.top));
    moreButton.imageEdgeInsets = imageEdgeInsets;
    //    moreButton.accessibilityLabel = NSLocalizedString(@"CALL_LABEL", "Accessibility label for placing call button");
    [moreButton addTarget:self action:@selector(moreButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    moreButton.frame = CGRectMake(0,0,
                                  round(image.size.width + imageEdgeInsets.left + imageEdgeInsets.right),
                                  round(image.size.height + imageEdgeInsets.top + imageEdgeInsets.bottom));
    [barButtons addObject:[[UIBarButtonItem alloc] initWithCustomView:moreButton]];
    
    if (self.shouldShowCallButton) {
        UIButton *btnCall = [UIButton buttonWithType:UIButtonTypeCustom];
        btnCall.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        UIImage *callImage = [[UIImage imageNamed:@"ic_voice_call"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        btnCall.tintColor = Theme.primaryIconColor;
        [btnCall setImage:callImage forState:UIControlStateNormal];
        //        btnCall.imageEdgeInsets = imageEdgeInsets;
        [btnCall addTarget:self action:@selector(btnCallAction:) forControlEvents:UIControlEventTouchUpInside];
        btnCall.frame = moreButton.frame;
        [barButtons addObject:[[UIBarButtonItem alloc] initWithCustomView:btnCall]];
    }
    
    if (self.disappearingMessagesConfiguration.isEnabled) {
        //        DisappearingTimerConfigurationView *timerView = [[DisappearingTimerConfigurationView alloc]
        //            initWithDurationSeconds:self.disappearingMessagesConfiguration.durationSeconds];
        //        timerView.delegate = self;
        //        timerView.tintColor = Theme.primaryIconColor;
        //
        //        // As of iOS11, we can size barButton item custom views with autoLayout.
        //        // Before that, though we can still use autoLayout *within* the customView,
        //        // setting the view's size with constraints causes the customView to be temporarily
        //        // laid out with a misplaced origin.
        //        if (@available(iOS 11.0, *)) {
        //            [timerView autoSetDimensionsToSize:CGSizeMake(36, 44)];
        //        } else {
        //            timerView.frame = CGRectMake(0, 0, 36, 44);
        //        }
        //
        //        [barButtons addObject:[[UIBarButtonItem alloc] initWithCustomView:timerView]];
    }
    
    self.navigationItem.rightBarButtonItems = [barButtons copy];
}

- (BOOL)shouldShowCallButton {
    
    if ([self.thread isKindOfClass:[TSContactThread class]]) {
        return ![self.thread.contactIdentifier isEqualToString:[TSAccountManager sharedInstance].localNumber] && self.thread.contactIdentifier.length > 6;
    }
    
    return YES;
}

- (void)moreButtonClick:(UIButton *)sender {
    [self showConversationSettings];
}

- (void)btnCallAction:(id)sender {
    
    [self startVideoCall];
}

- (void)updateNavigationBarSubtitleLabel
{
    NSMutableAttributedString *subtitleText = [NSMutableAttributedString new];
    
    UIColor *subtitleColor = Theme.secondaryTextAndIconColor;
    if (self.thread.isMuted) {
        // Show a "mute" icon before the navigation bar subtitle if this thread is muted.
        [subtitleText
         appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"\ue067  "
                                 attributes:@{
            NSFontAttributeName : [UIFont ows_elegantIconsFont:7.f],
            NSForegroundColorAttributeName : subtitleColor
         }]];
    }
    
    BOOL isVerified = YES;
    for (NSString *recipientId in self.thread.recipientIdentifiers) {
        if ([[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId]
            != OWSVerificationStateVerified) {
            isVerified = NO;
            break;
        }
    }
    if (isVerified) {
        // Show a "checkmark" icon before the navigation bar subtitle if this thread is verified.
        [subtitleText
         appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:@"\uf00c "
                                 attributes:@{
            NSFontAttributeName : [UIFont ows_fontAwesomeFont:10.f],
            NSForegroundColorAttributeName : subtitleColor,
         }]];
    }
    
    if (self.userLeftGroup) {
        [subtitleText
         appendAttributedString:[[NSAttributedString alloc]
                                 initWithString:NSLocalizedString(@"GROUP_YOU_LEFT", @"")
                                 attributes:@{
            NSFontAttributeName : self.headerView.subtitleFont,
            NSForegroundColorAttributeName : subtitleColor,
         }]];
    } else {
        if (self.thread.isGroupThread) {
            /*
             [subtitleText appendAttributedString:
             [[NSAttributedString alloc]
             initWithString:NSLocalizedString(@"MESSAGES_VIEW_TITLE_SUBTITLE",
             @"The subtitle for the messages view title indicates that the "
             @"title can be tapped to access settings for this conversation.")
             attributes:@{
             NSFontAttributeName : self.headerView.subtitleFont,
             NSForegroundColorAttributeName : subtitleColor,
             }]];
             */
        }else{
            subtitleText = nil;
            subtitleText = [NSMutableAttributedString new];
            SignalAccount *account = [_contactsManager signalAccountForRecipientId:self.thread.contactIdentifier];
            Contact *contact = account.contact;
            NSString *string = self.thread.contactIdentifier;
            if (account && contact) {
                if (contact.signature && contact.signature.length >0) {
                    string = contact.signature;
                }else if(contact.email && contact.email.length >0){
                    string = contact.email;
                }else {
                    string = contact.number;
                }
                
            }
            [subtitleText appendAttributedString:
             [[NSAttributedString alloc]
              initWithString:string?:@""
              attributes:@{
                NSFontAttributeName : self.headerView.subtitleFont,
                NSForegroundColorAttributeName : subtitleColor,
             }]];
        }
        
    }
    //    [self.headerView updateUserStateToUpdateUserStateImageViewWithThread:self.thread];
    
    if (subtitleText && ![self.headerView.attributedSubtitle.string isEqualToString:subtitleText.string]) {
        
        self.headerView.attributedSubtitle = subtitleText.copy;
    }
}


#pragma mark - Identity

/**
 * Shows confirmation dialog if at least one of the recipient id's is not confirmed.
 *
 * returns YES if an alert was shown
 *          NO if there were no unconfirmed identities
 */
- (BOOL)showSafetyNumberConfirmationIfNecessaryWithConfirmationText:(NSString *)confirmationText
                                                         completion:(void (^)(BOOL didConfirmIdentity))completionHandler
{
    return NO;
    /*
     [SafetyNumberConfirmationAlert presentAlertIfNecessaryWithRecipientIds:self.thread.recipientIdentifiers
     confirmationText:confirmationText
     contactsManager:self.contactsManager
     completion:^(BOOL didShowAlert) {
     // Pre iOS-11, the keyboard and inputAccessoryView will obscure the alert if the keyboard is up when the
     // alert is presented, so after hiding it, we regain first responder here.
     if (@available(iOS 11.0, *)) {
     // do nothing
     } else {
     [self becomeFirstResponder];
     }
     completionHandler(didShowAlert);
     }
     beforePresentationHandler:^(void) {
     if (@available(iOS 11.0, *)) {
     // do nothing
     } else {
     // Pre iOS-11, the keyboard and inputAccessoryView will obscure the alert if the keyboard is up when the
     // alert is presented.
     [self dismissKeyBoard];
     [self resignFirstResponder];
     }
     }];
     */
}

- (void)showFingerprintWithRecipientId:(NSString *)recipientId
{
    // Ensure keyboard isn't hiding the "safety numbers changed" interaction when we
    // return from FingerprintViewController.
    [self dismissKeyBoard];
    
    [FingerprintViewController presentFromViewController:self recipientId:recipientId];
}

#pragma mark - Calls

- (void)startAudioCall {
    
    [self callWithVideo:NO];
}

- (void)startVideoCall
{
    [self callWithVideo:YES];
}

- (void)callWithVideo:(BOOL)isVideo
{
    //    OWSAssertDebug([self.thread isKindOfClass:[TSContactThread class]]);
    
    if (![self canCall]) {
        DDLogWarn(@"Tried to initiate a call but thread is not callable.");
        return;
    }
    
    __weak ConversationViewController *weakSelf = self;
    if ([self isBlockedContactConversation]) {
        [self showUnblockContactUI:^(BOOL isBlocked) {
            if (!isBlocked) {
                [weakSelf callWithVideo:isVideo];
            }
        }];
        return;
    }
    
    BOOL didShowSNAlert =
    [self showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[CallStrings confirmAndCallButtonTitle]
                                                           completion:^(BOOL didConfirmIdentity) {
        if (didConfirmIdentity) {
            [weakSelf callWithVideo:isVideo];
        }
    }];
    if (didShowSNAlert) {
        return;
    }
    
    [self agoraRTMCallWithVideo:isVideo];
}

- (void)agoraRTMCallWithVideo:(BOOL) isVideo{
    if ([self.thread isKindOfClass:TSGroupThread.class]) {
        
        UIAlertController *alertController = [UIAlertController
                                              alertControllerWithTitle:@"Group Meeting"
                                              message:@"Start or join a group meeting now?"
                                              preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction
                                   actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
            //            if (isVideo) {
            [[DTMultiCallManager sharedManager] startCallWithThread:self.thread withCallType:DTCallTypeMultiVideo];
            //            }else {
            //                [[DTMultiCallManager sharedManager] startCallWithThread:self.thread ];
            //            }
            
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction
                                       actionWithTitle:@"Cancel"
                                       style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action) {
        }];
        
        [alertController addAction:cancelAction];
        [alertController addAction:okAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
    } else {
        //        if (isVideo) {
        [[DTMultiCallManager sharedManager] startCallWithThread:self.thread withCallType:DTCallType1v1Video];
        //        }else{
        //            [[DTMultiCallManager sharedManager] startCallWithThread:self.thread withCallType:DTCallType1v1Audio];
        //        }
        //
    }
}

- (BOOL)canCall {
    if (![self.thread isGroupThread]) {
        
        NSString *localNumber = [TSAccountManager localNumber];
        NSString *contactIdentifier = ((TSContactThread *)self.thread).contactIdentifier;
        return ![contactIdentifier isEqualToString:localNumber] && contactIdentifier.length > 6;
    } else {
        
        return YES;
    }
}

#pragma mark - Dynamic Text

/**
 Called whenever the user manually changes the dynamic type options inside Settings.
 
 @param notification NSNotification with the dynamic type change information.
 */
- (void)didChangePreferredContentSize:(NSNotification *)notification
{
    OWSLogInfo(@"%@ didChangePreferredContentSize", self.logTag);
    
    // Evacuate cached cell sizes.
    for (ConversationViewItem *viewItem in self.viewItems) {
        [viewItem clearCachedLayoutState];
    }
    [self resetContentAndLayout];
    [self.inputToolbar updateFontSizes];
}

#pragma mark - Actions

- (void)showNoLongerVerifiedUI
{
    NSArray<NSString *> *noLongerVerifiedRecipientIds = [self noLongerVerifiedRecipientIds];
    if (noLongerVerifiedRecipientIds.count > 1) {
        [self showConversationSettingsAndShowVerification:YES];
    } else if (noLongerVerifiedRecipientIds.count == 1) {
        // Pick one in an arbitrary but deterministic manner.
        NSString *recipientId = noLongerVerifiedRecipientIds.lastObject;
        [self showFingerprintWithRecipientId:recipientId];
    }
}

- (void)showConversationSettings
{
    [self showConversationSettingsAndShowVerification:NO];
}

- (void)showConversationSettingsAndShowVerification:(BOOL)showVerification
{
    if (self.userLeftGroup) {
        DDLogDebug(@"%@ Ignoring request to show conversation settings, since user left group", self.logTag);
        return;
    }
    
    OWSConversationSettingsViewController *settingsVC = [OWSConversationSettingsViewController new];
    settingsVC.conversationSettingsViewDelegate = self;
    [settingsVC configureWithThread:self.thread uiDatabaseConnection:self.uiDatabaseConnection];
    settingsVC.showVerificationOnAppear = showVerification;
    [self.navigationController pushViewController:settingsVC animated:YES];
}

#pragma mark - DisappearingTimerConfigurationViewDelegate

- (void)disappearingTimerConfigurationViewWasTapped:(DisappearingTimerConfigurationView *)disappearingTimerView
{
    DDLogDebug(@"%@ Tapped timer in navbar", self.logTag);
    [self showConversationSettings];
}

#pragma mark - Load More

- (void)autoLoadMoreIfNecessary {
    if ([self forbidLoadMore]) return;
    
    if (!self.showLoadMoreHeader && !self.showLoadMoreFooter) {
        return;
    }
    
    [self.navigationController.view layoutIfNeeded];
    CGSize navControllerSize = self.navigationController.view.frame.size;
    CGFloat loadThreshold = MAX(navControllerSize.width, navControllerSize.height);
    
    BOOL closeToTop = self.collectionView.contentOffset.y < loadThreshold;
    if (self.showLoadMoreHeader && closeToTop) {
        [self loadAnotherPageOfMessages];
        
        OWSLogDebug(@"autoLoadMoreHeaderData olderPageCount %lu", self.loadOlderPageCount);
    }
    
    CGFloat distanceFromBottom = self.collectionView.contentSize.height - self.collectionView.bounds.size.height - self.collectionView.contentOffset.y;
    BOOL closeToBottom = distanceFromBottom < loadThreshold;
    if (self.showLoadMoreFooter && closeToBottom) {
        self.loadNewerPageCount++;
        NSUInteger offset = self.lastRangeOffset > kYapDatabasePageSize ? self.lastRangeOffset - kYapDatabasePageSize : 0;
        self.lastRangeOffset = offset;
        [self resetMappings];
        
        OWSLogDebug(@"autoLoadMoreFooterData newerPageCount=%ld offset=%ld", (long)self.loadNewerPageCount, (long)offset);
    }
}

- (BOOL)forbidLoadMore {
    BOOL isMainAppAndActive = CurrentAppContext().isMainAppAndActive;
    return  self.isUserScrolling || !self.isViewVisible || !isMainAppAndActive;
}

- (void)loadAnotherPageOfMessages
{
    BOOL hasEarlierUnseenMessages = self.dynamicInteractions.unreadIndicator.hasMoreUnseenMessages;
    
    [self loadNMoreMessages:kYapDatabasePageSize];
    
    // Don’t auto-scroll after “loading more messages” unless we have “more unseen messages”.
    //
    // Otherwise, tapping on "load more messages" autoscrolls you downward which is completely wrong.
    if (hasEarlierUnseenMessages && !self.focusMessageIdOnOpen) {
        // Ensure view items are updated before trying to scroll to the
        // unread indicator.
        //
        // loadNMoreMessages calls resetMappings which calls ensureDynamicInteractions,
        // which may move the unread indicator, and for scrollToUnreadIndicatorAnimated
        // to work properly, the view items need to be updated to reflect that change.
        [self.databaseStorage.yapPrimaryStorage updateUIDatabaseConnectionToLatest];
        
        [self scrollToUnreadIndicatorAnimated];
    }
}

- (void)loadNMoreMessages:(NSUInteger)numberOfMessagesToLoad
{
    // We want to restore the current scroll state after we update the range, update
    // the dynamic interactions and re-layout.  Here we take a "before" snapshot.
    CGFloat scrollDistanceToBottom = self.safeContentHeight - self.collectionView.contentOffset.y;
    
    self.lastRangeLength = MIN(self.lastRangeLength + numberOfMessagesToLoad, (NSUInteger)kYapDatabaseRangeMaxLength);
    
    self.loadOlderPageCount++;
    
    [self resetMappings];
    
    [self.layout prepareLayout];
    
    self.collectionView.contentOffset = CGPointMake(0, self.safeContentHeight - scrollDistanceToBottom);
}

- (void)updateShowLoadMoreFooter{
    
    __block BOOL hasMoreData = NO;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:TSMessageDatabaseViewExtensionName];
        NSUInteger lastRow = [self.messageMappings numberOfItemsInGroup:[self getCurrentGrouping]] - 1;
        TSInteraction *lastInteraction = [viewTransaction lastObjectInGroup:[self getCurrentGrouping]];
        TSInteraction *interaction =
        [viewTransaction objectAtRow:lastRow inSection:0 withMappings:self.messageMappings];
        hasMoreData = (interaction != lastInteraction);
    }];
    self.showLoadMoreFooter = hasMoreData;
}

- (void)updateShowLoadMoreHeader
{
    if (self.lastRangeLength == kYapDatabaseRangeMaxLength) {
        self.showLoadMoreHeader = NO;
        return;
    }
    
    __block BOOL hasMoreData = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *readTransaction) {
        YapDatabaseReadTransaction *transaction = readTransaction.transitional_yapReadTransaction;
        
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:[self getDatabaseViewExtensionName]];
        TSInteraction *firstInteraction = nil;
        if (self.conversationViewMode == ConversationViewMode_Thread) {
            TSMessage *botmsg = (TSMessage *)self.botViewItem.interaction;
            firstInteraction = [viewTransaction firstObjectInGroup:botmsg.threadContextID];
        }else {
            
            firstInteraction = [viewTransaction firstObjectInGroup:self.thread.uniqueId];
        }
        TSInteraction *interaction =
        [viewTransaction objectAtRow:0 inSection:0 withMappings:self.messageMappings];
        hasMoreData = (interaction != firstInteraction);
        //        totalMessageCount =
        //            [viewTransaction numberOfItemsInGroup:self.thread.uniqueId];
        
        //        NSUInteger count = totalMessageCount;
        //        for (NSUInteger row = 0; row < count; row++) {
        //            TSInteraction *interaction =
        //                [viewTransaction objectAtIndex:row inGroup:self.thread.uniqueId];
        //            if([interaction isKindOfClass:[OWSDisappearingConfigurationUpdateInfoMessage class]]){
        //                totalMessageCount --;
        //            }
        //        }
    }];
    self.showLoadMoreHeader = hasMoreData;
}

- (void)setShowLoadMoreHeader:(BOOL)showLoadMoreHeader
{
    BOOL valueChanged = _showLoadMoreHeader != showLoadMoreHeader;
    
    _showLoadMoreHeader = showLoadMoreHeader;
    
    self.loadMoreHeader.hidden = !showLoadMoreHeader;
    self.loadMoreHeader.userInteractionEnabled = showLoadMoreHeader;
    
    if (valueChanged && self.isViewVisible) {
        [self resetContentAndLayout];
    }
}

- (void)updateDisappearingMessagesConfiguration
{
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        self.disappearingMessagesConfiguration =
        [OWSDisappearingMessagesConfiguration fetchObjectWithUniqueID:self.thread.uniqueId transaction:transaction];
    }];
}

- (void)setDisappearingMessagesConfiguration:(nullable OWSDisappearingMessagesConfiguration *)disappearingMessagesConfiguration {
    if (_disappearingMessagesConfiguration.isEnabled == disappearingMessagesConfiguration.isEnabled
        && _disappearingMessagesConfiguration.durationSeconds == disappearingMessagesConfiguration.durationSeconds) {
        return;
    }
    
    OWSLogInfo(@"%@ set \n %@ %@ ", self.logTag, _disappearingMessagesConfiguration, disappearingMessagesConfiguration);
    
    if (![self.thread.contactIdentifier isEqualToString:[TSAccountManager localNumber]]) { // 配置会话顶部 archive 提示
        if (disappearingMessagesConfiguration.durationSeconds > 0) {
            NSString *infoFormat = NSLocalizedString(@"ARCHIVE_NOTICE_DISAPPEARING_MESSAGES_CONFIGURATION",
                                                     @"Archive notice Info message embedding a {{time amount}}, see the *_TIME_AMOUNT strings for context.");
            //    NSString *durationString = [NSString formatDurationSeconds:disappearingMessagesConfiguration.durationSeconds useShortFormat:NO];
            NSUInteger days = disappearingMessagesConfiguration.durationSeconds/(24*60*60);
            NSString *durationString = [NSNumberFormatter localizedStringFromNumber:@(days) numberStyle:NSNumberFormatterNoStyle];
            self.archiveNoticeHeader.text = [NSString stringWithFormat:infoFormat, durationString];
            self.archiveNoticeHeader.hidden = NO;
        }
    }
    
    _disappearingMessagesConfiguration = disappearingMessagesConfiguration;
    /*
     if (_disappearingMessagesConfiguration != nil
     && (disappearingMessagesConfiguration == nil
     || disappearingMessagesConfiguration.isEnabled == NO
     || disappearingMessagesConfiguration.durationSeconds != OWSDisappearingMessagesConfigurationDefaultExpirationDuration
     || _disappearingMessagesConfiguration.isEnabled == NO
     || _disappearingMessagesConfiguration.durationSeconds != OWSDisappearingMessagesConfigurationDefaultExpirationDuration)){
     
     //    if ((disappearingMessagesConfiguration.isEnabled == NO
     //        || disappearingMessagesConfiguration.durationSeconds != OWSDisappearingMessagesConfigurationDefaultExpirationDuration)
     //        && _disappearingMessagesConfiguration == nil){
     
     disappearingMessagesConfiguration =
     [[OWSDisappearingMessagesConfiguration alloc] initDefaultWithThreadId:self.thread.uniqueId];
     [disappearingMessagesConfiguration save];
     
     OWSDisappearingConfigurationUpdateInfoMessage *infoMessage =
     [[OWSDisappearingConfigurationUpdateInfoMessage alloc]
     initWithTimestamp:[NSDate ows_millisecondTimeStamp]
     thread:self.thread
     configuration:disappearingMessagesConfiguration
     createdByRemoteName:nil
     createdInExistingGroup:NO];
     [infoMessage save];
     
     [OWSNotifyRemoteOfUpdatedDisappearingConfigurationJob
     runWithConfiguration:disappearingMessagesConfiguration
     thread:self.thread
     messageSender:self.messageSender];
     }
     */
    [self updateBarButtonItems];
}

- (void)updateMessageMappingRangeOptions {
    if (self.lastRangeLength == 0) {
        NSUInteger rangeLength = 0;
        
        // If this is the first time we're configuring the range length,
        // try to take into account the position of the unread indicator
        // and the "focus message".
        OWSAssertDebug(self.dynamicInteractions);
        
        // We'd like to include at least N seen messages,
        // to give the user the context of where they left off the conversation.
        const NSUInteger kPreferredSeenMessageCount = 1;
        
        if (self.focusMessageIdOnOpen) {
            //            OWSAssertDebug(self.dynamicInteractions.focusMessagePosition);
            if (self.dynamicInteractions.focusMessagePosition) {
                OWSLogDebug(@"%@ ensuring load of focus message: %@",
                            self.logTag,
                            self.dynamicInteractions.focusMessagePosition);
                rangeLength = MAX(rangeLength, 2 + kPreferredSeenMessageCount + self.dynamicInteractions.focusMessagePosition.unsignedIntegerValue);
            }
        }
        
        if (self.dynamicInteractions.unreadIndicator) {
            NSUInteger unreadIndicatorPosition
            = (NSUInteger)self.dynamicInteractions.unreadIndicator.unreadIndicatorPosition;
            
            // If there is an unread indicator, increase the initial load window
            // to include it.
            OWSAssertDebug(unreadIndicatorPosition > 0);
            OWSAssertDebug(unreadIndicatorPosition <= kYapDatabaseRangeMaxLength);
            
            rangeLength = MAX(rangeLength, unreadIndicatorPosition + kPreferredSeenMessageCount);
        }
        
        // 初始需要加载的消息位置所需偏移
        // 例如：1.第 100 条是未读，偏移是 101-25=76 2.第 100 条是搜索到的消息，偏移则是 103-25=78
        NSUInteger initialOffset = rangeLength > kYapDatabasePageSize ? rangeLength - kYapDatabasePageSize : 0;
        // try to load at least a single page of messages.
        rangeLength = kYapDatabasePageSize;
        
        YapDatabaseViewRangeOptions *rangeOptions = [YapDatabaseViewRangeOptions flexibleRangeWithLength:kYapDatabasePageSize
                                                                                                  offset:initialOffset
                                                                                                    from:YapDatabaseViewEnd];
        
        self.lastRangeLength = rangeLength;
        self.lastRangeOffset = initialOffset;
        
        OWSLogDebug(@"init rangeOptions length=%lu offset=%lu", self.lastRangeLength, self.lastRangeOffset);
        
        rangeOptions.maxLength = MAX(rangeLength, kYapDatabaseRangeMaxLength);
        rangeOptions.minLength = kYapDatabaseRangeMinLength;
        [self.messageMappings setRangeOptions:rangeOptions forGroup:self.thread.uniqueId];
    } else {
        
        NSUInteger rangeLength = (self.loadNewerPageCount + self.loadOlderPageCount) * kYapDatabasePageSize;
        
        // Range size should monotonically increase.
        rangeLength = MAX(rangeLength, self.lastRangeLength);
        
        // Enforce max range size.
        rangeLength = MIN(rangeLength, kYapDatabaseRangeMaxLength);
        
        YapDatabaseViewRangeOptions *rangeOptions = [YapDatabaseViewRangeOptions flexibleRangeWithLength:rangeLength
                                                                                                  offset:self.lastRangeOffset
                                                                                                    from:YapDatabaseViewEnd];
        
        self.lastRangeLength = rangeLength;
        
        
        rangeOptions.maxLength = MAX((NSUInteger)rangeLength, kYapDatabaseRangeMaxLength);
        rangeOptions.minLength = kYapDatabaseRangeMinLength;
        [self.messageMappings setRangeOptions:rangeOptions forGroup:self.thread.uniqueId];
        
        OWSLogDebug(@"rangeOptions length=%lu offset=%lu", self.lastRangeLength, self.lastRangeOffset);
        
        [self updateShowLoadMoreHeader];
        [self updateShowLoadMoreFooter];
    }
}

#pragma mark Bubble User Actions

- (void)handleFailedDownloadTapForMessage:(TSMessage *)message
                        attachmentPointer:(TSAttachmentPointer *)attachmentPointer
{
    
    NSString *title = nil;
    NSString *retryActionText = nil;
    if(attachmentPointer.state == TSAttachmentPointerStateEnqueued){
        retryActionText = NSLocalizedString(@"MESSAGES_VIEW_FAILED_DOWNLOAD_ACTION", @"Action sheet button text");
    }else{
        title = NSLocalizedString(@"MESSAGES_VIEW_FAILED_DOWNLOAD_ACTIONSHEET_TITLE", comment
                                  : "Action sheet title after tapping on failed download.");
        retryActionText = NSLocalizedString(@"MESSAGES_VIEW_FAILED_DOWNLOAD_RETRY_ACTION", @"Action sheet button text");
    }
    
    UIAlertController *actionSheetController = [UIAlertController
                                                alertControllerWithTitle:title
                                                message:nil
                                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    
    UIAlertAction *deleteMessageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_DELETE_TITLE", @"")
                                                                  style:UIAlertActionStyleDestructive
                                                                handler:^(UIAlertAction *action) {
        [message remove];
    }];
    [actionSheetController addAction:deleteMessageAction];
    
    UIAlertAction *retryAction = [UIAlertAction
                                  actionWithTitle:retryActionText
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action) {
        OWSAttachmentsProcessor *processor =
        [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer
                                                    networkManager:self.networkManager];
        [processor fetchAttachmentsForMessage:message
                                forceDownload:YES
                                      success:^(TSAttachmentStream *attachmentStream) {
            OWSLogInfo(
                       @"%@ Successfully redownloaded attachment in thread: %@", self.logTag, message.thread);
        }
                                      failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to redownload message with error: %@", self.logTag, error);
        }];
    }];
    
    [actionSheetController addAction:retryAction];
    
    [self dismissKeyBoard];
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)handleUnsentMessageTap:(TSOutgoingMessage *)message
{
    UIAlertController *actionSheetController =
    [UIAlertController alertControllerWithTitle:nil/*message.mostRecentFailureText*/
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    
    UIAlertAction *deleteMessageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_DELETE_TITLE", @"")
                                                                  style:UIAlertActionStyleDestructive
                                                                handler:^(UIAlertAction *action) {
        [message remove];
    }];
    [actionSheetController addAction:deleteMessageAction];
    
    UIAlertAction *resendMessageAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"SEND_AGAIN_BUTTON", @"")
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction *action) {
        [self.messageSender enqueueMessage:message
                                   success:^{
            OWSLogInfo(@"%@ Successfully resent failed message.", self.logTag);
        }
                                   failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to send message with error: %@", self.logTag, error);
        }];
    }];
    
    [actionSheetController addAction:resendMessageAction];
    
    [self dismissKeyBoard];
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)tappedNonBlockingIdentityChangeForRecipientId:(nullable NSString *)signalId
{
    if (signalId == nil) {
        if (self.thread.isGroupThread) {
            // Before 2.13 we didn't track the recipient id in the identity change error.
            DDLogWarn(@"%@ Ignoring tap on legacy nonblocking identity change since it has no signal id", self.logTag);
        } else {
            OWSLogInfo(
                       @"%@ Assuming tap on legacy nonblocking identity change corresponds to current contact thread: %@",
                       self.logTag,
                       self.thread.contactIdentifier);
            signalId = self.thread.contactIdentifier;
        }
    }
    
    [self showFingerprintWithRecipientId:signalId];
}

- (void)tappedCorruptedMessage:(TSErrorMessage *)message
{
    NSString *alertMessage = [NSString
                              stringWithFormat:NSLocalizedString(@"CORRUPTED_SESSION_DESCRIPTION", @"ActionSheet title"), self.thread.name];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:alertMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[OWSAlerts cancelAction]];
    
    UIAlertAction *resetSessionAction = [UIAlertAction
                                         actionWithTitle:NSLocalizedString(@"FINGERPRINT_SHRED_KEYMATERIAL_BUTTON", @"")
                                         style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction *action) {
        if (![self.thread isKindOfClass:[TSContactThread class]]) {
            // Corrupt Message errors only appear in contact threads.
            DDLogError(@"%@ Unexpected request to reset session in group thread. Refusing", self.logTag);
            return;
        }
        TSContactThread *contactThread = (TSContactThread *)self.thread;
        [OWSSessionResetJob runWithContactThread:contactThread
                                   messageSender:self.messageSender
                                  primaryStorage:self.databaseStorage.yapPrimaryStorage];
    }];
    [alertController addAction:resetSessionAction];
    
    [self dismissKeyBoard];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)tappedInvalidIdentityKeyErrorMessage:(TSInvalidIdentityKeyErrorMessage *)errorMessage
{
    NSString *keyOwner = [self.contactsManager displayNameForPhoneIdentifier:errorMessage.theirSignalId];
    NSString *titleFormat = NSLocalizedString(@"SAFETY_NUMBERS_ACTIONSHEET_TITLE", @"Action sheet heading");
    NSString *titleText = [NSString stringWithFormat:titleFormat, keyOwner];
    
    UIAlertController *actionSheetController =
    [UIAlertController alertControllerWithTitle:titleText
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    
    UIAlertAction *showSafteyNumberAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"SHOW_SAFETY_NUMBER_ACTION", @"Action sheet item")
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction *action) {
        OWSLogInfo(@"%@ Remote Key Changed actions: Show fingerprint display", self.logTag);
        [self showFingerprintWithRecipientId:errorMessage.theirSignalId];
    }];
    [actionSheetController addAction:showSafteyNumberAction];
    
    UIAlertAction *acceptSafetyNumberAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"ACCEPT_NEW_IDENTITY_ACTION", @"Action sheet item")
                             style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction *action) {
        OWSLogInfo(@"%@ Remote Key Changed actions: Accepted new identity key", self.logTag);
        
        // DEPRECATED: we're no longer creating these incoming SN error's per message,
        // but there will be some legacy ones in the wild, behind which await
        // as-of-yet-undecrypted messages
        if ([errorMessage isKindOfClass:[TSInvalidIdentityKeyReceivingErrorMessage class]]) {
            [errorMessage acceptNewIdentityKey];
        }
    }];
    [actionSheetController addAction:acceptSafetyNumberAction];
    
    [self dismissKeyBoard];
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)handleCallTap:(TSCall *)call
{
    OWSAssertDebug(call);
    
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        OWSFailDebug(@"%@ unexpected thread: %@ in %s", self.logTag, self.thread, __PRETTY_FUNCTION__);
        return;
    }
    
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:contactThread.contactIdentifier];
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:[CallStrings callBackAlertTitle]
                                          message:[NSString stringWithFormat:[CallStrings callBackAlertMessageFormat], displayName]
                                          preferredStyle:UIAlertControllerStyleAlert];
    
    __weak ConversationViewController *weakSelf = self;
    UIAlertAction *callAction = [UIAlertAction actionWithTitle:[CallStrings callBackAlertCallButton]
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        [weakSelf startAudioCall];
    }];
    [alertController addAction:callAction];
    [alertController addAction:[OWSAlerts cancelAction]];
    
    [self dismissKeyBoard];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)tappedAttributedMessage:(TSInfoMessage *)message{
    if(![message isKindOfClass:[TSInfoMessage class]]){
        return;
    }
    
    if (message.messageType == TSInfoMessageRecallMessage) {
        
        if(message.recall && message.recall.body.length){
            NSString *newText = [NSString stringWithFormat:@"%@%@", message.recall.body, DFInputAtEndChar];
            if(self.inputToolbar.originMessageText.length){
                newText = [NSString stringWithFormat:@"%@%@%@",self.inputToolbar.originMessageText, message.recall.body, DFInputAtEndChar];
            }
            [[message.recall.atPersons componentsSeparatedByString:@";"] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if(!obj.length){
                    return;
                }
                DFInputAtItem *item = [DFInputAtItem new];
                SignalAccount *account = [self.contactsManager signalAccountForRecipientId:obj];
                if(account){
                    item.uid = obj;
                    item.name = [NSString stringWithFormat:@"%@%@%@",DFInputAtStartChar, account.contactFullName, DFInputAtEndChar];
                    [self.inputToolbar.atCache addAtItem:item];
                }
            }];
            [self.inputToolbar setMessageText:newText animated:YES];
            [self.inputToolbar beginEditingTextMessage];
        }
    } else if (message.messageType == TSInfoMessagePinMessage) {
        //MARK: pin消息跳转
        [self scrollToOrigionMessageWithRealSource:message.realSource];
    }
}

#pragma mark - MessageActionsDelegate

- (void)messageActionsShowDetailsForItem:(ConversationViewItem *)conversationViewItem {
    [self showDetailViewForViewItem:conversationViewItem];
}

- (void)messageActionsTranslateForItem:(ConversationViewItem *)conversationViewItem {
    [self showTranslateLanguageAlertWithItem:(ConversationViewItem *)conversationViewItem];
}
- (void)messageActionsOriginalTranslateForItem:(ConversationViewItem *)conversationViewItem {
    TSMessage *message = (TSMessage *)conversationViewItem.interaction;
    DTTranslateMessage *translateMessage = message.translateMessage;
    if (![translateMessage.translatedType isEqual:@(DTTranslateMessageTypeOriginal)]) {
        translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
        message.translateMessage = translateMessage;
        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
            [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
        }];
    }
}
//translateAlert
- (void)showTranslateLanguageAlertWithItem:(ConversationViewItem *)conversationViewItem {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *englishAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"SETTINGS_SECTION_TRANSLATE_LANGUAGE_ENGLISH", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (![self isCacheTargetLanguageResultWithTargetLanguageType:DTTranslateMessageTypeEnglish viewItem:conversationViewItem]) {
            [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeEnglish item:conversationViewItem];//翻译成英文
        }else {
            TSMessage *message = (TSMessage *)conversationViewItem.interaction;
            DTTranslateMessage *translateMessage = message.translateMessage;
            translateMessage.translatedType = @(DTTranslateMessageTypeEnglish);
            translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
            message.translateMessage = translateMessage;
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
            }];
        }
        
    }];
    UIAlertAction *chinseAction = [UIAlertAction actionWithTitle: NSLocalizedString(@"SETTINGS_SECTION_TRANSLATE_LANGUAGE_CHINESE", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (![self isCacheTargetLanguageResultWithTargetLanguageType:DTTranslateMessageTypeChinese viewItem:conversationViewItem]) {
            [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeChinese item:conversationViewItem];//翻译成中文
        }else {
            TSMessage *message = (TSMessage *)conversationViewItem.interaction;
            DTTranslateMessage *translateMessage = message.translateMessage;
            translateMessage.translatedType = @(DTTranslateMessageTypeChinese);
            translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
            message.translateMessage = translateMessage;
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
            }];
        }
        
    }];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle: NSLocalizedString(@"TXT_CANCEL_TITLE", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertVC addAction:englishAction];
    [alertVC addAction:chinseAction];
    [alertVC addAction:cancelAction];
    [self presentViewController:alertVC animated:true completion:nil];
}
//是否缓存了目标语言的缓存
- (BOOL)isCacheTargetLanguageResultWithTargetLanguageType:(DTTranslateMessageType)type viewItem:(ConversationViewItem *) conversationViewItem {
    
    TSMessage *tmpMessage = (TSMessage *) conversationViewItem.interaction;
    TSMessage *message = [TSMessage fetchObjectWithUniqueID:tmpMessage.uniqueId];
    if (!message || (message && !message.translateMessage)) {
        return false;
    }
    if( (type == DTTranslateMessageTypeEnglish) &&  [message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] && message.translateMessage.tranEngLishResult.length){
        return true;
    }else if ((type == DTTranslateMessageTypeChinese) && [message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] && message.translateMessage.tranChinseResult.length) {
        return true;
    }else {
        return false;
    }
}
- (void)translateMessageWithTargetLanguageType:(DTTranslateMessageType)type item:(ConversationViewItem *)conversationViewItem{
    NSString *contents;
    TSMessage *message;
    if ([conversationViewItem.interaction isKindOfClass:[TSMessage class]]) {
        message = (TSMessage *)conversationViewItem.interaction;
    }
    if (message == nil) {
        return;
    }
    if (message.attachmentIds && message.attachmentIds.count) {//表示附件类型」
        NSString *attachmentUniqid = message.attachmentIds.firstObject;
        __block TSAttachment *_Nullable attachment;
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            attachment = [TSAttachment fetchObjectWithUniqueID:attachmentUniqid transaction:transaction.transitional_yapReadTransaction];
        }];
        
        if (attachment && [attachment isKindOfClass:TSAttachmentStream.class] ) {
            TSAttachmentStream * attachmentStream = (TSAttachmentStream *)attachment;
            NSData *textData = [NSData dataWithContentsOfURL:attachmentStream.mediaURL];
            NSString *text = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
            if ([attachmentStream.contentType isEqualToString:OWSMimeTypeOversizeTextMessage] && text && text.length > kOversizeTextMessageSizelength) {//处理长文本
                [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_LONG_TEXT", @"")];
                return;
            }else if ([attachmentStream.contentType isEqualToString:OWSMimeTypeOversizeTextMessage] && text && text.length <= kOversizeTextMessageSizelength){
                [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeTranslating translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE", @"")];
            }else{
                if (message.body) {//含消息体
                    contents = message.body;
                    [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeTranslating translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE", @"")];
                    [self requestTranslateLanguageWithItem:(TSMessage *)conversationViewItem.interaction sourceLang:nil targetLang:type contents:contents];
                }else{//不含消息体 直接失败
                    [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_FAILED", @"")];
                    return;
                }
            }
        }else{
            if (message.body) {
                contents = message.body;
                [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeTranslating translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE", @"")];
                [self requestTranslateLanguageWithItem:(TSMessage *)conversationViewItem.interaction sourceLang:nil targetLang:type contents:contents];
            }else{
                [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_FAILED", @"")];
                return;
            }
        }
    }else if ([message isSingleForward]){
        DTCombinedForwardingMessage *forwardingMessage = message.combinedForwardingMessage.subForwardingMessages.firstObject;
        TSAttachmentStream *attachmentStream = [conversationViewItem attachmentStream];
        NSData *textData = [NSData dataWithContentsOfURL:attachmentStream.mediaURL];
        NSString *text = [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
        if (attachmentStream && [attachmentStream.contentType isEqualToString:OWSMimeTypeOversizeTextMessage] && text && text.length > kOversizeTextMessageSizelength) {//处理长文本
            [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_LONG_TEXT", @"")];
            return;
        }
        contents = message.body;
        if (contents.length) {
            contents = forwardingMessage.body;
        }
        [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeTranslating translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE", @"")];
        [self requestTranslateLanguageWithItem:(TSMessage *)conversationViewItem.interaction sourceLang:nil targetLang:type contents:contents];
    } else {
        contents = message.body;
        [self handleTranslateStateWithMessage:message languageType:type translatedState:DTTranslateMessageStateTypeTranslating translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE", @"")];
        [self requestTranslateLanguageWithItem:(TSMessage *)conversationViewItem.interaction sourceLang:nil targetLang:type contents:contents];
    }
}

- (void)handleTranslateStateWithMessage:(TSMessage *)message languageType:(DTTranslateMessageType)languageType translatedState:(DTTranslateMessageStateType)type translateTipMessage:(nullable NSString *)tipMessage{
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
        DTTranslateMessage *translateMessage = [TSMessage fetchObjectWithUniqueID:message.uniqueId transaction:transaction.transitional_yapWriteTransaction].translateMessage;
        if(!translateMessage){
            translateMessage = [DTTranslateMessage new];
        }
        translateMessage.translatedState = @(type);
        translateMessage.translatedType = @(languageType);
        translateMessage.translateTipMessage = tipMessage;
        message.translateMessage = translateMessage;
        [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
    }];
}

//单条信息翻译
- (void)requestTranslateLanguageWithItem:(TSMessage *)message sourceLang:(nullable NSString *)sourceLanguage targetLang:(DTTranslateMessageType)targetLanguageType contents:(NSString *)contents {
    [self.translateApi sendRequestWithSourceLang:sourceLanguage targetLang:targetLanguageType contents:contents success:^(DTTranslateEntity * _Nonnull entity) {
        TSMessage *tmpMessage = [TSMessage fetchObjectWithUniqueID:message.uniqueId];
        if ([tmpMessage isKindOfClass:TSIncomingMessage.class] || [tmpMessage isKindOfClass:TSOutgoingMessage.class]) {//主要防止消息被撤回消息类型发生改变
            DTTranslateSingleEntity *translateSingleEntity;
            DTTranslateMessage *translateMessage = [tmpMessage.translateMessage copy];
            if (!translateMessage) {
                translateMessage = [DTTranslateMessage new];
            }
            translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
            if (entity && entity.data && entity.data.count) {
                translateSingleEntity = entity.data.firstObject;
            }
            if (translateSingleEntity) {
                switch (targetLanguageType) {
                    case DTTranslateMessageTypeOriginal:break;
                    case DTTranslateMessageTypeEnglish:{
                        translateMessage.translatedType = @(targetLanguageType);
                        translateMessage.tranEngLishResult = translateSingleEntity.translatedText;
                    }
                        break;
                    case DTTranslateMessageTypeChinese:{
                        translateMessage.translatedType = @(targetLanguageType);
                        translateMessage.tranChinseResult = translateSingleEntity.translatedText;
                    }
                        break;
                    default:
                        break;
                }
                message.translateMessage = translateMessage;
                [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
                    YapDatabaseReadWriteTransaction *transaction = writeTransaction.transitional_yapWriteTransaction;
                    [message saveWithTransaction:transaction];
                }];
            }else{
                [self handleTranslateStateWithMessage:message languageType:targetLanguageType translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_FAILED", @"")];
            }
        }else {
            return;
        }
        
    } failure:^(NSError * _Nonnull error) {
        [self handleTranslateStateWithMessage:message languageType:targetLanguageType translatedState:DTTranslateMessageStateTypeFailed translateTipMessage:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_FAILED", @"")];
        
        [DTToastHelper toastWithText:NSLocalizedString(@"TRANSLATE_TIP_MESSAGE_FAILED", nil) inView:self.view durationTime:2.5];
    }];
}

- (void)messageActionsReplyToItem:(ConversationViewItem *)conversationViewItem
{
    [self populateReplyForViewItem:conversationViewItem];
}

- (void)messageActionsForwardItem:(ConversationViewItem *)conversationViewItem {
    OWSAssertDebug(conversationViewItem);
    
    [self.forwardMessageItems addObject:conversationViewItem];
    [self showSelectThreadViewController];
    
}

- (void)messageActionsRecallItem:(ConversationViewItem *)conversationViewItem {
    OWSAssertDebug(conversationViewItem);
    
    if(![conversationViewItem.interaction isKindOfClass:[TSOutgoingMessage class]]){
        return;
    }
    
    BOOL (^checkPassedTimeBlock)(void) = ^{
        if (([NSDate ows_millisecondTimeStamp] - conversationViewItem.interaction.timestamp) > [DTRecallConfig fetchRecallConfig].timeoutInterval * 1000){
            
            UIAlertController *alertController =
            [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:NSLocalizedString(@"RECALL_PASSED_TIME", nil), [DateUtil formatToMinuteHourDayWeekWithTimeInterval:[DTRecallConfig fetchRecallConfig].timeoutInterval]]
                                                message:nil
                                         preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[OWSAlerts doneAction]];
            [self presentViewController:alertController animated:YES completion:nil];
            
            return YES;
        }else{
            return NO;
        }
    };
    
    if(checkPassedTimeBlock()){
        return;
    }
    
    UIAlertController *actionSheetController =
    [UIAlertController alertControllerWithTitle:NSLocalizedString(@"RECALL_CONFIRM_TITLE", nil)
                                        message:nil
                                 preferredStyle:UIAlertControllerStyleActionSheet];
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    UIAlertAction *confirmAction =
    [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                             style:UIAlertActionStyleDestructive
                           handler:^(UIAlertAction * _Nonnull action) {
        
        if(checkPassedTimeBlock()){
            return;
        }
        
        TSOutgoingMessage *originMessage = (TSOutgoingMessage *)conversationViewItem.interaction;
        [SVProgressHUD show];
        [ThreadUtil sendRecallMessageWithOriginMessage:originMessage
                                              inThread:self.thread
                                               success:^{
            DispatchMainThreadSafe(^{
                [SVProgressHUD dismiss];
            });
        } failure:^(NSError * _Nonnull error) {
            DispatchMainThreadSafe(^{
                [DTToastHelper toastWithText:NSLocalizedString(@"MESSAGE_STATUS_FAILED", @"Sent") inView:self.view durationTime:2];
            });
        }];
    }];
    [actionSheetController addAction:confirmAction];
    
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

- (void)messageActionsForwardItemToNote:(ConversationViewItem *)conversationViewItem {
    OWSAssertDebug(conversationViewItem);
    
    TSContactThread *noteToSelfThread = [TSContactThread getOrCreateThreadWithContactId:[TSAccountManager localNumber]];
    [DTForwardMessageHelper forwardMessageIsFromGroup:self.thread.isGroupThread targetThread:noteToSelfThread messages:@[(TSMessage *)conversationViewItem.interaction] success:^{
        DispatchMainThreadSafe(^{
            [DTToastHelper toastWithText:NSLocalizedString(@"MESSAGE_METADATA_VIEW_MESSAGE_STATUS_SENT", @"Sent") inView:self.view durationTime:1.5];
        });
    } failure:^(NSError * _Nonnull error) {
        DispatchMainThreadSafe(^{
            [DTToastHelper toastWithText:NSLocalizedString(@"MESSAGE_STATUS_FAILED", @"Sent") inView:self.view durationTime:1.5];
        });
    }];
}

- (void)messageActionsCreateTaskForItem:(ConversationViewItem *)conversationViewItem {
    OWSAssertDebug(conversationViewItem);
    
    NSString *taskName = conversationViewItem.displayableBodyText.fullText;
    OWSAssertDebug(taskName);
    //MARK: 截取前2000字符
    if (taskName.length > 2000) {
        taskName = [taskName substringToIndex:2000];
    }
    TSMessage *relatedMessage = (TSMessage *)conversationViewItem.interaction;
    
    DTLightTaskEntity *taskEntity = [DTLightTaskEntity new];
    taskEntity.name = taskName;
    taskEntity.priority = 3;
    if ([self.thread isKindOfClass:[TSGroupThread class]]) {
        taskEntity.gid = self.serverGroupId;
        if (DTParamsUtils.validateString(relatedMessage.atPersons)) {
            NSArray *atMembers = nil;
            NSMutableSet <NSString *> *finalMembers = [NSMutableSet new];
            if ([relatedMessage.atPersons containsString:@"MENTIONS_ALL"]) {
                atMembers = self.thread.recipientIdentifiers;
                [finalMembers addObjectsFromArray:atMembers];
                [finalMembers addObject:[TSAccountManager localNumber]];
            } else if ([relatedMessage.atPersons containsString:@"+"]) {
                atMembers = [relatedMessage.atPersons componentsSeparatedByString:@";"];
                [atMembers enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (obj.length) {
                        [finalMembers addObject:obj];
                    }
                }];
            }
            
            NSUInteger maxAssigneeCount = [DTTaskConfig fetchGroupConfig].maxAssigneeCount;
            if (finalMembers.count <= maxAssigneeCount) {
                NSMutableArray <DTTaskMemberEntity *> *users = @[].mutableCopy;
                for (NSString *memberId in finalMembers) {
                    DTTaskMemberEntity *user = [DTTaskMemberEntity new];
                    user.role = DTTaskMemberRoleAssignee;
                    user.uid = memberId;
                    [users addObject:user];
                }
                taskEntity.users = users.copy;
            }
        }
    } else {
        taskEntity.uid = self.thread.contactIdentifier;
        DTTaskMemberEntity *user = [DTTaskMemberEntity new];
        user.role = DTTaskMemberRoleAssignee;
        user.uid = self.thread.contactIdentifier;
        taskEntity.users = @[user];
    }
    
    [self addTaskWithEntity:taskEntity];
}

- (void)messageActionsPinItem:(ConversationViewItem *)conversationViewItem {
    OWSAssertDebug(conversationViewItem);
    
    TSMessage *targetMessage = (TSMessage *)conversationViewItem.interaction;
    if (conversationViewItem.isPinned) {
        [self unpinMessageWithPinId:targetMessage.pinId];
    } else {
        [self pinMessageWithMessage:targetMessage];
    }
}

- (void)messageActionsMultiSelectItem:(ConversationViewItem *)conversationViewItem {
    
    DDLogInfo(@"turn into multiple select mode");
    [self.forwardMessageItems addObject:conversationViewItem];
    
    self.isMultiSelectMode = YES;
    self.collectionView.allowsMultipleSelection = YES;
    [self reloadInputViews];
    [self dismissKeyBoard];
    [self.forwardToolbar showIn:self.view];
    [self.forwardToolbar updateActionItemsSelectedCount:1];
    [self leftEdgePanGestureDisabled:YES];
    [NSLayoutConstraint deactivateConstraints:self.collectionViewEdges];
    
    self.collectionViewEdges = [self.collectionView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 0, -40, 0)];
#ifdef DEBUG
    self.scrollUpButton.alpha = 0;
#endif
    self.scrollDownButton.alpha = 0;
    self.headerView.userInteractionEnabled = NO;
    self.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(cancelMultiSelectMode)];
    self.navigationItem.rightBarButtonItems = @[];
}

- (void)cancelMultiSelectMode {
    
    DDLogInfo(@"quit multiple select mode");
    [self.forwardMessageItems removeAllObjects];
    
    self.isMultiSelectMode = NO;
    self.collectionView.allowsMultipleSelection = NO;
    [UIView performWithoutAnimation:^{
        [self.collectionView reloadData];
    }];
    [self reloadInputViews];
    [self.forwardToolbar hideWithAnimated:NO];
    [self leftEdgePanGestureDisabled:NO];
    [NSLayoutConstraint deactivateConstraints:self.collectionViewEdges];
    self.collectionViewEdges = [self.collectionView autoPinEdgesToSuperviewEdges];
#ifdef DEBUG
    self.scrollUpButton.alpha = 1;
#endif
    self.scrollDownButton.alpha = 1;
    self.headerView.userInteractionEnabled = YES;
    self.navigationItem.leftBarButtonItem = self.navigationItem.backBarButtonItem;
    [self updateBarButtonItems];
}

#pragma mark - MenuActionsViewControllerDelegate

- (void)menuActionsDidHide:(MenuActionsViewController *)menuActionsViewController
{
    [[OWSWindowManager sharedManager] hideMenuActionsWindow];
    [self updateShouldObserveDBModifications];
}

- (void)menuActions:(MenuActionsViewController *)menuActionsViewController
isPresentingWithVerticalFocusChange:(CGFloat)verticalChange
{
    UIEdgeInsets oldInset = self.collectionView.contentInset;
    CGPoint oldOffset = self.collectionView.contentOffset;
    
    UIEdgeInsets newInset = oldInset;
    CGPoint newOffset = oldOffset;
    
    // In case the message is at the very top or bottom edge of the conversation we have to have these additional
    // insets to be sure we can sufficiently scroll the contentOffset.
    newInset.top += verticalChange;
    newInset.bottom -= verticalChange;
    newOffset.y -= verticalChange;
    
    DDLogDebug(@"%@ in %s verticalChange: %f, insets: %@ -> %@",
               self.logTag,
               __PRETTY_FUNCTION__,
               verticalChange,
               NSStringFromUIEdgeInsets(oldInset),
               NSStringFromUIEdgeInsets(newInset));
    
    // Because we're in the context of the frame-changing animation, these adjustments should happen
    // in lockstep with the messageActions frame change.
    self.collectionView.contentOffset = newOffset;
    self.collectionView.contentInset = newInset;
}

- (void)menuActions:(MenuActionsViewController *)menuActionsViewController
isDismissingWithVerticalFocusChange:(CGFloat)verticalChange
{
    UIEdgeInsets oldInset = self.collectionView.contentInset;
    CGPoint oldOffset = self.collectionView.contentOffset;
    
    UIEdgeInsets newInset = oldInset;
    CGPoint newOffset = oldOffset;
    
    // In case the message is at the very top or bottom edge of the conversation we have to have these additional
    // insets to be sure we can sufficiently scroll the contentOffset.
    newInset.top -= verticalChange;
    newInset.bottom += verticalChange;
    newOffset.y += verticalChange;
    
    DDLogDebug(@"%@ in %s verticalChange: %f, insets: %@ -> %@",
               self.logTag,
               __PRETTY_FUNCTION__,
               verticalChange,
               NSStringFromUIEdgeInsets(oldInset),
               NSStringFromUIEdgeInsets(newInset));
    
    // Because we're in the context of the frame-changing animation, these adjustments should happen
    // in lockstep with the messageActions frame change.
    self.collectionView.contentOffset = newOffset;
    self.collectionView.contentInset = newInset;
}

#pragma mark - ConversationViewCellDelegate
//快捷翻译按钮事件
- (void)didTapTranslateIncomeingWithViewItem:(ConversationViewItem *)conversationViewItem {//点击来的消息
    TSMessage *message = (TSMessage *) conversationViewItem.interaction;
    if (![message isKindOfClass:TSIncomingMessage.class]) {
        return;
    }
    if (message.translateMessage) {
        if([message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] && [message.translateMessage.translatedType isEqual:@(DTTranslateMessageTypeEnglish)] && message.translateMessage.tranEngLishResult.length){//表示翻译成英文且有结果
            DTTranslateMessage *translateMessage = message.translateMessage;
            translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
            message.translateMessage = translateMessage;
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
            }];
            
        }else if ([message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] && [message.translateMessage.translatedType isEqual:@(DTTranslateMessageTypeChinese)] && message.translateMessage.tranChinseResult.length) {//表示翻译成中文且有结果
            DTTranslateMessage *translateMessage = message.translateMessage;
            translateMessage.translatedType = @(DTTranslateMessageTypeOriginal);
            message.translateMessage = translateMessage;
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
            }];
        }else {//这个地方表示翻译失败了或则当前是原文展示 当前是翻译成目标语言
            if ([self isCurrentLanguageZh]) {//当前是中文
                if (message.translateMessage.tranChinseResult.length) {
                    DTTranslateMessage *translateMessage = message.translateMessage;
                    translateMessage.translatedType = @(DTTranslateMessageTypeChinese);
                    translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                    message.translateMessage = translateMessage;
                    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                        [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
                    }];
                }else{
                    [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeChinese item:conversationViewItem];
                }
            }else {//当前是其他语言翻译成英文
                if (message.translateMessage.tranEngLishResult.length) {
                    DTTranslateMessage *translateMessage = message.translateMessage;
                    translateMessage.translatedType = @(DTTranslateMessageTypeEnglish);
                    translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                    message.translateMessage = translateMessage;
                    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                        [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
                    }];
                }else{
                    [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeEnglish item:conversationViewItem];
                }
            }
        }
    }else {//目前展示的是原文 直接翻译成系统语言  只支持中英文
        if ([self isCurrentLanguageZh]) {//当前是中文
            if (message.translateMessage.tranChinseResult.length) {
                DTTranslateMessage *translateMessage = message.translateMessage;
                translateMessage.translatedType = @(DTTranslateMessageTypeChinese);
                translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                message.translateMessage = translateMessage;
                [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                    [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
                }];
            }else{
                [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeChinese item:conversationViewItem];
            }
        }else {//当前是其他语言翻译成英文
            if (message.translateMessage.tranEngLishResult.length) {
                DTTranslateMessage *translateMessage = message.translateMessage;
                translateMessage.translatedType = @(DTTranslateMessageTypeEnglish);
                translateMessage.translatedState = @(DTTranslateMessageStateTypeSucessed);
                message.translateMessage = translateMessage;
                [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                    [message saveWithTransaction:transaction.transitional_yapWriteTransaction];
                }];
            }else{
                [self translateMessageWithTargetLanguageType:DTTranslateMessageTypeEnglish item:conversationViewItem];
            }
        }
    }
}
//判断当前语言是否是中文
- (BOOL)isCurrentLanguageZh{
    NSArray *languages = [NSLocale preferredLanguages];
    NSString *currentLanguage = [languages objectAtIndex:0];
    if ([currentLanguage containsString:@"zh"])
    {
        return YES;
    }
    return NO;
}

- (BOOL)recipientsContainsBot{
    __block BOOL containsBot = NO;
    NSArray *recipients = @[];
    if([self.thread isGroupThread]){
        //        TSGroupThread *groupThread = (TSGroupThread *)self.thread;
        //        recipients = groupThread.groupModel.groupMemberIds;
        return NO;
    }else{
        if(self.thread.contactIdentifier.length){
            recipients = @[self.thread.contactIdentifier];
        }
    }
    [recipients enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(DTParamsUtils.validateString(obj)){
            NSString *numberString = [obj stringByReplacingOccurrencesOfString:@"+"withString:@""];
            if(numberString.length <= 6){
                containsBot = YES;
                *stop = YES;
            }
        }
    }];
    return containsBot;
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressTextViewItem:(ConversationViewItem *)viewItem
{
    TSMessage *message = (TSMessage *)viewItem.interaction;
    NSArray<MenuAction *> *messageActions;
    if(!message.translateMessage){//没翻译过
        messageActions = [viewItem textActionsContainTranslateWithDelegate:self];
    }else if (message.translateMessage && [message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] ) {//用户翻译过，且翻译成功
        if (![message.translateMessage.translatedType isEqual:@(DTTranslateMessageTypeOriginal)]) {
            //展示恢复原文按钮
            messageActions = [viewItem textActionsContainoriginalTranslateWithDelegate:self];
        }else {//展示翻译按钮
            messageActions = [viewItem textActionsContainTranslateWithDelegate:self];
        }
    }else {
        messageActions = [viewItem textActionsContainTranslateWithDelegate:self];//展示翻译按钮
    }
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressMediaViewItem:(ConversationViewItem *)viewItem
{
    NSArray<MenuAction *> *messageActions = [viewItem mediaActionsWithDelegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressQuoteViewItem:(ConversationViewItem *)viewItem
{
    NSArray<MenuAction *> *messageActions = [viewItem quotedMessageActionsWithDelegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressCombinedForwardingViewItem:(ConversationViewItem *)viewItem {
    NSArray<MenuAction *> *messageActions = [viewItem combinedForwardingMessageActionsWithDelegate:self];
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressContactMessageViewItem:(ConversationViewItem *)viewItem {
    NSArray<MenuAction *> *messageActions = [viewItem contactShareMessageActionsWithDelegate:self];
    
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressTaskViewItem:(ConversationViewItem *)viewItem {
    
    NSArray<MenuAction *> *messageActions = [viewItem taskMessageActionsWithDelegate:self];
    
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressVoteViewItem:(ConversationViewItem *)viewItem {
    NSArray<MenuAction *> *messageActions = [viewItem voteMessageActionsWithDelegate:self];
    
    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell didLongpressSystemMessageViewItem:(ConversationViewItem *)viewItem
{
    //    NSArray<MenuAction *> *messageActions = [viewItem infoMessageActionsWithDelegate:self];
    //    [self presentMessageActions:messageActions withFocusedCell:cell];
}

- (void)conversationCell:(ConversationViewCell *)cell threadInteractiveBarClick:(UIButton *)sender viewItem:(ConversationViewItem *)viewItem{
    [self presentThreadConversationControllerWithItem:viewItem];
}

- (void)conversationCell:(ConversationViewCell *)cell replyButtonClick:(UIButton *)sender viewItem:(ConversationViewItem *)viewItem {
    [self presentThreadConversationControllerWithItem:viewItem];
}

- (void)presentThreadConversationControllerWithItem:(ConversationViewItem *)viewItem {
    ConversationViewController *viewController = [ConversationViewController new];
    viewController.botViewItem = viewItem;
    [viewController configureForThread:self.thread action:ConversationViewActionNone focusMessageId:nil viewModel:ConversationViewMode_Thread];
    OWSNavigationController *threadNav = [[OWSNavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:threadNav animated:true completion:nil];
}

- (void)presentMessageActions:(NSArray<MenuAction *> *)messageActions withFocusedCell:(ConversationViewCell *)cell
{
    [self.forwardMessageItems removeAllObjects];
    [self dismissKeyBoard];
    
    OWSMessageBubbleView *bubbleView;
    for (UIView *view in cell.contentView.subviews) {
        if ([view isKindOfClass:OWSMessageBubbleView.class]) {
            bubbleView = (OWSMessageBubbleView *)view;
        }
    }
    MenuActionsViewController *menuActionsViewController;
    if (bubbleView) {
        menuActionsViewController =
        [[MenuActionsViewController alloc] initWithFocusedView:bubbleView actions:messageActions];
    }else {
        menuActionsViewController =
        [[MenuActionsViewController alloc] initWithFocusedView:cell actions:messageActions];
    }
    
    menuActionsViewController.delegate = self;
    
    [[OWSWindowManager sharedManager] showMenuActionsWindow:menuActionsViewController];
    
    [self updateShouldObserveDBModifications];
}

- (NSAttributedString *)attributedContactOrProfileNameForPhoneIdentifier:(NSString *)recipientId
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(recipientId.length > 0);
    
    return [self.contactsManager attributedContactOrProfileNameForPhoneIdentifier:recipientId];
}

- (void)tappedUnknownContactBlockOfferMessage:(OWSContactOffersInteraction *)interaction
{
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        OWSFailDebug(@"%@ unexpected thread: %@ in %s", self.logTag, self.thread, __PRETTY_FUNCTION__);
        return;
    }
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    
    NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:interaction.recipientId];
    NSString *title =
    [NSString stringWithFormat:NSLocalizedString(@"BLOCK_OFFER_ACTIONSHEET_TITLE_FORMAT",
                                                 @"Title format for action sheet that offers to block an unknown user."
                                                 @"Embeds {{the unknown user's name or phone number}}."),
     [BlockListUIUtils formatDisplayNameForAlertTitle:displayName]];
    
    UIAlertController *actionSheetController =
    [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheetController addAction:[OWSAlerts cancelAction]];
    
    UIAlertAction *blockAction = [UIAlertAction
                                  actionWithTitle:NSLocalizedString(
                                                                    @"BLOCK_OFFER_ACTIONSHEET_BLOCK_ACTION", @"Action sheet that will block an unknown user.")
                                  style:UIAlertActionStyleDestructive
                                  handler:^(UIAlertAction *action) {
        OWSLogInfo(@"%@ Blocking an unknown user.", self.logTag);
        [self.blockingManager addBlockedPhoneNumber:interaction.recipientId];
        // Delete the offers.
        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *transaction) {
            contactThread.hasDismissedOffers = YES;
            [contactThread saveWithTransaction:transaction.transitional_yapWriteTransaction];
            [interaction removeWithTransaction:transaction.transitional_yapWriteTransaction];
        }];
    }];
    [actionSheetController addAction:blockAction];
    
    [self dismissKeyBoard];
    [self presentViewController:actionSheetController animated:YES completion:nil];
}

/*
 - (void)tappedAddToContactsOfferMessage:(OWSContactOffersInteraction *)interaction
 {
 if (![self.thread isKindOfClass:[TSContactThread class]]) {
 OWSFailDebug(@"%@ unexpected thread: %@ in %s", self.logTag, self.thread, __PRETTY_FUNCTION__);
 return;
 }
 TSContactThread *contactThread = (TSContactThread *)self.thread;
 
 NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:interaction.recipientId];
 NSString *title =
 [NSString stringWithFormat:NSLocalizedString(@"ADD_OFFER_ACTIONSHEET_TITLE_FORMAT",
 @"Title format for action sheet that offers to add an unknown user."
 @"Embeds {{the unknown user's name or phone number}}."),
 [BlockListUIUtils formatDisplayNameForAlertTitle:displayName]];
 
 UIAlertController *actionSheetController =
 [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
 
 [actionSheetController addAction:[OWSAlerts cancelAction]];
 
 UIAlertAction *blockAction = [UIAlertAction
 actionWithTitle:NSLocalizedString(
 @"ADD_OFFER_ACTIONSHEET_ADD_ACTION", @"Action sheet that will block an unknown user.")
 style:UIAlertActionStyleDestructive
 handler:^(UIAlertAction *action) {
 OWSLogInfo(@"%@ Adding an unknown user to contact list.", self.logTag);
 // add user contact to contact list
 NSString *fullName = [[OWSProfileManager sharedManager] profileNameForRecipientId:interaction.recipientId];
 Contact * newContact = [[Contact alloc] initWithFullName:fullName phoneNumber:interaction.recipientId];
 __weak ConversationViewController *weakSelf = self;
 [self.contactsManager addUnknownContact:newContact addSuccess:^(NSString * _Nonnull result) {
 if ([result isEqualToString:@"ADD_CONTACT_ADD_SUCCESS"]) {
 // Delete the offers.
 [weakSelf.editingDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
 contactThread.hasDismissedOffers = YES;
 [contactThread saveWithTransaction:transaction];
 [interaction removeWithTransaction:transaction];
 }];
 }
 
 UIAlertController *alert = [UIAlertController
 alertControllerWithTitle:NSLocalizedString(@"COMMON_NOTICE_TITLE", @"Alert view title")
 message:NSLocalizedString(result, @"Add contact result description")
 preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"")
 style:UIAlertActionStyleDefault
 handler:nil
 ]];
 
 [weakSelf presentViewController:alert animated:YES completion:nil];
 }];
 }];
 [actionSheetController addAction:blockAction];
 
 [self dismissKeyBoard];
 [self presentViewController:actionSheetController animated:YES completion:nil];
 }
 */

- (void)tappedAddToProfileWhitelistOfferMessage:(OWSContactOffersInteraction *)interaction
{
    // This is accessed via the contact offer. Group whitelisting happens via a different interaction.
    if (![self.thread isKindOfClass:[TSContactThread class]]) {
        OWSFailDebug(@"%@ unexpected thread: %@ in %s", self.logTag, self.thread, __PRETTY_FUNCTION__);
        return;
    }
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    
    [self presentAddThreadToProfileWhitelistWithSuccess:^() {
        // Delete the offers.
        [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction *transaction) {
            contactThread.hasDismissedOffers = YES;
            [contactThread saveWithTransaction:transaction.transitional_yapWriteTransaction];
            [interaction removeWithTransaction:transaction.transitional_yapWriteTransaction];
        }];
    }];
}

- (void)presentAddThreadToProfileWhitelistWithSuccess:(void (^)(void))successHandler
{
    [[OWSProfileManager sharedManager] presentAddThreadToProfileWhitelist:self.thread
                                                       fromViewController:self
                                                                  success:successHandler];
}
#pragma mark DTSUserStateProtocol
/// 监听服务端指定用户的状态更新
/// @param message 获取到的消息体
- (void)onListenUpdateUserStatusFromServer:(SignalWebSocketRecieveUpdateUserStatusModel *)message {
    OWSLogInfo(@"ConversationViewController onListenUpdateUserStatusFromServer: 消息体 :%@ viewDidAppear:%d",[message signal_modelToJSONString], _viewDidAppear);
    if (!self) return;
    if(!self.thread || !message){
        return;
    }
    if (!message.data) {
        return;
    }
    if (_viewDidAppear) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dealUserStateChangeCellWith:message];
        });
    }else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dealUserStateChangeCellWith:message];
        });
    }
}

- (void)onUserStatesWebSoketDidConnect {
    OWSLogInfo(@"ConversationViewController onUserStatesWebSoketDidConnect viewDidAppear:%d",_viewDidAppear);
    if(_viewDidAppear){
        [self updateCellsUserState];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self updateCellsUserState];
        });
    }
}

- (void)dealUserStateChangeCellWith:(SignalWebSocketRecieveUpdateUserStatusModel *)message {
    OWSLogInfo(@"ConversationViewController onListenUpdateUserStatusFromServer: 消息体: %@ viewDidAppear: %d isGroupThread: %d",[message signal_modelToJSONString], _viewDidAppear,self.thread.isGroupThread);
    [self.collectionView layoutIfNeeded];
    if(!self.thread.isGroupThread) {
        [self updateNavigationBarSubtitleLabel];
    }
    NSArray <UICollectionViewCell*> *cellArr = self.collectionView.visibleCells;
    for (UICollectionViewCell *item in cellArr) {
        if (![item isKindOfClass:[OWSMessageCell class]]) continue;
        OWSMessageCell *reloadCell = (OWSMessageCell *)item;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:item];
        if (!indexPath) continue;
        NSUInteger row = (NSUInteger)indexPath.item;
        if (row + 1 > self.viewItems.count) {continue;}
        ConversationViewItem *viewItem = self.viewItems[(NSUInteger)indexPath.item];
        TSInteraction *interaction = viewItem.interaction;
        if([interaction isKindOfClass:[TSIncomingMessage class]]){
            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)viewItem.interaction;
            if (!incomingMessage) continue;
            if ([incomingMessage.authorId isEqualToString:message.data.number]) {
                [reloadCell reloadUserStateImage];
            }
        }else {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
            if (!outgoingMessage) continue;
            [reloadCell reloadUserStateImage];
        }
        
    }
}
- (void)updateCellsUserState {
    [self.collectionView layoutIfNeeded];
    if(!self.thread.isGroupThread){//私聊的时候去更新用户的顶部头像
        [self privateChatUpdateCellsUserState];
    }else {
        [self groupChatUpdateCellsUserState];
    }
    
}

//私聊用户更新用户状态
- (void)privateChatUpdateCellsUserState {
    OWSLogInfo(@"ConversationViewController privateChatUpdateCellsUserState 1v1私聊");
    [self updateNavigationBarSubtitleLabel];
    __weak typeof(self) weakSelf = self;
    DTSUserStateRequestModel *requestModel = [DTSUserStateRequestModel new];
    requestModel.contactIdentifier = self.thread.contactIdentifier;
    requestModel.indexpath = nil;
    
    DTSUserStateRequestModel *requestModelSelf = [DTSUserStateRequestModel new];
    requestModel.contactIdentifier = [TSAccountManager sharedInstance].localNumber;
    requestModel.indexpath = nil;
    
    [[DTSUserStateManager sharedManager] getUserStatusActionWithRecipientIdParams:@[requestModel,requestModelSelf] sucessCallback:^(SignalWebSocketBaseModel *socketResponseModel, NSArray<DTSUserStateRequestModel *> *arr) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf updateNavigationBarSubtitleLabel];
    }];
    [[DTSUserStateManager sharedManager] addListenUserStatusActionWithIncrementalRecipientIdParams:@[requestModel,requestModelSelf] sucessCallback:nil];
}

- (void)groupChatUpdateCellsUserState {
    OWSLogInfo(@"ConversationViewController groupChatUpdateCellsUserState 进入群组");
    NSArray *cellArrs = [self.collectionView visibleCells];
    NSMutableArray* cellSetArr = [NSMutableArray array];
    NSMutableArray <DTSUserStateRequestModel *>*userStateRequestModelArr = [NSMutableArray array];
    for (UICollectionViewCell *cell in cellArrs) {
        if ([cell isKindOfClass:[OWSMessageCell class]]) {
            NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
            if (!indexPath) continue;
            NSUInteger row = (NSUInteger)indexPath.item;
            if (row + 1 > self.viewItems.count) {continue;}
            ConversationViewItem *viewItem = self.viewItems[(NSUInteger)indexPath.item];
            TSInteraction *interaction = viewItem.interaction;
            NSMutableDictionary *cellSet = [NSMutableDictionary dictionary];
            if([interaction isKindOfClass:[TSIncomingMessage class]]){
                TSIncomingMessage *incomingMessage = (TSIncomingMessage *)viewItem.interaction;
                DTSUserStateRequestModel *requestModel = [[DTSUserStateRequestModel alloc]init];
                requestModel.indexpath = indexPath;
                requestModel.contactIdentifier = incomingMessage.authorId;
                [cellSet setValue:cell forKey:incomingMessage.authorId];
                [cellSetArr addObject:cellSet];
                [userStateRequestModelArr addObject:requestModel];
            }else {
                DTSUserStateRequestModel *requestModel = [[DTSUserStateRequestModel alloc]init];
                requestModel.indexpath = indexPath;
                requestModel.contactIdentifier = [TSAccountManager sharedInstance].localNumber;
                if (![TSAccountManager sharedInstance].localNumber) {continue;}
                [cellSet setValue:cell forKey:[TSAccountManager sharedInstance].localNumber];
                [cellSetArr addObject:cellSet];
                [userStateRequestModelArr addObject:requestModel];
            }
        }
    }
    [[DTSUserStateManager sharedManager] getUserStatusActionWithRecipientIdParams:userStateRequestModelArr sucessCallback:^(SignalWebSocketBaseModel *socketResponseModel, NSArray<DTSUserStateRequestModel *> *arr) {
        SignalWebSocketRecieveMessageModel *model = (SignalWebSocketRecieveMessageModel *)socketResponseModel;
        if (!model) return;
        SignalWebSocketRecieveUserStatusModel *data = model.data;
        if(!data) return;
        NSArray *userStatus = data.userStatus;
        if (userStatus && userStatus.count>0) {
            for (SignalUserStatesModel * state in userStatus) {
                if (!state) {continue;}
                if (!state.number) {continue;}
                if (!cellSetArr) {return;}
                [cellSetArr enumerateObjectsUsingBlock:^(NSDictionary *cellSet, NSUInteger idx, BOOL * _Nonnull stop) {
                    OWSMessageCell *reloadCell = [cellSet objectForKey:state.number];
                    if (reloadCell) {
                        [reloadCell reloadUserStateImage];
                    }
                }];
            }
        }
    }];
    [[DTSUserStateManager sharedManager] addListenUserStatusActionWithRecipientIdParams:userStateRequestModelArr.copy sucessCallback:nil];
}


#pragma mark - OWSMessageBubbleViewDelegate
- (void)didTapEmailOrUidString:(ConversationViewItem *)viewItem withuid:(NSString *)contactIdentifier {
    NSString *recipientId = [NSString stringWithFormat:@"%@%@",@"+",contactIdentifier];
    SignalAccount * signalAccount = [self.contactsViewHelper signalAccountForRecipientId:[NSString stringWithFormat:@"%@%@",@"+",contactIdentifier]];
    if (signalAccount) {
        DTPersonnalCardController *personnalVC = [DTPersonnalCardController new];
        [personnalVC configureWithRecipientId:recipientId withType:DTPersonnalCardTypeOther];
        [self.navigationController pushViewController:personnalVC animated:YES];
    }else{
        [DTToastHelper toastWithText:NSLocalizedString(@"TOAST_CAN_NOT_TO_PERSONCARD", @"vote now in view")  inView:self.view durationTime:2];
    }
}
- (void)didTapImageViewItem:(ConversationViewItem *)viewItem
           attachmentStream:(TSAttachmentStream *)attachmentStream
                  imageView:(UIView *)imageView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);
    OWSAssertDebug(imageView);
    
    [self dismissKeyBoard];
    
    // In case we were presenting edit menu, we need to become first responder before presenting another VC
    // else UIKit won't restore first responder status to us when the presented VC is dismissed.
    if (!self.isFirstResponder) {
        [self becomeFirstResponder];
    }
    
    if (![viewItem.interaction isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"Unexpected viewItem.interaction");
        return;
    }
    TSMessage *mediaMessage = (TSMessage *)viewItem.interaction;
    
    MediaGalleryViewController *vc = [[MediaGalleryViewController alloc]
                                      initWithThread:self.thread
                                      uiDatabaseConnection:self.uiDatabaseConnection
                                      options:MediaGalleryOptionSliderEnabled | MediaGalleryOptionShowAllMediaButton];
    
    [vc presentDetailViewFromViewController:self mediaMessage:mediaMessage replacingView:imageView];
}

- (void)didTapVideoViewItem:(ConversationViewItem *)viewItem
           attachmentStream:(TSAttachmentStream *)attachmentStream
                  imageView:(UIImageView *)imageView
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);
    
    [self dismissKeyBoard];
    // In case we were presenting edit menu, we need to become first responder before presenting another VC
    // else UIKit won't restore first responder status to us when the presented VC is dismissed.
    if (!self.isFirstResponder) {
        [self becomeFirstResponder];
    }
    
    if (![viewItem.interaction isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"Unexpected viewItem.interaction");
        return;
    }
    TSMessage *mediaMessage = (TSMessage *)viewItem.interaction;
    
    MediaGalleryViewController *vc = [[MediaGalleryViewController alloc]
                                      initWithThread:self.thread
                                      uiDatabaseConnection:self.uiDatabaseConnection
                                      options:MediaGalleryOptionSliderEnabled | MediaGalleryOptionShowAllMediaButton];
    
    [vc presentDetailViewFromViewController:self mediaMessage:mediaMessage replacingView:imageView];
}

- (void)didTapAudioViewItem:(ConversationViewItem *)viewItem attachmentStream:(TSAttachmentStream *)attachmentStream
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:[attachmentStream.mediaURL path]]) {
        OWSFailDebug(@"%@ Missing video file: %@", self.logTag, attachmentStream.mediaURL);
    }
    
    [self dismissKeyBoard];
    
    if (self.audioAttachmentPlayer) {
        // Is this player associated with this media adapter?
        if (self.audioAttachmentPlayer.owner == viewItem) {
            // Tap to pause & unpause.
            [self.audioAttachmentPlayer togglePlayState];
            return;
        }
        [self.audioAttachmentPlayer stop];
        self.audioAttachmentPlayer = nil;
    }
    self.audioAttachmentPlayer = [[OWSAudioPlayer alloc] initWithMediaUrl:attachmentStream.mediaURL delegate:viewItem];
    // Associate the player with this media adapter.
    self.audioAttachmentPlayer.owner = viewItem;
    [self.audioAttachmentPlayer playWithPlaybackAudioCategory];
}

#pragma mark - attachment preview

- (void)didTapGenericAttachmentViewItem:(ConversationViewItem *)viewItem
                       attachmentStream:(TSAttachmentStream *)attachmentStream{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentStream);
    
    NSString *filePath = attachmentStream.filePath;
    if(![[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        return;
    }
    
    DTPreviewViewController *previewContentViewController = [DTPreviewViewController new];
    previewContentViewController.filePath = filePath;
    previewContentViewController.modalPresentationStyle = UIModalPresentationFullScreen;
    UIView *snapshotView = [self.navigationController.view snapshotViewAfterScreenUpdates:YES];
    [previewContentViewController.view addSubview:snapshotView];
    [snapshotView autoPinEdgesToSuperviewEdges];
    [self presentViewController:previewContentViewController animated:NO completion:nil];
    
}

- (void)didTapTruncatedTextMessage:(ConversationViewItem *)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);
    
    LongTextViewController *view = [[LongTextViewController alloc] initWithViewItem:conversationItem];
    [self.navigationController pushViewController:view animated:YES];
}

- (void)didTapContactShareViewItem:(ConversationViewItem *)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug(conversationItem.contactShare);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);
    
    //    ContactViewController *view = [[ContactViewController alloc] initWithContactShare:conversationItem.contactShare];
    //    [self.navigationController pushViewController:view animated:YES];
    DTPersonnalCardController *personCardVC = [[DTPersonnalCardController alloc] init];
    NSString *shareContactId = conversationItem.contactShare.phoneNumbers[0].phoneNumber;
    [personCardVC configureWithRecipientId:shareContactId withType:DTPersonnalCardTypeOther];
    [self.navigationController pushViewController:personCardVC animated:true];
}

/*
 - (void)didTapSendMessageToContactShare:(ContactShareViewModel *)contactShare
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(contactShare);
 
 [self.contactShareViewHelper sendMessageWithContactShare:contactShare fromViewController:self];
 }
 
 - (void)didTapSendInviteToContactShare:(ContactShareViewModel *)contactShare
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(contactShare);
 
 [self.contactShareViewHelper showInviteContactWithContactShare:contactShare fromViewController:self];
 }
 
 - (void)didTapShowAddToContactUIForContactShare:(ContactShareViewModel *)contactShare
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug(contactShare);
 
 [self.contactShareViewHelper showAddToContactsWithContactShare:contactShare fromViewController:self];
 }
 */

- (void)didTapFailedIncomingAttachment:(ConversationViewItem *)viewItem
                     attachmentPointer:(TSAttachmentPointer *)attachmentPointer
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentPointer);
    
    // Restart failed downloads
    TSMessage *message = (TSMessage *)viewItem.interaction;
    [self handleFailedDownloadTapForMessage:message attachmentPointer:attachmentPointer];
}

- (void)didTapFailedOutgoingMessage:(TSOutgoingMessage *)message
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(message);
    
    [self handleUnsentMessageTap:message];
}

// added: handler for tap group member avatar
- (void)didTapAvatarWithRecipientId:(NSString *)recipientId {
    DTPersonnalCardController *personnalVC = [DTPersonnalCardController new];
    [personnalVC configureWithRecipientId:recipientId withType:DTPersonnalCardTypeOther];
    [self.navigationController pushViewController:personnalVC animated:YES];
}


// added: handler for longPress group member avatar
- (void)didLongPressAvatarWithRecipientId:(NSString *)recipientId senderName:(nullable NSString *)name {
    OWSAssertDebug(recipientId.length > 0);
    
    if (!self.isGroupConversation) {
        return;
    }
    
    NSString *originMessageText = self.inputToolbar.originMessageText;
    
    NSString *atMember = [NSString stringWithFormat:@"@%@", name.length > 0 ? [NSString stringWithFormat:@"%@",name] : @""];
    if (![atMember hasSuffix:DFInputAtEndChar]) {
        atMember = [NSString stringWithFormat:@"%@ ", atMember];
    }
    if (![originMessageText containsString:atMember]) { // 避免重复长按头像 at
        NSString *textWithAt = [NSString stringWithFormat:@"%@@",self.inputToolbar.originMessageText];
        [self.inputToolbar setMessageText:textWithAt animated:NO];
        
        [self selectAtPersonRecipientId:recipientId name:(name ? name : @"")];
    }
}

- (void)didTapConversationItem:(ConversationViewItem *)viewItem
                   quotedReply:(OWSQuotedReplyModel *)quotedReply
failedThumbnailDownloadAttachmentPointer:(TSAttachmentPointer *)attachmentPointer
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(attachmentPointer);
    
    TSMessage *message = (TSMessage *)viewItem.interaction;
    if (![message isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"%@ in %s message had unexpected class: %@", self.logTag, __PRETTY_FUNCTION__, message.class);
        return;
    }
    
    OWSAttachmentsProcessor *processor =
    [[OWSAttachmentsProcessor alloc] initWithAttachmentPointer:attachmentPointer
                                                networkManager:self.networkManager];
    
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
        [processor fetchAttachmentsForMessage:nil
                                forceDownload:YES
                                  transaction:transaction.transitional_yapWriteTransaction
                                      success:^(TSAttachmentStream *attachmentStream) {
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *postSuccessTransaction) {
                [message setQuotedMessageThumbnailAttachmentStream:attachmentStream];
                [message saveWithTransaction:postSuccessTransaction.transitional_yapWriteTransaction];
            }];
        }
                                      failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to redownload thumbnail with error: %@", self.logTag, error);
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *postFailTransaction) {
                [message touchWithTransaction:postFailTransaction.transitional_yapWriteTransaction];
            }];
        }];
    }];
}

- (void)didTapConversationItem:(ConversationViewItem *)viewItem quotedReply:(OWSQuotedReplyModel *)quotedReply
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(quotedReply);
    OWSAssertDebug(quotedReply.timestamp > 0);
    OWSAssertDebug(quotedReply.authorId.length > 0);
    
    // We try to find the index of the item within the current thread's
    // interactions that includes the "quoted interaction".
    //
    // NOTE: There are two indices:
    //
    // * The "group index" of the member of the database views group at
    //   the db conneciton's current checkpoint.
    // * The "index row/section" in the message mapping.
    //
    // NOTE: Since the range _IS NOT_ filtered by author,
    // and timestamp collisions are possible, it's possible
    // for:
    //
    // * The range to include more than the "quoted interaction".
    // * The range to be non-empty but NOT include the "quoted interaction",
    //   although this would be a bug.
    
    DTRealSourceEntity *realSource = [DTRealSourceEntity new];
    realSource.source = quotedReply.authorId;
    realSource.timestamp = quotedReply.timestamp;
    [self scrollToOrigionMessageWithRealSource:realSource];
}

- (void)didTapCombinedForwardingItem:(ConversationViewItem *)viewItem {
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    OWSAssertDebug(viewItem.combinedForwardingMessage);
    OWSAssertDebug(viewItem.combinedForwardingMessage.subForwardingMessages.count > 0);
    OWSAssertDebug(viewItem.combinedForwardingMessage.timestamp > 0);
    OWSAssertDebug(viewItem.combinedForwardingMessage.authorId.length > 0);
    
    if (![viewItem.interaction isKindOfClass:[TSMessage class]]) {
        OWSFailDebug(@"Unexpected viewItem.interaction");
        return;
    }
    
    TSMessage *combinedMessage = (TSMessage *)viewItem.interaction;
    BOOL isGroupChat = combinedMessage.combinedForwardingMessage.isFromGroup;
    DTCombinedMessageController *combinedMessageVC = [DTCombinedMessageController new];
    [combinedMessageVC configureWithThread:self.thread combinedMessage:(TSMessage *)viewItem.interaction isGroupChat:isGroupChat];
    [self.navigationController pushViewController:combinedMessageVC animated:YES];
}

- (void)didTapTaskDetailItem:(ConversationViewItem *)viewItem {
    
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem.task);
    
    DTLightTaskController *lightTaskController = [DTLightTaskController new];
    lightTaskController.shouldUseTheme = YES;
    [lightTaskController configTaskWithTaskId:viewItem.task.taskId];
    [self.navigationController pushViewController:lightTaskController animated:YES];
}

//投票按钮的事件
- (void)voteMessageView:(DTVoteMessageView *)voteView voteButtonClick:(UIButton *)sender withInfo:(NSDictionary *)parms {
    
    if (self.userLeftGroup) {
        return;
    }
    
    sender.userInteractionEnabled  = false;
    sender.selected = false;
    [sender setTitle:NSLocalizedString(@"VOTE_CREAT_VOTING", @"vote now in view")  forState:UIControlStateNormal];
    [self.voteNowApi voteRequestWithParms:parms success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTVoteMessageEntity *messageEntity = [MTLJSONAdapter modelOfClass:[DTVoteMessageEntity class] fromJSONDictionary:entity.data error:&error];
        if (messageEntity && !error) {
            //VOTING_HAS_ENDED
            sender.userInteractionEnabled  = false;
            sender.selected = false;
            [sender setTitle:NSLocalizedString(@"VOTE_CREAT_VOTE_NOW", @"vote now in view")  forState:UIControlStateNormal];
            [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
                YapDatabaseReadWriteTransaction *transaction = writeTransaction.transitional_yapWriteTransaction;
                
                DTVoteMessageEntity *localVote = [DTVoteMessageEntity fetchObjectWithUniqueID:messageEntity.voteId transaction:transaction];
                [localVote updateWithTransaction:transaction changeBlock:^(DTVoteMessageEntity * _Nonnull entity_) {
                    entity_.version = messageEntity.version;
                    entity_.status = messageEntity.status;
                    entity_.votersCount = messageEntity.votersCount;
                    entity_.totalVotes = messageEntity.totalVotes;
                    [entity_.options enumerateObjectsUsingBlock:^(DTVoteOptionEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        obj.count = messageEntity.options[idx].count;
                    }];
                    if (messageEntity.selected && (!localVote.selected || localVote.selected.count == 0)) {
                        entity_.selected = messageEntity.selected;
                    }
                    
                    if (messageEntity.status == OWSSignalServiceProtosDataMessageVoteStatusClosed) {
                        [DTToastHelper toastWithText:NSLocalizedString(@"VOTING_HAS_ENDED", @"vote now in view") inView:self.view durationTime:3];
                        return;
                    }
                    if (messageEntity.voted) {
                        [DTToastHelper toastWithText:NSLocalizedString(@"VOTING_HAS_VOTED", @"vote now in view") inView:self.view durationTime:3];
                        return;
                    }
                }];
            }];
            
        }else{
            sender.userInteractionEnabled  = true;
            sender.selected = true;
        }
    } failure:^(NSError * _Nonnull error) {
        sender.selected = true;
        sender.userInteractionEnabled = true;
        [sender setTitle:NSLocalizedString(@"VOTE_CREAT_VOTE_NOW", @"vote now in view")  forState:UIControlStateNormal];
    }];
}

- (void)voteMessageView:(DTVoteMessageView *)voteView voteResultBottomView:(DTVoteResultBottomView *)resultView voteEndResultBtnClick:(UIButton *)sender {
    DTVoteListViewController *voteListVC = [DTVoteListViewController new];
    voteListVC.voteEntity = [voteView voteEntity];
    [self.navigationController pushViewController:voteListVC animated:true];
}

- (void)didTapMoreTasksItem:(ConversationViewItem *)viewItem{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    
    UITabBarController *tabBarVC = self.navigationController.tabBarController;
    tabBarVC.selectedIndex = 2;
    [self.navigationController popToRootViewControllerAnimated:NO];
}

- (void)didTapReadStatusAction:(ConversationViewItem *)conversationItem{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);
    
    TSMessage *message = (TSMessage *)conversationItem.interaction;
    
    if(self.thread.isLargeGroupThread && [message isKindOfClass:[TSOutgoingMessage class]]){
        DTMessageDetailViewController *detailVc = [[DTMessageDetailViewController alloc] initWithMessage:(TSOutgoingMessage *)message];
        [self.navigationController pushViewController:detailVc animated:YES];
        
    }else{
        MessageDetailViewController *view =
        [[MessageDetailViewController alloc] initWithViewItem:conversationItem
                                                      message:message
                                                       thread:self.thread
                                                         mode:MessageMetadataViewModeFocusOnMetadata];
        [self.navigationController pushViewController:view animated:YES];
    }
    
}

- (nullable NSNumber *)findGroupIndexOfThreadInteraction:(TSInteraction *)interaction
                                             transaction:(YapDatabaseReadTransaction *)transaction
{
    OWSAssertDebug(interaction);
    OWSAssertDebug(transaction);
    
    YapDatabaseAutoViewTransaction *_Nullable extension = [transaction extension:[self getDatabaseViewExtensionName]];
    if (!extension) {
        OWSFailDebug(@"%@ Couldn't load view.", self.logTag);
        return nil;
    }
    
    NSUInteger groupIndex = 0;
    BOOL foundInGroup =
    [extension getGroup:nil index:&groupIndex forKey:interaction.uniqueId inCollection:TSInteraction.collection];
    if (!foundInGroup) {
        DDLogError(@"%@ Couldn't find quoted message in group.", self.logTag);
        return nil;
    }
    return @(groupIndex);
}

- (void)showDetailViewForViewItem:(ConversationViewItem *)conversationItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(conversationItem);
    OWSAssertDebug([conversationItem.interaction isKindOfClass:[TSMessage class]]);
    
    TSMessage *message = (TSMessage *)conversationItem.interaction;
    
    if(self.thread.isLargeGroupThread && [message isKindOfClass:[TSOutgoingMessage class]]){
        DTMessageDetailViewController *detailVc = [[DTMessageDetailViewController alloc] initWithMessage:(TSOutgoingMessage *)message];
        [self.navigationController pushViewController:detailVc animated:YES];
        
    }else{
        MessageDetailViewController *view =
        [[MessageDetailViewController alloc] initWithViewItem:conversationItem
                                                      message:message
                                                       thread:self.thread
                                                         mode:MessageMetadataViewModeFocusOnMetadata];
        [self.navigationController pushViewController:view animated:YES];
    }
    
}
//长按回复的处理
- (void)populateReplyForViewItem:(ConversationViewItem *)conversationItem {
    DDLogDebug(@"%@ user did tap reply", self.logTag);
    
    __block OWSQuotedReplyModel *quotedReply;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        quotedReply = [OWSQuotedReplyModel quotedReplyForConversationViewItem:conversationItem transaction:transaction];
    }];
    
    if (![quotedReply isKindOfClass:[OWSQuotedReplyModel class]]) {
        OWSFailDebug(@"%@ unexpected quotedMessage: %@", self.logTag, quotedReply.class);
        return;
    }
    
    TSMessage *message = (TSMessage *)conversationItem.interaction;
    quotedReply = [self dealQuotedReplyModelWith:quotedReply message:message inputToolbar:self.inputToolbar];
    quotedReply.viewModel = self.conversationViewMode;
    quotedReply.quotedType = DTPreviewQuotedType_Quote;
    quotedReply.longPressed = true;
    quotedReply.quoteItem = conversationItem;
    self.inputToolbar.quotedReply = quotedReply;
    [self.inputToolbar beginEditingTextMessage];
}

#pragma mark - ContactEditingDelegate

- (void)didFinishEditingContact
{
    DDLogDebug(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark - CNContactViewControllerDelegate

//- (void)contactViewController:(CNContactViewController *)viewController
//       didCompleteWithContact:(nullable CNContact *)contact
//{
//    if (contact) {
//        // Saving normally returns you to the "Show Contact" view
//        // which we're not interested in, so we skip it here. There is
//        // an unfortunate blip of the "Show Contact" view on slower devices.
//        DDLogDebug(@"%@ completed editing contact.", self.logTag);
//        [self dismissViewControllerAnimated:NO completion:nil];
//    } else {
//        DDLogDebug(@"%@ canceled editing contact.", self.logTag);
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }
//}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    
    if(!self.thread.isLargeGroupThread){
        [self ensureDynamicInteractions];
    }
    
}

- (void)ensureDynamicInteractions
{
    OWSAssertIsOnMainThread();
    
    const int currentMaxRangeSize = (int)self.lastRangeLength;
    const int maxRangeSize = MAX(kConversationInitialMaxRangeSize, currentMaxRangeSize);
    
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull readTransaction) {
        self.dynamicInteractions = [ThreadUtil ensureDynamicInteractionsForThread:self.thread
                                                                  contactsManager:self.contactsManager
                                                                  blockingManager:self.blockingManager
                                                      hideUnreadMessagesIndicator:self.hasClearedUnreadMessagesIndicator
                                                              lastUnreadIndicator:self.dynamicInteractions.unreadIndicator
                                                                   focusMessageId:self.focusMessageIdOnOpen
                                                                     maxRangeSize:maxRangeSize
                                                                      transaction:readTransaction];
    }];
}


- (void)clearUnreadMessagesIndicator
{
    OWSAssertIsOnMainThread();
    
    NSIndexPath *_Nullable indexPathOfUnreadIndicator = [self indexPathOfUnreadMessagesIndicator];
    if (indexPathOfUnreadIndicator) {
        ConversationViewItem *oldIndicatorItem = [self viewItemForIndex:indexPathOfUnreadIndicator.item];
        OWSAssertDebug(oldIndicatorItem);
        
        // TODO: ideally this would be happening within the *same* transaction that caused the unreadMessageIndicator
        // to be cleared.
        [self.databaseStorage
         asyncWriteWithBlock:^(SDSAnyWriteTransaction *_Nonnull transaction) {
            [oldIndicatorItem.interaction touchWithTransaction:transaction.transitional_yapWriteTransaction];
        }];
    }
    
    if (self.hasClearedUnreadMessagesIndicator) {
        // ensureDynamicInteractionsForThread is somewhat expensive
        // so we don't want to call it unnecessarily.
        return;
    }
    
    // Once we've cleared the unread messages indicator,
    // make sure we don't show it again.
    self.hasClearedUnreadMessagesIndicator = YES;
    
    if (self.dynamicInteractions.unreadIndicator) {
        // If we've just cleared the "unread messages" indicator,
        // update the dynamic interactions.
        [self ensureDynamicInteractions];
    }
}

- (void)createConversationScrollButtons
{
    self.scrollDownButton = [[ConversationScrollButton alloc] initWithIconText:@"\uf103"];
    [self.scrollDownButton addTarget:self
                              action:@selector(scrollDownButtonTapped)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.scrollDownButton];
    [self.scrollDownButton autoSetDimension:ALDimensionWidth toSize:ConversationScrollButton.buttonSize];
    [self.scrollDownButton autoSetDimension:ALDimensionHeight toSize:ConversationScrollButton.buttonSize];
    
    self.scrollDownButtonButtomConstraint = [self.scrollDownButton autoPinEdgeToSuperviewMargin:ALEdgeBottom];
    [self.scrollDownButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    
#ifdef DEBUG
    self.scrollUpButton = [[ConversationScrollButton alloc] initWithIconText:@"\uf102"];
    [self.scrollUpButton addTarget:self
                            action:@selector(scrollUpButtonTapped)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.scrollUpButton];
    [self.scrollUpButton autoSetDimension:ALDimensionWidth toSize:ConversationScrollButton.buttonSize];
    [self.scrollUpButton autoSetDimension:ALDimensionHeight toSize:ConversationScrollButton.buttonSize];
    [self.scrollUpButton autoPinToTopLayoutGuideOfViewController:self withInset:0];
    [self.scrollUpButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
#endif
}

- (void)setHasUnreadMessages:(BOOL)hasUnreadMessages
{
    if (_hasUnreadMessages == hasUnreadMessages) {
        return;
    }
    
    _hasUnreadMessages = hasUnreadMessages;
    
    self.scrollDownButton.hasUnreadMessages = hasUnreadMessages;
    [self ensureDynamicInteractions];
}

- (void)scrollDownButtonTapped
{
    NSIndexPath *indexPathOfUnreadMessagesIndicator = [self indexPathOfUnreadMessagesIndicator];
    if (indexPathOfUnreadMessagesIndicator != nil) {
        NSInteger unreadRow = indexPathOfUnreadMessagesIndicator.item;
        
        BOOL isScrolledAboveUnreadIndicator = YES;
        NSArray<NSIndexPath *> *visibleIndices = self.collectionView.indexPathsForVisibleItems;
        for (NSIndexPath *indexPath in visibleIndices) {
            if (indexPath.item > unreadRow) {
                isScrolledAboveUnreadIndicator = NO;
                break;
            }
        }
        
        if (isScrolledAboveUnreadIndicator) {
            // Only scroll as far as the unread indicator if we're scrolled above the unread indicator.
            [[self collectionView] scrollToItemAtIndexPath:indexPathOfUnreadMessagesIndicator
                                          atScrollPosition:UICollectionViewScrollPositionTop
                                                  animated:YES];
            return;
        }
    }
    
    [self scrollToBottomAnimated:YES];
}

#ifdef DEBUG
- (void)scrollUpButtonTapped
{
    [self.collectionView setContentOffset:CGPointZero animated:YES];
}
#endif

- (void)ensureScrollDownButton
{
    OWSAssertIsOnMainThread();
    
    BOOL shouldShowScrollDownButton = NO;
    CGFloat scrollSpaceToBottom = (self.safeContentHeight + self.collectionView.contentInset.bottom
                                   - (self.collectionView.contentOffset.y + self.collectionView.frame.size.height));
    CGFloat pageHeight = (self.collectionView.frame.size.height
                          - (self.collectionView.contentInset.top + self.collectionView.contentInset.bottom));
    // Show "scroll down" button if user is scrolled up at least
    // one page.
    BOOL isScrolledUp = scrollSpaceToBottom > pageHeight * 1.f;
    
    if (self.viewItems.count > 0) {
        ConversationViewItem *lastViewItem = [self.viewItems lastObject];
        OWSAssertDebug(lastViewItem);
        
        if (lastViewItem.interaction.timestampForSorting > self.lastVisibleTimestamp) {
            shouldShowScrollDownButton = YES;
        } else if (isScrolledUp) {
            shouldShowScrollDownButton = YES;
        }
    }
    
    if (shouldShowScrollDownButton) {
        self.scrollDownButton.hidden = NO;
        
    } else {
        self.scrollDownButton.hidden = YES;
    }
    
#ifdef DEBUG
    BOOL shouldShowScrollUpButton = self.collectionView.contentOffset.y > 0;
    if (shouldShowScrollUpButton) {
        self.scrollUpButton.hidden = NO;
    } else {
        self.scrollUpButton.hidden = YES;
    }
#endif
}

#pragma mark - Attachment Picking: Contacts

- (void)chooseContactForSending
{
    ContactsPicker *contactsPicker =
    [[ContactsPicker alloc] initWithAllowsMultipleSelection:NO subtitleCellType:SubtitleCellValueNone];
    contactsPicker.contactsPickerDelegate = self;
    contactsPicker.title
    = NSLocalizedString(@"CONTACT_PICKER_TITLE", @"navbar title for contact picker when sharing a contact");
    
    OWSNavigationController *navigationController =
    [[OWSNavigationController alloc] initWithRootViewController:contactsPicker];
    [self dismissKeyBoard];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Attachment Picking: Documents

- (void)showAttachmentDocumentPickerMenu
{
    NSString *allItems = (__bridge NSString *)kUTTypeItem;
    NSArray<NSString *> *documentTypes = @[ allItems ];
    // UIDocumentPickerModeImport copies to a temp file within our container.
    // It uses more memory than "open" but lets us avoid working with security scoped URLs.
    UIDocumentPickerMode pickerMode = UIDocumentPickerModeImport;
    UIDocumentPickerViewController *menuController = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:pickerMode];
    
    menuController.delegate = self;
    
    [self dismissKeyBoard];
    [self presentViewController:menuController animated:YES completion:nil];
}

#pragma mark - Attachment Picking: GIFs

- (void)showGifPicker
{
    GifPickerViewController *view =
    [[GifPickerViewController alloc] initWithThread:self.thread messageSender:self.messageSender];
    view.delegate = self;
    OWSNavigationController *navigationController = [[OWSNavigationController alloc] initWithRootViewController:view];
    
    [self dismissKeyBoard];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark GifPickerViewControllerDelegate

- (void)gifPickerDidSelectWithAttachment:(SignalAttachment *)attachment
{
    OWSAssertDebug(attachment);
    
    [self tryToSendAttachmentIfApproved:attachment];
    
    [ThreadUtil addThreadToProfileWhitelistIfEmptyContactThread:self.thread];
    [self ensureDynamicInteractions];
}

- (void)messageWasSent:(TSOutgoingMessage *)message
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(message);
    [self.unreplyProcessor updateUnReplyMessageWithMessage:message];
    
    [self updateLastVisibleTimestamp:message.timestampForSorting];
    self.lastMessageSentDate = [NSDate new];
    [self clearUnreadMessagesIndicator];
    if (self.conversationViewMode == ConversationViewMode_Main) {
        self.inputToolbar.quotedReply = nil;
    }
    
    if ([Environment.preferences soundInForeground]) {
        SystemSoundID soundId = [OWSSounds systemSoundIDForSound:OWSSound_MessageSent quiet:YES];
        AudioServicesPlaySystemSound(soundId);
    }
}

#pragma mark UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    DDLogDebug(@"%@ Picked document at url: %@", self.logTag, url);
    
    NSString *type;
    NSError *typeError;
    [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&typeError];
    if (typeError) {
        OWSFailDebug(@"%@ Determining type of picked document at url: %@ failed with error: %@", self.logTag, url, typeError);
    }
    if (!type) {
        OWSFailDebug(@"%@ falling back to default filetype for picked document at url: %@", self.logTag, url);
        type = (__bridge NSString *)kUTTypeData;
    }
    
    NSNumber *isDirectory;
    NSError *isDirectoryError;
    [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&isDirectoryError];
    if (isDirectoryError) {
        OWSFailDebug(@"%@ Determining if picked document at url: %@ was a directory failed with error: %@",
                     self.logTag,
                     url,
                     isDirectoryError);
    } else if ([isDirectory boolValue]) {
        OWSLogInfo(@"%@ User picked directory at url: %@", self.logTag, url);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [OWSAlerts
             showAlertWithTitle:
                 NSLocalizedString(@"ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_TITLE",
                                   @"Alert title when picking a document fails because user picked a directory/bundle")
             message:
                 NSLocalizedString(@"ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_BODY",
                                   @"Alert body when picking a document fails because user picked a directory/bundle")];
        });
        return;
    }
    
    NSString *filename = url.lastPathComponent;
    if (!filename) {
        OWSFailDebug(@"%@ Unable to determine filename from url: %@", self.logTag, url);
        filename = NSLocalizedString(
                                     @"ATTACHMENT_DEFAULT_FILENAME", @"Generic filename for an attachment with no known name");
    }
    
    OWSAssertDebug(type);
    OWSAssertDebug(filename);
    DataSource *_Nullable dataSource = [DataSourcePath dataSourceWithURL:url];
    if (!dataSource) {
        OWSFailDebug(@"%@ attachment data was unexpectedly empty for picked document url: %@", self.logTag, url);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [OWSAlerts showAlertWithTitle:NSLocalizedString(@"ATTACHMENT_PICKER_DOCUMENTS_FAILED_ALERT_TITLE",
                                                            @"Alert title when picking a document fails for an unknown reason")];
        });
        return;
    }
    
    [dataSource setSourceFilename:filename];
    
    // Although we want to be able to send higher quality attachments throught the document picker
    // it's more imporant that we ensure the sent format is one all clients can accept (e.g. *not* quicktime .mov)
    if ([SignalAttachment isInvalidVideoWithDataSource:dataSource dataUTI:type]) {
        [self sendQualityAdjustedAttachmentForVideo:url filename:filename skipApprovalDialog:NO];
        return;
    }
    
    // "Document picker" attachments _SHOULD NOT_ be resized, if possible.
    SignalAttachment *attachment =
    [SignalAttachment attachmentWithDataSource:dataSource dataUTI:type imageQuality:TSImageQualityOriginal];
    [self tryToSendAttachmentIfApproved:attachment];
}

#pragma mark - UIImagePickerController

/*
 *  Presenting UIImagePickerController
 */
- (void)takePictureOrVideo
{
    [self ows_askForCameraPermissions:^(BOOL granted) {
        if (!granted) {
            DDLogWarn(@"%@ camera permission denied.", self.logTag);
            return;
        }
        
        UIImagePickerController *picker = [UIImagePickerController new];
        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
        picker.mediaTypes = @[ (__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie ];
        picker.allowsEditing = NO;
        picker.delegate = self;
        
        [self dismissKeyBoard];
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (UIActivityIndicatorView *)loadingView {
    
    if (!_loadingView) {
        _loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _loadingView.hidesWhenStopped = YES;
        [self.view addSubview:_loadingView];
        
        [_loadingView autoCenterInSuperview];
    }
    
    return _loadingView;
}

- (DFPhotoBrowserHelper *)photoBrowser {
    
    if (!_photoBrowser) {
        
        __weak ConversationViewController *weakSelf = self;
        _photoBrowser = [[DFPhotoBrowserHelper alloc] initWithViewController:self maxSelectCount:9 selectImageBlock:^(NSArray<UIImage *> * _Nonnull images, NSArray<PHAsset *> * _Nonnull assets, BOOL isOrigion) {
            if (assets.count == 0) {
                return;
            }
            [weakSelf createAttacmentsWithAssets:assets];
        }];
    }
    return _photoBrowser;
}

- (void)chooseFromLibraryAsDocument
{
    OWSAssertIsOnMainThread();
    
    //    [self chooseFromLibraryAsDocument:YES];
    self.isPickingMediaAsDocument = YES;
    [self.photoBrowser showLibrary];
}

- (void)chooseFromLibraryAsMedia
{
    OWSAssertIsOnMainThread();
    
    //    [self chooseFromLibraryAsDocument:NO];
    self.isPickingMediaAsDocument = NO;
    [self.photoBrowser showLibrary];
}

- (NSString *)wea_videoTmpPath {
    return @"wea_photo_video/";
}

- (NSString *)wea_videoDocumentsPath {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    documents = [documents stringByAppendingPathComponent:[self wea_videoTmpPath]];
    return documents;
}
- (void)wea_removeVideoFilePath {
    NSString *videoDir = [self wea_videoTmpPath];
    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSError *error;
    if ([fileManger fileExistsAtPath:videoDir]) {
        [fileManger removeItemAtPath:videoDir error:&error];
    }
    if (error) {
        OWSLogInfo(@"%@",error.description);
    }
}

- (void)createAttacmentsWithAssets:(NSArray<PHAsset *> *)assets
{
    [self wea_removeVideoFilePath];
    
    __block NSMutableArray *attachments = [NSMutableArray new];
    [self.loadingView startAnimating];
    for (NSUInteger i = 0; i < assets.count; i ++) {
        [attachments addObject:[NSNull null]];
    }
    dispatch_group_t attachmentGroup = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    [assets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_group_async(attachmentGroup, queue, ^{
            
            dispatch_group_enter(attachmentGroup);
            void (^failedToPickAttachment)(NSError *error) = ^void(NSError *error) {
                DDLogError(@"failed to pick attachment with error: %@", error);
            };
            
            if (!obj) {
                dispatch_group_leave(attachmentGroup);
                return failedToPickAttachment(nil);
            }
            
            PHAssetMediaType mediaType = obj.mediaType;
            DDLogDebug(@"%@ Picked mediaType <%ld> for file: %@", self.logTag, mediaType, [obj valueForKey:@"filename"]);
            
            if (mediaType == PHAssetMediaTypeVideo) {
                
                PHVideoRequestOptions *options = [PHVideoRequestOptions new];
                
                options.version = PHVideoRequestOptionsVersionCurrent;
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
                
                [[PHImageManager defaultManager] requestAVAssetForVideo:obj options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                    __block NSURL *url = nil;
                    if ([asset isKindOfClass:AVURLAsset.class]) {
                        AVURLAsset *urlAsset = (AVURLAsset *)asset;
                        url = urlAsset.URL;
                        DataSource *dataSource = [DataSourcePath dataSourceWithURL:url];
                        dataSource.sourceFilename = [obj valueForKey:@"filename"];
                        VideoCompressionResult *compressionResult =
                        [SignalAttachment compressVideoAsMp4WithDataSource:dataSource
                                                                   dataUTI:(NSString *)kUTTypeMPEG4];
                        //                          [compressionResult.attachmentPromise retainUntilComplete];
                        compressionResult.attachmentPromise.done(^ (SignalAttachment *attachment) {
                            //                          OWSAssertIsOnMainThread();
                            OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);
                            if (!attachment || [attachment hasError]) {
                                DDLogError(@"%@ %s Invalid attachment: %@.",
                                           self.logTag,
                                           __PRETTY_FUNCTION__,
                                           attachment ? [attachment errorName] : @"Missing data");
                                [self showErrorAlertForAttachment:attachment];
                                failedToPickAttachment(nil);
                            } else {
                                [attachments replaceObjectAtIndex:idx withObject:attachment];
                                dispatch_group_leave(attachmentGroup);
                            }
                        });
                    } else {
                        NSString *documentsDirectory = [self wea_videoDocumentsPath];
                        NSError *creatFileError;
                        if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory]) {
                            [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&creatFileError];
                            
                        }
                        NSString *tmpPathDocs;
                        if (creatFileError) return;
                        uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                        tmpPathDocs = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%llu.mov",timestamp]];
                        
                        
                        url = [NSURL fileURLWithPath:tmpPathDocs];
                        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
                        exporter.outputURL = url;
                        exporter.outputFileType = AVFileTypeQuickTimeMovie;
                        exporter.shouldOptimizeForNetworkUse = YES;
                        [exporter exportAsynchronouslyWithCompletionHandler:^{
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (exporter.status == AVAssetExportSessionStatusCompleted) {
                                    url = exporter.outputURL;
                                    DataSource *dataSource = [DataSourcePath dataSourceWithURL:url];
                                    dataSource.sourceFilename = [obj valueForKey:@"filename"];
                                    VideoCompressionResult *compressionResult =
                                    [SignalAttachment compressVideoAsMp4WithDataSource:dataSource
                                                                               dataUTI:(NSString *)kUTTypeMPEG4];
                                    //                                      [compressionResult.attachmentPromise retainUntilComplete];
                                    compressionResult.attachmentPromise.done(^ (SignalAttachment *attachment) {
                                        OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);
                                        if (!attachment || [attachment hasError]) {
                                            DDLogError(@"%@ %s Invalid attachment: %@.",
                                                       self.logTag,
                                                       __PRETTY_FUNCTION__,
                                                       attachment ? [attachment errorName] : @"Missing data");
                                            [self showErrorAlertForAttachment:attachment];
                                            failedToPickAttachment(nil);
                                        } else {
                                            [attachments replaceObjectAtIndex:idx withObject:attachment];
                                            dispatch_group_leave(attachmentGroup);
                                        }
                                    });
                                }
                            });
                            
                        }];
                    }
                }];
                
            } else if (mediaType == PHAssetMediaTypeImage) {
                
                TSImageQuality imageQuality = TSImageQualityOriginal;
                
                PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
                options.synchronous = YES; // We're only fetching one asset.
                options.networkAccessAllowed = YES; // iCloud OK
                options.version = PHImageRequestOptionsVersionCurrent;
                options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat; // Don't need quick/dirty version
                options.resizeMode = PHImageRequestOptionsResizeModeNone;
                [[PHImageManager defaultManager]
                 requestImageDataForAsset:obj
                 options:options
                 resultHandler:^(NSData *_Nullable imageData,
                                 NSString *_Nullable dataUTI,
                                 UIImageOrientation orientation,
                                 NSDictionary *_Nullable assetInfo) {
                    
                    NSError *assetFetchingError = assetInfo[PHImageErrorKey];
                    if (assetFetchingError || !imageData) {
                        return failedToPickAttachment(assetFetchingError);
                    }
                    //                                   OWSAssertIsOnMainThread();
                    
                    DataSource *_Nullable dataSource =
                    [DataSourceValue dataSourceWithData:imageData utiType:dataUTI];
                    [dataSource setSourceFilename:[obj valueForKey:@"filename"]];
                    
                    SignalAttachment *attachment = [SignalAttachment attachmentWithDataSource:dataSource
                                                                                      dataUTI:dataUTI
                                                                                 imageQuality:imageQuality];
                    
                    //                                    OWSAssertIsOnMainThread();
                    if (!attachment || [attachment hasError]) {
                        DDLogWarn(@"%@ %s Invalid attachment: %@.",
                                  self.logTag,
                                  __PRETTY_FUNCTION__,
                                  attachment ? [attachment errorName] : @"Missing data");
                        [self showErrorAlertForAttachment:attachment];
                        failedToPickAttachment(nil);
                    } else {
                        [attachments replaceObjectAtIndex:idx withObject:attachment];
                        dispatch_group_leave(attachmentGroup);
                        //                                [self tryToSendAttachmentIfApproved:attachment];
                    }
                }];
            }
        });
    }];
    
    dispatch_group_notify(attachmentGroup, queue, ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.loadingView stopAnimating];
            OWSNavigationController *modal =
            [AttachmentApprovalViewController wrappedInNavControllerWithAttachments:(NSArray <SignalAttachment *> *)attachments delegate:self];
            [self presentViewController:modal animated:YES completion:nil];
        });
        
    });
}

- (void)chooseFromLibraryAsDocument:(BOOL)shouldTreatAsDocument
{
    OWSAssertIsOnMainThread();
    
    self.isPickingMediaAsDocument = shouldTreatAsDocument;
    
    [self ows_askForMediaLibraryPermissions:^(BOOL granted) {
        if (!granted) {
            DDLogWarn(@"%@ Media Library permission denied.", self.logTag);
            return;
        }
        
        UIImagePickerController *picker = [UIImagePickerController new];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.delegate = self;
        picker.mediaTypes = @[ (__bridge NSString *)kUTTypeImage, (__bridge NSString *)kUTTypeMovie ];
        
        [self dismissKeyBoard];
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

/*
 *  Dismissing UIImagePickerController
 */

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetFrame
{
    // fixes bug on frame being off after this selection
    CGRect frame = [UIScreen mainScreen].bounds;
    self.view.frame = frame;
}

/*
 *  Fetching data from UIImagePickerController
 */
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
{
    [self resetFrame];
    
    NSURL *referenceURL = [info valueForKey:UIImagePickerControllerReferenceURL];
    if (!referenceURL) {
        DDLogVerbose(@"Could not retrieve reference URL for picked asset");
        [self imagePickerController:picker didFinishPickingMediaWithInfo:info filename:nil];
        return;
    }
    
    PHAsset *asset = [[PHAsset fetchAssetsWithALAssetURLs:@[referenceURL] options:nil] lastObject];
    NSString *filename = [asset valueForKey:@"filename"];
    [self imagePickerController:picker didFinishPickingMediaWithInfo:info filename:filename];
}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info
                     filename:(NSString *_Nullable)filename
{
    OWSAssertIsOnMainThread();
    
    void (^failedToPickAttachment)(NSError *error) = ^void(NSError *error) {
        DDLogError(@"failed to pick attachment with error: %@", error);
    };
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    DDLogDebug(@"%@ Picked mediaType <%@> for file: %@", self.logTag, mediaType, filename);
    if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeMovie]) {
        // Video picked from library or captured with camera
        
        [self dismissViewControllerAnimated:YES
                                 completion:^{
            [self sendQualityAdjustedAttachmentForPicked:info
                                                filename:filename
                                      skipApprovalDialog:NO];
        }];
    } else if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        // Static Image captured from camera
        
        UIImage *imageFromCamera = [info[UIImagePickerControllerOriginalImage] normalizedImage];
        
        [self dismissViewControllerAnimated:YES
                                 completion:^{
            OWSAssertIsOnMainThread();
            
            if (imageFromCamera) {
                // "Camera" attachments _SHOULD_ be resized, if possible.
                SignalAttachment *attachment =
                [SignalAttachment imageAttachmentWithImage:imageFromCamera
                                                   dataUTI:(NSString *)kUTTypeJPEG
                                                  filename:filename
                                              imageQuality:TSImageQualityCompact];
                if (!attachment || [attachment hasError]) {
                    DDLogWarn(@"%@ %s Invalid attachment: %@.",
                              self.logTag,
                              __PRETTY_FUNCTION__,
                              attachment ? [attachment errorName] : @"Missing data");
                    [self showErrorAlertForAttachment:attachment];
                    failedToPickAttachment(nil);
                } else {
                    [self tryToSendAttachmentIfApproved:attachment skipApprovalDialog:NO];
                }
            } else {
                failedToPickAttachment(nil);
            }
        }];
    } else {
        // Non-Video image picked from library
        
        // To avoid re-encoding GIF and PNG's as JPEG we have to get the raw data of
        // the selected item vs. using the UIImagePickerControllerOriginalImage
        NSURL *assetURL = info[UIImagePickerControllerReferenceURL];
        PHAsset *asset = [[PHAsset fetchAssetsWithALAssetURLs:@[ assetURL ] options:nil] lastObject];
        if (!asset) {
            return failedToPickAttachment(nil);
        }
        
        // Images chosen from the "attach document" UI should be sent as originals;
        // images chosen from the "attach media" UI should be resized to "medium" size;
        TSImageQuality imageQuality = (self.isPickingMediaAsDocument ? TSImageQualityOriginal : TSImageQualityMedium);
        
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.synchronous = YES; // We're only fetching one asset.
        options.networkAccessAllowed = YES; // iCloud OK
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat; // Don't need quick/dirty version
        [[PHImageManager defaultManager]
         requestImageDataForAsset:asset
         options:options
         resultHandler:^(NSData *_Nullable imageData,
                         NSString *_Nullable dataUTI,
                         UIImageOrientation orientation,
                         NSDictionary *_Nullable assetInfo) {
            
            NSError *assetFetchingError = assetInfo[PHImageErrorKey];
            if (assetFetchingError || !imageData) {
                return failedToPickAttachment(assetFetchingError);
            }
            OWSAssertIsOnMainThread();
            
            DataSource *_Nullable dataSource =
            [DataSourceValue dataSourceWithData:imageData utiType:dataUTI];
            [dataSource setSourceFilename:filename];
            SignalAttachment *attachment = [SignalAttachment attachmentWithDataSource:dataSource
                                                                              dataUTI:dataUTI
                                                                         imageQuality:imageQuality];
            [self dismissViewControllerAnimated:YES
                                     completion:^{
                OWSAssertIsOnMainThread();
                if (!attachment || [attachment hasError]) {
                    DDLogWarn(@"%@ %s Invalid attachment: %@.",
                              self.logTag,
                              __PRETTY_FUNCTION__,
                              attachment ? [attachment errorName] : @"Missing data");
                    [self showErrorAlertForAttachment:attachment];
                    failedToPickAttachment(nil);
                } else {
                    [self tryToSendAttachmentIfApproved:attachment];
                }
            }];
        }];
    }
}

- (void)sendMessageAttachment:(SignalAttachment *)attachment targetThread:(nullable TSThread *)targetThread completion:(nullable void(^)(void))completion
{
    OWSAssertIsOnMainThread();
    // TODO: Should we assume non-nil or should we check for non-nil?
    OWSAssertDebug(attachment != nil);
    OWSAssertDebug(![attachment hasError]);
    OWSAssertDebug([attachment mimeType].length > 0);
    
    DDLogVerbose(@"Sending attachment. Size in bytes: %lu, contentType: %@",
                 (unsigned long)[attachment dataLength],
                 [attachment mimeType]);
    
    TSThread *thread = targetThread ?: self.thread;
    BOOL didAddToProfileWhitelist = [ThreadUtil addThreadToProfileWhitelistIfEmptyContactThread:thread];
    __block TSOutgoingMessage *message = nil;
    message = [ThreadUtil sendMessageWithAttachment:attachment
                                           inThread:thread
                                   quotedReplyModel:self.inputToolbar.quotedReply
                                      messageSender:self.messageSender
                                       ignoreErrors:NO
                                         completion:^(NSError * _Nullable error) {
        if (!error) {
            if (completion) completion();
        } else {
            if(error.code == OWSErrorCodeAttachmentExceedsLimit){
                //                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
                [message remove];
            }
        }
    }];
    
    [self messageWasSent:message];
    
    if (didAddToProfileWhitelist) {
        [self ensureDynamicInteractions];
    }
}

- (void)sendContactShare:(ContactShareViewModel *)contactShare
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(contactShare);
    
    DDLogVerbose(@"%@ Sending contact share.", self.logTag);
    
    BOOL didAddToProfileWhitelist = [ThreadUtil addThreadToProfileWhitelistIfEmptyContactThread:self.thread];
    
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *transaction) {
        if (contactShare.avatarImage) {
            [contactShare.dbRecord saveAvatarImage:contactShare.avatarImage transaction:transaction.transitional_yapWriteTransaction];
        }
    } completion:^{
        TSOutgoingMessage *message = [ThreadUtil sendMessageWithContactShare:contactShare.dbRecord
                                                                    inThread:self.thread
                                                               messageSender:self.messageSender
                                                                  completion:nil];
        [self messageWasSent:message];
        
        if (didAddToProfileWhitelist) {
            [self ensureDynamicInteractions];
        }
    }];
}

- (void)sendQualityAdjustedAttachmentForVideo:(NSURL *)movieURL
                                     filename:(NSString *)filename
                           skipApprovalDialog:(BOOL)skipApprovalDialog
{
    OWSAssertIsOnMainThread();
    
    [ModalActivityIndicatorViewController
     presentFromViewController:self
     canCancel:YES
     backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
        DataSource *dataSource = [DataSourcePath dataSourceWithURL:movieURL];
        dataSource.sourceFilename = filename;
        VideoCompressionResult *compressionResult =
        [SignalAttachment compressVideoAsMp4WithDataSource:dataSource
                                                   dataUTI:(NSString *)kUTTypeMPEG4];
        //                      [compressionResult.attachmentPromise retainUntilComplete];
        
        compressionResult.attachmentPromise.done(^ (SignalAttachment *attachment) {
            OWSAssertIsOnMainThread();
            OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);
            
            if (modalActivityIndicator.wasCancelled) {
                return;
            }
            
            [modalActivityIndicator dismissWithCompletion:^{
                if (!attachment || [attachment hasError]) {
                    DDLogError(@"%@ %s Invalid attachment: %@.",
                               self.logTag,
                               __PRETTY_FUNCTION__,
                               attachment ? [attachment errorName] : @"Missing data");
                    [self showErrorAlertForAttachment:attachment];
                } else {
                    [self tryToSendAttachmentIfApproved:attachment skipApprovalDialog:skipApprovalDialog];
                }
            }];
        });
    }];
}

- (void)sendQualityAdjustedAttachmentForPicked:(NSDictionary<NSString *, id> *)pickedInfo
                                      filename:(NSString *)filename
                            skipApprovalDialog:(BOOL)skipApprovalDialog
{
    OWSAssertIsOnMainThread();
    
    [ModalActivityIndicatorViewController
     presentFromViewController:self
     canCancel:YES
     backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
        DataSource *dataSource = [DataSourcePath dataSourceWithPickedInfo:pickedInfo];
        dataSource.sourceFilename = filename;
        VideoCompressionResult *compressionResult =
        [SignalAttachment compressVideoAsMp4WithDataSource:dataSource
                                                   dataUTI:(NSString *)kUTTypeMPEG4];
        //                      [compressionResult.attachmentPromise retainUntilComplete];
        
        compressionResult.attachmentPromise.done(^ (SignalAttachment *attachment) {
            OWSAssertIsOnMainThread();
            OWSAssertDebug([attachment isKindOfClass:[SignalAttachment class]]);
            
            if (modalActivityIndicator.wasCancelled) {
                return;
            }
            
            [modalActivityIndicator dismissWithCompletion:^{
                if (!attachment || [attachment hasError]) {
                    DDLogError(@"%@ %s Invalid attachment: %@.",
                               self.logTag,
                               __PRETTY_FUNCTION__,
                               attachment ? [attachment errorName] : @"Missing data");
                    [self showErrorAlertForAttachment:attachment];
                } else {
                    [self tryToSendAttachmentIfApproved:attachment skipApprovalDialog:skipApprovalDialog];
                }
            }];
        });
    }];
}

#pragma mark - Storage access

- (YapDatabaseConnection *)uiDatabaseConnection
{
    return self.databaseStorage.yapPrimaryStorage.uiDatabaseConnection;
}

- (void)uiDatabaseDidUpdateExternally:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    if (self.shouldObserveDBModifications) {
        // External database modifications can't be converted into incremental updates,
        // so rebuild everything.  This is expensive and usually isn't necessary, but
        // there's no alternative.
        //
        // We don't need to do this if we're not observing db modifications since we'll
        // do it when we resume.
        [self resetMappings];
    }
}

//- (void)yapDatabaseModifiedCrossProcess:(NSNotification *)notification {
//    OWSAssertIsOnMainThread();
//
//    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
//
//    if (self.shouldObserveDBModifications) {
//        // External database modifications can't be converted into incremental updates,
//        // so rebuild everything.  This is expensive and usually isn't necessary, but
//        // there's no alternative.
//        //
//        // We don't need to do this if we're not observing db modifications since we'll
//        // do it when we resume.
//        [self resetMappings];
//    }
//}

- (void)uiDatabaseWillUpdate:(NSNotification *)notification
{
    // HACK to work around radar #28167779
    // "UICollectionView performBatchUpdates can trigger a crash if the collection view is flagged for layout"
    // more: https://github.com/PSPDFKit-labs/radar.apple.com/tree/master/28167779%20-%20CollectionViewBatchingIssue
    // This was our #2 crash, and much exacerbated by the refactoring somewhere between 2.6.2.0-2.6.3.8
    //
    // NOTE: It's critical we do this before beginLongLivedReadTransaction.
    //       We want to relayout our contents using the old message mappings and
    //       view items before they are updated.
    [self.collectionView layoutIfNeeded];
    // ENDHACK to work around radar #28167779
}

- (void)uiDatabaseDidUpdate:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    if (![self.thread.contactIdentifier isEqualToString:[TSAccountManager localNumber]]) {
        
        TSThread *currentThread = [TSThread fetchObjectWithUniqueID:self.thread.uniqueId];
        NSInteger translateSettingType = currentThread.translateSettingType.integerValue;
        if (translateSettingType == 0) {
            [self.inputToolbar setTranslateOpen:NO];
        } else {
            [self.inputToolbar setTranslateOpen:YES];
        }
    }
    
    if (!self.shouldObserveDBModifications) {
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [self.messageMappings updateWithTransaction:transaction];
        }];
        return;
    }
    
    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    NSArray<NSNotification *> *notifications = notification.userInfo[OWSUIDatabaseConnectionNotificationsKey];
    OWSAssertDebug([notifications isKindOfClass:[NSArray class]]);
    
    [self updateBackButtonUnreadCount];
    [self updateNavigationBarSubtitleLabel];
    
    if (self.isGroupConversation) {
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            TSGroupThread *gThread = (TSGroupThread *)self.thread;
            
            if (gThread.groupModel) {
                TSGroupThread *_Nullable updatedThread =
                [TSGroupThread threadWithGroupId:gThread.groupModel.groupId transaction:transaction];
                if (updatedThread) {
                    self.thread = updatedThread;
                } else {
                    OWSFailDebug(@"%@ Could not reload thread.", self.logTag);
                }
            }
        }];
        [self updateNavigationTitle];
        if(((TSGroupThread *)self.thread).groupModel.groupImage){
            self.headerView.avatarImage = ((TSGroupThread *)self.thread).groupModel.groupImage;
        }
        [self hideInputIfNeeded];
    }
    
    if ([[self.uiDatabaseConnection ext:DTPinnedMessageDatabaseViewExtensionName] hasChangesForGroup:self.serverGroupId inNotifications:notifications]) {
        [self resetPinnedMappingsAnimated:YES];
    }
    
    [self updateDisappearingMessagesConfiguration];
    
    if (notifications && notifications.count > 0) {
        NSDictionary *firstChangeset = [notifications.firstObject userInfo];
        NSDictionary *lastChangeset = [notifications.lastObject userInfo];
        
        uint64_t firstSnapshot = [[firstChangeset objectForKey:YapDatabaseSnapshotKey] unsignedLongLongValue];
        
        if (self.messageMappings.snapshotOfLastUpdate != (firstSnapshot - 1)) {
            [self resetMappings];
            
            OWSLogError(@"SnapShot Error firstSnapshot=%llu preUpdate=%llu", firstSnapshot, self.messageMappings.snapshotOfLastUpdate);
            
            return;
        }
        
        uint64_t lastSnapshot = [[lastChangeset objectForKey:YapDatabaseSnapshotKey] unsignedLongLongValue];
        
        YapDatabaseViewMappings *postMappings = self.messageMappings.copy;
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
            [postMappings updateWithTransaction:transaction];
        }];
        
        if (postMappings.snapshotOfLastUpdate != lastSnapshot) {
            [self resetMappings];
            
            OWSLogError(@"SnapShot Error lastSnapshot=%llu postUpdate=%llu", lastSnapshot, postMappings.snapshotOfLastUpdate);
            
            return;
        }
        
    } else {
        
        return;
    }
    
    YapDatabaseViewConnection *viewConnection = [self.uiDatabaseConnection ext:[self getDatabaseViewExtensionName]];
    if (![viewConnection isKindOfClass:YapDatabaseViewConnection.class]) {
        return;
    }
    if (![viewConnection hasChangesForGroup:[self getCurrentGrouping] inNotifications:notifications]) {
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            [self.messageMappings updateWithTransaction:transaction];
        }];
        return;
    }
    
    NSArray<YapDatabaseViewSectionChange *> *sectionChanges = nil;
    NSArray<YapDatabaseViewRowChange *> *rowChanges = nil;
    [viewConnection getSectionChanges:&sectionChanges
                           rowChanges:&rowChanges
                     forNotifications:notifications
                         withMappings:self.messageMappings];
    
    if (([sectionChanges count] == 0 && [rowChanges count] == 0)) {
        // YapDatabase will ignore insertions within the message mapping's
        // range that are not within the current mapping's contents.  We
        // may need to extend the mapping's contents to reflect the current
        // range.
        [self updateMessageMappingRangeOptions];
        // Calling resetContentAndLayout is a bit expensive.
        // Since by definition this won't affect any cells in the previous
        // range, it should be sufficient to call invalidateLayout.
        //
        // TODO: Investigate whether we can just call invalidateLayout.
        [self resetContentAndLayout];
        return;
    }
    
    // We need to reload any modified interactions _before_ we call
    // reloadViewItems.
    BOOL hasMalformedRowChange = NO;
    for (YapDatabaseViewRowChange *rowChange in rowChanges) {
        switch (rowChange.type) {
            case YapDatabaseViewChangeUpdate: {
                YapCollectionKey *collectionKey = rowChange.collectionKey;
                if (collectionKey.key) {
                    ConversationViewItem *_Nullable viewItem = self.viewItemCache[collectionKey.key];
                    if (viewItem) {
                        [self reloadInteractionForViewItem:viewItem];
                    } else {
                        hasMalformedRowChange = YES;
                    }
                } else if (rowChange.indexPath && rowChange.originalIndex < self.viewItems.count) {
                    // Do nothing, this is a pseudo-update generated due to
                    // setCellDrawingDependencyOffsets.
                    OWSAssertDebug(rowChange.changes == YapDatabaseViewChangedDependency);
                    //                    hasMalformedRowChange = YES;
                } else {
                    hasMalformedRowChange = YES;
                }
                break;
            }
            case YapDatabaseViewChangeDelete: {
                // Discard cached view items after deletes.
                YapCollectionKey *collectionKey = rowChange.collectionKey;
                if (collectionKey.key) {
                    [self.viewItemCache removeObjectForKey:collectionKey.key];
                } else {
                    hasMalformedRowChange = YES;
                }
                break;
            }
            default:
                break;
        }
        if (hasMalformedRowChange) {
            break;
        }
    }
    
    if (hasMalformedRowChange) {
        // These errors seems to be very rare; they can only be reproduced
        // using the more extreme actions in the debug UI.
        OWSLogError(@"%@ hasMalformedRowChange", self.logTag);
        //        [self resetContentAndLayout];
        //        [self updateLastVisibleTimestamp];
        //        [self scrollToBottomAnimated:NO];
        [self resetMappings];
        return;
    }
    
    NSUInteger oldViewItemCount = self.viewItems.count;
    [self reloadViewItems];
    if (!self.viewItems.count) {
        OWSLogError(@"viewItems error, self.viewItems %zd -> %zd", oldViewItemCount, self.viewItems.count);
        [self resetMappings];
        return;
    }
    
    __block NSInteger insertDeleteCount = 0;
    [rowChanges enumerateObjectsUsingBlock:^(YapDatabaseViewRowChange * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.type == YapDatabaseViewChangeDelete) {
            insertDeleteCount = insertDeleteCount - 1;
        } else if (obj.type == YapDatabaseViewChangeInsert) {
            insertDeleteCount = insertDeleteCount + 1;
        }
    }];
    
    //    BOOL batchUpdateError = (insertDeleteCount + (NSInteger)oldViewItemCount) != (NSInteger)self.viewItems.count;
    //    if (batchUpdateError) {
    //        OWSLogError(@"batchUpdateError realcount=%lu viewItems.count=%lu", (insertDeleteCount + (NSInteger)oldViewItemCount), self.viewItems.count);
    //        [self resetMappings];
    //        return;
    //    }
    
    BOOL wasAtBottom = [self isScrolledToBottom];
    // We want sending messages to feel snappy.  So, if the only
    // update is a new outgoing message AND we're already scrolled to
    // the bottom of the conversation, skip the scroll animation.
    __block BOOL shouldAnimateScrollToBottom = !wasAtBottom;
    // We want to scroll to the bottom if the user:
    //
    // a) already was at the bottom of the conversation.
    // b) is inserting new interactions.
    __block BOOL scrollToBottom = wasAtBottom;
    
    void (^batchUpdates)(void) = ^{
        for (YapDatabaseViewRowChange *rowChange in rowChanges) {
            switch (rowChange.type) {
                case YapDatabaseViewChangeDelete: {
                    OWSLogDebug(@"YapDatabaseViewChangeDelete collectionKey: %@, indexPath: %@, finalIndex: %lu",
                                rowChange.collectionKey,
                                rowChange.indexPath,
                                (unsigned long)rowChange.finalIndex);
                    [self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ]];
                    YapCollectionKey *collectionKey = rowChange.collectionKey;
                    OWSAssertDebug(collectionKey.key.length > 0);
                    break;
                }
                case YapDatabaseViewChangeInsert: {
                    OWSLogDebug(@"YapDatabaseViewChangeInsert collectionKey: %@, newIndexPath: %@, finalIndex: %lu",
                                rowChange.collectionKey,
                                rowChange.newIndexPath,
                                (unsigned long)rowChange.finalIndex);
                    [self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
                    ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:(NSInteger)rowChange.finalIndex];
                    if ([viewItem.interaction isKindOfClass:[TSOutgoingMessage class]]) {
                        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
                        if (!outgoingMessage.isFromLinkedDevice) {
                            scrollToBottom = YES;
                            shouldAnimateScrollToBottom = NO;
                        }
                        if (rowChange.newIndexPath.row >=1 && ConversationViewMode_Thread) {
                            NSIndexPath *tmpIndexPath = [NSIndexPath indexPathForRow:rowChange.newIndexPath.row - 1 inSection:rowChange.newIndexPath.section];
                            [self.collectionView reloadItemsAtIndexPaths:@[tmpIndexPath]];
                        }
                    }
                    [self performTranlateMessageWithDelayTime:1];
                    break;
                }
                case YapDatabaseViewChangeMove: {
                    OWSLogDebug(@"YapDatabaseViewChangeMove collectionKey: %@, indexPath: %@, newIndexPath: %@, "
                                @"finalIndex: %lu",
                                rowChange.collectionKey,
                                rowChange.indexPath,
                                rowChange.newIndexPath,
                                (unsigned long)rowChange.finalIndex);
                    [self.collectionView moveItemAtIndexPath:rowChange.indexPath toIndexPath:rowChange.newIndexPath];
                    //                    [self.collectionView deleteItemsAtIndexPaths:@[ rowChange.indexPath ]];
                    //                    [self.collectionView insertItemsAtIndexPaths:@[ rowChange.newIndexPath ]];
                    ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:(NSInteger)rowChange.finalIndex];
                    if ([viewItem.interaction isKindOfClass:[TSOutgoingMessage class]]) {
                        TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
                        if (!outgoingMessage.isFromLinkedDevice) {
                            scrollToBottom = YES;
                            shouldAnimateScrollToBottom = NO;
                        }
                    }
                    break;
                }
                case YapDatabaseViewChangeUpdate: {
                    OWSLogDebug(@"YapDatabaseViewChangeUpdate collectionKey: %@, indexPath: %@, finalIndex: %lu",
                                rowChange.collectionKey,
                                rowChange.indexPath,
                                (unsigned long)rowChange.finalIndex);
                    [self.collectionView reloadItemsAtIndexPaths:@[ rowChange.indexPath ]];
                    break;
                }
            }
        }
    };
    
    OWSLogInfo(@"self.viewItems.count: %zd -> %zd", oldViewItemCount, self.viewItems.count);
    
    BOOL shouldAnimateUpdates = [self shouldAnimateRowUpdates:rowChanges oldViewItemCount:oldViewItemCount];
    void (^batchUpdatesCompletion)(BOOL) = ^(BOOL finished) {
        OWSAssertIsOnMainThread();
        
        
        if (!finished) {
            OWSLogInfo(@"%@ performBatchUpdates did not finish", self.logTag);
        }
        
        [self updateLastVisibleTimestamp];
        if (scrollToBottom && shouldAnimateUpdates) {
            [self scrollToBottomAnimated:shouldAnimateScrollToBottom];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performReloadUserStateSelectorWithDelayTime:0.3];
        });
    };
    
    @try {
        if (shouldAnimateUpdates) {
            [self.collectionView performBatchUpdates:batchUpdates completion:batchUpdatesCompletion];
        } else {
            // HACK: We use `UIView.animateWithDuration:0` rather than `UIView.performWithAnimation` to work around a
            // UIKit Crash like:
            //
            //     *** Assertion failure in -[ConversationViewLayout prepareForCollectionViewUpdates:],
            //     /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIKit_Sim/UIKit-3600.7.47/UICollectionViewLayout.m:760
            //     *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'While
            //     preparing update a visible view at <NSIndexPath: 0xc000000011c00016> {length = 2, path = 0 - 142}
            //     wasn't found in the current data model and was not in an update animation. This is an internal
            //     error.'
            //
            // I'm unclear if this is a bug in UIKit, or if we're doing something crazy in
            // ConversationViewLayout#prepareLayout. To reproduce, rapidily insert and delete items into the
            // conversation. See `DebugUIMessages#thrashCellsInThread:`
            [UIView
             animateWithDuration:0.0
             animations:^{
                [self.collectionView performBatchUpdates:batchUpdates completion:batchUpdatesCompletion];
                if (scrollToBottom) {
                    [self scrollToBottomAnimated:shouldAnimateUpdates];
                }
            }];
        }
    } @catch (NSException *exception) {
        DDLogError(@"exception: %@ of type: %@ with reason: %@, user info: %@.",
                   exception.description,
                   exception.name,
                   exception.reason,
                   exception.userInfo);
        
        for (YapDatabaseViewRowChange *rowChange in rowChanges) {
            switch (rowChange.type) {
                case YapDatabaseViewChangeDelete:
                    DDLogWarn(@"YapDatabaseViewChangeDelete collectionKey: %@, indexPath: %@, finalIndex: %lu",
                              rowChange.collectionKey,
                              rowChange.indexPath,
                              (unsigned long)rowChange.finalIndex);
                    break;
                case YapDatabaseViewChangeInsert:
                    DDLogWarn(@"YapDatabaseViewChangeInsert collectionKey: %@, newIndexPath: %@, finalIndex: %lu",
                              rowChange.collectionKey,
                              rowChange.newIndexPath,
                              (unsigned long)rowChange.finalIndex);
                    break;
                case YapDatabaseViewChangeMove:
                    DDLogWarn(@"YapDatabaseViewChangeMove collectionKey: %@, indexPath: %@, finalIndex: %@, "
                              @"finalIndex: %lu",
                              rowChange.collectionKey,
                              rowChange.indexPath,
                              rowChange.newIndexPath,
                              (unsigned long)rowChange.finalIndex);
                    break;
                case YapDatabaseViewChangeUpdate:
                    DDLogWarn(@"YapDatabaseViewChangeUpdate collectionKey: %@, indexPath: %@, finalIndex: %lu, "
                              @"isDependency: %d",
                              rowChange.collectionKey,
                              rowChange.indexPath,
                              (unsigned long)rowChange.finalIndex,
                              rowChange.changes == YapDatabaseViewChangedDependency);
                    break;
            }
        }
        
        @throw exception;
    }
    
    self.lastReloadDate = [NSDate new];
}

- (BOOL)shouldAnimateRowUpdates:(NSArray<YapDatabaseViewRowChange *> *)rowChanges
               oldViewItemCount:(NSUInteger)oldViewItemCount
{
    OWSAssertDebug(rowChanges);
    
    // If user sends a new outgoing message, don't animate the change.
    BOOL isOnlyModifyingLastMessage = YES;
    for (YapDatabaseViewRowChange *rowChange in rowChanges) {
        switch (rowChange.type) {
            case YapDatabaseViewChangeDelete:
                isOnlyModifyingLastMessage = NO;
                break;
            case YapDatabaseViewChangeInsert: {
                ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:(NSInteger)rowChange.finalIndex];
                if (([viewItem.interaction isKindOfClass:[TSIncomingMessage class]] ||
                     [viewItem.interaction isKindOfClass:[TSOutgoingMessage class]])
                    && rowChange.finalIndex >= oldViewItemCount) {
                    continue;
                }
                isOnlyModifyingLastMessage = NO;
            }
            case YapDatabaseViewChangeMove:
                isOnlyModifyingLastMessage = NO;
                break;
            case YapDatabaseViewChangeUpdate: {
                if (rowChange.changes == YapDatabaseViewChangedDependency) {
                    continue;
                }
                ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:(NSInteger)rowChange.finalIndex];
                if (([viewItem.interaction isKindOfClass:[TSIncomingMessage class]] ||
                     [viewItem.interaction isKindOfClass:[TSOutgoingMessage class]])
                    && rowChange.finalIndex >= oldViewItemCount) {
                    continue;
                }
                isOnlyModifyingLastMessage = NO;
                break;
            }
        }
    }
    BOOL shouldAnimateRowUpdates = !isOnlyModifyingLastMessage;
    return shouldAnimateRowUpdates;
}

- (BOOL)isScrolledToBottom
{
    CGFloat contentHeight = self.safeContentHeight;
    
    // This is a bit subtle.
    //
    // The _wrong_ way to determine if we're scrolled to the bottom is to
    // measure whether the collection view's content is "near" the bottom edge
    // of the collection view.  This is wrong because the collection view
    // might not have enough content to fill the collection view's bounds
    // _under certain conditions_ (e.g. with the keyboard dismissed).
    //
    // What we're really interested in is something a bit more subtle:
    // "Is the scroll view scrolled down as far as it can, "at rest".
    //
    // To determine that, we find the appropriate "content offset y" if
    // the scroll view were scrolled down as far as possible.  IFF the
    // actual "content offset y" is "near" that value, we return YES.
    const CGFloat kIsAtBottomTolerancePts = 5;
    // Note the usage of MAX() to handle the case where there isn't enough
    // content to fill the collection view at its current size.
    CGFloat contentOffsetYBottom
    = MAX(0.f, contentHeight + self.collectionView.contentInset.bottom - self.collectionView.bounds.size.height);
    
    CGFloat distanceFromBottom = contentOffsetYBottom - self.collectionView.contentOffset.y;
    BOOL isScrolledToBottom = distanceFromBottom <= kIsAtBottomTolerancePts;
    
    return isScrolledToBottom;
}

#pragma mark - Audio

- (void)requestRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();
    
    NSUUID *voiceMessageUUID = [NSUUID UUID];
    self.voiceMessageUUID = voiceMessageUUID;
    
    __weak typeof(self) weakSelf = self;
    [self ows_askForMicrophonePermissions:^(BOOL granted) {
        __strong typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (strongSelf.voiceMessageUUID != voiceMessageUUID) {
            // This voice message recording has been cancelled
            // before recording could begin.
            return;
        }
        
        if (granted) {
            [strongSelf startRecordingVoiceMemo];
        } else {
            OWSLogInfo(@"%@ we do not have recording permission.", self.logTag);
            [strongSelf cancelVoiceMemo];
            [OWSAlerts showNoMicrophonePermissionAlert];
        }
    }];
}

- (void)startRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"startRecordingVoiceMemo");
    
    // Cancel any ongoing audio playback.
    [self.audioAttachmentPlayer stop];
    self.audioAttachmentPlayer = nil;
    
    NSString *temporaryDirectory = NSTemporaryDirectory();
    NSString *filename = [NSString stringWithFormat:@"%lld.m4a", [NSDate ows_millisecondTimeStamp]];
    NSString *filepath = [temporaryDirectory stringByAppendingPathComponent:filename];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    
    // Setup audio session
    BOOL configuredAudio = [OWSAudioSession.shared startRecordingAudioActivity:self.voiceNoteAudioActivity];
    if (!configuredAudio) {
        OWSFailDebug(@"%@ Couldn't configure audio session", self.logTag);
        [self cancelVoiceMemo];
        return;
    }
    
    NSError *error;
    // Initiate and prepare the recorder
    self.audioRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL
                                                     settings:@{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVSampleRateKey : @(44100),
        AVNumberOfChannelsKey : @(2),
        AVEncoderBitRateKey : @(128 * 1024),
    }
                                                        error:&error];
    if (error) {
        OWSFailDebug(@"%@ Couldn't create audioRecorder: %@", self.logTag, error);
        [self cancelVoiceMemo];
        return;
    }
    
    self.audioRecorder.meteringEnabled = YES;
    
    if (![self.audioRecorder prepareToRecord]) {
        OWSFailDebug(@"%@ audioRecorder couldn't prepareToRecord.", self.logTag);
        [self cancelVoiceMemo];
        return;
    }
    
    if (![self.audioRecorder record]) {
        OWSFailDebug(@"%@ audioRecorder couldn't record.", self.logTag);
        [self cancelVoiceMemo];
        return;
    }
}

- (void)endRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"endRecordingVoiceMemo");
    
    self.voiceMessageUUID = nil;
    
    if (!self.audioRecorder) {
        // No voice message recording is in progress.
        // We may be cancelling before the recording could begin.
        DDLogError(@"%@ Missing audioRecorder", self.logTag);
        return;
    }
    
    NSTimeInterval durationSeconds = self.audioRecorder.currentTime;
    
    [self stopRecording];
    
    const NSTimeInterval kMinimumRecordingTimeSeconds = 1.f;
    if (durationSeconds < kMinimumRecordingTimeSeconds) {
        OWSLogInfo(@"Discarding voice message; too short.");
        self.audioRecorder = nil;
        
        [self dismissKeyBoard];
        
        [OWSAlerts
         showAlertWithTitle:
             NSLocalizedString(@"VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE",
                               @"Title for the alert indicating the 'voice message' needs to be held to be held down to record.")
         message:NSLocalizedString(@"VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE",
                                   @"Message for the alert indicating the 'voice message' needs to be held to be held "
                                   @"down to record.")];
        return;
    }
    
    DataSource *_Nullable dataSource = [DataSourcePath dataSourceWithURL:self.audioRecorder.url];
    self.audioRecorder = nil;
    
    if (!dataSource) {
        OWSFailDebug(@"%@ Couldn't load audioRecorder data", self.logTag);
        self.audioRecorder = nil;
        return;
    }
    
    NSString *filename = [NSLocalizedString(@"VOICE_MESSAGE_FILE_NAME", @"Filename for voice messages.")
                          stringByAppendingPathExtension:@"m4a"];
    [dataSource setSourceFilename:filename];
    // Remove temporary file when complete.
    [dataSource setShouldDeleteOnDeallocation];
    SignalAttachment *attachment =
    [SignalAttachment voiceMessageAttachmentWithDataSource:dataSource dataUTI:(NSString *)kUTTypeMPEG4Audio];
    DDLogVerbose(@"%@ voice memo duration: %f, file size: %zd", self.logTag, durationSeconds, [dataSource dataLength]);
    if (!attachment || [attachment hasError]) {
        DDLogWarn(@"%@ %s Invalid attachment: %@.",
                  self.logTag,
                  __PRETTY_FUNCTION__,
                  attachment ? [attachment errorName] : @"Missing data");
        [self showErrorAlertForAttachment:attachment];
    } else {
        [self tryToSendAttachmentIfApproved:attachment skipApprovalDialog:YES];
    }
}

- (void)stopRecording
{
    [self.audioRecorder stop];
    [OWSAudioSession.shared endAudioActivity:self.voiceNoteAudioActivity];
}

- (void)cancelRecordingVoiceMemo
{
    OWSAssertIsOnMainThread();
    DDLogDebug(@"cancelRecordingVoiceMemo");
    
    [self stopRecording];
    self.audioRecorder = nil;
    self.voiceMessageUUID = nil;
}

- (void)setAudioRecorder:(nullable AVAudioRecorder *)audioRecorder
{
    // Prevent device from sleeping while recording a voice message.
    if (audioRecorder) {
        [DeviceSleepManager.sharedInstance addBlockWithBlockObject:audioRecorder];
    } else if (_audioRecorder) {
        [DeviceSleepManager.sharedInstance removeBlockWithBlockObject:_audioRecorder];
    }
    
    _audioRecorder = audioRecorder;
}

#pragma mark Accessory View

- (nullable NSIndexPath *)lastVisibleIndexPath
{
    NSIndexPath *_Nullable lastVisibleIndexPath = nil;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForVisibleItems]) {
        if (!lastVisibleIndexPath || indexPath.item > lastVisibleIndexPath.item) {
            lastVisibleIndexPath = indexPath;
        }
    }
    if (lastVisibleIndexPath && lastVisibleIndexPath.item >= (NSInteger)self.viewItems.count) {
        return (self.viewItems.count > 0 ? [NSIndexPath indexPathForRow:(NSInteger)self.viewItems.count - 1 inSection:0]
                : nil);
    }
    return lastVisibleIndexPath;
}

- (nullable ConversationViewItem *)lastVisibleViewItem
{
    NSIndexPath *_Nullable lastVisibleIndexPath = [self lastVisibleIndexPath];
    if (!lastVisibleIndexPath) {
        return nil;
    }
    return [self viewItemForIndex:lastVisibleIndexPath.item];
}

// In the case where we explicitly scroll to bottom, we want to synchronously
// update the UI to reflect that, since the "mark as read" logic is asynchronous
// and won't update the UI state immediately.
- (void)didScrollToBottom
{
    
    ConversationViewItem *_Nullable lastVisibleViewItem = [self.viewItems lastObject];
    if (lastVisibleViewItem) {
        uint64_t lastVisibleTimestamp = lastVisibleViewItem.interaction.timestampForSorting;
        self.lastVisibleTimestamp = MAX(self.lastVisibleTimestamp, lastVisibleTimestamp);
    }
    
    self.scrollDownButton.hidden = YES;
    
    self.hasUnreadMessages = NO;
}

- (void)handleSpecialItemDisappearing{
    NSMutableArray<TSInfoMessage *> *items = @[].mutableCopy;
    for (NSIndexPath *indexPath in [self.collectionView indexPathsForVisibleItems]) {
        if(indexPath){
            ConversationViewItem *viewItem = [self viewItemForIndex:indexPath.item];
            if([viewItem.interaction isKindOfClass:[TSInfoMessage class]]){
                TSInfoMessage *recallInfoMsg = (TSInfoMessage *)viewItem.interaction;
                if(recallInfoMsg.messageType == TSInfoMessageRecallMessage && recallInfoMsg.expireStartedAt == 0){
                    [items addObject:recallInfoMsg];
                }
            }
            
        }
    }
    if(items.count){
        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
            [items enumerateObjectsUsingBlock:^(TSInfoMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [[OWSDisappearingMessagesJob sharedJob] startAnyExpirationForMessage:obj
                                                                 expirationStartedAt:[NSDate ows_millisecondTimeStamp]
                                                                         transaction:transaction.transitional_yapWriteTransaction];
            }];
        }];
    }
}

- (void)updateLastVisibleTimestamp
{
    ConversationViewItem *_Nullable lastVisibleViewItem = [self lastVisibleViewItem];
    if (lastVisibleViewItem) {
        uint64_t lastVisibleTimestamp = lastVisibleViewItem.interaction.timestampForSorting;
        self.lastVisibleTimestamp = MAX(self.lastVisibleTimestamp, lastVisibleTimestamp);
    }
    
    [self ensureScrollDownButton];
    
    __block NSUInteger numberOfUnreadMessages;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        numberOfUnreadMessages =
        [[transaction ext:TSUnreadDatabaseViewExtensionName] numberOfItemsInGroup:self.thread.uniqueId];
    }];
    self.hasUnreadMessages = numberOfUnreadMessages > 0;
}

- (void)updateLastVisibleTimestamp:(uint64_t)timestamp
{
    OWSAssertDebug(timestamp > 0);
    
    self.lastVisibleTimestamp = MAX(self.lastVisibleTimestamp, timestamp);
    
    [self ensureScrollDownButton];
}

- (void)markVisibleMessagesAsRead
{
    if (self.presentedViewController) {
        OWSLogInfo(@"%@ Not marking messages as read; another view is presented.", self.logTag);
        return;
    }
    if (OWSWindowManager.sharedManager.shouldShowCallView) {
        OWSLogInfo(@"%@ Not marking messages as read; call view is presented.", self.logTag);
        return;
    }
    if (self.navigationController.topViewController != self) {
        OWSLogInfo(@"%@ Not marking messages as read; another view is pushed.", self.logTag);
        return;
    }
    
    [self updateLastVisibleTimestamp];
    
    uint64_t lastVisibleTimestamp = self.lastVisibleTimestamp;
    
    if (lastVisibleTimestamp == 0) {
        // No visible messages yet. New Thread.
        return;
    }
    
    // 进入会话，全部标记已读
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
        [self.thread markAllAsReadWithTransaction:transaction.transitional_yapWriteTransaction];
    }];
    //    [OWSReadReceiptManager.sharedManager markAsReadLocallyBeforeTimestamp:lastVisibleTimestamp thread:self.thread];
    
    [self handleSpecialItemDisappearing];
}



- (void)removeGroupMemberWithGroupThread:(TSGroupThread *)groupThread
                          removedMembers:(NSSet *)removedMembers
                         updateGroupInfo:(nonnull NSString *)updateGroupInfo
                       successCompletion:(void (^_Nullable)(void))successCompletion
{
    __block TSOutgoingMessage *message;
    
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
        YapDatabaseReadWriteTransaction *transaction = writeTransaction.transitional_yapWriteTransaction;
        
        uint32_t expiresInSeconds = [groupThread disappearingMessagesDurationWithTransaction:transaction];
        message = [TSOutgoingMessage outgoingMessageInThread:groupThread
                                            groupMetaMessage:TSGroupMessageUpdate
                                                   atPersons:nil
                                            expiresInSeconds:expiresInSeconds];
        [message updateWithCustomMessage:updateGroupInfo transaction:transaction];
        [message sendingWithRemovedGroupMembers:removedMembers];
        message.compatibleUpdateInfo = YES;
        
    } completion:^{
        [self.messageSender enqueueMessage:message
                                   success:^{
            DDLogDebug(@"%@ Successfully sent group update", self.logTag);
            if (successCompletion) {
                successCompletion();
            }
        }
                                   failure:^(NSError *error) {
            DDLogError(@"%@ Failed to send group update with error: %@", self.logTag, error);
        }];
    }];
    
    self.thread = groupThread;
}

- (void)updateGroupModelTo:(TSGroupThread *)groupThread
           updateGroupInfo:(NSString *)updateGroupInfo
         successCompletion:(void (^_Nullable)(void))successCompletion
{
    __block TSOutgoingMessage *message;
    
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
        YapDatabaseReadWriteTransaction *transaction = writeTransaction.transitional_yapWriteTransaction;
        
        uint32_t expiresInSeconds = [groupThread disappearingMessagesDurationWithTransaction:transaction];
        message = [TSOutgoingMessage outgoingMessageInThread:groupThread
                                            groupMetaMessage:TSGroupMessageUpdate
                                                   atPersons:nil
                                            expiresInSeconds:expiresInSeconds];
        [message updateWithCustomMessage:updateGroupInfo transaction:transaction];
        message.compatibleUpdateInfo = YES;
    }];
    
    [groupThread fireAvatarChangedNotification];
    
    if (groupThread.groupModel.groupImage) {
        NSData *data = UIImagePNGRepresentation(groupThread.groupModel.groupImage);
        DataSource *_Nullable dataSource = [DataSourceValue dataSourceWithData:data fileExtension:@"png"];
        [self.messageSender enqueueAttachment:dataSource
                                  contentType:OWSMimeTypeImagePng
                               sourceFilename:nil
                                    inMessage:message
                                      success:^{
            DDLogDebug(@"%@ Successfully sent group update with avatar", self.logTag);
            if (successCompletion) {
                successCompletion();
            }
        }
                                      failure:^(NSError *error) {
            DDLogError(@"%@ Failed to send group avatar update with error: %@", self.logTag, error);
        }];
    } else {
        [self.messageSender enqueueMessage:message
                                   success:^{
            DDLogDebug(@"%@ Successfully sent group update", self.logTag);
            if (successCompletion) {
                successCompletion();
            }
        }
                                   failure:^(NSError *error) {
            DDLogError(@"%@ Failed to send group update with error: %@", self.logTag, error);
        }];
    }
    
    self.thread = groupThread;
}



- (void)popKeyBoard
{
    [self.inputToolbar beginEditingTextMessage];
}

- (void)dismissKeyBoard
{
    if (self.inputToolbar.isFunctionViewDisplay) {
        [self.inputToolbar switchFunctionViewState:DTInputToobarStateNone animated:YES];
    } else {
        [self.inputToolbar endEditingTextMessage];
    }
}

#pragma mark Drafts

- (void)loadDraftInCompose
{
    OWSAssertIsOnMainThread();
    
    __block NSString *draft;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        draft = [self.thread currentDraftWithTransaction:transaction];
    }];
    [self.inputToolbar setMessageText:draft animated:NO];
}

- (void)saveDraft
{
    if (self.conversationViewMode == ConversationViewMode_Thread) {
        return;
    }
    if (self.inputToolbar.hidden == NO) {
        __block TSThread *thread = _thread;
        __block NSString *currentDraft = [self.inputToolbar messageText];
        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *transaction) {
            [thread setDraft:currentDraft transaction:transaction.transitional_yapWriteTransaction];
        }];
    }
}

- (void)clearDraft
{
    __block TSThread *thread = _thread;
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction *transaction) {
        [thread setDraft:@"" transaction:transaction.transitional_yapWriteTransaction];
    }];
}

#pragma mark Unread Badge

- (void)updateBackButtonUnreadCount
{
    OWSAssertIsOnMainThread();
    self.backButtonUnreadCount = [OWSMessageUtils.sharedManager unreadMessagesCountExcept:self.thread];
}

- (void)setBackButtonUnreadCount:(NSUInteger)unreadCount
{
    OWSAssertIsOnMainThread();
    if (_backButtonUnreadCount == unreadCount) {
        // No need to re-render same count.
        return;
    }
    _backButtonUnreadCount = unreadCount;
    
    OWSAssertDebug(_backButtonUnreadCountView != nil);
    _backButtonUnreadCountView.hidden = unreadCount <= 0;
    
    OWSAssertDebug(_backButtonUnreadCountLabel != nil);
    
    // Max out the unread count at 99+.
    const NSUInteger kMaxUnreadCount = 99;
    _backButtonUnreadCountLabel.text = [OWSFormat formatInt:(int)MIN(kMaxUnreadCount, unreadCount)];
}

#pragma mark 3D Touch Preview Actions

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    return @[];
}

#pragma mark - ConversationHeaderViewDelegate
// 点击 header 回调
- (void)didTapConversationHeaderView:(ConversationHeaderView *)conversationHeaderView {
    if (self.thread.isGroupThread) {
        [self showConversationSettings];
    }else {
        DTPersonnalCardController *personnalVC = [DTPersonnalCardController new];
        if ([self.thread.contactIdentifier isEqualToString:[TSAccountManager sharedInstance].localNumber]) {
            [self showConversationSettings];
        }else {
            [personnalVC configureWithRecipientId:self.thread.contactIdentifier withType:DTPersonnalCardTypeOther];
            [self.navigationController pushViewController:personnalVC animated:YES];
        }
    }
    
}

#ifdef USE_DEBUG_UI
- (void)navigationTitleLongPressed:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        [DebugUITableViewController presentDebugUIForThread:self.thread fromViewController:self];
    }
}
#endif

#pragma mark - ConversationInputTextViewDelegate
- (void)inputTextViewSendMessagePressed
{
    //    [self sendButtonPressed];
}

- (void)didPasteAttachment:(SignalAttachment *_Nullable)attachment
{
    DDLogError(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    [self tryToSendAttachmentIfApproved:attachment];
}

- (void)tryToSendAttachmentIfApproved:(SignalAttachment *_Nullable)attachment
{
    [self tryToSendAttachmentIfApproved:attachment skipApprovalDialog:NO];
}

- (void)tryToSendAttachmentIfApproved:(SignalAttachment *_Nullable)attachment
                   skipApprovalDialog:(BOOL)skipApprovalDialog
{
    DDLogError(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    
    DispatchMainThreadSafe(^{
        __weak ConversationViewController *weakSelf = self;
        if ([self isBlockedContactConversation]) {
            [self showUnblockContactUI:^(BOOL isBlocked) {
                if (!isBlocked) {
                    [weakSelf tryToSendAttachmentIfApproved:attachment];
                }
            }];
            return;
        }
        
        BOOL didShowSNAlert = [self
                               showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[SafetyNumberStrings confirmSendButton] completion:^(BOOL didConfirmIdentity) {
            
            if (didConfirmIdentity) {
                [weakSelf tryToSendAttachmentIfApproved:attachment];
            }
        }];
        if (didShowSNAlert) {
            return;
        }
        
        if (attachment == nil || [attachment hasError]) {
            DDLogWarn(@"%@ %s Invalid attachment: %@.",
                      self.logTag,
                      __PRETTY_FUNCTION__,
                      attachment ? [attachment errorName] : @"Missing data");
            [self showErrorAlertForAttachment:attachment];
        } /*else if (skipApprovalDialog) {
           [self sendMessageAttachment:attachment];
           } */else {
               //            OWSNavigationController *modal =
               //                [AttachmentApprovalViewController wrappedInNavControllerWithAttachment:attachment delegate:self];
               //            [self presentViewController:modal animated:YES completion:nil];
               [self sendMessageAttachment:attachment targetThread:nil completion:nil];
           }
    });
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    // `willChange` is the correct keyboard notifiation to observe when adjusting contentInset
    // in lockstep with the keyboard presentation animation. `didChange` results in the contentInset
    // not adjusting until after the keyboard is fully up.
    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);
    [self handleKeyboardNotification:notification];
}

- (void)handleKeyboardNotification:(NSNotification *)notification
{
    OWSAssertIsOnMainThread();
    
    NSDictionary *userInfo = [notification userInfo];
    
    NSValue *_Nullable keyboardBeginFrameValue = userInfo[UIKeyboardFrameBeginUserInfoKey];
    if (!keyboardBeginFrameValue) {
        OWSFailDebug(@"%@ Missing keyboard begin frame", self.logTag);
        return;
    }
    
    NSValue *_Nullable keyboardEndFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey];
    if (!keyboardEndFrameValue) {
        OWSFailDebug(@"%@ Missing keyboard end frame", self.logTag);
        return;
    }
    CGRect keyboardEndFrame = [keyboardEndFrameValue CGRectValue];
    
    UIEdgeInsets oldInsets = self.collectionView.contentInset;
    UIEdgeInsets newInsets = oldInsets;
    // bottomLayoutGuide accounts for extra offset needed on iPhoneX
    newInsets.bottom = keyboardEndFrame.size.height - self.bottomLayoutGuide.length;
    
    BOOL wasScrolledToBottom = [self isScrolledToBottom];
    
    void (^adjustInsets)(void) = ^(void) {
        self.collectionView.contentInset = newInsets;
        self.collectionView.scrollIndicatorInsets = newInsets;
        
        // Note there is a bug in iOS11.2 which where switching to the emoji keyboard
        // does not fire a UIKeyboardFrameWillChange notification. In that case, the scroll
        // down button gets mostly obscured by the keyboard.
        // RADAR: #36297652
        self.scrollDownButtonButtomConstraint.constant = -1 * newInsets.bottom;
        [self.scrollDownButton setNeedsLayout];
        [self.scrollDownButton layoutIfNeeded];
        // HACK: I've made the assumption that we are already in the context of an animation, in which case the
        // above should be sufficient to smoothly move the scrollDown button in step with the keyboard presentation
        // animation. Yet, setting the constraint doesn't animate the movement of the button - it "jumps" to it's final
        // position. So here we manually lay out the scroll down button frame (seemingly redundantly), which allows it
        // to be smoothly animated.
        //        CGRect newButtonFrame = self.scrollDownButton.frame;
        //        newButtonFrame.origin.y
        //            = self.scrollDownButton.superview.height - (newInsets.bottom + self.scrollDownButton.height);
        //        self.scrollDownButton.frame = newButtonFrame;
        
        // Adjust content offset to prevent the presented keyboard from obscuring content.
        if (!self.viewHasEverAppeared) {
            [self scrollToDefaultPosition];
        } else if (wasScrolledToBottom) {
            // If we were scrolled to the bottom, don't do any fancy math. Just stay at the bottom.
            [self scrollToBottomAnimated:NO];
        } else {
            // If we were scrolled away from the bottom, shift the content in lockstep with the
            // keyboard, up to the limits of the content bounds.
            CGFloat insetChange = newInsets.bottom - oldInsets.bottom;
            CGFloat oldYOffset = self.collectionView.contentOffset.y;
            CGFloat newYOffset = CGFloatClamp(oldYOffset + insetChange, 0, self.safeContentHeight);
            CGPoint newOffset = CGPointMake(0, newYOffset);
            
            // If the user is dismissing the keyboard via interactive scrolling, any additional conset offset feels
            // redundant, so we only adjust content offset when *presenting* the keyboard (i.e. when insetChange > 0).
            if (insetChange > 0 && newYOffset > keyboardEndFrame.origin.y) {
                [self.collectionView setContentOffset:newOffset animated:NO];
            }
        }
    };
    
    if (self.isViewCompletelyAppeared) {
        adjustInsets();
    } else {
        // Even though we are scrolling without explicitly animating, the notification seems to occur within the context
        // of a system animation, which is desirable when the view is visible, because the user sees the content rise
        // in sync with the keyboard. However, when the view hasn't yet been presented, the animation conflicts and the
        // result is that initial load causes the collection cells to visably "animate" to their final position once the
        // view appears.
        [UIView performWithoutAnimation:adjustInsets];
    }
}

//相册选择--附件发送
- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval didApproveAttachments:(NSArray <SignalAttachment *> * _Nonnull)attachments
{
    [attachments enumerateObjectsUsingBlock:^(SignalAttachment * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * idx * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self sendMessageAttachment:obj targetThread:nil completion:nil];
        });
    }];
    
    [self dismissViewControllerAnimated:YES completion:nil];
    // We always want to scroll to the bottom of the conversation after the local user
    // sends a message.  Normally, this is taken care of in yapDatabaseModified:, but
    // we don't listen to db modifications when this view isn't visible, i.e. when the
    // attachment approval view is presented.
    [self scrollToBottomAnimated:YES];
}

- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval didCancelAttachments:(NSArray <SignalAttachment *> * _Nonnull)attachments
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showErrorAlertForAttachment:(SignalAttachment *_Nullable)attachment
{
    OWSAssertDebug(attachment == nil || [attachment hasError]);
    
    NSString *errorMessage
    = (attachment ? [attachment localizedErrorDescription] : [SignalAttachment missingDataErrorMessage]);
    
    DDLogError(@"%@ %s: %@", self.logTag, __PRETTY_FUNCTION__, errorMessage);
    
    [OWSAlerts showAlertWithTitle:NSLocalizedString(
                                                    @"ATTACHMENT_ERROR_ALERT_TITLE", @"The title of the 'attachment error' alert.")
                          message:errorMessage];
}

- (CGFloat)safeContentHeight
{
    // Don't use self.collectionView.contentSize.height as the collection view's
    // content size might not be set yet.
    //
    // We can safely call prepareLayout to ensure the layout state is up-to-date
    // since our layout uses a dirty flag internally to debounce redundant work.
    [self.layout prepareLayout];
    return [self.collectionView.collectionViewLayout collectionViewContentSize].height;
}

- (void)scrollToBottomAnimated:(BOOL)animated
{
    OWSAssertIsOnMainThread();
    
    if (self.isUserScrolling) {
        return;
    }
    
    // Ensure the view is fully layed out before we try to scroll to the bottom, since
    // we use the collectionView bounds to determine where the "bottom" is.
    [self.view layoutIfNeeded];
    
    const CGFloat topInset = ^{
        if (@available(iOS 11, *)) {
            return -self.collectionView.adjustedContentInset.top;
        } else {
            return -self.collectionView.contentInset.top;
        }
    }();
    
    const CGFloat bottomInset = ^{
        if (@available(iOS 11, *)) {
            return -self.collectionView.adjustedContentInset.bottom;
        } else {
            return -self.collectionView.contentInset.bottom;
        }
    }();
    
    const CGFloat firstContentPageTop = topInset;
    const CGFloat collectionViewUnobscuredHeight = self.collectionView.bounds.size.height + bottomInset;
    const CGFloat lastContentPageTop = self.safeContentHeight - collectionViewUnobscuredHeight;
    
    CGFloat dstY = MAX(firstContentPageTop, lastContentPageTop);
    
    [self.collectionView setContentOffset:CGPointMake(0, dstY) animated:NO];
    [self didScrollToBottom];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateLastVisibleTimestamp];
    [self autoLoadMoreIfNecessary];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.userHasScrolled = YES;
    self.isUserScrolling = YES;
    if (self.inputToolbar.isFunctionViewDisplay) {
        [self.inputToolbar switchFunctionViewState:DTInputToobarStateNone animated:YES];
    }
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self performReloadUserStateSelectorWithDelayTime:0.3];
    [self performTranlateMessageWithDelayTime:1];
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    self.isUserScrolling = NO;
    if(!decelerate){
        [self performReloadUserStateSelectorWithDelayTime:0.3];
        [self performTranlateMessageWithDelayTime:1];
    }
}
- (void)performReloadUserStateSelectorWithDelayTime:(double) time {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateCellsUserState) object:nil];
    [self performSelector:@selector(updateCellsUserState) withObject:nil afterDelay:time inModes:@[NSDefaultRunLoopMode]];
}

- (void)performTranlateMessageWithDelayTime:(double) time {
    OWSLogInfo(@"performTranlateMessageWithDelayTime:::我被调用了");
    dispatch_async(dispatch_get_main_queue(), ^{//保证在同一个线程中
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(translateVisiableMeesage) object:nil];
        [self performSelector:@selector(translateVisiableMeesage) withObject:nil afterDelay:time];
    });
}

- (void)translateVisiableMeesage {
    OWSLogInfo(@"translateVisiableMeesage:::我被调用了");
    NSArray *visibleCells = self.collectionView.visibleCells;
    TSThread *thread = [TSThread fetchObjectWithUniqueID:self.thread.uniqueId];
    [self translateWithVisibleCells:visibleCells withThread:thread];
}

#pragma mark - OWSConversationSettingsViewDelegate

/*
 - (void)resendGroupUpdateForErrorMessage:(TSErrorMessage *)message
 {
 OWSAssertIsOnMainThread();
 OWSAssertDebug([_thread isKindOfClass:[TSGroupThread class]]);
 OWSAssertDebug(message);
 
 TSGroupThread *groupThread = (TSGroupThread *)self.thread;
 TSGroupModel *groupModel = groupThread.groupModel;
 [self updateGroupModelTo:groupModel
 successCompletion:^{
 OWSLogInfo(@"Group updated, removing group creation error.");
 
 [message remove];
 }];
 }
 */

- (void)conversationColorWasUpdated
{
    [self.conversationStyle updateProperties];
    [self.headerView updateAvatar];
    [self resetContentAndLayout];
}

//compatible old version
- (void)groupWasUpdated:(TSGroupThread *)groupThread removedMembers:(NSSet * _Nullable)removedMembers updateGroupInfo:(NSString *)updateGroupInfo
{
    OWSAssertDebug(groupThread);
    
    NSMutableSet *groupMemberIds = [NSMutableSet setWithArray:groupThread.groupModel.groupMemberIds];
    [groupMemberIds addObject:[TSAccountManager localNumber]];
    groupThread.groupModel.groupMemberIds = [NSMutableArray arrayWithArray:[groupMemberIds allObjects]];
    if(removedMembers.count){
        [self removeGroupMemberWithGroupThread:groupThread removedMembers:removedMembers updateGroupInfo:updateGroupInfo successCompletion:nil];
    }else{
        [self updateGroupModelTo:groupThread updateGroupInfo:updateGroupInfo successCompletion:nil];
    }
}


- (void)popAllConversationSettingsViews
{
    if (self.presentedViewController) {
        [self.presentedViewController
         dismissViewControllerAnimated:YES
         completion:^{
            [self.navigationController popToViewController:self animated:YES];
        }];
    } else {
        [self.navigationController popToViewController:self animated:YES];
    }
}

#pragma mark - ChooseAtMembersViewControllerDelegate
//@触发
- (void)chooseAtPeronsDidSelectRecipientId:(NSString *)recipientId name:(NSString *)name {
    [self selectAtPersonRecipientId:recipientId name:name];
}

- (void)selectAtPersonRecipientId:(NSString *)recipientId name:(NSString *)name {
    
    BOOL isAtALL = [recipientId isEqualToString:@"MENTIONS_ALL"] && [name isEqualToString:NSLocalizedString(@"SPECIAL_ACCOUNT_NAME_ALL", nil)];
    
    NSString *inputBarShowStr = [NSString stringWithFormat:@"%@%@%@",self.inputToolbar.messageText, name.length > 0?[NSString stringWithFormat:@"%@",name]:@"",DFInputAtEndChar];
    if(isAtALL){
        inputBarShowStr = [NSString stringWithFormat:@"%@%@%@",self.inputToolbar.messageText, name.length > 0?name:@"",DFInputAtEndChar];
    }
    if (![inputBarShowStr hasSuffix:DFInputAtEndChar]) {
        inputBarShowStr = [NSString stringWithFormat:@"%@%@", inputBarShowStr, DFInputAtEndChar];
    }
    [self.inputToolbar setMessageText:inputBarShowStr animated:NO];
    
    // 保存
    NSString *personShowStr = [NSString stringWithFormat:@"@%@%@", name.length > 0?[NSString stringWithFormat:@"%@",name]:@"",DFInputAtEndChar];
    if(isAtALL){
        personShowStr = [NSString stringWithFormat:@"@%@%@", name.length > 0?name:@"",DFInputAtEndChar];
    }
    if (![personShowStr hasSuffix:DFInputAtEndChar]) {
        personShowStr = [NSString stringWithFormat:@"%@%@", personShowStr, DFInputAtEndChar];
    }
    
    DFInputAtItem *item = [DFInputAtItem new];
    item.uid = recipientId;
    item.name = personShowStr;
    [self.inputToolbar.atCache addAtItem:item];
    
    [self.atVC dismissVC];
    [self.inputToolbar beginEditingTextMessage];
}

- (void)chooseAtPeronsCancel {
    [self.inputToolbar beginEditingTextMessage];
}

#pragma mark - ConversationViewLayoutDelegate

- (NSArray<id<ConversationViewLayoutItem>> *)layoutItems
{
    return self.viewItems;
}

- (CGFloat)layoutHeaderHeight
{
    return (self.showLoadMoreHeader ? kLoadMoreHeaderHeight : 0.f);
}

#pragma mark - ConversationInputToolbarDelegate


- (void)atIsActive{
    if (self.isGroupConversation) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // UI更新代码
            self.atVC = [ChooseAtMembersViewController presentFromViewController:self thread:(TSGroupThread *)self.thread delegate:self];
        });
    }
}

- (void)senderButtonPressed:(ConversationInputToolbar *)inputToolbar view:(UITextView *)textView {
    [self tryToSendTextMessage:self.inputToolbar.messageText updateKeyboardState:YES];
}


//@相关人的时候 @事件的处理
- (void)senderButtonPressed:(ConversationInputToolbar *)inputToolbar view:(UITextView *)textView atItem:(DFInputAtItem *)inputAtItem {
    [self tryToSendTextMessage:self.inputToolbar.messageText updateKeyboardState:YES];
}

//Thread回复
- (void)functionButtonPressed:(ConversationInputToolbar *)inputToolbar tag:(NSInteger)tag {
    if (tag == 0) {
        if (self.conversationViewMode == ConversationViewMode_Thread) {
            [self replayToUesrActionWith:inputToolbar];
        }
    }else if (tag == 1) {
        [self chooseFromLibraryAsMedia];
    } else if (tag == 2) {
        [self takePictureOrVideo];
    } else if (tag == 3) {
        [self translateStateChangeAction];
    } else if (tag == 4) {
        [inputToolbar startGroupAt];
        [self atIsActive];
    } else if (tag == 5) {
        if (inputToolbar.isFunctionViewDisplay) {
            [self scrollToBottomAnimated:YES];
        }
    }
}

- (void)replayToUesrActionWith:(ConversationInputToolbar *)inputToolbar{
    if (!inputToolbar.quotedReply) {//处理引用不存在的情况
        __block OWSQuotedReplyModel *quotedReply;
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            quotedReply = [OWSQuotedReplyModel quotedReplyForConversationViewItem:self.botViewItem transaction:transaction];
        }];
        
        if (![quotedReply isKindOfClass:[OWSQuotedReplyModel class]]) {
            OWSFailDebug(@"%@ unexpected quotedMessage: %@", self.logTag, quotedReply.class);
            return;
        }
        TSMessage *message = (TSMessage *)self.botViewItem.interaction;
        DTBotContextEntity *botContextEntity = nil;
        if (message.botContext) {//点击bot转发的消息进来thread页面
            botContextEntity = message.botContext;
            quotedReply.botContextEntity = botContextEntity;
        }else {//点击已经回复的信息进来。已经回复的消息中一定包含 threadContext
            //threadContext 上下文存在
            quotedReply.threadContext = message.threadContext;
        }
        quotedReply.viewModel = self.conversationViewMode;
        quotedReply.replyToUser = !inputToolbar.replyToUser;
        
        [inputToolbar setReplyToUserState:!inputToolbar.replyToUser];
        [inputToolbar setQuotedReply:quotedReply showQuotedMessagePreview:quotedReply.replyToUser];
        
        
        //        if ([self.botViewItem.interaction isKindOfClass:TSMessage.class]) {
        //            TSMessage *currentMessage =  (TSMessage *)self.botViewItem.interaction;
        //            self.threadHeadView.titleLabel.text = [self configureQuotedAuthorLabelWithAuthorId:currentMessage.botContext ? currentMessage.botContext.source.source : currentMessage.threadContext.source.source withGroupid:currentMessage.botContext.groupId?:currentMessage.threadContext.groupId];
        //        }
    }else{
        [inputToolbar setReplyToUserState:!inputToolbar.replyToUser];
        inputToolbar.quotedReply.replyToUser = inputToolbar.replyToUser;
        [inputToolbar setQuotedReply:inputToolbar.quotedReply showQuotedMessagePreview:inputToolbar.replyToUser];
        //        if (inputToolbar.replyToUser) {
        //            if ([self.botViewItem.interaction isKindOfClass:TSMessage.class]) {
        //                TSMessage *currentMessage =  (TSMessage *)self.botViewItem.interaction;
        //                self.threadHeadView.titleLabel.text = [self configureQuotedAuthorLabelWithAuthorId:currentMessage.botContext ? currentMessage.botContext.source.source : currentMessage.threadContext.source.source withGroupid:currentMessage.botContext.groupId?:currentMessage.threadContext.groupId];
        //            }
        //        }else {
        //            self.threadHeadView.titleLabel.attributedText = [self getNavgationTitle];
        //        }
    }
}

- (void)beginInput {
    
    [self scrollToBottomAnimated:YES];
}

- (NSArray<DTInputToolBarMoreItem *> *)inputToolbarMoreViewItems {
    
    NSMutableArray <DTInputToolBarMoreItem *> *tempItems = @[].mutableCopy;
    
    DTInputToolBarMoreItem *documentItem = [[DTInputToolBarMoreItem alloc] initWithTitle:NSLocalizedString(@"MEDIA_FROM_DOCUMENT_PICKER_BUTTON", @"") imageName:@"ic_inputbar_more_document"];
    documentItem.itemType = DTInputToolBarMoreItemTypeDocument;
    [tempItems addObject:documentItem];
    
    if (self.thread.isGroupThread && self.conversationViewMode != ConversationViewMode_Thread) {
        DTInputToolBarMoreItem *taskItem = [[DTInputToolBarMoreItem alloc] initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_CREATE_TASK", @"") imageName:@"ic_inputbar_more_task"];
        taskItem.itemType = DTInputToolBarMoreItemTypeTask;
        [tempItems addObject:taskItem];
        
        DTInputToolBarMoreItem *pollItem = [[DTInputToolBarMoreItem alloc] initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_CREATE_VOTE", @"") imageName:@"ic_inputbar_more_poll"];
        pollItem.itemType = DTInputToolBarMoreItemTypePoll;
        [tempItems addObject:pollItem];
    } else {
        if (self.thread.contactIdentifier.length <= 6) {
            
        } else {
            DTInputToolBarMoreItem *taskItem = [[DTInputToolBarMoreItem alloc] initWithTitle:NSLocalizedString(@"MESSAGE_ACTION_CREATE_TASK", @"") imageName:@"ic_inputbar_more_task"];
            taskItem.itemType = DTInputToolBarMoreItemTypeTask;
            [tempItems addObject:taskItem];
        }
    }
    
    return tempItems.copy;
}

- (void)inputToolbar:(ConversationInputToolbar *)inputToolbar didSelectItemType:(DTInputToolBarMoreItemType)itemType {
    
    switch (itemType) {
        case DTInputToolBarMoreItemTypeDocument:
            [self showAttachmentDocumentPickerMenu];
            break;
        case DTInputToolBarMoreItemTypeTask: {
            DTLightTaskEntity *taskEntity = [DTLightTaskEntity new];
            taskEntity.priority = 3;
            if ([self.thread isKindOfClass:[TSGroupThread class]]) {
                taskEntity.gid = self.serverGroupId;
            } else {
                taskEntity.uid = self.thread.contactIdentifier;
                DTTaskMemberEntity *member = [DTTaskMemberEntity new];
                member.role = DTTaskMemberRoleAssignee;
                member.uid = self.thread.contactIdentifier;
                taskEntity.users = @[member];
            }
            [self addTaskWithEntity:taskEntity];
        }
            break;
        case DTInputToolBarMoreItemTypePoll:{
            if ([self.thread isKindOfClass:TSGroupThread.class]) {
                DTVoteViewController *voteVC = [[DTVoteViewController alloc] initWithThread:(TSGroupThread *)self.thread withSuccessHandler:^(DTVoteMessageEntity * _Nonnull entity) {
                    OWSLogInfo(@"DTVoteViewController::::::");
                    entity.uniqueId = entity.voteId;
                    [ThreadUtil sendVoteMessageWithVote:entity inThread:self.thread success:^{
                        
                    } failure:^(NSError * _Nonnull error) {
                        
                    }];
                }];
                OWSNavigationController *voteNav = [[OWSNavigationController alloc] initWithRootViewController:voteVC];
                voteNav.modalPresentationStyle = UIModalPresentationFullScreen;
                [self presentViewController:voteNav animated:true completion:nil];
            }
        }
            break;
        default:
            break;
    }
}

- (void)translateStateChangeAction {
    
    NSInteger translateSettingType = self.thread.translateSettingType.integerValue;
    if (translateSettingType == 0) {
        if ([DateUtil isChinese]) {
            [self changeTranslateSettingType:DTTranslateMessageTypeChinese];
        } else {
            [self changeTranslateSettingType:DTTranslateMessageTypeEnglish];
        }
        [self.inputToolbar setTranslateOpen:YES];
    } else {
        [self changeTranslateSettingType:DTTranslateMessageTypeOriginal];
        [self.inputToolbar setTranslateOpen:NO];
    }
}

- (void)changeTranslateSettingType:(DTTranslateMessageType)type {
    self.thread.translateSettingType = @(type);
    [self.databaseStorage writeWithBlock:^(SDSAnyWriteTransaction * _Nonnull writeTransaction) {
        YapDatabaseReadWriteTransaction *transaction = writeTransaction.transitional_yapWriteTransaction;
        
        NSString * upinfo = [DTGroupUtils getTranslateSettingChangedInfoStringWithUserChangeType:type];
        if (upinfo && upinfo.length) {
            uint64_t now = [NSDate ows_millisecondTimeStamp];
            [[[TSInfoMessage alloc] initWithTimestamp:now
                                             inThread:self.thread
                                          messageType:TSInfoMessageTypeGroupUpdate
                                        customMessage:upinfo] saveWithTransaction:transaction];
        }
        
        [self.thread saveWithTransaction:transaction];
    }];
}

- (void)updateOldVersionReplyState {
    NSString * buildVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if ([buildVersion integerValue] <= 22031902) {
        
    }
}

- (void)tryToSendTextMessage:(NSString *)text updateKeyboardState:(BOOL)updateKeyboardState
{
    
    // modify 隐藏掉黑名单功能，则不需要判断
    __weak ConversationViewController *weakSelf = self;
    //    if ([self isBlockedContactConversation]) {
    //        [self showUnblockContactUI:^(BOOL isBlocked) {
    //            if (!isBlocked) {
    //                [weakSelf tryToSendTextMessage:text updateKeyboardState:NO];
    //            }
    //        }];
    //        return;
    //    }
    // modify 去掉提示信任安全码功能
    BOOL didShowSNAlert =
    [self showSafetyNumberConfirmationIfNecessaryWithConfirmationText:[SafetyNumberStrings confirmSendButton] completion:^(BOOL didConfirmIdentity) {
        if (didConfirmIdentity) {
            [weakSelf tryToSendTextMessage:text updateKeyboardState:NO];
        }
    }];
    if (didShowSNAlert) {
        return;
    }
    
    text = [text ows_stripped];
    
    if (text.length < 1) {
        return;
    }
    
    // Limit outgoing text messages to 16kb.
    //
    // We convert large text messages to attachments
    // which are presented as normal text messages.
    BOOL didAddToProfileWhitelist = [ThreadUtil addThreadToProfileWhitelistIfEmptyContactThread:self.thread];
    TSOutgoingMessage *message;
    
    if ([text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] >= kOversizeTextMessageSizeThreshold) {
        DataSource *_Nullable dataSource = [DataSourceValue dataSourceWithOversizeText:text];
        SignalAttachment *attachment =
        [SignalAttachment attachmentWithDataSource:dataSource dataUTI:kOversizeTextAttachmentUTI];
        // TODO we should redundantly send the first n chars in the body field so it can be viewed
        // on clients that don't support oversized text messgaes, (and potentially generate a preview
        // before the attachment is downloaded)
        message = [ThreadUtil sendMessageWithAttachment:attachment
                                               inThread:self.thread
                                       quotedReplyModel:self.inputToolbar.quotedReply
                                          messageSender:self.messageSender
                                             completion:nil];
    } else {
        message = [ThreadUtil sendMessageWithText:text
                                        atPersons:[self finalChoosePersons]
                                         inThread:self.thread
                                 quotedReplyModel:self.inputToolbar.quotedReply
                                    messageSender:self.messageSender];
    }
    
    [self messageWasSent:message];
    
    if (updateKeyboardState) {
        [self.inputToolbar toggleDefaultKeyboard];
    }
    [self.inputToolbar clearTextMessageAnimated:YES];
    [self.inputToolbar.atCache clean];
    [self clearDraft];
    if (didAddToProfileWhitelist) {
        [self ensureDynamicInteractions];
    }
}

- (void)checkReplyModelForBot {//如果是Thread 模式
    if (self.conversationViewMode == ConversationViewMode_Thread) {
        __block OWSQuotedReplyModel *quotedReply;
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            quotedReply = [OWSQuotedReplyModel quotedReplyForConversationViewItem:self.botViewItem transaction:transaction];
        }];
        
        if (![quotedReply isKindOfClass:[OWSQuotedReplyModel class]]) {
            OWSFailDebug(@"%@ unexpected quotedMessage: %@", self.logTag, quotedReply.class);
            return;
        }
        
        TSMessage *message = (TSMessage *)self.botViewItem.interaction;
        DTBotContextEntity *botContextEntity = nil;
        if (message.botContext) {//点击bot转发的消息进来thread页面
            botContextEntity = message.botContext;
            quotedReply.botContextEntity = botContextEntity;
        }else {//点击已经回复的信息进来。已经回复的消息中一定包含 threadContext
            //threadContext 上下文存在
            quotedReply.threadContext = message.threadContext;
        }
        quotedReply.viewModel = self.conversationViewMode;
        quotedReply.longPressed = false;
        quotedReply.quoteItem = self.botViewItem;
        quotedReply.replyToUser = true;
        quotedReply.manualBuild = true;
        [self.inputToolbar setReplyToUserState:true];
        quotedReply.quotedType = DTPreviewQuotedType_Reply;
        self.inputToolbar.quotedReply = quotedReply;
    }
}


-(NSString *)finalChoosePersons{
    NSMutableString *realPersons = [[NSMutableString alloc] initWithCapacity:1];
    
    NSArray *allShowName = [self.inputToolbar.atCache allAtUid:self.inputToolbar.originMessageText];
    for (NSString *recipientId in allShowName) {
        if (recipientId.length) {
            [realPersons appendString:[NSString stringWithFormat:@"%@;",recipientId]];
        }
    }
    
    return realPersons;
}

- (void)voiceMemoGestureDidStart
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"voiceMemoGestureDidStart");
    
    const CGFloat kIgnoreMessageSendDoubleTapDurationSeconds = 2.f;
    if (self.lastMessageSentDate &&
        [[NSDate new] timeIntervalSinceDate:self.lastMessageSentDate] < kIgnoreMessageSendDoubleTapDurationSeconds) {
        // If users double-taps the message send button, the second tap can look like a
        // very short voice message gesture.  We want to ignore such gestures.
        [self.inputToolbar cancelVoiceMemoIfNecessary];
        [self.inputToolbar hideVoiceMemoUI:NO];
        [self cancelRecordingVoiceMemo];
        return;
    }
    
    [self.inputToolbar showVoiceMemoUI];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    [self requestRecordingVoiceMemo];
}

- (void)voiceMemoGestureDidEnd
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"voiceMemoGestureDidEnd");
    
    [self.inputToolbar hideVoiceMemoUI:YES];
    [self endRecordingVoiceMemo];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)voiceMemoGestureDidCancel
{
    OWSAssertIsOnMainThread();
    
    OWSLogInfo(@"voiceMemoGestureDidCancel");
    
    [self.inputToolbar hideVoiceMemoUI:NO];
    [self cancelRecordingVoiceMemo];
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)voiceMemoGestureDidChange:(CGFloat)cancelAlpha
{
    OWSAssertIsOnMainThread();
    
    [self.inputToolbar setVoiceMemoUICancelAlpha:cancelAlpha];
}

- (void)cancelVoiceMemo
{
    OWSAssertIsOnMainThread();
    
    [self.inputToolbar cancelVoiceMemoIfNecessary];
    [self.inputToolbar hideVoiceMemoUI:NO];
    [self cancelRecordingVoiceMemo];
}

#pragma mark - Database Observation

- (void)setIsUserScrolling:(BOOL)isUserScrolling
{
    _isUserScrolling = isUserScrolling;
    [self autoLoadMoreIfNecessary];
}

- (void)setIsViewVisible:(BOOL)isViewVisible
{
    _isViewVisible = isViewVisible;
    
    [self updateShouldObserveDBModifications];
    [self updateCellsVisible];
}

- (void)updateCellsVisible
{
    BOOL isAppInBackground = CurrentAppContext().isInBackground;
    BOOL isCellVisible = self.isViewVisible && !isAppInBackground;
    for (ConversationViewCell *cell in self.collectionView.visibleCells) {
        cell.isCellVisible = isCellVisible;
    }
}

- (void)updateShouldObserveDBModifications
{
    if (!CurrentAppContext().isAppForegroundAndActive) {
        self.shouldObserveDBModifications = NO;
        return;
    }
    
    if (!self.isViewVisible) {
        self.shouldObserveDBModifications = NO;
        return;
    }
    
    if (OWSWindowManager.sharedManager.isPresentingMenuActions) {
        self.shouldObserveDBModifications = NO;
        return;
    }
    
    self.shouldObserveDBModifications = YES;
}

- (void)setShouldObserveDBModifications:(BOOL)shouldObserveDBModifications
{
    if (_shouldObserveDBModifications == shouldObserveDBModifications) {
        return;
    }
    
    _shouldObserveDBModifications = shouldObserveDBModifications;
    
    if (self.shouldObserveDBModifications) {
        DDLogVerbose(@"%@ resume observation of database modifications.", self.logTag);
        // We need to call resetMappings when we _resume_ observing DB modifications,
        // since we've been ignore DB modifications so the mappings can be wrong.
        //
        // resetMappings can however have the side effect of increasing the mapping's
        // "window" size.  If that happens, we need to restore the scroll state.
        
        // Snapshot the scroll state by measuring the "distance from top of view to
        // bottom of content"; if the mapping's "window" size grows, it will grow
        // _upward_.
        CGFloat viewTopToContentBottom = 0;
        OWSAssertDebug([self.collectionView.collectionViewLayout isKindOfClass:[ConversationViewLayout class]]);
        ConversationViewLayout *conversationViewLayout
        = (ConversationViewLayout *)self.collectionView.collectionViewLayout;
        // To avoid laying out the collection view during initial view
        // presentation, don't trigger layout here (via safeContentHeight)
        // until layout has been done at least once.
        if (conversationViewLayout.hasEverHadLayout) {
            viewTopToContentBottom = self.safeContentHeight - self.collectionView.contentOffset.y;
        }
        
        NSUInteger oldCellCount = [self.messageMappings numberOfItemsInGroup:self.thread.uniqueId];
        
        // ViewItems modified while we were not observing may be stale.
        //
        // TODO: have a more fine-grained cache expiration based on rows modified.
        [self.viewItemCache removeAllObjects];
        
        // Snapshot the "previousLastTimestamp" value; it will be cleared by resetMappings.
        NSNumber *_Nullable previousLastTimestamp = self.previousLastTimestamp;
        
        [self resetMappings];
        
        NSUInteger newCellCount = [self.messageMappings numberOfItemsInGroup:self.thread.uniqueId];
        
        // Detect changes in the mapping's "window" size.
        if (oldCellCount != newCellCount) {
            CGFloat newContentHeight = self.safeContentHeight;
            CGPoint newContentOffset = CGPointMake(0, MAX(0, newContentHeight - viewTopToContentBottom));
            [self.collectionView setContentOffset:newContentOffset animated:NO];
        }
        
        // When we resume observing database changes, we want to scroll to show the user
        // any new items inserted while we were not observing.  We therefore find the
        // first item at or after the "view horizon".  See the comments below which explain
        // the "view horizon".
        ConversationViewItem *_Nullable lastViewItem = self.viewItems.lastObject;
        BOOL hasAddedNewItems = (lastViewItem && previousLastTimestamp
                                 && lastViewItem.interaction.timestamp > previousLastTimestamp.unsignedLongLongValue);
        
        OWSLogInfo(@"%@ hasAddedNewItems: %d", self.logTag, hasAddedNewItems);
        if (hasAddedNewItems) {
            NSIndexPath *_Nullable indexPathToShow = [self firstIndexPathAtViewHorizonTimestamp];
            if (indexPathToShow) {
                // The goal is to show _both_ the last item before the "view horizon" and the
                // first item after the "view horizon".  We can't do "top on first item after"
                // or "bottom on last item before" or we won't see the other. Unfortunately,
                // this gets tricky if either is huge.  The largest cells are oversize text,
                // which should be rare.  Other cells are considerably smaller than a screenful.
                [self.collectionView scrollToItemAtIndexPath:indexPathToShow
                                            atScrollPosition:UICollectionViewScrollPositionCenteredVertically
                                                    animated:NO];
            }
        }
        self.viewHorizonTimestamp = nil;
        DDLogVerbose(@"%@ resumed observation of database modifications.", self.logTag);
    } else {
        DDLogVerbose(@"%@ pausing observation of database modifications.", self.logTag);
        // When stopping observation, try to record the timestamp of the "view horizon".
        // The "view horizon" is where we'll want to focus the users when we resume
        // observation if any changes have happened while we weren't observing.
        // Ideally, we'll focus on those changes.  But we can't skip over unread
        // interactions, so we prioritize those, if any.
        //
        // We'll use this later to update the view to reflect any changes made while
        // we were not observing the database.  See extendRangeToIncludeUnobservedItems
        // and the logic above.
        ConversationViewItem *_Nullable lastViewItem = self.viewItems.lastObject;
        if (lastViewItem) {
            self.previousLastTimestamp = @(lastViewItem.interaction.timestamp);
        } else {
            self.previousLastTimestamp = nil;
        }
        __block TSInteraction *_Nullable firstUnseenInteraction = nil;
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            firstUnseenInteraction =
            [[TSDatabaseView unseenDatabaseViewExtension:transaction] firstObjectInGroup:self.thread.uniqueId];
        }];
        if (firstUnseenInteraction) {
            // If there are any unread interactions, focus on the first one.
            self.viewHorizonTimestamp = @(firstUnseenInteraction.timestamp);
        } else if (lastViewItem) {
            // Otherwise, focus _just after_ the last interaction.
            self.viewHorizonTimestamp = @(lastViewItem.interaction.timestamp + 1);
        } else {
            self.viewHorizonTimestamp = nil;
        }
        DDLogVerbose(@"%@ paused observation of database modifications.", self.logTag);
    }
}

- (nullable NSIndexPath *)firstIndexPathAtViewHorizonTimestamp
{
    OWSAssertDebug(self.shouldObserveDBModifications);
    
    if (!self.viewHorizonTimestamp) {
        return nil;
    }
    if (self.viewItems.count < 1) {
        return nil;
    }
    uint64_t viewHorizonTimestamp = self.viewHorizonTimestamp.unsignedLongLongValue;
    // Binary search for the first view item whose timestamp >= the "view horizon" timestamp.
    // We want to move "left" rightward, discarding interactions before this cutoff.
    // We want to move "right" leftward, discarding all-but-the-first interaction after this cutoff.
    // In the end, if we converge on an item _after_ this cutoff, it's the one we want.
    // If we converge on an item _before_ this cutoff, there was no interaction that fit our criteria.
    NSUInteger left = 0, right = self.viewItems.count - 1;
    while (left != right) {
        OWSAssertDebug(left < right);
        NSUInteger mid = (left + right) / 2;
        OWSAssertDebug(left <= mid);
        OWSAssertDebug(mid < right);
        ConversationViewItem *viewItem  = self.viewItems[mid];
        if (viewItem.interaction.timestamp >= viewHorizonTimestamp) {
            right = mid;
        } else {
            // This is an optimization; it also ensures that we converge.
            left = mid + 1;
        }
    }
    OWSAssertDebug(left == right);
    ConversationViewItem *viewItem  = self.viewItems[left];
    if (viewItem.interaction.timestamp >= viewHorizonTimestamp) {
        OWSLogInfo(@"%@ firstIndexPathAtViewHorizonTimestamp: %zd / %zd", self.logTag, left, self.viewItems.count);
        return [NSIndexPath indexPathForRow:(NSInteger) left inSection:0];
    } else {
        OWSLogInfo(@"%@ firstIndexPathAtViewHorizonTimestamp: none / %zd", self.logTag, self.viewItems.count);
        return nil;
    }
}

// We stop observing database modifications when the app or this view is not visible
// (see: shouldObserveDBModifications).  When we resume observing db modifications,
// we want to extend the "range" of this view to include any items added to this
// thread while we were not observing.
- (void)extendRangeToIncludeUnobservedItems
{
    if (!self.shouldObserveDBModifications) {
        return;
    }
    if (!self.previousLastTimestamp) {
        return;
    }
    
    uint64_t previousLastTimestamp = self.previousLastTimestamp.unsignedLongLongValue;
    __block NSUInteger addedItemCount = 0;
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [[transaction ext:[self getDatabaseViewExtensionName]]
         enumerateRowsInGroup:self.thread.uniqueId
         withOptions:NSEnumerationReverse
         usingBlock:^(NSString *collection,
                      NSString *key,
                      id object,
                      id metadata,
                      NSUInteger index,
                      BOOL *stop) {
            
            if (![object isKindOfClass:[TSInteraction class]]) {
                OWSFailDebug(@"Expected a TSInteraction: %@", [object class]);
                return;
            }
            
            TSInteraction *interaction = (TSInteraction *)object;
            if (interaction.timestamp <= previousLastTimestamp) {
                *stop = YES;
                return;
            }
            
            addedItemCount++;
        }];
    }];
    OWSLogInfo(@"%@ extendRangeToIncludeUnobservedItems: %zd", self.logTag, addedItemCount);
    self.lastRangeLength += addedItemCount;
    // We only want to do this once, so clear the "previous last timestamp".
    self.previousLastTimestamp = nil;
}

- (void)resetMappings
{
    // If we're entering "active" mode (e.g. view is visible and app is in foreground),
    // reset all state updated by yapDatabaseModified:.
    if (self.messageMappings != nil) {
        // Before we begin observing database modifications, make sure
        // our mapping and table state is up-to-date.
        // refresh step 4-1 beginLongLivedReadTransaction
        [self.uiDatabaseConnection beginLongLivedReadTransaction];
        //        [self extendRangeToIncludeUnobservedItems];
        [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            // refresh step 4-2 update messageMappings
            [self.messageMappings updateWithTransaction:transaction];
        }];
        // refresh step 4-3 update the messageMappings range
        [self updateMessageMappingRangeOptions];
    }
    
    // refresh step 4-4 reloadViewItems
    //    self.collapseCutoffDate = [NSDate new];
    //    [self reloadViewItems];
    
    // refresh step 4-4 reloadViewItems in resetContentAndLayout
    [self resetContentAndLayout];
    
    [self ensureDynamicInteractions];
    [self updateBackButtonUnreadCount];
}

#pragma mark - ConversationCollectionViewDelegate

- (void)collectionViewWillChangeLayout
{
    OWSAssertIsOnMainThread();
}

- (void)collectionViewDidChangeLayout
{
    OWSAssertIsOnMainThread();
    
    [self updateLastVisibleTimestamp];
    self.conversationStyle.viewWidth = self.collectionView.width;
}

#pragma mark - View Items

// This is a key method.  It builds or rebuilds the list of
// cell view models.
- (void)reloadViewItems
{
    NSMutableArray<ConversationViewItem *> *viewItems = [NSMutableArray new];
    NSMutableDictionary<NSString *, ConversationViewItem *> *viewItemCache = [NSMutableDictionary new];
    
    NSUInteger count = [self.messageMappings numberOfItemsInSection:0];
    OWSLogInfo(@"count = %lu", (unsigned long)count);
    BOOL isGroupThread = self.isGroupConversation;
    
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        YapDatabaseViewTransaction *viewTransaction = [transaction ext:[self getDatabaseViewExtensionName]];
        OWSAssertDebug(viewTransaction);
        for (NSUInteger row = 0; row < count; row++) {
            TSInteraction *interaction =
            [viewTransaction objectAtRow:row inSection:0 withMappings:self.messageMappings];
            if (!interaction) {
                OWSLogError(@"%@ missing interaction in message mappings: %zd / %zd.", self.logTag, row, count);
                // TODO: Add analytics.
                continue;
            }
            if (!interaction.uniqueId) {
                OWSLogError(@"%@ invalid interaction in message mappings: %zd / %zd: %@.",
                            self.logTag,
                            row,
                            count,
                            interaction.description);
                // TODO: Add analytics.
                continue;
            }
            
            if (![interaction isKindOfClass:[TSInteraction class]]) {
                continue;
            }
            
            //            if ([interaction isKindOfClass:[OWSDisappearingConfigurationUpdateInfoMessage class]]) {
            //                continue;
            //            }
            
            ConversationViewItem *_Nullable viewItem = self.viewItemCache[interaction.uniqueId];
            if (!viewItem) {
                viewItem = [[ConversationViewItem alloc] initWithInteraction:interaction
                                                               isGroupThread:isGroupThread
                                                                 transaction:transaction
                                                           conversationStyle:self.conversationStyle];
            }
            if([interaction isKindOfClass:[TSMessage class]] && ((TSMessage *)interaction).taskId.length){
                DTTaskMessageEntity *task = [DTTaskMessageEntity fetchObjectWithUniqueID:((TSMessage *)interaction).taskId
                                                                             transaction:transaction];
                viewItem.task = task;
            }
            
            if ([interaction isKindOfClass:[TSMessage class]] && ((TSMessage *)interaction).voteId.length) {
                DTVoteMessageEntity *vote = [DTVoteMessageEntity fetchObjectWithUniqueID:((TSMessage *)interaction).voteId
                                                                             transaction:transaction];
                viewItem.vote = vote;
                if ([self.voteInfo.allKeys containsObject:interaction.uniqueId]) {
                    viewItem.voteInfoArr = [self.voteInfo objectForKey:interaction.uniqueId];
                }
            }
            
            [viewItems addObject:viewItem];
            
            OWSAssertDebug(!viewItemCache[interaction.uniqueId]);
            viewItemCache[interaction.uniqueId] = viewItem;
        }
    }];
    
    // Update the "break" properties (shouldShowDate and unreadIndicator) of the view items.
    BOOL shouldShowDateOnNextViewItem = YES;
    uint64_t previousViewItemTimestamp = 0;
    OWSUnreadIndicator *_Nullable unreadIndicator = self.dynamicInteractions.unreadIndicator;
    uint64_t collapseCutoffTimestamp = [NSDate ows_millisecondsSince1970ForDate:self.collapseCutoffDate];
    
    BOOL hasPlacedUnreadIndicator = NO;
    for (ConversationViewItem *viewItem in viewItems) {
        BOOL canShowDate = NO;
        switch (viewItem.interaction.interactionType) {
            case OWSInteractionType_Unknown:
            case OWSInteractionType_Offer:
                canShowDate = NO;
                break;
            case OWSInteractionType_IncomingMessage:
            case OWSInteractionType_OutgoingMessage:
            case OWSInteractionType_Error:
            case OWSInteractionType_Info:
            case OWSInteractionType_Call:
                canShowDate = YES;
                break;
            default:
                canShowDate = NO;
                break;
        }
        
        uint64_t viewItemTimestamp = viewItem.interaction.timestampForSorting;
        OWSAssertDebug(viewItemTimestamp > 0);
        
        BOOL shouldShowDate = NO;
        if (previousViewItemTimestamp == 0) {
            shouldShowDateOnNextViewItem = YES;
        } else if (![DateUtil isSameDayWithTimestamp:previousViewItemTimestamp timestamp:viewItemTimestamp]) {
            shouldShowDateOnNextViewItem = YES;
        }
        
        if (shouldShowDateOnNextViewItem && canShowDate) {
            shouldShowDate = YES;
            shouldShowDateOnNextViewItem = NO;
        }
        
        viewItem.shouldShowDate = shouldShowDate;
        
        previousViewItemTimestamp = viewItemTimestamp;
        
        // When a conversation without unread messages receives an incoming message,
        // we call ensureDynamicInteractions to ensure that the unread indicator (etc.)
        // state is updated accordingly.  However this is done in a separate transaction.
        // We don't want to show the incoming message _without_ an unread indicator and
        // then immediately re-render it _with_ an unread indicator.
        //
        // To avoid this, we use a temporary instance of OWSUnreadIndicator whenever
        // we find an unread message that _should_ have an unread indicator, but no
        // unread indicator exists yet on dynamicInteractions.
        BOOL isItemUnread = ([viewItem.interaction conformsToProtocol:@protocol(OWSReadTracking)]
                             && !((id<OWSReadTracking>)viewItem.interaction).wasRead);
        if (isItemUnread && !unreadIndicator && !hasPlacedUnreadIndicator && !self.hasClearedUnreadMessagesIndicator) {
            
            unreadIndicator =
            [[OWSUnreadIndicator alloc] initHasMoreUnseenMessages:NO
                             missingUnseenSafetyNumberChangeCount:0
                                          unreadIndicatorPosition:0
                                  firstUnseenInteractionTimestamp:viewItem.interaction.timestampForSorting];
        }
        
        // Place the unread indicator onto the first appropriate view item,
        // if any.
        if (unreadIndicator && viewItem.interaction.timestampForSorting >= unreadIndicator.firstUnseenInteractionTimestamp) {
            viewItem.unreadIndicator = unreadIndicator;
            unreadIndicator = nil;
            hasPlacedUnreadIndicator = YES;
        } else {
            viewItem.unreadIndicator = nil;
        }
    }
    if (unreadIndicator) {
        // This isn't necessarily a bug - all of the interactions after the
        // unread indicator may have disappeared or been deleted.
        OWSLogWarn(@"%@ Couldn't find an interaction to hang the unread indicator on.", self.logTag);
    }
    
    // Update the properties of the view items.
    //
    // NOTE: This logic uses the break properties which are set in the previous pass.
    for (NSUInteger i = 0; i < viewItems.count; i++) {
        ConversationViewItem *viewItem = viewItems[i];
        ConversationViewItem *_Nullable previousViewItem = (i > 0 ? viewItems[i - 1] : nil);
        ConversationViewItem *_Nullable nextViewItem = (i + 1 < viewItems.count ? viewItems[i + 1] : nil);
        BOOL shouldShowSenderAvatar = NO;
        BOOL shouldHideFooter = NO;
        BOOL isFirstInCluster = YES;
        BOOL isLastInCluster = YES;
        NSAttributedString *_Nullable senderName = nil;
        
        OWSInteractionType interactionType = viewItem.interaction.interactionType;
        NSString *timestampText = [DateUtil formatTimestampShort:viewItem.interaction.timestamp];
        
        if (interactionType == OWSInteractionType_OutgoingMessage) {
            TSOutgoingMessage *outgoingMessage = (TSOutgoingMessage *)viewItem.interaction;
            MessageReceiptStatus receiptStatus =
            [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:outgoingMessage];
            BOOL isDisappearingMessage = outgoingMessage.isExpiringMessage;
            
            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                TSOutgoingMessage *nextOutgoingMessage = (TSOutgoingMessage *)nextViewItem.interaction;
                MessageReceiptStatus nextReceiptStatus =
                [MessageRecipientStatusUtils recipientStatusWithOutgoingMessage:nextOutgoingMessage];
                NSString *nextTimestampText = [DateUtil formatTimestampShort:nextViewItem.interaction.timestamp];
                
                // We can skip the "outgoing message status" footer if the next message
                // has the same footer and no "date break" separates us...
                // ...but always show "failed to send" status
                // ...and always show the "disappearing messages" animation.
                shouldHideFooter
                = ([timestampText isEqualToString:nextTimestampText] && receiptStatus == nextReceiptStatus
                   && outgoingMessage.messageState != TSOutgoingMessageStateFailed && !nextViewItem.hasCellHeader
                   && !isDisappearingMessage);
            }
            
            // clustering
            if (previousViewItem == nil) {
                isFirstInCluster = YES;
            } else if (viewItem.hasCellHeader) {
                isFirstInCluster = YES;
            } else {
                isFirstInCluster = previousViewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage;
            }
            
            if (nextViewItem == nil) {
                isLastInCluster = YES;
            } else if (nextViewItem.hasCellHeader) {
                isLastInCluster = YES;
            } else {
                isLastInCluster = nextViewItem.interaction.interactionType != OWSInteractionType_OutgoingMessage;
            }
            if (previousViewItem && previousViewItem.interaction.interactionType == interactionType) {
                shouldShowSenderAvatar = viewItem.hasCellHeader;
            }else {
                shouldShowSenderAvatar = YES;
            }
        } else if (interactionType == OWSInteractionType_IncomingMessage) {
            
            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)viewItem.interaction;
            NSString *incomingSenderId = incomingMessage.authorId;
            OWSAssertDebug(incomingSenderId.length > 0);
            BOOL isDisappearingMessage = incomingMessage.isExpiringMessage;
            
            NSString *_Nullable nextIncomingSenderId = nil;
            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                TSIncomingMessage *nextIncomingMessage = (TSIncomingMessage *)nextViewItem.interaction;
                nextIncomingSenderId = nextIncomingMessage.authorId;
                OWSAssertDebug(nextIncomingSenderId.length > 0);
            }
            
            if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
                NSString *nextTimestampText = [DateUtil formatTimestampShort:nextViewItem.interaction.timestamp];
                // We can skip the "incoming message status" footer in a cluster if the next message
                // has the same footer and no "date break" separates us.
                // ...but always show the "disappearing messages" animation.
                shouldHideFooter = ([timestampText isEqualToString:nextTimestampText] && !nextViewItem.hasCellHeader &&
                                    [NSObject isNullableObject:nextIncomingSenderId equalTo:incomingSenderId]
                                    && !isDisappearingMessage);
            }
            
            // clustering
            if (previousViewItem == nil) {
                isFirstInCluster = YES;
            } else if (viewItem.hasCellHeader) {
                isFirstInCluster = YES;
            } else if (previousViewItem.interaction.interactionType != OWSInteractionType_IncomingMessage) {
                isFirstInCluster = YES;
            } else {
                TSIncomingMessage *previousIncomingMessage = (TSIncomingMessage *)previousViewItem.interaction;
                isFirstInCluster = ![incomingSenderId isEqual:previousIncomingMessage.authorId];
            }
            
            if (nextViewItem == nil) {
                isLastInCluster = YES;
            } else if (nextViewItem.interaction.interactionType != OWSInteractionType_IncomingMessage) {
                isLastInCluster = YES;
            } else if (nextViewItem.hasCellHeader) {
                isLastInCluster = YES;
            } else {
                TSIncomingMessage *nextIncomingMessage = (TSIncomingMessage *)nextViewItem.interaction;
                isLastInCluster = ![incomingSenderId isEqual:nextIncomingMessage.authorId];
            }
            
            //            if (viewItem.isGroupThread) {
            // Show the sender name for incoming group messages unless
            // the previous message has the same sender name and
            // no "date break" separates us.
            BOOL shouldShowSenderName = YES;
            if (previousViewItem && previousViewItem.interaction.interactionType == interactionType) {
                TSIncomingMessage *previousIncomingMessage = (TSIncomingMessage *)previousViewItem.interaction;
                NSString *previousIncomingSenderId = previousIncomingMessage.authorId;
                OWSAssertDebug(previousIncomingSenderId.length > 0);
                shouldShowSenderAvatar = (![NSObject isNullableObject:previousIncomingSenderId equalTo:incomingSenderId]|| viewItem.hasCellHeader);
                shouldShowSenderName
                = (![NSObject isNullableObject:previousIncomingSenderId equalTo:incomingSenderId]
                   || viewItem.hasCellHeader);
            }else {
                shouldShowSenderAvatar = YES;
            }
            
            if (shouldShowSenderName) {
                senderName = [self.contactsManager
                              attributedContactOrProfileNameForPhoneIdentifier:incomingSenderId
                              primaryAttributes:[OWSMessageBubbleView
                                                 senderNamePrimaryAttributes]
                              secondaryAttributes:[OWSMessageBubbleView
                                                   senderNameSecondaryAttributes]];
            }
            
            // Show the sender avatar for incoming group messages unless
            // the next message has the same sender avatar and
            // no "date break" separates us.
            //                shouldShowSenderAvatar = YES;
            //                if (nextViewItem && nextViewItem.interaction.interactionType == interactionType) {
            //                    shouldShowSenderAvatar = (![NSObject isNullableObject:nextIncomingSenderId equalTo:incomingSenderId]
            //                        || nextViewItem.hasCellHeader);
            //                }
            //            }
        }
        
        if (viewItem.interaction.timestampForSorting > collapseCutoffTimestamp) {
            shouldHideFooter = NO;
        }
        
        viewItem.isFirstInCluster = isFirstInCluster;
        viewItem.isLastInCluster = isLastInCluster;
        viewItem.shouldShowSenderAvatar = shouldShowSenderAvatar;
        viewItem.shouldHideFooter = shouldHideFooter;
        viewItem.senderName = senderName;
        viewItem.conversationViewMode = self.conversationViewMode;
    }
    
    self.viewItems = viewItems;
    self.viewItemCache = viewItemCache;
}

// Whenever an interaction is modified, we need to reload it from the DB
// and update the corresponding view item.
- (void)reloadInteractionForViewItem:(ConversationViewItem *)viewItem
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(viewItem);
    
    // This should never happen, but don't crash in production if we have a bug.
    if (!viewItem) {
        return;
    }
    
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *readTransaction) {
        YapDatabaseReadTransaction *transaction = readTransaction.transitional_yapReadTransaction;
        TSInteraction *_Nullable interaction =
        [TSInteraction fetchObjectWithUniqueID:viewItem.interaction.uniqueId transaction:transaction];
        if (!interaction) {
            OWSFailDebug(@"%@ could not reload interaction", self.logTag);
        } else {
            [viewItem replaceInteraction:interaction transaction:transaction];
        }
    }];
}

- (nullable ConversationViewItem *)viewItemForIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)self.viewItems.count) {
        OWSFailDebug(@"%@ Invalid view item index: %zd", self.logTag, index);
        return nil;
    }
    return self.viewItems[(NSUInteger)index];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return (NSInteger)self.viewItems.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:indexPath.item];
    ConversationViewCell *cell = [viewItem dequeueCellForCollectionView:self.collectionView indexPath:indexPath];
    if (!cell) {
        OWSFailDebug(@"%@ Could not dequeue cell.", self.logTag);
        return cell;
    }
    cell.viewItem = viewItem;
    cell.delegate = self;
    if ([cell isKindOfClass:[OWSMessageCell class]]) {
        OWSMessageCell *messageCell = (OWSMessageCell *)cell;
        messageCell.messageBubbleView.delegate = self;
        messageCell.multiSelectMode = self.isMultiSelectMode;
        messageCell.isCellSelected = [self viewItemWasSelected:viewItem];
    }
    cell.conversationStyle = self.conversationStyle;
    
    [self.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        [cell loadForDisplayWithTransaction:transaction];
    }];
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
       willDisplayCell:(UICollectionViewCell *)cell
    forItemAtIndexPath:(NSIndexPath *)indexPath
{
    OWSAssertDebug([cell isKindOfClass:[ConversationViewCell class]]);
    
    ConversationViewCell *conversationViewCell = (ConversationViewCell *)cell;
    conversationViewCell.isCellVisible = YES;
}

- (void)collectionView:(UICollectionView *)collectionView
  didEndDisplayingCell:(nonnull UICollectionViewCell *)cell
    forItemAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    OWSAssertDebug([cell isKindOfClass:[ConversationViewCell class]]);
    
    ConversationViewCell *conversationViewCell = (ConversationViewCell *)cell;
    conversationViewCell.isCellVisible = NO;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!self.isMultiSelectMode) {
        return;
    }
    [collectionView deselectItemAtIndexPath:indexPath animated:NO];
    ConversationViewItem *_Nullable viewItem = [self viewItemForIndex:indexPath.item];
    BOOL isSelected = [self viewItemWasSelected:viewItem];
    NSUInteger messageMaxSelectCount = 50;
    if (self.forwardMessageItems.count == messageMaxSelectCount && !isSelected) {
        NSString *tips = [NSString stringWithFormat:NSLocalizedString(@"FORWARD_MESSAGE_SELECT_MESSAGE_MAX_COUNT", @""), messageMaxSelectCount];
        [DTToastHelper toastWithText:tips inView:self.view durationTime:1];
        return;
    }
    
    //MARK: 多选转发附件消息上限
    /*
     if ([self numberOfAttachmentItemInMultiSelect] >= 3) {
     [DTToastHelper toastWithText:@"附件消息不能超过3个" inView:self.view durationTime:1];
     return;
     }
     */
    
    if (viewItem.messageCellType == OWSMessageCellType_DownloadingAttachment) {
        [DTToastHelper toastWithText:NSLocalizedString(@"FORWARD_MESSAGE_ATTACHMENT_NOT_DOWNLOADED", @"attachment is not downloaded") inView:self.view durationTime:1];
        return;
    }
    //    转发个人名片支持选择
    //    viewItem.messageCellType == OWSMessageCellType_ContactShare
    if (viewItem.messageCellType == OWSMessageCellType_Audio || viewItem.messageCellType == OWSMessageCellType_Task || viewItem.messageCellType == OWSMessageCellType_Vote) {
        [DTToastHelper toastWithText:NSLocalizedString(@"FORWARD_MESSAGE_FORBIDDEN_REMINDER", @"attachment unsupported") inView:self.view durationTime:1];
        return;
    }
    
    if (!isSelected) {
        [self.forwardMessageItems addObject:viewItem];
    } else {
        ConversationViewItem *viewItemSaved = [self hasSameViewItemInMultiSelect:viewItem];
        [self.forwardMessageItems removeObject:viewItemSaved];
    }
    [self.forwardToolbar updateActionItemsSelectedCount:self.forwardMessageItems.count];
    [collectionView reloadItemsAtIndexPaths:@[indexPath]];
}

#pragma mark - ContactsPickerDelegate

- (void)contactsPickerDidCancel:(ContactsPicker *)contactsPicker
{
    DDLogDebug(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker contactFetchDidFail:(NSError *)error
{
    DDLogDebug(@"%@ in %s with error %@", self.logTag, __PRETTY_FUNCTION__, error);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker didSelectContact:(Contact *)contact
{
    OWSAssertDebug(contact);
    
    CNContact *_Nullable cnContact = [self.contactsManager cnContactWithId:contact.cnContactId];
    if (!cnContact) {
        OWSFailDebug(@"%@ Could not load system contact.", self.logTag);
        return;
    }
    
    DDLogDebug(@"%@ in %s with contact: %@", self.logTag, __PRETTY_FUNCTION__, contact);
    
    OWSContact *_Nullable contactShareRecord = [OWSContacts contactForSystemContact:cnContact];
    if (!contactShareRecord) {
        OWSFailDebug(@"%@ Could not convert system contact.", self.logTag);
        return;
    }
    
    BOOL isProfileAvatar = NO;
    NSData *_Nullable avatarImageData = [self.contactsManager avatarDataForCNContactId:cnContact.identifier];
    for (NSString *recipientId in contact.textSecureIdentifiers) {
        if (avatarImageData) {
            break;
        }
        avatarImageData = [self.contactsManager profileImageDataForPhoneIdentifier:recipientId];
        if (avatarImageData) {
            isProfileAvatar = YES;
        }
    }
    contactShareRecord.isProfileAvatar = isProfileAvatar;
    
    ContactShareViewModel *contactShare =
    [[ContactShareViewModel alloc] initWithContactShareRecord:contactShareRecord avatarImageData:avatarImageData];
    
    // TODO: We should probably show this in the same navigation view controller.
    ContactShareApprovalViewController *approveContactShare =
    [[ContactShareApprovalViewController alloc] initWithContactShare:contactShare
                                                     contactsManager:self.contactsManager
                                                            delegate:self];
    OWSAssertDebug(contactsPicker.navigationController);
    [contactsPicker.navigationController pushViewController:approveContactShare animated:YES];
}

- (void)contactsPicker:(ContactsPicker *)contactsPicker didSelectMultipleContacts:(NSArray<Contact *> *)contacts
{
    OWSFailDebug(@"%@ in %s with contacts: %@", self.logTag, __PRETTY_FUNCTION__, contacts);
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)contactsPicker:(ContactsPicker *)contactsPicker shouldSelectContact:(Contact *)contact
{
    // Any reason to preclude contacts?
    return YES;
}

#pragma mark - ContactShareApprovalViewControllerDelegate

- (void)approveContactShare:(ContactShareApprovalViewController *)approveContactShare
     didApproveContactShare:(ContactShareViewModel *)contactShare
{
    OWSLogInfo(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    
    [self dismissViewControllerAnimated:YES
                             completion:^{
        [self sendContactShare:contactShare];
    }];
}

- (void)approveContactShare:(ContactShareApprovalViewController *)approveContactShare
      didCancelContactShare:(ContactShareViewModel *)contactShare
{
    OWSLogInfo(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ContactShareViewHelperDelegate

- (void)didCreateOrEditContact
{
    OWSLogInfo(@"%@ in %s", self.logTag, __PRETTY_FUNCTION__);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -

- (void)presentViewController:(UIViewController *)viewController
                     animated:(BOOL)animated
                   completion:(void (^__nullable)(void))completion
{
    // Ensure that we are first responder before presenting other views.
    // This ensures that the input toolbar will be restored after the
    // presented view is dismissed.
    if (![self isFirstResponder]) {
        [self becomeFirstResponder];
    }
    
    [super presentViewController:viewController animated:animated completion:completion];
}

#pragma mark - new group

/*
 - (void)checkAndUpgradeToANewGroup{
 
 TSGroupThread *groupThread = (TSGroupThread *)self.thread;
 
 if(!self.thread.isGroupThread ||
 !groupThread.groupModel.groupId){
 return;
 }
 
 if(![groupThread.groupModel.groupMemberIds containsObject:[TSAccountManager localNumber]]){
 return;
 }
 
 if(groupThread.groupTransitionStatus != TSGroupTransitionStatusOld){
 
 if(!groupThread.groupModel.groupOwner.length){
 [self getGroupInfo:groupThread];
 }
 
 return;
 }
 
 NSString *groupName = groupThread.name;
 groupName = groupName.length ? groupName : NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
 NSArray *members = groupThread.groupModel.groupMemberIds;
 NSString *serverGId = [groupThread convertToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
 if(!serverGId.length){
 return;
 }
 [SVProgressHUD show];
 [self.upgradeToANewGroupAPI sendRequestWithGroupId:serverGId
 name:groupName
 avatar:@""
 numbers:members
 success:^(DTUpgradeToANewGroupDataEntity * _Nonnull entity) {
 [SVProgressHUD dismiss];
 if(groupThread.groupModel.groupId.length == 32){
 groupThread.groupTransitionStatus = TSGroupTransitionStatusNew;
 }else{
 groupThread.groupTransitionStatus = TSGroupTransitionStatusOldToNew;
 }
 groupThread.groupModel.groupOwner = self.contactsViewHelper.localNumber;
 [OWSPrimaryStorage.sharedManager.newDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
 [groupThread saveWithTransaction:transaction];
 }];
 } failure:^(NSError * _Nonnull error) {
 [SVProgressHUD dismiss];
 if(error.code == DTAPIRequestResponseStatusGroupExists){
 if(groupThread.groupModel.groupId.length == 32){
 groupThread.groupTransitionStatus = TSGroupTransitionStatusNew;
 }else{
 groupThread.groupTransitionStatus = TSGroupTransitionStatusOldToNew;
 }
 [OWSPrimaryStorage.sharedManager.newDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
 [groupThread saveWithTransaction:transaction];
 }];
 [self getGroupInfo:groupThread];
 }else{
 [SVProgressHUD showErrorWithStatus:error.localizedDescription];
 }
 }];
 }
 
 - (void)getGroupInfo:(TSGroupThread *)groupThread{
 NSString *serverGId = [groupThread convertToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
 if(!serverGId.length) return;
 [SVProgressHUD show];
 [self.getGroupInfoAPI sendRequestWithGroupId:serverGId
 success:^(DTGetGroupInfoDataEntity * _Nonnull entity) {
 [SVProgressHUD dismiss];
 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.role = 0"];
 NSArray *results = [entity.members filteredArrayUsingPredicate:predicate];
 if(results.count){
 DTGroupMemberEntity *member = results.firstObject;
 groupThread.groupModel.groupOwner = member.uid;
 }
 
 NSMutableArray *numbers = @[].mutableCopy;
 [entity.members enumerateObjectsUsingBlock:^(DTGroupMemberEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
 if(obj.uid.length){
 [numbers addObject:obj.uid];
 }
 }];
 NSSet *currentNumbers = [NSSet setWithArray:groupThread.groupModel.groupMemberIds];
 NSSet *newNumbers = [NSSet setWithArray:numbers];
 if(![currentNumbers isEqualToSet:newNumbers]){
 groupThread.groupModel.groupMemberIds = numbers.copy;
 }
 [OWSPrimaryStorage.sharedManager.newDatabaseConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction * _Nonnull transaction) {
 [groupThread saveWithTransaction:transaction];
 }];
 
 
 //        if(![currentNumbers isEqualToSet:newNumbers]){
 //            TSGroupModel *newGroupModel = [[TSGroupModel alloc] initWithTitle:groupThread.groupModel.groupName
 //                                                                 memberIds:numbers
 //                                                                     image:groupThread.groupModel.groupImage
 //                                                                      groupId:groupThread.groupModel.groupId
 //                                                                   groupOwner:groupThread.groupModel.groupOwner
 //                                                                   groupAdmin:nil];
 //            [self updateGroupModelTo:newGroupModel successCompletion:nil];
 //        }
 
 } failure:^(NSError * _Nonnull error) {
 [SVProgressHUD dismiss];
 }];
 }
 */


- (void)getGroupInfo:(TSGroupThread *)groupThread{
    
    NSString *serverGId = self.serverGroupId;
    if(!DTParamsUtils.validateString(serverGId)){
        return;
    }
    
    BOOL needSkipUpdateGroupInfo = [self.conversationTagInfo[serverGId] boolValue];
    if(needSkipUpdateGroupInfo && ![TSAccountManager sharedInstance].isChangeGlobalNotificationType){
        return;
    }
    self.conversationTagInfo[serverGId] = @(YES);
    if(!serverGId.length) return;
    
    [self.getGroupInfoAPI sendRequestWithGroupId:serverGId
                                         success:^(DTGetGroupInfoDataEntity * _Nonnull entity) {
        
        [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
            [self.groupUpdateMessageProcessor generateOrUpdateConverationWithGroupId:groupThread.groupModel.groupId
                                                                        needGMessage:NO
                                                                            envelope:nil
                                                                           groupInfo:entity
                                                                         transaction:transaction.transitional_yapWriteTransaction];
        }];
        
    } failure:^(NSError * _Nonnull error) {
        if(error.code == DTAPIRequestResponseStatusNoSuchGroup ||
           error.code == DTAPIRequestResponseStatusNoPermission){
            NSMutableArray *memberIds = groupThread.groupModel.groupMemberIds.mutableCopy;
            if([memberIds containsObject:[TSAccountManager localNumber]]){
                [memberIds removeObject:[TSAccountManager localNumber]];
                [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
                    groupThread.groupModel.groupMemberIds = memberIds.mutableCopy;
                    [groupThread saveWithTransaction:transaction.transitional_yapWriteTransaction];
                }];
            }
        }
    }];
    
    //MARK: 打开app首次拉取pinned message
    [[DTPinnedDataSource shared] syncPinnedMessageWithServer:self.serverGroupId];
}

- (NSMutableArray<ConversationViewItem *> *)forwardMessageItems {
    if (!_forwardMessageItems) {
        _forwardMessageItems = [NSMutableArray new];
    }
    return _forwardMessageItems;
}

- (DTTranslateApi *)translateApi {
    if (!_translateApi) {
        _translateApi = [DTTranslateApi new];
    }
    return _translateApi;
}

- (DTVoteNowApi *)voteNowApi {
    if (!_voteNowApi) {
        _voteNowApi = [DTVoteNowApi new];
    }
    return _voteNowApi;
}

- (DTThreadHeadView *)threadHeadView {
    if (!_threadHeadView) {
        _threadHeadView = [DTThreadHeadView new];
    }
    return _threadHeadView;
}

- (NSMutableArray *)unReplyMessageArr {
    if (!_unReplyMessageArr) {
        _unReplyMessageArr = [NSMutableArray array];
    }
    return _unReplyMessageArr;
}

- (NSString *)serverGroupId {
    
    if (!self.thread.isGroupThread) {
        return nil;
    }
    
    TSGroupThread *groupThread = (TSGroupThread *)self.thread;
    return [TSGroupThread transformToServerGroupIdWithLocalGroupId:groupThread.groupModel.groupId];
}

- (DTUpdateUnreplyProcessor*)unreplyProcessor {
    if (!_unreplyProcessor) {
        _unreplyProcessor = [DTUpdateUnreplyProcessor new];
    }
    return _unreplyProcessor;
}

@end

NS_ASSUME_NONNULL_END

