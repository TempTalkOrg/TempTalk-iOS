//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "ContactsManagerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ContactsManagerProtocol;
@class OWSMessageSender;
@protocol NotificationsProtocol;
@protocol CallMessageHandlerProtocol;
@protocol ProfileManagerProtocol;
@protocol DTMeetingManagerProtocol;
@protocol DTSettingsManagerProtocol;

@interface TextSecureKitEnv : NSObject

- (instancetype)initWithContactsManager:(id<ContactsManagerProtocol>)contactsManager
                          messageSender:(OWSMessageSender *)messageSender
                         profileManager:(id<ProfileManagerProtocol>)profileManager NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedEnv;
+ (void)setSharedEnv:(TextSecureKitEnv *)env;

@property (nonatomic, readonly) id<CallMessageHandlerProtocol> callMessageHandler;
@property (nonatomic, readonly) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) id<ProfileManagerProtocol> profileManager;

@property (atomic, nullable) id<NotificationsProtocol> notificationsManager;
@property (nonatomic, nullable) id<DTMeetingManagerProtocol> meetingManager;
@property (nonatomic, nullable) id<DTSettingsManagerProtocol> settingsManager;

@end

NS_ASSUME_NONNULL_END
