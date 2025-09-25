//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSContact.h"
#import "Contact.h"
#import "MIMETypeUtil.h"
#import "NSString+SSK.h"
#import "OWSContact+Private.h"
#import "DTParamsBaseUtils.h"

#import "TSAttachment.h"
#import "TSAttachmentPointer.h"
#import "TSAttachmentStream.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@import Contacts;

NS_ASSUME_NONNULL_BEGIN

// NOTE: When changing the value of this feature flag, you also need
// to update the filtering in the SAE's info.plist.
BOOL kIsSendingContactSharesEnabled = YES;

NSString *NSStringForContactPhoneType(OWSContactPhoneType value)
{
    switch (value) {
        case OWSContactPhoneType_Home:
            return @"Home";
        case OWSContactPhoneType_Mobile:
            return @"Mobile";
        case OWSContactPhoneType_Work:
            return @"Work";
        case OWSContactPhoneType_Custom:
            return @"Custom";
    }
}

@interface OWSContactPhoneNumber ()

@property (nonatomic) OWSContactPhoneType phoneType;
@property (nonatomic, nullable) NSString *label;

@property (nonatomic) NSString *phoneNumber;

@end

#pragma mark -

@implementation OWSContactPhoneNumber

- (BOOL)ows_isValid
{
    if (self.phoneNumber.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid phone number: %@.", self.logTag, self.phoneNumber);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.phoneType) {
        case OWSContactPhoneType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactPhoneType_Mobile:
            return [CNLabeledValue localizedStringForLabel:CNLabelPhoneNumberMobile];
        case OWSContactPhoneType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return Localized(@"CONTACT_PHONE", @"Label for a contact's phone number.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)debugDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Phone Number: %@, ", NSStringForContactPhoneType(self.phoneType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.phoneNumber.length > 0) {
        [result appendFormat:@"phoneNumber: %@, ", self.phoneNumber];
    }

    [result appendString:@"]"];
    return result;
}

// TODO: Delete
/*
- (nullable NSString *)tryToConvertToE164
{
    PhoneNumber *_Nullable parsedPhoneNumber;
    parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromE164:self.phoneNumber];
    if (!parsedPhoneNumber) {
        parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:self.phoneNumber];
    }
    if (parsedPhoneNumber) {
        return parsedPhoneNumber.toE164;
    }
    return nil;
}
*/
 
@end

#pragma mark -

NSString *NSStringForContactEmailType(OWSContactEmailType value)
{
    switch (value) {
        case OWSContactEmailType_Home:
            return @"Home";
        case OWSContactEmailType_Mobile:
            return @"Mobile";
        case OWSContactEmailType_Work:
            return @"Work";
        case OWSContactEmailType_Custom:
            return @"Custom";
    }
}

@interface OWSContactEmail ()

@property (nonatomic) OWSContactEmailType emailType;
@property (nonatomic, nullable) NSString *label;

@property (nonatomic) NSString *email;

@end

#pragma mark -

@implementation OWSContactEmail

- (BOOL)ows_isValid
{
    if (self.email.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid email: %@.", self.logTag, self.email);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.emailType) {
        case OWSContactEmailType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactEmailType_Mobile:
            return [CNLabeledValue localizedStringForLabel:CNLabelPhoneNumberMobile];
        case OWSContactEmailType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return Localized(@"CONTACT_EMAIL", @"Label for a contact's email address.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)debugDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Email: %@, ", NSStringForContactEmailType(self.emailType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.email.length > 0) {
        [result appendFormat:@"email: %@, ", self.email];
    }

    [result appendString:@"]"];
    return result;
}

@end

#pragma mark -

NSString *NSStringForContactAddressType(OWSContactAddressType value)
{
    switch (value) {
        case OWSContactAddressType_Home:
            return @"Home";
        case OWSContactAddressType_Work:
            return @"Work";
        case OWSContactAddressType_Custom:
            return @"Custom";
    }
}
@interface OWSContactAddress ()

@property (nonatomic) OWSContactAddressType addressType;
@property (nonatomic, nullable) NSString *label;

@property (nonatomic, nullable) NSString *street;
@property (nonatomic, nullable) NSString *pobox;
@property (nonatomic, nullable) NSString *neighborhood;
@property (nonatomic, nullable) NSString *city;
@property (nonatomic, nullable) NSString *region;
@property (nonatomic, nullable) NSString *postcode;
@property (nonatomic, nullable) NSString *country;

@end

#pragma mark -

@implementation OWSContactAddress

- (BOOL)ows_isValid
{
    if (self.street.ows_stripped.length < 1 && self.pobox.ows_stripped.length < 1
        && self.neighborhood.ows_stripped.length < 1 && self.city.ows_stripped.length < 1
        && self.region.ows_stripped.length < 1 && self.postcode.ows_stripped.length < 1
        && self.country.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid address; empty.", self.logTag);
        return NO;
    }
    return YES;
}

- (NSString *)localizedLabel
{
    switch (self.addressType) {
        case OWSContactAddressType_Home:
            return [CNLabeledValue localizedStringForLabel:CNLabelHome];
        case OWSContactAddressType_Work:
            return [CNLabeledValue localizedStringForLabel:CNLabelWork];
        default:
            if (self.label.ows_stripped.length < 1) {
                return Localized(@"CONTACT_ADDRESS", @"Label for a contact's postal address.");
            }
            return self.label.ows_stripped;
    }
}

- (NSString *)debugDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendFormat:@"[Address: %@, ", NSStringForContactAddressType(self.addressType)];

    if (self.label.length > 0) {
        [result appendFormat:@"label: %@, ", self.label];
    }
    if (self.street.length > 0) {
        [result appendFormat:@"street: %@, ", self.street];
    }
    if (self.pobox.length > 0) {
        [result appendFormat:@"pobox: %@, ", self.pobox];
    }
    if (self.neighborhood.length > 0) {
        [result appendFormat:@"neighborhood: %@, ", self.neighborhood];
    }
    if (self.city.length > 0) {
        [result appendFormat:@"city: %@, ", self.city];
    }
    if (self.region.length > 0) {
        [result appendFormat:@"region: %@, ", self.region];
    }
    if (self.postcode.length > 0) {
        [result appendFormat:@"postcode: %@, ", self.postcode];
    }
    if (self.country.length > 0) {
        [result appendFormat:@"country: %@, ", self.country];
    }

    [result appendString:@"]"];
    return result;
}

@end

#pragma mark -

@implementation OWSContactName

- (NSString *)logDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"["];

    if (self.givenName.length > 0) {
        [result appendFormat:@"givenName: %@, ", self.givenName];
    }
    if (self.familyName.length > 0) {
        [result appendFormat:@"familyName: %@, ", self.familyName];
    }
    if (self.middleName.length > 0) {
        [result appendFormat:@"middleName: %@, ", self.middleName];
    }
    if (self.namePrefix.length > 0) {
        [result appendFormat:@"namePrefix: %@, ", self.namePrefix];
    }
    if (self.nameSuffix.length > 0) {
        [result appendFormat:@"nameSuffix: %@, ", self.nameSuffix];
    }
    if (self.displayName.length > 0) {
        [result appendFormat:@"displayName: %@, ", self.displayName];
    }

    [result appendString:@"]"];
    return result;
}

