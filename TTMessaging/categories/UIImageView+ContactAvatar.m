//
//  UIImageView+ContactAvatar.m
//  TTMessaging
//
//  Created by Kris.s on 2021/11/9.
//

#import "UIImageView+ContactAvatar.h"
#import <SDWebImage/SDWebImage.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/SSKCryptography.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <SignalCoreKit/Threading.h>
#import "Environment.h"
#import "NSObject+OWS.h"
#import "DTParamsBaseUtils.h"
#import "OWSProfileManager.h"
#import "OWSProfileManger+Extension.h"
#import "OWSContactAvatarBuilder.h"
#import "UIColor+OWS.h"
#import "TSThread.h"
#import "DTContactAvatarEntity.h"
#import "OWSContactsManager.h"
#import "objc/runtime.h"
#import "DTServerUrlManager.h"

static void * loadKeyPropertyKey = &loadKeyPropertyKey;

@implementation UIImageView (ContactAvatar)

- (NSString *)loadKey{
    return objc_getAssociatedObject(self, loadKeyPropertyKey);
}

- (void)setLoadKey:(NSString *)loadKey {
    objc_setAssociatedObject(self, loadKeyPropertyKey, loadKey, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (SDImageCache *)imageCache{
    return Environment.shared.contactsManager.sdAvatarCache;
}

- (SDWebImageManager *)imageManager{
    return Environment.shared.contactsManager.imageManager;
}

- (OWSContactsManager *)contactsManager {
    return Environment.shared.contactsManager;
}

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      transaction:(SDSAnyReadTransaction *)transaction
                       completion:(void (^ __nullable)(UIImage *))completion {
    NSString *displayName = [self.contactsManager displayNameForPhoneIdentifier:recipientId transaction:transaction];
    
    [self setImageWithContactAvatar:avatar recipientId:recipientId displayName:displayName asyncMaxSize:self.defaultAsyncMaxSize completion:completion];
}

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName
                       completion:(void (^ __nullable)(UIImage *))completion {
    
    [self setImageWithContactAvatar:avatar
                        recipientId:recipientId
                        displayName:displayName
                       asyncMaxSize:self.defaultAsyncMaxSize
                         completion:completion];
}

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName
                     asyncMaxSize:(NSUInteger)asyncMaxSize
                       completion:(void (^ __nullable)(UIImage *))completion {
    DTContactAvatarEntity *entity = nil;
    if(DTParamsUtils.validateDictionary(avatar)){
        entity = [MTLJSONAdapter modelOfClass:[DTContactAvatarEntity class] fromJSONDictionary:avatar error:nil];
    }
    
    if (!DTParamsUtils.validateString(entity.encKey) || !entity.attachmentId.length) {
        
        self.loadKey = @"";
        [self setDefaultImageWithName:displayName recipientId:recipientId];
        
        return;
    }
    
    SDWebImageDownloaderDecryptor *decryptor = [SDWebImageDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
        return [self decryptProfileData:data profileKeyString:entity.encKey];
    }];
    
    // TODO: check
    NSString *avatarUrlString = [self.class placeHolderImageCacherKey:entity];
    NSString *cacheKey = [SSKCryptography getMd5WithString:entity.attachmentId];
    
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString *filePath = [self.imageCache.diskCache cachePathForKey:avatarUrlString];
    NSUInteger imageDataLength = 0;
    if ([manager fileExistsAtPath:filePath]){
        imageDataLength = [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    NSUInteger maxSize = asyncMaxSize;
    __block UIImage *placeHolderImage = nil;
    
    self.loadKey = cacheKey;
    
    @weakify(self);
    void (^setImageBlock)(void) = ^{
        
        if (placeHolderImage.sd_isAnimated) {
            
            placeHolderImage = [placeHolderImage.images firstObject];
        }
        
        if (!placeHolderImage) {
                        
            NSString *colorName = [TSThread stableConversationColorNameForString:recipientId];
            UIColor *color = [UIColor ows_conversationColorForColorName:colorName];
            placeHolderImage = [[[OWSContactAvatarBuilder alloc] initWithSignalId:recipientId
                                                                            color:color
                                                                         diameter:48
                                                                  contactsManager:Environment.shared.contactsManager]
                                build];
        } else {
            if([cacheKey isEqualToString:self.loadKey]){
                self.image = placeHolderImage;
            }
            return;
        }
        
        [self sd_internalSetImageWithURL:[NSURL URLWithString:avatarUrlString]
                        placeholderImage:placeHolderImage
                                 options:SDWebImageDecodeFirstFrameOnly | SDWebImageScaleDownLargeImages
                                 context:@{SDWebImageContextDownloadDecryptor:decryptor,
                                           SDWebImageContextCustomManager:self.imageManager
                                         }
                           setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            @strongify(self);
            if (!completion) {
                DispatchMainThreadSafe(^{
                    
                    if([cacheKey isEqualToString:self.loadKey]){
                        self.image = image;
                    }
                    
                    
                });
            }
            
        }                       progress:nil
                               completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, SDImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
            if (completion && [cacheKey isEqualToString:self.loadKey]) {
                completion(image);
            }
        }];
    };
    
    if(imageDataLength <= maxSize) {
        placeHolderImage = [self.class placeHolderImageFromCacheForKey:avatarUrlString];
        setImageBlock();
    } else {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            placeHolderImage = [self.class placeHolderImageFromCacheForKey:avatarUrlString];
            dispatch_async(dispatch_get_main_queue(), ^{
                setImageBlock();
            });
        });
    }
}

+ (nullable UIImage *)placeHolderImageFromCacheForKey:(NSString *) avatarUrlString {
    return  [Environment.shared.contactsManager.sdAvatarCache imageFromCacheForKey:avatarUrlString options: SDWebImageDecodeFirstFrameOnly | SDWebImageScaleDownLargeImages context:nil];
}

