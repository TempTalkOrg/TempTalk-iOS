//
//  DTCommonGroupContext.m
//  TempTalk
//
//  Created by Kris.s on 2024/12/18.
//  Copyright © 2024 Difft. All rights reserved.
//

#import "DTCommonGroupContext.h"
#import "TempTalk-Swift.h"
#import "TSContactThread.h"

@interface DTCommonGroupContext ()

@property (nonatomic, strong, nullable) NSArray <GroupSearchResult *> *inCommonGroups;
@property (nonatomic, strong, nullable) NSDictionary <NSString *, NSString *> *sortedGroupMembers;
@property (nonatomic, strong) TSContactThread *thread;
@property (nonatomic, copy) void (^completion)(void);

@end

@implementation DTCommonGroupContext

- (instancetype)initWithContactThread:(TSContactThread *)thread completion:(nonnull void (^)(void))completion {
    if (self = [super init]) {
        self.thread = thread;
        self.completion = completion;
    }
    
    return self;
}

- (void)fetchInCommonGroupsData {
    
    if (self.thread.isGroupThread || self.thread.isNoteToSelf) return;
    
    @weakify(self)
    [GroupInCommonSeacher.shared loadInCommonGroups:self.thread.contactIdentifier closure:^(NSArray<GroupSearchResult *> * _Nonnull resultGroups) {
        @strongify(self)
        self.inCommonGroups = [resultGroups sortedArrayUsingComparator:^NSComparisonResult(GroupSearchResult * _Nonnull obj1, GroupSearchResult * _Nonnull obj2) {
            return [obj2.thread.lastMessageDate compare:obj1.thread.lastMessageDate];
        }];
        DispatchMainThreadSafe(^{
            self.completion();
        });
        
        NSMutableDictionary *sortedGroupMembers = [NSMutableDictionary dictionary];
        [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            [resultGroups enumerateObjectsUsingBlock:^(GroupSearchResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                
                NSArray <NSString *> *sortedMemberIds = [[self class] sortedGroupMemberIdsWithGroup:obj.thread transaction:transaction];
                NSMutableArray <NSString *> *memberNames = @[].mutableCopy;
                [sortedMemberIds enumerateObjectsUsingBlock:^(NSString * _Nonnull _obj, NSUInteger _idx, BOOL * _Nonnull _stop) {
                    if ([_obj isEqualToString:[self.tsAccountManager localNumberWithTransaction:transaction]]) {
                        return;
                    }
                    NSString *memberName = [Environment.shared.contactsManager displayNameForPhoneIdentifier:_obj transaction:transaction];
                    [memberNames addObject:memberName];

                    if (_idx > 8) *_stop = YES;
                }];
                NSString *memberNamesDesc = [memberNames componentsJoinedByString:@", "];
                [sortedGroupMembers addEntriesFromDictionary:@{obj.thread.serverThreadId : memberNamesDesc}];
            }];
        } completion:^{
            @strongify(self);
            self.sortedGroupMembers = sortedGroupMembers;
        }];
    }];
}

+ (NSArray <NSString *> *)sortedGroupMemberIdsWithGroup:(TSGroupThread *)groupThread transaction:(SDSAnyReadTransaction *)transaction {
   
    TSGroupModel *groupModel = groupThread.groupModel;
    
    return [groupModel.groupMemberIds sortedArrayUsingComparator:^NSComparisonResult(NSString * _Nonnull obj1, NSString * _Nonnull obj2) {
        if ([obj1 isEqualToString:groupModel.groupOwner] &&
            ![obj2 isEqualToString:groupModel.groupOwner]) {
            return NSOrderedAscending;
        }
        if (![obj1 isEqualToString:groupModel.groupOwner] &&
            [obj2 isEqualToString:groupModel.groupOwner]) {
            return NSOrderedDescending;
        }
        if ([groupModel.groupAdmin containsObject:obj1] &&
            ![groupModel.groupAdmin containsObject:obj2]) {
            return NSOrderedAscending;
        }
        if (![groupModel.groupAdmin containsObject:obj1] &&
            [groupModel.groupAdmin containsObject:obj2]) {
            return NSOrderedDescending;
        }
        
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        
        SignalAccount *account1 = [contactsManager signalAccountForRecipientId:obj1 transaction:transaction];
        SignalAccount *account2 = [contactsManager signalAccountForRecipientId:obj2 transaction:transaction];
        if ([groupModel.groupAdmin containsObject:obj1] &&
            [groupModel.groupAdmin containsObject:obj2]) {
            return [contactsManager compareSignalAccount:account1 withSignalAccount:account2];
        }
        
        return [contactsManager compareSignalAccount:account1 withSignalAccount:account2];
    }];
}

- (void)showCommonViewWithNavigationController:(UINavigationController *)navigationController {
    if (self.inCommonGroups.count == 0) return;
    DTGroupInCommonController *groupInCommonVC = [DTGroupInCommonController new];
    groupInCommonVC.shouldUseTheme = YES;
    groupInCommonVC.resultGroups = self.inCommonGroups;
    groupInCommonVC.sortedGroupMembers = self.sortedGroupMembers;
    groupInCommonVC.leaveGroupHandler = ^(NSArray<GroupSearchResult *> * _Nonnull newResultGroups) {
        self.inCommonGroups = newResultGroups;
        self.completion();
    };

    [navigationController pushViewController:groupInCommonVC animated:YES];
}

@end
