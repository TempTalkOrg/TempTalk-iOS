//
//  DTGroupsViewController.m
//  Signal
//
//  Created by Kris.s on 2021/9/28.
//

#import "DTGroupsViewController.h"
#import "ConversationItemMacro.h"
#import "ContactCellView.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/DTGroupUtils.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSConstants.h>
#import <TTServiceKit/DTGroupBaseInfoEntity.h>
#import <TTServiceKit/DTToastHelper.h>
#import "TempTalk-Swift.h"

@interface DTGroupsViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSArray <DTGroupBaseInfoEntity *> *groups;
@property (nonatomic, copy) void(^scrollCallback)(UIScrollView *scrollView);

@end

@implementation DTGroupsViewController

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = Theme.backgroundColor;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.estimatedRowHeight = 0;
        _tableView.rowHeight = 70;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        if (@available(iOS 15.0, *)) {
            _tableView.sectionHeaderTopPadding = 0;
        }
        [_tableView registerClass:[ContactTableViewCell class] forCellReuseIdentifier:[ContactTableViewCell reuseIdentifier]];
        UIRefreshControl *pullToRefreshView = [UIRefreshControl new];
        pullToRefreshView.tintColor = [UIColor grayColor];
        [pullToRefreshView addTarget:self
                              action:@selector(pullToRefreshPerformed:)
                    forControlEvents:UIControlEventValueChanged];
        _tableView.refreshControl = pullToRefreshView;
    }
    
    return _tableView;
}

- (void)loadView {
    [super loadView];
    
    [self.view addSubview:self.tableView];
    [self.tableView autoPinEdgesToSuperviewSafeArea];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    @weakify(self)
    [[NSNotificationCenter defaultCenter] addObserverForName:TSGroupThreadAvatarChangedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @strongify(self)
        [self fetchData];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:DTGroupBaseInfoChangedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        @strongify(self)
        NSDictionary <NSString *, NSNumber *> *userInfo = note.userInfo;
        BOOL isRemove = userInfo.allKeys.firstObject.boolValue;
        DTGroupBaseInfoEntity *targetInfo = (DTGroupBaseInfoEntity *)userInfo.allValues.firstObject;
        NSMutableArray <DTGroupBaseInfoEntity *> *tmpGroups = [self.groups mutableCopy];
        if (!isRemove) {
            [tmpGroups addObject:targetInfo];
            self.groups = [tmpGroups sortedArrayUsingComparator:^NSComparisonResult(DTGroupBaseInfoEntity * _Nonnull obj1, DTGroupBaseInfoEntity * _Nonnull obj2) {
                return [obj1.name compare:obj2.name];
            }];

        } else {
            [self.groups enumerateObjectsUsingBlock:^(DTGroupBaseInfoEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([targetInfo.gid isEqualToString:obj.gid]) {
                    [tmpGroups removeObjectAtIndex:idx];
                    *stop = YES;
                }
            }];
            self.groups = tmpGroups.copy;
        }
        [self.tableView reloadData];
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
    [super applyTheme];
    self.tableView.backgroundColor = Theme.backgroundColor;
    [self.tableView reloadData];
}

- (void)pullToRefreshPerformed:(UIRefreshControl *)refreshControl {
        
    [DTGroupUtils syncMyGroupsBaseInfoSuccess:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [refreshControl endRefreshing];
            [self fetchData];
        });
    } failure:^(NSError * _Nonnull error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [refreshControl endRefreshing];
            if (!error) { return; }
            [DTToastHelper showWithInfo:error.localizedDescription];
        });
    }];
}

- (void)fetchData {
    NSMutableArray <DTGroupBaseInfoEntity *> *groupBaseInfos = @[].mutableCopy;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        [DTGroupBaseInfoEntity anyEnumerateWithTransaction:transaction
                                                   batched:YES
                                                     block:^(DTGroupBaseInfoEntity * object, BOOL * stop) {
            if ([object isKindOfClass:DTGroupBaseInfoEntity.class]) {
                [groupBaseInfos addObject:object];
            }
        }];
    } completion:^{
        self.groups = [groupBaseInfos sortedArrayUsingComparator:^NSComparisonResult(DTGroupBaseInfoEntity * _Nonnull obj1, DTGroupBaseInfoEntity * _Nonnull obj2) {
            return [obj1.name compare:obj2.name];
        }];
        [self.tableView reloadData];
    }];
}

