//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/SecTrust.h>

NS_ASSUME_NONNULL_BEGIN

extern NSData *SSKTextSecureServiceCertificateData(void);

/// A simplified version of AFNetworking's AFSecurityPolicy.
@interface OWSHTTPSecurityPolicy : NSObject

+ (instancetype)sharedPolicy;
+ (instancetype)systemDefault;

@property (readonly) NSSet<NSData *> *pinnedCertificates;

- (instancetype)initWithPinnedCertificates:(NSSet<NSData *> *)certificates;

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(nullable NSString *)domain;

@end

NS_ASSUME_NONNULL_END

