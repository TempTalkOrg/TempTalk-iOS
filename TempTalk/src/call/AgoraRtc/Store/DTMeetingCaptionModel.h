//
//  DTMeetingCaptionModel.h
//  Signal
//
//  Created by Ethan on 15/08/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMeetingCaptionModel : MTLModel<MTLJSONSerializing>
//        {"eventType":0,"eventId":"1956152668-5","agoraUid":1000175764,"agoraAccount":"","userName":"EthanTest","wuid":"+77073621954","text":"123","lang":"zh-CN","type":"caption","recognizedAtTimeMillis":1691771654962}

@property (nonatomic, copy) NSString *eventId;
/// 字幕文本
@property (nonatomic, copy) NSString *text;

/// 以下字段暂时用不到
/// meeting userAccount
@property (nonatomic, copy) NSString *agoraAccount;
/// agora uid
@property (nonatomic, assign) NSUInteger agoraUid;
/// 用户名
@property (nonatomic, copy) NSString *userName;
/// uid
@property (nonatomic, copy) NSString *wuid;
/// 选择字幕语言
@property (nonatomic, copy) NSString *lang;
/// 字幕生成时间
@property (nonatomic, assign) uint64_t recognizedAtTimeMillis;
@property (nonatomic, assign) NSInteger eventType;


@end

NS_ASSUME_NONNULL_END
