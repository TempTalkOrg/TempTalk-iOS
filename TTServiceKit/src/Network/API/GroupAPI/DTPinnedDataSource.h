//
//  DTPinnedDataSource.h
//  TTServiceKit
//
//  Created by Ethan on 2022/3/26.
//

#import <Foundation/Foundation.h>
@class YapDatabaseConnection;
@class DTPinnedMessage;

NS_ASSUME_NONNULL_BEGIN

@interface DTPinnedDataSource : NSObject

+ (instancetype)shared;

- (nullable NSArray <DTPinnedMessage *> *)localPinnedMessagesWithGroupId:(nullable NSString *)groupId;

- (void)removeAllPinnedMessage:(NSString *)groupId;

- (void)syncPinnedMessageWithServer:(NSString *)serverGroupId;

@end

NS_ASSUME_NONNULL_END
