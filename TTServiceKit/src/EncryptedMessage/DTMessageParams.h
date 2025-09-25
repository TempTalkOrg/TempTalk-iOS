//
//  DTMessageParams.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/23.
//

#import "TSConstants.h"
#import <Mantle/Mantle.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSMessageMacro.h"

@class DTReadPositionEntity;
@class DTRealSourceEntity;
@class DTMsgPeerContextParams;

NS_ASSUME_NONNULL_BEGIN

@interface DTMessageParams : MTLModel<MTLJSONSerializing>

@property (nonatomic, readonly) int type;
@property (nonatomic, readonly) NSString *content;
@property (nonatomic, nullable, readonly) NSString *legacyContent;
@property (nonatomic, readonly) BOOL readReceipt;
@property (nonatomic, readonly) NSDictionary *notification;
//sync msg + read receipt msg needed
@property (nonatomic, strong) NSDictionary *conversation;
@property (nonatomic, assign) DSKProtoEnvelopeMsgType msgType;
@property (nonatomic, assign) OWSDetailMessageType detailMessageType;


@property (nonatomic, strong) NSArray<DTReadPositionEntity *> *readPositions;
//recall msg needed
@property (nonatomic, strong) DTRealSourceEntity *realSource;

@property (nonatomic, assign) NSTimeInterval timestamp;

@property (nonatomic, assign) BOOL silent;

@property (nonatomic, strong) NSArray<DTMsgPeerContextParams *> *recipients;


- (instancetype)initWithType:(TSWhisperMessageType)type
                     content:(NSData *)content
               legacyContent:(NSData * __nullable)legacyContent
                 readReceipt:(BOOL)readReceipt
                    apnsInfo:(NSDictionary *)apnsInfo;

@end

NS_ASSUME_NONNULL_END
