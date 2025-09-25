//
//  DTArchiveMessageSettingController.m
//  Signal
//
//  Created by hornet on 2022/7/26.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTArchiveMessageSettingController.h"
#import <TTServiceKit/TSConstants.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import "DTUpdateGroupInfoAPI.h"
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/DTGroupConfig.h>
#import <TTServiceKit/DTFetchThreadConfigAPI.h>
#import "OWSConversationSettingsViewDelegate.h"
#import "TempTalk-Swift.h"

extern NSString *const DTGroupMessageExpiryConfigChangedNotification;
extern NSString *const DTConversationSharingConfigurationChangeNotification;
extern const NSTimeInterval kDayInterval;

NSString *const kDefaultMessageExpiryKey = @"messageExpiry";

@interface DTArchiveMessageSettingController ()
@property (nonatomic, strong) NSDictionary *params;
@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;
@property (nonatomic, strong) DTUpdateConversationShareConfigApi *updateConversationShareConfigApi;
@property (nonatomic, strong) NSArray *messageArchivingTimeOptionValues;
@end

@implementation DTArchiveMessageSettingController

- (void)loadView {
    [super loadView];
    [self prepareUIData];
    [self updateTableContents];
}
- (void)prepareUIData {
    if([self.thread isGroupThread]){
        DTGroupConfigEntity *groupConfigEntity = [DTGroupConfig fetchGroupConfig];
        if (groupConfigEntity && groupConfigEntity.messageArchivingTimeOptionValues.count) {
            self.messageArchivingTimeOptionValues = [groupConfigEntity.messageArchivingTimeOptionValues copy];
        }
    } else {
        DTDisappearanceTimeIntervalEntity *timeIntervalEntity = [DTDisappearanceTimeIntervalConfig fetchDisappearanceTimeInterval];
        if (timeIntervalEntity && timeIntervalEntity.messageArchivingTimeOptionValues.count) {
            self.messageArchivingTimeOptionValues = [timeIntervalEntity.messageArchivingTimeOptionValues copy];
        }
    }
}

- (UITableViewCell *)baseCell {
    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"UITableViewCellStyleValue1"];
    cell.contentView.backgroundColor = Theme.backgroundColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    return cell;
}

- (UITableViewCell *)tipHeaderCell {
    UITableViewCell *cell = [self baseCell];

    UILabel *tipLabel = [UILabel new];
    tipLabel.numberOfLines = 0;
    tipLabel.text = Localized(@"YOU_UPDATED_DISAPPEARING_MESSAGES_TIP_MESSAGE", nil);
    tipLabel.textColor = Theme.thirdTextAndIconColor;
    tipLabel.font = [UIFont ows_regularFontWithSize:14.f];
    [cell.contentView addSubview:tipLabel];

    // ⭐️ 必须禁用 autoresizingMask，确保纯 Auto Layout
    tipLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [tipLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:12];
    [tipLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:16];
    [tipLabel autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:16];

    // 分割线
    UIView *lineView = [UIView new];
    lineView.backgroundColor = Theme.thirdTextAndIconColor;
    lineView.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:lineView];

    [lineView autoSetDimension:ALDimensionHeight toSize:1.0];
    [lineView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:16];
    [lineView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:16];
    [lineView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:tipLabel withOffset:12];

    [lineView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    return cell;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [OWSArchivedMessageJob sharedJob].inConversation = NO;
    self.title = Localized(@"CONVERSATION_SETTINGS_ARCHIVE", nil);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageExpiryConfigChanged:)
                                                 name:DTGroupMessageExpiryConfigChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageExpiryConfigChanged:)
                                                 name:DTConversationSharingConfigurationChangeNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [OWSArchivedMessageJob sharedJob].inConversation = YES;
}

- (void)messageExpiryConfigChanged:(NSNotification *)notify {
    self.params = @{};
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        TSThread *lastestThread = [TSThread anyFetchWithUniqueId:self.thread.uniqueId
                                                     transaction:transaction];
        self.durationSeconds = [lastestThread messageExpiresInSeconds];
    } completion:^{
        [self updateTableContents];
    }];
}

