//
//  DTSignChativeController.m
//  TTMessaging
//
//  Created by hornet on 2022/10/1.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTSignChativeController.h"
#import "DTSignChativeController+internal.h"
#import "DTSignChativeController+PasskeyLogin.h"
#import "DTSignChativeController+EmailByVcodeLogin.h"
#import "DTSignChativeController+PhoneByVcodeLogin.h"
#import <TTServiceKit/Localize_Swift.h>

@interface DTSignChativeController ()<UITextFieldDelegate, CountryCodeViewControllerDelegate>
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) DTLayoutButton *countryCodeBtn;
@property (nonatomic, strong) UIView *vLine;
@property (nonatomic, strong) DTTextField *tfAccount;
@property (nonatomic, strong) NSLayoutConstraint *tfAccountLeftLayoutConstraint;
@property (nonatomic, strong) UIView *tfContentView;
@property (nonatomic, strong) UILabel *errorTipLabel;
@property (nonatomic, strong) NSLayoutConstraint *errorTipLabelTopConstraint;
@property (nonatomic, strong) OWSFlatButton *loginButton;
@property (nonatomic, strong) UILabel *transferLabel;
@property (nonatomic, strong) UIButton *signupTipBtn;

@property (nonatomic, strong) NSLayoutConstraint *loginButtonTopConstraint;
@property (nonatomic, assign) DTLoginState loginState;


@property (nonatomic, strong) NSNumber *isNewRegister;
@property (nonatomic, readonly) AccountManager *accountManager;
@property (nonatomic, strong) NSString *vCodeCompleteNumber;
@property (nonatomic, strong) NSString *vCodePhoneNumber;

@property (nonatomic) NSString *pin;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *scrollContentView;
@property (nonatomic, assign) DTSignInModeType signInModeType;
@property (nonatomic, assign) DTLoginModeType loginModeType;

@end

@implementation DTSignChativeController

- (void)loadView {
    [super loadView];
    [self configSubViews];
    [self configSubviewLayout];
    [self applyTheme];
    [self configInitProperty];
    [self addObserver];
    self.countryCodeBtn.hidden = true;
    self.vLine.hidden = true;
//    [[DTCountryLocationManger sharedInstance] getDefaultLocation];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    self.navigationController.navigationBar.hidden = true;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
//    self.navigationController.navigationBar.hidden = false;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _accountManager = SignalApp.sharedApp.accountManager;
    MainAppContext *mainAppContext = CurrentAppContext();
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
            //暂时将+1 作为默认值
            NSString *errorString = [NSError errorDesc:error errResponse:nil];
            OWSLogInfo(@"asyncGetRegistrationCountryState error%@",errorString);
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.tfAccount becomeFirstResponder];
}

- (void)dealloc {
    DDLogInfo(@"dealloc ::::%@",[self class]);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)configSubViews {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.scrollContentView];
    [self.scrollContentView addSubview:self.iconImageView];
//    [self.scrollContentView addSubview:self.titleLabel];
    [self.scrollContentView addSubview:self.tfContentView];
    [self.tfContentView addSubview:self.countryCodeBtn];
    [self.tfContentView addSubview:self.vLine];
    [self.tfContentView addSubview:self.tfAccount];
    [self.scrollContentView addSubview:self.errorTipLabel];
    [self.scrollContentView addSubview:self.loginButton];
    self.errorTipLabel.alpha = 0;
}

