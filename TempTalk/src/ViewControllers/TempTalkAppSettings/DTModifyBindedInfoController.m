//
//  DTModifyBindedInfoController.m
//  Signal
//
//  Created by hornet on 2023/6/12.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTModifyBindedInfoController.h"

#import "DTSignInController.h"
#import "DTTextField.h"
#import <TTServiceKit/DTToastHelper.h>
#import "DTVerificationCodeController.h"
#import "TempTalk-Swift.h"
#import "AppDelegate.h"
#import "DTChatLoginUtils.h"
#import <TTServiceKit/Localize_Swift.h>

extern NSString *const kSendEmailCodeSucess;
extern NSString *const kSendEmailCodeForLoginSucess;
extern NSString *const kSendPhoneCodeForLoginSucess;

extern NSString *const kSendEmailCodeForChangeEmailSucess;
extern NSString *const kSendEmailCodeForChangePhoneSucess;

@interface DTModifyBindedInfoController ()<UITextFieldDelegate,CountryCodeViewControllerDelegate>
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) DTTextField *tfAccount;
@property (nonatomic, strong) DTLayoutButton *countryCodeBtn;
@property (nonatomic, strong) UIView *vLine;
@property (nonatomic, strong) NSLayoutConstraint *tfAccountLeftLayoutConstraint;
@property (nonatomic, strong) UIView *tfContentView;

@property (nonatomic, strong) OWSFlatButton *nextButton;
@property (nonatomic, strong) NSLayoutConstraint *nextButtonTopConstraint;
@property (nonatomic, strong) UILabel *errorTipLabel;
@property (nonatomic, strong) NSLayoutConstraint *errorTipLabelTopConstraint;
@property (nonatomic, strong) DTBindEmailApi *bindEmailApi;
@property (nonatomic, strong) DTBindPhoneApi *bindPhoneApi;

@property (nonatomic, assign) DTLoginState loginState;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *scrollContentView;
@end

@implementation DTModifyBindedInfoController
- (void)loadView {
    [super loadView];
//    [self creatNav];
    [self configSubViews];
    [self configSubviewLayout];
    [self applyTheme];
    if(self.modifyType == DTModifyTypeChangeEmail){
        self.tfAccount.placeholder = Localized(@"SETTINGS_VC_TITLE_CHANGE_EMAIL_PLACE_HOLDER", @"");
    } else {
        self.tfAccount.placeholder = Localized(@"SETTINGS_VC_TITLE_CHANGE_PHONE_NUMBER_PLACE_HOLDER", @"");
    }
}

- (void)viewDidLoad {
    self.navigationController.navigationBarHidden = false;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldTextDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    RegistrationCountryState * countryState = [DTCountryLocationManger sharedInstance].countryState;
    if(DTParamsUtils.validateString(countryState.callingCode)){
        [self.countryCodeBtn setTitle:countryState.callingCode forState:UIControlStateNormal];
    } else {
        [[DTCountryLocationManger sharedInstance] asyncGetRegistrationCountryState:^(RegistrationCountryState * _Nonnull returnCountryState) {
            if(DTParamsUtils.validateString(returnCountryState.callingCode)){
                if(!DTParamsUtils.validateString(self.countryCodeBtn.titleLabel.text)){
                    [self.countryCodeBtn setTitle:returnCountryState.callingCode forState:UIControlStateNormal];
                }
            }
        } failure:^(NSError * _Nonnull error) {
            NSString *errorString = [NSError errorDesc:error errResponse:nil];
            OWSLogInfo(@"asyncGetRegistrationCountryState error%@",errorString);
        }];
    }
}

