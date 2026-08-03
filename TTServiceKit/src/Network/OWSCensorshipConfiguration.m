//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSCensorshipConfiguration.h"
#import "OWSCountryMetadata.h"
#import "OWSError.h"
#import "TSConstants.h"
#import "OWSHTTPSecurityPolicy.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSCensorshipConfiguration_SouqFrontingHost = @"cms.souqcdn.com";
NSString *const OWSCensorshipConfiguration_YahooViewFrontingHost = @"view.yahoo.com";
NSString *const OWSCensorshipConfiguration_DefaultFrontingHost = OWSCensorshipConfiguration_YahooViewFrontingHost;

@implementation OWSCensorshipConfiguration

+ (nullable instancetype)censorshipConfigurationWithPhoneNumber:(NSString *)e164PhoneNumber
{
    NSString *countryCode = [self censoredCountryCodeWithPhoneNumber:e164PhoneNumber];
    if (countryCode.length == 0) {
        return nil;
    }

    return [self censorshipConfigurationWithCountryCode:countryCode];
}

+ (instancetype)censorshipConfigurationWithCountryCode:(NSString *)countryCode
{
    OWSCountryMetadata *countryMetadadata = [OWSCountryMetadata countryMetadataForCountryCode:countryCode];
    OWSAssertDebug(countryMetadadata);

    NSString *_Nullable specifiedDomain = countryMetadadata.frontingDomain;

    NSURL *baseURL;
    OWSHTTPSecurityPolicy *securityPolicy;
    if (specifiedDomain.length > 0) {
        NSString *frontingURLString = [NSString stringWithFormat:@"https://%@", specifiedDomain];
        baseURL = [NSURL URLWithString:frontingURLString];
        securityPolicy = [self securityPolicyForDomain:specifiedDomain];
    } else {
        NSString *frontingURLString =
            [NSString stringWithFormat:@"https://%@", OWSCensorshipConfiguration_DefaultFrontingHost];
        baseURL = [NSURL URLWithString:frontingURLString];
        securityPolicy = [self securityPolicyForDomain:OWSCensorshipConfiguration_DefaultFrontingHost];
    }

    OWSAssertDebug(baseURL);
    OWSAssertDebug(securityPolicy);

    return [[OWSCensorshipConfiguration alloc] initWithDomainFrontBaseURL:baseURL securityPolicy:securityPolicy];
}

- (instancetype)initWithDomainFrontBaseURL:(NSURL *)domainFrontBaseURL
                            securityPolicy:(OWSHTTPSecurityPolicy *)securityPolicy
{
    OWSAssertDebug(domainFrontBaseURL);
    OWSAssertDebug(securityPolicy);

    self = [super init];
    if (!self) {
        return self;
    }

    _domainFrontBaseURL = domainFrontBaseURL;
    _domainFrontSecurityPolicy = securityPolicy;

    return self;
}

#pragma mark - Public Getters

- (NSString *)signalServiceReflectorHost
{
    return textSecureServiceReflectorHost;
}

- (NSString *)CDNReflectorHost
{
    return textSecureCDNReflectorHost;
}

#pragma mark - Util

+ (NSDictionary<NSString *, NSString *> *)censoredCountryCodes
{
    return @{
        // Egypt
        @"+20" : @"EG",
        // Oman
        @"+968" : @"OM",
        // Qatar
        @"+974" : @"QA",
        // UAE
        @"+971" : @"AE",
    };
}

+ (BOOL)isCensoredPhoneNumber:(NSString *)e164PhoneNumber
{
    return [self censoredCountryCodeWithPhoneNumber:e164PhoneNumber].length > 0;
}

+ (nullable NSString *)censoredCountryCodeWithPhoneNumber:(NSString *)e164PhoneNumber
{
    NSDictionary<NSString *, NSString *> *censoredCountryCodes = self.censoredCountryCodes;

    for (NSString *callingCode in censoredCountryCodes) {
        if ([e164PhoneNumber hasPrefix:callingCode]) {
            return censoredCountryCodes[callingCode];
        }
    }

    return nil;
}

#pragma mark - Certificate Pinning

+ (OWSHTTPSecurityPolicy *)securityPolicyForDomain:(NSString *)domain
{
    if ([domain isEqualToString:OWSCensorshipConfiguration_SouqFrontingHost]) {
        return [self souqPinningPolicy];
    } else if ([domain isEqualToString:OWSCensorshipConfiguration_YahooViewFrontingHost]) {
        return [self yahooViewPinningPolicy];
    } else {
        OWSFailDebug(@"unknown pinning domain.");
        return [self yahooViewPinningPolicy];
    }
}

+ (OWSHTTPSecurityPolicy *)pinningPolicyWithCertNames:(NSArray<NSString *> *)certNames
{
    NSMutableSet<NSData *> *certificates = [NSMutableSet new];
    for (NSString *certName in certNames) {
        NSError *error;
        NSData *certData = [self certificateDataWithName:certName error:&error];
        if (error) {
            DDLogError(@"%@ reading certificate: %@ failed: %@", self.logTag, certName, error);
            OWSRaiseException(@"OWSSignalService_UnableToReadCertificate", @"%@", error.description);
        }

        if (!certData) {
            DDLogError(@"%@ No data for certificate: %@", self.logTag, certName);
            OWSRaiseException(@"OWSSignalService_UnableToReadCertificate", @"missing cert data");
        }
        [certificates addObject:certData];
    }

    return [[OWSHTTPSecurityPolicy alloc] initWithPinnedCertificates:certificates];
}

+ (nullable NSData *)certificateDataWithName:(NSString *)name error:(NSError **)error
{
    if (!name.length) {
        NSString *failureDescription = [NSString stringWithFormat:@"%@ expected name with length > 0", self.logTag];
        *error = OWSErrorMakeAssertionError(failureDescription);
        return nil;
    }

    NSBundle *bundle = [NSBundle bundleForClass:self.class];
    NSString *path = [bundle pathForResource:name ofType:@"crt"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSString *failureDescription =
            [NSString stringWithFormat:@"%@ Missing certificate for name: %@", self.logTag, name];
        *error = OWSErrorMakeAssertionError(failureDescription);
        return nil;
    }

    NSData *_Nullable certData = [NSData dataWithContentsOfFile:path options:0 error:error];

    if (*error != nil) {
        OWSFailDebug(@"%@ Failed to read cert file: %@", self.logTag, path);
        return nil;
    }

    if (certData.length == 0) {
        OWSFailDebug(@"%@ empty certData for: %@", self.logTag, name);
        return nil;
    }

    DDLogVerbose(@"%@ read cert: %@ length: %lu", self.logTag, name, (unsigned long)certData.length);
    return certData;
}

+ (OWSHTTPSecurityPolicy *)yahooViewPinningPolicy
{
    static OWSHTTPSecurityPolicy *securityPolicy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *certNames = @[ @"DigiCertSHA2HighAssuranceServerCA" ];
        securityPolicy = [self pinningPolicyWithCertNames:certNames];
    });
    return securityPolicy;
}

+ (OWSHTTPSecurityPolicy *)souqPinningPolicy
{
    static OWSHTTPSecurityPolicy *securityPolicy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *certNames = @[ @"SFSRootCAG2" ];
        securityPolicy = [self pinningPolicyWithCertNames:certNames];
    });
    return securityPolicy;
}

@end

NS_ASSUME_NONNULL_END
