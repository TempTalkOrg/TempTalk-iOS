//
//  DTSignInController.m
//  Signal
//
//  Created by hornet on 2022/10/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTSignInController.h"
#import "DTTextField.h"
#import <TTServiceKit/DTToastHelper.h>
#import "DTVerificationCodeController.h"
#import "TempTalk-Swift.h"
#import "AppDelegate.h"
#import "DTChatLoginUtils.h"
#import "DTChativeMacro.h"

NSString *const kSendEmailCodeSucess = @"kSendEmailCodeSucess";
NSString *const kSendEmailCodeForLoginSucess = @"kSendEmailCodeForLoginSucess";
NSString *const kSendPhoneCodeForLoginSucess = @"kSendPhoneCodeForLoginSucess";

NSString *const kSendEmailCodeForChangeEmailSucess = @"kSendEmailCodeForChangeEmailSucess";
NSString *const kSendEmailCodeForChangePhoneSucess = @"kSendEmailCodeForChangePhoneSucess";


@interface DTSignInController ()<UITextFieldDelegate, CountryCodeViewControllerDelegate>
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
@property (nonatomic, strong) DTLoginWithEmailApi *loginWithEmailApi;
@property (nonatomic, strong) DTLoginWithPhoneNumberApi *loginWithPhoneApi;
@property (nonatomic, strong) DTLoginWithPhoneCodeApi *loginWithPhoneCodeApi;
@property (nonatomic, assign) DTLoginState loginState;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *scrollContentView;
@end

@implementation DTSignInController
- (void)loadView {
    [super loadView];
    [self creatNav];
    [self configSubViews];
    [self configSubviewLayout];
    [self applyTheme];
    
}

- (void)viewDidLoad {
    self.navigationController.navigationBarHidden = false;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldTextDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
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
    [DTToastHelper hide];
    [self showAlertViewController];
}

- (void)showAlertViewController {
    
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:nil
                                        message:Localized(@"LOGIN_SKIP_ALERT_MESSAGE",
                                                                  @"")
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"LOGIN_SKIP_ALERT_CANCEL", nil)
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *_Nonnull action) {
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:Localized(@"LOGIN_SKIP_ALERT_CONTINUE", nil)
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *_Nonnull action) {
        [alertController dismissViewControllerAnimated:true completion:nil];
        
        AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
        [appDelegate switchToTabbarVCFromRegistration:YES];
    }]];
    [self.navigationController presentViewController:alertController animated:true completion:nil];
}

- (void)setTitleString:(NSString *)titleString {
    _titleString = titleString;
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
   
    
//    [self.tfAccount autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.titleLabel withOffset:32];
    self.tfAccountLeftLayoutConstraint = [self.tfAccount autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.tfContentView withOffset:0];
    [self.tfAccount autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    [self.tfAccount autoPinTrailingToEdgeOfView:self.tfContentView offset:0];
    
    
//    [self.tfAccount autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.descLabel withOffset:32];
//    [self.tfAccount autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
//    [self.tfAccount autoPinLeadingToEdgeOfView:self.scrollContentView offset:16];
//    [self.tfAccount autoPinTrailingToEdgeOfView:self.scrollContentView offset:-16];
    
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
        self.tfAccount.layer.borderColor = [UIColor colorWithRGBHex:0xF6465D].CGColor;
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
        self.tfAccount.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor: [UIColor colorWithRGBHex:0xEAECEF].CGColor;
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
    [self.nextButton setTitleColor: [UIColor colorWithRGBHex:0xFFFFFF] for:UIControlStateSelected];
    [self.nextButton setTitleColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xB7BDC6] for:UIControlStateNormal];
    [self.nextButton setBackgroundColor:[UIColor colorWithRGBHex:0x056FFA] for:UIControlStateSelected];
    [self.nextButton setBackgroundColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF] for:UIControlStateNormal];
    self.tfAccount.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor: [UIColor colorWithRGBHex:0xEAECEF].CGColor;
}

