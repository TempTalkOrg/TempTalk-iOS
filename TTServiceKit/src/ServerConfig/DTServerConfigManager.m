//
//  DTServerConfigManager.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

/*
 更新策略：
 1、启动；
 2、后台切前台；
 3、获取的空间未找到；
 4、30分钟只能更新一次；
 */

#import "DTServerConfigManager.h"
#import "DTFileDownloader.h"
#import "DTFileUtils.h"
#import "DTServerConfigMetaData.h"
#import "DTParamsBaseUtils.h"
#import "SSKCryptography.h"
#import "DTServersConfig.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const kServerConfigUpdatedNotify = @"serverConfigUpdatedNotify";

//static NSString *kServerConfigFileUrl = @"https://difft-config.oss-cn-shanghai.aliyuncs.com/global-config.json";

@interface DTServerConfigManager ()

@property (nonatomic, strong) NSMutableArray *configUrls;

@property (nonatomic, assign) NSTimeInterval lastTimeStamp;

@end

@implementation DTServerConfigManager

- (instancetype)init{
    if(self = [super init]){
        
        [self setup];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNofity:) name:UIApplicationDidBecomeActiveNotification object:nil] ;
    }
    return self;
}

- (void)setup{
    @synchronized (self) {
#if POD_CONFIGURATION_RELEASE_CHATIVETEST || POD_CONFIGURATION_RELEASE_TEST || POD_CONFIGURATION_DEBUG_TEST // 测试环境 scheme test
        self.configUrls = @[
            @"https://aly-c-config-1307206075.oss-accelerate.aliyuncs.com/testenv/TChative-MultiGlobalConfigureationFile.json"
        ].mutableCopy;
#else // 正式环境 scheme debug release
        self.configUrls = @[
            @"https://aly-c-config-1307206075.oss-accelerate.aliyuncs.com/Chative-MultiGlobalConfigureationFile.json",
            @"https://d3repcs3hxhwgl.cloudfront.net/Chative-MultiGlobalConfigureationFile.json",
            @"https://chative-config-files.s3.me-central-1.amazonaws.com/Chative-MultiGlobalConfigureationFile.json"
        ].mutableCopy;
#endif
    }
}

+ (instancetype)sharedManager{
    static DTServerConfigManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [DTServerConfigManager new];
    });
    
    return _sharedManager;
}

- (void)fetchConfigFromLocalWithSpaceName:(NSString *)spaceName
                               completion:(void (^)(id _Nullable, NSError * _Nullable))completion{
    if([[NSFileManager defaultManager] fileExistsAtPath:[DTFileUtils serverConfigFilePath]]){
        NSData *data = [NSData dataWithContentsOfFile:[DTFileUtils serverConfigFilePath]];
        NSError *error = nil;
        if (data) {
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if(error){
                completion(nil, error);
            }else{
                DTServerConfigMetaData *entity = [MTLJSONAdapter modelOfClass:[DTServerConfigMetaData class] fromJSONDictionary:jsonObject error:&error];
                if(error){
                    completion(nil, error);
                }else{
                    completion(entity.data[spaceName], error);
                }
            }
        } else {
            completion(nil, nil);
        }
    }else{
        completion(nil, nil);
    }
}

- (void)fetchServersConfigCompletion:(void (^)(id _Nullable, NSError * _Nullable))completion {
    if([[NSFileManager defaultManager] fileExistsAtPath:[DTFileUtils serverConfigFilePath]]){
        NSData *data = [NSData dataWithContentsOfFile:[DTFileUtils serverConfigFilePath]];
        NSError *error = nil;
        if (data) {
            NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (error) {
                completion(nil, error);
            } else {
                DTServerConfigMetaData *entity = [MTLJSONAdapter modelOfClass:[DTServerConfigMetaData class] fromJSONDictionary:jsonObject error:&error];
                if (error) {
                    completion(nil, error);
                } else {
                    NSArray *hosts = entity.data[@"hosts"];
                    NSDictionary *srvs = entity.data[@"srvs"];
                    NSString *avatarFile = entity.data[@"avatarFile"];
                    NSArray *domains = entity.data[@"domains"];
                    NSArray *services = entity.data[@"services"];
                    
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
            }
        } else {
            completion(nil, nil);
        }
    } else {
        completion(nil, nil);
    }
}

- (void)updateConfig{
    
    if(!self.configUrls.count){
        [self setup];
    }
    
    if(CACurrentMediaTime() - self.lastTimeStamp < 35 * 60){
        return;
    }
    
    [self fetchConfigFromServer];
}

- (void)fetchConfigFromServer {
    [self fetchConfigFromServerCompletion:nil];
}

- (void)fetchConfigFromServerCompletion:(void(^)(void))completion {
    
    NSString *firstUrlString = nil;
    @synchronized (self) {
        firstUrlString = self.configUrls.firstObject;
    }
    
    if(!DTParamsUtils.validateString(firstUrlString)){
        return;
    }
    
    [[DTFileDownloader defaultDownloader] downloadFileWithUrl:firstUrlString
                                                      success:^(NSData * _Nonnull fileData) {
        if(fileData.length){
            
            if([[NSFileManager defaultManager] fileExistsAtPath:[DTFileUtils serverConfigFilePath]]){
                NSData *data = [NSData dataWithContentsOfFile:[DTFileUtils serverConfigFilePath]];
                NSDictionary *config = [NSJSONSerialization JSONObjectWithData:fileData options:NSJSONReadingMutableContainers error:nil];
                OWSLogDebug(@"%@---\n%@", self.logTag, config);
                NSData *newDigest = [SSKCryptography computeMD5Digest:fileData];
                NSData *ourDigest = [SSKCryptography computeMD5Digest:data];
                if (!ourDigest || ![ourDigest ows_constantTimeIsEqualToData:newDigest]) {
                    [fileData writeToFile:[DTFileUtils serverConfigFilePath] atomically:YES];
                    [self dataUpdated];
                }
                
            }else{
                [fileData writeToFile:[DTFileUtils serverConfigFilePath] atomically:YES];
                [self dataUpdated];
            }
            if (completion) completion();
                
            self.lastTimeStamp = CACurrentMediaTime();
            
        }else{
            DDLogError(@"updateConfig data length == 0!");
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        @synchronized (self) {
            [self.configUrls removeObject:firstUrlString];
        }
        if(self.configUrls.count){
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self fetchConfigFromServerCompletion:completion];
            });
        }else{
            DDLogError(@"updateConfig failed! %@",error);
        }
        
    }];
}

- (void)dataUpdated{
    DDLogInfo(@"server-config ：%@ server config data updated",self.logTag);
    

    [self updateServicePath];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kServerConfigUpdatedNotify object:nil userInfo:nil];
}

// TODO: 放到测速位置？
- (void)updateServicePath {
    DTServersEntity *entity = [DTServersConfig fetchServersConfig];
}

- (void)applicationDidBecomeActiveNofity:(NSNotification *)nofity {
    [self updateConfig];
}

@end
