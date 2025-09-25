//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "DebugUIStress.h"
#import "OWSMessageSender.h"
#import "OWSTableViewController.h"
#import "SignalApp.h"
#import "ThreadUtil.h"
#import <TTMessaging/Environment.h>
#import <TTServiceKit/SSKCryptography.h>
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/OWSDynamicOutgoingMessage.h>
#import <TTServiceKit/SecurityUtils.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/TSThread.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/SDSDatabaseStorage+Objc.h>

NS_ASSUME_NONNULL_BEGIN

@implementation DebugUIStress

#pragma mark - Factory Methods

- (NSString *)name
{
    return @"Stress";
}

- (nullable OWSTableSection *)sectionForThread:(nullable TSThread *)thread
{
    OWSAssertDebug(thread);
    
    NSMutableArray<OWSTableItem *> *items = [NSMutableArray new];
    [items addObject:[OWSTableItem itemWithTitle:@"Send empty message"
                                     actionBlock:^{
                                         [DebugUIStress sendStressMessage:thread block:^(SignalRecipient *recipient) {
                                             return [NSData new];
                                         }];
                                     }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send random noise message"
                                     actionBlock:^{
                                         [DebugUIStress
                                             sendStressMessage:thread
                                                         block:^(SignalRecipient *recipient) {
                                                             NSUInteger contentLength = arc4random_uniform(32);
                                                             return [SSKCryptography generateRandomBytes:contentLength];
                                                         }];
                                     }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send no payload message"
                                     actionBlock:^{
                                         [DebugUIStress sendStressMessage:thread block:^(SignalRecipient *recipient) {
                                             DSKProtoContentBuilder *contentBuilder = [DSKProtoContent builder];
                                             
                                             NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                             if (!content) {
                                                 content = [NSData new];
                                             }
                                             return content;
                                         }];
                                     }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send empty null message"
                                     actionBlock:^{
                                         [DebugUIStress sendStressMessage:thread block:^(SignalRecipient *recipient) {
                                             DSKProtoContentBuilder *contentBuilder = [DSKProtoContent builder];
                                             DSKProtoNullMessageBuilder *nullMessageBuilder = [DSKProtoNullMessage builder];
                                             contentBuilder.nullMessage = [nullMessageBuilder buildAndReturnError:nil];
                                             
                                             
                                             NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                             if (!content) {
                                                 content = [NSData new];
                                             }
                                             return content;
                                         }];
                                     }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send random null message"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoNullMessageBuilder *nullMessageBuilder =
                                                              [DSKProtoNullMessage builder];
                                                          NSUInteger contentLength = arc4random_uniform(32);
                                                          nullMessageBuilder.padding =
                                                              [SSKCryptography generateRandomBytes:contentLength];
                                                          contentBuilder.nullMessage = [nullMessageBuilder buildAndReturnError:nil];
                                                          
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                          if (!content) {
                                                              content = [NSData new];
                                                          }
                                                          return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send empty sync message"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                          if (!content) {
                                                              content = [NSData new];
                                                          }
                                                          return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send empty sync sent message"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                          
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                          if (!content) {
                                                              content = [NSData new];
                                                          }
                                                          return content;
                                                      }];
                                  }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send whitespace text data message"
                                     actionBlock:^{
                                         [DebugUIStress
                                             sendStressMessage:thread
                                                         block:^(SignalRecipient *recipient) {
                                                             DSKProtoContentBuilder *contentBuilder =
                                                                 [DSKProtoContent builder];
                                                             DSKProtoDataMessageBuilder *dataBuilder =
                                                                 [DSKProtoDataMessage builder];
                                                             dataBuilder.body = @" ";
                                                             [DebugUIStress ensureGroupOfDataBuilder:dataBuilder
                                                                                              thread:thread];
                                                             contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                             
                                                            NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                            if (!content) {
                                                                content = [NSData new];
                                                            }
                                                            return content;
                                                         }];
                                     }]];
    [items addObject:[OWSTableItem
                         itemWithTitle:@"Send bad attachment data message"
                           actionBlock:^{
                               [DebugUIStress
                                   sendStressMessage:thread
                                               block:^(SignalRecipient *recipient) {
                                                   DSKProtoContentBuilder *contentBuilder =
                                                       [DSKProtoContent builder];
                                                   DSKProtoDataMessageBuilder *dataBuilder =
                                                       [DSKProtoDataMessage builder];
                                                   DSKProtoAttachmentPointerBuilder *attachmentPointer =
                                                       [DSKProtoAttachmentPointer builder];
                                                   [attachmentPointer setId:arc4random_uniform(32) + 1];
                                                   [attachmentPointer setContentType:@"1"];
                                                   [attachmentPointer setSize:arc4random_uniform(32) + 1];
                                                   [attachmentPointer setDigest:[SSKCryptography generateRandomBytes:1]];
                                                   [attachmentPointer setFileName:@" "];
                                                   [DebugUIStress ensureGroupOfDataBuilder:dataBuilder thread:thread];
                                                   contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                   
                                                   NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                   if (!content) {
                                                       content = [NSData new];
                                                   }
                                                   return content;
                                               }];
                           }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send normal text data message"
                                     actionBlock:^{
                                         [DebugUIStress
                                             sendStressMessage:thread
                                                         block:^(SignalRecipient *recipient) {
                                                             DSKProtoContentBuilder *contentBuilder =
                                                                 [DSKProtoContent builder];
                                                             DSKProtoDataMessageBuilder *dataBuilder =
                                                                 [DSKProtoDataMessage builder];
                                                             dataBuilder.body = @"alice";
                                                             [DebugUIStress ensureGroupOfDataBuilder:dataBuilder
                                                                                              thread:thread];
                                                             contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                             
                                                             NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                             if (!content) {
                                                                 content = [NSData new];
                                                             }
                                                             return content;
                                                         }];
                                     }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send N text messages with same timestamp"
                                     actionBlock:^{
                                         uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                                         for (int i = 0; i < 3; i++) {
                                             [DebugUIStress
                                                 sendStressMessage:thread
                                                         timestamp:timestamp
                                                             block:^(SignalRecipient *recipient) {
                                                                 DSKProtoContentBuilder *contentBuilder =
                                                                     [DSKProtoContent builder];
                                                                 DSKProtoDataMessageBuilder *dataBuilder =
                                                                     [DSKProtoDataMessage builder];
                                                                 dataBuilder.body = [NSString stringWithFormat:@"%@ %d",
                                                                                              [NSUUID UUID].UUIDString,
                                                                                              i];
                                                                 [DebugUIStress ensureGroupOfDataBuilder:dataBuilder
                                                                                                  thread:thread];
                                                                 contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                                 
                                                                 NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                             }];
                                         }
                                     }]];
    [items addObject:[OWSTableItem
                         itemWithTitle:@"Send text message with current timestamp"
                           actionBlock:^{
                               uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                               [DebugUIStress
                                   sendStressMessage:thread
                                           timestamp:timestamp
                                               block:^(SignalRecipient *recipient) {
                                                   DSKProtoContentBuilder *contentBuilder =
                                                       [DSKProtoContent builder];
                                                   DSKProtoDataMessageBuilder *dataBuilder =
                                                       [DSKProtoDataMessage builder];
                                                   dataBuilder.body =
                                                       [[NSUUID UUID].UUIDString stringByAppendingString:@" now"];
                                                   [DebugUIStress ensureGroupOfDataBuilder:dataBuilder thread:thread];
                                                   contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                   NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                               }];
                           }]];
    [items addObject:[OWSTableItem
                         itemWithTitle:@"Send text message with future timestamp"
                           actionBlock:^{
                               uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                               timestamp += kHourInMs;
                               [DebugUIStress
                                   sendStressMessage:thread
                                           timestamp:timestamp
                                               block:^(SignalRecipient *recipient) {
                                                   DSKProtoContentBuilder *contentBuilder =
                                                       [DSKProtoContent builder];
                                                   DSKProtoDataMessageBuilder *dataBuilder =
                                                       [DSKProtoDataMessage builder];
                                                   dataBuilder.body =
                                                       [[NSUUID UUID].UUIDString stringByAppendingString:@" now"];
                                                   [DebugUIStress ensureGroupOfDataBuilder:dataBuilder thread:thread];
                                                   contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                   NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                               }];
                           }]];
    [items addObject:[OWSTableItem
                         itemWithTitle:@"Send text message with past timestamp"
                           actionBlock:^{
                               uint64_t timestamp = [NSDate ows_millisecondTimeStamp];
                               timestamp -= kHourInMs;
                               [DebugUIStress
                                   sendStressMessage:thread
                                           timestamp:timestamp
                                               block:^(SignalRecipient *recipient) {
                                                   DSKProtoContentBuilder *contentBuilder =
                                                       [DSKProtoContent builder];
                                                   DSKProtoDataMessageBuilder *dataBuilder =
                                                       [DSKProtoDataMessage builder];
                                                   dataBuilder.body =
                                                       [[NSUUID UUID].UUIDString stringByAppendingString:@" now"];
                                                   [DebugUIStress ensureGroupOfDataBuilder:dataBuilder thread:thread];
                                                   contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                                   NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                   return content;
                                               }];
                           }]];
    [items addObject:[OWSTableItem itemWithTitle:@"Send N text messages with same timestamp"
                                     actionBlock:^{
                                         DSKProtoContentBuilder *contentBuilder =
                                             [DSKProtoContent builder];
                                         DSKProtoDataMessageBuilder *dataBuilder =
                                             [DSKProtoDataMessage builder];
                                         dataBuilder.body = @"alice";
                                         contentBuilder.dataMessage = [dataBuilder buildAndReturnError:nil];
                                         [DebugUIStress ensureGroupOfDataBuilder:dataBuilder thread:thread];
                                         
                                         NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                         if (!content) {
                                             content = [NSData new];
                                         }

                                         uint64_t timestamp = [NSDate ows_millisecondTimeStamp];

                                         for (int i = 0; i < 3; i++) {
                                             [DebugUIStress sendStressMessage:thread
                                                                    timestamp:timestamp
                                                                        block:^(SignalRecipient *recipient) {
                                                                            return content;
                                                                        }];
                                         }
                                     }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send malformed sync sent message 1"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          sentBuilder.timestamp = arc4random_uniform(32) + 1;
                                                          DSKProtoDataMessageBuilder *dataBuilder =
                                                              [DSKProtoDataMessage builder];
                                                          sentBuilder.message = [dataBuilder buildAndReturnError:nil];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send malformed sync sent message 2"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          sentBuilder.timestamp = 0;
                                                          DSKProtoDataMessageBuilder *dataBuilder =
                                                              [DSKProtoDataMessage builder];
                                                          sentBuilder.message = [dataBuilder buildAndReturnError:nil];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send malformed sync sent message 3"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          sentBuilder.timestamp = 0;
                                                          DSKProtoDataMessageBuilder *dataBuilder =
                                                              [DSKProtoDataMessage builder];
                                                          dataBuilder.body = @" ";
                                                          sentBuilder.message = [dataBuilder buildAndReturnError:nil];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send malformed sync sent message 4"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          sentBuilder.timestamp = 0;
                                                          DSKProtoDataMessageBuilder *dataBuilder =
                                                              [DSKProtoDataMessage builder];
                                                          dataBuilder.body = @" ";
                                                          DSKProtoGroupContextBuilder *groupBuilder =
                                                              [DSKProtoGroupContext builder];
                                                          [groupBuilder setId:[SSKCryptography generateRandomBytes:1]];
                                                          dataBuilder.group = [groupBuilder buildAndReturnError:nil];
                                                          sentBuilder.message = [dataBuilder buildAndReturnError:nil];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send malformed sync sent message 5"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          sentBuilder.timestamp = 0;
                                                          DSKProtoDataMessageBuilder *dataBuilder =
                                                              [DSKProtoDataMessage builder];
                                                          dataBuilder.body = @" ";
                                                          DSKProtoGroupContextBuilder *groupBuilder =
                                                              [DSKProtoGroupContext builder];
                                                          [groupBuilder setId:[SSKCryptography generateRandomBytes:1]];
                                                          dataBuilder.group = [groupBuilder buildAndReturnError:nil];
                                                          sentBuilder.message = [dataBuilder buildAndReturnError:nil];
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                             return content;
                                                      }];
                                  }]];
    [items
        addObject:[OWSTableItem itemWithTitle:@"Send empty sync sent message 6"
                                  actionBlock:^{
                                      [DebugUIStress
                                          sendStressMessage:thread
                                                      block:^(SignalRecipient *recipient) {
                                                          DSKProtoContentBuilder *contentBuilder =
                                                              [DSKProtoContent builder];
                                                          DSKProtoSyncMessageBuilder *syncMessageBuilder =
                                                              [DSKProtoSyncMessage builder];
                                                          DSKProtoSyncMessageSentBuilder *sentBuilder =
                                                              [DSKProtoSyncMessageSent builder];
                                                          sentBuilder.destination = @"abc";
                                                          syncMessageBuilder.sent = [sentBuilder buildAndReturnError:nil];
                                                          contentBuilder.syncMessage = [syncMessageBuilder buildAndReturnError:nil];
                                          
                                                          NSData *content = [contentBuilder buildSerializedDataAndReturnError:nil];
                                                                 if (!content) {
                                                                     content = [NSData new];
                                                                 }
                                                          return content;
                                                      }];
                                  }]];
    
    if ([thread isKindOfClass:[TSGroupThread class]]) {
        TSGroupThread *groupThread = (TSGroupThread *)thread;
        [items addObject:[OWSTableItem itemWithTitle:@"Hallucinate twin group"
                                         actionBlock:^{
                                             [DebugUIStress hallucinateTwinGroup:groupThread];
                                         }]];
    }
    return [OWSTableSection sectionWithTitle:self.name items:items];
}

