//
//  DFInputCache.m
//  Signal
//
//  Created by Felix on 2021/7/7.
//

#import "DTInputAtCache.h"
#import "DTMention.h"
#import <TTServiceKit/DTPatternHelper.h>

NSString *const kMentionStartChar      = @"@";
NSString *const kMentionEndChar        = @" ";
NSString *const kMentionExternalSuffix = @"*";

@implementation DTInputAtItem

@end

@interface DTInputAtCache ()

@property (nonatomic, strong) NSMutableArray <DTInputAtItem *> *items;

@end

@implementation DTInputAtCache

- (instancetype)init
{
    self = [super init];
    if (self) {
        _items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray *)allAtShowName:(NSString *)sendText {
    NSArray *names = [self matchString:sendText];
    NSMutableArray *uids = [[NSMutableArray alloc] init];
    for (NSString *name in names) {
        DTInputAtItem *item = [self item:name];
        if (item)
        {
            [uids addObject:item];
        }
    }
    return [NSArray arrayWithArray:uids];
}

- (NSArray *)allAtUid:(NSString *)sendText
{
    NSMutableArray *atUids = @[].mutableCopy;
    [self.items enumerateObjectsUsingBlock:^(DTInputAtItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([sendText containsString:obj.name])
        [atUids addObject:obj.uid];
    }];
     
    return atUids.copy;
}

- (NSArray <DTMention *> *)allMentions:(NSString *)sendText {
    
    NSMutableDictionary <NSString *, NSMutableArray <DTInputAtItem*> *> *tmpItems = @{}.mutableCopy;
    [self.items enumerateObjectsUsingBlock:^(DTInputAtItem * _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *atName = [kMentionStartChar stringByAppendingString:item.name];
        if ([tmpItems.allKeys containsObject:atName]) {
            [tmpItems[atName] addObject:item];
        } else {
            NSMutableArray *tmpArr = @[item].mutableCopy;
            tmpItems[atName] = tmpArr;
        }
    }];
    
    NSMutableArray <DTMention *> *tmpAllMentions = [NSMutableArray new];
    NSMutableArray <DTMention *> *invalidMentions = [NSMutableArray new];
    [tmpItems enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<DTInputAtItem *> * _Nonnull items, BOOL * _Nonnull stop) {
        NSArray <NSTextCheckingResult *> *checkResults = [DTPatternHelper matchResultFormString:sendText pattern:key];
        [checkResults enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop_) {
            DTMention *mention = [[DTMention alloc] initWithStart:(uint32_t)result.range.location length:(uint32_t)result.range.length uid:items.firstObject.uid mentionType:items.firstObject.type];
            if (tmpAllMentions.count == 0) {
                [tmpAllMentions addObject:mention];
            } else {
                for (DTMention *existMention in tmpAllMentions.copy) {
                    if (existMention.start != result.range.location) {
                        if (![tmpAllMentions containsObject:mention]) {
                            [tmpAllMentions addObject:mention];
                        }
                    } else {
                        if (existMention.length < result.range.length) {
                            if (![invalidMentions containsObject:existMention]) {
                                [invalidMentions addObject:existMention];
                            }
                        }
                    }
                }
            }
        }];
    }];
    if (invalidMentions.count > 0) {
        [tmpAllMentions removeObjectsInArray:invalidMentions];
    }
    
    return tmpAllMentions.copy;
}

- (void)clean
{
    [self.items removeAllObjects];
}

- (void)addAtItem:(DTInputAtItem *)item {
    
    BOOL isExist = NO;
    for (DTInputAtItem *oldItem in self.items) {
        isExist = [item.uid isEqualToString:oldItem.uid] && NSEqualRanges(item.range, oldItem.range);
        if (isExist) { break; }
    }
    if (isExist) { return; }
    [self.items addObject:item];
}

- (DTInputAtItem *)item:(NSString *)name
{
    __block DTInputAtItem *item;
    [_items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DTInputAtItem *object = obj;
        if ([object.name isEqualToString:name])
        {
            item = object;
            *stop = YES;
        } else {
            if ([name containsString:object.name]) {
                item = object;
                *stop = YES;
            }
        }
    }];
    return item;
}

- (DTInputAtItem *)removeName:(NSString *)name
{
    __block DTInputAtItem *item;
    [_items enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DTInputAtItem *object = obj;
        if ([object.name isEqualToString:name]) {
            item = object;
            *stop = YES;
        }
    }];
    if (item) {
        [_items removeObject:item];
    }
    return item;
}

- (NSArray *)matchString:(NSString *)sendText
{
    NSString *pattern = [NSString stringWithFormat:@"%@([^@]+)%@", kMentionStartChar, kMentionEndChar];
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSArray *results = [regex matchesInString:sendText options:0 range:NSMakeRange(0, sendText.length)];
    NSMutableArray *matchs = [[NSMutableArray alloc] init];
    for (NSTextCheckingResult *result in results) {
        NSString *name = [sendText substringWithRange:result.range];
//        name = [name substringFromIndex:1];
//        name = [name substringToIndex:name.length -1];
        [matchs addObject:name];
    }
    return matchs;
     
//    NSMutableArray *matchs = [[NSMutableArray alloc] init];
//    NSArray *elements = [sendText componentsSeparatedByString:kMentionEndChar];
//    [elements enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        if([obj hasPrefix:kMentionStartChar] && obj.length > 1){
//            [matchs addObject:[obj substringFromIndex:1]];
//        }
//    }];
//    return matchs;
}

- (BOOL)hasMentions {
    return DTParamsUtils.validateArray(self.items);
}

- (void)setMentions:(NSArray <DTMention *> *)mentions body:(NSString *)body {
    
    if (body.length < 2) return;
    [self.items removeAllObjects];
    [mentions enumerateObjectsUsingBlock:^(DTMention * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange nameRange = NSMakeRange(obj.start + 1, obj.length - 1);
        if (nameRange.location + nameRange.length > body.length) {
            return;
        }
        if (nameRange.length > body.length) {
            return;
        }
        NSString *name = [body substringWithRange:nameRange];
        DTInputAtItem *item = [DTInputAtItem new];
        item.uid = obj.uid;
        item.type = obj.type;
        item.name = name;
        item.range = nameRange;
        [self addAtItem:item];
    }];
}

@end
