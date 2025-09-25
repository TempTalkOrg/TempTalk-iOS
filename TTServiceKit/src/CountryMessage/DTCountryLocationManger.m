//
//  DTCountryLocationManger.m
//  Signal
//
//  Created by hornet on 2022/11/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCountryLocationManger.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

static NSString *LOCATION_ERROR_DOMAIN = @"CountryLocation domain";

@interface DTCountryLocationManger()
@property (nonatomic, strong) DTGetLocationApi *locationApi;
@property (nonatomic, strong, readwrite) RegistrationCountryState *countryState;
@end


@implementation DTCountryLocationManger

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance configDefaultProrety];
    });
    return sharedInstance;
}

- (void)configDefaultProrety {
    self.countryState = nil;
}

- (void)getDefaultLocation {
    [self locationSuccess:nil failure:nil];
}

- (void)asyncGetRegistrationCountryState:(void (^ __nullable )(RegistrationCountryState * countryState))successHandler
                                 failure:(void (^ __nullable)(NSError *error))failureHandler {
    if(self.countryState){
        if(successHandler){
            successHandler(self.countryState);
        }
    } else {
        [self locationSuccess:^(RegistrationCountryState *countryState) {
            if(successHandler){
                successHandler(countryState);
            }
        } failure:^(NSError *error) {
            if(failureHandler){
                failureHandler(error);
            }
        }];
    }
}

- (void)locationSuccess:(void (^)(RegistrationCountryState * countryState))successHandler
                failure:(void (^)(NSError *error))failureHandler {
    @weakify(self);
    [self.locationApi location:^(id<HTTPResponse>  _Nonnull response) {
        @strongify(self);
        NSDictionary *responseObject = response.responseBodyJson;
        if(!DTParamsUtils.validateDictionary(responseObject)){
            return;
        }
        if([responseObject[@"status"] intValue] != 0){
            NSString *errorMessage = responseObject[@"reason"];
            NSError *error = nil;
            if(DTParamsUtils.validateString(errorMessage)){
                error = [NSError errorWithDomain:LOCATION_ERROR_DOMAIN code:[responseObject[@"status"] integerValue] userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
            } else {
                error = [NSError errorWithDomain:LOCATION_ERROR_DOMAIN code:[responseObject[@"status"] integerValue] userInfo:@{NSLocalizedDescriptionKey: @"get location error"}];
            }
            if(failureHandler){
                failureHandler(error);
            }
        } else {
            NSDictionary *responseData = responseObject[@"data"];
            NSString *countryName = responseData[@"countryName"] ? : @"";
            NSString *countryCode = responseData[@"countryCode"] ? : @"";
            NSString *dialingCode = responseData[@"dialingCode"] ? : @"";
            
            RegistrationCountryState * countryState = [[RegistrationCountryState alloc] initWithCountryName:countryName callingCode:dialingCode countryCode:countryCode];
            self.countryState = countryState;
            if(successHandler){
                successHandler(countryState);
            }
        }
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        if(failureHandler){
            failureHandler(error);
        }
    }];
}

- (DTGetLocationApi *)locationApi {
    if(!_locationApi){
        _locationApi = [DTGetLocationApi new];
    }
    return _locationApi;
}

@end
