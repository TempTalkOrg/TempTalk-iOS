//
//  DTServerSpeedTester.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServerSpeedTester.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTServerSpeedTester ()

@property (nonatomic, strong) RESTSpeedtestSessionManager * speedtestMainService;
@property (nonatomic, strong) OWSURLSession * speedtestNonMainService;

@property (nonatomic, weak) DTServerStatusEntity *serverStatusEntity;
@property (nonatomic, assign) DTServToType serverType;

@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;

@end

@implementation DTServerSpeedTester

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithServerStatusEntity:(DTServerStatusEntity *)serverStatusEntity serverType:(DTServToType)serverType{
    if(self = [super init]){
        self.serverStatusEntity = serverStatusEntity;
        self.serverType = serverType;
    }
    return self;
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)start
{
    [self willChangeValueForKey:@"isExecuting"];
    self.executing = YES;
    [self willChangeValueForKey:@"isExecuting"];
    
    [self startTest];

}

- (void)done {
    self.finished = YES;
    self.executing = NO;
    OWSLogInfo(@"Multi-server: speed test completion: serverType = %ld, isAvailable = %ld, url = %@, timeConsuming = %f", (long)self.serverType, (long)self.serverStatusEntity.isAvailable, self.serverStatusEntity.url, self.serverStatusEntity.timeConsuming);
}

- (void)startTest{
    
    if(!self.serverStatusEntity){
        [self done];
        return;
    }
    
    CFTimeInterval start = CACurrentMediaTime();
    NSString *urlString = [NSString stringWithFormat:@"https://%@?%f", self.serverStatusEntity.url, start];
    NSURL *url = [NSURL URLWithString:urlString];
    TSRequest *request = [TSRequest requestWithURL:url];
    request.shouldHaveAuthorizationHeaders = NO;
    
    OWSLogInfo(@"Multi-server: speed test begin %@.", urlString);
    
    if (self.serverType == DTServToTypeChat) {
        
        dispatch_async(NetworkManagerQueue(), ^{
            [self.speedtestMainService performRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
                
                self.serverStatusEntity.isAvailable = YES;
                self.serverStatusEntity.timeConsuming = CACurrentMediaTime() - start;
                [self done];
            } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
                
                NSError *errorWapper = error.asNSError;
                
                if(errorWapper.httpResponseData){
                    self.serverStatusEntity.isAvailable = YES;
                    self.serverStatusEntity.timeConsuming = CACurrentMediaTime() - start;
                }else{
                    self.serverStatusEntity.isAvailable = NO;
                    self.serverStatusEntity.timeConsuming = 30;
                }
                [self done];
            }];
        });
        
    } else {
        dispatch_async(NetworkManagerQueue(), ^{
            [self.speedtestNonMainService performNonmainRequest:request completeQueue:dispatch_get_main_queue() success:^(id<HTTPResponse>  _Nonnull response) {
                
                self.serverStatusEntity.isAvailable = YES;
                self.serverStatusEntity.timeConsuming = CACurrentMediaTime() - start;
                [self done];
            } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
                NSError *errorWapper = error.asNSError;
                
                if(errorWapper.httpResponseData){
                    self.serverStatusEntity.isAvailable = YES;
                    self.serverStatusEntity.timeConsuming = CACurrentMediaTime() - start;
                }else{
                    self.serverStatusEntity.isAvailable = NO;
                    self.serverStatusEntity.timeConsuming = 30;
                }
                [self done];
            }];
        });
    }
}

- (RESTSpeedtestSessionManager *)speedtestMainService {
    if (!_speedtestMainService) {
        _speedtestMainService = [RESTSpeedtestSessionManager new];
    }
    
    return _speedtestMainService;
}

- (OWSURLSession *)speedtestNonMainService {
    if (!_speedtestNonMainService) {
        _speedtestNonMainService = OWSSignalService.sharedInstance.urlSessionForNoneService;
    }
    
    return _speedtestNonMainService;
}

@end
