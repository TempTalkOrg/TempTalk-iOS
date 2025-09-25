//
//  DTCltlogAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/22.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, DTDroppedMessageType) {
    DTDroppedMessageTypeDeserialization,
    DTDroppedMessageTypeDecrypt,
};

@interface DTCltlogAPI : DTBaseAPI

- (void)sendRequestWithEventName:(NSString *)eventName
                          params:(NSDictionary *)params
                         success:(DTAPISuccessBlock)success
                         failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
