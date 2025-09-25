//
//  DTVerificationCodeController.m
//  Signal
//
//  Created by hornet on 2022/10/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTVerificationCodeController.h"
#import "DTTextField.h"
#import "DTStepTextFiled.h"
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import <TTServiceKit/TSAccountManager.h>
#import "AppDelegate.h"
#import "SignalApp.h"
#import "TempTalk-Swift.h"
#import "DTChatLoginUtils.h"
#import <TTServiceKit/Localize_Swift.h>
#import <TTServiceKit/DTScreenLockEntity.h>
#import <TTMessaging/TTMessaging.h>

extern NSString *const kSendEmailCodeSucess;
extern NSString *const kSendEmailCodeForLoginSucess;
extern NSString *const kSendPhoneCodeForLoginSucess;

extern NSString *const kSendEmailCodeForChangeEmailSucess;
extern NSString *const kSendEmailCodeForChangePhoneSucess;

@interface DTVerificationCodeController ()
//@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *descLabel;
@property (nonatomic, strong) DTStepTextFiled *stepTextFiled;
@property (nonatomic, strong) OWSFlatButton *nextButton;
@property (nonatomic, strong) NSLayoutConstraint *nextButtonTopConstraint;
@property (nonatomic, strong) UILabel *errorTipLabel;
@property (nonatomic, strong) UIView *bottomContainview;
@property (nonatomic, strong) UILabel *bottomTipLabel;
@property (nonatomic, strong) UIButton *resendButton;
@property (nonatomic, strong) NSLayoutConstraint *errorTipLabelTopConstraint;
@property (nonatomic, strong) DTVerificationEmailCodeApi *verEmailCodeApi;
@property (nonatomic, strong) DTVerificationPhoneCodeApi *verPhoneCodeApi;
@property (nonatomic, strong) DTLoginWithEmailCodeApi *loginWithEmailCodeApi;
@property (nonatomic, strong) NSString *verCode;
@property (nonatomic, strong) NSString *email;
@property (nonatomic, strong) NSString *phone;
@property (nonatomic, readonly) AccountManager *accountManager;
@property (nonatomic, strong) dispatch_source_t timer;
@property (nonatomic, strong) DTBindEmailApi *bindEmailApi;
@property (nonatomic, strong) DTBindPhoneApi *bindPhoneApi;

@property (nonatomic, strong) DTLoginWithEmailApi *loginWithEmailApi;
@property (nonatomic, strong) DTLoginWithPhoneNumberApi *loginWithPhoneApi;
@property (nonatomic, strong) DTLoginWithPhoneCodeApi *loginWithPhoneCodeApi;
@property (nonatomic, strong) NSString *vCode;
@property (nonatomic) NSString *pin;

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *scrollContentView;
@property (nonatomic, strong) NSString *dialingCode;
@property (nonatomic, assign) BOOL isExecuteNexting;//是否正在执行下一步

@end
static dispatch_source_t _timer;

@implementation DTVerificationCodeController

- (instancetype)initWithEmail:(NSString *)email {
    self = [super init];
    if(self){
        self.email = email;
        self.descLabel.text = [NSString stringWithFormat:@"OTP sent to %@",[self.email ows_stripped]];
    }
    return self;
}
- (instancetype)initWithPhone:(NSString *)phone dialingCode:(nullable NSString *)dialingCode {
    self = [super init];
    if(self){
        self.phone = phone;
        self.dialingCode = dialingCode;
        self.descLabel.text = [NSString stringWithFormat:@"OTP sent to %@",[self.phone ows_stripped]];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self configSubViews];
    [self configSubviewLayout];
    [self applyTheme];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self configTimer];
    if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe || self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
        [self.nextButton setTitleWithTitle:Localized(@"Save", @"")];
    } else {
        [self.nextButton setTitleWithTitle:Localized(@"WEA_LOGIN_NEXT", @"")];
    }
}
- (void)setTitleString:(NSString *)titleString {
    self.titleLabel.text = titleString;
}

