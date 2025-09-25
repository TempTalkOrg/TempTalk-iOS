//
//  DTServerNotifyMessageHandler.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/26.
//

#import <Foundation/Foundation.h>
#import "DTGroupUpdateMessageProcessor.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const NSNotificationNameNotifyScheduleListRefresh;
extern NSNotificationName const NSNotificationNameNotifyCallEnd;

extern NSString * const NotifyCallEndRoomIdKey;

@class SDSAnyWriteTransaction;
@class DSKProtoEnvelope;

@interface DTServerNotifyMessageHandler : NSObject

@property (nonatomic, strong) DTGroupUpdateMessageProcessor *groupUpdateMessageProcessor;

- (void)handleNotifyDataWithEnvelope:(DSKProtoEnvelope *)envelope
                       plaintextData:(NSData *)plaintextData
                         transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
