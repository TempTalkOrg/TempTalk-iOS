//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

#import <CocoaLumberjack/DDFileLogger.h>

NS_ASSUME_NONNULL_BEGIN

@interface DebugLogger : NSObject

+ (instancetype)shared;

- (void)enableErrorReporting;

@property (nonatomic, readonly) NSURL *errorLogsDir;

- (void)wipeLogs;

- (NSArray<NSString *> *)allLogFilePaths;
+ (NSArray<NSString *> *)allLogsDirPaths;

@property (nonatomic, readonly, class) NSString *mainAppDebugLogsDirPath;
@property (nonatomic, readonly, class) NSString *shareExtensionDebugLogsDirPath;
@property (nonatomic, readonly, class) NSString *nseDebugLogsDirPath;
@property (nonatomic, readonly, class) NSString *agoraLogsDirPath;

//#ifdef TESTABLE_BUILD
//@property (nonatomic, readonly, class) NSString *testDebugLogsDirPath;
//#endif

// exposed for Swift interop
@property (nonatomic, nullable) DDFileLogger *fileLogger;

@end

#pragma mark -

@interface DebugLogFileManager : DDLogFileManagerDefault
@end

#pragma mark -

@interface ErrorLogger : DDFileLogger

+ (void)playAlertSound;

@end

NS_ASSUME_NONNULL_END