- (void)configTimer {
    NSString *timeStampString = nil;
    if(self.loginModeType == DTLoginModeTypeLoginViaEmail){
        timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:[DTChatLoginUtils accountWithEmail:[self.email ows_stripped] key:kSendEmailCodeForLoginSucess]];
    } else if(self.loginModeType == DTLoginModeTypeLoginViaPhone){
        timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:[DTChatLoginUtils accountWithEmail:[self.phone ows_stripped] key:kSendPhoneCodeForLoginSucess]];
    } else if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe){
        timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:[DTChatLoginUtils accountWithEmail:[self.phone ows_stripped] key:kSendEmailCodeForChangeEmailSucess]];
    } else if(self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
        timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:[DTChatLoginUtils accountWithEmail:[self.phone ows_stripped] key:kSendEmailCodeForChangePhoneSucess]];
    } else {
        timeStampString = [DTTokenKeychainStore loadPasswordWithAccountKey:[DTChatLoginUtils accountWithEmail:[self.email ows_stripped] key:kSendEmailCodeSucess]];
    }
    int64_t timeStamp = (int64_t)[NSDate ows_millisecondTimeStamp]/1000;
    __block uint64_t diff = 60;// default
    if(timeStampString ){
        int64_t timeStampNumber = (int64_t)[timeStampString longLongValue];
        if(60 - (timeStamp - timeStampNumber) > 0){
            diff = (uint64_t)(60 - (timeStamp - timeStampNumber));
        }
    }
    if(self->_timer){dispatch_cancel(self->_timer); self->_timer = nil;}
    self->_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    
    dispatch_source_set_timer(self->_timer, dispatch_walltime(NULL, 0), 1 * NSEC_PER_SEC, 0);
    @weakify(self);
    dispatch_source_set_event_handler(self->_timer, ^{
        @strongify(self);
        dispatch_async(dispatch_get_main_queue(), ^{
            if(diff > 0){
                [self->_resendButton setTitle:[NSString stringWithFormat:@"Resend(%llu s)",diff] forState:UIControlStateNormal];
                self->_resendButton.userInteractionEnabled = false;
                diff --;
            } else {
                self->_resendButton.userInteractionEnabled = true;
                [self->_resendButton setTitle:@"Resend" forState:UIControlStateNormal];
            }
        });
    });
    if(diff > 0){
        dispatch_resume(self->_timer);
    }
}

- (NSString *)accountWithPreString:(NSString *) account{
    NSString *email = [self.email ows_stripped];
    return [NSString stringWithFormat:@"%@_%@",kSendEmailCodeForLoginSucess,email];
}

//获取剪贴板的内容
- (void)checkPasteboardContent {
    NSString * pasteboardString = [UIPasteboard generalPasteboard].string;
    if(!DTParamsUtils.validateString(pasteboardString)){
        return;
    }
    NSString * vCode = [DTPatternHelper verification:pasteboardString];
    if(DTParamsUtils.validateString(vCode)){
        [self.stepTextFiled setContentTextValue:vCode];
        [UIPasteboard generalPasteboard].string = @"";
    }
}

- (void)checkOrResetTimeStamp {
    NSString *email = [self.email ows_stripped];
    if(self.loginModeType == DTLoginModeTypeLoginViaEmail){
        [DTChatLoginUtils checkOrResetTimeStampWith:email key:kSendEmailCodeForLoginSucess];
    } else if(self.loginModeType == DTLoginModeTypeLoginViaPhone){
        NSString *phone = [self.phone ows_stripped];
        [DTChatLoginUtils checkOrResetTimeStampWith:phone key:kSendPhoneCodeForLoginSucess];
    } else if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe){
        [DTChatLoginUtils checkOrResetTimeStampWith:email key:kSendEmailCodeForChangeEmailSucess];
    } else if(self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
        NSString *phone = [self.phone ows_stripped];
        [DTChatLoginUtils checkOrResetTimeStampWith:phone key:kSendEmailCodeForChangePhoneSucess];
   } else {
        [DTChatLoginUtils checkOrResetTimeStampWith:email key:kSendEmailCodeSucess];
    }
    if(self.timer){
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    [self configTimer];
}


- (void)viewDidLoad {
    
    _accountManager = SignalApp.sharedApp.accountManager;
    [self addObserver];
    self.isExecuteNexting = false;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:false animated:true];
}

- (void)addObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)applicationDidBecomeActive {
    [self checkPasteboardContent];
}

- (void)configSubViews {
    [self.view addSubview:self.scrollView];
    [self.scrollView addSubview:self.scrollContentView];
    
    [self.scrollContentView addSubview:self.titleLabel];
    [self.scrollContentView addSubview:self.descLabel];
    
    [self.scrollContentView addSubview:self.stepTextFiled];
    [self.scrollContentView addSubview:self.errorTipLabel];
    [self.scrollContentView addSubview:self.nextButton];
    
    self.bottomContainview = [UIView new];
    [self.scrollContentView addSubview:self.bottomContainview];
    [self.bottomContainview addSubview:self.bottomTipLabel];
    [self.bottomContainview addSubview:self.resendButton];
    self.errorTipLabel.hidden = true;
}


