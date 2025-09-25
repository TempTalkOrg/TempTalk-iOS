//
//  DTCommonGroupContext.h
//  TempTalk
//
//  Created by Kris.s on 2024/12/18.
//  Copyright © 2024 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class GroupSearchResult;
@class TSContactThread;
@class OWSNavigationController;
@class TSGroupThread;
@class SDSAnyReadTransaction;

@interface DTCommonGroupContext : NSObject

@property (nonatomic, strong, readonly, nullable) NSArray <GroupSearchResult *> *inCommonGroups;
@property (nonatomic, strong, readonly, nullable) NSDictionary <NSString *, NSString *> *sortedGroupMembers;
@property (nonatomic, strong, readonly) TSContactThread *thread;
@property (nonatomic, copy, readonly) void (^completion)(void);

- (instancetype)initWithContactThread:(TSContactThread *)thread completion:(void(^)(void))completion;

- (void)fetchInCommonGroupsData;

- (void)showCommonViewWithNavigationController:(UINavigationController *)navigationController;

+ (NSArray <NSString *> *)sortedGroupMemberIdsWithGroup:(TSGroupThread *)groupThread transaction:(SDSAnyReadTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
