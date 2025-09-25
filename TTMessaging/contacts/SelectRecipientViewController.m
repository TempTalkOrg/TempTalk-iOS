//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "SelectRecipientViewController.h"

#import "ViewControllerUtils.h"
#import <TTMessaging/ContactTableViewCell.h>
#import <TTMessaging/ContactsViewHelper.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTMessaging/UIFont+OWS.h>
#import <TTMessaging/UIUtil.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/ContactsUpdater.h>
#import <TTServiceKit/OWSBlockingManager.h>

#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TSAccountManager.h>

#import <SignalCoreKit/NSString+OWS.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const kSelectRecipientViewControllerCellIdentifier = @"kSelectRecipientViewControllerCellIdentifier";

#pragma mark -

@interface SelectRecipientViewController () <
    ContactsViewHelperDelegate,
    UITextFieldDelegate,
    UISearchBarDelegate>

@property (nonatomic, readonly) UITableView *tableView;

@property (nonatomic) UIButton *countryCodeButton;

@property (nonatomic) UITextField *phoneNumberTextField;

@property (nonatomic) OWSFlatButton *phoneNumberButton;

@property (nonatomic) UILabel *examplePhoneNumberLabel;


@property (nonatomic) NSString *callingCode;

@property (nonatomic, strong) OWSSearchBar *searchBar;

@property (nonatomic, strong) NSMutableArray <NSString *> *selectedRecipientIds;

@end

#pragma mark -

@implementation SelectRecipientViewController

- (UITableView *)tableView {
    return self.tableViewController.tableView;
}

- (NSMutableArray<NSString *> *)selectedRecipientIds {
    if (!_selectedRecipientIds) {
        _selectedRecipientIds = [NSMutableArray new];
    }
    return _selectedRecipientIds;;
}

- (void)applyTheme {
    [super applyTheme];
    self.tableView.backgroundColor = Theme.backgroundColor;
}

- (void)loadView
{
    [super loadView];

    self.view.backgroundColor = Theme.backgroundColor;

    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];

    [self createViews];

//    [self populateDefaultCountryNameAndCode];

    if (self.delegate.shouldHideContacts) {
        self.tableView.scrollEnabled = NO;
    }
}

- (void)viewDidLoad
{
    OWSAssertDebug(self.tableViewController);

    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.tableViewController viewDidAppear:animated];

    if ([self.delegate shouldHideContacts]) {
        [self.phoneNumberTextField becomeFirstResponder];
    }
}

