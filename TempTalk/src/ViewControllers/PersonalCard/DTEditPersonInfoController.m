//
//  DTEditPersonInfoController.m
//  Wea
//
//  Created by hornet on 2021/12/1.
//

#import "DTEditPersonInfoController.h"
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/TTServiceKit-swift.h>
#import <TTServiceKit/Localize_Swift.h>

#import "DTTextField.h"
#import "DTTextView.h"

NSUInteger const kDTUserNameMaxLength    = 30;
NSUInteger const kDTUserSignatureLength  = 80;

@interface DTEditPersonInfoController ()<UITextViewDelegate,UITextFieldDelegate>
@property(nonatomic,strong) DTTextField *textField;
@property(nonatomic,strong) DTTextView *textView;
@property(nonatomic,strong) UIView *lineView;
@property(nonatomic,strong) UIButton *saveButton;
@property(nonatomic,copy) NSString *recipientId;
@property(nonatomic,assign) DTEditPersonInfoType edittype;
@property(nonatomic,copy) NSString *defaultEditText;

@end

@implementation DTEditPersonInfoController

- (void)loadView {
    [super loadView];
    self.view.backgroundColor = Theme.backgroundColor;
        self.textView = [[DTTextView alloc] init];
        self.textView.backgroundColor = Theme.searchFieldBackgroundColor;
        self.textView.layoutManager.allowsNonContiguousLayout = false;
        self.textView.textColor = Theme.primaryTextColor;
        self.textView.delegate = self;
        self.textView.layer.cornerRadius = 5;
        self.textView.layer.masksToBounds = true;
        self.textView.keyboardAppearance = Theme.keyboardAppearance;
        self.textView.font = [UIFont systemFontOfSize:17];
        self.lineView = [UIView new];
        self.lineView.backgroundColor = Theme.hairlineColor;
    
    if (self.edittype == DTEditPersonInfoTypeName) {
        self.title = Localized(@"CONTACT_EDIT_NAME", @"Title for editName view.");
    }else {
        self.title = Localized(@"APP_WORK_SIGNATURE", @"Title for editSignature view.");
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
   
    [self.textField becomeFirstResponder];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNavBar];
    [self addsubViews];
    [self configUILayouts];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.textView.text = self.defaultEditText;
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.textField resignFirstResponder];
}
- (void)setNavBar {
    self.saveButton = [[UIButton alloc] init];
    self.saveButton.titleLabel.font = [UIFont ows_regularFontWithSize:17];
    self.saveButton.userInteractionEnabled = NO;
    self.saveButton.selected = false;
    [self.saveButton setTitle:Localized(@"MESSAGE_ACTION_SAVE_MEDIA", @"") forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor ows_darkSkyBlueColor] forState:UIControlStateSelected];
    [self.saveButton addTarget:self action:@selector(saveButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.saveButton];
}
- (void)addsubViews {
    [self.view addSubview:self.textView];
    [self.view addSubview:self.lineView];
}

- (void)saveButtonClick:(UIButton *)sender {
   
    if (self.edittype == DTEditPersonInfoTypeName) {
        NSString *userName = self.textView.text;
        if ([self.textView.text isEqualToString:self.defaultEditText]) {
            [self.navigationController popViewControllerAnimated:true];
        }else {
            userName = [userName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSDictionary *parms = @{@"name":userName};
            [self requestForEditPersonInfoWithParams:parms];
        }
       
    }else {//DTEditPersonInfoTypeSignature
        NSString *signature = self.textView.text;
        if ([self.textView.text isEqualToString:self.defaultEditText]) {
            [self.navigationController popViewControllerAnimated:true];
        } else {
            signature = [signature stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSDictionary *parms = @{@"signature":signature};
            [self requestForEditPersonInfoWithParams:parms];
        }
    }
}

- (void)requestForEditPersonInfoWithParams:(NSDictionary *) parms{
    OWSLogInfo(@"(DTEditPersonInfoController) putV1ProfileWithParams:%@",parms);
    [DTToastHelper showHudInView:self.view];
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (DTParamsUtils.validateDictionary(responseObject)) {
            NSNumber *status = (NSNumber *)responseObject[@"status"];
            if (responseObject && [status intValue] == 0 ) {//上报成功，更新本地缓存
                if (self.edittype == DTEditPersonInfoTypeName) {
                    NSString *userName = [parms objectForKey:@"name"];
                    [self dealPersonInfoNameResponseWithUserName:userName];
                } else {
                    NSString *signature = [parms objectForKey:@"signature"];
                    [self dealPersonInfoNameResponseWithSignature:signature];
                    self.defaultEditText = signature;
                }
            } else {//上报失败
                [DTToastHelper toastWithText:Localized(@"UPDATENAME_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
            }
        } else {
            [DTToastHelper toastWithText:Localized(@"UPDATENAME_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
        }
        
        [DTToastHelper hide];
        
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {//上报失败
        [DTToastHelper hide];
        [DTToastHelper toastWithText:Localized(@"UPDATENAME_FAILED", @"") inView:self.view durationTime:3 afterDelay:0.1];
    }];
}

- (void)dealPersonInfoNameResponseWithUserName:(NSString *)userName {
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transation) {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        account.contact.fullName = userName;
        SignalAccount *newAccount = [account copy];
        [contactsManager updateSignalAccountWithRecipientId:self.recipientId withNewSignalAccount:newAccount withTransaction:transation];
        [self.navigationController popViewControllerAnimated:true];
    });
}

- (void)dealPersonInfoNameResponseWithSignature:(NSString *)signature {
    DatabaseStorageWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transation) {
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        SignalAccount *account = [contactsManager signalAccountForRecipientId:self.recipientId transaction:transation];
        SignalAccount *newAccount = [account copy];
        newAccount.contact = [account.contact copy];
        newAccount.contact.signature = signature;
        [contactsManager updateSignalAccountWithRecipientId:self.recipientId withNewSignalAccount:newAccount withTransaction:transation];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:true];
    });
}

