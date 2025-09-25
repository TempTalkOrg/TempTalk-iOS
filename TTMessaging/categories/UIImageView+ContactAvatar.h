//
//  UIImageView+ContactAvatar.h
//  TTMessaging
//
//  Created by Kris.s on 2021/11/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class TSGroupThread;
@class OWSContactsManager;
@class SDSAnyReadTransaction;
@class DTContactAvatarEntity;

@interface UIImageView (ContactAvatar)

//recommend
- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName;

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      transaction:(SDSAnyReadTransaction *)transaction
                       completion:(void (^ __nullable)(UIImage *))completion;

- (void)setImageWithContactAvatar:(NSDictionary * _Nullable)avatar
                      recipientId:(NSString * _Nullable)recipientId
                      displayName:(NSString * _Nullable)displayName
                       completion:(void (^ __nullable)(UIImage *))completion;

- (void)setImageWithContactAvatar:(NSDictionary *)avatar;

- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId;

//- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId
//                   asyncMaxSize:(NSUInteger)asyncMaxSize;
- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId
                    displayName:(NSString * _Nullable)displayName;

- (void)setImageWithRecipientId:(NSString * _Nullable)recipientId
                    displayName:(NSString * _Nullable)displayName
                   asyncMaxSize:(NSUInteger)asyncMaxSize;

- (void)setImageWithGroupThread:(TSGroupThread *)thread
                       diameter:(NSUInteger)diameter
                contactsManager:(OWSContactsManager *)contactsManager;

- (void)setImageWithGroupThread:(TSGroupThread *)thread
                       diameter:(NSUInteger)diameter
                contactsManager:(OWSContactsManager *)contactsManager
                     completion:(void (^ __nullable)(UIImage *))completion;

- (void)dt_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder;

+ (NSData *)decryptProfileData:(NSData *)encryptedData profileKeyString:(NSString *)profileKeyString;
+ (nullable UIImage *)placeHolderImageFromCacheForKey:(NSString *) avatarUrlString;
+ (NSString *)placeHolderImageCacherKey:(DTContactAvatarEntity *) entity;
@end

NS_ASSUME_NONNULL_END
