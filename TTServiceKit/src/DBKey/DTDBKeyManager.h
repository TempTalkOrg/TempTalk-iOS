//
//  DTDBKeyManager.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTDBKeyManager : NSObject

@property (nonatomic, strong, nullable) NSData *dbKey;

@property (nonatomic, assign) BOOL registered;

@property (nonatomic, assign) BOOL rekeyFlag;

@property (nonatomic, assign) BOOL fetchingDBKey;

+ (instancetype)sharedInstance;

- (void)asyncRegisterDBKeyWithCompletion:(void(^)( NSError * _Nullable error))completion;

- (void)fetchDBKeyWithCompletion:(void(^)( NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
