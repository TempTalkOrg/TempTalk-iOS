//
//  DTMessageParamsBuilder.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import <Foundation/Foundation.h>
#import "TSConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class TSOutgoingMessage;
@class TSThread;
@class SignalRecipient;
@class DTMsgPeerContextParams;

@interface DTMessageParamsBuilder : NSObject

- (NSDictionary * _Nullable)buildParamsWithMessage:(TSOutgoingMessage *)message
                                          toThread:(TSThread *)thread
                                         recipient:(SignalRecipient *)recipient
                                       messageType:(TSWhisperMessageType)messageType
                                    serializedData:(NSData *)serializedData
                              legacySerializedData:(NSData * __nullable)legacySerializedData
                             recipientPeerContexts:(NSArray<DTMsgPeerContextParams *> *)recipientPeerContexts
                                             error:(NSError **)error;

- (BOOL)checkShouldUseGroupRequestWithThread:(TSThread *)thread
                                   recipient:(SignalRecipient *)recipient;

@end

NS_ASSUME_NONNULL_END