- (void)createViews
{
    OWSAssertDebug(self.delegate);

    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    [self.view addSubview:self.tableViewController.view];
    [_tableViewController.view autoPinWidthToSuperview];
    [_tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [_tableViewController.view autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.backgroundColor = Theme.backgroundColor;
    OWSSearchBar *searchBar = [OWSSearchBar new];
    _searchBar = searchBar;
    searchBar.customPlaceholder = Localized(@"SEARCH_BYNAMEORNUMBER_PLACEHOLDER_TEXT",
        @"Placeholder text for search bar which filters contacts.");
    searchBar.delegate = self;
    [searchBar sizeToFit];

    self.tableView.tableHeaderView = searchBar;
    
    [self updateTableContents];

    [self updatePhoneNumberButtonEnabling];
}

- (UILabel *)countryCodeLabel
{
    UILabel *countryCodeLabel = [UILabel new];
    countryCodeLabel.font = [UIFont ows_semiboldFontWithSize:18.f];
    countryCodeLabel.textColor = [UIColor blackColor];
    countryCodeLabel.text
        = Localized(@"REGISTRATION_DEFAULT_COUNTRY_NAME", @"Label for the country code field");
    return countryCodeLabel;
}

- (UILabel *)phoneNumberLabel
{
    UILabel *phoneNumberLabel = [UILabel new];
    phoneNumberLabel.font = [UIFont ows_semiboldFontWithSize:18.f];
    phoneNumberLabel.textColor = [UIColor blackColor];
    phoneNumberLabel.text
        = Localized(@"REGISTRATION_PHONENUMBER_BUTTON", @"Label for the phone number textfield");
    return phoneNumberLabel;
}

- (UIFont *)examplePhoneNumberFont
{
    return [UIFont ows_regularFontWithSize:16.f];
}

- (UILabel *)examplePhoneNumberLabel
{
    if (!_examplePhoneNumberLabel) {
        _examplePhoneNumberLabel = [UILabel new];
        _examplePhoneNumberLabel.font = [self examplePhoneNumberFont];
        _examplePhoneNumberLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.f];
    }

    return _examplePhoneNumberLabel;
}

- (UITextField *)phoneNumberTextField
{
    if (!_phoneNumberTextField) {
        _phoneNumberTextField = [UITextField new];
        _phoneNumberTextField.font = [UIFont ows_semiboldFontWithSize:18.f];
        _phoneNumberTextField.textAlignment = _phoneNumberTextField.textAlignmentUnnatural;
        _phoneNumberTextField.textColor = [UIColor ows_materialBlueColor];
        _phoneNumberTextField.placeholder = Localized(
            @"REGISTRATION_ENTERNUMBER_DEFAULT_TEXT", @"Placeholder text for the phone number textfield");
        _phoneNumberTextField.keyboardType = UIKeyboardTypeNumberPad;
        _phoneNumberTextField.delegate = self;
        [_phoneNumberTextField addTarget:self
                                  action:@selector(textFieldDidChange:)
                        forControlEvents:UIControlEventEditingChanged];
    }

    return _phoneNumberTextField;
}

- (OWSFlatButton *)phoneNumberButton
{
    if (!_phoneNumberButton) {
        const CGFloat kButtonHeight = 40;
        OWSFlatButton *button = [OWSFlatButton buttonWithTitle:[self.delegate phoneNumberButtonText]
                                                          font:[OWSFlatButton fontForHeight:kButtonHeight]
                                                    titleColor:[UIColor whiteColor]
                                               backgroundColor:[UIColor ows_materialBlueColor]
                                                        target:self
                                                      selector:@selector(phoneNumberButtonPressed)];
        _phoneNumberButton = button;
        [button autoSetDimension:ALDimensionWidth toSize:140];
        [button autoSetDimension:ALDimensionHeight toSize:kButtonHeight];
    }
    return _phoneNumberButton;
}

- (UIView *)createRowWithHeight:(CGFloat)height
                    previousRow:(nullable UIView *)previousRow
                      superview:(nullable UIView *)superview
{
    UIView *row = [UIView containerView];
    [superview addSubview:row];
    [row autoPinLeadingAndTrailingToSuperviewMargin];
    if (previousRow) {
        [row autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:previousRow withOffset:0];
    } else {
        [row autoPinEdgeToSuperviewEdge:ALEdgeTop];
    }
    [row autoSetDimension:ALDimensionHeight toSize:height];
    return row;
}

#pragma mark - Country

// TODO: delete
/*
- (void)populateDefaultCountryNameAndCode
{
    PhoneNumber *localNumber = [PhoneNumber phoneNumberFromE164:[TSAccountManager localNumber]];
    OWSAssertDebug(localNumber);

    NSString *countryCode;
    NSNumber *callingCode;
    if (localNumber) {
        callingCode = [localNumber getCountryCode];
        OWSAssertDebug(callingCode);
        if (callingCode) {
            NSString *prefix = [NSString stringWithFormat:@"+%d", callingCode.intValue];
            countryCode = [[PhoneNumberUtil sharedThreadLocal] probableCountryCodeForCallingCode:prefix];
        }
    }

    if (!countryCode || !callingCode) {
        countryCode = [PhoneNumber defaultCountryCode];
        callingCode = [[PhoneNumberUtil sharedThreadLocal].nbPhoneNumberUtil getCountryCodeForRegion:countryCode];
    }

    NSString *countryName = [PhoneNumberUtil countryNameFromCountryCode:countryCode];

    [self updateCountryWithName:countryName
                    callingCode:[NSString stringWithFormat:@"%@%@", COUNTRY_CODE_PREFIX, callingCode]
                    countryCode:countryCode];
}
 */

- (void)updateCountryWithName:(NSString *)countryName
                  callingCode:(NSString *)callingCode
                  countryCode:(NSString *)countryCode
{
    _callingCode = callingCode;

    NSString *titleFormat = (CurrentAppContext().isRTL ? @"(%2$@) %1$@" : @"%1$@ (%2$@)");
    NSString *title = [NSString stringWithFormat:titleFormat, callingCode, countryCode.localizedUppercaseString];
    [self.countryCodeButton setTitle:title forState:UIControlStateNormal];
    [self.countryCodeButton layoutSubviews];

    self.examplePhoneNumberLabel.text =
        [ViewControllerUtils examplePhoneNumberForCountryCode:countryCode callingCode:callingCode];
    [self.examplePhoneNumberLabel.superview layoutSubviews];
}

- (void)setCallingCode:(NSString *)callingCode
{
    _callingCode = callingCode;

    [self updatePhoneNumberButtonEnabling];
}

#pragma mark - Actions

- (void)phoneNumberButtonPressed
{
    [self tryToSelectPhoneNumber];
}

- (void)tryToSelectPhoneNumber
{
    OWSAssertDebug(self.delegate);

    if (![self hasValidPhoneNumber]) {
        OWSFailDebug(@"Invalid phone number was selected.");
        return;
    }

    NSString *rawPhoneNumber = [self.callingCode stringByAppendingString:self.phoneNumberTextField.text.digitsOnly];

    NSMutableArray<NSString *> *possiblePhoneNumbers = [NSMutableArray new];
//    for (PhoneNumber *phoneNumber in
//        [PhoneNumber tryParsePhoneNumbersFromsUserSpecifiedText:rawPhoneNumber
//                                              clientPhoneNumber:[TSAccountManager localNumber]]) {
//        [possiblePhoneNumbers addObject:phoneNumber.toE164];
//    }
    
    if (rawPhoneNumber && rawPhoneNumber.length) {
        [possiblePhoneNumbers addObject:rawPhoneNumber];
    }
    
    if ([possiblePhoneNumbers count] < 1) {
        OWSFailDebug(@"Couldn't parse phone number.");
        return;
    }

    [self.phoneNumberTextField resignFirstResponder];

    // There should only be one phone number, since we're explicitly specifying
    // a country code and therefore parsing a number in e164 format.
    OWSAssertDebug([possiblePhoneNumbers count] == 1);

    if ([self.delegate shouldValidatePhoneNumbers]) {
        // Show an alert while validating the recipient.

        @weakify(self)
        [ModalActivityIndicatorViewController
            presentFromViewController:self
                            canCancel:YES
                      backgroundBlock:^(ModalActivityIndicatorViewController *modalActivityIndicator) {
                          [[ContactsUpdater sharedUpdater] lookupIdentifiers:possiblePhoneNumbers
                              success:^(NSArray<SignalRecipient *> *recipients) {
                                  OWSAssertIsOnMainThread();
                                  OWSAssertDebug(recipients.count > 0);

                              @strongify(self)
                                  if (modalActivityIndicator.wasCancelled) {
                                      return;
                                  }

                                  NSString *recipientId = recipients[0].uniqueId;
                                  [modalActivityIndicator
                                      dismissViewControllerAnimated:NO
                                                         completion:^{
                                                             [self.delegate phoneNumberWasSelected:recipientId];
                                                         }];
                              }
                              failure:^(NSError *error) {
                                  OWSAssertIsOnMainThread();
                                  if (modalActivityIndicator.wasCancelled) {
                                      return;
                                  }
                                  [modalActivityIndicator
                                      dismissViewControllerAnimated:NO
                                                         completion:^{
                                                             [OWSAlerts
                                                                 showErrorAlertWithMessage:error.localizedDescription];
                                                         }];
                              }];
                      }];
    } else {
        NSString *recipientId = possiblePhoneNumbers[0];
        [self.delegate phoneNumberWasSelected:recipientId];
    }
}

- (void)textFieldDidChange:(id)sender
{
    [self updatePhoneNumberButtonEnabling];
}

// TODO: We could also do this in registration view.
- (BOOL)hasValidPhoneNumber
{
    if (!self.callingCode) {
        return NO;
    }
    NSString *possiblePhoneNumber =
        [self.callingCode stringByAppendingString:self.phoneNumberTextField.text.digitsOnly];
//    NSArray<PhoneNumber *> *parsePhoneNumbers =
//        [PhoneNumber tryParsePhoneNumbersFromsUserSpecifiedText:possiblePhoneNumber
//                                              clientPhoneNumber:[TSAccountManager localNumber]];
//    if (parsePhoneNumbers.count < 1) {
//        return NO;
//    }
//    PhoneNumber *parsedPhoneNumber = parsePhoneNumbers[0];
    // It'd be nice to use [PhoneNumber isValid] but it always returns false for some countries
    // (like afghanistan) and there doesn't seem to be a good way to determine beforehand
    // which countries it can validate for without forking libPhoneNumber.
    return possiblePhoneNumber.length > 1;
}

- (void)updatePhoneNumberButtonEnabling
{
    BOOL isEnabled = [self hasValidPhoneNumber];
    self.phoneNumberButton.enabled = isEnabled;
    [self.phoneNumberButton
        setBackgroundColorsWithUpColor:(isEnabled ? [UIColor ows_signalBrandBlueColor] : [UIColor lightGrayColor])];
}

#pragma mark - UITextFieldDelegate

// TODO: This logic resides in both RegistrationViewController and here.
//       We should refactor it out into a utility function.
- (BOOL)textField:(UITextField *)textField
    shouldChangeCharactersInRange:(NSRange)range
                replacementString:(NSString *)insertionText
{
    [ViewControllerUtils phoneNumberTextField:textField
                shouldChangeCharactersInRange:range
                            replacementString:insertionText
                                  countryCode:_callingCode];

    [self updatePhoneNumberButtonEnabling];

    return NO; // inform our caller that we took care of performing the change
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if ([self hasValidPhoneNumber]) {
        [self tryToSelectPhoneNumber];
    }
    return NO;
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSLogInfo(@"==== 执行查询操作 ====");
    
    OWSTableContents *contents = [OWSTableContents new];
    ContactsViewHelper *helper = self.contactsViewHelper;

    if ([self.delegate shouldHideContacts]) {
        return;
    }
    
    NSArray <SignalAccount *> *signalAccounts = nil;
    BOOL hasSearchText = [self.searchBar text].length > 0;

    if (hasSearchText) {
        
        [self contactsSectionsForSearchWithCompletion:^(OWSTableSection * filterSection) {
            [contents addSection:filterSection];
            self.tableViewController.contents = contents;
        }];
    } else {
        
        OWSTableSection *contactsSection = [OWSTableSection new];
        signalAccounts = helper.signalAccounts;
        if (signalAccounts.count == 0) {
            // No Contacts
            OWSTableItem *item = [OWSTableItem softCenterLabelItemWithText:
                     Localized(@"SETTINGS_BLOCK_LIST_NO_CONTACTS",
                                       @"A label that indicates the user has no Signal contacts.")];
            item.canEdit = NO;
            [contactsSection addItem:item];
        } else {
            contactsSection.headerTitle = [self.delegate contactsSectionTitle];
            contactsSection.customHeaderHeight = @(34.f);
            @weakify(self)
            NSArray *memberIds = nil;
            BOOL needFilter = NO;
            if (self.thread) {
                needFilter = YES;
                memberIds = self.thread.recipientIdentifiers;
            }
            // Contacts
            for (SignalAccount *signalAccount in signalAccounts) {
                
                if (needFilter && [memberIds containsObject:signalAccount.recipientId]) {
                    continue;
                }
                
                if (signalAccount.contact.isExternal) {
                    continue;
                }
                
                if (self.from == SelectRecipientFrom_Meeting && signalAccount.recipientId.length <= 6) { // meeting 不能邀请 bot
                    continue;
                }
                OWSTableItem *item = [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
                    @strongify(self)

                    ContactTableViewCell *cell = [ContactTableViewCell new];
                    cell.tintColor = [UIColor ows_materialBlueColor];
                    BOOL isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
                    if (isBlocked) {
                        cell.accessoryMessage = Localized(@"CONTACT_CELL_IS_BLOCKED",
                                                                  @"An indicator that a contact has been blocked.");
                    } else {
                        cell.accessoryMessage =
                        [self.delegate accessoryMessageForSignalAccount:signalAccount];
                    }
                    if ([signalAccount.recipientId isEqualToString:TSAccountManager.localNumber]) {
                        cell.cellView.type = UserOfSelfIconTypeRealAvater;
                    }
                    [cell configureWithSignalAccount:signalAccount
                                     contactsManager:helper.contactsManager];
                    
                    if (self.delegate) {
                        
                        if ([self.delegate respondsToSelector:@selector(canSignalAccountBeSelected:)] &&
                            ![self.delegate canSignalAccountBeSelected:signalAccount]) {
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.selected = YES;
                        }
                        
                        if ([self.delegate respondsToSelector:@selector(canMeetingMemberBeSelected:)] &&
                            ![self.delegate canMeetingMemberBeSelected:signalAccount]) {
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        }
                    }

                    return cell;
                } customRowHeight:70 actionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath){
                    @strongify(self)
                    
                    if (!self.delegate) {
                        return;
                    }
                    if (![self.delegate canSignalAccountBeSelected:signalAccount]) {
                        [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
                        return;
                    }
                    
                    [self allResignFirstResponder];
                    
                    if ([self.delegate respondsToSelector:@selector(signalAccountWasSelected:)]) {
                        [self.delegate signalAccountWasSelected:signalAccount];
                    }
                    if ([self.delegate respondsToSelector:@selector(signalAccountWasSelected:withIndexPath:)]) {
                        [self.delegate signalAccountWasSelected:signalAccount withIndexPath:indexPath];
                    }
                    [self.selectedRecipientIds addObject:signalAccount.recipientId];
                    
                } deselectActionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath) {
                    @strongify(self)
                    if (!self.delegate) {
                        return;
                    }
                    if ([self.delegate respondsToSelector:@selector(signalAccountWasUnSelected:)]) {
                        [self.delegate signalAccountWasUnSelected:signalAccount];
                    }
                    if ([self.delegate respondsToSelector:@selector(signalAccountWasUnSelected:withIndexPath:)]) {
                        [self.delegate signalAccountWasUnSelected:signalAccount withIndexPath:indexPath];
                    }
                    [self.selectedRecipientIds removeObject:signalAccount.recipientId];
                }];
                item.canEdit = YES;
                [contactsSection addItem:item];
            }
        }
        [contents addSection:contactsSection];
        
        self.tableViewController.contents = contents;
    }
        
}

