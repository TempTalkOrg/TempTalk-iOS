//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "Contact.h"
#import "SSKCryptography.h"
#import "NSString+SSK.h"
//

#import "SignalRecipient.h"
#import "TSAccountManager.h"
#import "ContactsManagerProtocol.h"

#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/SignalAccount.h>

@import Contacts;

static NSString *voipKey = @"voipNotification";
static NSString *calendarKey = @"calendarNotification";

NS_ASSUME_NONNULL_BEGIN

@implementation ContactPublicConfigs

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

- (BOOL)isEqualToPublicConfigs:(ContactPublicConfigs *)publicConfigs {
    return ([self.publicName isEqualToString:publicConfigs.publicName] && (self.meetingVersion == publicConfigs.meetingVersion));
}
@end

@implementation ContactPrivateConfig

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;
    if (![dictionaryValue.allKeys containsObject:voipKey]) {
        self.voipNotification = YES;
    }
    
    return self;
}

@end


@implementation DTLastSourceEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

@end

@implementation DTThumbsUpEntity
+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}
@end



@interface Contact ()

@property (nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *phoneNumberNameMap;
@property (nonatomic, readonly) NSUInteger imageHash;

@end

#pragma mark -

@implementation Contact

@synthesize comparableNameFirstLast = _comparableNameFirstLast;
@synthesize comparableNameLastFirst = _comparableNameLastFirst;

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

+ (NSValueTransformer *)privateConfigsJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:ContactPrivateConfig.class];
}

// adapt previous versions privateConfigs are dictionary in database
// @since 2.9.3
- ( ContactPrivateConfig * _Nullable )privateConfigs {
    if ([_privateConfigs isKindOfClass:NSDictionary.class]) {
        NSMutableDictionary *privateConfigsDict = ((NSDictionary *)_privateConfigs).mutableCopy;
        BOOL hasVoipConfig = [privateConfigsDict.allKeys containsObject:voipKey];
        if (!hasVoipConfig) {
            privateConfigsDict[voipKey] = @(YES);
        }
        BOOL hasCalendarConfig = [privateConfigsDict.allKeys containsObject:calendarKey];
        if (!hasCalendarConfig) {
            privateConfigsDict[calendarKey] = @(YES);
        }
        NSError *error;
        ContactPrivateConfig *value = [MTLJSONAdapter modelOfClass:ContactPrivateConfig.class fromJSONDictionary:privateConfigsDict error:&error];
        if (error) {
            OWSLogError(@"_privateConfigs transformer error: %@", error);
        }
        return value;
    } else if ([_privateConfigs isKindOfClass:ContactPrivateConfig.class]) {
        return _privateConfigs;
    } else {
        return nil;
    }
}

#if TARGET_OS_IOS

- (void)configWithFullName:(NSString *)fullName phoneNumber:(NSString *)number{
    _fullName = fullName;
    _firstName = fullName;
    _number = number;
    _cnContactId = [NSString stringWithFormat:@"%@-%@", fullName, number];
    _userTextPhoneNumbers = @[number];

    _phoneNumberNameMap = [NSMutableDictionary new];
    for (NSString * item in _userTextPhoneNumbers) {
        _phoneNumberNameMap[item] = CNLabelHome;
    }
}

- (instancetype)initWithFullName:(NSString *)fullName phoneNumber:(NSString *)number
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    [self configWithFullName:fullName phoneNumber:number];
    
    return self;
}

- (instancetype)initWithRecipientId:(NSString *)recipientId {
    self = [super init];
    if (!self) {
        return self;
    }
    _number = recipientId;
    _fullName = recipientId;
    
    return self;
}

