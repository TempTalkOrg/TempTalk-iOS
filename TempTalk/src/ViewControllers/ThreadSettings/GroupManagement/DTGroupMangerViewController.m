//
//  DTGroupMangerViewController.m
//  Wea
//
//  Created by hornet on 2021/12/31.
//

#import "DTGroupMangerViewController.h"
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSAccountManager.h>
#import <SignalCoreKit/Threading.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>

#import "DTAddToGroupItem.h"
#import "DTGroupMemberController.h"
#import "DTUpdateGroupInfoAPI.h"
#import "DTToastHelper.h"
#import "DTGroupUpdateInfoMessageHelper.h"
#import <TTServiceKit/TSInfoMessage.h>
#import "DTGroupSettingChangedProcessor.h"

CGFloat const kSelectedItemHeight = 40;
CGFloat const kItemNumber = 7;


extern NSString *const kDTAddToGroupItemIdentifier;
@interface DTGroupMangerViewController ()<UICollectionViewDataSource,UICollectionViewDelegate,DTGroupMemberControllerDelegate>
@property (nonatomic, strong) TSGroupThread *thread;
@property (nonatomic, strong) NSMutableArray *selectedIdsArr;
@property (nonatomic, strong) NSMutableArray *defaultIconArr;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSLayoutConstraint *collectionViewTopConstraint;
@property (nonatomic, strong) NSLayoutConstraint *collectionViewBottomConstraint;

@property (nonatomic, strong) DTGroupSettingChangedProcessor *groupSettingChangedProcessor;

@end

@implementation DTGroupMangerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setTitle:Localized(@"LIST_GROUP_MEMBERS_MANAGER", nil)];
   
    [self updateTableContents];
    if (self.selectedIdsArr.count > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)self.selectedIdsArr.count - 1 inSection:0];
        if (indexPath) {
            [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionNone animated:false];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)configWithThread:(TSGroupThread *)thread {
    _thread = thread;

    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMemberIds);
    if (self.thread.groupModel.groupAdmin.count >= 0) {
        NSMutableArray *tmpArr = [self.thread.groupModel.groupAdmin mutableCopy];
        if (!tmpArr) {
            tmpArr = [NSMutableArray array];
        }
        [tmpArr addObjectsFromArray:self.defaultIconArr];
        self.selectedIdsArr = tmpArr;
        [self addOwerId];
    }
    if (self.selectedIdsArr.count > kItemNumber) {//只取后8个元素进行展示
        [self.selectedIdsArr removeObjectsInRange:NSMakeRange(0, (NSUInteger)self.selectedIdsArr.count - (NSUInteger) kItemNumber)];
    }
    
}

- (void)removeOwerid {
    if ([self.selectedIdsArr containsObject:self.thread.groupModel.groupOwner]) {
        [self.selectedIdsArr removeObject:self.thread.groupModel.groupOwner];
    }
}

- (void)addOwerId {
    if (![self.selectedIdsArr containsObject:self.thread.groupModel.groupOwner]) {
        [self.selectedIdsArr insertObject:self.thread.groupModel.groupOwner atIndex:0];
    }
}

#pragma mark colectionViewDelegate
//collectionView的代理方法及数据源方法
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

//每个section的item个数
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
   return (NSInteger)self.selectedIdsArr.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [NSString stringWithFormat:@"%@%ld%ld",kDTAddToGroupItemIdentifier,indexPath.row,indexPath.section];
    //在cellForItem方法中注册cell（多个分区）
    [collectionView registerClass:[DTAddToGroupItem class] forCellWithReuseIdentifier:identifier];
    DTAddToGroupItem *item = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    if (indexPath.row <= (NSInteger)self.selectedIdsArr.count -1) {//最后一个元素 即删除
        if (indexPath.row == (NSInteger)self.selectedIdsArr.count -1) {
            if (self.selectedIdsArr.count == 3) {//表示只有群主自己
                [item configWithImage: nil];
                item.hidden = true;
            }else {
                [item configWithImage: self.selectedIdsArr[(NSUInteger)indexPath.row]];
                item.hidden = false;
            }
            
        }else if (indexPath.row == (NSInteger)self.selectedIdsArr.count -2){//倒数第二个元素 即添加
            [item configWithImage: self.selectedIdsArr[(NSUInteger)indexPath.row]];
            item.hidden = false;
        }else {
            [item configWithReceptId:[self.selectedIdsArr objectAtIndex:(NSUInteger)indexPath.row]];
            item.hidden = false;
        }
    }
    return item;
}
//设置每个item的尺寸
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(kSelectedItemHeight,kSelectedItemHeight);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

