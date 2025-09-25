//
//  DTSignChativeController+EmailByVcodeLogin.h
//  Signal
//
//  Created by hornet on 2023/7/26.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "DTSignChativeController.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTSignChativeController (EmailByVcodeLogin)
- (void)requestLoginViaEmail:(NSString *)email shouldErrorToast:(BOOL) toast;
@end

NS_ASSUME_NONNULL_END
