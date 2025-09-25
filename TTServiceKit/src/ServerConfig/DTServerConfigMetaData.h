//
//  DTServerConfigMetaData.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTServerConfigMetaData : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger code;
@property (nonatomic, strong) NSDictionary *data;

@end

NS_ASSUME_NONNULL_END
