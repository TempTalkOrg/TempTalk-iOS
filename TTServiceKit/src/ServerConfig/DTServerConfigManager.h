//
//  DTServerConfigManager.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import <Foundation/Foundation.h>

@class SDSAnyReadTransaction;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kServerConfigUpdatedNotify;

@interface DTServerConfigManager : NSObject


/// 初始化DTServerConfigManager单例对象
+ (instancetype)sharedManager;

- (void)fetchConfigFromLocalWithSpaceName:(NSString *)spaceName
                               completion:(void (^)(id _Nullable config, NSError * _Nullable error))completion;

- (void)fetchConfigFromLocalWithSpaceName:(NSString *)spaceName
                              transaction:(SDSAnyReadTransaction *)transaction
                               completion:(void (^)(id _Nullable config, NSError * _Nullable error))completion;

/// 获取 server 配置信息
/// - Parameter completion: completion
- (void)fetchServersConfigCompletion:(void (^)(id _Nullable, NSError * _Nullable))completion;

- (void)updateConfig;
- (void)fetchConfigFromServerCompletion:(void(^ _Nullable)(void))completion;

@end

NS_ASSUME_NONNULL_END
