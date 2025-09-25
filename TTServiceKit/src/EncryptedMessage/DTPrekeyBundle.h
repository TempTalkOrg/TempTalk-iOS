//
//  DTPrekeyBundle.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTPrekeyBundle : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy, nullable) NSString *uid;

@property (nonatomic, copy, nullable) NSString *identityKey;

@property (nonatomic, assign) NSInteger registrationId;

@property (nonatomic, assign) NSInteger resetIdentityKeyTime;

- (NSData *)identityKeyData;

@end

NS_ASSUME_NONNULL_END
