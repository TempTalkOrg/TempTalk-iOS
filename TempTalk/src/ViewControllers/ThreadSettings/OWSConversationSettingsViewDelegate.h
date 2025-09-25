//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class TSGroupThread;
@class DTInputAtItem;

@protocol OWSConversationSettingsViewDelegate <NSObject>

- (void)conversationColorWasUpdated;

- (void)popAllConversationSettingsViews;

- (void)sendEmergencyAlertMessage:(NSString *)messageText
                          atItems:(NSArray <DTInputAtItem *> *)items;


@end

NS_ASSUME_NONNULL_END
