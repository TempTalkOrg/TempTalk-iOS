//
//  DTChatFolderConfig.h
//  TTServiceKit
//
//  Created by Ethan on 2022/4/27.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTChatFolderConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger maxFolderCount;

@end

@interface DTChatFolderConfig : NSObject

+ (DTChatFolderConfigEntity *)fetchChatFolderConfig;

@end

NS_ASSUME_NONNULL_END
