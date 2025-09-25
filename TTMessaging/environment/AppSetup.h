//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@protocol NotificationsProtocol;

typedef void (^CallMessageHandlerBlock)(void);
typedef id<NotificationsProtocol> _Nonnull (^NotificationsManagerBlock)(void);

// This is _NOT_ a singleton and will be instantiated each time that the SAE is used.
@interface AppSetup : NSObject

+ (void)setupEnvironmentWithAppSpecificSingletonBlock:(dispatch_block_t)appSpecificSingletonBlock
                                  migrationCompletion:(dispatch_block_t)migrationCompletion;

@end

NS_ASSUME_NONNULL_END
