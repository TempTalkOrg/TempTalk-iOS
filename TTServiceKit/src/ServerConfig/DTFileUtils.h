//
//  DTFileUtils.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTFileUtils : NSObject

+ (NSString *)dataPath;

+ (NSString *)serverConfigFilePath;

+ (NSString *)workspaceCertificateFilePath;

+ (NSString *)workspaceP12FilePath;

+ (NSString *)beyondcorpConfigureationFilePath;
@end

NS_ASSUME_NONNULL_END