- (void)configSubviewLayout {
    UIWindow *window = [[OWSWindowManager sharedManager] rootWindow];
    CGFloat safeAreaTop = window.safeAreaInsets.top;
    
    [self.scrollView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoSetDimensionsToSize:[UIScreen mainScreen].bounds.size];
    
    [self.iconImageView autoPinEdgeToSuperviewSafeArea:ALEdgeTop withInset:safeAreaTop];
    [self.iconImageView autoSetDimensionsToSize:CGSizeMake(160, 160)];
    [self.iconImageView autoHCenterInSuperview];
    
    [self.tfContentView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.iconImageView withOffset:32];
    [self.tfContentView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.scrollContentView withOffset:16];
    [self.tfContentView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.scrollContentView withOffset:-16];
    [self.tfContentView autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    
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
    
    self.errorTipLabelTopConstraint = [self.errorTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfContentView withOffset:8];
    [self.errorTipLabel autoPinLeadingToEdgeOfView:self.tfContentView offset:0];
    [self.errorTipLabel autoPinTrailingToEdgeOfView:self.tfContentView offset:0];
    [self.errorTipLabel autoSetDimension:ALDimensionHeight toSize:16];
    
    self.loginButtonTopConstraint = [self.loginButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfContentView withOffset:24];
    [self.loginButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.scrollView withOffset:16];
    [self.loginButton autoPinTrailingToEdgeOfView:self.scrollView offset:-16];
    [self.loginButton autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    
    UIStackView *stackView = [UIStackView new];
    [self.scrollContentView addSubview:stackView];
    [stackView autoSetDimension:ALDimensionHeight toSize:20];
    
    stackView.distribution = UIStackViewDistributionFill;
    stackView.spacing = 5.0;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.axis = UILayoutConstraintAxisHorizontal;
    
    [stackView addArrangedSubview:self.transferLabel];
    [stackView addArrangedSubview:self.signupTipBtn];
    
    [stackView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.loginButton withOffset:24];
    [stackView autoHCenterInSuperview];
    [stackView autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
}

- (void)resetSubviewsLayoutWithState:(DTLoginState)state errorMesssage:(NSString * __nullable) message {
    if(state == self.loginState ){
        return;
    }
    self.loginState = state;
    if(state == DTLoginStateTypeLoginFailed){
        self.tfContentView.layer.borderColor =  [UIColor colorWithRGBHex:0xF6465D].CGColor;
        if(!message || message.length <= 0){return;}
        [self.loginButtonTopConstraint autoRemove];
        self.errorTipLabel.text = message;
        [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            self.loginButtonTopConstraint = [self.loginButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.errorTipLabel withOffset:20];
            [self.view layoutIfNeeded];
        } completion:nil];
        
        [UIView animateWithDuration:0.1 delay:0.1 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            self.errorTipLabel.alpha = 1;
        } completion:^(BOOL finishedA) {
            
        }];
    } else {
        self.errorTipLabel.text = @"";
        [self.loginButtonTopConstraint autoRemove];
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionTransitionFlipFromLeft animations:^{
            self.loginButtonTopConstraint = [self.loginButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.tfContentView withOffset:16];
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
    self.loginButton.isSelected = self.tfAccount.text.length;
    self.loginButton.userInteractionEnabled = self.tfAccount.text.length;
    [self.loginButton setTitleColor: [UIColor colorWithRGBHex:0xFFFFFF] for:UIControlStateSelected];
    [self.loginButton setTitleColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xB7BDC6] for:UIControlStateNormal];
    [self.loginButton setBackgroundColor:[UIColor colorWithRGBHex:0x056FFA] for:UIControlStateSelected];
    [self.loginButton setBackgroundColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF] for:UIControlStateNormal];
    self.tfContentView.layer.borderColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57].CGColor: [UIColor colorWithRGBHex:0xEAECEF].CGColor;
}

- (void)configInitProperty {
    if(self.signType == DTSignTypeLogin){
        self.titleLabel.text = [NSString stringWithFormat:Localized(@"CHATIVE_LOGIN_SIGN_IN_TITLE", @""), TSConstants.appDisplayName];
        [self.loginButton setTitleWithTitle:Localized(@"CHATIVE_LOGIN_SIGN_IN", @"")];
        self.transferLabel.text = Localized(@"CHATIVE_LOGIN_TRANSFER_TO_SIGN_UP_NOT_ACCOUNT",@"");
        [self.signupTipBtn setTitle:Localized(@"CHATIVE_LOGIN_SIGN_UP", @"Title for pick view cancel") forState:UIControlStateNormal];
        
    } else {
        self.titleLabel.text = [NSString stringWithFormat:Localized(@"CHATIVE_LOGIN_SIGN_UP_TITLE", @""), TSConstants.appDisplayName];
        [self.loginButton setTitleWithTitle:Localized(@"CHATIVE_LOGIN_SIGN_UP", @"")];
        self.transferLabel.text = Localized(@"CHATIVE_LOGIN_TRANSFER_TO_SIGN_IN_HAVE_ACCOUNT",@"");
        [self.signupTipBtn setTitle:Localized(@"CHATIVE_LOGIN_SIGN_IN", @"Title for pick view cancel") forState:UIControlStateNormal];;
        
    }
    
}

