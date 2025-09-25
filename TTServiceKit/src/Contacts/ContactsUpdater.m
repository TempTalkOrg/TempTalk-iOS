//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ContactsUpdater.h"
#import "Contact.h"
#import "SSKCryptography.h"
#import "OWSError.h"
//
#import "OWSRequestFactory.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

//

NS_ASSUME_NONNULL_BEGIN

@implementation ContactsUpdater

+ (instancetype)sharedUpdater {
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [self new];
    });
    return sharedInstance;
}


- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSSingletonAssert();

    return self;
}

- (nullable SignalRecipient *)synchronousLookup:(NSString *)identifier error:(NSError **)error
{
    OWSAssertDebug(error);

    DDLogInfo(@"%@ %s %@", self.logTag, __PRETTY_FUNCTION__, identifier);

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    __block SignalRecipient *recipient;

    // Assigning to a pointer parameter within the block is not preventing the referenced error from being dealloc
    // Instead, we avoid ambiguity in ownership by assigning to a local __block variable ensuring the error will be
    // retained until our error parameter can take ownership.
    __block NSError *retainedError;
    [self lookupIdentifier:identifier
        success:^(SignalRecipient *fetchedRecipient) {
            recipient = fetchedRecipient;
            dispatch_semaphore_signal(sema);
        }
        failure:^(NSError *lookupError) {
            DDLogError(
                @"%@ Could not find recipient for recipientId: %@, error: %@.", self.logTag, identifier, lookupError);

            retainedError = lookupError;
            dispatch_semaphore_signal(sema);
        }];

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    *error = retainedError;
    return recipient;
}

- (void)lookupIdentifier:(NSString *)identifier
                 success:(void (^)(SignalRecipient *recipient))success
                 failure:(void (^)(NSError *error))failure
{
    // This should never happen according to nullability annotations... but IIRC it does. =/
    if (!identifier) {
        OWSFailDebug(@"%@ Cannot lookup nil identifier", self.logTag);
        failure(OWSErrorWithCodeDescription(OWSErrorCodeInvalidMethodParameters, @"Cannot lookup nil identifier"));
        return;
    }
    
    [self contactIntersectionWithSet:[NSSet setWithObject:identifier]
                             success:^(NSSet<NSString *> *_Nonnull matchedIds) {
                                 if (matchedIds.count == 1) {
                                     success([SignalRecipient recipientWithTextSecureIdentifier:identifier]);
                                 } else {
                                     failure(OWSErrorMakeNoSuchSignalRecipientError());
                                 }
                             }
                             failure:failure];
}

- (void)lookupIdentifiers:(NSArray<NSString *> *)identifiers
                 success:(void (^)(NSArray<SignalRecipient *> *recipients))success
                 failure:(void (^)(NSError *error))failure
{
    if (identifiers.count < 1) {
        OWSFailDebug(@"%@ Cannot lookup zero identifiers", self.logTag);
        failure(OWSErrorWithCodeDescription(OWSErrorCodeInvalidMethodParameters, @"Cannot lookup zero identifiers"));
        return;
    }

    [self contactIntersectionWithSet:[NSSet setWithArray:identifiers]
                             success:^(NSSet<NSString *> *_Nonnull matchedIds) {
                                 if (matchedIds.count > 0) {
                                     NSMutableArray<SignalRecipient *> *recipients = [NSMutableArray new];
                                     for (NSString *identifier in matchedIds) {
                                         [recipients addObject:[SignalRecipient recipientWithTextSecureIdentifier:identifier]];
                                     }
                                     success([recipients copy]);
                                 } else {
                                     failure(OWSErrorMakeNoSuchSignalRecipientError());
                                 }
                             }
                             failure:failure];
}

