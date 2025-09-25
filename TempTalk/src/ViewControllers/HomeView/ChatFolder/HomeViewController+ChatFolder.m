//
//  HomeViewController+ChatFolder.m
//  Wea
//
//  Created by Ethan on 2022/4/14.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "HomeViewController+ChatFolder.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/DTThreadHelper.h>
#import <JXCategoryView/JXCategoryView.h>
#import <TTMessaging/Theme.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import <objc/runtime.h>
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "DTChatFolderManager.h"
#import "TempTalk-Swift.h"

static NSString *DTChatFolderBarKey = @"kChatFolderBarKey";

@interface HomeViewController()<JXCategoryTitleViewDataSource, JXCategoryViewDelegate, DTChatFolderManagerDelegate, DTThreadHelperDelegate>

@property (nonatomic, strong, nullable) NSArray <NSString *> *lastFolderKeys;
@property (nonatomic, assign) NSUInteger lastUnreadThreadCount;
@property (nonatomic, assign) NSUInteger versionTag;

@end

@implementation HomeViewController (ChatFolder)

- (void)setLastFolderKeys:(NSArray<NSString *> *)lastFolderKeys {
    objc_setAssociatedObject(self, @selector(lastFolderKeys), lastFolderKeys, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSString *> *)lastFolderKeys {
    return objc_getAssociatedObject(self, @selector(lastFolderKeys));
}

- (void)setLastUnreadThreadCount:(NSUInteger)lastUnreadThreadCount {
    objc_setAssociatedObject(self, @selector(lastUnreadThreadCount), @(lastUnreadThreadCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSUInteger)lastUnreadThreadCount {
    NSNumber *number = objc_getAssociatedObject(self, @selector(lastUnreadThreadCount)) ?: @(0);
    return [number unsignedIntegerValue];
}

- (void)setVersionTag:(NSUInteger)versionTag {
    objc_setAssociatedObject(self, @selector(versionTag), @(versionTag), OBJC_ASSOCIATION_COPY);
}

- (NSUInteger )versionTag {
    NSNumber *numberTag = objc_getAssociatedObject(self, @selector(versionTag)) ?: @0;
    return numberTag.unsignedIntegerValue;
}

- (NSArray<DTChatFolderEntity *> *)chatFolders {
    return [DTChatFolderManager sharedManager].chatFolders;
}

- (BOOL)isSelectedFolder {
    return self.currentFolder != nil;
}

- (BOOL)isSelectedRecommendFolder {
    return [[DTChatFolderManager recommendKeys] containsObject:self.currentFolder.name];
}

- (NSArray <NSString *> *)folderKeys {
    NSMutableArray *folderKeys = @[].mutableCopy;
    [self.chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [folderKeys addObject:obj.name];
    }];

    return folderKeys.copy;
}

- (BOOL)shouldShowFolderBar {
    
    return self.homeViewMode == HomeViewMode_Inbox && self.chatFolders.count > 0;
}

- (void)updateFiltering {
    
    OWSLogInfo(@"---updateFiltering---");
    
    if (!self.isSelectedFolder) {
        [self resetMappings];
        [DTThreadHelper sharedManager].folderThreadUniqueIds = nil;
        [self.allUnreadThreadArr removeAllObjects];
        return;
    }
    
    [self resetMappings];
    [self getCurrentFolderThreadUniqueIds];
     
}

- (void)removeFolderThread:(TSThread *)thread {
    
    NSMutableArray <DTChatFolderEntity *> *chatFolders = [[NSMutableArray alloc] initWithArray:[DTChatFolderManager sharedManager].chatFolders copyItems:YES];
    __block DTChatFolderEntity *targetFolder = nil;
    [chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:self.currentFolder.name]) {
            targetFolder = obj;
            *stop = YES;
        }
    }];
    
    NSString *serverThreadId = thread.serverThreadId;
    if (!targetFolder || !serverThreadId) {
        OWSLogError(@"target folder is not exist");
        return;
    }
    
    if ((targetFolder.cIds && targetFolder.cIds.count == 1) && !DTParamsUtils.validateString(targetFolder.conditions.keywords) && !DTParamsUtils.validateString(targetFolder.conditions.groupOwners)) {
        [SVProgressHUD showInfoWithStatus:Localized(@"CHAT_FOLDER_REMOVE_LAST_TIP", @"")];
        return;
    }
    
    __block BOOL isConditons = NO;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        isConditons = [self.currentFolder isConditonsContainThread:thread transaction:transaction];
    }];
    
    NSString *sheetMessage = nil;
    if (isConditons) {
        sheetMessage = Localized(@"CHAT_FOLDER_REMOVE_CONDITIONS_THREAD_TIPS", @"");
    } else {
        sheetMessage = Localized(@"CHAT_FOLDER_REMOVE_FROM_FOLDER_TIP", @"");
    }

    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil message:sheetMessage];
    
    [actionSheet addAction:[OWSActionSheets cancelAction]];
    
    @weakify(self)
    ActionSheetAction *sureAction = [[ActionSheetAction alloc] initWithTitle:Localized(@"TXT_CONFIRM_TITLE", @"") style:ActionSheetActionStyleDestructive handler:^(ActionSheetAction * _Nonnull action) {

        @strongify(self)
        if (isConditons) {
            DTCreateFolderController *editVC = [DTCreateFolderController new];
            editVC.shouldUseTheme = YES;
            editVC.mode = FolderEditModeEdit;
            editVC.currentIndex = self.currentFolderIndex;
//            DTAddConditionsController *keywordsVC = [DTAddConditionsController new];
//            keywordsVC.lastKeywords = targetFolder.conditions.keywords;
//            keywordsVC.saveKeywordsHandler = ^(NSString * _Nonnull keywords) {
//                @strongify(self)
//                DTFolderConditions *conditions = [DTFolderConditions new];
//                conditions.keywords = keywords;
//                targetFolder.conditions = conditions;
//                [self saveChatFoldersToServer:chatFolders];
//            };
            [self.navigationController pushViewController:editVC animated:YES];
            return;
        }
        NSMutableArray <DTFolderThreadEntity *> *threadEntities = targetFolder.cIds.mutableCopy;
        __block NSUInteger removeIdx = 0;
        [targetFolder.cIds enumerateObjectsUsingBlock:^(DTFolderThreadEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!obj.id) return;
            if ([obj.id isEqualToString:serverThreadId]) {
                removeIdx = idx;
                *stop = YES;
            }
        }];
        if (removeIdx < threadEntities.count) {
            [threadEntities removeObjectAtIndex:removeIdx];
        } else {
            OWSLogError(@"out of bound of array");
            return;
        }
        targetFolder.cIds = threadEntities.copy;
        [self saveChatFoldersToServer:chatFolders];
    }];
    [actionSheet addAction:sureAction];
    [self presentActionSheet:actionSheet];
}

