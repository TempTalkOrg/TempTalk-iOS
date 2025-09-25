//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSHTTPSecurityPolicy.h"
#import <AssertMacros.h>

#ifdef POD_CONFIGURATION_DEBUG

#define CerName  @"DifftCyberTrustRoot"
#define TestCerName  @"DifftTestRoot"
#define TestCrtName  @"root"

#elif POD_CONFIGURATION_DEVELOPMENT

#define CerName  @"textsecure_dev"
#define TestCerName  @"DifftTestRoot"
#define TestCrtName  @"root"

#else

#define CerName  @"DifftCyberTrustRoot"
#define TestCerName  @"DifftTestRoot"
#define TestCrtName  @"root"

#endif

NS_ASSUME_NONNULL_BEGIN

@interface OWSHTTPSecurityPolicy ()
//@property (readonly) NSSet<NSData *> *pinnedCertificates;
@end

@implementation OWSHTTPSecurityPolicy

+ (instancetype)sharedPolicy {
    static OWSHTTPSecurityPolicy *httpSecurityPolicy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        httpSecurityPolicy = [[self alloc]
                              initWithPinnedCertificates:[NSSet setWithObjects:
                                                          [self certificateDataForService:CerName fileType:@"cer"],
                                                          [self certificateDataForService:TestCrtName fileType:@"der"],
                                                          nil]];
    });
    return httpSecurityPolicy;
}

+ (instancetype)systemDefault {
    return [[self alloc] initWithPinnedCertificates:[NSSet set]];
}

- (instancetype)initWithPinnedCertificates:(NSSet<NSData *> *)certificates {
    self = [super init];
    if (self) {
        _pinnedCertificates = [certificates copy];
    }
    return self;
}

+ (NSData *)dataFromCertificateFileForService:(NSString *)service fileType:(NSString *)fileType {
    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *path = [bundle pathForResource:service ofType:fileType];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        OWSFail(@"Missing signing certificate for service %@", service);
    }
    
    NSData *data = [NSData dataWithContentsOfFile:path];
    OWSAssert(data.length > 0);
    
    return data;
}

+ (NSData *)certificateDataForService:(NSString *)service fileType:(NSString *)fileType {
    SecCertificateRef certRef = [self newCertificateForService:service fileType:fileType ];
    NSData *result = (__bridge_transfer NSData *)SecCertificateCopyData(certRef);
    CFRelease(certRef);
    return result;
}

+ (SecCertificateRef)newCertificateForService:(NSString *)service fileType:(NSString *)fileType CF_RETURNS_RETAINED {
    NSData *certificateData = [self dataFromCertificateFileForService:service fileType:fileType];
    SecCertificateRef certRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)(certificateData));
    OWSAssert(certRef);
    return certRef;
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forDomain:(nullable NSString *)domain {
    NSMutableArray *policies = [NSMutableArray array];
    [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    
    if (SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies) != errSecSuccess) {
        OWSLogError(@"The trust policy couldn't be set.");
        return NO;
    }
    
    if ([self.pinnedCertificates count] > 0) {
        NSMutableArray *pinnedCertificates = [NSMutableArray array];
        for (NSData *certificateData in self.pinnedCertificates) {
            [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(
                                                                                             NULL, (__bridge CFDataRef)certificateData)];
        }
        
        if (SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates) != errSecSuccess) {
            OWSLogError(@"The anchor certificates couldn't be set.");
            return NO;
        }
    } else {
        // Use SecTrust's default set of anchor certificates.
    }
    
//    CFDictionaryRef dicRef = SecTrustCopyResult(serverTrust);
//    OWSLogDebug(@"%@.", dicRef);
    
    if (!AFServerTrustIsValid(serverTrust)) {
        OWSLogDebug(@"Multi-server: %@, trust: NO", domain);
        
        return NO;
    }
    
//    OWSLogDebug(@"Multi-server: %@, trust: YES", domain);
    return YES;
}

static BOOL AFServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    __Require_noErr_Quiet(SecTrustEvaluate(serverTrust, &result), _out);
    
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    
_out:
    return isValid;
}

NSData *SSKTextSecureServiceCertificateData(void) {
    return [OWSHTTPSecurityPolicy dataFromCertificateFileForService:@"textsecure" fileType:@"cer"];
}

@end

NS_ASSUME_NONNULL_END
