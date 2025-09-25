//
//  DTGroupMeetingDetailsModel.h
//  Signal
//
//  Created by Ethan on 2022/8/18.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupMeetingDetailsModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *account;
@property (nonatomic, copy) NSString *event;
@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, readonly) NSAttributedString *logsDescription;
@property (nonatomic, readonly) NSString *userName;
@property (nonatomic, readonly) NSString *userEmail;
@property (nonatomic, readonly) NSString *logsTime;

@end

NS_ASSUME_NONNULL_END
