//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTMessaging/OWSViewController.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ConversationViewItem;
@class GalleryItemBox;
@class MediaDetailViewController;
@class TSAttachmentStream;

typedef NS_OPTIONS(NSInteger, MediaGalleryOption) {
    MediaGalleryOptionSliderEnabled = 1 << 0,
    MediaGalleryOptionShowAllMediaButton = 1 << 1
};

@protocol MediaDetailViewControllerDelegate <NSObject>

- (void)mediaDetailViewController:(MediaDetailViewController *)mediaDetailViewController
    requestDeleteConversationViewItem:(id <ConversationViewItem>)conversationViewItem;

- (void)mediaDetailViewController:(MediaDetailViewController *)mediaDetailViewController
                   isPlayingVideo:(BOOL)isPlayingVideo;

- (void)mediaDetailViewControllerDidTapMedia:(MediaDetailViewController *)mediaDetailViewController;

- (void)mediaDetailViewController:(MediaDetailViewController *)mediaDetailViewController didChangeRecognizedViewStatus:(BOOL)isShow;

@end

@interface MediaDetailViewController : OWSViewController

@property (nonatomic, weak) id<MediaDetailViewControllerDelegate> delegate;
@property (nonatomic, readonly) GalleryItemBox *galleryItemBox;

// YES when the media is zoomed in past fit-to-screen. Drag-to-dismiss is
// disabled in that state so a pan pans the zoomed image instead.
@property (nonatomic, readonly) BOOL isZoomedIn;

// Full image decoded ahead of time by the pager. Set before the view loads so
// the page shows instantly instead of flashing its background while decoding.
// For animated attachments this is a YYImage.
@property (nonatomic, nullable) UIImage *preloadedImage;

// Decodes an attachment's full image off the main thread for preloading. Returns
// a YYImage for animated attachments, a UIImage for still images, nil otherwise.
+ (nullable UIImage *)decodedImageForAttachment:(TSAttachmentStream *)attachmentStream;

// If viewItem is non-null, long press will show a menu controller.
- (instancetype)initWithGalleryItemBox:(GalleryItemBox *)galleryItemBox
                              viewItem:(id <ConversationViewItem> _Nullable)viewItem;
#pragma mark - Actions

- (void)didPressShare:(id)sender;
- (void)didPressDelete:(id)sender;
- (void)didPressPlayBarButton:(id)sender;
- (void)didPressPauseBarButton:(id)sender;
- (void)playVideo;

// Stops playback and rewinds
- (void)stopAnyVideo;

- (void)setShouldHideToolbars:(BOOL)shouldHideToolbars;
- (void)zoomOutAnimated:(BOOL)isAnimated;

@end

NS_ASSUME_NONNULL_END