+ (NSString *)placeHolderImageCacherKey:(DTContactAvatarEntity *) entity {
    return [TSConstants.avatarStorageServerURL stringByAppendingPathComponent:entity.attachmentId];
}

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName
{
    [self setImageWithContactAvatar:avatar recipientId:recipientId displayName:displayName asyncMaxSize:self.defaultAsyncMaxSize];
}

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName
                     asyncMaxSize:(NSUInteger)asyncMaxSize
{
    [self setImageWithContactAvatar:avatar recipientId:recipientId displayName:displayName asyncMaxSize:asyncMaxSize completion:nil];
}

- (void)setImageWithContactAvatar:(NSDictionary *)avatar{
    [self setImageWithContactAvatar:avatar recipientId:nil displayName:nil];
}

- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId {
    [self setImageWithRecipientId:recipientId
                      displayName:nil
                     asyncMaxSize:self.defaultAsyncMaxSize];
}

//- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId
//                   asyncMaxSize:(NSUInteger)asyncMaxSize {
//    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
//    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
//    [self setImageWithContactAvatar:account.contact.avatar recipientId:recipientId displayName:account.contact.fullName asyncMaxSize:asyncMaxSize];
//}

- (void)setImageWithRecipientId:(NSString *)recipientId
                    displayName:(NSString *)displayName {
    [self setImageWithRecipientId:recipientId
                      displayName:displayName
                     asyncMaxSize:self.defaultAsyncMaxSize];
}

- (void)setImageWithRecipientId:(NSString *)recipientId
                    displayName:(NSString *)displayName
                   asyncMaxSize:(NSUInteger)asyncMaxSize {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:recipientId];
    NSDictionary *avatar = nil;
    if (account) {
        avatar = account.contact.avatar;
        if (!displayName || [displayName isEqualToString:recipientId]) {
            displayName = account.contact.fullName;
        }
    }
    [self setImageWithContactAvatar:avatar
                        recipientId:recipientId
                        displayName:displayName
                       asyncMaxSize:asyncMaxSize];
}

- (void)setDefaultImageWithName:(NSString * _Nullable)name recipientId:(NSString * _Nullable)recipientId {
    
    BOOL unexpectedId = [recipientId.lowercaseString isEqualToString:@"unknown"] || !DTParamsUtils.validateString(recipientId);
    if (unexpectedId) {
        recipientId = @"#";
    }
        
    DispatchMainThreadSafe(^{
        self.image = [[[OWSContactAvatarBuilder alloc] initWithSignalId:recipientId
                                                                   name:name
                                                               diameter:48
                                                        contactsManager:Environment.shared.contactsManager] build];
    });
}

- (void)getAvatarUrlWithContactAvatarEntity:(DTContactAvatarEntity *)entity
                                 completion:(void(^)(NSString *urlString))completion{
    
    TSRequest *req = [OWSRequestFactory profileAvatarUploadUrlRequest:entity.attachmentId];
    
    [self.networkManager makeRequest:req
                     completionQueue:dispatch_get_main_queue() success:^(id<HTTPResponse> _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        if (DTParamsUtils.validateDictionary(responseObject)) {
            NSString* location = [responseObject objectForKey:@"location"];
            
            completion(location);
        } else {
            OWSLogError(@"unexpected response from server: %@", responseObject);
            completion(nil);
            return;
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        OWSLogError(@"Failed to allocate attachment with error: %@", error.asNSError);
        completion(nil);
    }];
}

- (NSData *)decryptProfileData:(NSData *)encryptedData profileKeyString:(NSString *)profileKeyString
{
    
    return [[self class] decryptProfileData:encryptedData profileKeyString:profileKeyString];
}

+ (NSData *)decryptProfileData:(NSData *)encryptedData profileKeyString:(NSString *)profileKeyString
{
    
    if(!DTParamsUtils.validateString(profileKeyString)){
        return nil;
    }
    
    NSData *profileKeyData = [NSData dataFromBase64String:profileKeyString];
    
    if(!profileKeyData.length) return nil;
    
    SSKAES256Key *profileKey = [SSKAES256Key keyWithData:profileKeyData];
    
    OWSAssertDebug(profileKey.keyData.length == kAES256_KeyByteLength);

    if (!encryptedData) {
        return nil;
    }

    return [SSKCryptography decryptAESGCMWithData:encryptedData key:profileKey];
}



- (void)setImageWithGroupThread:(TSGroupThread *)thread
                       diameter:(NSUInteger)diameter
                contactsManager:(OWSContactsManager *)contactsManager{
    
    self.loadKey = @"0";
    DispatchMainThreadSafe(^{
        @weakify(self);
        [self setImageWithGroupThread:thread diameter:diameter contactsManager:contactsManager completion:^(UIImage * _Nonnull image) {
            @strongify(self);
            self.image = image;
        }];
    });
}

- (void)setImageWithGroupThread:(TSGroupThread *)thread
                       diameter:(NSUInteger)diameter
                contactsManager:(OWSContactsManager *)contactsManager
                     completion:(void (^ __nullable)(UIImage *))completion {
    
    self.loadKey = @"0";
    UIImage *placeholderImage = [OWSAvatarBuilder buildImageForThread:thread
                                                             diameter:diameter
                                                      contactsManager:contactsManager];
    DispatchMainThreadSafe(^{
        if (completion) {
            completion(placeholderImage);
        }
    });
}

- (void)dt_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder{
    self.loadKey = @"1";
    DispatchMainThreadSafe(^{
        [self sd_setImageWithURL:url placeholderImage:placeholder];
    });
}

- (NSUInteger)defaultAsyncMaxSize {
    return 200 * 1024;
}

@end
