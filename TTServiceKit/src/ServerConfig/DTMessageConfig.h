//
//  DTMessageConfig.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/5/20.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMessageConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong) NSArray *tunnelSecurityEnds;
@property (nonatomic, assign) BOOL tunnelSecurityEnabled;

- (BOOL)hitTheTunnelEncryptionEndsWithNumber:(NSString *)number;

@end

@interface DTMessageConfig : NSObject

+ (DTMessageConfigEntity *)fetchMessageConfig;

@end

NS_ASSUME_NONNULL_END