- (NSInteger)currentFolderIndex {
    
    NSArray <DTChatFolderEntity *> *chatFolders = [DTChatFolderManager sharedManager].chatFolders;
    __block NSInteger targetIndex = 0;
    [chatFolders enumerateObjectsUsingBlock:^(DTChatFolderEntity * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([self.currentFolder.name isEqualToString:obj.name]) {
            targetIndex = (NSInteger)idx;
            *stop = YES;
        }
    }];
    
    return targetIndex;
}

- (void)saveChatFoldersToServer:(NSArray <DTChatFolderEntity *> *)chatFolders {
    [SVProgressHUD show];
    [DTChatFolderManager saveChatFolders:chatFolders success:^{
        [SVProgressHUD dismissWithDelay:0.5];
    } failure:^(NSError * _Nonnull error) {
        [SVProgressHUD showErrorWithStatus:Localized(@"CHAT_FOLDER_UPDATE_FAILED_TIP", @"")];
    }];
}


- (void)getCurrentFolderThreadUniqueIds {
    
    AnyThreadFinder *threadFinder = [AnyThreadFinder new];
    threadFinder.currentFolder = self.currentFolder;
    NSMutableArray <NSString *> *threadUniqueIds = @[].mutableCopy;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        NSError *error;
        [threadFinder enumerateVisibleThreadsWithIsArchived:NO transaction:transaction error:&error block:^(TSThread * _Nonnull thread) {
            
            if([thread isKindOfClass:[TSContactThread class]]){
                [threadUniqueIds addObject:thread.uniqueId];
            }else if ([thread isKindOfClass:[TSGroupThread class]]){
                if([DTChatFolderManager sharedManager].excludeVegaFromAll &&
                    [((TSGroupThread *)thread) businessFromVega]){
                    
                }else{
                    [threadUniqueIds addObject:thread.uniqueId];
                }
            }
            
        }];
        if (error) {
            OWSLogError(@"[chat folder] enumerate error %@", error.localizedDescription);
        }
    } completion:^{
        [DTThreadHelper sharedManager].folderThreadUniqueIds = threadUniqueIds;
        [self.allUnreadThreadArr removeAllObjects];
    }];
}

@end