- (NSString *)displayName
{
    [self ensureDisplayName];

    if (_displayName.length < 1) {
        OWSFailDebug(@"%@ could not derive a valid display name.", self.logTag);
        return Localized(@"CONTACT_WITHOUT_NAME", @"Indicates that a contact has no name.");
    }
    return _displayName;
}

- (void)ensureDisplayName
{
    if (_displayName.length < 1) {
        CNContact *_Nullable cnContact = [self systemContactForName];
        _displayName = [CNContactFormatter stringFromContact:cnContact style:CNContactFormatterStyleFullName];
    }
    if (_displayName.length < 1) {
        // Fall back to using the organization name.
        _displayName = self.organizationName;
    }
}

- (void)updateDisplayName
{
    _displayName = nil;

    [self ensureDisplayName];
}

- (nullable CNContact *)systemContactForName
{
    CNMutableContact *systemContact = [CNMutableContact new];
    systemContact.givenName = self.givenName.ows_stripped;
    systemContact.middleName = self.middleName.ows_stripped;
    systemContact.familyName = self.familyName.ows_stripped;
    systemContact.namePrefix = self.namePrefix.ows_stripped;
    systemContact.nameSuffix = self.nameSuffix.ows_stripped;
    // We don't need to set display name, it's implicit for system contacts.
    systemContact.organizationName = self.organizationName.ows_stripped;
    return systemContact;
}

