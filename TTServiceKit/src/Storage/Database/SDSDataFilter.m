//
//  SDSDataFilter.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/10/28.
//

#import "SDSDataFilter.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSThread.h"
#import "DTChatFolderManager.h"

@implementation SDSDataFilter

+ (BOOL)filterThread:(TSThread *)thread
         chartFolder:(nullable DTChatFolderEntity *)folder
         transaction:(SDSAnyReadTransaction *)transaction {
    if (!folder) {
        return YES;
    }
    
    //MARK: 推荐folder特殊处理
    if ([folder.name isEqualToString:kChatFolderPrivateKey]) {
        
        return [thread isKindOfClass:[TSContactThread class]];
    } else if ([folder.name isEqualToString:kChatFolderUnreadKey]) {
        
        return [thread unreadMessageCount] > 0 || (thread.isUnread && [thread.lastMessageDate ows_millisecondsSince1970] <= thread.unreadTimeStimeStamp);
    } else if ([folder.name isEqualToString:kChatFolderAtMeKey]) {
        
        NSString *localNumber = [[TSAccountManager sharedInstance] localNumberWithTransaction:transaction];
        if (!thread.isGroupThread || !localNumber) {
            return NO;
        }
        NSString *atPersons = [thread atPersonsWithTransaction:transaction];
        return [atPersons containsString:localNumber] || [atPersons containsString:@"MENTIONS_ALL"];
    } else if ([folder.name isEqualToString:kChatFolderVegaKey] && folder.folderType == DTFolderTypeRecommend) {
        if(thread.isGroupThread &&
           [((TSGroupThread *)thread) businessFromVega]){
            return YES;
        }
        return NO;
    }

    return [folder isManualContainThread:thread] || [folder isConditonsContainThread:thread transaction:transaction];
    
}

@end
