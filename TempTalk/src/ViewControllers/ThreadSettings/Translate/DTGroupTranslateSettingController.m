//
//  DTGroupTranslateSettingController.m
//  Wea
//
//  Created by hornet on 2022/1/11.
//

#import "DTGroupTranslateSettingController.h"
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSContactThread.h>
#import "DTChangeYourSettingsInAGroupAPI.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/TSInfoMessage.h>
#import <TTServiceKit/DTGroupUtils.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>


@interface DTGroupTranslateSettingController ()
@property(nonatomic,strong) Contact *contact;
@property(nonatomic,strong) NSNumber* customGroupTranslateSetting;//自定义消息的值
@property(nonatomic,strong) TSThread *thread;
@property(nonatomic,assign) DTTranslateMessageType type;
@end

@implementation DTGroupTranslateSettingController

- (void)configureWithThread:(TSThread *)thread {
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        [thread anyReloadWithTransaction:readTransaction];
    }];
    
    self.thread = thread;
    self.type = [self.thread.translateSettingType intValue];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:Localized(@"SETTINGS_SECTION_TRANSLATE", nil)];
    if(self.thread.isGroupThread){
        
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self preapreUIData];
}

- (void)preapreUIData {
    [self updateTableContents];
}

#pragma mark - Table Contents
- (void)updateTableContents {
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *notitySection = [self getNotitySection];
    [contents addSection:notitySection];
    self.contents = contents;
}

- (OWSTableSection *)getNotitySection {
    OWSTableSection *translateSettingSection = [OWSTableSection new];
    @weakify(self)
    [translateSettingSection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_SECTION_TRANSLATE_LANGUAGE_OFF",@"") actionBlock:^{
        @strongify(self)
        [self changeTranslateSettingType:DTTranslateMessageTypeOriginal];
    } accessoryType:self.type == DTTranslateMessageTypeOriginal? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [translateSettingSection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_SECTION_TRANSLATE_LANGUAGE_CHINESE",@"") actionBlock:^{
        @strongify(self)
        [self changeTranslateSettingType:DTTranslateMessageTypeChinese];
    } accessoryType: self.type == DTTranslateMessageTypeChinese? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [translateSettingSection addItem:[OWSTableItem itemWithText:Localized(@"SETTINGS_SECTION_TRANSLATE_LANGUAGE_ENGLISH",@"") actionBlock:^{
        @strongify(self)
        [self changeTranslateSettingType:DTTranslateMessageTypeEnglish];
    } accessoryType:self.type == DTTranslateMessageTypeEnglish? UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone]];
    
    [translateSettingSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self custonTipCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:nil]];
    
    return translateSettingSection;
}

- (UITableViewCell *)custonTipCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.backgroundColor = Theme.tableCellBackgroundColor;
    
    UILabel *detailTextLabel = [UILabel new];
    detailTextLabel.font = [UIFont ows_regularFontWithSize:14.f];
    detailTextLabel.textColor = Theme.accentBlueColor;
    [cell.contentView addSubview:detailTextLabel];
    [detailTextLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:cell.contentView withOffset:0];
    [detailTextLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView withOffset:-10];
    [detailTextLabel autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [detailTextLabel autoPinEdgeToSuperviewMargin:ALEdgeRight];
    switch (self.type) {
        case DTTranslateMessageTypeEnglish:{
            detailTextLabel.text = Localized(@"TRANSLATE_SETTINGS_SELECTED_ENGLISH_LANGUAGE", @"");
        }
            break;
        case DTTranslateMessageTypeChinese:{
            detailTextLabel.text = Localized(@"TRANSLATE_SETTINGS_SELECTED_CHINISE_LANGUAGE", @"");
        }
            break;
        case DTTranslateMessageTypeOriginal:{
            detailTextLabel.text = Localized(@"TRANSLATE_SETTINGS_SELECTED_ORIGINAL", @"");
        }
            break;
        default:{
            detailTextLabel.text = Localized(@"TRANSLATE_SETTINGS_SELECTED_ORIGINAL", @"");
        }
            break;
    }
    detailTextLabel.numberOfLines = 0;

    return cell;
}

//改变语言
- (void)changeTranslateSettingType:(DTTranslateMessageType)type {
    self.type = type;
    [self updateTableContents];
    
    // TODO: refactor to async and add loading
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.thread anyUpdateWithTransaction:transaction
                                        block:^(TSThread * instance) {
            instance.translateSettingType = @(type);
        }];
        
        NSString * upinfo = [DTGroupUtils getTranslateSettingChangedInfoStringWithUserChangeType:self.type];
        if (upinfo && upinfo.length) {
            uint64_t now = [NSDate ows_millisecondTimeStamp];
            [[[TSInfoMessage alloc] initWithTimestamp:now
                                             inThread:self.thread
                                          messageType:TSInfoMessageTypeGroupUpdate
                                        customMessage:upinfo] anyInsertWithTransaction:transaction];
            
        }
    });
}

@end
