//
//  TSMessageMacro.h
//  TTServiceKit
//
//  Created by hornet on 2022/10/12.
//

#ifndef TSMessageMacro_h
#define TSMessageMacro_h

typedef NS_ENUM(SInt32, OWSDetailMessageType) {
    OWSDetailMessageTypeUnknow      = 0,
    OWSDetailMessageTypeForward     = 1,
    OWSDetailMessageTypeContact     = 2,
    OWSDetailMessageTypeRecall      = 3,
    OWSDetailMessageTypeTask        = 4,
    OWSDetailMessageTypeVote        = 5,
    OWSDetailMessageTypeReaction    = 6,
    OWSDetailMessageTypeCard        = 7,
    OWSDetailMessageTypeConfidential= 8,
    OWSDetailMessageTypeScreenshot  = 9,
    OWSDetailMessageTypeCardRefresh = 1000,
    OWSDetailMessageTypeMsgReject   = 1001,
    OWSDetailMessageTypeAllHangup   = 1002
};

typedef NS_ENUM(NSInteger, TSMessageModeType) {
    TSMessageModeTypeNormal            = 0,
    TSMessageModeTypeConfidential      = 1,
};

#endif /* TSMessageMacro_h */