- (instancetype)initWithSystemContact:(CNContact *)cnContact
{
    self = [super init];
    if (!self) {
        return self;
    }

    _cnContactId = cnContact.identifier;
    _firstName = cnContact.givenName.ows_stripped;
    _lastName = cnContact.familyName.ows_stripped;
    _fullName = [Contact formattedFullNameWithCNContact:cnContact];

    NSMutableArray<NSString *> *phoneNumbers = [NSMutableArray new];
    NSMutableDictionary<NSString *, NSString *> *phoneNumberNameMap = [NSMutableDictionary new];
    for (CNLabeledValue *phoneNumberField in cnContact.phoneNumbers) {
        if ([phoneNumberField.value isKindOfClass:[CNPhoneNumber class]]) {
            CNPhoneNumber *phoneNumber = (CNPhoneNumber *)phoneNumberField.value;
            [phoneNumbers addObject:phoneNumber.stringValue];
            if ([phoneNumberField.label isEqualToString:CNLabelHome]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_HOME", @"Label for 'Home' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelWork]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_WORK", @"Label for 'Work' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberiPhone]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_IPHONE", @"Label for 'iPhone' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberMobile]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_MOBILE", @"Label for 'Mobile' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberMain]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_MAIN", @"Label for 'Main' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberHomeFax]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_HOME_FAX", @"Label for 'HomeFAX' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberWorkFax]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_WORK_FAX", @"Label for 'Work FAX' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberOtherFax]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_OTHER_FAX", @"Label for 'Other FAX' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelPhoneNumberPager]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_PAGER", @"Label for 'Pager' phone numbers.");
            } else if ([phoneNumberField.label isEqualToString:CNLabelOther]) {
                phoneNumberNameMap[phoneNumber.stringValue]
                    = Localized(@"PHONE_NUMBER_TYPE_OTHER", @"Label for 'Other' phone numbers.");
            } else if (phoneNumberField.label.length > 0 && ![phoneNumberField.label hasPrefix:@"_$"]) {
                // We'll reach this case for:
                //
                // * User-defined custom labels, which we want to display.
                // * Labels like "_$!<CompanyMain>!$_", which I'm guessing are synced from other platforms.
                //   We don't want to display these labels. Even some of iOS' default labels (like Radio) show
                //   up this way.
                phoneNumberNameMap[phoneNumber.stringValue] = phoneNumberField.label;
            }
        }
    }

    _userTextPhoneNumbers = [phoneNumbers copy];
    _phoneNumberNameMap = [NSMutableDictionary new];

    NSMutableArray<NSString *> *emailAddresses = [NSMutableArray new];
    for (CNLabeledValue *emailField in cnContact.emailAddresses) {
        if ([emailField.value isKindOfClass:[NSString class]]) {
            [emailAddresses addObject:(NSString *)emailField.value];
        }
    }
    _emails = [emailAddresses copy];

    NSData *_Nullable avatarData = [Contact avatarDataForCNContact:cnContact];
    if (avatarData) {
        NSUInteger hashValue = 0;
        NSData *_Nullable hashData = [SSKCryptography computeSHA256Digest:avatarData truncatedToBytes:sizeof(hashValue)];
        if (hashData) {
            [hashData getBytes:&hashValue length:sizeof(hashValue)];
        } else {
            OWSFailDebug(@"%@ could not compute hash for avatar.", self.logTag);
        }
        _imageHash = hashValue;
    } else {
        _imageHash = 0;
    }

    return self;
}

- (NSString *)uniqueId
{
    return self.cnContactId;
}

+ (nullable Contact *)contactWithVCardData:(NSData *)data
{
    CNContact *_Nullable cnContact = [self cnContactWithVCardData:data];

    if (!cnContact) {
        return nil;
    }

    // TODO: maybe reconstract this, this is just reusing this code
    return [[self alloc] initWithSystemContact:cnContact];
}

#endif // TARGET_OS_IOS

- (NSString *)comparableNameFirstLast {
//    if (_comparableNameFirstLast == nil) {
        // Combine the two names with a tab separator, which has a lower ascii code than space, so that first names
        // that contain a space ("Mary Jo\tCatlett") will sort after those that do not ("Mary\tOliver")
        _comparableNameFirstLast = [self combineLeftName:_firstName withRightName:_lastName usingSeparator:@"\t"];
//    }
    
    return _comparableNameFirstLast;
}

- (NSString *)comparableNameLastFirst {
//    if (_comparableNameLastFirst == nil) {
        // Combine the two names with a tab separator, which has a lower ascii code than space, so that last names
        // that contain a space ("Van Der Beek\tJames") will sort after those that do not ("Van\tJames")
        _comparableNameLastFirst = [self combineLeftName:_lastName withRightName:_firstName usingSeparator:@"\t"];
//    }
    
    return _comparableNameLastFirst;
}

