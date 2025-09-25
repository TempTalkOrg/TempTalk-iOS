//
//  DTTokenEntity.h
//  TTServiceKit
//
//  Created by hornet on 2021/11/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTTokenEntity : NSObject

@property(nonatomic,strong) NSNumber *did;
@property(nonatomic,strong) NSNumber *exp;//过期时间
@property(nonatomic,strong) NSNumber *iat;//创建时间
@property(nonatomic,copy) NSString *uid;//用户id
@property(nonatomic,strong) NSNumber *ver;//版本
@property(nonatomic,copy) NSString *authToken;//版本

@property(nonatomic,assign,readwrite) NSInteger expLocalTime;//已经校正的本地过期时间

@end

NS_ASSUME_NONNULL_END
