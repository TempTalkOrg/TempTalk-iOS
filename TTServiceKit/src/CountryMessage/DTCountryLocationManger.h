//
//  DTCountryLocationManger.h
//  Signal
//
//  Created by hornet on 2022/11/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RegistrationCountryState;
NS_ASSUME_NONNULL_BEGIN

@interface DTCountryLocationManger : NSObject
@property (nonatomic, strong, readonly) RegistrationCountryState *countryState;

+ (instancetype)sharedInstance;
- (void)getDefaultLocation;
- (void)asyncGetRegistrationCountryState:(void (^ __nullable)(RegistrationCountryState * countryState))successHandler
                                 failure:(void (^ __nullable)(NSError *error))failureHandler;
@end

NS_ASSUME_NONNULL_END