- (void)creatNav {
    UIButton *backButton = [UIButton new];
    [backButton addTarget:self action:@selector(backButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [backButton setImage:[UIImage imageNamed:@"nav_back_arrow_new"] forState:UIControlStateNormal];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    self.navigationItem.leftBarButtonItem = item;
}

- (void)backButtonPressed {
    [self.navigationController popViewControllerAnimated:true];
}

- (void)skipButtonPressed:(UIButton *)sender {

}

- (void)setTitleString:(NSString *)titleString {
    _titleString = titleString;
    self.title = titleString;
}

- (void)configSubViews {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.scrollContentView];
    
    [self.scrollContentView addSubview:self.iconImageView];
    [self.scrollContentView addSubview:self.titleLabel];
    [self.scrollContentView addSubview:self.descLabel];
    [self.scrollContentView addSubview:self.tfContentView];
    [self.tfContentView addSubview:self.countryCodeBtn];
    [self.tfContentView addSubview:self.vLine];
    [self.tfContentView addSubview:self.tfAccount];
    [self.scrollContentView addSubview:self.errorTipLabel];
    [self.scrollContentView addSubview:self.nextButton];
    
    self.errorTipLabel.alpha = 0;
}


- (void)configSubviewLayout {
    
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    CGFloat safeAreaTop = window.safeAreaInsets.top;
    
    [self.scrollView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoSetDimensionsToSize:[UIScreen mainScreen].bounds.size];
    
    [self.iconImageView autoPinEdgeToSuperviewSafeArea:ALEdgeTop withInset:safeAreaTop];
    [self.iconImageView autoSetDimensionsToSize:CGSizeMake(120, 120)];
    [self.iconImageView autoHCenterInSuperview];
    
    [self.titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.iconImageView withOffset:0];
    [self.titleLabel autoHCenterInSuperview];
    
    [self.descLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.titleLabel withOffset:8];
    [self.descLabel autoSetDimension:ALDimensionHeight toSize:20];
    [self.descLabel autoPinLeadingToEdgeOfView:self.scrollContentView offset:16];
    [self.descLabel autoPinTrailingToEdgeOfView:self.scrollContentView offset:-16];
    
    [self.tfContentView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.descLabel withOffset:32];
    [self.tfContentView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.scrollContentView withOffset:16];
    [self.tfContentView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.scrollContentView withOffset:-16];
    [self.tfContentView autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    
    [self.countryCodeBtn autoPinLeadingToEdgeOfView:self.tfContentView offset:5.5];
    [self.countryCodeBtn autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.tfContentView withOffset:8];
    [self.countryCodeBtn autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.tfAccount withOffset:0];
    [self.countryCodeBtn autoSetDimension:ALDimensionHeight toSize:20];
    [self.countryCodeBtn autoSetDimension:ALDimensionWidth toSize:63];
    
    [self.countryCodeBtn autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.vLine withOffset:-12];
    
    [self.vLine autoSetDimension:ALDimensionWidth toSize:1];
    [self.vLine autoSetDimension:ALDimensionHeight toSize:20];
    [self.vLine autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.tfAccount withOffset:0];
    [self.vLine autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:self.countryCodeBtn withOffset:12];
   
    
    self.tfAccountLeftLayoutConstraint = [self.tfAccount autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.tfContentView withOffset:0];
    [self.tfAccount autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    [self.tfAccount autoPinTrailingToEdgeOfView:self.tfContentView offset:0];
    
    self.errorTipLabelTopConstraint = [self.errorTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfAccount withOffset:8];
    [self.errorTipLabel autoPinLeadingToEdgeOfView:self.tfContentView offset:0];
    [self.errorTipLabel autoPinTrailingToEdgeOfView:self.tfContentView offset:0];
    [self.errorTipLabel autoSetDimension:ALDimensionHeight toSize:16];
    
    self.nextButtonTopConstraint = [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfContentView withOffset:24];
    [self.nextButton autoPinLeadingToEdgeOfView:self.tfContentView offset:0];
    [self.nextButton autoPinTrailingToEdgeOfView:self.tfContentView offset:0];
    [self.nextButton autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
}

- (void)resetSubviewsLayoutWithState:(DTLoginState)state errorMesssage:(NSString * __nullable) message {
    if(state == self.loginState ){
        return;
    }
    self.loginState = state;
    if(state == DTLoginStateTypeLoginFailed){
        if(!message || message.length <= 0){return;}
        self.tfContentView.layer.borderColor = [UIColor colorWithRGBHex:0xF6465D].CGColor;
        self.errorTipLabel.text = message;
        [self.nextButtonTopConstraint autoRemove];
        self.nextButtonTopConstraint = [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.errorTipLabel withOffset:20];
        [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            [self.view layoutIfNeeded];
        } completion:nil];

        [UIView animateWithDuration:0.1 delay:0.1 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self.errorTipLabel.alpha = 1;
        } completion:^(BOOL finishedA) {

        }];
    } else {
        self.errorTipLabel.text = @"";
        [self.nextButtonTopConstraint autoRemove];
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            self.nextButtonTopConstraint = [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfAccount withOffset:16];
            self.errorTipLabel.alpha = 0;
            [self.view layoutIfNeeded];
        } completion:nil];
        self.tfContentView.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor: [UIColor colorWithRGBHex:0xEAECEF].CGColor;
    }
}