- (void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldTextDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
}


- (void)autoRegisterWithInviteCode:(NSString *) inviteCode {
    if(DTParamsUtils.validateString(inviteCode)){
        self.tfAccount.text = inviteCode;
        self.loginButton.isSelected = true;
        self.loginButton.userInteractionEnabled = true;
        NSString *strippedText = [self.tfAccount.text ows_stripped];
        [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:nil];
        [self registerWithInviteCode:strippedText];
    }
}


- (void)loginButtonClick:(UIButton *)sender {
    NSString *strippedText = [self.tfAccount.text ows_stripped];
    //邀请码
    BOOL isInvitedCode = [DTPatternHelper validateChativeInvitedCode:strippedText];
    BOOL isEmail = [DTPatternHelper validateEmail:strippedText];
    NSString *phoneString = [DTPatternHelper verificationTextInputNumer:strippedText];
    BOOL isPhone = DTParamsUtils.validateString(phoneString);
    NSString *plusPhoneString = [DTPatternHelper verificationTextInputNumerWithPlus:strippedText];
    BOOL isPlusPhone = DTParamsUtils.validateString(plusPhoneString);
    if (!isInvitedCode && !isEmail && !isPhone && !isPlusPhone) {
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"LOGIN_ERROR", @"")];
        return;
    }
    
    if(isPhone){
        [self loginViaPhoneNumber:false];
        return;
    }
    
    if(isPlusPhone){
        [self loginViaPhoneNumber:true];
        return;
    }
    
    if(isEmail){
        [self loginViaEmail];
        return;
    }
    
    if (isInvitedCode) {
        [self registerWithInviteCode:strippedText];
        return;
    }
}

- (void)loginViaPhoneNumber:(BOOL)isPlusPhone {
    NSString *phone = [self.tfAccount.text ows_stripped];
    NSString *countryCode = @"";
    if(!isPlusPhone){
        countryCode = self.countryCodeBtn.titleLabel.text;
    }
    NSString *phoneNumber = [NSString stringWithFormat:@"%@%@",countryCode,phone];
    self.email = nil;
    self.phoneNumber = phoneNumber;
    
    [[self passKeyManager] checkAccountExistsWithEmail:nil phoneNumber:phoneNumber sucess:^(DTAPIMetaEntity * _Nullable entity) {
        if(DTParamsUtils.validateDictionary(entity.data)){
            BOOL exists = [entity.data[@"exists"] boolValue];///当前账号是否存在
            NSString *user_id = entity.data[@"webauthnUserID"];///user_id passkey 注册后生成的user_id
            BOOL hasWebauthn = [entity.data[@"hasWebauthn"] boolValue];//用户是否注册了passkey
            [TSAccountManager sharedInstance].hasWebauthn = hasWebauthn;
            //当前用户存在且目前在登录页面
            if (exists && self.signType == DTSignTypeLogin ){
                if(hasWebauthn && DTParamsUtils.validateString(user_id) && [[self passKeyManager] isPasskeySupported]){
                    self.loginModeType = DTLoginModeTypeLoginViaPhoneByPasskeyAuth;
                    [self loginViaPhoneByPasskeysAuthWithID:user_id phoneNumber:self.phoneNumber countryCode:countryCode];
                    return;
                }
                //TODO: 未拿到用户id 表示用户没有注册过passkeys 需要按照没有注册过passkeys的流程走
                [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:false];
            } else if (!exists && self.signType == DTSignTypeLogin ){
                [DTToastHelper hide];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"CHECK_USER_IS_NOT_EXITS", @"")];
            } else if (exists && self.signType == DTSignTypeRegister){//当前用户存在且目前在注册页面
                [DTToastHelper hide];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"CHECK_USER_IS_AREADY_EXITS", @"")];
            } else if (!exists && self.signType == DTSignTypeRegister){//当前用户存在且目前在注册页面
                [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:false];
            } else {
                [DTToastHelper hide];
                OWSLogInfo(@"checkAccountExistsWithEmail error");
            }
        } else {
            OWSLogInfo(@"[Passkey module] loginViaPhoneNumber error");
            [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:false];
        }
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        OWSLogInfo(@"[Passkey module] loginViaPhoneNumber error");
        [self requestLoginViaPhoneNumber:phoneNumber countryCode: countryCode shouldErrorToast:false];
    }];
}


