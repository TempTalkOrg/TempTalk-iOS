//
//  DTOutgoingCallMessage.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/27.
//

#import "TSOutgoingMessage.h"
#import "DTApnsMessageBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTOutgoingCallMessage : TSOutgoingMessage

@property (nonatomic, assign) DTApnsMessageType apnsType;

@property (nonatomic, strong) NSDictionary<NSString *, id> *apnsPassthroughInfo;

@property (nonatomic, copy) NSString *collapseId;

@property (nonatomic, copy) NSString *groupName;

// --- CODE GENERATION MARKER
// --- CODE GENERATION MARKER

+ (instancetype)outgoingCallMessageWithText:(NSString *)text
                                   apnsType:(DTApnsMessageType)apnsType
                                   inThread:(TSThread *)thread;

+ (instancetype)outgoingCallMessageWithText:(NSString *)text
                                  atPersons:(nullable NSString *)atPersons
                                   mentions:(nullable NSArray <DTMention *> *)mentions
                                   apnsType:(DTApnsMessageType)apnsType
                                   inThread:(TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