- (void)updateTableContents {
    NSNumber *requestDurationSeconds = [self.params objectForKey:kDefaultMessageExpiryKey];
    if (!requestDurationSeconds) {
        requestDurationSeconds = @(self.durationSeconds);
    }
    int requestDays = (int)([requestDurationSeconds integerValue] / kDayInterval);
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *tipSection = [OWSTableSection new];
    [tipSection addItem:[OWSTableItem
                         itemWithCustomCellBlock:^{
                             UITableViewCell * tipHeaderCell = [self tipHeaderCell];
                             return tipHeaderCell;
                         }
                         customRowHeight:UITableViewAutomaticDimension
                         actionBlock:nil]];
    [contents addSection:tipSection];
    OWSTableSection *archiveSection = [OWSTableSection new];
    for (NSNumber *configTimeInterval in self.messageArchivingTimeOptionValues) {
        int minuteNum = (int)([configTimeInterval integerValue]/kMinuteInterval);
        int hourNum = (int)([configTimeInterval integerValue]/kHourInterval);
        int dayNum = (int)([configTimeInterval integerValue]/kDayInterval);
        if(minuteNum > 0 && hourNum == 0){
            int requestMinutes = (int)([requestDurationSeconds integerValue] / kMinuteInterval);
            NSString *minute = nil;
            if (minuteNum > 1) {
                minute = [NSString stringWithFormat:@"%d%@", minuteNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_MINUTERS",@"")];
            } else {
                minute = [NSString stringWithFormat:@"%d%@", minuteNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_MINUTER",@"")];
            }
           
            @weakify(self)
            [archiveSection addItem:[OWSTableItem itemWithText:minute actionBlock:^{
               @strongify(self)
                [self changeCustomMesssageWithTimeInterval:[configTimeInterval integerValue]];
            } accessoryType: minuteNum == requestMinutes ? UITableViewCellAccessoryCheckmark :UITableViewCellAccessoryNone]];
        }else {
            if(dayNum == 0 && hourNum > 0){
                int requestHours = (int)([requestDurationSeconds integerValue] / kHourInterval);
                NSString *hours = nil;
                if (hourNum > 1) {
                    hours = [NSString stringWithFormat:@"%d%@", hourNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_HOURS",@"")];
                } else {
                    hours = [NSString stringWithFormat:@"%d%@", hourNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_HOUR",@"")];
                }
               
                @weakify(self)
                [archiveSection addItem:[OWSTableItem itemWithText:hours actionBlock:^{
                   @strongify(self)
                    [self changeCustomMesssageWithTimeInterval:[configTimeInterval integerValue]];
                } accessoryType: hourNum == requestHours ? UITableViewCellAccessoryCheckmark :UITableViewCellAccessoryNone]];
            } else {
                NSString *days = nil;
                if (dayNum > 1) {
                    days = [NSString stringWithFormat:@"%d%@", dayNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DAYS",@"")];
                } else {
                    days = [NSString stringWithFormat:@"%d%@", dayNum, Localized(@"CONVERSATION_SETTINGS_ARCHIVE_DAY",@"")];
                }
               
                @weakify(self)
                [archiveSection addItem:[OWSTableItem itemWithText:days actionBlock:^{
                   @strongify(self)
                    [self changeCustomMesssageWithTimeInterval:[configTimeInterval integerValue]];
                } accessoryType: dayNum == requestDays ? UITableViewCellAccessoryCheckmark :UITableViewCellAccessoryNone]];
            }
        }
    }
    [contents addSection:archiveSection];
    self.contents = contents;
}

- (void)changeCustomMesssageWithTimeInterval:(NSInteger)timeInterval {
    
    if(self.durationSeconds == timeInterval){
        return;
    }
    
    if (timeInterval > self.durationSeconds) {
        [self alertPopVCWithTitle:Localized(@"EXPIRE_EXTEND_TITLE", nil)
                      description:Localized(@"EXPIRE_EXTEND_DESCRIPTION", nil)
                          confirm:Localized(@"EXPIRE_EXTEND_CONFIRM", nil)
                           cancel:Localized(@"EXPIRE_EXTEND_CANCEL", nil)
                     timeInterval:timeInterval];
    } else {
        [self alertPopVCWithTitle:Localized(@"EXPIRE_SHORTEN_TITLE", nil)
                      description:Localized(@"EXPIRE_SHORTEN_DESCRIPTION", nil)
                          confirm:Localized(@"EXPIRE_SHORTEN_CONFIRM", nil)
                           cancel:Localized(@"EXPIRE_SHORTEN_CANCEL", nil)
                     timeInterval:timeInterval];
    }
}

- (void)alertPopVCWithTitle:(NSString *)title description:(NSString *)description confirm:(NSString *)confirm cancel:(NSString *)cancel timeInterval:(NSInteger)timeInterval {
    UIAlertController *controller =
        [UIAlertController alertControllerWithTitle:title
                                            message:description
                                     preferredStyle:UIAlertControllerStyleAlert];

    [controller addAction:[UIAlertAction actionWithTitle:confirm
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *_Nonnull action){
        if([self.thread isGroupThread]){
            [self configGroupThreadWithTimeInterval:timeInterval];
        } else {
            [self configContactThreadWithTimeInterval:timeInterval];
        }

                                                 }]];
    [controller addAction:[UIAlertAction actionWithTitle:cancel
                                                   style:UIAlertActionStyleCancel
                                                 handler:^(UIAlertAction *_Nonnull action){

                                                 }]];
    UIViewController *fromViewController = [[UIApplication sharedApplication] frontmostViewController];
    [fromViewController presentViewController:controller
                                     animated:YES
                                   completion:^{
                                   }];
}

- (void)configGroupThreadWithTimeInterval:(NSInteger)timeInterval {
    [DTToastHelper showHudInView:self.view];
    @weakify(self);
    [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:[self.thread serverThreadId] updateInfo:@{@"messageExpiry" : @(timeInterval)} success:^(DTAPIMetaEntity * _Nonnull entity) {
        @strongify(self);
        [DTToastHelper hide];
        self.durationSeconds = (uint32_t)timeInterval;
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [(TSGroupThread *)self.thread anyUpdateGroupThreadWithTransaction:transaction
                                                                        block:^(TSGroupThread * latestInstance) {
                if([latestInstance isKindOfClass:[TSGroupThread class]]){
                    latestInstance.groupModel.messageExpiry = @(self.durationSeconds);
                    
                    [self updateExpiTimeAndClearMessagesWithData:entity.data thread:latestInstance];
                }
            }];
            
            [transaction addAsyncCompletionOnMain:^{
                [self updateTableContents];
            }];
        });
    } failure:^(NSError * _Nonnull error) {
        [DTToastHelper hide];
        OWSLogInfo(@"change timeInterval fail & messageExpiry = %ld",(long)timeInterval);
    }];
}

- (void)configContactThreadWithTimeInterval:(NSInteger)timeInterval {
    [DTToastHelper showHudInView:self.view];
    OWSLogInfo(@"change timeInterval to %ld",(long)timeInterval);
    TSContactThread *contactThread = (TSContactThread *)self.thread;
    NSString *parmsString = [contactThread generateConversationId];
    @weakify(self)
    [self.updateConversationShareConfigApi updateConversationShareConfig:parmsString messageExpiry:@(timeInterval) sucess:^(DTAPIMetaEntity * _Nullable entity) {
        @strongify(self);
        [DTToastHelper hide];
        OWSLogInfo(@"contact changeCustomMesssageWithTimeInterval: sucess");
        self.durationSeconds = (uint32_t)timeInterval;
        NSDictionary *responseData = entity.data;
        NSError *error;
        DTThreadConfigEntity * sharingConfigurationEntity = [MTLJSONAdapter modelOfClass:[DTThreadConfigEntity class] fromJSONDictionary:responseData error:&error];
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [contactThread anyUpdateContactThreadWithTransaction:transaction
                                                           block:^(TSContactThread * latestInstance) {
                if([latestInstance isKindOfClass:[TSContactThread class]]){
                    DTThreadConfigEntity * threadConfig = [DTThreadConfigEntity new];
                    threadConfig.source = [TSAccountManager sharedInstance].localNumber;
                    threadConfig.sourceDeviceId = [OWSDevice currentDeviceId];
                    threadConfig.messageExpiry = sharingConfigurationEntity.messageExpiry;
                    threadConfig.changeType = 1;
                    threadConfig.ver = sharingConfigurationEntity.ver;
                    threadConfig.conversation = sharingConfigurationEntity.conversation;
                    latestInstance.threadConfig = threadConfig;
                    
                    [self updateExpiTimeAndClearMessagesWithData:entity.data thread:latestInstance];
                }
            }];
                        
            [transaction addAsyncCompletionOnMain:^{
                [self updateTableContents];
                // 之前个人页面会会退到消息页面
//                [self.conversationSettingsViewDelegate popAllConversationSettingsViews];
            }];
        } );
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        [DTToastHelper hide];
        OWSLogInfo(@"change timeInterval fail & messageExpiry = %ld",(long)timeInterval);
    }];
}

- (void)updateExpiTimeAndClearMessagesWithData:(NSDictionary *)data thread:(TSThread *)thread {
    // 修改就更新会话的字段
    UInt64 messageClearAnchor = [self uint64ValueFromDict:data key:@"messageClearAnchor"];
    UInt64 expiresInSeconds = [self uint64ValueFromDict:data key:@"messageExpiry"];

    [[DataUpdateUtil shared] updateConversationWithThread:thread
                                               expireTime:@(expiresInSeconds)
                                       messageClearAnchor:@(messageClearAnchor)];
}

- (UInt64)uint64ValueFromDict:(NSDictionary *)dict key:(NSString *)key {
    id value = dict[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return (UInt64)[value longLongValue];
    }
    return 0;
}

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI {
    if (!_updateGroupInfoAPI) {
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}

- (void)dealloc {
    OWSLogDebug(@"dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (DTUpdateConversationShareConfigApi *)updateConversationShareConfigApi {
    if (!_updateConversationShareConfigApi) {
        _updateConversationShareConfigApi = [DTUpdateConversationShareConfigApi new];
    }
    return _updateConversationShareConfigApi;
}
@end