///这个页面仅仅是绑定邮箱使用的
- (void)nextButtonClick:(UIButton *)sender {
    NSString *tfText = [self.tfAccount.text ows_stripped];
    BOOL isEmail = [DTPatternHelper validateEmail:tfText];
//    BOOL isPhone = [DTPatternHelper verificationTextInputNumer:tfText];
    if(!DTParamsUtils.validateString(tfText)){
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"LOGIN_EMAIL_EMPTY", @"")];
    }
    if(isEmail){
        [self.bindEmailApi bind:tfText nonce:nil sucess:^(id<HTTPResponse>  _Nonnull response) {
            [DTChatLoginUtils checkOrResetTimeStampWith:tfText key:kSendEmailCodeForLoginSucess];
            DTVerificationCodeController *verificationCodeVC = [[DTVerificationCodeController alloc] initWithEmail:tfText];
            ///需要知道是Email 还是 Phone
            if(self.signInModeType == DTSignInModeTypeLogin || self.signInModeType == DTSignInModeTypeRegisterViaInviteCode){
                verificationCodeVC.loginModeType = DTLoginModeTypeRegisterEmailFromLogin;
            } else {
                verificationCodeVC.loginModeType = DTLoginModeTypeChangeEmailFromMe;
            }
            verificationCodeVC.titleString =  [NSString stringWithFormat:@"Sign in to %@",TSConstants.appDisplayName];
            [self.navigationController pushViewController:verificationCodeVC animated:true];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            NSString *errorMessage = [self errorDesc:error errResponse:errResponse];
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    }
}

- (NSString *)errorDesc:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse {
    if(error && errResponse){
        int httpStatusCode = [error.httpStatusCode intValue];
        NSInteger status = errResponse.status;
        if(httpStatusCode == 403 && status > 0){
            return [NSString stringWithFormat:@"(%zd) %@",status,errResponse.reason];
        } else {
            return [NSString stringWithFormat:@"%@",Localized(@"REQUEST_FAILED_TRY_AGAIN", @"")];
        }
    } else {
        int httpStatusCode = [error.httpStatusCode intValue];
        if (httpStatusCode == 413){
            return @"rate limit";
        }
        return [NSString stringWithFormat:@"%@",Localized(@"REQUEST_FAILED_TRY_AGAIN", @"")];
    }
}
#pragma mark textFieldDelegate
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:nil];
    if (textField == self.tfAccount && textField.text.length >1 && range.location == 0 && [string isEqualToString:@""]) {
        self.nextButton.isSelected = true;
    } else if (textField == self.tfAccount && textField.text.length <= 1 && range.location == 0 && [string isEqualToString:@""]) {
        self.nextButton.isSelected = false;
    } else {
        self.nextButton.isSelected = true;
    }
    return true;
}

- (void)textFieldTextDidChange:(NSNotification *)notity {

}

- (void)countryCodeBtnClick:(UIButton *)sender {
    CountryCodeViewController * countryCodeVC = [CountryCodeViewController new];
    countryCodeVC.customTableConstraints = true;
    countryCodeVC.countryCodeDelegate = self;
    [self.navigationController pushViewController:countryCodeVC animated:true];
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
        _descLabel.text = @"Bind your email";
        _descLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _descLabel;
}

- (DTTextField *)tfAccount {
    if(!_tfAccount){
        _tfAccount = [DTTextField new];
        _tfAccount.delegate = self;
        _tfAccount.layer.cornerRadius = 5;
        _tfAccount.clearButtonMode = UITextFieldViewModeWhileEditing;
        _tfAccount.layer.masksToBounds = true;
        _tfAccount.layer.borderWidth = 1;
        _tfAccount.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor : [UIColor colorWithRGBHex:0xEAECEF].CGColor;
        _tfAccount.placeholder = Localized(@"LOGIN_EMAIL_PLACEHOLDER_CHATIVE_SIGNIN_EMAIL", @"");
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

- (DTLoginWithPhoneNumberApi *)loginWithPhoneApi {
    if(!_loginWithPhoneApi){
        _loginWithPhoneApi = [DTLoginWithPhoneNumberApi new];
    }
    return _loginWithPhoneApi;
}

- (DTLoginWithPhoneCodeApi *)loginWithPhoneCodeApi {
    if(_loginWithPhoneCodeApi){
        _loginWithPhoneCodeApi = [DTLoginWithPhoneCodeApi new];
    }
    return _loginWithPhoneCodeApi;
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
