//
//  DTRecallConfig.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/1.
//

#import <Foundation/Foundation.h>
#import "DTRecallConfigEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTRecallConfig : NSObject

+ (DTRecallConfigEntity *)fetchRecallConfig;

@end

NS_ASSUME_NONNULL_END
