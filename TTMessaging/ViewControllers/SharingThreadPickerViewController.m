//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SharingThreadPickerViewController.h"
#import "Environment.h"
#import "NSString+OWS.h"
#import "SignalApp.h"
#import "ThreadUtil.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/OWSDispatch.h>
#import <TTServiceKit/OWSError.h>
#import <TTServiceKit/OWSMessageSender.h>
#import <TTServiceKit/TSThread.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SendCompletionBlock)(NSError *_Nullable, TSOutgoingMessage *, NSUInteger);
typedef void (^SendMessageBlock)(SendCompletionBlock completion);

@interface SharingThreadPickerViewController () <SelectThreadViewControllerDelegate,
    AttachmentApprovalViewControllerDelegate>

@property (nonatomic, readonly) OWSContactsManager *contactsManager;
@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic) TSThread *thread;
@property (nonatomic, readonly, weak) id<ShareViewDelegate> shareViewDelegate;
@property (nonatomic, readonly) UIProgressView *progressView;
@property (nonatomic, nullable) NSMutableArray <TSOutgoingMessage *> *outgoingMessages;
@property (nonatomic, assign) NSUInteger attachmentUploadedCount;

@end

#pragma mark -

@implementation SharingThreadPickerViewController

- (instancetype)initWithShareViewDelegate:(id<ShareViewDelegate>)shareViewDelegate
{
    self = [super init];
    if (!self) {
        return self;
    }

    _shareViewDelegate = shareViewDelegate;
    self.selectThreadViewDelegate = self;
    self.attachmentUploadedCount = 0;
    
    return self;
}

- (void)loadView
{
    [super loadView];
    self.navigationItem.rightBarButtonItem = nil;

    _contactsManager = Environment.shared.contactsManager;
    _messageSender = Environment.shared.messageSender;

    _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    
    NSString *shareToPrefix = Localized(@"SHARE_EXTENSION_VIEW_TITLE", @"Title for the 'share extension' view.");
    NSString *sharingThreadTitle = [NSString stringWithFormat:@"%@%@", shareToPrefix, TSConstants.appDisplayName];
    self.title = sharingThreadTitle;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(attachmentUploadProgress:)
                                                 name:kAttachmentUploadProgressNotification
                                               object:nil];
}

- (BOOL)canSelectBlockedContact
{
    return NO;
}

