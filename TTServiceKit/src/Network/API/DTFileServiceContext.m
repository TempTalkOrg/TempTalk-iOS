//
//  DTFileServiceContext.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/12.
//

#import "DTFileServiceContext.h"
#import "DTBaseAPI.h"

@interface DTFileServiceContext ()

@property (nonatomic, assign) NSUInteger retryCount;

@property (nonatomic, assign) NSTimeInterval lastRefreshTokenTime;

@end

@implementation DTFileServiceContext

- (instancetype)init{
    if(self = [super init]){
        self.retryCount = 3;
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static DTFileServiceContext *sharedInstance;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

- (void)fetchAuthTokenWithSuccess:(void (^)(NSString * _Nonnull))success
                          failure:(void (^)(NSError * ))failure{
    
    if([self calculateTokenValiditeTime]){
        success(self.authToken);
        return;
    }
    
    DTBaseAPI *api = [DTBaseAPI new];
    TSRequest *request = [OWSRequestFactory userStateWSTokenAuthRequestWithAppId:nil];
    [api sendRequest:request
             success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSString *token = entity.data[@"token"];
        if(DTParamsUtils.validateString(token)){
            [[self class] decodeWithJwtString:token];
            self.authToken = token;
            self.lastRefreshTokenTime = [[NSDate date] timeIntervalSince1970];
            success(token);
        }else{
            OWSProdError(@"response token == nil");
            OWSLogError(@"%@ response token == nil", self.logTag);
            failure(nil);
        }
    } failure:^(NSError * _Nonnull error) {
        OWSLogError(@"%@ request token error: %@", self.logTag, error);
        failure(error);
    }];
    
}

- (BOOL)calculateTokenValiditeTime{
    
    if(!DTParamsUtils.validateString(self.authToken)){
        return NO;
    }
    
    NSDictionary *tokenInfo = [[self class] decodeWithJwtString:self.authToken];
    
    if(!DTParamsUtils.validateNumber(tokenInfo[@"iat"]) ||
       !DTParamsUtils.validateNumber(tokenInfo[@"exp"])){
        return NO;
    }
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval iatTime = [tokenInfo[@"iat"] doubleValue];
    NSTimeInterval expTime = [tokenInfo[@"exp"] doubleValue];
    
    NSTimeInterval expDiffTime = expTime - iatTime;
    if(currentTime - self.lastRefreshTokenTime + 2*60 >= expDiffTime){
        return NO;
    }
    
    return YES;
    
}

+ (NSDictionary *)decodeWithJwtString:(NSString *)jwtStr{
    NSArray * segments = [jwtStr componentsSeparatedByString:@"."];
    NSString * base64String = [segments objectAtIndex:1];
    int requiredLength = (int)(4 *ceil((float)[base64String length]/4.0));
    int nbrPaddings = requiredLength - (int)[base64String length];
    if(nbrPaddings > 0) {
        NSString * pading = [[NSString string] stringByPaddingToLength:nbrPaddings withString:@"=" startingAtIndex:0];
        base64String = [base64String stringByAppendingString:pading];
    }
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSData * decodeData = [[NSData alloc] initWithBase64EncodedData:[base64String dataUsingEncoding:NSUTF8StringEncoding] options:0];
    NSString * decodeString = [[NSString alloc] initWithData:decodeData encoding:NSUTF8StringEncoding];
    NSDictionary * jsonDict = [NSJSONSerialization JSONObjectWithData:[decodeString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    return jsonDict;
}

@end
