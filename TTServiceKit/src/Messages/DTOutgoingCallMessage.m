//
//  DTOutgoingCallMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/27.
//

#import "DTOutgoingCallMessage.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import "OWSDisappearingMessagesConfiguration.h"
#import "TSThread.h"

@implementation DTOutgoingCallMessage

// --- CODE GENERATION MARKER
// --- CODE GENERATION MARKER

+ (instancetype)outgoingCallMessageWithText:(NSString *)text
                                   apnsType:(DTApnsMessageType)apnsType
                                   inThread:(TSThread *)thread{
    
    return [DTOutgoingCallMessage outgoingCallMessageWithText:text
                                                    atPersons:nil
                                                     mentions:nil
                                                     apnsType:apnsType
                                                     inThread:thread];
}

+ (instancetype)outgoingCallMessageWithText:(NSString *)text
                                  atPersons:(NSString *)atPersons
                                   mentions:(nullable NSArray <DTMention *> *)mentions
                                   apnsType:(DTApnsMessageType)apnsType
                                   inThread:(TSThread *)thread {
    
    uint32_t expiresInSeconds = [thread messageExpiresInSeconds];
    
    DTOutgoingCallMessage *message = [[DTOutgoingCallMessage alloc] initOutgoingMessageWithTimestamp:[NSDate ows_millisecondTimeStamp]
                                                                                            inThread:thread
                                                                                         messageBody:text
                                                                                           atPersons:atPersons
                                                                                            mentions:mentions
                                                                                       attachmentIds:@[].mutableCopy
                                                                                    expiresInSeconds:expiresInSeconds
                                                                                     expireStartedAt:0
                                                                                      isVoiceMessage:NO
                                                                                    groupMetaMessage:TSGroupMessageUnspecified
                                                                                       quotedMessage:nil
                                                                                   forwardingMessage:nil
                                                                                        contactShare:nil];
    
    message.apnsType = apnsType;
    return message;
}

- (BOOL)isSilent
{
    return NO;
}

- (BOOL)shouldBeSaved
{
//    if(self.apnsType == DTApnsMessageType_PERSONAL_CALL){
//        return NO;
//    }
    return YES;
}

@end
