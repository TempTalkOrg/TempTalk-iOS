//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "AttachmentSharing.h"
#import "UIUtil.h"
#import <TTServiceKit/AppContext.h>
#import <TTServiceKit/MIMETypeUtil.h>
#import <TTServiceKit/OWSDispatch.h>
#import <TTServiceKit/TSAttachmentStream.h>
#import <SignalCoreKit/Threading.h>

NS_ASSUME_NONNULL_BEGIN

@implementation AttachmentSharing

+ (void)showShareUIForAttachment:(TSAttachmentStream *)stream
{
    OWSAssertDebug(stream);
    NSString *uti = [MIMETypeUtil utiTypeForMIMEType:stream.contentType] ?: @"public.data";
    NSItemProvider *provider = [[NSItemProvider alloc] init];
    // Preserve the normalized attachment filename without creating a plaintext file.
    NSString *_Nullable suggestedName = stream.filePath.lastPathComponent;
    provider.suggestedName = suggestedName.length > 0 ? suggestedName : stream.uniqueId;
    [provider registerDataRepresentationForTypeIdentifier:uti
                                                visibility:NSItemProviderRepresentationVisibilityAll
                                               loadHandler:^NSProgress *_Nullable(void (^completionHandler)(NSData *_Nullable,
                                                                                                               NSError *_Nullable)) {
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
        // Decrypt lazily so presenting a large encrypted file never freezes the UI.
        dispatch_async([OWSDispatch attachmentsQueue], ^{
            NSData *_Nullable data = stream.decryptedData;
            if (data) {
                progress.completedUnitCount = 1;
                completionHandler(data, nil);
                return;
            }

            NSError *error = [NSError errorWithDomain:@"AttachmentSharing"
                                                 code:1
                                             userInfo:@{
                                                 NSLocalizedDescriptionKey : NSLocalizedString(
                                                     @"ERROR_DESCRIPTION_UNKNOWN_ERROR", nil)
                                             }];
            OWSLogError(@"%@ Could not decrypt attachment for sharing.", self.logTag);
            completionHandler(nil, error);
        });
        return progress;
    }];
    [AttachmentSharing showShareUIForActivityItems:@[ provider ] completion:nil];
}

+ (void)showShareUIForURL:(NSURL *)url
{
    [self showShareUIForURL:url completion:nil];
}

+ (void)showShareUIForURL:(NSURL *)url completion:(nullable AttachmentSharingCompletion)completion
{
    OWSAssertDebug(url);

    [AttachmentSharing showShareUIForActivityItems:@[
        url,
    ]
                                        completion:completion];
}

+ (void)showShareUIForText:(NSString *)text
{
    [self showShareUIForText:text completion:nil];
}

+ (void)showShareUIForText:(NSString *)text completion:(nullable AttachmentSharingCompletion)completion
{
    OWSAssertDebug(text);

    [AttachmentSharing showShareUIForActivityItems:@[
        text,
    ]
                                        completion:completion];
}

#ifdef DEBUG
+ (void)showShareUIForUIImage:(UIImage *)image
{
    OWSAssertDebug(image);

    [AttachmentSharing showShareUIForActivityItems:@[
        image,
    ]
                                        completion:nil];
}
#endif

+ (void)showShareUIForActivityItems:(NSArray *)activityItems completion:(nullable AttachmentSharingCompletion)completion
{
    OWSAssertDebug(activityItems);

    DispatchMainThreadSafe(^{
        UIActivityViewController *activityViewController =
            [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[]];

        [activityViewController setCompletionWithItemsHandler:^(UIActivityType __nullable activityType,
            BOOL completed,
            NSArray *__nullable returnedItems,
            NSError *__nullable activityError) {

            if (activityError) {
                OWSLogInfo(@"%@ Failed to share with activityError: %@", self.logTag, activityError);
            } else if (completed) {
                OWSLogInfo(@"%@ Did share with activityType: %@", self.logTag, activityType);
            }

            if (completion) {
                DispatchMainThreadSafe(completion);
            }
        }];

        UIViewController *fromViewController = CurrentAppContext().frontmostViewController;
        while (fromViewController.presentedViewController) {
            fromViewController = fromViewController.presentedViewController;
        }
        OWSAssertDebug(fromViewController);
        [fromViewController presentViewController:activityViewController animated:YES completion:nil];
    });
}

@end

NS_ASSUME_NONNULL_END