- (void)applyTheme {
    [super applyTheme];
    self.view.backgroundColor = Theme.backgroundColor;
    self.titleLabel.textColor = Theme.primaryTextColor;
    self.tfAccount.keyboardAppearance = Theme.keyboardAppearance;
    self.tfAccount.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF] ;
    self.tfAccount.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329];
    self.nextButton.isSelected = self.tfAccount.text.length;
    self.nextButton.userInteractionEnabled = self.tfAccount.text.length;
    [self.nextButton setTitleColor: [UIColor colorWithRGBHex:0xFFFFFF] for:UIControlStateSelected];
    [self.nextButton setTitleColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xB7BDC6] for:UIControlStateNormal];
    [self.nextButton setBackgroundColor:[UIColor colorWithRGBHex:0x056FFA] for:UIControlStateSelected];
    [self.nextButton setBackgroundColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF] for:UIControlStateNormal];
    self.tfContentView.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor: [UIColor colorWithRGBHex:0xEAECEF].CGColor;
}

///这个页面仅仅是绑定邮箱使用的
- (void)nextButtonClick:(UIButton *)sender {
    [self bindRequestWithNonce:nil];
}

- (void)bindRequestWithNonce:(NSString * __nullable)nonce {
    NSString *tfText = [self.tfAccount.text ows_stripped];
    BOOL isEmail = [DTPatternHelper validateEmail:tfText];
    BOOL isPhone = [DTPatternHelper verificationTextInputNumer:tfText];
    if( self.modifyType == DTModifyTypeChangeEmail && (!DTParamsUtils.validateString(tfText) || !isEmail)){
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"MODIFY_EMAIL_EMPTY", @"")];
        return;
    }
    if(self.modifyType == DTModifyTypeChangePhoneNumber && (!DTParamsUtils.validateString(tfText) || !isPhone) ){
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"MODIFY_PHONE_NUMBER_EMPTY", @"")];
        return;
    }
    if(self.modifyType == DTModifyTypeChangeEmail) {
        [DTToastHelper showHudInView:self.view];
        [self.bindEmailApi bind:tfText nonce:nonce sucess:^(id<HTTPResponse>  _Nonnull response) {
            [DTToastHelper hide];
            [DTChatLoginUtils checkOrResetTimeStampWith:tfText key:kSendEmailCodeForChangeEmailSucess];
            DTVerificationCodeController *verificationCodeVC = [[DTVerificationCodeController alloc] initWithEmail:tfText];
            verificationCodeVC.loginModeType = DTLoginModeTypeChangeEmailFromMe;
            verificationCodeVC.titleString = Localized(@"SETTINGS_VC_TITLE_CHANGE_EMAIL", @"modifyEmailVC");
            verificationCodeVC.nonce = nonce;
            [self.navigationController pushViewController:verificationCodeVC animated:true];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            [DTToastHelper hide];
            if (DTParamsUtils.validateNumber([error httpStatusCode]) &&
                [error httpStatusCode].intValue == 403
                && errResponse.status == 24) {
                [self showForceBindAlertWithModifyType:DTModifyTypeChangeEmail
                                          confirmBlock:^{
                    NSString *newNonce = errResponse.data[@"nonce"];
                    if (DTParamsUtils.validateString(newNonce)) {
                        [self bindRequestWithNonce:newNonce];
                    } else {
                        [self bindRequestWithNonce:nil];
                        OWSLogError(@"bindEmailApi nonce is empty");
                    }
                }];
            } else {
                NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else if (self.modifyType == DTModifyTypeChangePhoneNumber) {
        NSString *phone = [self.tfAccount.text ows_stripped];
        NSString *countryCode = @"";
        NSString *plusPhoneString = [DTPatternHelper verificationTextInputNumerWithPlus:phone];
        BOOL isPlusPhone = DTParamsUtils.validateString(plusPhoneString);
        if(!isPlusPhone){
            countryCode = self.countryCodeBtn.titleLabel.text;
        }
        NSString *phoneNumber = [NSString stringWithFormat:@"%@%@",countryCode,phone];
        [DTToastHelper showHudInView:self.view];
        [self.bindPhoneApi bind:phoneNumber dialingCode:countryCode nonce:nonce sucess:^(DTAPIMetaEntity *metaEntity) {
            [DTToastHelper hide];
            if (metaEntity.status == 10109 ||
                metaEntity.status == 10111) {
                [self showForceBindAlertWithModifyType:DTModifyTypeChangeEmail
                                          confirmBlock:^{
                    NSString *newNonce = metaEntity.data[@"nonce"];
                    if (DTParamsUtils.validateString(newNonce)) {
                        [self bindRequestWithNonce:newNonce];
                    } else {
                        [self bindRequestWithNonce:nil];
                        OWSLogError(@"bindPhoneApi nonce is empty");
                    }
                }];
            } else {
                
                [DTChatLoginUtils checkOrResetTimeStampWith:tfText key:kSendEmailCodeForChangePhoneSucess];
                DTVerificationCodeController *verificationCodeVC = [[DTVerificationCodeController alloc] initWithPhone:phoneNumber dialingCode:countryCode];
                verificationCodeVC.nonce = nonce;
                verificationCodeVC.loginModeType = DTLoginModeTypeChangePhoneNumberFromMe;
                verificationCodeVC.titleString = Localized(@"SETTINGS_VC_TITLE_CHANGE_PHONE_NUMBER", @"modifyEmailVC");
                [self.navigationController pushViewController:verificationCodeVC animated:true];
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable errResponse) {
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    }
}

- (void)showForceBindAlertWithModifyType:(DTModifyType)modifyType
                            confirmBlock:(void(^)(void))confirmBlock{
    
    NSString *title = nil;
    NSString *message = nil;
    if (modifyType == DTModifyTypeChangeEmail) {
        title = Localized(@"ACCOUNT_FORCEBIND_EMAIL_TITLE", @"");
        message = Localized(@"ACCOUNT_FORCEBIND_EMAIL_MESSAGE", @"");
    } else {
        title = Localized(@"ACCOUNT_FORCEBIND_PHONE_TITLE", @"");
        message = Localized(@"ACCOUNT_FORCEBIND_PHONE_MESSAGE", @"");
    }
    
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:title
                                        message:message
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"LOGIN_SKIP_ALERT_CANCEL", nil)
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *_Nonnull action) {
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"LOGIN_SKIP_ALERT_CONTINUE", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *_Nonnull action) {
        confirmBlock();
    }]];
    [self.navigationController presentViewController:alertController animated:true completion:nil];
}

#pragma mark textFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:nil];
    if (textField == self.tfAccount && textField.text.length >1 && range.location == 0 && [string isEqualToString:@""]) {
        self.nextButton.isSelected = true;
        self.nextButton.userInteractionEnabled = true;
    } else if (textField == self.tfAccount && textField.text.length <= 1 && range.location == 0 && [string isEqualToString:@""]) {
        self.nextButton.isSelected = false;
        self.nextButton.userInteractionEnabled = false;
    } else {
        self.nextButton.isSelected = true;
        self.nextButton.userInteractionEnabled = true;
        
    }
    return true;
}

- (void)textFieldTextDidChange:(NSNotification *)notity {
    NSString *result = [DTPatternHelper verificationTextInputNumer:[self.tfAccount.text ows_stripped]];
    if(DTParamsUtils.validateString(result)){
        self.countryCodeBtn.hidden = false;
        self.vLine.hidden = false;
        self.tfAccountLeftLayoutConstraint.constant = 91;
    } else {
        self.tfAccountLeftLayoutConstraint.constant = 0;
        self.countryCodeBtn.hidden = true;
        self.vLine.hidden = true;
    }
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:Localized(@"LOGIN_EMAIL_EMPTY", @"")];
    return true;
}

