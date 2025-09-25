//
//  DTOriginalMessageEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/13.
//

#import "DTOriginalMessageEntity.h"

@implementation DTOriginalMessageEntity

- (instancetype)initSourceWithRealSource:(DTRealSourceEntity *)realSource
                          conversationId:(NSString *)conversationId{
    if(self = [super init]){
        self.realSource = realSource;
        self.conversationId = conversationId;
    }
    return self;
}

//+ (DTOriginalMessageEntity *)originalMessageWithProto:(DSKProtoDataMessageOriginalMessage *)originalMessageProto{
//
//    if(!originalMessageProto || !originalMessageProto.hasSource || !originalMessageProto.hasConversationId){
//        return nil;
//    }
//
//    DTRealSourceEntity *realSourceEntity = [DTRealSourceEntity realSourceEntityWithProto:originalMessageProto.source];
//    DTOriginalMessageEntity *originalMessageEntity = [[DTOriginalMessageEntity alloc] initSourceWithRealSource:realSourceEntity
//                                                                                                conversationId:originalMessageProto.conversationId];
//    return originalMessageEntity;
//}
//
//+ (DSKProtoDataMessageOriginalMessage *)protoWithOriginalMessageEntity:(DTOriginalMessageEntity *)originalMessageEntity{
//    if(!originalMessageEntity){
//        return nil;
//    }
//    DSKProtoDataMessageOriginalMessageBuilder *builder = [DSKProtoDataMessageOriginalMessage builder];
//    builder.conversationId = originalMessageEntity.conversationId;
//    builder.source = [DTRealSourceEntity protoWithRealSourceEntity:originalMessageEntity.realSource];
//
//}

@end
