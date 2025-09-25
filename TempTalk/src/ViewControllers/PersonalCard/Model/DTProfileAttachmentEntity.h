//
//  DTProfileAttachmentEntity.h
//  TTMessaging
//
//  Created by hornet on 2021/11/28.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTProfileAttachmentEntity : MTLModel<MTLJSONSerializing>
@property(nonatomic,assign) long id;
@property(nonatomic,copy) NSString *idString;
@property(nonatomic,copy) NSString *location;
@end

NS_ASSUME_NONNULL_END
