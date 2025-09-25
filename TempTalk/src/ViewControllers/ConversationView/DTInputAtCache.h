//
//  DFInputCache.h
//  Signal
//
//  Created by Felix on 2021/7/7.
//

#import <Foundation/Foundation.h>
#import <TTServiceKit/TTServiceKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kMentionStartChar;
extern NSString *const kMentionEndChar;
extern NSString *const kMentionExternalSuffix;

@interface DTInputAtItem : NSObject

@property (nonatomic, copy) NSString *name;

@property (nonatomic, copy) NSString *uid;

@property (nonatomic, assign) NSRange range;

/// DSKProtoDataMessageMentionType
@property (nonatomic, assign) int32_t type;

@end


@interface DTInputAtCache : NSObject

- (NSArray *)allAtShowName:(NSString *)sendText;

- (NSArray *)allAtUid:(NSString *)sendText;

- (NSArray <DTMention *> *)allMentions:(NSString *)sendText;

- (void)clean;

- (void)addAtItem:(DTInputAtItem *)item;

- (DTInputAtItem *)item:(NSString *)name;

- (DTInputAtItem *)removeName:(NSString *)name;

- (BOOL)hasMentions;

- (void)setMentions:(NSArray <DTMention *> *)mentions body:(NSString *)body;

@end

NS_ASSUME_NONNULL_END
