//
//  DTServerUrlManager.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServerUrlManager.h"
#import "DTParamsBaseUtils.h"
#import "DTServerSpeedTester.h"
#import "objc/runtime.h"
#import "DTServerConfigManager.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

static NSString *kQueueOperationsChanged = @"kQueueOperationsChanged";

double const kDefaultTestInterval = 30 * 60; // 30 minute
//double const kDefaultTestInterval = 10; // 10 second

static void * lastCompleteTimePropertyKey = &lastCompleteTimePropertyKey;

@interface NSOperationQueue (DTTags)

@end

@implementation NSOperationQueue (DTTags)

- (NSNumber *)lastCompleteTime{
    return objc_getAssociatedObject(self, lastCompleteTimePropertyKey);
}

- (void)setLastCompleteTime:(NSNumber *)time {
    objc_setAssociatedObject(self, lastCompleteTimePropertyKey, time, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


@interface DTServerUrlManager ()

@property (nonatomic, strong) DTServersEntity *serversEntity;
@property (atomic, strong) NSMutableDictionary *serverUrlsInfo;

//@property (nonatomic, strong) NSOperationQueue *speedTestQueue;
@property (atomic, strong) NSMutableDictionary<NSString *, NSOperationQueue *> *speedTestQueueMap;

@end

@implementation DTServerUrlManager

+ (instancetype)sharedManager{
    static DTServerUrlManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [DTServerUrlManager new];
    });
    
    return _sharedManager;
}

- (instancetype)init{
    if(self = [super init]){
        self.serverUrlsInfo = @{}.mutableCopy;
        self.speedTestQueueMap = @{}.mutableCopy;
//        self.speedTestQueue = [NSOperationQueue new];
////        self.speedTestQueue.qualityOfService = NSOperationQualityOfServiceUserInitiated;
//        self.speedTestQueue.maxConcurrentOperationCount = 8;
        
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNofity:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverConfigUpdatedNofity:) name:kServerConfigUpdatedNotify object:nil];
    }
    return self;
}

- (DTServersEntity *)serversEntity{
    if(!_serversEntity){
        _serversEntity = [DTServersConfig fetchServersConfig];
    }
    return _serversEntity;
}

- (NSOperationQueue *)speedTestQueueWithServerType:(DTServToType)serverType{

    @synchronized(self)
    {
        NSString *key = [self getServersEntityPropertyNameWithServerType:serverType];
        NSOperationQueue *speedTestQueue = self.speedTestQueueMap[key];

        if (!speedTestQueue) {
            speedTestQueue = [NSOperationQueue new];
            speedTestQueue.maxConcurrentOperationCount = 3;
            speedTestQueue.qualityOfService = NSQualityOfServiceBackground;
            speedTestQueue.name = [self queueNameWithServerType:serverType];
            [speedTestQueue addObserver:self forKeyPath:@"operations" options:0 context:&kQueueOperationsChanged];

            self.speedTestQueueMap[key] = speedTestQueue;
        }

        return speedTestQueue;
    }
}

- (NSString *)queueNameWithServerType:(DTServToType)serverType{
    NSString *key = [self getServersEntityPropertyNameWithServerType:serverType];
    return [NSString stringWithFormat:@"%@QUEUE", key];
}

- (NSString *)getServersEntityPropertyNameWithServerType:(DTServToType)serverType{
    NSString *propertyName = nil;
    switch (serverType) {
        case DTServToTypeChat:
        {
            propertyName = @"chat";
        }
            break;
//        case DTServToTypeFuse:
//        {
//            propertyName = @"fuse";
//        }
//            break;
        default:
            break;
    }
    return propertyName;
}