+ (void)ensureGroupOfDataBuilder:(DSKProtoDataMessageBuilder *)dataBuilder thread:(TSThread *)thread
{
    OWSAssertDebug(dataBuilder);
    OWSAssertDebug(thread);

    if (![thread isKindOfClass:[TSGroupThread class]]) {
        return;
    }

    TSGroupThread *groupThread = (TSGroupThread *)thread;
    DSKProtoGroupContextBuilder *groupBuilder = [DSKProtoGroupContext builder];
    [groupBuilder setType:DSKProtoGroupContextTypeDeliver];
    [groupBuilder setId:groupThread.groupModel.groupId];
    [dataBuilder setGroup:[groupBuilder buildAndReturnError:nil]];
}

+ (void)sendStressMessage:(TSOutgoingMessage *)message
{
    OWSAssertDebug(message);

    [self.messageSender enqueueMessage:message
        success:^{
            OWSLogInfo(@"%@ Successfully sent message.", self.logTag);
        }
        failure:^(NSError *error) {
            DDLogWarn(@"%@ Failed to deliver message with error: %@", self.logTag, error);
        }];
}

+ (void)sendStressMessage:(TSThread *)thread
                    block:(DynamicOutgoingMessageBlock)block
{
    OWSAssertDebug(thread);
    OWSAssertDebug(block);

    OWSDynamicOutgoingMessage *message =
        [[OWSDynamicOutgoingMessage alloc] initWithPlainTextDataBlock:block thread:thread];

    [self sendStressMessage:message];
}

