//
//  DTFileUtils.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/19.
//

#import "DTFileUtils.h"
#import "OWSFileSystem.h"

@implementation DTFileUtils

+ (NSString *)dataPath{
    
    NSString *dataPath = [[OWSFileSystem appSharedDataDirectoryPath] stringByAppendingPathComponent:@"DTDatas"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return dataPath;
}

+ (NSString *)serverConfigFilePath{
    return [[self dataPath] stringByAppendingPathComponent:@"serverConfig.json"];
}

+ (NSString *)workspaceCertificateFilePath{
    return [[self dataPath] stringByAppendingPathComponent:@"workspaceCertificateInfo.json"];
}

+ (NSString *)workspaceP12FilePath{
    return [[self dataPath] stringByAppendingPathComponent:@"workspaceCertificate.p12"];
}

+ (NSString *)beyondcorpConfigureationFilePath{
    return [[self dataPath] stringByAppendingPathComponent:@"prodGlobalConfigureation.json"];
}

@end