- (void)configureWithRecipientId:(NSString *)recipientId withType:(DTEditPersonInfoType)edittype defaultEditText:(NSString *)editText {
    self.recipientId = recipientId;
    self.edittype = edittype;
    self.defaultEditText = editText;
}

- (void)configUILayouts {
        [self.textView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
        [self.textView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view withOffset:9];
        [self.textView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view withOffset:-9];
        [self.textView autoSetDimension:ALDimensionHeight toSize:120];
        
        [self.lineView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textView ];
        [self.lineView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.textView ];
        [self.lineView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.textView];
        [self.lineView autoSetDimension:ALDimensionHeight toSize:1];
}

#pragma mark - textField Delegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    if ((textField.text.length == 1 && string.length == 0 && self.defaultEditText.length > 0) || (textField.text.length == 0 && string.length == 0 && self.defaultEditText.length > 0)) {
        self.saveButton.selected  = true;
        self.saveButton.userInteractionEnabled = true;
    } else if ((textField.text.length == 1 &&
                string.length == 0 && self.defaultEditText.length == 0) || (textField.text.length == 0 && string.length == 0 && self.defaultEditText.length == 0)) {
        self.saveButton.selected  = false;
        self.saveButton.userInteractionEnabled = false;
    }
    else{
        self.saveButton.selected  = true;
        self.saveButton.userInteractionEnabled = true;
    }

    NSUInteger maxLength = self.edittype == DTEditPersonInfoTypeSignature ? kDTUserSignatureLength : kDTUserNameMaxLength;
    if (textField.text.length > maxLength - 1 && ![textField.text isEqualToString:@""]) {
        return NO;
    }
    
    return YES;
}

- (void)textFieldTextDidChange:(UITextField *)textField {
    NSUInteger maxLength = self.edittype == DTEditPersonInfoTypeSignature ? kDTUserSignatureLength : kDTUserNameMaxLength;
    if (textField.text.length > maxLength) {
        NSString *text = textField.text;
        text = [text substringToIndex:maxLength];
        textField.text = text;
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ((textView.text.length == 1 && text.length == 0 && self.defaultEditText.length > 0) || (textView.text.length == 0 && text.length == 0 && self.defaultEditText.length > 0)) {
        self.saveButton.selected  = true;
        self.saveButton.userInteractionEnabled = true;
    } else if ((textView.text.length == 1 && text.length == 0 && self.defaultEditText.length == 0) || (textView.text.length == 0 && text.length == 0 && self.defaultEditText.length == 0)) {
        self.saveButton.selected  = false;
        self.saveButton.userInteractionEnabled = false;
    }
    else{
        self.saveButton.selected  = true;
        self.saveButton.userInteractionEnabled = true;
    }
    NSUInteger maxLength = self.edittype == DTEditPersonInfoTypeSignature ? kDTUserSignatureLength : kDTUserNameMaxLength;
    if (textView.text.length > maxLength - 1 && ![text isEqualToString:@""]) {
        return NO;
    }

    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    NSUInteger maxLength = self.edittype == DTEditPersonInfoTypeSignature ? kDTUserSignatureLength : kDTUserNameMaxLength;
    if (textView.text.length > maxLength) {
        NSString *text = textView.text;
        text = [text substringToIndex:maxLength];
        textView.text = text;
    }
    if (self.edittype == DTEditPersonInfoTypeName) {
        NSString *strippedText = self.textView.text.ows_stripped;
        self.navigationItem.rightBarButtonItem.enabled = self.textView.text != nil && strippedText.length > 0 && ![strippedText isEqualToString:self.defaultEditText];
    }
}

@end
