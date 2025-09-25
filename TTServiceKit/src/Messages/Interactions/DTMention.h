//
//  DTMention.h
//  TTServiceKit
//
//  Created by Ethan on 2022/11/8.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@class DSKProtoDataMessage;
@class DSKProtoDataMessageMention;

@interface DTMention : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) uint32_t start;
@property (nonatomic, assign) uint32_t length;
@property (nonatomic, copy) NSString *uid;
/// DSKProtoDataMessageMentionType
@property (nonatomic, assign) int32_t type;


/// create instance of DTMention
/// - Parameters:
///   - start: start
///   - length: length
///   - uid: uid
///   - mentionType: DSKProtoDataMessageMentionType
- (instancetype)initWithStart:(uint32_t)start
                       length:(uint32_t)length
                          uid:(NSString *)uid
                  mentionType:(int32_t)mentionType;

+ (NSArray <DTMention *> *)mentionsWithProto:(DSKProtoDataMessage *)dataMessage;
+ (NSArray <DTMention *> *)mentionsWithMentionsProto:(NSArray <DSKProtoDataMessageMention *> *)mentionsProto;
+ (NSArray <DSKProtoDataMessageMention *> *)mentionsProtoWithMentions:(NSArray <DTMention *> *)mentions;

+ (nullable NSString *)atPersons:(NSArray <DTMention *> *)mentions;

@end

NS_ASSUME_NONNULL_END