- (void)configSubviewLayout {
    UIWindow *window = [OWSWindowManager sharedManager].rootWindow;
    CGFloat safeAreaTop = window.safeAreaInsets.top;
    
    [self.scrollView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoPinEdgesToSuperviewEdges];
    [self.scrollContentView autoSetDimensionsToSize:[UIScreen mainScreen].bounds.size];
    
    [self.titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.view withOffset:safeAreaTop + 44 +36];
    [self.titleLabel autoHCenterInSuperview];
    
    [self.descLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.titleLabel withOffset:24];
    [self.descLabel autoSetDimension:ALDimensionHeight toSize:20];
    [self.descLabel autoPinLeadingToEdgeOfView:self.scrollContentView offset:16];
    [self.descLabel autoPinTrailingToEdgeOfView:self.scrollContentView offset:-16];
    
    [self.stepTextFiled autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.descLabel withOffset:24];
    [self.stepTextFiled autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    [self.stepTextFiled autoPinLeadingToEdgeOfView:self.scrollContentView offset:16];
    [self.stepTextFiled autoPinTrailingToEdgeOfView:self.scrollContentView offset:-16];
    
    [self.errorTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stepTextFiled withOffset:8];
    [self.errorTipLabel autoPinLeadingToEdgeOfView:self.stepTextFiled offset:0];
    [self.errorTipLabel autoPinTrailingToEdgeOfView:self.stepTextFiled offset:0];
    [self.errorTipLabel autoSetDimension:ALDimensionHeight toSize:16];
    
    [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stepTextFiled withOffset:32];
    [self.nextButton autoPinLeadingToEdgeOfView:self.stepTextFiled offset:0];
    [self.nextButton autoPinTrailingToEdgeOfView:self.stepTextFiled offset:0];
    [self.nextButton autoSetDimension:ALDimensionHeight toSize:kTextFiledHeight];
    
    [self.bottomContainview autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.nextButton withOffset:24];
    [self.bottomContainview autoHCenterInSuperview];
    [self.bottomContainview autoSetDimension:ALDimensionHeight toSize:16];
    
    [self.bottomTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.resendButton];
    [self.bottomTipLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.bottomContainview];
    [self.bottomTipLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.resendButton];
    [self.bottomTipLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.bottomContainview];
   
    [self.resendButton autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.bottomContainview];
    [self.resendButton autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.bottomContainview];
    [self.resendButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.bottomContainview];
}

- (void)resetSubviewsLayoutWithState:(DTLoginState)state errorMesssage:(NSString * __nullable) message {
    DispatchMainThreadSafe(^{
        if(state == DTLoginStateTypeLoginFailed){
            self.errorTipLabel.hidden = false;
            self.errorTipLabel.text = message;
            [self.errorTipLabelTopConstraint autoRemove];
            [self.nextButtonTopConstraint autoRemove];
            self.errorTipLabelTopConstraint = [self.errorTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stepTextFiled withOffset:16];
            self.nextButtonTopConstraint = [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.errorTipLabel withOffset:32];
            [self.view layoutIfNeeded];
        } else {
            self.errorTipLabel.hidden = true;
            self.errorTipLabel.text = @"";
            [self.nextButtonTopConstraint autoRemove];
            self.nextButtonTopConstraint = [self.nextButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stepTextFiled withOffset:32];
            [self.errorTipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.stepTextFiled withOffset:8];
            [self.view layoutIfNeeded];
        }
    });
}

- (void)applyTheme {
    [super applyTheme];
    self.view.backgroundColor = Theme.backgroundColor;
    self.titleLabel.textColor = Theme.primaryTextColor;
    self.descLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] :[UIColor colorWithRGBHex:0x474D57];
    self.bottomTipLabel.textColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xEAECEF] : [UIColor colorWithRGBHex:0x1E2329];
    [self.resendButton setTitleColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x4DA0FF] : [UIColor colorWithRGBHex:0x4DA0FF] forState:UIControlStateNormal];
    [self.resendButton setTitleColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x4DA0FF] : [UIColor colorWithRGBHex:0x4DA0FF] forState:UIControlStateHighlighted];
    
    [self.nextButton setTitleColor: [UIColor colorWithRGBHex:0xFFFFFF] for:UIControlStateSelected];
    [self.nextButton setTitleColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xB7BDC6] for:UIControlStateNormal];
    [self.nextButton setBackgroundColor:[UIColor colorWithRGBHex:0x056FFA] for:UIControlStateSelected];
    [self.nextButton setBackgroundColor: Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF] for:UIControlStateNormal];
}

- (void)nextButtonClick:(UIButton *)sender {
    [self performRequest];
}

