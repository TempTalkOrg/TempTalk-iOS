//
//  DTScreenLockEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2024/8/30.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTScreenLockEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) BOOL requirePasscode;
@property (nonatomic, copy, nullable) NSString *passcodeSalt;
@property (nonatomic, strong, nullable) NSNumber *screenLockTimeout;

@property (nonatomic, strong, nullable) NSNumber *changeType;
@property (nonatomic, copy, nullable) NSString *passcode;

@end

NS_ASSUME_NONNULL_END
