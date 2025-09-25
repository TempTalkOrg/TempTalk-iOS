//
//  DTServerStatusEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTServerStatusEntity : NSObject

@property (atomic, copy) NSString *url;
@property (atomic, assign) BOOL isAvailable;
@property (atomic, assign) NSTimeInterval timeConsuming;

@end

NS_ASSUME_NONNULL_END
