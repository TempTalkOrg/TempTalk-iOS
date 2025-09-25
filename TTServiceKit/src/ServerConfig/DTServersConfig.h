//
//  DTServersConfig.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Foundation/Foundation.h>
#import "DTServersEntity.h"
#import "TSConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTServersConfig : NSObject

+ (DTServersEntity *)fetchServersConfig;

//+ (NSString *)convertToOriginUrlWithWebSocketUrl:(NSString *)webSocketUrl serverType:(DTServerType)serverType;
+ (NSString *)convertToWebSocketUrlWithOriginUrl:(NSString *)originUrl serverType:(DTServerType)serverType;

@end

NS_ASSUME_NONNULL_END