/*

- (void)updateSignalContactIntersectionWithABContacts:(NSArray<Contact *> *)abContacts
                                              success:(void (^)(void))success
                                              failure:(void (^)(NSError *error))failure
{
    NSMutableSet<NSString *> *abPhoneNumbers = [NSMutableSet set];

    for (Contact *contact in abContacts) {
        for (NSString *phoneNumber in contact.userTextPhoneNumbers) {
            [abPhoneNumbers addObject:phoneNumber];
        }
    }
    
    [self.databaseStorage asyncWriteWithBlock:^(SDSAnyWriteTransaction * _Nonnull transaction) {
        NSMutableSet *recipientIds = [NSMutableSet set];
        NSArray *allRecipientKeys = [SignalRecipient anyAllUniqueIdsWithTransaction:transaction];
        [recipientIds addObjectsFromArray:allRecipientKeys];
        
        NSMutableSet<NSString *> *allContacts = [[abPhoneNumbers setByAddingObjectsFromSet:recipientIds] mutableCopy];
        NSMutableSet<NSString *> *allContactsToDeal = allContacts.mutableCopy;
        
        [Batching loopObjcWithBatchSize:Batching.kDefaultBatchSize loopBlock:^(BOOL * _Nonnull stop) {
            NSString *identifier = allContactsToDeal.anyObject;
            if (!identifier) {
                *stop = YES;
                return;
            }
            
            SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:identifier
                                                                            withTransaction:transaction];
            if (!recipient) {
                OWSLogInfo(@"insert contact attributes");
                recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:identifier relay:nil];
                [recipient anyInsertWithTransaction:transaction];
            }
            
            [allContactsToDeal removeObject:identifier];
        }];
        
        [recipientIds minusSet:allContacts.copy];
        
        for (NSString *identifier in recipientIds) {
            SignalRecipient *recipient =
            [SignalRecipient recipientWithTextSecureIdentifier:identifier withTransaction:transaction];
            
            [recipient anyRemoveWithTransaction:transaction];
        }
        
        OWSLogInfo(@"%@ contactIntersectionWithSet to remove recipientIds count = %ld", self.logTag, recipientIds.count);
    } completion:^{
        OWSLogInfo(@"%@ successfully intersected contacts.", self.logTag);
        success();
    }];
}
 */

- (void)contactIntersectionWithSet:(NSSet<NSString *> *)idSet
                           success:(void (^)(NSSet<NSString *> *matchedIds))success
                           failure:(void (^)(NSError *error))failure {
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
        // Insert or update contact attributes
        for (NSString *identifier in idSet) {
            SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:identifier
                                                                            withTransaction:writeTransaction];
            if (!recipient) {
                recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:identifier relay:nil];
                [recipient anyInsertWithTransaction:writeTransaction];
            }
        }
        
        [writeTransaction addAsyncCompletionOnMain:^{
            success(idSet);
        }];
    });
    
       
        /*
         此接口用于查询不在通讯录的号码在服务端存不存在，mac 端无此逻辑
         
      NSMutableDictionary *phoneNumbersByHashes = [NSMutableDictionary dictionary];
      for (NSString *identifier in idSet) {
          [phoneNumbersByHashes setObject:identifier
                                   forKey:[Cryptography truncatedSHA1Base64EncodedWithoutPadding:identifier]];
      }
      NSArray *hashes = [phoneNumbersByHashes allKeys];

      TSRequest *request = [OWSRequestFactory contactsIntersectionRequestWithHashesArray:hashes];
      [[TSNetworkManager sharedManager] makeRequest:request
          success:^(NSURLSessionDataTask *tsTask, id responseDict) {
              NSMutableDictionary *attributesForIdentifier = [NSMutableDictionary dictionary];
              NSArray *contactsArray = [(NSDictionary *)responseDict objectForKey:@"contacts"];

              // Map attributes to phone numbers
              if (contactsArray) {
                  for (NSDictionary *dict in contactsArray) {
                      NSString *hash = [dict objectForKey:@"token"];
                      NSString *identifier = [phoneNumbersByHashes objectForKey:hash];

                      if (!identifier) {
                          DDLogWarn(@"%@ An interesecting hash wasn't found in the mapping.", self.logTag);
                          break;
                      }

                      [attributesForIdentifier setObject:dict forKey:identifier];
                  }
              }

              // Insert or update contact attributes
              [OWSPrimaryStorage.dbReadWriteConnection
                  readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
                      for (NSString *identifier in attributesForIdentifier) {
                          SignalRecipient *recipient = [SignalRecipient recipientWithTextSecureIdentifier:identifier
                                                                                          withTransaction:transaction];
                          if (!recipient) {
                              recipient = [[SignalRecipient alloc] initWithTextSecureIdentifier:identifier relay:nil];
                          }

                          NSDictionary *attributes = [attributesForIdentifier objectForKey:identifier];

                          recipient.relay = attributes[@"relay"];

                          [recipient saveWithTransaction:transaction];
                      }
                  }];

              success([NSSet setWithArray:attributesForIdentifier.allKeys]);
          }
          failure:^(NSURLSessionDataTask *task, NSError *error) {
              if (!error.isNetworkConnectivityFailure) {
                  OWSProdError([OWSAnalyticsEvents contactsErrorContactsIntersectionFailed]);
              }

              NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
              if (response.statusCode == 413) {
                  failure(OWSErrorWithCodeDescription(
                      OWSErrorCodeContactsUpdaterRateLimit, @"Contacts Intersection Rate Limit"));
              } else {
                  failure(error);
              }
          }];
         */
}

@end

NS_ASSUME_NONNULL_END
