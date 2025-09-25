//
//  DTContactsUpdateMessageProcessor.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/10/25.
//

#import <Foundation/Foundation.h>
#import "DTContactsNotifyEntity.h"
//

NS_ASSUME_NONNULL_BEGIN

@class SDSAnyWriteTransaction;
@class DTAddContactsEntity;
@class DSKProtoEnvelope;

extern NSString *const kContactsUpdateNotifyIncrement;
extern NSString *const kContactsUpdateNotifyFull;
extern NSString *const kContactsUpdateMembersKey;

@interface DTContactsUpdateMessageProcessor : NSObject

- (void)handleContactsUpdateMessageWithContactsNotifyEntity:(DTContactsNotifyEntity *)contactsNotifyEntity transaction:(SDSAnyWriteTransaction *)transaction;

+ (void)saveContactsVersion:(NSInteger)version;

- (void)handleAddContactMessageWithEnvelope:(DSKProtoEnvelope *)envelope contactsNotifyEntity:(DTAddContactsEntity *)addContactsEntity transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
