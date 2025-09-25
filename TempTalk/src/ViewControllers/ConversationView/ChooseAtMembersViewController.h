//
//  ChooseAtMembersViewController.h
//  Signal
//
//  Created by user on 2021/6/2.
//

#import "OWSTableViewController.h"

typedef enum : NSUInteger {
    ChooseMemberPageTypeMention,
    ChooseMemberPageTypeSendContact
} ChooseMemberPageType;

@class TSThread;

@protocol ChooseAtMembersViewControllerDelegate <NSObject>

/// chooseAtPeronsDidSelectRecipientId
/// - Parameters:
///   - recipientId: recipientId description
///   - name: name description
///   - type: DSKDataMessageMentionType
- (void)chooseAtPeronsDidSelectRecipientId:(NSString *)recipientId
                                      name:(NSString *)name
                               mentionType:(int32_t)mentionType
                                  pageType:(ChooseMemberPageType)pageType;
- (void)chooseAtPeronsCancel;

@end

@interface ChooseAtMembersViewController : OWSTableViewController
@property (nonatomic, weak) id<ChooseAtMembersViewControllerDelegate> resultDelegate;

+ (ChooseAtMembersViewController *)presentFromViewController:(UIViewController *)viewController
                                                    pageType:(ChooseMemberPageType)pageType
                                                      thread:(TSThread *)thread
                                                    delegate:(id<ChooseAtMembersViewControllerDelegate>)theDelegate;

- (void)dismissVC;

@end

