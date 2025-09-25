//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface TSAttributes : NSObject

+ (NSDictionary *)attributesFromStorageWithManualMessageFetching:(BOOL)isEnabled
                                                             pin:(nullable NSString *)pin
                                                        passcode:(nullable NSString *)passcode;

+ (NSDictionary *)attributesWithSignalingKey:(NSString *)signalingKey
                             serverAuthToken:(NSString *)authToken
                       manualMessageFetching:(BOOL)isEnabled
                                         pin:(nullable NSString *)pin
                                    passcode:(nullable NSString *)passcode;

@end

NS_ASSUME_NONNULL_END
