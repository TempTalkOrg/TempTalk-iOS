//
//  DTGroupSettingChangedProcessor.h
//  Signal
//
//  Created by Kris.s on 2023/2/16.
//  Copyright © 2023 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TSGroupThread;

@interface DTGroupSettingChangedProcessor : NSObject

@property (nonatomic, strong) TSGroupThread *groupThread;

- (instancetype)initWithGroupThread:(TSGroupThread *)groupThread;

- (void)changeGroupSettingWithPropertyName:(NSString *)propertyName
                                     value:(NSNumber *)value
                                   success:(void(^)(SDSAnyWriteTransaction *writeTransaction))success
                                   failure:(void(^)(void))failure;

@end

NS_ASSUME_NONNULL_END
