//
//  DTGroupAvatarUpdateProcessor.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DataSource;
@class TSGroupThread;
@class TSOutgoingMessage;
@class DTAPIMetaEntity;
@class DTGroupBaseInfoNotifyEntity;
@class TSAttachmentStream;

@interface DTGroupAvatarUpdateProcessor : NSObject

@property (nonatomic, strong) TSGroupThread *groupThread;

- (instancetype)initWithGroupThread:(TSGroupThread * _Nullable)groupThread;

- (void)uploadAttachment:(id <DataSource>)dataSource
             contentType:(NSString *)contentType
          sourceFilename:(nullable NSString *)sourceFilename
                 success:(void (^)(NSString * _Nullable))successHandler
                 failure:(void (^)(NSError *error))failureHandler;

- (void)updateWithAttachment:(id <DataSource>)dataSource
                 contentType:(NSString *)contentType
              sourceFilename:(nullable NSString *)sourceFilename
                     success:(void (^)(DTAPIMetaEntity * _Nonnull entity))successHandler
                     failure:(void (^)(NSError *error))failureHandler;

- (void)handleReceivedGroupAvatarUpdateWithAvatarUpdate:(NSString *)avatar
                                                success:(void (^)(TSAttachmentStream *attachmentStream))successHandler
                                                failure:(void (^)(NSError *error))failureHandler;

@end

NS_ASSUME_NONNULL_END
