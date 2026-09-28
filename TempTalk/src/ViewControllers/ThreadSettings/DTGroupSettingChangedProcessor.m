//
//  DTGroupSettingChangedProcessor.m
//  Signal
//
//  Created by Kris.s on 2023/2/16.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTGroupSettingChangedProcessor.h"
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/DTUpdateGroupInfoAPI.h>
#import <TTServiceKit/TTServiceKit-swift.h>
#import <SignalCoreKit/Threading.h>

@interface DTGroupSettingChangedProcessor ()

@property (nonatomic, strong) DTUpdateGroupInfoAPI *updateGroupInfoAPI;

@end

@implementation DTGroupSettingChangedProcessor

- (DTUpdateGroupInfoAPI *)updateGroupInfoAPI {
    if (!_updateGroupInfoAPI) {
        _updateGroupInfoAPI = [DTUpdateGroupInfoAPI new];
    }
    return _updateGroupInfoAPI;
}

- (instancetype)initWithGroupThread:(TSGroupThread *)groupThread {
    if(self = [super init]){
        self.groupThread = groupThread;
    }
    return self;
}

- (void)changeGroupSettingWithPropertyName:(NSString *)propertyName
                                    value:(NSNumber *)value
                                  success:(void(^)(SDSAnyWriteTransaction *writeTransaction))success
                                  failure:(void(^)(void))failure {
    [self changeGroupSettingWithPropertyName:propertyName
                                       value:value
                  successWithServerTimestamp:^(SDSAnyWriteTransaction *writeTransaction, uint64_t serverTimestamp) {
        success(writeTransaction);
    }
                                     failure:failure];
}

- (void)changeGroupSettingWithPropertyName:(NSString *)propertyName
                                     value:(NSNumber *)value
                successWithServerTimestamp:(void(^)(SDSAnyWriteTransaction *writeTransaction,
                                                     uint64_t serverTimestamp))success
                                   failure:(void(^)(void))failure {
    
    if(![self.groupThread.groupModel respondsToSelector:NSSelectorFromString(propertyName)] ||
       !DTParamsUtils.validateString(propertyName) ||
       !DTParamsUtils.validateNumber(value)){
        failure();
        return;
    };
    NSDictionary *parms = @{propertyName:value};
    [self.updateGroupInfoAPI sendUpdateGroupWithGroupId:self.groupThread.serverThreadId updateInfo:parms success:^(DTAPIMetaEntity * _Nonnull entity) {
        DispatchMainThreadSafe(^{
            DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                [self.groupThread anyUpdateGroupThreadWithTransaction:writeTransaction
                                                                block:^(TSGroupThread * instance) {
                    [instance.groupModel setValue:value forKey:propertyName];
                }];
                success(writeTransaction, entity.serverTimestamp.unsignedLongLongValue);
            });
        });
    } failure:^(NSError * _Nonnull error) {
        DispatchMainThreadSafe(^{
            failure();
        });
    }];
    
}

@end
