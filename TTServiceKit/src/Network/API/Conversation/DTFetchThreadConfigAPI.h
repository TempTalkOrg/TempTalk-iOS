//
//  DTFetchThreadConfigAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/3/31.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTThreadConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) uint32_t sourceDeviceId;
@property (nonatomic, copy) NSString * conversation;
@property (nonatomic, assign) int ver;
@property (nonatomic, assign) int changeType;
@property (nonatomic, strong) NSNumber *messageExpiry;
@property (nonatomic, assign) uint64_t endTimestamp;
@property (nonatomic, assign) NSInteger askedVersion;
@property (nonatomic, assign) uint64_t messageClearAnchor;

@end

@interface DTFetchThreadConfigAPI : DTBaseAPI

- (void)fetchThreadConfigRequestWithNumber:(NSString *)number
                                   success:(void(^)(DTThreadConfigEntity * __nullable entity))success
                                   failure:(DTAPIFailureBlock)failure;

- (void)fetchThreadConfigRequestWithConversationIds:(NSArray<NSString *> *)conversationIds
                                            success:(void(^)(NSArray<DTThreadConfigEntity *> * __nullable entities))success
                                            failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
