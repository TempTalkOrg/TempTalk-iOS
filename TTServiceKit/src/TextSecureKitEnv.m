//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "TextSecureKitEnv.h"
#import "AppContext.h"

NS_ASSUME_NONNULL_BEGIN

static TextSecureKitEnv *sharedTextSecureKitEnv;

@interface TextSecureKitEnv ()

//@property (nonatomic) id<CallMessageHandlerProtocol> callMessageHandler;
@property (nonatomic) id<ContactsManagerProtocol> contactsManager;
@property (nonatomic) OWSMessageSender *messageSender;
@property (nonatomic) id<ProfileManagerProtocol> profileManager;

@end

#pragma mark -

@implementation TextSecureKitEnv

- (instancetype)initWithContactsManager:(id<ContactsManagerProtocol>)contactsManager
                          messageSender:(OWSMessageSender *)messageSender
                         profileManager:(id<ProfileManagerProtocol>)profileManager {
    self = [super init];
    if (!self) {
        return self;
    }

    OWSAssertDebug(contactsManager);
    OWSAssertDebug(messageSender);
    OWSAssertDebug(profileManager);

    _contactsManager = contactsManager;
    _messageSender = messageSender;
    _profileManager = profileManager;

    return self;
}

+ (instancetype)sharedEnv
{
    OWSAssertDebug(sharedTextSecureKitEnv);

    return sharedTextSecureKitEnv;
}

+ (void)setSharedEnv:(TextSecureKitEnv *)env
{
    OWSAssertDebug(env);
    OWSAssertDebug(!sharedTextSecureKitEnv || !CurrentAppContext().isMainApp);

    sharedTextSecureKitEnv = env;
}

@end

NS_ASSUME_NONNULL_END