- (void)resetLoginButton {
    
}

- (void)countryCodeBtnClick:(UIButton *)sender {
    CountryCodeViewController * countryCodeVC = [CountryCodeViewController new];
    countryCodeVC.customTableConstraints = true;
    countryCodeVC.countryCodeDelegate = self;
    [self.navigationController pushViewController:countryCodeVC animated:true];
}

- (void)countryCodeViewController:(CountryCodeViewController *)vc didSelectCountry:(RegistrationCountryState *)didSelectCountry {
    [self.countryCodeBtn setTitle:didSelectCountry.callingCode forState:UIControlStateNormal];
}


- (UIImageView *)iconImageView {
    if(!_iconImageView){
        _iconImageView = [UIImageView new];
        _iconImageView.image = [UIImage imageNamed:TSConstants.appLogoName];
        _iconImageView.layer.cornerRadius = 5;
        _iconImageView.layer.masksToBounds = YES;
    }
    return _iconImageView;
}

- (UILabel *)titleLabel {
    if(!_titleLabel){
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont ows_semiboldFontWithSize:20];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.text = self.titleString;
    }
    return _titleLabel;
}


- (UILabel *)descLabel {
    if(!_descLabel){
        _descLabel = [UILabel new];
        _descLabel.font = [UIFont ows_regularFontWithSize:14];
        _descLabel.text = @"";
        _descLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _descLabel;
}

- (DTTextField *)tfAccount {
    if(!_tfAccount){
        _tfAccount = [DTTextField new];
        _tfAccount.delegate = self;
        _tfAccount.clearButtonMode = UITextFieldViewModeWhileEditing;
        _tfAccount.keyboardAppearance = Theme.keyboardAppearance;
        _tfAccount.keyboardType = UIKeyboardTypeEmailAddress;
    }
    return _tfAccount;
}

- (OWSFlatButton *)nextButton {
    if(!_nextButton){
        _nextButton = [OWSFlatButton buttonWithTitle:Localized(@"WEA_LOGIN_NEXT", @"")
                                                     font:[OWSFlatButton orignalFontForHeight:16]
                                               titleColor:[UIColor whiteColor]
                                          backgroundColor:[UIColor ows_signalBrandBlueColor]
                                                   target:self
                                             selector:@selector(nextButtonClick:)];
        [_nextButton setTitleColor:[UIColor colorWithRGBHex:0xFFFFFF] for:UIControlStateSelected];
        [_nextButton setTitleColor:[UIColor colorWithRGBHex:0xB7BDC6] for:UIControlStateNormal];
        [_nextButton setBackgroundColor:[UIColor colorWithRGBHex:0x056FFA] for:UIControlStateSelected];
        [_nextButton setBackgroundColor:[UIColor colorWithRGBHex:0xEAECEF] for:UIControlStateNormal];
    }
    return _nextButton;
}

- (UILabel *)errorTipLabel {
    if(!_errorTipLabel){
        _errorTipLabel = [UILabel new];
        _errorTipLabel.font = [UIFont systemFontOfSize:14];
        _errorTipLabel.text = @"Email does not exist, please try another email";
        _errorTipLabel.textColor = [UIColor colorWithRGBHex:0xF6465D];
    }
    return _errorTipLabel;
}

- (DTBindEmailApi *)bindEmailApi {
    if(!_bindEmailApi){
        _bindEmailApi = [DTBindEmailApi new];
    }
    return _bindEmailApi;
}

- (DTBindPhoneApi *)bindPhoneApi {
    if(!_bindPhoneApi){
        _bindPhoneApi = [DTBindPhoneApi new];
    }
    return _bindPhoneApi;
}

- (UIScrollView *)scrollView {
    if(!_scrollView){
        _scrollView = [UIScrollView new];
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.showsVerticalScrollIndicator = false;
        _scrollView.bounces = false;
    }
    return _scrollView;
}

- (UIView *)scrollContentView {
    if(!_scrollContentView){
        _scrollContentView = [UIView new];
    }
    return _scrollContentView;
}

- (DTLayoutButton *)countryCodeBtn {
    if(!_countryCodeBtn){
        _countryCodeBtn = [DTLayoutButton new];
        _countryCodeBtn.spacing = 4;
        _countryCodeBtn.titleAlignment = DTButtonTitleAlignmentTypeLeft;
        [_countryCodeBtn setTitle:@"+986" forState:UIControlStateNormal];
        [_countryCodeBtn setImage:[UIImage imageNamed:@"input_arrow"] forState:UIControlStateNormal];
        [_countryCodeBtn setTitleColor:Theme.primaryTextColor forState:UIControlStateNormal];
        _countryCodeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_countryCodeBtn addTarget:self action:@selector(countryCodeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _countryCodeBtn.hidden = true;
    }
    return _countryCodeBtn;
}

- (UIView *)tfContentView {
    if(!_tfContentView){
        _tfContentView = [UIView new];
        _tfContentView.layer.cornerRadius = 5;
        _tfContentView.layer.masksToBounds = true;
        _tfContentView.layer.borderWidth = 1;
    }
    return _tfContentView;
}

- (UIView *)vLine {
    if(!_vLine){
        _vLine = [UIView new];
        _vLine.backgroundColor = [UIColor colorWithRGBHex:0x474D57];
        _vLine.hidden = true;
    }
    return _vLine;
}
@end
