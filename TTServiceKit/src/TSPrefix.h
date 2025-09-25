//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <TTServiceKit/OWSAnalytics.h>
#import <TTServiceKit/SSKAsserts.h>
#import <TTServiceKit/OWSDispatch.h>
#import <TTServiceKit/iOSVersions.h>
#import <TTServiceKit/Constraints.h>

#import <SignalCoreKit/NSObject+OWS.h>
#import <SignalCoreKit/OWSAsserts.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalCoreKit/NSData+OWS.h>

#define BLOCK_SAFE_RUN(block, ...)                                                        \
    block ? dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), \
                           ^{                                                             \
                             block(__VA_ARGS__);                                          \
                           })                                                             \
          : nil
#define SYNC_BLOCK_SAFE_RUN(block, ...) block ? block(__VA_ARGS__) : nil

#define MacrosSingletonImplemention          \
    +(instancetype)sharedInstance {          \
        static dispatch_once_t onceToken;    \
        static id sharedInstance = nil;      \
        dispatch_once(&onceToken, ^{         \
          sharedInstance = [self.class new]; \
        });                                  \
                                             \
        return sharedInstance;               \
    }

#define MacrosSingletonInterface +(instancetype)sharedInstance;
