//
//  DTDBKeyManager.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/8/12.
//

#import "DTDBKeyManager.h"
#import "DTUploadSecretGetNonceAPI.h"
#import "DTUploadSecretAPI.h"
#import "DTGetSecretGetNonceAPI.h"
#import "DTGetSecretAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTDBKeyExceptionWrapper.h"

@interface DTDBKeyManager ()

@property (nonatomic, strong) DTUploadSecretGetNonceAPI *uploadSecretGetNonceAPI;

@property (nonatomic, strong) DTUploadSecretAPI *uploadSecretAPI;

@property (nonatomic, strong) DTGetSecretGetNonceAPI *getSecretGetNonceAPI;

@property (nonatomic, strong) DTGetSecretAPI *getSecretAPI;

@end

@implementation DTDBKeyManager

- (DTUploadSecretGetNonceAPI *)uploadSecretGetNonceAPI {
    if(!_uploadSecretGetNonceAPI){
        _uploadSecretGetNonceAPI = [DTUploadSecretGetNonceAPI new];
    }
    return _uploadSecretGetNonceAPI;
}

- (DTUploadSecretAPI *)uploadSecretAPI {
    if(!_uploadSecretAPI){
        _uploadSecretAPI = [DTUploadSecretAPI new];
    }
    return _uploadSecretAPI;
}

- (DTGetSecretGetNonceAPI *)getSecretGetNonceAPI {
    if(!_getSecretGetNonceAPI){
        _getSecretGetNonceAPI = [DTGetSecretGetNonceAPI new];
    }
    return _getSecretGetNonceAPI;
}

- (DTGetSecretAPI *)getSecretAPI {
    if(!_getSecretAPI){
        _getSecretAPI = [DTGetSecretAPI new];
    }
    return _getSecretAPI;
}

- (instancetype)init {
    if(self = [super init]) {
        self.registered = [DTDBKeyCipher registered];
        self.rekeyFlag = [DTDBKeyCipher rekeyFlag];
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];;
    });
    
    return sharedInstance;
}

- (void)asyncRegisterDBKeyWithCompletion:(void(^)( NSError * _Nullable error))completion {
    
    NSError *error;
    DTDBKeyCipher *cipher = [DTDBKeyCipher new];
    [cipher generateAndStoreKeypairAndReturnError:&error];
    if(error){
        completion(error);
        return;
    }
    
    NSString *pem = [cipher publicKeyPemContentAndReturnError:&error];
    if(error){
        completion(error);
        return;
    }
    
    [self.uploadSecretGetNonceAPI sendRequestWithPK:pem
                                            success:^(NSString * _Nonnull nonce) {
        NSError *error;
        NSString *secretText = [cipher encryptDataWithPlainTextData:self.dbKey
                                                              error:&error];
        if(error){
            completion(error);
            return;
        }
        
        NSString *text = [secretText stringByAppendingString:nonce];
        
        NSString *signature = [cipher signatureDataWithText:text
                                                      error:&error];
        if(error){
            completion(error);
            return;
        }
        
        [self.uploadSecretAPI sendRequestWithSecretText:secretText
                                              signature:signature
                                                  nonce:nonce
                                             deviceInfo:@""
                                                success:^{
            NSError *error;
            [DTDBKeyCipher markAsRegisteredAndReturnError:&error];
            completion(error);
        } failure:^(NSError * _Nonnull error) {
            completion(error);
        }];
    } failure:^(NSError * _Nonnull error) {
        completion(error);
    }];
    
}

- (void)fetchDBKeyWithCompletion:(void(^)( NSError * _Nullable error))completion {
    
    self.fetchingDBKey = NO;
    
    if(!DTDBKeyCipher.registered){
        completion(nil);
        return;
    }
    
    __block NSError *error;
    DTDBKeyCipher *cipher = [DTDBKeyCipher new];
    
    NSString *pem = [cipher publicKeyPemContentAndReturnError:&error];
    if(error){
        completion(error);
        return;
    }
    
    self.fetchingDBKey = YES;
    [self.getSecretGetNonceAPI sendRequestWithPK:pem
                                         success:^(NSString * _Nonnull nonce) {
        NSString *signature = [cipher signatureDataWithText:nonce
                                                      error:&error];
        if(error){
            self.fetchingDBKey = NO;
            completion(error);
            return;
        }
        [self.getSecretAPI sendRequestWithSignature:signature
                                              nonce:nonce
                                            success:^(NSString * _Nonnull secretText) {
            self.dbKey = [cipher decryptDataWithCipherText:secretText
                                                     error:&error];
            self.fetchingDBKey = NO;
            completion(error);
            
        } failure:^(NSError * _Nonnull error) {
            self.fetchingDBKey = NO;
            completion(error);
        }];
    } failure:^(NSError * _Nonnull error) {
        self.fetchingDBKey = NO;
        completion(error);
    }];
    
}

@end
