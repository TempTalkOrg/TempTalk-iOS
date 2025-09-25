//
//  DTFileRequestHandler.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/13.
//

#import <Foundation/Foundation.h>
#import "DTFileAPI.h"

NS_ASSUME_NONNULL_BEGIN

@class DTRapidFile;

typedef void (^DTFileRequestCompletionBlock)(DTFileDataEntity *_Nullable entity, NSError * _Nullable error);

@interface DTFileRequestHandler : NSObject


+ (void)checkFileExistsWithFileHash:(NSString *)fileHash
                         recipients:(NSArray *)recipients
                         completion:(DTFileRequestCompletionBlock)completion;

+ (void)reportToServerWithFileHash:(NSString *)fileHash
                        recipients:(NSArray *)recipients
                      attachmentId:(NSString *)attachmentId
                          fileSize:(long long)fileSize
                            digest:(NSString *)digest
                        completion:(DTFileRequestCompletionBlock)completion;

+ (void)getFileInfoWithFileHash:(NSString *)fileHash
                    authorizeId:(UInt64)authorizeId
                            gid:(NSString *)gid
                     completion:(DTFileRequestCompletionBlock)completion;

+ (void)markAsInvalidWithFileHash:(NSString *)fileHash
                      authorizeId:(UInt64)authorizeId
                       completion:(DTFileRequestCompletionBlock)completion;


/// 取消文件授权
/// - Parameters:
///   - fileInfos: 取消授权文件信息
///   - completion: complete
+ (void)removeAuthorizeWithFileInfos:(NSArray<DTRapidFile *> *)fileInfos
                          completion:(DTFileRequestCompletionBlock _Nullable)completion;


@end

NS_ASSUME_NONNULL_END