- (TSGroupThread *)groupThreadWithGId:(NSString *)gId {

    NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:gId];

    if(!groupId.length) return nil;

    __block TSGroupThread *groupThread = nil;
    [self.databaseStorage uiReadWithBlock:^(SDSAnyReadTransaction * _Nonnull readTransaction) {
        groupThread = [TSGroupThread threadWithGroupId:groupId transaction:readTransaction];
    }];
    return groupThread;
}

- (TSGroupThread *)groupThreadWithBaseInfo:(DTGroupBaseInfoEntity *)baseInfo {
    
    NSData *groupId = [TSGroupThread transformToLocalGroupIdWithServerGroupId:baseInfo.gid];

    __block TSGroupThread *groupThread = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        groupThread = [TSGroupThread threadWithGroupId:groupId transaction:transaction];
    }];
    if (groupThread) return groupThread;
    
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        NSString *localNumber = [[TSAccountManager shared] localNumberWithTransaction:transaction];
        NSArray *memberIds = localNumber ? @[localNumber] : @[];
        TSGroupModel *groupModel = [[TSGroupModel alloc] initWithTitle:baseInfo.name
                                                             memberIds:memberIds
                                                                 image:nil
                                                               groupId:groupId
                                                            groupOwner:nil
                                                            groupAdmin:nil
                                                           transaction:transaction];
        groupModel.messageExpiry = baseInfo.messageExpiry;
        groupModel.invitationRule = baseInfo.invitationRule;
        groupModel.remindCycle = baseInfo.remindCycle && baseInfo.remindCycle.length > 0 ? baseInfo.remindCycle : @"none";
        groupModel.anyoneRemove = baseInfo.anyoneRemove;
        groupModel.rejoin = baseInfo.rejoin;
        groupModel.ext = baseInfo.ext;
        
        groupThread = [TSGroupThread getOrCreateThreadWithGroupModel:groupModel transaction:transaction];
    });
    
    return groupThread;
}

//MARK: UITableViewDelegate/UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.groups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[ContactTableViewCell reuseIdentifier] forIndexPath:indexPath];
    
    NSUInteger row = (NSUInteger)indexPath.row;
    if (row >= self.groups.count) return cell;
    
    DTGroupBaseInfoEntity *baseInfo = self.groups[row];
    TSGroupThread *groupThread = nil;
    if(!baseInfo.gid.length) return cell;
    groupThread = [self groupThreadWithGId:baseInfo.gid];
    
    SignalAccount *specialAccount = [[SignalAccount alloc] initWithRecipientId:@"GROUP_LIST"];
    specialAccount.contact = [[Contact alloc] initWithFullName:baseInfo.name ? baseInfo.name : @"group" phoneNumber:@"GROUP_LIST"];
    [cell configureWithSpecialAccount:specialAccount thread:groupThread];
    ContactCellView *cellView = cell.cellView;
    if([cellView isKindOfClass:[ContactCellView class]]){
        DTAvatarImageView *avatarView = [cellView valueForKey:@"avatarView"];
        if([avatarView isKindOfClass:[DTAvatarImageView class]]){
            if (groupThread && groupThread.groupModel.groupImage) {
                avatarView.image = groupThread.groupModel.groupImage;
            }
        }
    }
    
    return cell;
}
 
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 70;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSUInteger row = (NSUInteger)indexPath.row;
    OWSAssertDebug(row < self.groups.count);
    if (row >= self.groups.count) return;
    
    DTGroupBaseInfoEntity *baseInfo = self.groups[row];
    TSGroupThread *groupThread = [self groupThreadWithBaseInfo:baseInfo];
    
    ConversationViewController *conversationVC = [[ConversationViewController alloc] initWithThread:groupThread
                                                                                             action:ConversationViewActionNone
                                                                                     focusMessageId:nil
                                                                                        botViewItem:nil
                                                                                           viewMode:ConversationViewMode_Main];
    [self.navigationController pushViewController:conversationVC animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    scrollView.bounces = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    !self.scrollCallback ?: self.scrollCallback(scrollView);
}

- (void)listWillAppear {
    [self fetchData];
}

#pragma mark - JXPagingViewListViewDelegate
- (UIView *)listView {
    return self.view;
}

- (UIScrollView *)listScrollView {
    return self.tableView;
}

- (void)listViewDidScrollCallback:(void (^)(UIScrollView *))callback {
    self.scrollCallback = callback;
}

- (void)userTakeScreenshotEvent:(NSNotification *)notify {
}
@end