- (BOOL)hasAnyNamePart
{
    return (self.givenName.ows_stripped.length > 0 || self.middleName.ows_stripped.length > 0
        || self.familyName.ows_stripped.length > 0 || self.namePrefix.ows_stripped.length > 0
        || self.nameSuffix.ows_stripped.length > 0);
}

@end

#pragma mark -

@interface OWSContact ()

@property (nonatomic) NSArray<OWSContactPhoneNumber *> *phoneNumbers;
@property (nonatomic) NSArray<OWSContactEmail *> *emails;
@property (nonatomic) NSArray<OWSContactAddress *> *addresses;

@property (nonatomic, nullable) NSString *avatarAttachmentId;
@property (nonatomic) BOOL isProfileAvatar;

@property (nonatomic, nullable) NSArray<NSString *> *e164PhoneNumbersCached;

@end

#pragma mark -

@implementation OWSContact

- (instancetype)init
{
    if (self = [super init]) {
        _name = [OWSContactName new];
        _phoneNumbers = @[];
        _emails = @[];
        _addresses = @[];
    }

    return self;
}

- (void)normalize
{
    self.phoneNumbers = [self.phoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactPhoneNumber *value,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return value.ows_isValid;
        }]];
    self.emails = [self.emails filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactEmail *value,
                                                               NSDictionary<NSString *, id> *_Nullable bindings) {
        return value.ows_isValid;
    }]];
    self.addresses =
        [self.addresses filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(OWSContactAddress *value,
                                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return value.ows_isValid;
        }]];
}

- (BOOL)ows_isValid
{
    if (self.name.displayName.ows_stripped.length < 1) {
        DDLogWarn(@"%@ invalid contact; no display name.", self.logTag);
        return NO;
    }
    BOOL hasValue = NO;
    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        if (!phoneNumber.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    for (OWSContactEmail *email in self.emails) {
        if (!email.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    for (OWSContactAddress *address in self.addresses) {
        if (!address.ows_isValid) {
            return NO;
        }
        hasValue = YES;
    }
    return hasValue;
}

- (NSString *)debugDescription
{
    NSMutableString *result = [NSMutableString new];
    [result appendString:@"["];

    [result appendFormat:@"%@, ", self.name.logDescription];

    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        [result appendFormat:@"%@, ", phoneNumber.debugDescription];
    }
    for (OWSContactEmail *email in self.emails) {
        [result appendFormat:@"%@, ", email.debugDescription];
    }
    for (OWSContactAddress *address in self.addresses) {
        [result appendFormat:@"%@, ", address.debugDescription];
    }

    [result appendString:@"]"];
    return result;
}

- (OWSContact *)newContactWithName:(OWSContactName *)name
{
    OWSAssertDebug(name);

    OWSContact *newContact = [OWSContact new];

    newContact.name = name;

    [name updateDisplayName];

    return newContact;
}

- (OWSContact *)copyContactWithName:(OWSContactName *)name
{
    OWSAssertDebug(name);

    OWSContact *contactCopy = [self copy];

    contactCopy.name = name;

    [name updateDisplayName];

    return contactCopy;
}

#pragma mark - Avatar

- (nullable TSAttachment *)avatarAttachmentWithTransaction:(SDSAnyReadTransaction *)transaction
{
    if(!self.avatarAttachmentId.length){
        return nil;
    }
    return [TSAttachment anyFetchWithUniqueId:self.avatarAttachmentId transaction:transaction];
}


- (void)saveAvatarImage:(UIImage *)image transaction:(SDSAnyWriteTransaction *)transaction
{
    NSData *imageData = UIImageJPEGRepresentation(image, (CGFloat)0.9);

    TSAttachmentStream *attachmentStream = [[TSAttachmentStream alloc] initWithContentType:OWSMimeTypeImageJpeg
                                                                                 byteCount:(UInt32)imageData.length
                                                                            sourceFilename:nil
                                                                            albumMessageId:nil
                                                                                   albumId:nil];

    NSError *error;
    BOOL success = [attachmentStream writeData:imageData error:&error];
    OWSAssertDebug(success && !error);

    [attachmentStream anyInsertWithTransaction:transaction];
    self.avatarAttachmentId = attachmentStream.uniqueId;
}

- (void)removeAvatarAttachmentWithTransaction:(SDSAnyWriteTransaction *)transaction
{
    TSAttachmentStream *_Nullable attachment = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:self.avatarAttachmentId transaction:transaction];
    [attachment anyRemoveWithTransaction:transaction];
}

#pragma mark - Phone Numbers and Recipient IDs

- (NSArray<NSString *> *)systemContactsWithSignalAccountPhoneNumbers:(id<ContactsManagerProtocol>)contactsManager
{
    OWSAssertDebug(contactsManager);

    return [self.e164PhoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *_Nullable recipientId,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return [contactsManager isSystemContactWithSignalAccount:recipientId];
        }]];
}