//设置每个item垂直间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

//设置每个item水平间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 5;
}
//设置item选中的状态
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return true;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == (NSInteger)self.selectedIdsArr.count -1) {//最后一个元素。delete
        if (self.selectedIdsArr.count == 3) {
            return;
        }
        DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
        groupMemberVC.selectedType = DTGroupMemberSelectedType_MultipleChoice;//单选
        groupMemberVC.controllerType = DTGroupMemberSelectedType_DeleteAdminPeople;
        groupMemberVC.memberControllerDelegate = self;
        [groupMemberVC configWithThread:self.thread];
        [self.navigationController pushViewController:groupMemberVC animated:true];
    }else if (indexPath.row == (NSInteger)self.selectedIdsArr.count -2) {//add
        DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
        groupMemberVC.selectedType = DTGroupMemberSelectedType_MultipleChoice;//单选
        groupMemberVC.controllerType = DTGroupMemberSelectedType_AddAdminPeople;//
        groupMemberVC.memberControllerDelegate = self;
        [groupMemberVC configWithThread:self.thread];
        [self.navigationController pushViewController:groupMemberVC animated:true];
    }else {
        DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
        groupMemberVC.selectedType = DTGroupMemberSelectedType_SingleChoice;//单选
        groupMemberVC.controllerType = DTGroupMemberSelectedType_ShowAdminPeople;
        [groupMemberVC configWithThread:self.thread];
        [self.navigationController pushViewController:groupMemberVC animated:true];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
}
#pragma mark DTGroupMemberControllerDelegate
- (void)memberIdsWasAdded:(NSArray *)recipientIds withType:(DTGroupMemberControllerType)type {
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        [self.thread anyReloadWithTransaction:readTransaction];
    }];
    
    switch (type) {
        case DTGroupMemberSelectedType_AddAdminPeople:{
//            [self.selectedIdsArr removeObjectsInArray:self.defaultIconArr];
            [self.selectedIdsArr removeAllObjects];
            for (NSString *receptid in self.thread.groupModel.groupAdmin) {
                 [self.selectedIdsArr addObject:receptid];
            }
            [self.selectedIdsArr addObjectsFromArray:self.defaultIconArr];
            [self addOwerId];
            if (self.selectedIdsArr.count > kItemNumber) {
                [self.selectedIdsArr removeObjectsInRange:NSMakeRange(0, (NSUInteger)self.selectedIdsArr.count - (NSUInteger)kItemNumber)];
            }
           
            DispatchMainThreadSafe(^{
                [self updateTableContents];
//                [self dealCollectionViewState];
                [self.collectionView reloadData];
            });
        }   break;
        case DTGroupMemberSelectedType_DeleteAdminPeople:{
            [self.selectedIdsArr removeAllObjects];
            for (NSString *receptid in self.thread.groupModel.groupAdmin) {
                [self.selectedIdsArr addObject:receptid];
            }
            [self.selectedIdsArr addObjectsFromArray:self.defaultIconArr];
            [self addOwerId];
            if (self.selectedIdsArr.count > kItemNumber) {
                [self.selectedIdsArr removeObjectsInRange:NSMakeRange(0, (NSUInteger)self.selectedIdsArr.count - (NSUInteger)kItemNumber)];
            }
            DispatchMainThreadSafe(^{
                [self updateTableContents];
                [self.collectionView reloadData];
            });

        }   break;
        default:
            break;
    }
}

