//
//  Copyright (c) 2026 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Migrates legacy attachment plaintext to encrypted-at-rest storage.
@interface DTAttachmentPlaintextMigrator : NSObject

/// Starts or resumes a batched background migration.
+ (void)runAsync;

@end

NS_ASSUME_NONNULL_END