- (NSArray *)getOrCreateOneServerStatusItemsWithServerType:(DTServToType)serverType {
    
    NSString *propertyName = [self getServersEntityPropertyNameWithServerType:serverType];

    @synchronized(self){
    
        NSArray *oneServerStatusItems = self.serverUrlsInfo[propertyName];
        if(!oneServerStatusItems.count){
            NSArray<DTServerHostEntity *> *urls = self.serversEntity.hosts; //[self.serversEntity valueForKey:propertyName];
            NSMutableArray *serverStatusItems = @[].mutableCopy;
            [urls enumerateObjectsUsingBlock:^(DTServerHostEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.servTo isEqualToString:propertyName]) {
                    NSString *url = obj.name;
                    if(DTParamsUtils.validateString(url)){
                        DTServerStatusEntity *statusEntity = [DTServerStatusEntity new];
                        statusEntity.url = url;
                        [serverStatusItems addObject:statusEntity];
                    }
                }
            }];
            oneServerStatusItems = serverStatusItems.copy;
            self.serverUrlsInfo[propertyName] = oneServerStatusItems;
            OWSLogInfo(@"[DomainSwitch] %@ create %@ items count = %ld",self.logTag, [self getServersEntityPropertyNameWithServerType:serverType], (long)oneServerStatusItems.count);
        }
        
        OWSAssertDebug(oneServerStatusItems.count);
        if(!oneServerStatusItems.count){
            OWSProdError(@"one server status items count == 0");
            DTServerStatusEntity *statusEntity = [DTServerStatusEntity new];
            statusEntity.url = @"https://chat.chative.im";
            return @[statusEntity];
        }
        
        return oneServerStatusItems.copy;
    }
}

- (NSArray<NSString *> *)getTheServerUrlsWithServerType:(DTServToType)serverType{

    // Under proxy: chat candidates are exactly the proxy.tunnelDomains.chat list (server config,
    // else tier-2 derived), rotated within — never the speed-tested multi-origin pool.
    if (serverType == DTServToTypeChat) {
        NSArray<NSString *> *chatDomains = [ProxyManager shared].tunnelChatDomains;
        if (chatDomains.count) {
            return chatDomains;
        }
    }

    NSArray *oneServerStatusItems = [self getOrCreateOneServerStatusItemsWithServerType:serverType];
    NSMutableArray *availableItems = @[].mutableCopy;
    [oneServerStatusItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(obj.isAvailable){
            [availableItems addObject:obj];
        }
    }];

    if (!availableItems.count) {
        [self resetWithServerType:serverType];
        [self startSpeedTestWithServerType:serverType];
        return [self getTheServerUrlsWithServerType:serverType];
    }

    NSString *lastSuccessfulHost = [[DTLastSuccessfulHostManager shared] getLastSuccessfulHostWithServerType:serverType];

    NSArray *newItems = [availableItems sortedArrayUsingComparator:^NSComparisonResult(DTServerStatusEntity *obj1, DTServerStatusEntity *obj2) {
        BOOL obj1IsLast = (lastSuccessfulHost && [lastSuccessfulHost isEqualToString:obj1.url]);
        BOOL obj2IsLast = (lastSuccessfulHost && [lastSuccessfulHost isEqualToString:obj2.url]);
        if (obj1IsLast && !obj2IsLast) return NSOrderedAscending;
        if (!obj1IsLast && obj2IsLast) return NSOrderedDescending;
        return [@(obj1.timeConsuming) compare:@(obj2.timeConsuming)];
    }];

    NSMutableArray *urls = @[].mutableCopy;
    [newItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [urls addObject:obj.url];
    }];

    OWSLogInfo(@"[DomainSwitch] %@ get urls count = %ld contents = %@",self.logTag, (long)urls.count, urls);
    return urls;

}

