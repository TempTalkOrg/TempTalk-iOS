//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class TSAttachmentStream;

typedef void (^AttachmentStateBlock)(BOOL isAttachmentReady);

// This entity is used to display upload progress for outgoing
// attachments in conversation view cells.
//
// During attachment uploads we want to:
//
// * Dim the media view using a mask layer.
// * Show and update a progress bar.
// * Disable any media view controls using a callback.
@interface AttachmentUploadView : UIView

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachment
           attachmentStateCallback:(AttachmentStateBlock _Nullable)attachmentStateCallback;

/// Suppresses the built-in progress bar and label, leaving only the state callback.
/// For cells that draw their own treatment: video cells share one spinner between
/// compression and upload, which the user has no reason to tell apart. Defaults to NO.
@property (nonatomic) BOOL suppressesProgressUI;

@end

NS_ASSUME_NONNULL_END
