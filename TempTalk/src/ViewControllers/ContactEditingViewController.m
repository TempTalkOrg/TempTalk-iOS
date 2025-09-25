//
//  ContactEditingViewController.m
//  Signal
//
//  Created by anonoymous on 2019/4/3.
//  Copyright © 2019 anonoymous. All rights reserved.
//

#import "ContactEditingViewController.h"
#import "AppDelegate.h"
#import "TempTalk-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <SignalCoreKit/NSString+OWS.h>
//#import <TTMessaging/TTMessaging-Swift.h>
#import <SignalCoreKit/NSDate+OWS.h>

@interface ContactEditingViewController () <UITextFieldDelegate, OWSNavigationChildController>

@property (nonatomic) NSString *recipientId;

@property (nonatomic) UITextField *remarkTextField;

@property (nonatomic) BOOL hasUnsavedChanges;

@property (nonatomic) BOOL isNeverSetRemark;

@property (nonatomic, readonly) OWSContactsManager *contactsManager;

@end

@implementation ContactEditingViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _contactsManager = Environment.shared.contactsManager;
    
    return self;
}

- (void)configureWithRecipientId:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);

    _recipientId = recipientId;
}

- (void)loadView
{
    [super loadView];

    self.title = Localized(@"CONTACT_EDITING_VIEW_TITLE", @"Title for the contact editing view.");

    [self createViews];
    [self updateNavigationItem];
}

- (void)createViews
{
    self.view.backgroundColor = [UIColor colorWithRGBHex:0xefeff4];

    UIView *contentView = [UIView containerView];
    contentView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:contentView];
    [contentView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [contentView autoPinWidthToSuperview];

    const CGFloat fontSizePoints = ScaleFromIPhone5To7Plus(16.f, 20.f);
    NSMutableArray<UIView *> *rows = [NSMutableArray new];

    // RemarkName 备注名
    UIView *remarkNameRow = [UIView containerView];
    remarkNameRow.userInteractionEnabled = YES;
    [remarkNameRow
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nameRowTapped:)]];
    [rows addObject:remarkNameRow];

    UILabel *remarkNameLabel = [UILabel new];
    remarkNameLabel.text = Localized(
        @"CONTACT_REMARK_NAME_FIELD", @"Label for the remark name field of the contact setting view.");
    remarkNameLabel.textColor = [UIColor blackColor];
    remarkNameLabel.font = [UIFont ows_semiboldFontWithSize:fontSizePoints];
    [remarkNameRow addSubview:remarkNameLabel];
    [remarkNameLabel autoPinLeadingToSuperviewMargin];
    [remarkNameLabel autoPinHeightToSuperviewWithMargin:5.f];

    UITextField *remarkTextField;
    if (UIDevice.currentDevice.isIPhone5OrShorter) {
        remarkTextField = [DismissableTextField new];
    } else {
        remarkTextField = [UITextField new];
    }
    _remarkTextField = remarkTextField;
    remarkTextField.font = [UIFont ows_semiboldFontWithSize:18.f];
    remarkTextField.textColor = [UIColor ows_materialBlueColor];
    remarkTextField.placeholder = Localized(
        @"CONTACT_REMARK_NAME_DEFAULT_TEXT", @"Default text for the remark name field.");
    remarkTextField.delegate = self;
    remarkTextField.text = [self remarkNameOrRecommendationNameForRecipientId:_recipientId];
    remarkTextField.textAlignment = NSTextAlignmentRight;
    remarkTextField.font = [UIFont ows_semiboldFontWithSize:fontSizePoints];
    [remarkTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [remarkNameRow addSubview:remarkTextField];
    [remarkTextField autoPinLeadingToTrailingEdgeOfView:remarkNameLabel offset:10.f];
    [remarkTextField autoPinTrailingToSuperviewMargin];
    [remarkTextField autoVCenterInSuperview];

    // Row Layout
    UIView *_Nullable lastRow = nil;
    for (UIView *row in rows) {
        [contentView addSubview:row];
        if (lastRow) {
            [row autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastRow withOffset:5.f];
        } else {
            [row autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:15.f];
        }
        [row autoPinLeadingToSuperviewMarginWithInset:18.f];
        [row autoPinTrailingToSuperviewMarginWithInset:18.f];
        lastRow = row;

        if (lastRow == remarkNameRow) {
            UIView *separator = [UIView containerView];
            separator.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1.f];
            [contentView addSubview:separator];
            [separator autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lastRow withOffset:5.f];
            [separator autoPinLeadingToSuperviewMarginWithInset:18.f];
            [separator autoPinTrailingToSuperviewMarginWithInset:18.f];
            [separator autoSetDimension:ALDimensionHeight toSize:1.f];
            lastRow = separator;
        }
    }
    [lastRow autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:10.f];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self.remarkTextField becomeFirstResponder];
}