- (NSArray<NSString *> *)systemContactPhoneNumbers:(id<ContactsManagerProtocol>)contactsManager
{
    OWSAssertDebug(contactsManager);

    return [self.e164PhoneNumbers
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *_Nullable recipientId,
                                        NSDictionary<NSString *, id> *_Nullable bindings) {
            return [contactsManager isSystemContact:recipientId];
        }]];
}

// TODO: rename-e164
- (NSArray<NSString *> *)e164PhoneNumbers
{
    if (self.e164PhoneNumbersCached) {
        return self.e164PhoneNumbersCached;
    }
    NSMutableArray<NSString *> *e164PhoneNumbers = [NSMutableArray new];
    for (OWSContactPhoneNumber *phoneNumber in self.phoneNumbers) {
        NSString *_Nullable parsedPhoneNumber = phoneNumber.phoneNumber;
//        parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromE164:phoneNumber.phoneNumber];
//        if (!parsedPhoneNumber) {
//            parsedPhoneNumber = [PhoneNumber tryParsePhoneNumberFromUserSpecifiedText:phoneNumber.phoneNumber];
//        }
        if (parsedPhoneNumber) {
            [e164PhoneNumbers addObject:parsedPhoneNumber];
        }
    }
    self.e164PhoneNumbersCached = e164PhoneNumbers;
    return e164PhoneNumbers;
}


@end

#pragma mark -

@implementation OWSContacts

+ (nullable OWSContact *)contactForLocalContact:(nullable Contact *)localContact contactsManager:(nonnull id<ContactsManagerProtocol>)contactsManager {
   
    if (!localContact) {
        OWSFailDebug(@"Missing contact.");
        return nil;
    }
    
    OWSContact *contact = [OWSContact new];
    
    OWSContactName *contactName = [OWSContactName new];
    NSString *displayName = localContact.fullName;
    if (!DTParamsUtils.validateString(displayName)) {
        displayName = [contactsManager displayNameForPhoneIdentifier:localContact.number];
    }
    contactName.displayName = displayName;
    contact.name = contactName;
    
    OWSContactPhoneNumber *contactNumber = [OWSContactPhoneNumber new];
    contactNumber.phoneNumber = localContact.number;
    contactNumber.phoneType = OWSContactPhoneType_Work;
    contact.phoneNumbers = @[contactNumber];
    
    return contact;
}

#pragma mark - Proto Serialization

