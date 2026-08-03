//
//  DTServerConfigManager.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import "DTServerConfigManager.h"
#import "DTFileDownloader.h"
#import "DTParamsBaseUtils.h"
#import "DTServersConfig.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const kServerConfigUpdatedNotify = @"serverConfigUpdatedNotify";

@interface DTServerConfigManager ()

@property (nonatomic, strong) NSMutableArray *configUrls;
@property (nonatomic, assign) NSTimeInterval lastTimeStamp;
@property (nonatomic, strong) NSData *cachedConfigData;

@end

@implementation DTServerConfigManager

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActiveNotify:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)setup {
    @synchronized (self) {
#if POD_CONFIGURATION_RELEASE_CHATIVETEST || POD_CONFIGURATION_RELEASE_TEST || POD_CONFIGURATION_DEBUG_TEST
        self.configUrls = @[
            @"https://aly-c-config-1307206075.oss-accelerate.aliyuncs.com/testenv/TChative-MultiGlobalConfigureationFile.json"
        ].mutableCopy;
#else
        self.configUrls = @[
            @"https://aly-c-config-1307206075.oss-accelerate.aliyuncs.com/Chative-MultiGlobalConfigureationFile.json",
            @"https://d3repcs3hxhwgl.cloudfront.net/Chative-MultiGlobalConfigureationFile.json",
            @"https://chative-config-files.s3.me-central-1.amazonaws.com/Chative-MultiGlobalConfigureationFile.json"
        ].mutableCopy;
#endif
    }
}

+ (instancetype)sharedManager {
    static DTServerConfigManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [DTServerConfigManager new];
    });
    return _sharedManager;
}

#pragma mark - Config Reading

- (NSData *)currentConfigData {
    @synchronized (self) {
        if (self.cachedConfigData) {
            return self.cachedConfigData;
        }
    }
    return [DTBundleConfigLoader loadBundleConfig];
}

- (void)fetchConfigFromLocalWithSpaceName:(NSString *)spaceName
                               completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    NSData *data = [self currentConfigData];
    NSError *error = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        completion(nil, error);
        return;
    }
    completion(jsonObject[spaceName], nil);
}

- (void)fetchConfigFromLocalWithSpaceName:(NSString *)spaceName
                              transaction:(SDSAnyReadTransaction *)transaction
                               completion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    NSData *data = [self currentConfigData];
    NSError *error = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        completion(nil, error);
        return;
    }
    completion(jsonObject[spaceName], nil);
}

- (void)fetchServersConfigCompletion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    NSData *data = [self currentConfigData];
    NSError *error = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        completion(nil, error);
        return;
    }

    NSArray *hosts = jsonObject[@"hosts"];
    NSDictionary *srvs = jsonObject[@"srvs"];
    NSString *avatarFile = jsonObject[@"avatarFile"];
    NSArray *domains = jsonObject[@"domains"];
    NSArray *services = jsonObject[@"services"];

    NSMutableDictionary *dictM = @{}.mutableCopy;
    if (DTParamsUtils.validateArray(hosts)) {
        dictM[@"hosts"] = hosts;
    }
    if (DTParamsUtils.validateDictionary(srvs)) {
        dictM[@"srvs"] = srvs;
    }
    if (DTParamsUtils.validateString(avatarFile)) {
        dictM[@"avatarFile"] = avatarFile;
    }
    if (DTParamsUtils.validateArray(domains)) {
        dictM[@"domains"] = domains;
    }
    if (DTParamsUtils.validateArray(services)) {
        dictM[@"services"] = services;
    }

    if (dictM.allKeys.count > 0) {
        completion(dictM.copy, error);
    } else {
        completion(nil, error);
    }
}

#pragma mark - CDN Update

- (void)updateConfig {
    if (!self.configUrls.count) {
        [self setup];
    }
    if (self.lastTimeStamp > 0 && CACurrentMediaTime() - self.lastTimeStamp < 35 * 60) {
        return;
    }
    [self fetchConfigFromServer];
}

- (void)fetchConfigFromServer {
    [self fetchConfigFromServerCompletion:nil];
}

- (void)fetchConfigFromServerCompletion:(void (^_Nullable)(void))completion {
    NSString *firstUrlString = nil;
    @synchronized (self) {
        firstUrlString = self.configUrls.firstObject;
    }

    if (!DTParamsUtils.validateString(firstUrlString)) {
        OWSLogWarn(@"[GlobalConfig] No valid config URL, skipping fetch");
        if (completion) completion();
        return;
    }

    OWSLogInfo(@"[GlobalConfig] Fetching config from: %@", firstUrlString);

    [[DTFileDownloader defaultDownloader] downloadFileWithUrl:firstUrlString
                                                      success:^(NSData * _Nonnull fileData) {
        if (!fileData.length) {
            OWSLogError(@"[GlobalConfig] Downloaded data length == 0");
            if (completion) completion();
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:nil];
        NSData *configData = nil;
        if (json[@"data"]) {
            configData = [NSJSONSerialization dataWithJSONObject:json[@"data"] options:0 error:nil];
        }

        if (!configData) {
            OWSLogWarn(@"[GlobalConfig] Failed to extract 'data' from CDN response");
            if (completion) completion();
            return;
        }

        @synchronized (self) {
            self.cachedConfigData = configData;
        }
        OWSLogInfo(@"[GlobalConfig] Config updated from CDN");

        [self dataUpdated];
        self.lastTimeStamp = CACurrentMediaTime();
        if (completion) completion();

    } failure:^(NSError * _Nonnull error) {
        @synchronized (self) {
            [self.configUrls removeObject:firstUrlString];
        }
        if (self.configUrls.count) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self fetchConfigFromServerCompletion:completion];
            });
        } else {
            OWSLogError(@"[GlobalConfig] All CDN URLs failed: %@", error);
            if (completion) completion();
        }
    }];
}

- (void)dataUpdated{
    OWSLogInfo(@"server-config ：%@ server config data updated",self.logTag);
    [TSConstants invalidateServerConfigCache];
    [DTServersConfig fetchServersConfig];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kServerConfigUpdatedNotify object:nil userInfo:nil];
}

- (void)applicationDidBecomeActiveNotify:(NSNotification *)notification {
    [self updateConfig];
}

@end
