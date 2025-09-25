//
//  DTOutgoingSyncArchiveMessage.h
//  TTServiceKit
//
//  Created by Felix on 2023/5/25.
//

#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DTConversationArchiveEntity;

@interface DTOutgoingSyncArchiveMessage : OWSOutgoingSyncMessage

- (instancetype)initWithArchiveEntity:(DTConversationArchiveEntity *)archiveEntity;

@end

NS_ASSUME_NONNULL_END
