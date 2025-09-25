//
//  DTMultiChatItemModel.h
//  Signal
//
//  Created by Felix on 2021/8/5.
//

#import <Foundation/Foundation.h>
#import <TTServiceKit/DTCallManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMultiChatItemModel : NSObject

/// 加入 channel 的 account，iOS 端前缀为 ios+id, Mac 端前缀为 mac+id
@property (nonatomic, copy) NSString* _Nullable account;
/// 加入 channel 的 account recipientId 电话号
@property (nonatomic, copy) NSString* _Nullable recipientId;
/// 加入 channel 的 account name
@property (nonatomic, copy) NSString* _Nullable displayName;
/// 第三方 SDK uid 
@property (nonatomic, assign) NSUInteger uid;

@property (nonatomic, assign, getter=isInChannel) BOOL inChannel;

// 是否在说话
@property (nonatomic, assign, getter=isSpeaking) BOOL speaking;
/// 是否当前屏幕分享人
@property (nonatomic, assign, getter=isSharing) BOOL sharing;
/// 是否当前主持人
@property (nonatomic, assign, getter=isHost) BOOL host;

@property (nonatomic, assign) NSUInteger volume;
// 是否开始音频外放
@property (nonatomic, assign, getter=isSpeakerphoneOut) BOOL speakerphoneOut;
// 是否静音
@property (nonatomic, assign, getter=isMute) BOOL mute;
@property (nonatomic, assign, getter=isVideoEnable) BOOL videoEnable;
// 是否成功切换了 摄像头，此字段只针对推流方在使用，默认为false, 使用这个字段区分用户是否点击切换摄像头导致remoteVideoStateChangedOfUid被回调
@property (nonatomic, assign) BOOL isSwithCamera;

@property (nonatomic, assign, getter=isFirstFrameDecoded) BOOL firstFrameDecoded;

//@property (nonatomic, strong, nullable) NSDate *date_Mute;

//@property (nonatomic, assign) BOOL isTurnOnCC;

@property (nonatomic, assign) LiveStreamRole role;

+ (instancetype)itemWithAccount:(NSString* _Nullable)account
                            uid:(NSUInteger)uid;

/// 重置状态
- (void)resetStatusForLeft;

- (void)combieFromItemModel:(DTMultiChatItemModel *)itemModel;

@end

NS_ASSUME_NONNULL_END