- (void)groupOwerWasChangedWithType:(DTGroupMemberControllerType)type {
    // 更新thread
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        [self.thread anyReloadWithTransaction:readTransaction];
    }];
        
    [self.selectedIdsArr removeObjectsInArray:self.defaultIconArr];
    NSString *localNumber = [TSAccountManager sharedInstance].localNumber;
    // NSMutableArray *groupAdminArr = self.thread.groupModel.groupAdmin.mutableCopy;
    for (NSString *receptid in self.thread.groupModel.groupAdmin) {//groupAdmin中包含localNumber
        if (![self.selectedIdsArr containsObject:localNumber] && [receptid isEqualToString:localNumber]) {
            [self.selectedIdsArr addObject:localNumber];
        }
    }
    [self.selectedIdsArr addObjectsFromArray:self.defaultIconArr];
    if (self.selectedIdsArr.count >kItemNumber) {
        [self.selectedIdsArr removeObjectsInRange:NSMakeRange(0, (NSUInteger)self.selectedIdsArr.count - (NSUInteger)kItemNumber)];
    }else {
        if (self.selectedIdsArr.count < kItemNumber ) {
            for (NSString *receptid in self.thread.groupModel.groupAdmin.reverseObjectEnumerator) {
                if (![self.selectedIdsArr containsObject:receptid] && self.selectedIdsArr.count < kItemNumber) {
                    [self.selectedIdsArr insertObject:receptid atIndex:0];
                }
            }
        }else {//=8不处理
            
        }
    }
    [self updateTableContents];
   
    DispatchMainThreadSafe(^{
        [self.collectionView reloadData];
    });
}

- (void)dealCollectionViewState {
    if (self.selectedIdsArr.count <= 2) {
        self.collectionView.hidden = true;
        self.collectionViewTopConstraint.constant = 0;
        self.collectionViewBottomConstraint.constant = 0;
        [self.collectionView autoSetDimension:ALDimensionHeight toSize:0];

    }else {
        self.collectionView.hidden = false;
        self.collectionViewTopConstraint.constant = 10;
        self.collectionViewBottomConstraint.constant = -10;
        [self.collectionView autoSetDimension:ALDimensionHeight toSize:kSelectedItemHeight];

    }
}