+ (nullable DSKProtoDataMessageContact *)protoForContact:(OWSContact *)contact
{
    OWSAssertDebug(contact);

    DSKProtoDataMessageContactBuilder *contactBuilder = [DSKProtoDataMessageContact builder];

    DSKProtoDataMessageContactNameBuilder *nameBuilder = [DSKProtoDataMessageContactName builder];

    OWSContactName *contactName = contact.name;
    if (contactName.givenName.ows_stripped.length > 0) {
        nameBuilder.givenName = contactName.givenName.ows_stripped;
    }
    if (contactName.familyName.ows_stripped.length > 0) {
        nameBuilder.familyName = contactName.familyName.ows_stripped;
    }
    if (contactName.middleName.ows_stripped.length > 0) {
        nameBuilder.middleName = contactName.middleName.ows_stripped;
    }
    if (contactName.namePrefix.ows_stripped.length > 0) {
        nameBuilder.prefix = contactName.namePrefix.ows_stripped;
    }
    if (contactName.nameSuffix.ows_stripped.length > 0) {
        nameBuilder.suffix = contactName.nameSuffix.ows_stripped;
    }
    if (contactName.organizationName.ows_stripped.length > 0) {
        contactBuilder.organization = contactName.organizationName.ows_stripped;
    }
    nameBuilder.displayName = contactName.displayName;
    
    DSKProtoDataMessageContactName *dataMessageContactName = [nameBuilder buildAndReturnError:nil];
    if (dataMessageContactName) {
        [contactBuilder setName:dataMessageContactName];
    }

    for (OWSContactPhoneNumber *phoneNumber in contact.phoneNumbers) {
        DSKProtoDataMessageContactPhoneBuilder *phoneBuilder = [DSKProtoDataMessageContactPhone builder];
        phoneBuilder.value = phoneNumber.phoneNumber;
        if (phoneNumber.label.ows_stripped.length > 0) {
            phoneBuilder.label = phoneNumber.label.ows_stripped;
        }
        switch (phoneNumber.phoneType) {
            case OWSContactPhoneType_Home:
                phoneBuilder.type = DSKProtoDataMessageContactPhoneTypeHome;
                break;
            case OWSContactPhoneType_Mobile:
                phoneBuilder.type = DSKProtoDataMessageContactPhoneTypeMobile;
                break;
            case OWSContactPhoneType_Work:
                phoneBuilder.type = DSKProtoDataMessageContactPhoneTypeWork;
                break;
            case OWSContactPhoneType_Custom:
                phoneBuilder.type = DSKProtoDataMessageContactPhoneTypeCustom;
                break;
        }
        
        DSKProtoDataMessageContactPhone *dataMessageContactPhone = [phoneBuilder buildAndReturnError:nil];
        if (dataMessageContactPhone) {
            [contactBuilder addNumber:dataMessageContactPhone];
        }
    }

    for (OWSContactEmail *email in contact.emails) {
        DSKProtoDataMessageContactEmailBuilder *emailBuilder = [DSKProtoDataMessageContactEmail builder];
        emailBuilder.value = email.email;
        if (email.label.ows_stripped.length > 0) {
            emailBuilder.label = email.label.ows_stripped;
        }
        switch (email.emailType) {
            case OWSContactEmailType_Home:
                emailBuilder.type = DSKProtoDataMessageContactEmailTypeHome;
                break;
            case OWSContactEmailType_Mobile:
                emailBuilder.type = DSKProtoDataMessageContactEmailTypeMobile;
                break;
            case OWSContactEmailType_Work:
                emailBuilder.type = DSKProtoDataMessageContactEmailTypeWork;
                break;
            case OWSContactEmailType_Custom:
                emailBuilder.type = DSKProtoDataMessageContactEmailTypeCustom;
                break;
        }
        
        DSKProtoDataMessageContactEmail *dataMessageContactEmail = [emailBuilder buildAndReturnError:nil];
        if (dataMessageContactEmail) {
            [contactBuilder addEmail:dataMessageContactEmail];
        }
    }

    for (OWSContactAddress *address in contact.addresses) {
        DSKProtoDataMessageContactPostalAddressBuilder *addressBuilder = [DSKProtoDataMessageContactPostalAddress builder];
        if (address.label.ows_stripped.length > 0) {
            addressBuilder.label = address.label.ows_stripped;
        }
        if (address.street.ows_stripped.length > 0) {
            addressBuilder.street = address.street.ows_stripped;
        }
        if (address.pobox.ows_stripped.length > 0) {
            addressBuilder.pobox = address.pobox.ows_stripped;
        }
        if (address.neighborhood.ows_stripped.length > 0) {
            addressBuilder.neighborhood = address.neighborhood.ows_stripped;
        }
        if (address.city.ows_stripped.length > 0) {
            addressBuilder.city = address.city.ows_stripped;
        }
        if (address.region.ows_stripped.length > 0) {
            addressBuilder.region = address.region.ows_stripped;
        }
        if (address.postcode.ows_stripped.length > 0) {
            addressBuilder.postcode = address.postcode.ows_stripped;
        }
        if (address.country.ows_stripped.length > 0) {
            addressBuilder.country = address.country.ows_stripped;
        }
        
        DSKProtoDataMessageContactPostalAddress *dataMessageContactPostalAddress = [addressBuilder buildAndReturnError:nil];
        [contactBuilder addAddress:dataMessageContactPostalAddress];
    }

    if (contact.avatarAttachmentId != nil) {
        DSKProtoDataMessageContactAvatarBuilder *avatarBuilder =
            [DSKProtoDataMessageContactAvatar builder];
        avatarBuilder.avatar =
            [TSAttachmentStream buildProtoForAttachmentId:contact.avatarAttachmentId];
        contactBuilder.avatar = [avatarBuilder buildAndReturnError:nil];
    }

    DSKProtoDataMessageContact *contactProto = [contactBuilder buildAndReturnError:nil];
    if (contactProto.number.count < 1 && contactProto.email.count < 1 && contactProto.address.count < 1) {
        OWSFailDebug(@"%@ contact has neither phone, email or address.", self.logTag);
        return nil;
    }
    return contactProto;
}

