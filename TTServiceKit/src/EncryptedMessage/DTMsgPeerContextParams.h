//
//  DTMsgPeerContextParams.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMsgPeerContextParams : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *uid;

@property (nonatomic, assign) NSInteger registrationId;

@property (nonatomic, copy, nullable) NSString *peerContext;

- (instancetype)initWithDestination:(NSString *)destination
          destinationRegistrationId:(NSInteger)destinationRegistrationId
                        peerContext:(nullable NSString *)peerContext;

@end

NS_ASSUME_NONNULL_END
