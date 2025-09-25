//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSPreferences.h"
//

/**
 *
 * Environment is a data and data accessor class.
 * It handles application-level component wiring in order to support mocks for testing.
 * It also handles network configuration for testing/deployment server configurations.
 *
 **/

@class ContactsUpdater;
@class OWSContactsManager;
@class TSGroupThread;
@class TSThread;

@interface Environment : NSObject

- (instancetype)initWithContactsManager:(OWSContactsManager *)contactsManager
                        contactsUpdater:(ContactsUpdater *)contactsUpdater;

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) ContactsUpdater *contactsUpdater;
@property (nonatomic, readonly) OWSPreferences *preferences;

@property (class, nonatomic) Environment *shared;

+ (void)setShared:(Environment *)shared;

// Should only be called by tests.
+ (void)clearCurrentForTests;

+ (OWSPreferences *)preferences;

@end
