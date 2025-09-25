//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "Release.h"
#import "Environment.h"
#import "OWSContactsManager.h"
#import <TTServiceKit/ContactsUpdater.h>

@implementation Release

+ (Environment *)releaseEnvironment
{
    static Environment *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Order matters here.
        OWSContactsManager *contactsManager = [OWSContactsManager new];
        ContactsUpdater *contactsUpdater = [ContactsUpdater sharedUpdater];

        instance = [[Environment alloc] initWithContactsManager:contactsManager
                                                contactsUpdater:contactsUpdater];
    });
    return instance;
}

@end
