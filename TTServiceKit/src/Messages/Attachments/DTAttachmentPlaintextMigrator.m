//
//  Copyright (c) 2026 Difft. All rights reserved.
//

#import "DTAttachmentPlaintextMigrator.h"
#import "NSUserDefaults+OWS.h"
#import "TSAttachmentStream.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

// Change this key when the encrypted envelope changes.
static NSString *const kMigrationMarkerKey = @"AttachmentPlaintextMigration.v1";
static NSUInteger const kMigrationBatchSize = 16;
static NSTimeInterval const kMigrationBatchPause = 0.1;
static BOOL migrationInFlight = NO;

@implementation DTAttachmentPlaintextMigrator

// A restored database gets a new identity and is scanned again.
+ (nullable NSString *)databaseIdentity
{
    NSURL *databaseURL = SDSDatabaseStorage.grdbDatabaseFileUrl;
    id resourceIdentifier = nil;
    NSError *error = nil;
    if (![databaseURL getResourceValue:&resourceIdentifier
                               forKey:NSURLFileResourceIdentifierKey
                                error:&error]
        || !resourceIdentifier) {
        OWSLogError(@"%@ could not identify database for attachment migration: %@", self.logTag, error);
        return nil;
    }
    return [resourceIdentifier description];
}

+ (NSArray<NSString *> *)candidateAttachmentIds
{
    NSMutableArray<NSString *> *candidateIds = [NSMutableArray new];
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
        [TSAttachmentStream anyEnumerateWithTransaction:transaction
                                                batched:YES
                                                  block:^(TSAttachment *attachment, BOOL *stop) {
            if (![attachment isKindOfClass:[TSAttachmentStream class]]) {
                return;
            }
            TSAttachmentStream *stream = (TSAttachmentStream *)attachment;
            // Draft plaintext is still needed for preprocessing and upload.
            if (!stream.isUploaded || !stream.hasUsableEncryptionMetadata || stream.filePath.length == 0) {
                return;
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:stream.filePath]) {
                [candidateIds addObject:stream.uniqueId];
            }
        }];
    }];
    return candidateIds;
}

+ (void)processAttachmentIds:(NSArray<NSString *> *)attachmentIds
                       index:(NSUInteger)index
            databaseIdentity:(NSString *)databaseIdentity
                 deferredIds:(NSMutableArray<NSString *> *)deferredIds
{
    if (index >= attachmentIds.count) {
        // Mark complete only after a fresh scan finds no remaining candidates.
        if (deferredIds.count == 0 && [self candidateAttachmentIds].count == 0) {
            [[NSUserDefaults appUserDefaults] setObject:databaseIdentity forKey:kMigrationMarkerKey];
            OWSLogInfo(@"%@ attachment plaintext migration complete.", self.logTag);
        } else {
            OWSLogInfo(@"%@ attachment plaintext migration incomplete, deferred %lu; will retry next launch.",
                       self.logTag,
                       (unsigned long)deferredIds.count);
        }
        @synchronized(self) {
            migrationInFlight = NO;
        }
        return;
    }

    NSUInteger end = MIN(index + kMigrationBatchSize, attachmentIds.count);
    for (NSUInteger candidateIndex = index; candidateIndex < end; candidateIndex++) {
        @autoreleasepool {
            NSString *attachmentId = attachmentIds[candidateIndex];
            __block TSAttachmentStream *_Nullable stream = nil;
            [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction *transaction) {
                stream = [TSAttachmentStream anyFetchAttachmentStreamWithUniqueId:attachmentId
                                                                     transaction:transaction];
            }];
            if (!stream || !stream.isUploaded || !stream.hasUsableEncryptionMetadata) {
                continue;
            }
            if (![[NSFileManager defaultManager] fileExistsAtPath:stream.filePath]) {
                continue;
            }

            // The authenticated read creates or verifies the encrypted copy.
            NSData *_Nullable plaintext = stream.decryptedData;
            if (!plaintext || !stream.hasEncryptedFile) {
                [deferredIds addObject:attachmentId];
                continue;
            }
            NSError *cleanupError = nil;
            if (![stream removePlaintextFileWithError:&cleanupError]) {
                OWSLogError(@"%@ could not remove legacy attachment plaintext: %@", self.logTag, cleanupError);
                [deferredIds addObject:attachmentId];
            }
        }
    }

    // Yield between batches.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kMigrationBatchPause * NSEC_PER_SEC)),
                   dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                   ^{
                       [self processAttachmentIds:attachmentIds
                                            index:end
                                 databaseIdentity:databaseIdentity
                                      deferredIds:deferredIds];
                   });
}

+ (void)runAsync
{
    NSString *_Nullable databaseIdentity = [self databaseIdentity];
    if (!databaseIdentity) {
        return;
    }
    if ([[[NSUserDefaults appUserDefaults] stringForKey:kMigrationMarkerKey] isEqualToString:databaseIdentity]) {
        return;
    }
    @synchronized(self) {
        if (migrationInFlight) {
            return;
        }
        migrationInFlight = YES;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSArray<NSString *> *candidateIds = [self candidateAttachmentIds];
        OWSLogInfo(@"%@ attachment plaintext migration starting, candidates: %lu",
                   self.logTag,
                   (unsigned long)candidateIds.count);
        [self processAttachmentIds:candidateIds
                            index:0
                 databaseIdentity:databaseIdentity
                      deferredIds:[NSMutableArray new]];
    });
}

@end

NS_ASSUME_NONNULL_END
