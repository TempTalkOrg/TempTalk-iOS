//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class OWSContactsManager;
@class ThreadViewModel;
@class TSThread;
@class TSGroupThread;

typedef enum : NSUInteger {
    HomeViewCellStyleTypeNormal = 0,
    HomeViewCellStyleTypeSearchNormal,
    HomeViewCellStyleTypeSearchForConversations,
    HomeViewCellStyleTypeGroupInCommon,
} HomeViewCellStyle;

@protocol DTMeetingBarTapDelegate <NSObject>

- (void)didTapMeetingBarWithThread:(TSThread *)thread;

@end

@interface HomeViewCell : UITableViewCell

/// YES:首页会话列表 NO:搜索结果列表
@property (nonatomic, assign) BOOL isShowSticked;
/// 会话消息搜索专用，消息作者Id
@property (nonatomic, copy, nullable) NSString *messageAuthorId;

@property (nonatomic, weak) id <DTMeetingBarTapDelegate> meetingBarDelegate;
@property (nonatomic, readonly) ThreadViewModel *thread;
@property (nonatomic, readonly) UILabel *callDurationLabel;
@property (nonatomic, readonly) UIView *rightCallView;
@property (nonatomic, readonly) UILabel *dateTimeLabel;

@property (nonatomic, assign) BOOL shouldObserveMeeting;

+ (NSString *)cellReuseIdentifier;

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet;

- (void)configureWithThread:(ThreadViewModel *)thread
            contactsManager:(OWSContactsManager *)contactsManager
      blockedPhoneNumberSet:(NSSet<NSString *> *)blockedPhoneNumberSet
            overrideSnippet:(nullable NSAttributedString *)overrideSnippet
               overrideDate:(nullable NSDate *)overrideDate;

- (void)resetUIForSearch:(NSString *)searchText thread:(TSThread *)thread cellStyle:(HomeViewCellStyle)cellStyle;

- (void)configInCommonGroupWithThread:(TSGroupThread *)groupThread
                    sortedMemberNames:(NSString *)memberNames
                      contactsManager:(OWSContactsManager *)contactsManager;

- (void)showMeetingBar;

@end

NS_ASSUME_NONNULL_END