- (nullable UIView *)createHeaderWithSearchBar:(UISearchBar *)searchBar
{
    OWSAssertDebug(searchBar);

    const CGFloat contentVMargin = 0;

    UIView *header = [UIView new];
    header.backgroundColor = [UIColor whiteColor];

//    UIButton *cancelShareButton = [UIButton buttonWithType:UIButtonTypeSystem];
//    [header addSubview:cancelShareButton];
//
//    [cancelShareButton setTitle:[CommonStrings cancelButton] forState:UIControlStateNormal];
//    cancelShareButton.userInteractionEnabled = YES;
//
//    [cancelShareButton autoPinEdgeToSuperviewMargin:ALEdgeLeading];
//    [cancelShareButton autoPinEdgeToSuperviewMargin:ALEdgeBottom];
//    [cancelShareButton setCompressionResistanceHigh];
//    [cancelShareButton setContentHuggingHigh];
//
//    [cancelShareButton addTarget:self
//                          action:@selector(didTapCancelShareButton)
//                forControlEvents:UIControlEventTouchUpInside];

    [header addSubview:searchBar];
//    [searchBar autoPinEdge:ALEdgeLeading toEdge:ALEdgeTrailing ofView:cancelShareButton withOffset:6];
    [searchBar autoPinEdgesToSuperviewEdges];

    UIView *borderView = [UIView new];
    [header addSubview:borderView];

    borderView.backgroundColor = [UIColor colorWithRGBHex:0xbbbbbb];
    [borderView autoSetDimension:ALDimensionHeight toSize:0.5];
    [borderView autoPinWidthToSuperview];
    [borderView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    // UITableViewController.tableHeaderView must have its height set.
    header.frame = CGRectMake(0, 0, 0, (contentVMargin * 2 + searchBar.frame.size.height));

    return header;
}

#pragma mark - SelectThreadViewControllerDelegate

- (nullable NSString *)convertAttachmentToMessageTextIfPossible
{
//    OWSAssertDebug(self.attachments.count == 1);
    if (!self.attachments[0].isConvertibleToTextMessage) {
        return nil;
    }
    if (self.attachments[0].dataLength >= kOversizeTextMessageSizeThreshold) {
        return nil;
    }
    NSData *data = self.attachments[0].data;
    OWSAssertDebug(data.length < kOversizeTextMessageSizeThreshold);
    NSString *_Nullable messageText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [messageText filterStringForDisplay];
}

- (void)threadsWasSelected:(NSArray<TSThread *> *)threads
{
    OWSAssertDebug(self.attachments);
    OWSAssertDebug(threads.count == 1);

    self.thread = threads.firstObject;

    // TODO: 发送名片
//    if (self.attachments[0].isConvertibleToContactShare) {
//        return;
//    }

    NSString *_Nullable messageText = [self convertAttachmentToMessageTextIfPossible];

    if (messageText) {

        [self tryToSendTextMessage:messageText];
    } else {
        
        OWSNavigationController *approvalModal =
            [AttachmentApprovalViewController wrappedInNavControllerWithAttachments:self.attachments delegate:self];
        [self presentViewController:approvalModal animated:YES completion:nil];
    }
}

// override
- (void)dismissPressed:(id)sender
{
    OWSLogDebug(@"%@ tapped dismiss share button", self.logTag);
    [self cancelShareExperience];
}

//- (void)didTapCancelShareButton
//{
//    DDLogDebug(@"%@ tapped cancel share button", self.logTag);
//    [self cancelShareExperience];
//}

- (void)cancelShareExperience
{
    [self.shareViewDelegate shareViewWasCancelled];
}

#pragma mark - AttachmentApprovalViewControllerDelegate

- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval didApproveAttachments:(NSArray<SignalAttachment *> *)attachments
{
//    [ThreadUtil addThreadToProfileWhitelistIfEmptyContactThread:self.thread];
    
    if (!_outgoingMessages) {
        _outgoingMessages = [NSMutableArray new];
    }
    
    // Reset progress in case we're retrying
    self.progressView.progress = 0;
        
//    NSMutableArray <NSString *> *noLongerVerifiedRecipientIds = [NSMutableArray new];
//    for (NSString *recipentId in self.thread.recipientIdentifiers) {
//        if ([[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipentId]
//            == OWSVerificationStateNoLongerVerified) {
//            [noLongerVerifiedRecipientIds addObject:recipentId];
//        }
//    }
//    for (NSString *recipientId in noLongerVerifiedRecipientIds) {
//
//        OWSRecipientIdentity *_Nullable recipientIdentity =
//            [[OWSIdentityManager sharedManager] recipientIdentityForRecipientId:recipientId];
//        OWSAssertDebug(recipientIdentity);
//
//        NSData *identityKey = recipientIdentity.identityKey;
//        OWSAssertDebug(identityKey.length > 0);
//        if (identityKey.length < 1) {
//            continue;
//        }
//
//        [OWSIdentityManager.sharedManager setVerificationState:OWSVerificationStateDefault
//                                                   identityKey:identityKey
//                                                   recipientId:recipientId
//                                         isUserInitiatedChange:YES
//                                           isSendSystemMessage:NO];
//    }
    
    NSMutableArray *newAttachments = attachments.mutableCopy;
    
    [newAttachments enumerateObjectsUsingBlock:^(SignalAttachment * _Nonnull attachment, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([attachment hasError]) {
            DDLogWarn(@"%@ %s Invalid attachment: %@.",
                self.logTag,
                __PRETTY_FUNCTION__,
                attachment ? [attachment errorName] : @"Missing data");
            [self showErrorAlertForAttachment:attachment];
            [newAttachments removeObject:attachment];
        }
    }];
    
    if ([newAttachments count]) {
        [self tryToSendMessageWithAttachment:YES withBlock:^(SendCompletionBlock sendCompletion) {
        
            OWSAssertIsOnMainThread();
            [newAttachments enumerateObjectsUsingBlock:^(SignalAttachment * _Nonnull attachment, NSUInteger idx, BOOL * _Nonnull stop) {

                __block TSOutgoingMessage *outgoingMessage = nil;
                OWSLogInfo(@"SharingThreadPickerViewController -> tryToSendMessage");
                outgoingMessage = [ThreadUtil sendMessageWithAttachment:attachment
                                                               inThread:self.thread
                                                       quotedReplyModel:nil
                                                 preSendMessageCallBack:nil
                                                          messageSender:self.messageSender
                                                             completion:^(NSError *_Nullable error) {
                    OWSLogInfo(@"SharingThreadPickerViewController -> tryToSendMessage -> complete -> timestamp = %llu", outgoingMessage.timestamp);
                                                                 sendCompletion(error, outgoingMessage, idx);
                                                             }];
                OWSLogInfo(@"SharingThreadPickerViewController -> tryToSendMessage -> sending -> timestamp = %llu", outgoingMessage.timestamp);

                // This is necessary to show progress.
                [self.outgoingMessages addObject:outgoingMessage];
            }];
        }
                          fromViewController:attachmentApproval];
    }
}

- (void)showErrorAlertForAttachment:(SignalAttachment *_Nullable)attachment
{
    OWSAssertDebug(attachment == nil || [attachment hasError]);

    NSString *errorMessage
        = (attachment ? [attachment localizedErrorDescription] : [SignalAttachment missingDataErrorMessage]);

    DDLogError(@"%@ %s: %@", self.logTag, __PRETTY_FUNCTION__, errorMessage);

    [OWSAlerts showAlertWithTitle:Localized(
                                      @"ATTACHMENT_ERROR_ALERT_TITLE", @"The title of the 'attachment error' alert.")
                          message:errorMessage];
}

- (void)attachmentApproval:(AttachmentApprovalViewController *)attachmentApproval didCancelAttachments:(NSArray<SignalAttachment *> *)attachments {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (void)tryToSendTextMessage:(NSString *)text {
    [self tryToSendMessageWithAttachment:NO withBlock:^(SendCompletionBlock sendCompletion) {
        OWSAssertIsOnMainThread();
        
        TSOutgoingMessage *outgoingMessage = nil;
        outgoingMessage = [ThreadUtil sendMessageWithText:text
                                                atPersons:nil
                                                 mentions:nil
                                                 inThread:self.thread
                                         quotedReplyModel:nil
                                            messageSender:self.messageSender
                                                  success:^{
            sendCompletion(nil, outgoingMessage, 0);
        } failure:^(NSError * _Nonnull error) {
            sendCompletion(error, outgoingMessage, 0);
        }];
        
        // This is necessary to show progress.
        [self.outgoingMessages addObject:outgoingMessage];
        
    } fromViewController:self];
}

- (void)tryToSendMessageWithAttachment:(BOOL)withAttachment
                             withBlock:(SendMessageBlock)sendMessageBlock
                    fromViewController:(UIViewController *)fromViewController
{
    NSString *progressTitle = Localized(@"SHARE_EXTENSION_SENDING_IN_PROGRESS_TITLE", @"Alert title");
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:progressTitle
                                                                           message:withAttachment ? @"\n" : nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *progressCancelAction = [UIAlertAction actionWithTitle:[CommonStrings cancelButton]
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                                     [self.shareViewDelegate shareViewWasCancelled];
                                                                 }];
    [progressAlert addAction:progressCancelAction];

    // We add a progress subview to an AlertController, which is a total hack.
    // ...but it looks good, and given how short a progress view is and how
    // little the alert controller changes, I'm not super worried about it.
    if (withAttachment) {
        [progressAlert.view addSubview:self.progressView];
        [self.progressView autoPinWidthToSuperviewWithMargin:24];
        [self.progressView autoAlignAxis:ALAxisHorizontal toSameAxisOfView:progressAlert.view withOffset:3];
    }
    
    __block NSUInteger sendedMessageCount = 0;
    __block NSMutableArray <TSOutgoingMessage *> *errorOutgoingMessages = [NSMutableArray new];

    SendCompletionBlock sendCompletion = ^(NSError *_Nullable error, TSOutgoingMessage *message, NSUInteger messageIdx) {

        sendedMessageCount ++;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [errorOutgoingMessages addObject:message];
            }
            if (sendedMessageCount == self.attachments.count) {
                
                if (errorOutgoingMessages.count == 0) {
                    OWSLogInfo(@"%@ Sending message succeeded.", self.logTag);
                    [self.shareViewDelegate shareViewWasCompleted];
                } else {
                    [fromViewController
                        dismissViewControllerAnimated:YES
                                           completion:^(void) {
                                               OWSLogInfo(@"%@ Sending message %lu failed with error: %@", self.logTag, messageIdx, error);
                                               [self showSendFailureAlertWithError:error
                                                                           messages:errorOutgoingMessages
                                                                fromViewController:fromViewController];
                    }];

                }
            } else {
                
            }
        });
    };

    if (![fromViewController.presentedViewController isKindOfClass:UIAlertController.class]) {
        [fromViewController presentViewController:progressAlert
                                         animated:YES
                                       completion:^(void) {
                                           sendMessageBlock(sendCompletion);
        }];
    }
}