- (void)executeNext {
    OWSLogInfo(@"perform executeNext");
    NSString *vcode = [self.verCode ows_stripped];
    [DTToastHelper showHudInView:self.view];
   
    if(self.loginModeType == DTLoginModeTypeLoginViaEmail){
        NSString *email = [self.email ows_stripped];
        self.isExecuteNexting = true;
        @weakify(self);
        [self.loginWithEmailCodeApi login:email verificationCode:vcode sucess:^(id<HTTPResponse>  _Nonnull response) {
            @strongify(self);
            self.isExecuteNexting = false;
            NSDictionary *data = response.responseBodyJson[@"data"];
            
            OWSLogInfo(@"perform login:verificationCode: sucess");
            if (!DTParamsUtils.validateDictionary(data)) {
                [DTToastHelper hide];
                return;
            }
            BOOL accountOk = FALSE;
            do {
                
                NSNumber *transferable = [data objectForKey:@"transferable"];
                ///0 表示不支持数据转移，1表示支持数据转移
                NSDictionary *tokens = [data objectForKey:@"tokens"];
                BOOL isCanTranfer = [transferable intValue] == 1 && DTParamsUtils.validateDictionary(tokens);
                
                if(isCanTranfer && DTParamsUtils.validateDictionary(tokens)){
                    
                    [DTToastHelper hide];
                    DTTransferDataViewController * transferDataVC = [[DTTransferDataViewController alloc] initWithLoginType:self.loginModeType email:self.email phoneNumber:self.phone dialingCode:self.dialingCode logintoken:tokens[@"logintoken"] ? : @"" tdtToken:tokens[@"tdtoken"] ? : @""];
                    DispatchMainThreadSafe(^{
                        [self.navigationController pushViewController:transferDataVC animated:true];
                    });
                   
                    return;
                } else {
                    
                    NSString *number = [data objectForKey:@"account"];
                    if (DTParamsUtils.validateString(number)) {
                        TSAccountManager *manager = [TSAccountManager sharedInstance];
                        manager.phoneNumberAwaitingVerification = number;
                    }
                    
                    NSNumber *nextStep = [data objectForKey:@"nextStep"];
                    if(DTParamsUtils.validateNumber(nextStep) && [nextStep intValue] == 0){//走注册流程
                        
                        self.loginModeType = DTLoginModeTypeRegisterEmailFromLogin;
                        NSString *invitationCode = [data objectForKey:@"invitationCode"];
                        if (!DTParamsUtils.validateString(invitationCode)) { break; }
                        accountOk = TRUE;
                        [self registerWithInviteCode:invitationCode];
                        
                    } else if (DTParamsUtils.validateNumber(nextStep) && [nextStep intValue] == 1) {//走登陆流程
                        
                        self.loginModeType = DTLoginModeTypeLoginViaEmail;
                        NSString *vCode = [data objectForKey:@"verificationCode"];
                        if (!DTParamsUtils.validateString(vCode)) { break; }
                        accountOk = TRUE;
                        self.vCode = vCode;
                        NSError *error;
                        DTScreenLockEntity * screenLock = [MTLJSONAdapter modelOfClass:[DTScreenLockEntity class]
                                                                    fromJSONDictionary:data
                                                                                 error:&error];
                        [self submitVerificationWithCode:self.vCode screenlock:screenLock];
                        
                    }
                }
            } while(false);
            
            if (FALSE == accountOk) {
                
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
                OWSLogInfo(@"LoginViaEmail loginWithEmailCodeApi login: verificationCode: sucess call Back accountOk = false  errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
                
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            
            @strongify(self);
            self.isExecuteNexting = false;
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            OWSLogInfo(@"LoginViaEmail fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            
        }];
    } else if (self.loginModeType == DTLoginModeTypeLoginViaPhone){
        
        self.isExecuteNexting = true;
        NSString *phone = [self.phone ows_stripped];
        @weakify(self);
        [self.loginWithPhoneCodeApi login:phone verificationCode:vcode sucess:^(id<HTTPResponse>  _Nonnull response) {
            @strongify(self);
            self.isExecuteNexting = false;
            NSDictionary *responseData = response.responseBodyJson;
            if (!DTParamsUtils.validateDictionary(responseData) ) {
                [DTToastHelper hide];
                return;
            }
            if(DTParamsUtils.validateNumber(responseData[@"status"]) && [responseData[@"status"] intValue] != 0){
                if(DTParamsUtils.validateString(responseData[@"reason"])){
                    [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:responseData[@"reason"]];
                }
                [DTToastHelper hide];
                return;
            }
            BOOL accountOk = FALSE;
            NSDictionary *data = response.responseBodyJson[@"data"];
            if (!DTParamsUtils.validateDictionary(data) ) {
                [DTToastHelper hide];
                return;
            }
            do {
                NSNumber *transferable = [data objectForKey:@"transferable"];
                ///0 表示不支持数据转移，1表示支持数据转移
                NSDictionary *tokens = [data objectForKey:@"tokens"];
                BOOL isCanTranfer = [transferable intValue] == 1 && DTParamsUtils.validateDictionary(tokens);
//                BOOL isCanTranfer = true;
                if(isCanTranfer && DTParamsUtils.validateDictionary(tokens)){
                    DTTransferDataViewController * transferDataVC = [[DTTransferDataViewController alloc] initWithLoginType:self.loginModeType email:self.email phoneNumber:self.phone dialingCode:self.dialingCode logintoken:tokens[@"logintoken"] tdtToken:tokens[@"tdtoken"]];
                    [self.navigationController pushViewController:transferDataVC animated:true];
                    return;
                } else {
                    NSString *number = [data objectForKey:@"account"];
                    if (number.length) {
                        TSAccountManager *manager = [TSAccountManager sharedInstance];
                        manager.phoneNumberAwaitingVerification = number;
                    }
                    NSNumber *nextStep = [data objectForKey:@"nextStep"];
                    if([nextStep intValue] == 0){//走注册流程
                        self.loginModeType = DTLoginModeTypeRegisterPhoneNumberFromLogin;
                        NSString *invitationCode = [data objectForKey:@"invitationCode"];
                        if (!invitationCode) { break; }
                        accountOk = TRUE;
                        [self registerWithInviteCode:invitationCode];
                    } else if ([nextStep intValue] == 1) {//走登陆流程
                        self.loginModeType = DTLoginModeTypeLoginViaPhone;
                        NSString *vCode = [data objectForKey:@"verificationCode"];
                        if (!vCode) { break; }
                        accountOk = TRUE;
                        self.vCode = vCode;
                        NSError *error;
                        DTScreenLockEntity * screenLock = [MTLJSONAdapter modelOfClass:[DTScreenLockEntity class]
                                                                    fromJSONDictionary:data
                                                                                 error:&error];
                        [self submitVerificationWithCode:self.vCode screenlock:screenLock];
                    }
                }
            } while(false);
            
            if (FALSE == accountOk) {
                [DTToastHelper hide];
                NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            self.isExecuteNexting = false;
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            OWSLogInfo(@"LoginViaPhone fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    } else if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe){
        if(!DTParamsUtils.validateString(vcode)) {
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"VERIFICATION_CODE_EMPTY", @"")];
        }
        self.isExecuteNexting = true;
        @weakify(self);
        [self.verEmailCodeApi verificationCode:vcode nonce:self.nonce sucess:^(id<HTTPResponse> _Nonnull response) {
            @strongify(self);
            self.isExecuteNexting = false;
            [DTToastHelper hide];
            [DTToastHelper _showSuccess:Localized(@"OPREATION_SUCCESS", @"")];
            [self verificationWasCompleted];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            self.isExecuteNexting = false;
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            OWSLogError(@"verificationCode  fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    } else if(self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
        NSString *phone = [self.phone ows_stripped];
        if(!DTParamsUtils.validateString(vcode)) {
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"VERIFICATION_CODE_EMPTY", @"")];
        }
        self.isExecuteNexting = true;
        @weakify(self);
        [self.verPhoneCodeApi verification:phone code:vcode nonce:self.nonce sucess:^(DTAPIMetaEntity *metaEntity) {
            @strongify(self);
            self.isExecuteNexting = false;
            [DTToastHelper hide];
            
            if (metaEntity.status == 10109 ||
                metaEntity.status == 10111) {
                NSString *newNonce = metaEntity.data[@"nonce"];
                if (DTParamsUtils.validateString(newNonce)) {
                    self.nonce = newNonce;
                } else {
                    self.nonce = nil;
                    OWSLogError(@"verPhoneCodeApi nonce is empty");
                }
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:@"Encountered an error, please resend!"];
            } else {
                [DTToastHelper _showSuccess:Localized(@"OPREATION_SUCCESS", @"")];
                [self verificationWasCompleted];
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            self.isExecuteNexting = false;
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            OWSLogError(@"verificationCode  fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    } else {
        if(!DTParamsUtils.validateString(vcode)) {
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:Localized(@"VERIFICATION_CODE_EMPTY", @"")];
        }
        self.isExecuteNexting = true;
        @weakify(self);
        [self.verEmailCodeApi verificationCode:vcode nonce:self.nonce sucess:^(id<HTTPResponse> _Nonnull response) {
            @strongify(self);
            self.isExecuteNexting = false;
            [DTToastHelper hide];
            if((self.loginModeType == DTLoginModeTypeChangeEmailFromMe) || (self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe)){
                [self.navigationController popToRootViewControllerAnimated:true];
            } else {
                [self verificationWasCompleted];
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            self.isExecuteNexting = false;
            
            if (DTParamsUtils.validateNumber([error httpStatusCode]) &&
                [error httpStatusCode].intValue == 403
                && errResponse.status == 24) {
                NSString *newNonce = errResponse.data[@"nonce"];
                if (DTParamsUtils.validateString(newNonce)) {
                    self.nonce = newNonce;
                } else {
                    self.nonce = nil;
                    OWSLogError(@"verEmailCodeApi nonce is empty");
                }
            }
            
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            OWSLogInfo(@"verificationCode  fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }];
    }
}

- (void)resendCode {
    [DTToastHelper showHudInView:self.view];
    if(self.loginModeType == DTLoginModeTypeLoginViaEmail){
        NSString *email = [self.email ows_stripped];
        @weakify(self);
        [self.loginWithEmailApi login:email sucess:^(id<HTTPResponse> _Nonnull _) {
            @strongify(self);
            [DTToastHelper hide];
            [self checkOrResetTimeStamp];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            if(errorMessage.length > 0){
                OWSLogInfo(@"resendCode fail LoginViaEmail errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else if(self.loginModeType == DTLoginModeTypeLoginViaPhone){
        NSString *phone = [self.phone ows_stripped];
        NSString *dialingCode = [self.dialingCode ows_stripped];
        @weakify(self);
        [self.loginWithPhoneApi login:phone dialingCode:dialingCode sucess:^(id<HTTPResponse> _Nonnull _) {
            @strongify(self);
            [DTToastHelper hide];
            [self checkOrResetTimeStamp];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            if(errorMessage.length > 0){
                OWSLogInfo(@"resendCode fail LoginViaPhone errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe){
        NSString *email = [self.email ows_stripped];
        [DTToastHelper showHudInView:self.view];
        @weakify(self);
        [self.bindEmailApi bind:email nonce:self.nonce sucess:^(id<HTTPResponse>  _Nonnull response) {
            @strongify(self);
            [DTToastHelper hide];
            [self checkOrResetTimeStamp];
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            if(errorMessage.length > 0){
                OWSLogInfo(@"resendCode fail LoginViaEmail errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else if(self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
        NSString *phone = [self.phone ows_stripped];
        NSString *dialingCode = [self.dialingCode ows_stripped];
        @weakify(self);
        [self.bindPhoneApi bind:phone dialingCode:dialingCode nonce:self.nonce sucess:^(DTAPIMetaEntity *metaEntity) {
            @strongify(self);
            [DTToastHelper hide];
            
            if (metaEntity.status == 10109 ||
                metaEntity.status == 10111) {
                NSString *newNonce = metaEntity.data[@"nonce"];
                if (DTParamsUtils.validateString(newNonce)) {
                    self.nonce = newNonce;
                } else {
                    self.nonce = nil;
                    OWSLogError(@"bindPhoneApi nonce is empty");
                }
                [self resendCode];
            } else {
                [self checkOrResetTimeStamp];
            }
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
            if(errorMessage.length > 0){
                OWSLogInfo(@"resendCode fail LoginViaPhone errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    } else {
        @weakify(self);
        [self.bindEmailApi bind:self.email nonce:self.nonce sucess:^(id<HTTPResponse>  _Nonnull response) {
            @strongify(self);
            [DTToastHelper hide];
            [self checkOrResetTimeStamp];
            
        } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nonnull errResponse) {
            @strongify(self);
            [DTToastHelper hide];
            
            if (DTParamsUtils.validateNumber([error httpStatusCode]) &&
                [error httpStatusCode].intValue == 403
                && errResponse.status == 24) {
                NSString *newNonce = errResponse.data[@"nonce"];
                if (DTParamsUtils.validateString(newNonce)) {
                    self.nonce = newNonce;
                } else {
                    self.nonce = nil;
                    OWSLogError(@"bindEmailApi nonce is empty");
                }
                [self resendCode];
            } else {
                
                NSString *errorMessage = [NSError errorDesc:error errResponse:errResponse];
                OWSLogInfo(@"bind fail errorMessage = %@",errorMessage);
                [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
            }
        }];
    }
}

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
            if (![responseData isKindOfClass:[NSDictionary class]]) {
                [DTToastHelper hide];
                OWSLogInfo(@"responseData = %@", responseData);
                break;}
            NSString *number = [(NSDictionary *)responseData objectForKey:@"account"];
            if (number.length) {
                TSAccountManager *manager = [TSAccountManager sharedInstance];
                manager.phoneNumberAwaitingVerification = number;
            }
            NSString *vCode = [(NSDictionary *)responseData objectForKey:@"vcode"];
            NSString *inviter = [(NSDictionary *)responseData objectForKey:@"inviter"];
            if (!vCode) {[DTToastHelper hide];  OWSLogInfo(@"vCode = %@", vCode);  break; }
            accountOk = TRUE;
            self.vCode = vCode;
//            [self sendinfoMessageWith:inviter];
            [self submitVerificationWithCode:self.vCode screenlock:nil];
            
        } while(false);
        if (FALSE == accountOk) {
            [DTToastHelper hide];
            NSString *errorMessage = [NSError errorDesc:nil errResponse:nil];
            OWSLogInfo(@"exchangeAccountWithInviteCode accountOk = false  fail errorMessage = %@",errorMessage);
            [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
        }
    }failure:^(NSError *error){
        [DTToastHelper hide];
        NSString *errorMessage = [NSError errorDesc:error errResponse:nil];
        OWSLogInfo(@"exchangeAccountWithInviteCode  fail errorMessage = %@",errorMessage);
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
    }];
}

- (void)sendinfoMessageWith:(NSString *)inviter {
    if(!DTParamsUtils.validateString(inviter)){return;};
    __block TSContactThread *cThread = nil;
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        if([TSContactThread getThreadWithContactId:inviter transaction:writeTransaction]){
            uint64_t now = [NSDate ows_millisecondTimeStamp];
            [[[TSInfoMessage alloc] initWithTimestamp:now
                                             inThread:cThread
                                          messageType:TSInfoMessageAddToContactsSucess] anyInsertWithTransaction:writeTransaction];
            
        }
    });
}


- (void)submitVerificationWithCode:(NSString *)code screenlock:(DTScreenLockEntity *)screenlock {
    OWSLogInfo(@"submitVerificationWithCode = %@", code);
    
    [DTLoginNeedUnlockScreen checkIfNeedScreenlockWithVcode:code
                                                 screenlock:screenlock
                                                processedVc:self
                                         completionCallback:^{
        [self verificationWasCompleted];
        [[TSAccountManager sharedInstance] setWasTransferred:false];
    } errorBlock:^(NSString * _Nonnull errorMessage) {
        [self resetSubviewsLayoutWithState:DTLoginStateTypeLoginFailed errorMesssage:errorMessage];
    }];
    
}

- (void)presentAlertWithVerificationError:(NSError *)error {
    UIAlertController *alert;
    alert = [UIAlertController
             alertControllerWithTitle:Localized(@"REGISTRATION_VERIFICATION_FAILED_TITLE", @"Alert view title")
             message:error.localizedDescription
             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:CommonStrings.dismissButton
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    }]];
    DispatchMainThreadSafe(^{
        [self presentViewController:alert animated:YES completion:nil];
    });
    
}

- (void)verificationWasCompleted {
    [[DTCallManager sharedInstance] requestForConfigMeetingversion];
    OWSLogInfo(@"verificationWasCompleted ");
    /// 通过邮箱注册
    if(self.loginModeType == DTLoginModeTypeRegisterEmailFromLogin) {
        [DTToastHelper hide];
        [self saveEmailInStorage];
            DTEditProfileController *editProfileController = [[DTEditProfileController alloc] initWithEmail:self.email phoneNumber:nil];
            editProfileController.loginType = DTLoginModeTypeRegisterEmailFromLogin;
            [self.navigationController pushViewController:editProfileController animated:true];
//        }
        ///通过手机号注册
    } else if (self.loginModeType == DTLoginModeTypeRegisterPhoneNumberFromLogin) {
        [DTToastHelper hide];
        [self savePhoneInStorage];
        DTEditProfileController *editProfileController = [[DTEditProfileController alloc] initWithEmail:nil phoneNumber:self.phone];
        editProfileController.loginType = DTLoginModeTypeRegisterPhoneNumberFromLogin;
        [self.navigationController pushViewController:editProfileController animated:true];
        
    } else if (self.loginModeType == DTLoginModeTypeChangeEmailFromMe ) {
        [self saveEmailInStorage];
        NSArray *viewControllers = self.navigationController.viewControllers;
        UIViewController *targetVC = nil;
        for (UIViewController *vc in [viewControllers reverseObjectEnumerator] ) {
            //TODO:temptalk need handle
            if ([vc isKindOfClass:DTAccountSettingController.class]){
                targetVC = vc;
                break;
            }
        }
        if(targetVC){
            [self.navigationController popToViewController:targetVC animated:true];
        } else {
            [self.navigationController popViewControllerAnimated:true];
        }
        return;
    } else if (self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe ) {
        [self savePhoneInStorage];
        NSArray *viewControllers = self.navigationController.viewControllers;
        UIViewController *targetVC = nil;
        for (UIViewController *vc in [viewControllers reverseObjectEnumerator] ) {
            //TODO:temptalk need handle
            if ([vc isKindOfClass:DTAccountSettingController.class]){
                targetVC = vc;
                break;
            }
        }
        if(targetVC){
            [self.navigationController popToViewController:targetVC animated:true];
        } else {
            [self.navigationController popViewControllerAnimated:true];
        }
        return;
    } else {
        if(self.loginModeType == DTLoginModeTypeLoginViaEmail){[self saveEmailInStorage];}
        if(self.loginModeType == DTLoginModeTypeLoginViaPhone){ [self savePhoneInStorage];}
        ///通过手机号/邮箱进行登录
        [self requestContact];
    }
    
}


- (void)saveEmailInStorage {
    OWSLogInfo(@"saveEmailInStorage");
    if(DTParamsUtils.validateString(self.email)){
        [TSAccountManager.shared storeUserEmail:self.email];
    }
}

- (void)savePhoneInStorage {
    OWSLogInfo(@"savePhoneInStorage");
    if(DTParamsUtils.validateString(self.phone)){
        [TSAccountManager.shared storeUserPhone:self.phone];
    }
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

- (void)resendButtonClick:(UIButton *)sender {
    [self resendCode];
}

- (void)changeEmailButtonClick:(UIButton *)sender {
    if(self.timer){
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
    [self.navigationController popViewControllerAnimated:true];
}

- (void)showHomeView {
    if(_timer){
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
    [[TSAccountManager shared] setIsDeregistered:true];
    [[TSAccountManager shared] setTransferedSucess:false];
    [DTToastHelper hide];
    
    // 登录后默认不提示绑定 passkey version: 3.1.0
//    if(self.loginModeType == DTLoginModeTypeLoginViaEmail){
//        if ([[self passKeyManager] isPasskeySupported] && ![TSAccountManager sharedInstance].hasWebauthn){
//            DTSetUpPasskeysController * setUpPasskeysVC = [DTSetUpPasskeysController new];
//            setUpPasskeysVC.loginType = DTLoginModeTypeLoginViaEmail;
//            setUpPasskeysVC.email = self.email;
//            [self.navigationController pushViewController:setUpPasskeysVC animated:true];
//            return;
//        }
//       
//    }
//    if(self.loginModeType == DTLoginModeTypeLoginViaPhone && ![TSAccountManager sharedInstance].hasWebauthn){
//        if ([[self passKeyManager] isPasskeySupported]){
//            DTSetUpPasskeysController * setUpPasskeysVC = [DTSetUpPasskeysController new];
//            setUpPasskeysVC.loginType = DTLoginModeTypeLoginViaPhone;
//            [self.navigationController pushViewController:setUpPasskeysVC animated:true];
//            return;
//        }
//    }
    // 检查resetKey的数据
    if ([TSAccountManager shared].isSameAccountRelogin) {
        [[DTSettingsManager shared] checkResetIdentifyKey];
    }
    AppDelegate *appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    [appDelegate switchToTabbarVCFromRegistration:YES];
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
        _descLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _descLabel;
}

- (DTStepTextFiled *)stepTextFiled {
    if(!_stepTextFiled){
        _stepTextFiled = [[DTStepTextFiled alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth-32, kTextFiledHeight)
                                               config:[self getTextFiledConfig]];
        @weakify(self)
        _stepTextFiled.finishBlock = ^(DTStepTextFiled *codeView, NSString *code) {
            @strongify(self)
            if(DTParamsUtils.validateString(code) && code.length == 6 ){
                self.verCode = [code ows_stripped];
                OWSLogInfo(@"perform executeNext finishBlock");
                if(self.loginModeType == DTLoginModeTypeChangeEmailFromMe || self.loginModeType == DTLoginModeTypeChangePhoneNumberFromMe){
                    return;
                }
                [self performRequest];
            }
        };
        _stepTextFiled.inputBlock = ^(NSString *code) {
            @strongify(self)
            if(DTParamsUtils.validateString(code) && code.length == 6 ){
                self.nextButton.isSelected = true;
                self.nextButton.userInteractionEnabled = true;
            } else {
                self.nextButton.isSelected = false;
                self.nextButton.userInteractionEnabled = false;
            }
            if(![code isEqualToString:self.verCode]){
                [self resetSubviewsLayoutWithState:DTLoginStateTypePreLogin errorMesssage:nil];
            }
        };
    }
    return _stepTextFiled;
}


- (DTStepTextFieldConfig *)getTextFiledConfig {
    NSInteger inputBoxNumber = 6;
    CGFloat screenW =  CGRectGetWidth(self.view.bounds);
    CGFloat space = 12;
    CGFloat x = 0;
//    CGFloat y = 0;
    CGFloat w =  ( screenW - space * 2 - x * ( inputBoxNumber + 1 ) ) /  inputBoxNumber;
    
    
    DTStepTextFieldConfig *config     = [[DTStepTextFieldConfig alloc] init];
    config.inputBoxNumber  = 6;
    config.inputBoxSpacing = space;
    config.inputBoxWidth   = w;
    config.inputBoxHeight  = kTextFiledHeight;
    config.tintColor       = [UIColor blueColor];
    config.secureTextEntry = false;
    config.inputBoxColor   = [Theme isDarkThemeEnabled] ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF];
    config.font            = [UIFont systemFontOfSize:24];
    config.textColor       = Theme.primaryTextColor;
    config.inputType       = DTStepTextFieldConfigInputType_Number;
    
    config.inputBoxBorderWidth  = 1;
    config.inputBoxCornerRadius = 4;

    //config.customInputHolder = @"🔒";

    config.keyboardType = UIKeyboardTypeNumberPad;
    config.useSystemPasswordKeyboard = false;
    config.autoShowKeyboard = true;
    config.autoShowKeyboardDelay = 0;
    
//    config.inputBoxFinishColors = @[[UIColor redColor],[UIColor orangeColor]];
//    config.finishFonts = @[[UIFont boldSystemFontOfSize:20],[UIFont systemFontOfSize:20]];
//    config.finishTextColors = @[[UIColor greenColor],[UIColor orangeColor]];
    return config;
}

- (void)performRequest {
    if(self.isExecuteNexting ){return;}
    [self executeNext];
}

- (UILabel *)errorTipLabel {
    if(!_errorTipLabel){
        _errorTipLabel = [UILabel new];
        _errorTipLabel.font = [UIFont systemFontOfSize:14];
        _errorTipLabel.textColor = [UIColor colorWithRGBHex:0xF6465D];
        _errorTipLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _errorTipLabel;
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
        _nextButton.isSelected = false;
        _nextButton.userInteractionEnabled = false;
    }
    return _nextButton;
}

- (void)dealloc {
    OWSLogDebug(@"%@",@"dealloc");
    if(_timer){
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}

- (UILabel *)bottomTipLabel {
    if(!_bottomTipLabel){
        _bottomTipLabel = [UILabel new];
        _bottomTipLabel.text = @"Didn't receive? ";
        _bottomTipLabel.font = [UIFont ows_regularFontWithSize:12];
    }
    return _bottomTipLabel;
}

- (UIButton *)resendButton {
    if(!_resendButton){
        _resendButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _resendButton.titleLabel.font = [UIFont ows_regularFontWithSize:12];
        [_resendButton addTarget:self action:@selector(resendButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _resendButton;
}

- (DTVerificationEmailCodeApi *)verEmailCodeApi {
    if(!_verEmailCodeApi){
        _verEmailCodeApi = [DTVerificationEmailCodeApi new];
    }
    return _verEmailCodeApi;
}

- (DTVerificationPhoneCodeApi *)verPhoneCodeApi {
    if(!_verPhoneCodeApi){
        _verPhoneCodeApi = [DTVerificationPhoneCodeApi new];
    }
    return _verPhoneCodeApi;
}

- (DTLoginWithEmailCodeApi *)loginWithEmailCodeApi {
    if(!_loginWithEmailCodeApi){
        _loginWithEmailCodeApi = [DTLoginWithEmailCodeApi new];
    }
    return _loginWithEmailCodeApi;
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

- (DTLoginWithPhoneCodeApi *)loginWithPhoneCodeApi {
    if(!_loginWithPhoneCodeApi){
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

- (DTPasskeyManager *)passKeyManager {
    return [TSAccountManager sharedInstance].passKeyManager;
}

@end
