//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "Environment.h"
#import "DebugLogger.h"
//
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/ContactsUpdater.h>
#import <TTServiceKit/OWSSignalService.h>
#import <TTServiceKit/TSContactThread.h>
#import <TTServiceKit/TSGroupThread.h>
#import <SignalCoreKit/Threading.h>
#import "OWSContactsManager.h"
#import "OWSProfileManager.h"

static Environment *sharedEnvironment = nil;

@interface Environment ()

@property (nonatomic) OWSContactsManager *contactsManager;
@property (nonatomic) ContactsUpdater *contactsUpdater;
@property (nonatomic) OWSPreferences *preferences;

@end

#pragma mark -

@implementation Environment

+ (Environment *)shared
{
    OWSAssertDebug(sharedEnvironment);
    
    return sharedEnvironment;
}

+ (void)setShared:(Environment *)shared {
    OWSAssertDebug(!sharedEnvironment || !CurrentAppContext().isMainApp);
    OWSAssertDebug(shared);
    
    sharedEnvironment = shared;
}

+ (void)clearCurrentForTests
{
    sharedEnvironment = nil;
}

- (instancetype)initWithContactsManager:(OWSContactsManager *)contactsManager
                        contactsUpdater:(ContactsUpdater *)contactsUpdater
{
    self = [super init];
    if (!self) {
        return self;
    }

    _contactsManager = contactsManager;
    _contactsUpdater = contactsUpdater;

    OWSSingletonAssert()

    return self;
}

- (OWSContactsManager *)contactsManager
{
    OWSAssertDebug(_contactsManager);

    return _contactsManager;
}

- (ContactsUpdater *)contactsUpdater
{
    OWSAssertDebug(_contactsUpdater);

    return _contactsUpdater;
}

+ (OWSPreferences *)preferences
{
    OWSAssertDebug(Environment.shared.preferences);

    return Environment.shared.preferences;
}

// TODO: Convert to singleton?
- (OWSPreferences *)preferences
{
    @synchronized(self)
    {
        if (!_preferences) {
            _preferences = [OWSPreferences new];
        }
    }

    return _preferences;
}

@end