- (void)originalTableView:(UITableView *)tableView
          willDisplayCell:(UITableViewCell *)cell
        forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (![cell isKindOfClass:ContactTableViewCell.class]) {
        return;
    }
    
    ContactTableViewCell *contactCell = (ContactTableViewCell *)cell;
    SignalAccount *signalAccount = contactCell.signalAccount;
    NSString *virtualUserId = contactCell.cellView.virtualUserId;

    BOOL isSelectedSignalAccount = [self.selectedRecipientIds containsObject:signalAccount.recipientId];
    
    /// 非本地通讯录生成的虚拟用户, 唯一标识为uid || email
    BOOL isSelectedVirtualUser = NO;
    if (DTParamsUtils.validateString(virtualUserId)) {
        isSelectedVirtualUser = [self.selectedRecipientIds containsObject:virtualUserId];
    }
    if (isSelectedSignalAccount || isSelectedVirtualUser) {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

- (void)contactsSectionsForSearchWithCompletion:(void(^)(OWSTableSection *))completion
{
    ContactsViewHelper *helper = self.contactsViewHelper;

    OWSTableSection *filteredSection = [OWSTableSection new];
    // Contacts, filtered with the search text.
    __block NSArray<SignalAccount *> *filteredSignalAccounts = nil;
    NSString *searchString = self.searchBar.text;
    __block NSArray <NSString *> *noResultSearchKeys = nil;
    [self.databaseStorage asyncReadWithBlock:^(SDSAnyReadTransaction * transaction) {
        filteredSignalAccounts = [self filteredSignalAccountsWithSearchString:searchString
                                                                  transaction:transaction
                                                           noResultSearchKeys:&noResultSearchKeys];
    } completion:^{
        BOOL hasSearchResults = filteredSignalAccounts.count > 0;
        
        if (!hasSearchResults && !DTParamsUtils.validateArray(noResultSearchKeys)) {
            // No Search Results
            OWSTableSection *noResultsSection = [OWSTableSection new];
            OWSTableItem *item = [OWSTableItem softCenterLabelItemWithText:
                                      Localized(@"SETTINGS_BLOCK_LIST_NO_SEARCH_RESULTS",
                                                @"A label that indicates the user's search has no matching results.")
                                                               customRowHeight:80];
            item.canEdit = NO;
            [noResultsSection addItem:item];

            if(completion){
                completion(noResultsSection);
            }
        } else {
            filteredSection.headerTitle = [self.delegate contactsSectionTitle];;
            filteredSection.customHeaderHeight = @(34);
        }

        NSArray *memberIds = nil;
        BOOL needFilter = NO;
        if (self.thread) {
            needFilter = YES;
            memberIds = self.thread.recipientIdentifiers;
        }

        for (SignalAccount *signalAccount in filteredSignalAccounts) {
            
            if (needFilter && [memberIds containsObject:signalAccount.recipientId]) {
                continue;
            }
            
            if (signalAccount.contact.isExternal) {
                continue;
            }
            
            if (self.from == SelectRecipientFrom_Meeting && signalAccount.recipientId.length <= 6) { // 搜索时 meeting 不能邀请 bot
                continue;
            }
            
            @weakify(self)
            OWSTableItem *item = [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
                @strongify(self)
                
                ContactTableViewCell *cell = [ContactTableViewCell new];
                cell.tintColor = [UIColor ows_materialBlueColor];
                BOOL isBlocked = [helper isRecipientIdBlocked:signalAccount.recipientId];
                if (isBlocked) {
                    cell.accessoryMessage = Localized(@"CONTACT_CELL_IS_BLOCKED",
                                                              @"An indicator that a contact has been blocked.");
                } else {
                    cell.accessoryMessage =
                    [self.delegate accessoryMessageForSignalAccount:signalAccount];
                }
                
                if ([signalAccount.recipientId isEqualToString:TSAccountManager.localNumber]) {
                    cell.cellView.type = UserOfSelfIconTypeRealAvater;
                }
                
                [cell configureWithSignalAccount:signalAccount
                                 contactsManager:helper.contactsManager];
                
                if (self.delegate) {
                    
                    if ([self.delegate respondsToSelector:@selector(canSignalAccountBeSelected:)] &&
                        ![self.delegate canSignalAccountBeSelected:signalAccount]) {
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                        cell.selected = YES;
                    }
                    
                    if ([self.delegate respondsToSelector:@selector(canMeetingMemberBeSelected:)] &&
                        ![self.delegate canMeetingMemberBeSelected:signalAccount]) {
                        cell.selectionStyle = UITableViewCellSelectionStyleNone;
                    }
                }
                
                return cell;
            } customRowHeight:70 actionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath){
                @strongify(self)
                if (![self.delegate canSignalAccountBeSelected:signalAccount]) {
                    return;
                }
                [self allResignFirstResponder];
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(signalAccountWasSelected:)]) {
                    [self.delegate signalAccountWasSelected:signalAccount];
                }
                
                if (self.delegate  && [self.delegate respondsToSelector:@selector(signalAccountWasSelected:withIndexPath:)]) {
                    [self.delegate signalAccountWasSelected:signalAccount withIndexPath:indexPath];
                }
                [self.selectedRecipientIds addObject:signalAccount.recipientId];
            } deselectActionWithIndexPathBlock:^(NSIndexPath * _Nonnull indexPath){
                @strongify(self)
                if (self.delegate && [self.delegate respondsToSelector:@selector(signalAccountWasUnSelected:)]) {
                    [self.delegate signalAccountWasUnSelected:signalAccount];
                }
                if (self.delegate && [self.delegate respondsToSelector:@selector(signalAccountWasUnSelected:withIndexPath:)]) {
                    [self.delegate signalAccountWasUnSelected:signalAccount withIndexPath:indexPath];
                }
                [self.selectedRecipientIds removeObject:signalAccount.recipientId];
            }];
            item.canEdit = YES;
            [filteredSection addItem:item];
        }
        
        if (self.delegate && DTParamsUtils.validateArray(noResultSearchKeys)) {
      
            @weakify(self)
            for (NSString *noResultSearchKey in noResultSearchKeys) {
                NSString *lowercaseKey = [noResultSearchKey lowercaseString];
                OWSTableItem *item = [OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
                    @strongify(self)
                    ContactTableViewCell *cell = [ContactTableViewCell new];
                    cell.tintColor = [UIColor ows_materialBlueColor];
                    [cell.cellView setAvatar:lowercaseKey displayName:@""];
                    [cell.cellView setUserName:lowercaseKey isExt:NO];
                    
                    if ([self.delegate respondsToSelector:@selector(canUserIdOrEmailBeSelected:)]) {
                        BOOL canBeSelected = [self.delegate canUserIdOrEmailBeSelected:lowercaseKey];
                        if (!canBeSelected) {
                            cell.selectionStyle = UITableViewCellSelectionStyleNone;
                            cell.selected = YES;
                        }
                    }
                                    
                    return cell;
                } customRowHeight:70 actionBlock:^ {
                    @strongify(self)
                    if (![self.delegate canUserIdOrEmailBeSelected:lowercaseKey]) {
                        return;
                    }
                    [self allResignFirstResponder];

                    if ([self.delegate respondsToSelector:@selector(userIdOrEmailWasSelected:)]) {
                        [self.delegate userIdOrEmailWasSelected:lowercaseKey];
                    }
                    [self.selectedRecipientIds addObject:lowercaseKey];
                } deselectActionBlock:^{
                    @strongify(self)
                    if (self.delegate && [self.delegate respondsToSelector:@selector(userIdOrEmailWasUnselected:)]) {
                        [self.delegate userIdOrEmailWasUnselected:lowercaseKey];
                    }
                    [self.selectedRecipientIds removeObject:lowercaseKey];
                }];
                item.canEdit = YES;
                [filteredSection addItem:item];
            }
        }
        
        if(completion){
            completion(filteredSection);
        }
    }];
}