- (void)loginViaEmail {
    self.loginModeType = DTLoginModeTypeLoginViaEmail;
    NSString *email = [self.tfAccount.text ows_stripped];
    self.email = email;
    self.phoneNumber = nil;
    [DTToastHelper showHudInView:self.view];
    [[self passKeyManager] checkAccountExistsWithEmail:email phoneNumber:nil sucess:^(DTAPIMetaEntity * _Nullable entity) {
        if(DTParamsUtils.validateDictionary(entity.data)){
            BOOL exists = [entity.data[@"exists"] boolValue];///当前账号是否存在
            NSString *user_id = entity.data[@"webauthnUserID"];///user_id passkey 注册后生成的user_id
            BOOL hasWebauthn = [entity.data[@"hasWebauthn"] boolValue];//用户是否注册了passkey
            [TSAccountManager sharedInstance].hasWebauthn = hasWebauthn;
            //当前用户存在且目前在登录页面
            if (exists && self.signType == DTSignTypeLogin ){
                if(hasWebauthn && DTParamsUtils.validateString(user_id) && [[self passKeyManager] isPasskeySupported]){
                    [DTToastHelper hide];
                    self.loginModeType = DTLoginModeTypeLoginViaEmailByPasskeyAuth;
                    [self loginViaEmailByPasskeysAuthWithID:user_id email:email];
                    return;
                }
                //TODO: 未拿到用户id 表示用户没有注册过passkeys 需要按照没有注册过passkeys的流程走
                [self requestLoginViaEmail:email shouldErrorToast:false];
            } else if (!exists && self.signType == DTSignTypeLogin ){
                [DTToastHelper hide];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"CHECK_USER_IS_NOT_EXITS", @"")];
            } else if (exists && self.signType == DTSignTypeRegister){//当前用户存在且目前在注册页面
                [DTToastHelper hide];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"CHECK_USER_IS_AREADY_EXITS", @"")];
            } else if (!exists && self.signType == DTSignTypeRegister){//当前用户存在且目前在注册页面
                [self requestLoginViaEmail:email shouldErrorToast:false];
            } else {
                [DTToastHelper hide];
                OWSLogInfo(@"checkAccountExistsWithEmail error");
            }
        } else {
            OWSLogInfo(@"[Passkey module] loginViaPhoneNumber error");
            [self requestLoginViaEmail:email shouldErrorToast:false];
        }
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        OWSLogInfo(@"[Passkey module] loginViaPhoneNumber error");
        [self requestLoginViaEmail:email shouldErrorToast:false];
    }];
}

- (void)verificationWasCompleted {
    if(self.loginModeType == DTLoginModeTypeLoginViaEmailByPasskeyAuth){[self saveEmailInStorage];}
    if(self.loginModeType == DTLoginModeTypeLoginViaPhoneByPasskeyAuth){ [self savePhoneInStorage];}
    ///通过手机号/邮箱进行登录
    [self requestContact];
    [[DTCallManager sharedInstance] requestForConfigMeetingversion];
}

- (void)requestContact {
    OWSLogInfo(@"requestContact ");
    NSString *localNumber = [TSAccountManager localNumber];
    @weakify(self);
    [[TSAccountManager sharedInstance] getContactMessageByReceptid:localNumber success:^(Contact* c) {
        OWSLogInfo(@"requestContact sucess");
        [DTToastHelper hide];
        @strongify(self);
        __block SignalAccount *account = nil;
        __block Contact *contact = nil;
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
            contact = c;
            if(contact){
                OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                account = [contactsManager signalAccountForRecipientId:localNumber transaction:writeTransaction];
                
                if (!account) {
                    account = [[SignalAccount alloc] initWithRecipientId:localNumber];
                }
                
                account.contact = contact;
                SignalAccount *newAccount = [account copy];
                [contactsManager updateSignalAccountWithRecipientId:localNumber withNewSignalAccount:newAccount withTransaction:writeTransaction];
            }
        });
        [self showHomeView];
    } failure:^(NSError *error) {
        @strongify(self);
        [DTToastHelper hide];
        OWSLogInfo(@"requestContact error");
        [self showHomeView];
    }];
}




