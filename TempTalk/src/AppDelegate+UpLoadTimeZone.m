//
//  AppDelegate+UpLoadTimeZone.m
//  TTMessaging
//
//  Created by hornet on 2021/11/29.
//

#import "AppDelegate+UpLoadTimeZone.h"
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/DTTokenKeychainStore.h>
#import <TTMessaging/TTMessaging.h>

@implementation AppDelegate (UpLoadTimeZone)

- (void)addUpLoadTimeZonObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateTimeZoneWhenSignificantTimeChange:)
                                                 name:UIApplicationSignificantTimeChangeNotification
                                               object:nil];
    
}

- (void)uploadTimeZone {
    NSString *timeZone = [self getTimeZoneFromCacheWithKey:[self timeZoneKey]];
    NSString *localTimeZoneString = [self localTimeZoneValue];
    OWSLogInfo(@"timeZone -> keychain local-cache:timeZone %@ local-time%@",timeZone, localTimeZoneString);
    if (!timeZone || timeZone.length == 0) {//缓存中没有直接上报
        [self uploadTimeZoneToTheServer];
    } else {//缓存中有 判断缓存中时区和当前时区是否一致。不一致进行上报
        if (![localTimeZoneString isEqualToString:timeZone]) {
            [self uploadTimeZoneToTheServer];
        }
    }
}

- (NSString *)getTimeZoneFromCacheWithKey:(NSString *) timeZoneKey{
    NSString *timeZone = [CurrentAppContext().appUserDefaults stringForKey:timeZoneKey];
    OWSLogInfo(@"timeZone -> storage getTimeZone local-cache:timeZone %@ local-time%@",timeZone, [self localTimeZoneValue]);
    return [DTTokenKeychainStore loadPasswordWithAccountKey:[self timeZoneKey]];
}

- (void)uploadTimeZoneToTheServer {
    NSString *localTimeZoneString = [self localTimeZoneValue];
    if (!localTimeZoneString || localTimeZoneString.length == 0) {
        return;
    }
    NSDictionary *parms = @{@"timeZone":localTimeZoneString};
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    OWSLogInfo(@"(AppDelegate+UpLoadTimeZone) putV1ProfileWithParams:%@",parms);
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if ([responseObject isKindOfClass:NSDictionary.class]) {
            
            NSNumber *status = (NSNumber *)responseObject[@"status"];
            if (responseObject && [status intValue] == 0 ) {//上报成功，本地进行缓存
                [self saveTimeZone:localTimeZoneString];
            }else {//上报失败
                OWSLogInfo(@"uploadTimeZoneToTheServer response error");
            }
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        OWSLogInfo(@"uploadTimeZoneToTheServer fail");
    }];
}

- (NSString *)localTimeZoneValue {//获取当前时区
    float localTimeZoneValue = DateUtil.currentTimeZone;
    
    NSString *localTimeZoneString = nil;
    if (localTimeZoneValue >= 0) {
        localTimeZoneString = [NSString stringWithFormat:@"+%.2f",localTimeZoneValue];
    } else {
        localTimeZoneString = [NSString stringWithFormat:@"%.2f",localTimeZoneValue];
    }
    return localTimeZoneString;
}

- (void)saveTimeZone:(NSString *)localTimeZoneString {
    NSString *key = [self timeZoneKey];
    [DTTokenKeychainStore setPassword:localTimeZoneString forAccount:key];
}

- (NSString *)timeZoneKey {
    return [NSString stringWithFormat:@"timeZone_%@",[TSAccountManager sharedInstance].localNumber];
}

- (void)updateTimeZoneWhenSignificantTimeChange:(NSNotification *)notify {
    if ([TSAccountManager isRegistered]) {
        [self uploadTimeZone];
    }
}
@end
