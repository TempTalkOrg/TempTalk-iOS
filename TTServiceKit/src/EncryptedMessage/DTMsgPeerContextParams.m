//
//  DTMsgPeerContextParams.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import "DTMsgPeerContextParams.h"

@implementation DTMsgPeerContextParams

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (instancetype)initWithDestination:(NSString *)destination
          destinationRegistrationId:(NSInteger)destinationRegistrationId
                        peerContext:(nullable NSString *)peerContext {
    if(self = [super init]){
        self.uid = destination;
        self.registrationId = destinationRegistrationId;
        self.peerContext = peerContext;
    }
    
    return self;
}

@end