#pragma mark delegate
- (UITableViewCell *)getGroupMembersCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.backgroundColor = Theme.tableCellBackgroundColor;
    cell.contentView.backgroundColor = Theme.tableCellBackgroundColor;
    
    UIStackView *columnStackView = [UIStackView new];
    columnStackView.axis = UILayoutConstraintAxisVertical;
    columnStackView.alignment = UIStackViewAlignmentCenter;
    columnStackView.distribution = UIStackViewDistributionFill;
    [cell.contentView addSubview:columnStackView];
    [columnStackView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [columnStackView autoPinEdgeToSuperviewMargin:ALEdgeRight];
    [columnStackView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:cell.contentView];
    [columnStackView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:cell.contentView];
    
    UIStackView *topRowStackView = [UIStackView new];
    topRowStackView.axis = UILayoutConstraintAxisHorizontal;
    topRowStackView.alignment = UIStackViewAlignmentCenter;
    topRowStackView.distribution = UIStackViewDistributionEqualCentering;
    [columnStackView addArrangedSubview:topRowStackView];
    [topRowStackView autoSetDimension:ALDimensionHeight toSize:45.0];
    [topRowStackView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:columnStackView];
    [topRowStackView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:columnStackView];
    [topRowStackView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:columnStackView];
    
    UILabel *titleLabel = [UILabel new];
    titleLabel.font = [UIFont ows_regularFontWithSize:18.f];
    titleLabel.textColor = Theme.primaryTextColor;
    titleLabel.text = Localized(@"LIST_GROUP_MEMBERS_ADMIN",@"");
//    [cell.contentView addSubview:titleLabel];
    [topRowStackView addArrangedSubview:titleLabel];
    [titleLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:topRowStackView];
    [titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:topRowStackView];
//    [titleLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:cell.contentView withOffset:-10];
    
//    self.thread.groupModel.groupAdmin
    
    
    UILabel *numberLabel = [UILabel new];
    numberLabel.font = titleLabel.font = [UIFont ows_regularFontWithSize:18.f];
    numberLabel.textColor = Theme.secondaryTextAndIconColor;
    numberLabel.textAlignment = NSTextAlignmentRight;
    [topRowStackView addArrangedSubview:numberLabel];
    
    NSArray *groupMember = self.thread.groupModel.groupMemberIds;
    NSArray *groupAdmin = self.thread.groupModel.groupAdmin;
    if (groupAdmin.count > 0 && groupMember.count >= 2) {
        numberLabel.text = [NSString stringWithFormat:@"%ld",groupAdmin.count + 1];
    }else {
        numberLabel.text = @"";
    }
    
    [numberLabel autoAlignAxis:ALAxisHorizontal toSameAxisOfView:titleLabel];
    [numberLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:titleLabel withOffset:10];
    [numberLabel autoSetDimension:ALDimensionWidth toSize:50];
    
    UIImageView *navIconImageView = [[UIImageView alloc] init];
    navIconImageView.image = [[UIImage imageNamed:@"cell_nav_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [topRowStackView addArrangedSubview:navIconImageView];
    
    navIconImageView.tintColor = [UIColor colorWithRgbHex:0x58585B];
    [navIconImageView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:numberLabel];
    [navIconImageView autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:numberLabel withOffset:5];
    [navIconImageView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:topRowStackView withOffset:0];
    
    [navIconImageView autoSetDimension:ALDimensionWidth toSize:7];
    [navIconImageView autoSetDimension:ALDimensionHeight toSize:11.6];
    [numberLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:navIconImageView withOffset:-10];
    
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0,0, 0, 0) collectionViewLayout:layout];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.showsHorizontalScrollIndicator=NO;
    [_collectionView registerClass:[DTAddToGroupItem class] forCellWithReuseIdentifier:kDTAddToGroupItemIdentifier];
    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.bounces = NO;
    
    [cell.contentView addSubview:_collectionView];
    self.collectionViewTopConstraint = [self.collectionView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:topRowStackView withOffset:10];
    self.collectionViewBottomConstraint = [self.collectionView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:columnStackView withOffset:-10];
    [self.collectionView autoSetDimension:ALDimensionHeight toSize:kSelectedItemHeight];
    [self.collectionView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [self.collectionView autoPinEdgeToSuperviewMargin:ALEdgeRight];
    
    [self dealCollectionViewState];
    return cell;
}


- (void)updateTableContents {
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *groupSection = [OWSTableSection new];
    @weakify(self)
    [groupSection addItem: [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self getGroupMembersCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:^{
        @strongify(self)
        if (self.selectedIdsArr.count>2) {
            DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
            groupMemberVC.selectedType = DTGroupMemberSelectedType_SingleChoice;//单选
            groupMemberVC.controllerType = DTGroupMemberSelectedType_ShowAdminPeople;
            [groupMemberVC configWithThread:self.thread];
            [self.navigationController pushViewController:groupMemberVC animated:true];
        }else {
            DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
            groupMemberVC.selectedType = DTGroupMemberSelectedType_MultipleChoice;//单选
            groupMemberVC.controllerType = DTGroupMemberSelectedType_AddAdminPeople;//
            groupMemberVC.memberControllerDelegate = self;
            [groupMemberVC configWithThread:self.thread];
            [self.navigationController pushViewController:groupMemberVC animated:true];
        }
    }]];
    
    if ([[TSAccountManager sharedInstance].localNumber isEqualToString:self.thread.groupModel.groupOwner]) {
        [groupSection addItem:[OWSTableItem itemCustomAccessoryWithText:Localized(@"LIST_GROUP_MEMBERS_TRANSFER",@"") actionBlock:^{
            @strongify(self)
            DTGroupMemberController *groupMemberVC = [DTGroupMemberController new];
            groupMemberVC.selectedType = DTGroupMemberSelectedType_SingleChoice;//单选
            groupMemberVC.controllerType = DTGroupMemberSelectedType_TransferOwer;
            groupMemberVC.memberControllerDelegate = self;
            [groupMemberVC configWithThread:self.thread];
            [self.navigationController pushViewController:groupMemberVC animated:true];
        }]];
    }
    
    [groupSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self)
        BOOL isOn = self.thread.groupModel.invitationRule.integerValue == 1 || self.thread.groupModel.invitationRule.integerValue == 0;
        UITableViewCell *cell = [self cellWithName:Localized(@"LIST_GROUP_INVITE_RULE", @"table cell label in conversation settings")
                                        isSwitchOn:isOn
                                      switchAction:@selector(invitationRuleDidChange:)];
        
        return cell;
    } actionBlock:nil]];

    [groupSection addItem:[OWSTableItem itemWithCustomCellBlock:^{
        @strongify(self)
        UITableViewCell *cell = [self cellWithName:Localized(@"LIST_GROUP_PUBLISH_GROUP", @"table cell label in conversation settings")
                                        isSwitchOn:[self.thread.groupModel.publishRule intValue] == 1
                                      switchAction:@selector(publishRuleDidChange:)];
        
        return cell;
    } actionBlock:nil]];
    
    [contents addSection:groupSection];
    
    
    
    self.contents = contents;
}
    