#pragma mark - Event Handling

- (void)backOrSkipButtonPressed
{
    [self leaveViewCheckingForUnsavedChanges];
}

- (void)leaveViewCheckingForUnsavedChanges
{
    [self.remarkTextField resignFirstResponder];

    if (!self.hasUnsavedChanges) {
        // If user made no changes, return to conversation settings view.
        [self profileCompletedOrSkipped];
        return;
    }

    UIAlertController *controller = [UIAlertController
        alertControllerWithTitle:
            Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_TITLE",
                @"The alert title if user tries to exit the new group view without saving changes.")
                         message:
                             Localized(@"NEW_GROUP_VIEW_UNSAVED_CHANGES_MESSAGE",
                                 @"The alert message if user tries to exit the new group view without saving changes.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [controller
        addAction:[UIAlertAction actionWithTitle:Localized(@"ALERT_DISCARD_BUTTON",
                                                     @"The label for the 'discard' button in alerts and action sheets.")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                             [self profileCompletedOrSkipped];
                                         }]];
    [controller addAction:[OWSAlerts cancelAction]];
    [self presentViewController:controller animated:YES completion:nil];
}

- (NSString *)remarkNameOrRecommendationNameForRecipientId:(NSString *)recipientId
{
    SignalAccount* signalAccount = [_contactsManager signalAccountForRecipientId:recipientId];
    if (signalAccount.remarkName.length > 0) {
        [self setIsNeverSetRemark:NO];
        return signalAccount.remarkName;
    } else {
        [self setIsNeverSetRemark:YES];
        return [_contactsManager displayNameForPhoneIdentifier:_recipientId];;
    }
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
    _hasUnsavedChanges = hasUnsavedChanges;

    [self updateNavigationItem];
}

- (void)updateNavigationItem
{
    if (self.hasUnsavedChanges || self.isNeverSetRemark) {
        // If we have a unsaved changes, right item should be a "save" button.
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                          target:self
                                                          action:@selector(updatePressed)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)nameRowTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.remarkTextField becomeFirstResponder];
    }
}

- (void)updatePressed
{
    // save updated remark name
//    __weak ContactEditingViewController *weakSelf = self;
//     [_contactsManager updateSignalAccountWithRecipientId:_recipientId
//                                               remarkName:[weakSelf normalizedRemarkName]];
//    
//    [self profileCompletedOrSkipped];
}

- (NSString *)normalizedRemarkName
{
    return [self.remarkTextField.text ows_stripped];
}

- (void)profileCompletedOrSkipped
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)editingRange
                replacementString:(NSString *)insertionText
{
    return [TextFieldHelper textField:textField
        shouldChangeCharactersInRange:editingRange
                    replacementString:insertionText
                         maxByteCount:kOWSProfileManager_MaxNameLengthBytes];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    return NO;
}

- (void)textFieldDidChange:(id)sender
{
    self.hasUnsavedChanges = YES;
}

- (UIViewController *)fromViewController
{
    return self;
}

#pragma mark - OWSNavigationChildController

- (id<OWSNavigationChildController> _Nullable)childForOWSNavigationConfiguration {
    return nil;
}

- (BOOL)shouldCancelNavigationBack {
    BOOL result = self.hasUnsavedChanges;
    if (result) {
        [self backOrSkipButtonPressed];
    }
    return result;
}

- (UIColor * _Nullable)navbarBackgroundColorOverride {
    return nil;
}

- (BOOL)prefersNavigationBarHidden {
    return false;
}

- (UIColor * _Nullable)navbarTintColorOverride {
    return nil;
}


@end
