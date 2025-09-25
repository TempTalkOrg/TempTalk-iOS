//
//  DTCallMangerMacro.h
//  TTServiceKit
//
//  Created by hornet on 2023/3/14.
//

#ifndef DTCallMangerMacro_h
#define DTCallMangerMacro_h

///TSInfoMessageType 类型只能追加，不能中间插入否则老版本不兼容
typedef NS_ENUM(NSInteger, TSGroupMeetingVersionType) {
    TSGroupMeetingVersionTypeV1 = 1,
    TSGroupMeetingVersionTypeV2,
    TSGroupMeetingVersionTypeV3,//这个版本开始支持群组会议加密
};

typedef NS_ENUM(NSInteger, TSPrivateMeetingVersionType) {
    TSPrivateMeetingVersionTypeV1 = 1,
    TSPrivateMeetingVersionTypeV2,
    TSPrivateMeetingVersionTypeV3,
};

#endif /* DTCallMangerMacro_h */
