//
//  DTMultiMeetingView.h
//  Signal
//
//  Created by Ethan on 2022/7/29.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DTMultiMeetingMiniCell;
@class DTMultiChatItemModel;
@class DTMultiMeetingView;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DTMultiMeetingMode) {
    ///大头像，可以显示用户视频
    DTMultiMeetingModeDefault = 0,
    ///小头像，列表样式
    DTMultiMeetingModeMini
};

typedef NS_ENUM(NSInteger, DTMeetingMemberAction) {
    DTMeetingMemberActionCreate = 0,
    DTMeetingMemberActionUpdate,
    DTMeetingMemberActionJoin,
    DTMeetingMemberActionLeave
};

@protocol DTMeetingViewDelegate <NSObject>

@optional
- (void)meetingView:(DTMultiMeetingView *)meetingView didSelectUserViewAtItemModel:(DTMultiChatItemModel *)itemModel;

- (void)meetingView:(DTMultiMeetingView *)meetingView didSelectItemAtItemModel:(DTMultiChatItemModel *)itemModel;

- (void)meetingViewWillBeginDragging:(DTMultiMeetingView *)meetingView;

- (void)meetingViewDidEndDragging:(DTMultiMeetingView *)meetingView;

@end

@interface DTMultiMeetingView : UIView

- (instancetype)initWithMode:(DTMultiMeetingMode)mode
                isLiveStream:(BOOL)isLiveStream;

@property (nonatomic, weak) id<DTMeetingViewDelegate> meetingViewDelegate;
@property (nonatomic, copy) void(^tapBackgroundHandler)(void);
@property (nonatomic, assign) BOOL isHandupExpanded;

/// 更新聊天列表
/// @param broadcasters 主播(会议host和attendee)
/// @param audiences 观众(guest, 仅live stream)
- (void)updateWithBroadcasters:(NSArray<DTMultiChatItemModel *> *)broadcasters
               handupAudiences:(nullable NSArray<DTMultiChatItemModel *> *)handupAudiences;

- (void)udpateCollectionContents;
@end

NS_ASSUME_NONNULL_END
