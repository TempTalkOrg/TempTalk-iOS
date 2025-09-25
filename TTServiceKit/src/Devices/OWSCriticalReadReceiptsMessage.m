//
//  OWSCriticalReadReceiptsMessage.m
//  TTServiceKit
//
//  Created by Ethan on 16/04/2024.
//

#import "OWSCriticalReadReceiptsMessage.h"
#import "OWSLinkedDeviceReadReceipt.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation OWSCriticalReadReceiptsMessage

- (DSKProtoSyncMessageBuilder *)syncMessageBuilder {
    
    DSKProtoSyncMessageBuilder *syncMessageBuilder = [DSKProtoSyncMessage builder];
    for (OWSLinkedDeviceReadReceipt *cReadReceipt in self.readReceipts) {
        DSKProtoSyncMessageReadBuilder *cReadProtoBuilder = [DSKProtoSyncMessageRead builder];
        [cReadProtoBuilder setSender:cReadReceipt.senderId];
        [cReadProtoBuilder setTimestamp:cReadReceipt.messageIdTimestamp];
        
        [syncMessageBuilder addCriticalRead:[cReadProtoBuilder buildAndReturnError:nil]];
    }
    
    return  syncMessageBuilder;
}

@end