- (BOOL)containsHost:(NSString *)host serverType:(DTServToType)serverType {
    if (!DTParamsUtils.validateString(host)) {
        return NO;
    }
    NSString *normalized = [[host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSArray<DTServerStatusEntity *> *items = [self getOrCreateOneServerStatusItemsWithServerType:serverType];
    for (DTServerStatusEntity *item in items) {
        if (!DTParamsUtils.validateString(item.url)) { continue; }
        NSString *candidate = [[item.url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
        if ([candidate isEqualToString:normalized]) {
            return YES;
        }
    }
    return NO;
}

- (void)markAsInvalidWithUrl:(NSString *)url serverType:(DTServToType)serverType {

    NSMutableArray *oneServerStatusItems = [self getOrCreateOneServerStatusItemsWithServerType:serverType].mutableCopy;

    [oneServerStatusItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(obj.isAvailable && [url isEqualToString:obj.url]){
            obj.isAvailable = NO;
            OWSLogInfo(@"[DomainSwitch] %@ mark invalid: %@",self.logTag, url);
        }
    }];

    // Record the invalidated host so late-arriving success callbacks won't re-persist it.
    [[DTLastSuccessfulHostManager shared] markHostInvalidated:url serverType:serverType];

    // Clear the in-memory override in TSConstants so subsequent requests
    // don't keep using this now-invalid host. Under proxy the chat override is the
    // failover rotation pointer within the fixed tunnelDomains list (rotated by
    // switchServerHost), so don't clear it there.
    if (serverType == DTServToTypeChat && ![ProxyManager shared].isEnabled) {
        TSConstants.mainServiceHost = @"";
    }
}

/*
- (DTServerStatusEntity *)getTheBestServerUrlWithServerType:(DTServerToType)serverType{
    
    NSArray *oneServerStatusItems = [self getOrCreateOneServerStatusItemsWithServerType:serverType];
    
    __block DTServerStatusEntity *serverStatusEntity = nil;
    [oneServerStatusItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(!serverStatusEntity && obj.isAvailable){
            serverStatusEntity = obj;
        }else{
            if(obj.isAvailable &&
               serverStatusEntity.timeConsuming > obj.timeConsuming &&
               obj.tested){
                serverStatusEntity = obj;
            }
        }
    }];
    
    if(!serverStatusEntity){
        [self resetWithServerType:serverType];
        return [self getTheBestServerUrlWithServerType:serverType];
    }else{
        return serverStatusEntity;
    }
    
    
}
 */

- (void)markAsInvalidWithServerStatusEntity:(DTServerStatusEntity *)entity{
    entity.isAvailable = NO;
}

- (void)cancelAllSpeedTests{
    @synchronized(self){
        [self.speedTestQueueMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSOperationQueue *queue, BOOL *stop) {
            [queue cancelAllOperations];
        }];
    }
}

- (void)startSpeedTestAll{
    OWSLogInfo(@"[DomainSwitch] startSpeedTestAll");
    
    NSArray *serverTypes = @[@(DTServToTypeChat)];
    
    [serverTypes enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self startSpeedTestWithServerType:obj.integerValue];
    }];
}

- (void)startSpeedTestWithServerType:(DTServToType)serverType{

    // Under proxy: chat is pinned to one domain, so speed-testing the others (which dials them
    // directly and leaks the real IP) is both unnecessary and unsafe — skip it.
    if (serverType == DTServToTypeChat && [ProxyManager shared].isEnabled) {
        return;
    }

//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

        OWSLogInfo(@"[DomainSwitch] startSpeedTest type: %ld", (long)serverType);
        
        if(CACurrentMediaTime() - [self speedTestQueueWithServerType:serverType].lastCompleteTime.doubleValue >= kDefaultTestInterval){
            NSArray *oneServerStatusItems = [self getOrCreateOneServerStatusItemsWithServerType:serverType];
            if(oneServerStatusItems.count <= 1) return;
            
            [oneServerStatusItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                DTServerSpeedTester *tester = [[DTServerSpeedTester alloc] initWithServerStatusEntity:obj serverType:serverType];
                [[self speedTestQueueWithServerType:serverType] addOperation:tester];
            }];
        }
//    });
}

- (void)resetAll{
    @synchronized(self){
        _serversEntity = nil;
        self.serverUrlsInfo = @{}.mutableCopy;
        OWSLogInfo(@"[DomainSwitch] %@ reset all servers",self.logTag);
    }
}

- (void)resetWithServerType:(DTServToType)serverType{
    
    @synchronized(self){
        NSString *propertyName = [self getServersEntityPropertyNameWithServerType:serverType];
        [self.serverUrlsInfo removeObjectForKey:propertyName];
        OWSLogInfo(@"[DomainSwitch] %@ reset %@ server",self.logTag, propertyName);
    }
}


- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if ([object isKindOfClass:[NSOperationQueue class]] && [keyPath isEqualToString:@"operations"] && context == &kQueueOperationsChanged) {
        
        NSOperationQueue *queue = (NSOperationQueue *)object;
        
        if ([queue.operations count] == 0) {
            // Do something here when your queue has completed
            queue.lastCompleteTime = @(CACurrentMediaTime());
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object
                               change:change context:context];
    }
}

/*
- (void)applicationDidBecomeActiveNofity:(NSNotification *)nofity{
    OWSLogInfo(@"[DomainSwitch] %@ active notify, start speed test",self.logTag);
    
    [self startSpeedTestAll];
}
 */

- (void)serverConfigUpdatedNofity:(NSNotification *)nofity{
    
    OWSLogInfo(@"[DomainSwitch] %@ server config updated",self.logTag);
    
    [self cancelAllSpeedTests];
    [self resetAll];
    [self startSpeedTestAll];
}

@end
