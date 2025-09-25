//
//  DTFloatMenuActionConfigEntity.h
//  TTServiceKit
//
//  Created by Jaymin on 2024/1/11.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFloatMenuActionNameModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *zhCN;
@property (nonatomic, copy) NSString *enUS;

@end

@interface DTFloatMenuActionConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, strong) DTFloatMenuActionNameModel *name;
@property (nonatomic, copy) NSString *jumpUrl;
@property (nonatomic, copy) NSString *iconUrl;

@end

NS_ASSUME_NONNULL_END
