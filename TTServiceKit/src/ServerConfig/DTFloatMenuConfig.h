//
//  DTFloatMenuConfig.h
//  TTServiceKit
//
//  Created by Jaymin on 2024/1/11.
//

#import <Foundation/Foundation.h>
#import "DTFloatMenuActionConfigEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTFloatMenuConfig : NSObject

+ (NSArray<DTFloatMenuActionConfigEntity *> *)fetchFloatMenuConfig;
+ (NSString *)fetchCoworkerAppid;
@end

NS_ASSUME_NONNULL_END
