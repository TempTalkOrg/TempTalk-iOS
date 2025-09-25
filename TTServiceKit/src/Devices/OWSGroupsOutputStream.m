//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSGroupsOutputStream.h"
#import "MIMETypeUtil.h"
#import "OWSDisappearingMessagesConfiguration.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "TSGroupModel.h"
#import "TSGroupThread.h"

NS_ASSUME_NONNULL_BEGIN

@implementation OWSGroupsOutputStream

- (void)writeGroup:(TSGroupThread *)groupThread transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(groupThread);
    OWSAssertDebug(transaction);

    TSGroupModel *group = groupThread.groupModel;
    OWSAssertDebug(group);

    DSKProtoGroupDetailsBuilder *groupBuilder = [DSKProtoGroupDetails builder];
    [groupBuilder setId:group.groupId];
    [groupBuilder setName:group.groupName];
    [groupBuilder setMembers:group.groupMemberIds];
    [groupBuilder setActive:groupThread.hasEverHadMessage];
#ifdef CONVERSATION_COLORS_ENABLED
    [groupBuilder setColor:groupThread.conversationColorName];
#endif

    NSData *avatarPng;
    if (group.groupImage) {
        DSKProtoGroupDetailsAvatarBuilder *avatarBuilder =
            [DSKProtoGroupDetailsAvatar builder];

        [avatarBuilder setContentType:OWSMimeTypeImagePng];
        avatarPng = UIImagePNGRepresentation(group.groupImage);
        [avatarBuilder setLength:(uint32_t)avatarPng.length];
        [groupBuilder setAvatar:[avatarBuilder buildAndReturnError:nil]];
    }

    [groupBuilder setExpireTimer:[groupThread messageExpiresInSeconds]];

    NSData *groupData = [groupBuilder buildSerializedDataAndReturnError:nil];
    
    if (groupData) {
        uint32_t groupDataLength = (uint32_t)groupData.length;
        [self writeVariableLengthUInt32:groupDataLength];
        [self writeData:groupData];
    }

    if (avatarPng) {
        [self writeData:avatarPng];
    }
}

@end

NS_ASSUME_NONNULL_END