- (NSString *)combineLeftName:(NSString *)leftName withRightName:(NSString *)rightName usingSeparator:(NSString *)separator {
    const BOOL leftNameNonEmpty = (leftName.length > 0);
    const BOOL rightNameNonEmpty = (rightName.length > 0);
    
    if (leftNameNonEmpty && rightNameNonEmpty) {
        return [NSString stringWithFormat:@"%@%@%@", leftName, separator, rightName];
    } else if (leftNameNonEmpty) {
        return [leftName copy];
    } else if (rightNameNonEmpty) {
        return [rightName copy];
    } else {
        return @"";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: %@", self.fullName, self.userTextPhoneNumbers];
}

- (BOOL)isSignalContact {
    NSArray *identifiers = [self textSecureIdentifiers];

    return [identifiers count] > 0;
}

- (NSArray<SignalRecipient *> *)signalRecipientsWithTransaction:(SDSAnyReadTransaction *)transaction
{
    NSMutableArray<SignalRecipient *> *result = [NSMutableArray array];

    for (NSString *number in [self.userTextPhoneNumbers sortedArrayUsingSelector:@selector(compare:)]) {
        SignalRecipient *signalRecipient =
            [SignalRecipient recipientWithTextSecureIdentifier:number withTransaction:transaction];
        
        if (signalRecipient && [signalRecipient isKindOfClass:SignalRecipient.class]) {
            [result addObject:signalRecipient];
        }
    }

    return [result copy];
}

- (NSArray<NSString *> *)textSecureIdentifiers {
    __block NSMutableArray *identifiers = [NSMutableArray array];

    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * transaction) {
        for (NSString *number in self.userTextPhoneNumbers) {
            if ([SignalRecipient recipientWithTextSecureIdentifier:number withTransaction:transaction]) {
                [identifiers addObject:number];
            }
        }
    }];
    return [identifiers copy];
}

+ (NSComparator)comparatorSortingNamesByFirstThenLast:(BOOL)firstNameOrdering {
    return ^NSComparisonResult(id obj1, id obj2) {
        Contact *contact1 = (Contact *)obj1;
        Contact *contact2 = (Contact *)obj2;
        
        if (firstNameOrdering) {
            return [contact1.comparableNameFirstLast caseInsensitiveCompare:contact2.comparableNameFirstLast];
        } else {
            return [contact1.comparableNameLastFirst caseInsensitiveCompare:contact2.comparableNameLastFirst];
        }
    };
}

+ (NSString *)formattedFullNameWithCNContact:(CNContact *)cnContact
{
    return [CNContactFormatter stringFromContact:cnContact style:CNContactFormatterStyleFullName].ows_stripped;
}

- (NSString *)nameForPhoneNumber:(NSString *)recipientId
{
    OWSAssertDebug(recipientId.length > 0);
    OWSAssertDebug([self.textSecureIdentifiers containsObject:recipientId]);

    NSString *value = self.phoneNumberNameMap[recipientId];
    OWSAssertDebug(value);
    if (!value) {
        return Localized(@"PHONE_NUMBER_TYPE_UNKNOWN",
            @"Label used when we don't what kind of phone number it is (e.g. mobile/work/home).");
    }
    return value;
}

+ (nullable NSData *)avatarDataForCNContact:(nullable CNContact *)cnContact
{
    if (cnContact.thumbnailImageData) {
        return cnContact.thumbnailImageData.copy;
    } else if (cnContact.imageData) {
        // This only occurs when sharing a contact via the share extension
        return cnContact.imageData.copy;
    } else {
        return nil;
    }
}

// This method is used to de-bounce system contact fetch notifications
// by checking for changes in the contact data.
- (NSUInteger)hash
{
    // base hash is some arbitrary number
    NSUInteger hash = 1825038313;

    hash = hash ^ self.fullName.hash;

//    hash = hash ^ self.imageHash;

    for (NSString *phoneNumber in self.userTextPhoneNumbers) {
        hash = hash ^ phoneNumber.hash;
    }

    for (NSString *email in self.emails) {
        hash = hash ^ email.hash;
    }
    
    NSUInteger externalHash = 1825;
    if (self.external) {
        externalHash = 8313;
    }
    
    hash = hash ^ externalHash;

    return hash;
}

