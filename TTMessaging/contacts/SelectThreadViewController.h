//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTMessaging/OWSViewController.h>

@class TSThread;

NS_ASSUME_NONNULL_BEGIN

@protocol SelectThreadViewControllerDelegate <NSObject>

- (void)threadsWasSelected:(NSArray <TSThread *> *)threads;

@optional
- (BOOL)forwordThreadCanBeSelested:(TSThread *)thread;

- (BOOL)canSelectBlockedContact;

- (nullable UIView *)createHeaderWithSearchBar:(UISearchBar *)searchBar;

- (BOOL)showExternalContacts;

- (BOOL)showRecently;

- (BOOL)showSelfAsNote;

- (nullable NSString *)selectedMaxCountAlertFormat;

@end

#pragma mark -

// A base class for views used to pick a single signal user, either by
// entering a phone number or picking from your contacts.
@interface SelectThreadViewController : OWSViewController

@property (nonatomic, weak) id<SelectThreadViewControllerDelegate> selectThreadViewDelegate;
/// 已被选中的thread
@property (nonatomic, strong, nullable) NSArray <NSString *> *existingThreadIds;

@property (nonatomic, assign) NSUInteger maxSelectCount;
@property (nonatomic, assign, getter=isDefaultMultiSelect) BOOL defaultMultiSelect;

@end

NS_ASSUME_NONNULL_END
