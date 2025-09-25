//
//  DTInviteRequestHandler.m
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

#import "DTInviteRequestHandler.h"
#import "TempTalk-Swift.h"

@implementation DTInviteRequestHandler

- (instancetype)initWithSourceVc:(UIViewController *)sourceVc {
    if (self = [super init]) {
        self.sourceVc = sourceVc;
    }
    return self;
}

- (void)queryUserAccountByInviteCode:(NSString *)inviteCode {
    
    [DTToastHelper show];
    DTQueryUserIdApi *queryUserIdApi = [DTQueryUserIdApi new];
    [queryUserIdApi quertByInviteCode:inviteCode sucess:^(id<HTTPResponse>  _Nonnull response) {
        [DTToastHelper hide];
        NSDictionary *data = response.responseBodyJson[@"data"];
        
        OWSLogInfo(@"perform login:verificationCode: sucess");
        if (!DTParamsUtils.validateDictionary(data)) {
            return;
        }
        NSString *recipientId = data[@"uid"];
        if (!DTParamsUtils.validateString(recipientId)) {
            [DTToastHelper toastWithText:@"recipientId is empty!"];
            return;
        }
        NSString *avatarJsonString = data[@"avatar"];
        NSDictionary *avatar = nil;
        NSString *joinedAt = nil;
        if (DTParamsUtils.validateString(avatarJsonString)) {
            avatar = [NSObject signal_dictionaryWithJSON:avatarJsonString];
        }
        if (DTParamsUtils.validateString(data[@"joinedAt"])) {
            joinedAt = data[@"joinedAt"];
        }
        
        [DTToastHelper show];
        [DTPersonalCardController preConfigureWithRecipientId:recipientId
                                                     complete:^(SignalAccount * account) {
            [DTToastHelper hide];
            account.contact.avatar = avatar;
            account.contact.joinedAt = joinedAt;
            if (DTParamsUtils.validateDictionary(avatar) || DTParamsUtils.validateString(joinedAt)) {
                DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
                    [contactsManager updateSignalAccountWithRecipientId:recipientId withNewSignalAccount:account withTransaction:writeTransaction];
                    [writeTransaction addAsyncCompletionOnMain:^{
                        [self showPersonalCardView:recipientId account:account];
                    }];
                });
            } else {
                [self showPersonalCardView:recipientId account:account];
            }
        }];
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        [DTToastHelper hide];
        NSString *errorString = [NSError errorDesc:error errResponse:entity];
        OWSLogError(@"quertByInviteCode error: %@", errorString);
        [DTToastHelper toastWithText:Localized(@"ENTER_CODE_ERRORTIPS", @"")];
    }];
}

- (void)showPersonalCardView:(NSString *)recipientId account:(SignalAccount * __nullable)account {
    DTPersonalCardType cardType = DTPersonalCardTypeOther;
    if ([recipientId isEqualToString:TSAccountManager.localNumber]) {
        cardType = DTPersonalCardTypeSelfNoneEdit;
    }
    DTPersonalCardController *cardVC = [[DTPersonalCardController alloc] initWithType:cardType recipientId:recipientId account:account];
    if (self.sourceVc.navigationController) {
        [self.sourceVc.navigationController pushViewController:cardVC animated:YES];
    } else {
        [self.sourceVc presentViewController:cardVC animated:YES completion:nil];
    }
}

@end
