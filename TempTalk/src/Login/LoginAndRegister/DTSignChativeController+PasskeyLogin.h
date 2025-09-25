//
//  DTSignChativeController+Login.h
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTSignChativeController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTSignChativeController (PasskeyLogin)
- (void)loginViaEmailByPasskeysAuthWithID:(NSString *)user_id email:(NSString *)email;
- (void)loginViaPhoneByPasskeysAuthWithID:(NSString *)user_id phoneNumber:(NSString *)phoneNumber countryCode:(NSString *)countryCode ;
@end

NS_ASSUME_NONNULL_END
