//
//  DTSendGroupMessageAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/18.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DTPrekeyBundle;

@interface DTExtraRecipientsEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong, nullable) NSArray<DTPrekeyBundle *> *missing;

@property (nonatomic, strong, nullable) NSArray<DTPrekeyBundle *> *extra;

@property (nonatomic, strong, nullable) NSArray<DTPrekeyBundle *> *stale;

@end

NS_ASSUME_NONNULL_END