- (void)showSendFailureAlertWithError:(NSError *_Nullable)error
                              messages:(NSArray <TSOutgoingMessage *> *)messages
                   fromViewController:(UIViewController *)fromViewController
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(error);
    OWSAssertDebug(messages);
    OWSAssertDebug(fromViewController);

    NSString *failureTitle = Localized(@"SHARE_EXTENSION_SENDING_FAILURE_TITLE", @"Alert title");

    if ([error.domain isEqual:OWSTTServiceKitErrorDomain] && error.code == OWSErrorCodeUntrustedIdentity) {
        NSString *_Nullable untrustedRecipientId = error.userInfo[OWSErrorRecipientIdentifierKey];

        NSString *failureFormat = Localized(@"SHARE_EXTENSION_FAILED_SENDING_BECAUSE_UNTRUSTED_IDENTITY_FORMAT",
            @"alert body when sharing file failed because of untrusted/changed identity keys");

        NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:untrustedRecipientId];
        NSString *failureMessage = [NSString stringWithFormat:failureFormat, displayName];

        UIAlertController *failureAlert = [UIAlertController alertControllerWithTitle:failureTitle
                                                                              message:failureMessage
                                                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *failureCancelAction = [UIAlertAction actionWithTitle:[CommonStrings cancelButton]
                                                                      style:UIAlertActionStyleCancel
                                                                    handler:^(UIAlertAction *_Nonnull action) {
                                                                        [self.shareViewDelegate shareViewWasCancelled];
                                                                    }];
        [failureAlert addAction:failureCancelAction];

        if (untrustedRecipientId.length > 0) {
            UIAlertAction *confirmAction =
                [UIAlertAction actionWithTitle:[SafetyNumberStrings confirmSendButton]
                                         style:UIAlertActionStyleDefault
                                       handler:^(UIAlertAction *action) {
                                           [self confirmIdentityAndResendMessages:messages
                                                                     recipientId:untrustedRecipientId
                                                              fromViewController:fromViewController];
                                       }];

            [failureAlert addAction:confirmAction];
        } else {
            // This shouldn't happen, but if it does we won't offer the user the ability to confirm.
            // They may have to return to the main app to accept the identity change.
            OWSFailDebug(@"Untrusted recipient error is missing recipient id.");
        }

        [fromViewController presentViewController:failureAlert animated:YES completion:nil];
    } else {
        // Non-identity failure, e.g. network offline, rate limit

        UIAlertController *failureAlert = [UIAlertController alertControllerWithTitle:failureTitle
                                                                              message:error.localizedDescription
                                                                       preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *failureCancelAction = [UIAlertAction actionWithTitle:[CommonStrings cancelButton]
                                                                      style:UIAlertActionStyleCancel
                                                                    handler:^(UIAlertAction *_Nonnull action) {
                                                                        [self.shareViewDelegate shareViewWasCancelled];
                                                                    }];
        [failureAlert addAction:failureCancelAction];

        UIAlertAction *retryAction =
            [UIAlertAction actionWithTitle:[CommonStrings retryButton]
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
                                       [self resendMessages:messages fromViewController:fromViewController];
                                   }];

        [failureAlert addAction:retryAction];
        [fromViewController presentViewController:failureAlert animated:YES completion:nil];
    }
}

