//
//  DTFileRequestHandler.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/13.
//

#import "DTFileRequestHandler.h"
#import "TSAccountManager.h"
#import "DTRapidFile.h"

@implementation DTFileRequestHandler

+ (void)checkFileExistsWithFileHash:(NSString *)fileHash
                         recipients:(NSArray *)recipients
                         completion:(DTFileRequestCompletionBlock)completion{
    
    NSMutableArray *newNumbers = recipients.mutableCopy;
    if(!newNumbers){
        newNumbers = @[].mutableCopy;
    }
    
    if(!DTParamsUtils.validateString(fileHash) ||
       !DTParamsUtils.validateString([TSAccountManager localNumber])){
        completion(nil, DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    [newNumbers addObject:[TSAccountManager localNumber]];
    
    DTFileAPI *api = [DTFileAPI new];
    api.requestUrl = @"/v1/file/isExists";
    [api sendRequestWithParams:@{@"fileHash":fileHash,
                                 @"numbers":newNumbers.copy}
                       success:^(DTFileDataEntity * _Nonnull entity) {
        completion(entity, nil);
    } failure:^(NSError * _Nonnull error) {
        completion(nil, error);
    }];
    
}

+ (void)reportToServerWithFileHash:(NSString *)fileHash
                        recipients:(NSArray *)recipients
                      attachmentId:(NSString *)attachmentId
                          fileSize:(long long)fileSize
                            digest:(NSString *)digest
                        completion:(DTFileRequestCompletionBlock)completion{
    
    NSMutableArray *newNumbers = recipients.mutableCopy;
    if(!newNumbers){
        newNumbers = @[].mutableCopy;
    }
    
    if(!DTParamsUtils.validateString(fileHash) ||
       !DTParamsUtils.validateString(attachmentId) ||
       fileSize <= 0 ||
       !DTParamsUtils.validateString(digest) ||
       !DTParamsUtils.validateString([TSAccountManager localNumber])){
        completion(nil, DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    [newNumbers addObject:[TSAccountManager localNumber]];
    
    DTFileAPI *api = [DTFileAPI new];
    api.requestUrl = @"/v1/file/uploadInfo";
    [api sendRequestWithParams:@{@"fileHash":fileHash,
                                 @"attachmentId":attachmentId,
                                 @"fileSize":@(fileSize),
                                 @"hashAlg":@"SHA-256",
                                 @"keyAlg":@"SHA-512",
                                 @"encAlg":@"AES-CBC-256",
                                 @"cipherHash":digest,
                                 @"cipherHashType":@"MD5",
                                 @"numbers":newNumbers.copy}
                       success:^(DTFileDataEntity * _Nonnull entity) {
        completion(entity, nil);
    } failure:^(NSError * _Nonnull error) {
        completion(nil, error);
    }];
    
}

+ (void)getFileInfoWithFileHash:(NSString *)fileHash
                    authorizeId:(UInt64)authorizeId
                            gid:(NSString *)gid
                     completion:(DTFileRequestCompletionBlock)completion{
    
    if(!DTParamsUtils.validateString(fileHash) ||
       authorizeId <= 0){
        completion(nil, DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    DTFileAPI *api = [DTFileAPI new];
    api.requestUrl = @"/v1/file/download";
    NSMutableDictionary *parameters = @{
        @"fileHash" : fileHash,
        @"authorizeId" : [NSString stringWithFormat:@"%lld",authorizeId]
    }.mutableCopy;
    if (DTParamsUtils.validateString(gid)) {
        parameters[@"gid"] = gid;
    }

    [api sendRequestWithParams:parameters.copy
                       success:^(DTFileDataEntity * _Nonnull entity) {
        completion(entity, nil);
    } failure:^(NSError * _Nonnull error) {
        completion(nil, error);
    }];
    
}

+ (void)markAsInvalidWithFileHash:(NSString *)fileHash
                      authorizeId:(UInt64)authorizeId
                       completion:(DTFileRequestCompletionBlock)completion{
    if(!DTParamsUtils.validateString(fileHash) ||
       authorizeId <= 0){
        completion(nil, DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    DTFileAPI *api = [DTFileAPI new];
    api.requestUrl = @"/v1/file/delete";
    [api sendRequestWithParams:@{@"fileHash":fileHash, @"authorizeId":[NSString stringWithFormat:@"%lld",authorizeId]}
                       success:^(DTFileDataEntity * _Nonnull entity) {
        completion(entity, nil);
    } failure:^(NSError * _Nonnull error) {
        completion(nil, error);
        DDLogError(@"%@ mark as invalid error: %@", self.logTag, error);
    }];
}

+ (void)removeAuthorizeWithFileInfos:(NSArray<DTRapidFile *> *)fileInfos
                          completion:(DTFileRequestCompletionBlock)completion{
    if(!DTParamsUtils.validateArray(fileInfos)){
        completion(nil, DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    NSMutableArray *items = @[].mutableCopy;
    [fileInfos enumerateObjectsUsingBlock:^(DTRapidFile * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        __block NSDictionary *targetFileInfo = nil;
        [items enumerateObjectsUsingBlock:^(NSDictionary *info, NSUInteger idx, BOOL * _Nonnull stop) {
            if([info[@"fileHash"] isEqualToString:obj.rapidHash]){
                targetFileInfo = info;
                *stop = YES;
            }
        }];
        
        NSMutableArray *authorizeIds = @[].mutableCopy;
        if(DTParamsUtils.validateArray(targetFileInfo[@"authorizeIds"])){
            authorizeIds = [targetFileInfo[@"authorizeIds"] mutableCopy];
        }
        [authorizeIds addObject:obj.authorizedId];
        
        [items removeObject:targetFileInfo];
        [items addObject:@{@"fileHash" : obj.rapidHash,
                           @"authorizeIds" : authorizeIds.copy
                         }];
    }];
    
    DTFileAPI *api = [DTFileAPI new];
    api.requestUrl = @"/v1/file/delAuthorize";
    [api sendRequestWithParams:@{@"delAuthorizeInfos":items.copy}
                       success:^(DTFileDataEntity * _Nonnull entity) {
        completion(entity, nil);
    } failure:^(NSError * _Nonnull error) {
        completion(nil, error);
        DDLogError(@"%@ remove authorize error: %@", self.logTag, error);
    }];
    
}

@end