+ (void)sendStressMessage:(TSThread *)thread timestamp:(uint64_t)timestamp block:(DynamicOutgoingMessageBlock)block
{
    OWSAssertDebug(thread);
    OWSAssertDebug(block);

    OWSDynamicOutgoingMessage *message =
        [[OWSDynamicOutgoingMessage alloc] initWithPlainTextDataBlock:block timestamp:timestamp thread:thread];

    [self sendStressMessage:message];
}

// Creates a new group (by cloning the current group) without informing the,
// other members. This can be used to test "group info requests", etc.
+ (void)hallucinateTwinGroup:(TSGroupThread *)groupThread
{
    __block TSGroupThread *thread;
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            TSGroupModel *groupModel =
                [[TSGroupModel alloc] initWithTitle:[groupThread.groupModel.groupName stringByAppendingString:@" Copy"]
                                          memberIds:groupThread.groupModel.groupMemberIds
                                              image:groupThread.groupModel.groupImage
                                            groupId:[SecurityUtils generateRandomBytes:16]
                                         groupOwner:nil
                                         groupAdmin:nil];
            thread = [TSGroupThread getOrCreateThreadWithGroupModel:groupModel transaction:transaction];
        });
    OWSAssertDebug(thread);

    [SignalApp.sharedApp presentConversationForThread:thread];
}

@end

NS_ASSUME_NONNULL_END
