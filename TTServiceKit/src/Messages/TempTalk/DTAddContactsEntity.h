//
//  DTAddContactsEntity.h
//  TTServiceKit
//
//  Created by hornet on 2022/11/16.
//

#import <Mantle/Mantle.h>
#import "Contact.h"

typedef enum : NSUInteger {
    DTAddContactsActionTypeRequest = 1,//收到请求
    DTAddContactsActionTypeAccept,//接受请求
} DTAddContactsActionType;

NS_ASSUME_NONNULL_BEGIN

@interface DTOperatorEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) uint32_t sourceDeviceId;
@property (nonatomic, copy) NSString *sourceName;//用户id
@property (nonatomic, strong) ContactPublicConfigs *publicConfigs;
@property (nonatomic, strong) NSDictionary *avatar;
@end



///"notifyType": 6,
//"notifyTime": 1674069961605,
//"data": {
//    "operatorInfo": {
//        "operatorId": "+73635256642",
//        "operatorDeviceId": 1,
//        "operatorName": "huangfeng8912",
//        "publicConfigs": {
//            "publicName": "huangfeng8912",
//            "meetingVersion": 2
//        }
//    },
//    "askID": 550,
//    "actionType": 2,
//    "directoryVersion": 99
//}

@interface DTAddContactsEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, strong) DTOperatorEntity *operatorInfo;
@property (nonatomic, assign) uint64_t askID;
@property (nonatomic, assign) DTAddContactsActionType actionType;// 1: 申请加好友 ；2： 同意申请,
@property (nonatomic, assign) NSInteger directoryVersion;//通讯录版本号
@end

NS_ASSUME_NONNULL_END
