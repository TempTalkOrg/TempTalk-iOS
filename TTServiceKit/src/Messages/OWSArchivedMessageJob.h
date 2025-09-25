//
//  OWSArchivedMessageJob.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/16.
//

#import <Foundation/Foundation.h>

@class TSMessage;
@class TSThread;
@class SDSAnyWriteTransaction;

NS_ASSUME_NONNULL_BEGIN

@interface OWSArchivedMessageJob : NSObject

@property (nonatomic, assign) BOOL inConversation;

+ (instancetype)sharedJob;

- (void)startIfNecessary;

- (void)archiveMessage:(TSMessage *)message;

- (void)archiveMessage:(TSMessage *)message transaction:(SDSAnyWriteTransaction *)transaction;

- (void)fallbackTimerDidFire;

@end

NS_ASSUME_NONNULL_END
