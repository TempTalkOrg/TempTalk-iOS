//
//  DTFileAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/11.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTFileDataEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) BOOL exists;
@property (nonatomic, copy) NSString *attachmentId;
@property (nonatomic, copy) NSString *authorizeId;
@property (nonatomic, assign) UInt64 authorizeIdToInt;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, copy) NSString *fileHash;
@property (nonatomic, assign) long long fileSize;
@property (nonatomic, copy) NSString *hashAlg;
@property (nonatomic, copy) NSString *keyAlg;
@property (nonatomic, copy) NSString *encAlg;
@property (nonatomic, copy) NSString *cipherHash;
@property (nonatomic, copy) NSString *cipherHashType;

@end

@interface DTFileAPI : DTBaseAPI

- (void)sendRequestWithParams:(NSDictionary *)params
                      success:(void (^)(DTFileDataEntity * entity))success
                      failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
