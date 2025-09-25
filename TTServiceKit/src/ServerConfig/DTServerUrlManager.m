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
            OWSLogInfo(@"Multi-server: %@ create %@ server status items cout = %ld",self.logTag, [self getServersEntityPropertyNameWithServerType:serverType], (long)oneServerStatusItems.count);
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
    
    NSArray *newItems = [availableItems sortedArrayUsingComparator:^NSComparisonResult(DTServerStatusEntity *obj1, DTServerStatusEntity *obj2) {
        NSNumber *number1 = [NSNumber numberWithDouble:obj1.timeConsuming];
        NSNumber *number2 = [NSNumber numberWithDouble:obj2.timeConsuming];
        return [number1 compare:number2];
    }];
    
    NSMutableArray *urls = @[].mutableCopy;
    [newItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [urls addObject:obj.url];
    }];
    
    OWSLogInfo(@"Multi-server: %@ get urls count = %ld contents = %@",self.logTag, (long)urls.count, urls);
    return urls;
    
}

- (void)markAsInvalidWithUrl:(NSString *)url serverType:(DTServToType)serverType {
    
    NSMutableArray *oneServerStatusItems = [self getOrCreateOneServerStatusItemsWithServerType:serverType].mutableCopy;
    
    [oneServerStatusItems enumerateObjectsUsingBlock:^(DTServerStatusEntity *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(obj.isAvailable && [url isEqualToString:obj.url]){
            obj.isAvailable = NO;
            OWSLogInfo(@"Multi-server: %@ mark as invalid url = %@",self.logTag, url);
        }
    }];
    
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

- (void)startSpeedTestAll{
    OWSLogInfo(@"Multi-server: startSpeedTestAll.");
    
    NSArray *serverTypes = @[@(DTServToTypeChat)];
    
    [serverTypes enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self startSpeedTestWithServerType:obj.integerValue];
    }];
}

- (void)startSpeedTestWithServerType:(DTServToType)serverType{
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        
        OWSLogInfo(@"Multi-server: startSpeedTestWithServerType: %ld.", serverType);
        
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
        [self.serverUrlsInfo removeAllObjects];
        OWSLogInfo(@"Multi-server: %@ reset all servers",self.logTag);
    }
}

- (void)resetWithServerType:(DTServToType)serverType{
    
    @synchronized(self){
        NSString *propertyName = [self getServersEntityPropertyNameWithServerType:serverType];
        [self.serverUrlsInfo removeObjectForKey:propertyName];
        OWSLogInfo(@"Multi-server: %@ reset %@ server",self.logTag, propertyName);
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
    OWSLogInfo(@"Multi-server: %@ active notify, start speed test.",self.logTag);
    
    [self startSpeedTestAll];
}
 */

- (void)serverConfigUpdatedNofity:(NSNotification *)nofity{
    
    OWSLogInfo(@"Multi-server: %@ server config updated nofity",self.logTag);
    
    [self resetAll];
    [self startSpeedTestAll];
}

@end
