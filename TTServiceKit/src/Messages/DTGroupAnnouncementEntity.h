//
//  DTGroupAnnouncementEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupAnnouncementEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *aId;
@property (nonatomic, assign) NSTimeInterval announcementExpiry;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) NSTimeInterval reviseTime;

@end

NS_ASSUME_NONNULL_END
