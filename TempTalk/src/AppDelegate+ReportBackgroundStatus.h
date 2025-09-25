//
//  AppDelegate+ReportBackgroundStatus.h
//  Wea
//
//  Created by Ethan on 25/05/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (ReportBackgroundStatus)

- (void)reportBackgroundStatusByWebSocket:(BOOL)inBackground;

- (void)reportBackgroundStatusByHttp:(BOOL)inBackground;

@end

NS_ASSUME_NONNULL_END
