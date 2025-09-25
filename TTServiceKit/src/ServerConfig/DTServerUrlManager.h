//
//  DTServerUrlManager.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Foundation/Foundation.h>
#import "DTServerStatusEntity.h"
#import "TSConstants.h"
#import "DTServersConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTServerUrlManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, readonly) DTServersEntity *serversEntity;

- (void)startSpeedTestAll;
- (void)startSpeedTestWithServerType:(DTServToType)serverType;

//- (DTServerStatusEntity *)getTheBestServerUrlWithServerType:(DTServerType)serverType;

- (NSArray<NSString *> *)getTheServerUrlsWithServerType:(DTServToType)serverType;

- (void)markAsInvalidWithUrl:(NSString *)url serverType:(DTServToType)serverType;

- (void)resetAll;
- (void)resetWithServerType:(DTServToType)serverType;


@end

NS_ASSUME_NONNULL_END