+ (OWSContact *)contactForDataMessageContact:(DSKProtoDataMessageContact *)contactProto
                                    threadId:(NSString *)threadId
                                   messageId:(NSString *)messageId
                                       relay:(nullable NSString *)relay
                                 transaction:(SDSAnyWriteTransaction *)transaction
{
    OWSAssertDebug(contactProto);

    OWSContact *contact = [OWSContact new];

    OWSContactName *contactName = [OWSContactName new];
    
    DSKProtoDataMessageContactName *nameProto = contactProto.name;
    if (nameProto) {
        
        if (nameProto.hasGivenName) {
            contactName.givenName = nameProto.givenName.ows_stripped;
        }
        if (nameProto.hasFamilyName) {
            contactName.familyName = nameProto.familyName.ows_stripped;
        }
        if (nameProto.hasPrefix) {
            contactName.namePrefix = nameProto.prefix.ows_stripped;
        }
        if (nameProto.hasSuffix) {
            contactName.nameSuffix = nameProto.suffix.ows_stripped;
        }
        if (nameProto.hasMiddleName) {
            contactName.middleName = nameProto.middleName.ows_stripped;
        }
        if (nameProto.hasDisplayName) {
            contactName.displayName = nameProto.displayName.ows_stripped;
        }
    }
    
    if (contactProto.hasOrganization) {
        contactName.organizationName = contactProto.organization.ows_stripped;
    }
    
    [contactName ensureDisplayName];
    contact.name = contactName;

    NSMutableArray<OWSContactPhoneNumber *> *phoneNumbers = [NSMutableArray new];
    for (DSKProtoDataMessageContactPhone *phoneNumberProto in contactProto.number) {
        OWSContactPhoneNumber *_Nullable phoneNumber = [self phoneNumberForProto:phoneNumberProto];
        if (phoneNumber) {
            [phoneNumbers addObject:phoneNumber];
        }
    }
    contact.phoneNumbers = [phoneNumbers copy];

    NSMutableArray<OWSContactEmail *> *emails = [NSMutableArray new];
    for (DSKProtoDataMessageContactEmail *emailProto in contactProto.email) {
        OWSContactEmail *_Nullable email = [self emailForProto:emailProto];
        if (email) {
            [emails addObject:email];
        }
    }
    contact.emails = [emails copy];

    NSMutableArray<OWSContactAddress *> *addresses = [NSMutableArray new];
    for (DSKProtoDataMessageContactPostalAddress *addressProto in contactProto.address) {
        OWSContactAddress *_Nullable address = [self addressForProto:addressProto];
        if (address) {
            [addresses addObject:address];
        }
    }
    contact.addresses = [addresses copy];

    DSKProtoDataMessageContactAvatar *avatarInfo = contactProto.avatar;
    if (avatarInfo) {

        DSKProtoAttachmentPointer *avatarAttachment = avatarInfo.avatar;
        if (avatarAttachment) {

            TSAttachmentPointer *attachmentPointer =
                [TSAttachmentPointer attachmentPointerFromProto:avatarAttachment
                                                          relay:relay
                                                 albumMessageId:messageId
                                                        albumId:threadId];
            [attachmentPointer anyInsertWithTransaction:transaction];

            contact.avatarAttachmentId = attachmentPointer.uniqueId;
            contact.isProfileAvatar = avatarInfo.isProfile;
        } else {
            OWSFailDebug(@"%@ in %s avatarInfo.hasAvatar was unexpectedly false", self.logTag, __PRETTY_FUNCTION__);
        }
    }

    return contact;
}