- (void)confirmIdentityAndResendMessages:(NSArray <TSOutgoingMessage *> *)messages
                            recipientId:(NSString *)recipientId
                     fromViewController:(UIViewController *)fromViewController
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(messages);
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug(fromViewController);

    DDLogDebug(@"%@ Confirming identity for recipient: %@", self.logTag, recipientId);
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        OWSVerificationState verificationState =
        [[OWSIdentityManager sharedManager] verificationStateForRecipientId:recipientId transaction:transaction];
        switch (verificationState) {
            case OWSVerificationStateVerified: {
                OWSFailDebug(@"%@ Shouldn't need to confirm identity if it was already verified", self.logTag);
                break;
            }
            case OWSVerificationStateDefault: {
                // If we learned of a changed SN during send, then we've already recorded the new identity
                // and there's nothing else we need to do for the resend to succeed.
                // We don't want to redundantly set status to "default" because we would create a
                // "You marked Alice as unverified" notice, which wouldn't make sense if Alice was never
                // marked as "Verified".
                OWSLogInfo(@"%@ recipient has acceptable verification status. Next send will succeed.", self.logTag);
                break;
            }
            case OWSVerificationStateNoLongerVerified: {
                OWSLogInfo(@"%@ marked recipient: %@ as default verification status.", self.logTag, recipientId);
                NSData *identityKey =
                [[OWSIdentityManager sharedManager] identityKeyForRecipientId:recipientId transaction:transaction];
                OWSAssertDebug(identityKey);
                [[OWSIdentityManager sharedManager] setVerificationState:OWSVerificationStateDefault
                                                             identityKey:identityKey
                                                             recipientId:recipientId
                                                   isUserInitiatedChange:YES
                                                     isSendSystemMessage:NO
                                                             transaction:transaction];
                break;
            }
        }
        [transaction addAsyncCompletionOnMain:^{
            [self resendMessages:messages fromViewController:fromViewController];
        }];
    });
}