- (void)saveEmailInStorage {
    OWSLogInfo(@"saveEmailInStorage");
    if(DTParamsUtils.validateString(self.email)){
        [TSAccountManager.shared storeUserEmail:self.email];
    }
}

- (void)savePhoneInStorage {
    OWSLogInfo(@"savePhoneInStorage");
    if(DTParamsUtils.validateString(self.phoneNumber)){
        [TSAccountManager.shared storeUserPhone:self.phoneNumber];
    }
}



- (void)showHomeView {
    [DTToastHelper hide];
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate switchToTabbarVCFromRegistration:YES];
}

//跳转到注册页面绑定邮箱
- (void)showSignViewController {
    DTSignInController *signInVC = [DTSignInController new];
    signInVC.signInModeType = self.signInModeType;
    signInVC.titleString =  [NSString stringWithFormat:@"Sign in to %@",TSConstants.appDisplayName];
    [self.navigationController pushViewController:signInVC animated:true];
}

#pragma mark invited Code login
- (void)registerWithInviteCode:(NSString *)inviteCode {
    [DTToastHelper showHudInView:self.view];
    @weakify(self);
    [[TSAccountManager
      sharedInstance]
     exchangeAccountWithInviteCode: inviteCode
     success:^(DTAPIMetaEntity *metaEntity){
        @strongify(self);
        BOOL accountOk = FALSE;
        do {
            NSDictionary *responseData = metaEntity.data;
            if (![responseData isKindOfClass:[NSDictionary class]]) { break;}
            NSString *number = [(NSDictionary *)responseData objectForKey:@"account"];
            if (number.length) {
                TSAccountManager *manager = [TSAccountManager sharedInstance];
                manager.phoneNumberAwaitingVerification = number;
            }
            NSString *vCode = [(NSDictionary *)responseData objectForKey:@"vcode"];
            NSString *inviter = [(NSDictionary *)responseData objectForKey:@"inviter"];
            if (!vCode) { break; }
            accountOk = TRUE;
            self.vCode = vCode;
            self.isNewRegister = @(1);
            [self sendinfoMessageWith:inviter];
            [self submitVerificationWithCode:self.vCode screenLock:nil];
            
        } while(false);
        if (FALSE == accountOk) {
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }
    }failure:^(NSError *error){
        [DTToastHelper hide];
        NSString *errorMessage = [NSError errorDesc:error errResponse:nil];
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
    }];
}


- (void)sendinfoMessageWith:(NSString *)inviter {
    __block TSContactThread *cThread = nil;
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        cThread = [TSContactThread getOrCreateThreadWithContactId:inviter transaction:writeTransaction];
        SignalAccount *account = [SignalAccount anyFetchWithUniqueId:cThread.contactIdentifier transaction:writeTransaction];
        OWSContactsManager *contactsManager = Environment.shared.contactsManager;
        if(account){
            Contact *contact = account.contact;
            if(!contact){
                contact = [[Contact alloc] initWithRecipientId:cThread.contactIdentifier];
            }
            contact.external = false;
            account.contact = contact;
            [contactsManager updateSignalAccountWithRecipientId:cThread.contactIdentifier withNewSignalAccount:account withTransaction:writeTransaction];
        } else {
            account = [[SignalAccount alloc] initWithRecipientId:cThread.contactIdentifier];
            Contact *contact = [[Contact alloc] initWithFullName:cThread.contactIdentifier phoneNumber:cThread.contactIdentifier];
            contact.external = false;
            account.contact = contact;
            [contactsManager updateSignalAccountWithRecipientId:cThread.contactIdentifier withNewSignalAccount:account withTransaction:writeTransaction];
        }
    });
}

