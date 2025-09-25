//
//  NSError+errorMessage.h
//  TTServiceKit
//
//  Created by hornet on 2022/10/20.
//

#import <Foundation/Foundation.h>
@class DTAPIMetaEntity;
NS_ASSUME_NONNULL_BEGIN

@interface NSError (errorMessage)

+ (NSString *)errorDesc:(NSError * __nullable)error errResponse:(DTAPIMetaEntity * __nullable)errResponse;

+ (NSString *)loginErrorDescByInviteCode:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse;
+ (NSString *)loginErrorDescByEmail:(NSError *)error errResponse:(DTAPIMetaEntity *)errResponse;

+ (NSString *)defaultErrorMessage;

@end

NS_ASSUME_NONNULL_END
