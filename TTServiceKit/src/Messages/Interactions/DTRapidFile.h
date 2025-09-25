//
//  DTRapidFile.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/29.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTRapidFile : MTLModel<MTLJSONSerializing>

// 原始文件 hash 值再次 hash
@property (nonatomic, copy) NSString *rapidHash;
@property (nonatomic, copy) NSString *authorizedId;

@end

NS_ASSUME_NONNULL_END
