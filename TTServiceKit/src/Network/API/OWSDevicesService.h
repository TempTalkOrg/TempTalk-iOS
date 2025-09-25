//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class OWSDevice;

@interface OWSDevicesService : NSObject

+ (void)getDevicesWithSuccess:(void (^)(NSArray<OWSDevice *> *))successCallback
                      failure:(void (^)(NSError *))failureCallback;

+ (void)unlinkDevice:(OWSDevice *)device
             success:(void (^)(void))successCallback
             failure:(void (^)(NSError *))failureCallback;

/// 检查账号是否被禁用/踢下线
/// - Parameter complete: complete
+ (void)checkIfKickedOffComplete:(void (^)(BOOL kickedOff))complete;

@end

NS_ASSUME_NONNULL_END
