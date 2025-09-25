//
//  DTEditRemarkController.m
//  Wea
//
//  Created by hornet on 2022/12/19.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTEditRemarkController.h"
#import "TempTalk-Swift.h"
#import "DTTextField.h"
#import "DTSetConversationApi.h"
#import "DTConversationSettingHelper.h"
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/NSError+errorMessage.h>
#import <TTServiceKit/Localize_Swift.h>

NSUInteger const kMaxNameLength = 30;

@interface DTEditRemarkController ()<OWSTableViewControllerDelegate, UITextFieldDelegate>
@property (nonatomic, strong) NSString *recipientId;
@property (nonatomic, strong) NSString *defaultRemark;

@property (nonatomic, strong) OWSTableViewController *tableViewController;
@property (nonatomic, strong) Contact *contact;
@property (nonatomic, strong) UIButton *donebutton;
@property (nonatomic, strong) DTSetConversationApi *setConversationApi;
@property (nonatomic, strong) DTTextField *remarkNameTextField;
@end

@implementation DTEditRemarkController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNav];
    [self setupUI];
    [self configLayout];
    [self updateTableContents];
    [self.remarkNameTextField becomeFirstResponder];
}

- (void)setupNav {
    UIBarButtonItem *leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(goBack)];
    self.donebutton = [UIButton new];
    [self.donebutton setTitle:Localized(@"BUTTON_DONE",@"") forState:UIControlStateNormal];
    [self.donebutton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [self.donebutton setTitleColor:[UIColor ows_darkSkyBlueColor] forState:UIControlStateSelected];
    [self.donebutton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.donebutton.selected = false;
    UIBarButtonItem *doneBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.donebutton];
    
    self.navigationItem.leftBarButtonItems = @[leftBarButtonItem];
    self.navigationItem.rightBarButtonItems = @[doneBarButtonItem];
    
}

- (void)setupUI {
    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    _tableViewController.view.backgroundColor = Theme.backgroundColor;
    [self.view addSubview:self.tableViewController.view];
}

- (void)configLayout {
   
    [_tableViewController.view autoPinWidthToSuperview];
    [_tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
    [_tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableViewController.tableView.estimatedRowHeight = 60;
    self.tableViewController.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableViewController.tableView.backgroundColor = Theme.backgroundColor;
}

- (void)updateTableContents {
    
    @weakify(self)
    OWSTableContents *contents = [OWSTableContents new];
    OWSTableSection *headerSection = [OWSTableSection new];
    [headerSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self headerCell];
    } customRowHeight:120 actionBlock:^{
    }]];
    [contents addSection:headerSection];
    
    OWSTableSection *editRemarkSection = [OWSTableSection new];
    editRemarkSection.headerTitle = Localized([self isCurrentAccount] ? @"NAME" : @"CONTACT_REMARK",@"");
    [editRemarkSection addItem:[OWSTableItem itemWithCustomCellBlock:^UITableViewCell * _Nonnull{
        @strongify(self)
        return [self editRemarkCell];
    } customRowHeight:UITableViewAutomaticDimension actionBlock:^{
    }]];
    [contents addSection:editRemarkSection];
    self.tableViewController.contents = contents;
}

#pragma mark textField delegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    
    if ((textField.text.length == 1 && string.length == 0 && self.defaultRemark.length > 0) || (textField.text.length == 0 && string.length == 0 && self.defaultRemark.length > 0)) {
        self.self.donebutton.selected  = true;
        self.self.donebutton.userInteractionEnabled = true;
    } else if ((textField.text.length == 1 &&
                string.length == 0 && self.defaultRemark.length == 0) || (textField.text.length == 0 && string.length == 0 && self.defaultRemark.length == 0)) {
        self.self.donebutton.selected  = false;
        self.self.donebutton.userInteractionEnabled = false;
    }
    else{
        self.self.donebutton.selected  = true;
        self.self.donebutton.userInteractionEnabled = true;
    }

    if (string.length == 0) {
        return YES;
    }
    
    NSUInteger maxLength = kMaxNameLength;
    if (textField.text.length > maxLength - 1 && ![textField.text isEqualToString:@""]) {
        return NO;
    }
    
    return YES;
}

- (void)textFieldValueChange:(UITextField *)textField {
    NSUInteger maxLength = kMaxNameLength;
    if (textField.text.length > maxLength) {
        NSString *text = textField.text;
        text = [text substringToIndex:maxLength];
        textField.text = text;
    }

    if ([self isCurrentAccount] && textField.text.length == 0) {
        self.donebutton.selected = false;
        self.donebutton.userInteractionEnabled = false;
    } else if (![self isCurrentAccount] && self.defaultRemark.length > 0) {
        self.self.donebutton.selected  = true;
        self.self.donebutton.userInteractionEnabled = true;
    }
}