- (void)submitVerificationWithCode:(NSString *)code screenLock:(DTScreenLockEntity * __nullable)screenlock {
    @weakify(self);
    [DTLoginNeedUnlockScreen checkIfNeedScreenlockWithVcode:code
                                                 screenlock:screenlock
                                                processedVc:self
                                         completionCallback:^{
        @strongify(self)
        [DTToastHelper hide];
        [self verificationWasCompleted];
    } errorBlock:^(NSString * _Nonnull errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [DTToastHelper hide];
        });
    }];
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:nil];
    if (textField == self.tfAccount && textField.text.length >1 && range.location == 0 && [string isEqualToString:@""]) {
        self.loginButton.isSelected = true;
        self.loginButton.userInteractionEnabled = true;
    } else if (textField == self.tfAccount && textField.text.length <= 1 && range.location == 0 && [string isEqualToString:@""]) {
        self.loginButton.isSelected = false;
        self.loginButton.userInteractionEnabled = false;
    } else {
        self.loginButton.isSelected = true;
        self.loginButton.userInteractionEnabled = true;
    }
    return YES;
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

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self loginButtonClick:nil];
    return true;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
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

// 注册流程
- (void)signupTipBtnClick:(UIButton *)sender {

    UIWindow *window = [[OWSWindowManager sharedManager] rootWindow];
    LoginViewController *loginVC = [LoginViewController new];
    OWSNavigationController *loginNav = [[OWSNavigationController alloc] initWithRootViewController:loginVC];
    window.rootViewController = loginNav;
}

#pragma mark setter & getter
- (UIImageView *)iconImageView {
    if(!_iconImageView){
        _iconImageView = [UIImageView new];
        _iconImageView.image = [UIImage imageNamed:@"login_logo"];
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
    }
    return _titleLabel;
}

- (DTTextField *)tfAccount {
    if(!_tfAccount){
        _tfAccount = [DTTextField new];
        _tfAccount.delegate = self;
        _tfAccount.clearButtonMode = UITextFieldViewModeWhileEditing;
        _tfAccount.placeholder = Localized(@"LOGIN_EMAIL_PLACEHOLDER_CHATIVE", @"");
        _tfAccount.keyboardAppearance = Theme.keyboardAppearance;
        _tfAccount.keyboardType = UIKeyboardTypeEmailAddress;
    }
    return _tfAccount;
}

- (OWSFlatButton *)loginButton {
    if(!_loginButton){
        _loginButton = [OWSFlatButton buttonWithTitle:Localized(@"CHATIVE_LOGIN_SIGN_IN", @"")
                                                 font:[OWSFlatButton orignalFontForHeight:16]
                                           titleColor:[UIColor whiteColor]
                                      backgroundColor:[UIColor ows_signalBrandBlueColor]
                                               target:self
                                             selector:@selector(loginButtonClick:)];
        
    }
    return _loginButton;
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

- (DTLoginWithEmailApi *)loginWithEmailApi {
    if(!_loginWithEmailApi){
        _loginWithEmailApi = [DTLoginWithEmailApi new];
    }
    return _loginWithEmailApi;
}

- (DTLoginWithPhoneNumberApi *)loginWithPhoneApi {
    if(!_loginWithPhoneApi){
        _loginWithPhoneApi = [DTLoginWithPhoneNumberApi new];
    }
    return _loginWithPhoneApi;
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
        [_countryCodeBtn setImage:[UIImage imageNamed:@"input_arrow"] forState:UIControlStateNormal];
        [_countryCodeBtn setTitleColor:Theme.primaryTextColor forState:UIControlStateNormal];
        _countryCodeBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [_countryCodeBtn addTarget:self action:@selector(countryCodeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
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
    }
    return _vLine;
}

- (UILabel *)transferLabel {
    if(!_transferLabel){
        _transferLabel = [UILabel new];
        _transferLabel.font = [UIFont ows_semiboldFontWithSize:14];
        _transferLabel.textAlignment = NSTextAlignmentRight;
        _transferLabel.textColor = Theme.primaryTextColor;
    }
    return _transferLabel;
}

- (UIButton *)signupTipBtn {
    if(!_signupTipBtn){
        _signupTipBtn = [UIButton new];
        [_signupTipBtn setTitleColor:UIColor.ows_darkSkyBlueColor forState:UIControlStateNormal];
        _signupTipBtn.titleLabel.font = [UIFont systemFontOfSize:15];
        [_signupTipBtn addTarget:self action:@selector(signupTipBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _signupTipBtn;
}

- (DTPasskeyManager *)passKeyManager {
    return [TSAccountManager sharedInstance].passKeyManager;
}

@end
