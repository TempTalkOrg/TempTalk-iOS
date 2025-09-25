//
//  YapDatabaseDefines.h
//  Pods
//
//  Created by Kris.s on 2022/10/24.
//

#ifndef YapDatabaseDefines_h
#define YapDatabaseDefines_h

typedef NS_ENUM(NSUInteger, DTTaskFilteringType) {
    DTTaskFilteringTypeOngoing,
    DTTaskFilteringTypeReceived,
    DTTaskFilteringTypeCreated,
    DTTaskFilteringTypeCompleted,
    DTTaskFilteringTypeUnread = 100
};

typedef NS_ENUM(NSUInteger, DTTaskSortingType) {
    DTTaskSortingTypeCreateTime,
    DTTaskSortingTypeDueTime,
    DTTaskSortingTypePriority
};

typedef NS_ENUM(NSUInteger, DTThreadInteractionsFilteringType) {
    DTThreadInteractionsFilteringTypeMain =0,
    DTThreadInteractionsFilteringTypeThread,
    DTThreadInteractionsFilteringTypeThreadUnreply,//用于筛选thread中没有进行回复的信息
    DTThreadInteractionsFilteringTypeAllThreadMessage,//用于筛选所有的Thread消息
};

typedef NS_ENUM(NSUInteger, DTThreadGroupType) {
    DTThreadGroupTypeInbox,
    DTThreadGroupTypeVirtualForMeeting,
    DTThreadGroupTypeArchived
};

static NSString *const TSTaskBaseDatabaseViewExtensionName = @"TSTaskBaseDatabaseViewExtensionName";
static NSString *const TSTaskFilteredDatabaseViewExtensionName = @"TSTaskFilteredDatabaseViewExtensionName";
static NSString *const TSTaskGroupNameNormal = @"TSTaskGroupNameNormal";


#endif /* YapDatabaseDefines_h */