- (BOOL)isCurrentAccount {
    return [self.recipientId isEqualToString:[TSAccountManager sharedInstance].localNumber];
}

- (UITableViewCell *)headerCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.separatorInset = UIEdgeInsetsMake(0, UIScreen.mainScreen.bounds.size.width, 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = Theme.backgroundColor;
    cell.contentView.backgroundColor = Theme.backgroundColor;
   
    UILabel *titleLabel = [UILabel new];
    titleLabel.text = Localized([self isCurrentAccount] ? @"CONTACT_SET_NAME" : @"CONTACT_EDIT_REMARK", @"");
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    titleLabel.textColor = Theme.primaryTextColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    
    [cell.contentView addSubview:titleLabel];
    [titleLabel autoPinEdgesToSuperviewMargins];
    
    return cell;
}


- (UITableViewCell *)editRemarkCell {
    UITableViewCell *cell = [OWSTableItem newCell];
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.separatorInset = UIEdgeInsetsMake(0, UIScreen.mainScreen.bounds.size.width, 0, 0);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = Theme.backgroundColor;
    cell.contentView.backgroundColor = Theme.backgroundColor;
   
    DTTextField *remarkNameTextField = [DTTextField new];
    remarkNameTextField.font = [UIFont fontWithName:@"PingFangSC-Medium" size:20];
    remarkNameTextField.textColor = Theme.primaryTextColor;
    NSString *remark = [[DTConversationSettingHelper sharedInstance] decryptRemarkString:self.contact.remark receptid:self.recipientId];
    remarkNameTextField.text = DTParamsUtils.validateString(remark) ? remark : self.contact.fullName;
    [remarkNameTextField autoSetDimension:ALDimensionHeight toSize:44];
    remarkNameTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [remarkNameTextField addTarget:self action:@selector(textFieldValueChange:) forControlEvents:UIControlEventEditingChanged];
    remarkNameTextField.delegate = self;
    self.remarkNameTextField = remarkNameTextField;
    [cell.contentView addSubview:remarkNameTextField];
    
    [remarkNameTextField autoPinEdgesToSuperviewMargins];
    remarkNameTextField.backgroundColor = Theme.searchFieldBackgroundColor;
    remarkNameTextField.layer.cornerRadius = 5;
    
    return cell;
}

- (void)goBack {
    NSArray *viewControllers = [self.navigationController viewControllers];
    if (viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self.navigationController dismissViewControllerAnimated:YES completion: NULL];
    }
}

- (void)doneButtonPressed:(UIButton *)sender {
    NSString *remark = [self.remarkNameTextField.text ows_stripped];
    if ([remark isEqualToString:[self.defaultRemark ows_stripped]]) {
        [self goBack];
    } else if ([self isCurrentAccount]) {
        
    } else {
        remark = [remark stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self requestForEditPersonRemarkInfoWithRemarkName:remark];
    }
}

- (void)requestForEditPersonRemarkInfoWithRemarkName:(NSString *) remarkName {
    NSString *aesString = nil;
    if(DTParamsUtils.validateString(remarkName)){
        aesString = [[DTConversationSettingHelper sharedInstance] encryptRemarkString:remarkName receptid:self.recipientId];
    } else {
        aesString = @"";
    }
    [DTToastHelper showHudInView:self.view];
    [self.setConversationApi requestConfigConractRemarkWithConversationID:self.recipientId remark:aesString success:^(DTConversationEntity * _Nonnull entity) {
        [DTToastHelper hide];
        self.donebutton.selected = false;
        self.defaultRemark = self.remarkNameTextField.text;
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            SignalAccount *account = [SignalAccount anyFetchWithUniqueId:self.recipientId transaction:writeTransaction];
            account.contact.remark = DTParamsUtils.validateString(remarkName) ? [[DTConversationSettingHelper sharedInstance] decryptRemarkString:entity.remark receptid:self.recipientId] : @"";
            OWSContactsManager *contactsManager = Environment.shared.contactsManager;
            [contactsManager updateSignalAccountWithRecipientId:self.recipientId withNewSignalAccount:account withTransaction:writeTransaction];
            [writeTransaction addAsyncCompletionOnMain:^{
                [self goBack];
            }];
        });
    } failure:^(NSError * _Nonnull error) {
        [DTToastHelper hide];
        NSString *errorMsg = [NSError errorDesc:error errResponse:nil];
        [DTToastHelper toastWithText:errorMsg];
    }];
}

- (void)configureWithRecipientId:(NSString *)recipientId defaultRemarkText:(NSString *)remark {
    self.recipientId = recipientId;
    self.defaultRemark = remark;
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
    self.contact = account.contact;
}


- (DTSetConversationApi *)setConversationApi {
    if(!_setConversationApi){
        _setConversationApi = [DTSetConversationApi new];
    }
    return _setConversationApi;
}

@end
