//
//  DTActiveStateConfigModel.h
//  Wea
//
//  Created by user on 2022/8/23.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTActiveStateConfigModel : NSObject

@property (nonatomic, strong) NSNumber *mintues;

@property (nonatomic, strong, readonly) NSString *displayTitle;

@end

NS_ASSUME_NONNULL_END