- (void)resendMessages:(NSArray <TSOutgoingMessage *> *)messages fromViewController:(UIViewController *)fromViewController
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(messages);
    OWSAssertDebug(fromViewController);

    NSString *progressTitle = Localized(@"SHARE_EXTENSION_SENDING_IN_PROGRESS_TITLE", @"Alert title");
    UIAlertController *progressAlert = [UIAlertController alertControllerWithTitle:progressTitle
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *progressCancelAction = [UIAlertAction actionWithTitle:[CommonStrings cancelButton]
                                                                   style:UIAlertActionStyleCancel
                                                                 handler:^(UIAlertAction *_Nonnull action) {
                                                                     [self.shareViewDelegate shareViewWasCancelled];
                                                                 }];
    [progressAlert addAction:progressCancelAction];

    __block NSUInteger errorMessageCount = messages.count;
    [fromViewController
        presentViewController:progressAlert
                     animated:YES
                   completion:^(void) {
    
        [messages enumerateObjectsUsingBlock:^(TSOutgoingMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.messageSender enqueueMessage:message
                success:^(void) {
                errorMessageCount --;
                    OWSLogInfo(@"%@ Resending attachment succeeded.", self.logTag);
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        if (errorMessageCount == 0) {
                            [self.shareViewDelegate shareViewWasCompleted];
                        }
                    });
                }
                failure:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        [fromViewController
                            dismissViewControllerAnimated:YES
                                               completion:^(void) {
                                                   OWSLogInfo(@"%@ Sending attachment failed with error: %@",
                                                       self.logTag,
                                                       error);
                                                   [self showSendFailureAlertWithError:error
                                                                               messages:messages
                                                                    fromViewController:fromViewController];
                                               }];
                    });
            }];
        }];
    }];
}

- (void)attachmentUploadProgress:(NSNotification *)notification
{
    DDLogDebug(@"%@ upload progress.", self.logTag);
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.progressView);

    if (!self.outgoingMessages || self.outgoingMessages.count == 0) {
        DDLogDebug(@"%@ Ignoring upload progress until there is an outgoing message.", self.logTag);
        return;
    }

    NSDictionary *userinfo = [notification userInfo];
    float progress = [[userinfo objectForKey:kAttachmentUploadProgressKey] floatValue];
    NSString *attachmentID = [userinfo objectForKey:kAttachmentUploadAttachmentIDKey];

    if (self.outgoingMessages.count == 1) {
        NSString *_Nullable attachmentRecordId = self.outgoingMessages[0].attachmentIds.firstObject;
        if (!attachmentRecordId) {
            DDLogDebug(@"%@ Ignoring upload progress until outgoing message has an attachment record id", self.logTag);
            return;
        }

        if ([attachmentRecordId isEqual:attachmentID]) {
            if (!isnan(progress)) {
                [self.progressView setProgress:progress animated:YES];
            } else {
                OWSFailDebug(@"%@ Invalid attachment progress.", self.logTag);
            }
        }
    } else {
        
        if (progress < 1.f) return;
        __block BOOL containSameId = NO;
        [self.outgoingMessages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(TSOutgoingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *_Nullable attachmentRecordId = self.outgoingMessages[idx].attachmentIds.firstObject;
            if ([attachmentRecordId isEqualToString:attachmentID]) {
                containSameId = YES;
                self.attachmentUploadedCount ++;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressView setProgress:(float)self.attachmentUploadedCount/self.outgoingMessages.count animated:YES];
                });
                OWSLogInfo(@"%lu", self.attachmentUploadedCount);
                *stop = YES;
            }
        }];
        if (!containSameId) {
            OWSFailDebug(@"%@ Invalid attachment progress.", self.logTag);
        }
    }
}

@end

NS_ASSUME_NONNULL_END