#pragma mark - CNContactConverters

+ (nullable CNContact *)cnContactWithVCardData:(NSData *)data
{
    OWSAssertDebug(data);

    NSError *error;
    NSArray<CNContact *> *_Nullable contacts = [CNContactVCardSerialization contactsWithData:data error:&error];
    if (!contacts || error) {
        OWSFailDebug(@"%@ could not parse vcard: %@", self.logTag, error);
        return nil;
    }
    if (contacts.count < 1) {
        OWSFailDebug(@"%@ empty vcard: %@", self.logTag, error);
        return nil;
    }
    if (contacts.count > 1) {
        OWSFailDebug(@"%@ more than one contact in vcard: %@", self.logTag, error);
    }
    return contacts.firstObject;
}

- (BOOL)isEqualToContact:(Contact *)contact {
    return ([self.name  isEqualToString: contact.name] || (!self.name && !contact.name))
    && ([self.firstName isEqualToString: contact.firstName] || (!self.firstName && !contact.firstName))
    && ([self.remark isEqualToString: contact.remark] || (!self.remark && !contact.remark))
    && ([self.lastName  isEqualToString: contact.lastName] || (!self.lastName && !contact.lastName))
    && ([self.fullName  isEqualToString: contact.fullName] || (!self.fullName && !contact.fullName))
    && ([self.email     isEqualToString: contact.email] || (!self.email && !contact.email))
    && ([self.number    isEqualToString: contact.number] || (!self.number && !contact.number))
    && ([self.joinedAt isEqualToString: contact.joinedAt] || (!self.joinedAt && !contact.joinedAt))
    && ([self.superior  isEqualToString: contact.superior] || (!self.superior && !contact.superior))
    && ([self.timeZone  isEqualToString: contact.timeZone] || (!self.timeZone && !contact.timeZone))
    && ([self.avatar    isEqual: contact.avatar] || (!self.avatar && !contact.avatar))
    && ([self.signature isEqualToString: contact.signature] || (!self.signature && !contact.signature))
    && ([self.gender    isEqual: contact.gender] || (!self.gender && !contact.gender))
    && ([self.address   isEqualToString: contact.address] || (!self.address && !contact.address))
    && ([self.flag      isEqual: contact.flag] || (!self.flag && !contact.flag))
    && ([self.privateConfigs  isEqual:contact.privateConfigs] || (!self.privateConfigs && !contact.privateConfigs))
    && ([self.groupDisplayName  isEqualToString:contact.groupDisplayName] || (!self.groupDisplayName && !contact.groupDisplayName))
    && ([self.thumbsUp isEqual:contact.thumbsUp] || (!self.thumbsUp && !contact.thumbsUp))
    && ([self.extId isEqualToNumber:contact.extId] || (!self.extId && !contact.extId))
    && (self.spookyBotFlag == contact.spookyBotFlag);
}

/*
- (DTGlobalNotificationType)defaultNotificationType {
    __block NSNumber * globalNotification = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transation) {
        SignalAccount *account = [SignalAccount signalAccountWithRecipientId:[TSAccountManager sharedInstance].localNumber transaction:transation];
            Contact *contact = account.contact;
            globalNotification =  contact.privateConfigs.globalNotification;
    }];
    DTGlobalNotificationType type = [self getGlobalNotificationTypeWith:globalNotification];
    return type;
}

- (DTGlobalNotificationType)getGlobalNotificationTypeWith:(NSNumber *)globalNotification {
    if ([globalNotification intValue] == 0 ) {
        return DTGlobalNotificationTypeALL;
    }else if([globalNotification intValue] == 1 ){
        return DTGlobalNotificationTypeMENTION;
    }else if([globalNotification intValue] == 2 ){
        return DTGlobalNotificationTypeOFF;
    }else {
        return DTGlobalNotificationTypeALL;
    }
}
 */

@end

NS_ASSUME_NONNULL_END
