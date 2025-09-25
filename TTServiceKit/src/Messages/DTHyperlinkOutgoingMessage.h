//
//  DTHyperlinkOutgoingMessage.h
//  TTServiceKit
//
//  Created by Ethan on 2022/7/26.
//

#import "DTCardOutgoingMessage.h"
#import "DTApnsMessageBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTHyperlinkOutgoingMessage : DTCardOutgoingMessage

@property (nonatomic, assign) DTApnsMessageType apnsType;

@property (nonatomic, strong) NSDictionary<NSString *, id> *apnsPassthroughInfo;

@property (nonatomic, copy) NSString *collapseId;

@property (nonatomic, copy) NSString *groupName;

// --- CODE GENERATION MARKER
// --- CODE GENERATION MARKER

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                        thread:(TSThread *)thread;

+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
                                       atPersons:(nullable NSString *)atPersons
                                        mentions:(nullable NSArray <DTMention *> *)mentions
                                        apnsType:(DTApnsMessageType)apnsType
                                          thread:(TSThread *)thread;

+ (instancetype)outgoingHyperlinkMessageWithText:(nullable NSString *)text
                                        apnsType:(DTApnsMessageType)apnsType
                                          thread:(TSThread *)thread
                                        cardInfo:(nullable NSDictionary *)cardInfo;

//+ (instancetype)outgoingHyperlinkMessageWithText:(NSString *)text
//                                       atPersons:(nullable NSString *)atPersons
//                                        mentions:(nullable NSArray <DTMention *> *)mentions
//                                        apnsType:(DTApnsMessageType)apnsType
//                                        thread:(TSThread *)thread;


@end

NS_ASSUME_NONNULL_END