- (void)phoneNumberRowTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.phoneNumberTextField becomeFirstResponder];
    }
}

- (void)countryRowTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
    }
}

/// Description
/// - Parameters:
///   - searchString: searchString
///   - transaction: transaction
///   - noResultSearchString: email和符合wea的userId
- (NSArray<SignalAccount *> *)filteredSignalAccountsWithSearchString:(NSString *)searchString
                                                         transaction:(SDSAnyReadTransaction *)transaction
                                                  noResultSearchKeys:(NSArray <NSString *> **)noResultSearchKeys
{
    ContactsViewHelper *helper = self.contactsViewHelper;
    NSString *strippedString = [searchString ows_stripped];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(customUserConditions:)]) {
        NSArray <NSString *> *searchTexts = [[strippedString componentsSeparatedByString:@","]
                                             map:^NSString *(NSString *item) {
            return [item ows_stripped];
        }];
        NSMutableArray <SignalAccount *> *matchingAccounts = @[].mutableCopy;
        NSMutableArray <NSString *> *tmpNoResultSearchKeys = @[].mutableCopy;
        
        BOOL hiddenSelf = [self.delegate shouldHideLocalNumber];
        [searchTexts enumerateObjectsUsingBlock:^(NSString * _Nonnull obj,
                                                  NSUInteger idx,
                                                  BOOL * _Nonnull stop) {
            NSArray<SignalAccount *> *subMatchingAccounts = [helper signalAccountsMatchingSearchString:obj
                                                                                           transaction:transaction];
            subMatchingAccounts = [subMatchingAccounts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SignalAccount *signalAccount, NSDictionary<NSString *, id> *_Nullable bindings) {
                
                if ([signalAccount.recipientId isEqualToString:TSAccountManager.localNumber]) {
                    return !hiddenSelf;
                }
                return ![matchingAccounts containsObject:signalAccount] &&
                       !signalAccount.contact.isExternal &&
                       signalAccount.recipientId.length > 6;
            }]];
            if (subMatchingAccounts.count > 0) {
                [matchingAccounts addObjectsFromArray:subMatchingAccounts];
            } else {
                BOOL isMatch = [self.delegate customUserConditions:obj];
                if (isMatch) {
                    [tmpNoResultSearchKeys addObject:obj];
                }
            }
        }];
        
        *noResultSearchKeys = tmpNoResultSearchKeys.copy;
        return matchingAccounts;
    }
    
    NSArray<SignalAccount *> *matchingAccounts = [helper signalAccountsMatchingSearchString:searchString transaction:transaction];
    return matchingAccounts;
//    [matchingAccounts
//        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SignalAccount *signalAccount,
//                                        NSDictionary<NSString *, id> *_Nullable bindings) {
//        
//        return ![signalAccount.recipientId isEqualToString:[TSAccountManager localNumber]];
//    }]];
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    [self allResignFirstResponder];
}

- (void)allResignFirstResponder {
    [self.phoneNumberTextField resignFirstResponder];
    [self.searchBar resignFirstResponder];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return [self.delegate shouldHideLocalNumber];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self searchTextDidChange];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
    [self searchTextDidChange];
}

- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope
{
    [self searchTextDidChange];
}

- (void)searchTextDidChange
{
//    [self updateSearchPhoneNumbers];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTableContents) object:nil];
    [self performSelector:@selector(updateTableContents) withObject:nil afterDelay:0.4];
//    [self updateTableContents];
}

@end

NS_ASSUME_NONNULL_END
