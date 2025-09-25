//
//  DTContactsNotifyEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/10/25.
//

#import "Contact.h"
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DTContactNotifyAction) {
    DTContactNotifyActionAdd,
    DTContactNotifyActionUpdate,
    //删除好友关系
    DTContactNotifyActionDelete,
    //三个月不活跃删除账号、用户删除账号
    DTContactNotifyActionPermanentDelete
};


@interface DTContactActionEntity : Contact<MTLJSONSerializing>

@property (nonatomic, assign) DTContactNotifyAction action;
@property (nonatomic, assign) NSInteger directoryVersion;

@end

@interface DTContactsNotifyEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger directoryVersion;
@property (nonatomic, strong) NSArray<DTContactActionEntity *> *members;

@end

NS_ASSUME_NONNULL_END
