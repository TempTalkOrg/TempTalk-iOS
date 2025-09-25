//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ContactsManagerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class TSErrorMessage;
@class TSIncomingMessage;
@class TSThread;
@class SDSAnyReadTransaction;
@class SDSAnyWriteTransaction;

@protocol ContactsManagerProtocol;

@protocol NotificationsProtocol <NSObject>

- (void)notifyUserForIncomingMessage:(TSIncomingMessage *)incomingMessage
                            inThread:(TSThread *)thread
                         transaction:(SDSAnyWriteTransaction *)transaction;

- (void)notifyUserForIncomingMessage:(TSIncomingMessage *)incomingMessage
                            inThread:(TSThread *)thread
                     contactsManager:(id<ContactsManagerProtocol>)contactsManager
                         transaction:(SDSAnyReadTransaction *)transaction;

- (void)notifyUserForErrorMessage:(TSErrorMessage *)error
                           thread:(TSThread *)thread
                      transaction:(SDSAnyWriteTransaction *)transaction;

- (void)notifyUserForThreadlessErrorMessage:(TSErrorMessage *)error
                                transaction:(SDSAnyWriteTransaction *)transaction;

- (void)notifyForScheduleMeetingWithTitle:(NSString * _Nullable)title
                                     body:(NSString *)body
                                 userInfo:(NSDictionary<id, id> *)userInfo
                       replacingIdentifier:(NSString * _Nullable)replacingIdentifier
                      triggerTimeInterval:(NSTimeInterval)triggerTimeInterval
                               completion:(void (^_Nullable)(NSError *_Nullable))completion;


- (void)clearAllNotificationsExceptCategoryIdentifiers:(nullable NSArray <NSString *> *)categoryIdentifiers NS_SWIFT_NAME(clearAllNotifications(except:));

- (void)syncApnSoundIfNeeded;

@end

NS_ASSUME_NONNULL_END
