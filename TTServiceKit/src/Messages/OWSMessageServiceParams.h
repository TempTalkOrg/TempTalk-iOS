//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "TSConstants.h"
#import <Mantle/Mantle.h>
#import "TSMessageMacro.h"

@class DTReadPositionEntity;
@class DTRealSourceEntity;


/**
 * Contstructs the per-device-message parameters used when submitting a message to
 * the Signal Web Service.
 *
 * See:
 * https://github.com/signalapp/libsignal-service-java/blob/master/java/src/main/java/org/whispersystems/signalservice/internal/push/OutgoingPushMessage.java
 */
@interface OWSMessageServiceParams : MTLModel <MTLJSONSerializing>

@property (nonatomic, readonly) int type;
@property (nonatomic, readonly) NSString *destination;
@property (nonatomic, readonly) int destinationDeviceId;
@property (nonatomic, readonly) int destinationRegistrationId;
@property (nonatomic, readonly) NSString *content;
@property (nonatomic, readonly) BOOL readReceipt;
@property (nonatomic, readonly) NSDictionary *notification;
//sync msg + read receipt msg needed
@property (nonatomic, strong) NSDictionary *conversation;
//用于热数据处理
@property (nonatomic, assign) int32_t msgType;
@property (nonatomic, assign) OWSDetailMessageType detailMessageType;


@property (nonatomic, strong) NSArray<DTReadPositionEntity *> *readPositions;
//recall msg needed
@property (nonatomic, strong) DTRealSourceEntity *realSource;
//combined messages
@property (nonatomic, copy) NSString *businessId;
//reaction msg needed
@property (nonatomic, copy, nullable) NSDictionary *reactionInfo;

- (instancetype)initWithType:(TSWhisperMessageType)type
                 recipientId:(NSString *)destination
                      device:(int)deviceId
                     content:(NSData *)content
              registrationId:(int)registrationId
                 readReceipt:(BOOL)readReceipt
                    apnsInfo:(NSDictionary *)apnsInfo;

@end
