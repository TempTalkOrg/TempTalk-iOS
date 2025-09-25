//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import "TSContactThread.h"
#import "TSIncomingMessage.h"
#import "TSThread.h"
#import "TSInfoMessage.h"
#import "OWSUserProfile.h"

NS_ASSUME_NONNULL_BEGIN

@class MessageBodyRanges;

// This header exposes private properties for SDS serialization.

@interface TSThread (SDS)

@property (nonatomic, readonly) NSDate *creationDate;
@property (nonatomic, copy, nullable, readonly) NSDate *archivalDate;
@property (nonatomic, nullable, readonly) NSDate *lastMessageDate;
@property (nonatomic, copy, nullable, readonly) NSString *messageDraft;
@property (atomic, nullable, readonly) NSDate *mutedUntilDate;
@property (nonatomic, strong, nullable, readonly) NSDate *stickDate;
@property (nonatomic, strong, nullable, readonly) NSDate *stickCallingDate;
@property (nonatomic, assign, readonly) NSUInteger unreadState;
@property (nonatomic, copy, nullable, readonly) NSString *draftQuoteMessageId;

@end

#pragma mark -

@interface TSInteraction (SDS)

@end

#pragma mark -

@interface TSMessage (SDS)

// This property is only intended to be used by GRDB queries.
@property (nonatomic, readonly) BOOL storedShouldStartExpireTimer;

@end

#pragma mark -

@interface TSInfoMessage (SDS)

@property (nonatomic, getter=wasRead) BOOL read;

@end

#pragma mark -

@interface TSErrorMessage (SDS)

@property (nonatomic, getter=wasRead) BOOL read;

@end

#pragma mark -

@interface TSOutgoingMessage (SDS)

@property (nonatomic, readonly) TSOutgoingMessageState storedMessageState;

@end

#pragma mark -

@interface TSIncomingMessage (SDS)

@property (nonatomic, getter=wasRead) BOOL read;

@end

#pragma mark -

@interface TSAttachment (SDS)

@property (nonatomic, readonly) NSUInteger attachmentSchemaVersion;

@end

#pragma mark -

@interface TSAttachmentPointer (SDS)

@property (nonatomic, nullable, readonly) NSString *lazyRestoreFragmentId;

@end

#pragma mark -

@interface TSAttachmentStream (SDS)

@property (nullable, nonatomic, readonly) NSString *localRelativeFilePath;

@property (nullable, nonatomic, readonly) NSNumber *cachedImageWidth;
@property (nullable, nonatomic, readonly) NSNumber *cachedImageHeight;

@property (nullable, nonatomic, readonly) NSNumber *cachedAudioDurationSeconds;

@property (nonatomic, nullable) NSString *lazyRestoreFragmentId;

@end

#pragma mark -

@interface TSContactThread (SDS)

@property (nonatomic, nullable, readonly) NSString *contactPhoneNumber;
@property (nonatomic, nullable, readonly) NSString *contactUUID;

@end

#pragma mark -

@interface OWSUserProfile (SDS)

@property (atomic, nullable, readonly) NSString *recipientPhoneNumber;
@property (atomic, nullable, readonly) NSString *recipientUUID;
@property (atomic, nullable, readonly) NSString *profileName;

@end

NS_ASSUME_NONNULL_END
