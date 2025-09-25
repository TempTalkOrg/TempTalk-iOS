//
//  DTGroupPinAPI.h
//  TTServiceKit
//
//  Created by Ethan on 2022/3/17.
//

#import "DTBaseAPI.h"
#import "RESTNetworkManager.h"
@class DTPinnedMessageEntity;

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupPinAPI : DTBaseAPI


/// pinMessage
/// @param messageInfo envelpoe->base64
/// @param gid serverGroupId
/// @param source uid:DeviceId:timestamp
/// @param success succeww
/// @param failure failure
- (void)pinMessage:(NSString *)messageInfo
               gid:(NSString *)gid
    conversationId:(NSString *)source
        businessId:(nullable NSString *)businessId
           success:(RESTNetworkManagerSuccess)success
           failure:(RESTNetworkManagerFailure)failure;

- (void)unpinMessages:(NSArray <NSString *>*)pinnedMessageIds
                  gid:(NSString *)gid
              success:(DTAPISuccessBlock)success
              failure:(DTAPIFailureBlock)failure;

- (void)getPinnedMessagesWithGid:(NSString *)gid
                            page:(NSInteger)page
                            size:(NSInteger)size
                         success:(void(^)(NSArray <DTPinnedMessageEntity *>*pinnedMessageEntities))success
                         failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