+ (nullable OWSContactPhoneNumber *)phoneNumberForProto:(DSKProtoDataMessageContactPhone *)phoneNumberProto
{
    OWSContactPhoneNumber *result = [OWSContactPhoneNumber new];
    result.phoneType = OWSContactPhoneType_Custom;
    if (phoneNumberProto.hasType) {
        switch (phoneNumberProto.unwrappedType) {
            case DSKProtoDataMessageContactPhoneTypeHome:
                result.phoneType = OWSContactPhoneType_Home;
                break;
            case DSKProtoDataMessageContactPhoneTypeMobile:
                result.phoneType = OWSContactPhoneType_Mobile;
                break;
            case DSKProtoDataMessageContactPhoneTypeWork:
                result.phoneType = OWSContactPhoneType_Work;
                break;
            default:
                break;
        }
    }
    if (phoneNumberProto.hasLabel) {
        result.label = phoneNumberProto.label.ows_stripped;
    }
    if (phoneNumberProto.hasValue) {
        result.phoneNumber = phoneNumberProto.value.ows_stripped;
    } else {
        return nil;
    }
    return result;
}

+ (nullable OWSContactEmail *)emailForProto:(DSKProtoDataMessageContactEmail *)emailProto
{
    OWSContactEmail *result = [OWSContactEmail new];
    result.emailType = OWSContactEmailType_Custom;
    if (emailProto.hasType) {
        switch (emailProto.unwrappedType) {
            case DSKProtoDataMessageContactEmailTypeHome:
                result.emailType = OWSContactEmailType_Home;
                break;
            case DSKProtoDataMessageContactEmailTypeMobile:
                result.emailType = OWSContactEmailType_Mobile;
                break;
            case DSKProtoDataMessageContactEmailTypeWork:
                result.emailType = OWSContactEmailType_Work;
                break;
            default:
                break;
        }
    }
    if (emailProto.hasLabel) {
        result.label = emailProto.label.ows_stripped;
    }
    if (emailProto.hasValue) {
        result.email = emailProto.value.ows_stripped;
    } else {
        return nil;
    }
    return result;
}

+ (nullable OWSContactAddress *)addressForProto:(DSKProtoDataMessageContactPostalAddress *)addressProto
{
    OWSContactAddress *result = [OWSContactAddress new];
    result.addressType = OWSContactAddressType_Custom;
    if (addressProto.hasType) {
        switch (addressProto.unwrappedType) {
            case DSKProtoDataMessageContactPostalAddressTypeHome:
                result.addressType = OWSContactAddressType_Home;
                break;
            case DSKProtoDataMessageContactPostalAddressTypeWork:
                result.addressType = OWSContactAddressType_Work;
                break;
            default:
                break;
        }
    }
    if (addressProto.hasLabel) {
        result.label = addressProto.label.ows_stripped;
    }
    if (addressProto.hasStreet) {
        result.street = addressProto.street.ows_stripped;
    }
    if (addressProto.hasPobox) {
        result.pobox = addressProto.pobox.ows_stripped;
    }
    if (addressProto.hasNeighborhood) {
        result.neighborhood = addressProto.neighborhood.ows_stripped;
    }
    if (addressProto.hasCity) {
        result.city = addressProto.city.ows_stripped;
    }
    if (addressProto.hasRegion) {
        result.region = addressProto.region.ows_stripped;
    }
    if (addressProto.hasPostcode) {
        result.postcode = addressProto.postcode.ows_stripped;
    }
    if (addressProto.hasCountry) {
        result.country = addressProto.country.ows_stripped;
    }
    return result;
}

@end

NS_ASSUME_NONNULL_END
