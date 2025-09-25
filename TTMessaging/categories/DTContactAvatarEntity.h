//
//  DTContactAvatarEntity.h
//  TTMessaging
//
//  Created by Kris.s on 2021/11/9.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTContactAvatarEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *attachmentId;
@property (nonatomic, copy) NSString *encAlgo;
@property (nonatomic, copy) NSString *encKey;

@end

NS_ASSUME_NONNULL_END
