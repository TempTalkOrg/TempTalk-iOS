//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAvatarBuilder.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSContactsManager;
@class TSContactThread;

@interface OWSContactAvatarBuilder : OWSAvatarBuilder

/**
 * Build an avatar for a Signal recipient
 */

- (instancetype)initWithSignalId:(NSString *)signalId
                           color:(UIColor *)color
                        diameter:(NSUInteger)diameter
                 contactsManager:(OWSContactsManager *)contactsManager;

/**
 * Build an avatar for a recipient
 */
- (instancetype)initWithSignalId:(NSString *)signalId
                            name:(NSString *)name
                        diameter:(NSUInteger)diameter
                 contactsManager:(OWSContactsManager *)contactsManager;

- (UIImage *)buildDefaultImageForSave;

//MARK: Create a temporary avatar for the web user
- (instancetype)initWithName:(NSString *)name
                       color:(UIColor *)color
                    diameter:(NSUInteger)diameter;

- (UIImage *)buildImageForTemporary;

@end

NS_ASSUME_NONNULL_END