- (void)invitationRuleDidChange:(UISwitch *)switchView {
    
    if(!self.thread.isGroupThread) return;
    
    NSNumber *invitationRule = switchView.isOn ? @(1) : @(2);
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"invitationRule"
                                                                    value:invitationRule
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
        [self updateTableContents];
    } failure:^{
        [DTToastHelper hide];
        switchView.on = !switchView.isOn;
    }];
}

- (void)removeMemberRuleDidChange:(UISwitch *)sender {
    
    if(!self.thread.isGroupThread) return;
    
    BOOL anyoneRemove = sender.isOn;
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"anyoneRemove"
                                                                    value:@(anyoneRemove)
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
        [self updateTableContents];
    } failure:^{
        [DTToastHelper hide];
        sender.on = !sender.isOn;;
    }];
}

- (void)rejoinRuleDidChange:(UISwitch *)sender {
    
    if(!self.thread.isGroupThread) return;
    
    BOOL rejoin = sender.isOn;
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"rejoin"
                                                                    value:@(rejoin)
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
        [self updateTableContents];
    } failure:^{
        [DTToastHelper hide];
        sender.on = !sender.isOn;;
    }];
            
}

- (void)publishRuleDidChange:(UISwitch *)sender {
    
    if(!self.thread.isGroupThread) return;
    
    BOOL isModeratorsCanSpeak = sender.isOn;
    NSNumber * publish_rule = isModeratorsCanSpeak ? @1 : @2;
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"publishRule"
                                                                    value:publish_rule
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
        TSInfoMessage *groupUpdateInfoMessage = [DTGroupUpdateInfoMessageHelper groupUpdatePublishRuleInfoMessage:publish_rule timestamp:[NSDate ows_millisecondTimeStamp] serverTimestamp:[NSDate ows_millisecondTimeStamp]  inThread:self.thread];
        [groupUpdateInfoMessage anyInsertWithTransaction:writeTransaction];
        [self updateTableContents];
    } failure:^{
        [DTToastHelper hide];
        sender.on = !sender.isOn;;
    }];
    
}

- (void)anyoneChangeNameChanged:(UISwitch *)sender {
    
    if(!self.thread.isGroupThread) return;
    
    BOOL anyoneChangeName = sender.isOn;
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"anyoneChangeName"
                                                                    value:@(anyoneChangeName)
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
    } failure:^{
        [DTToastHelper hide];
        sender.on = !sender.isOn;;
    }];
    
}

- (void)anyoneChangeAutoClearChanged:(UISwitch *)sender {
    
    if(!self.thread.isGroupThread) return;
    
    BOOL anyoneChangeAutoClear = sender.isOn;
    
    [DTToastHelper showHudInView:self.view];
    
    [self.groupSettingChangedProcessor changeGroupSettingWithPropertyName:@"anyoneChangeAutoClear"
                                                                    value:@(anyoneChangeAutoClear)
                                                                  success:^(SDSAnyWriteTransaction *writeTransaction){
        [DTToastHelper hide];
    } failure:^{
        [DTToastHelper hide];
        sender.on = !sender.isOn;;
    }];
}

- (NSMutableArray *)selectedIdsArr {
    if (!_selectedIdsArr) {
        _selectedIdsArr = @[].mutableCopy;
    }
    return _selectedIdsArr;
}

- (NSMutableArray *)defaultIconArr {
    if (!_defaultIconArr) {
        _defaultIconArr = @[@"add_icon",@"delete_icon"].mutableCopy;
    }
    return _defaultIconArr;
}
    
- (DTGroupSettingChangedProcessor *)groupSettingChangedProcessor{
    if(!_groupSettingChangedProcessor){
        _groupSettingChangedProcessor = [[DTGroupSettingChangedProcessor alloc] initWithGroupThread:(TSGroupThread *)self.thread];
    }
    return _groupSettingChangedProcessor;
}

- (void)btnTipsAtion:(id)sender {
    
    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil message:Localized(@"GROUP_COMMEN_REJOIN_CONFLICT_TIPS", @"")];
    actionSheet.messageAlignment = ActionSheetContentAlignmentLeading;
    [actionSheet addAction:[OWSActionSheets cancelAction]];
    
    [self presentActionSheet:actionSheet];
}

@end
