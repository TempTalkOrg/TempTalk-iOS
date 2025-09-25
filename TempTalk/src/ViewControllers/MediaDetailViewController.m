//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "MediaDetailViewController.h"
#import "AttachmentSharing.h"
#import "ConversationItemMacro.h"
#import "ConversationViewItem.h"
#import "TempTalk-Swift.h"
#import "TSAttachmentStream.h"
#import "TSInteraction.h"
#import "UIColor+OWS.h"
#import "UIUtil.h"
#import "UIView+SignalUI.h"
#import <AVKit/AVKit.h>
#import <MediaPlayer/MPMoviePlayerViewController.h>
#import <MediaPlayer/MediaPlayer.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/NSData+Image.h>
#import <YYImage/YYImage.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark -

@interface MediaDetailViewController () <UIScrollViewDelegate,
    UIGestureRecognizerDelegate,
    PlayerProgressBarDelegate,
    OWSVideoPlayerDelegate,
    DTImageRecognizedContentViewDelegate>

@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UIView *mediaView;
@property (nonatomic) UIView *presentationView;
@property (nonatomic) UIView *replacingView;
@property (nonatomic) UIButton *shareButton;

@property (nonatomic) NSData *fileData;

@property (nonatomic) TSAttachmentStream *attachmentStream;
@property (nonatomic, nullable) id<ConversationViewItem> viewItem;
@property (nonatomic, readonly) UIImage *image;

@property (nonatomic, nullable) OWSVideoPlayer *videoPlayer;
@property (nonatomic, nullable) UIButton *playVideoButton;
@property (nonatomic, nullable) PlayerProgressBar *videoProgressBar;
@property (nonatomic, nullable) UIBarButtonItem *videoPlayBarButton;
@property (nonatomic, nullable) UIBarButtonItem *videoPauseBarButton;

@property (nonatomic, nullable) DTImageRecognizeButton *recognizeButton;
@property (nonatomic, nullable) NSLayoutConstraint *recognizeButtonTrailingConstraint;
@property (nonatomic, nullable) NSLayoutConstraint *recognizeButtonBottomConstraint;
@property (nonatomic, nullable) DTImageRecognizedContentView *recognizedContentView;

@property (nonatomic, nullable) NSArray<NSLayoutConstraint *> *presentationViewConstraints;
@property (nonatomic, nullable) NSLayoutConstraint *mediaViewBottomConstraint;
@property (nonatomic, nullable) NSLayoutConstraint *mediaViewLeadingConstraint;
@property (nonatomic, nullable) NSLayoutConstraint *mediaViewTopConstraint;
@property (nonatomic, nullable) NSLayoutConstraint *mediaViewTrailingConstraint;

@end

@implementation MediaDetailViewController

- (void)dealloc
{
    [self stopAnyVideo];
}

- (instancetype)initWithGalleryItemBox:(GalleryItemBox *)galleryItemBox
                              viewItem:(id <ConversationViewItem> _Nullable)viewItem
{
    self = [super init];
    if (!self) {
        return self;
    }

    _galleryItemBox = galleryItemBox;
    _viewItem = viewItem;
    // We cache the image data in case the attachment stream is deleted.
    _image = galleryItemBox.attachmentStream.image;

    return self;
}

- (TSAttachmentStream *)attachmentStream
{
    return self.galleryItemBox.attachmentStream;
}

- (NSURL *_Nullable)attachmentUrl
{
    return self.attachmentStream.mediaURL;
}

- (NSData *)fileData
{
    if (!_fileData) {
        NSURL *_Nullable url = self.attachmentUrl;
        if (url) {
            _fileData = [NSData dataWithContentsOfURL:url];
        }
    }
    return _fileData;
}

- (BOOL)isAnimated
{
    return self.attachmentStream.isAnimated;
}

- (BOOL)isVideo
{
    return self.attachmentStream.isVideo;
}

- (void)applyTheme {
    
    UIColor *backgroundColor = Theme.isDarkThemeEnabled ? [UIColor ows_blackColor] : [UIColor ows_whiteColor];
    self.view.backgroundColor = backgroundColor;
    self.scrollView.backgroundColor = backgroundColor;
    self.mediaView.backgroundColor = backgroundColor;
    
    if (self.recognizeButton) {
        [self.recognizeButton applyTheme];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor ows_whiteColor];

    [self createContents];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self resetMediaFrame];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    [self updateMinZoomScale];
    [self centerMediaViewConstraints];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self recognizeImageIfNeed:self.image];
}

- (void)updateMinZoomScale
{
    CGSize viewSize = self.scrollView.bounds.size;
    UIImage *image = self.image;
    
    OWSAssertDebug(image);
    
    if (!image) return;

    if (image.size.width == 0 || image.size.height == 0) {
        OWSFailDebug(@"%@ Invalid image dimensions. %@", self.logTag, NSStringFromCGSize(image.size));
        return;
    }

    CGFloat scaleWidth = viewSize.width / image.size.width;
    CGFloat scaleHeight = viewSize.height / image.size.height;
    CGFloat minScale = MIN(scaleWidth, scaleHeight);

    if (minScale != self.scrollView.minimumZoomScale) {
        self.scrollView.minimumZoomScale = minScale;
        self.scrollView.maximumZoomScale = minScale * 8;
        self.scrollView.zoomScale = minScale;
    }
}

- (void)zoomOutAnimated:(BOOL)isAnimated
{
    if (self.scrollView.zoomScale != self.scrollView.minimumZoomScale) {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:isAnimated];
    }
}

#pragma mark - Initializers

- (void)createContents
{
    UIScrollView *scrollView = [UIScrollView new];
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;
    scrollView.delegate = self;

    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    [scrollView contentInsetAdjustmentBehavior];
    
    [scrollView autoPinEdgesToSuperviewEdges];

    if (self.isAnimated) {
        if (self.attachmentStream.isValidImage) {
            YYImage *animatedGif = [YYImage imageWithData:self.fileData];
            YYAnimatedImageView *animatedView = [YYAnimatedImageView new];
            animatedView.image = animatedGif;
            self.mediaView = animatedView;
        } else {
            self.mediaView = [UIImageView new];
        }
    } else if (self.isVideo) {
        self.mediaView = [self buildVideoPlayerView];
    } else {
        // Present the static image using standard UIImageView
        UIImageView *imageView = [[UIImageView alloc] initWithImage:self.image];
        
        self.mediaView = imageView;
        
        [self setupRecognizeButton];
    }

    OWSAssertDebug(self.mediaView);

    // We add these gestures to mediaView rather than
    // the root view so that interacting with the video player
    // progres bar doesn't trigger any of these gestures.
    [self addGestureRecognizersToView:self.mediaView];

    [scrollView addSubview:self.mediaView];
    self.mediaViewLeadingConstraint = [self.mediaView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    self.mediaViewTopConstraint = [self.mediaView autoPinEdgeToSuperviewEdge:ALEdgeTop];
    self.mediaViewTrailingConstraint = [self.mediaView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    self.mediaViewBottomConstraint = [self.mediaView autoPinEdgeToSuperviewEdge:ALEdgeBottom];

    self.mediaView.contentMode = UIViewContentModeScaleAspectFit;
    self.mediaView.userInteractionEnabled = YES;
    self.mediaView.clipsToBounds = YES;
    self.mediaView.layer.allowsEdgeAntialiasing = YES;
    self.mediaView.translatesAutoresizingMaskIntoConstraints = NO;

    // Use trilinear filters for better scaling quality at
    // some performance cost.
    self.mediaView.layer.minificationFilter = kCAFilterTrilinear;
    self.mediaView.layer.magnificationFilter = kCAFilterTrilinear;

    if (self.isVideo) {
        PlayerProgressBar *videoProgressBar = [PlayerProgressBar new];
        videoProgressBar.delegate = self;
        videoProgressBar.player = self.videoPlayer.avPlayer;

        // We hide the progress bar until either:
        // 1. Video completes playing
        // 2. User taps the screen
        videoProgressBar.hidden = YES;

        self.videoProgressBar = videoProgressBar;
        [self.view addSubview:videoProgressBar];
        [videoProgressBar autoPinWidthToSuperview];
        [videoProgressBar autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
        CGFloat kVideoProgressBarHeight = 44;
        [videoProgressBar autoSetDimension:ALDimensionHeight toSize:kVideoProgressBarHeight];

        UIButton *playVideoButton = [UIButton new];
        self.playVideoButton = playVideoButton;

        [playVideoButton addTarget:self action:@selector(playVideo) forControlEvents:UIControlEventTouchUpInside];

        UIImage *playImage = [UIImage imageNamed:@"play_button"];
        [playVideoButton setBackgroundImage:playImage forState:UIControlStateNormal];
        playVideoButton.contentMode = UIViewContentModeScaleAspectFill;

        [self.view addSubview:playVideoButton];

        CGFloat playVideoButtonWidth = ScaleFromIPhone5(70);
        [playVideoButton autoSetDimensionsToSize:CGSizeMake(playVideoButtonWidth, playVideoButtonWidth)];
        [playVideoButton autoCenterInSuperview];
    }
    
    [self applyTheme];
}

- (UIView *)buildVideoPlayerView
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:[self.attachmentUrl path]]) {
        OWSFailDebug(@"%@ Missing video file: %@", self.logTag, self.attachmentStream.mediaURL);
    }

    OWSVideoPlayer *player = [[OWSVideoPlayer alloc] initWithUrl:self.attachmentUrl];
    [player seekToTime:kCMTimeZero];
    player.delegate = self;
    self.videoPlayer = player;

    VideoPlayerView *playerView = [VideoPlayerView new];
    playerView.player = player.avPlayer;

    [NSLayoutConstraint autoSetPriority:UILayoutPriorityDefaultLow
                         forConstraints:^{
                             [playerView autoSetDimensionsToSize:self.image.size];
                         }];

    return playerView;
}

- (void)setShouldHideToolbars:(BOOL)shouldHideToolbars
{
    self.videoProgressBar.hidden = shouldHideToolbars;
}

- (void)addGestureRecognizersToView:(UIView *)view
{
    UITapGestureRecognizer *doubleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTapImage:)];
    doubleTap.numberOfTapsRequired = 2;
    [view addGestureRecognizer:doubleTap];

    UITapGestureRecognizer *singleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSingleTapImage:)];
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [view addGestureRecognizer:singleTap];
}

#pragma mark - Gesture Recognizers

- (void)didSingleTapImage:(UITapGestureRecognizer *)gesture
{
    [self.delegate mediaDetailViewControllerDidTapMedia:self];
}

- (void)didDoubleTapImage:(UITapGestureRecognizer *)gesture
{
    DDLogVerbose(@"%@ did double tap image.", self.logTag);
    if (self.scrollView.zoomScale == self.scrollView.minimumZoomScale) {
        CGFloat kDoubleTapZoomScale = 2;

        CGFloat zoomWidth = self.scrollView.width / kDoubleTapZoomScale;
        CGFloat zoomHeight = self.scrollView.height / kDoubleTapZoomScale;

        // center zoom rect around tapLocation
        CGPoint tapLocation = [gesture locationInView:self.scrollView];
        CGFloat zoomX = MAX(0, tapLocation.x - zoomWidth / 2);
        CGFloat zoomY = MAX(0, tapLocation.y - zoomHeight / 2);

        CGRect zoomRect = CGRectMake(zoomX, zoomY, zoomWidth, zoomHeight);

        CGRect translatedRect = [self.mediaView convertRect:zoomRect fromView:self.scrollView];

        [self.scrollView zoomToRect:translatedRect animated:YES];
    } else {
        // If already zoomed in at all, zoom out all the way.
        [self zoomOutAnimated:YES];
    }
}

- (void)didPressShare:(id)sender
{
    OWSLogInfo(@"%@: didPressShare", self.logTag);
    if (!self.viewItem) {
        OWSFailDebug(@"share should only be available when a viewItem is present");
        return;
    }

    [self.viewItem shareMediaAction];
}

- (void)didPressDelete:(id)sender
{
    OWSLogInfo(@"%@: didPressDelete", self.logTag);
    if (!self.viewItem) {
        OWSFailDebug(@"delete should only be available when a viewItem is present");
        return;
    }

    [self.delegate mediaDetailViewController:self requestDeleteConversationViewItem:self.viewItem];
}

- (void)didPressPlayBarButton:(id)sender
{
    OWSAssertDebug(self.isVideo);
    OWSAssertDebug(self.videoPlayer);
    [self playVideo];
}

- (void)didPressPauseBarButton:(id)sender
{
    OWSAssertDebug(self.isVideo);
    OWSAssertDebug(self.videoPlayer);
    [self pauseVideo];
}

- (void)didPressRecognizeButton
{
    if (self.recognizedContentView == nil) {
        return;
    }
    if (self.recognizedContentView.superview == nil) {
        [self.scrollView addSubview:self.recognizedContentView];
    }
    self.recognizedContentView.frame = self.mediaView.frame;
    self.recognizeButton.isSelected = !self.recognizeButton.isSelected;
    
    BOOL isShowRecognizedContent = self.recognizeButton.isSelected;
    
    CGFloat alpha = isShowRecognizedContent ? 1.0 : 0;
    [UIView animateWithDuration:0.25 animations:^{
        self.recognizedContentView.alpha = alpha;
    } completion:^(BOOL finished) {
        if (!isShowRecognizedContent) {
            [self.recognizedContentView dismissSelection];
        }
    }];
    
    if (self.delegate && [self.delegate respondsToSelector: @selector(mediaDetailViewController:didChangeRecognizedViewStatus:)]) {
        [self.delegate mediaDetailViewController:self didChangeRecognizedViewStatus: isShowRecognizedContent];
    }
}

#pragma mark - UIScrollViewDelegate

- (nullable UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.mediaView;
}

- (CGFloat)safeAreaBottomInset
{
    UIWindow *foundWindow = nil;
    NSArray  *windows = [[UIApplication sharedApplication] windows];
    for (UIWindow  *window in windows) {
        if (window.isKeyWindow) {
            foundWindow = window;
            break;
        }
    }
    if (foundWindow) {
        return foundWindow.safeAreaInsets.bottom;
    }
    return 0;
}

- (void)centerMediaViewConstraints
{
    OWSAssertDebug(self.scrollView);

    CGSize scrollViewSize = self.scrollView.bounds.size;
    CGSize imageViewSize = self.mediaView.frame.size;

    CGFloat yOffset = MAX(0, (scrollViewSize.height - imageViewSize.height) / 2);
    self.mediaViewTopConstraint.constant = yOffset;
    self.mediaViewBottomConstraint.constant = yOffset;

    CGFloat xOffset = MAX(0, (scrollViewSize.width - imageViewSize.width) / 2);
    self.mediaViewLeadingConstraint.constant = xOffset;
    self.mediaViewTrailingConstraint.constant = xOffset;
    
    if (self.recognizeButton) {
        self.recognizeButtonTrailingConstraint.constant = -(xOffset + 15.0);
        CGFloat minBottomInset = [self safeAreaBottomInset] + 44.0;
        if (yOffset > minBottomInset) {
            self.recognizeButtonBottomConstraint.constant = -(yOffset + 15.0);
        } else {
            self.recognizeButtonBottomConstraint.constant = -(minBottomInset + 15.0);
        }
    }
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    [self centerMediaViewConstraints];
    [self.view layoutIfNeeded];
}

- (void)resetMediaFrame
{
    // HACK: Setting the frame to itself *seems* like it should be a no-op, but
    // it ensures the content is drawn at the right frame. In particular I was
    // reproducibly seeing some images squished (they were EXIF rotated, maybe
    // related). similar to this report:
    // https://stackoverflow.com/questions/27961884/swift-uiimageview-stretched-aspect
    [self.view layoutIfNeeded];
    self.mediaView.frame = self.mediaView.frame;
}

#pragma mark - Video Playback

- (void)playVideo
{
    OWSAssertDebug(self.videoPlayer);

    self.playVideoButton.hidden = YES;

    [self.videoPlayer play];

    [self.delegate mediaDetailViewController:self isPlayingVideo:YES];
}

- (void)pauseVideo
{
    OWSAssertDebug(self.isVideo);
    OWSAssertDebug(self.videoPlayer);

    [self.videoPlayer pause];

    [self.delegate mediaDetailViewController:self isPlayingVideo:NO];
}

- (void)stopAnyVideo
{
    if (self.isVideo) {
        [self stopVideo];
    }
}

- (void)stopVideo
{
    OWSAssertDebug(self.isVideo);
    OWSAssertDebug(self.videoPlayer);

    [self.videoPlayer stop];

    self.playVideoButton.hidden = NO;

    [self.delegate mediaDetailViewController:self isPlayingVideo:NO];
}

#pragma mark - OWSVideoPlayer

- (void)videoPlayerDidPlayToCompletion:(OWSVideoPlayer *)videoPlayer
{
    OWSAssertDebug(self.isVideo);
    OWSAssertDebug(self.videoPlayer);
    DDLogVerbose(@"%@ %s", self.logTag, __PRETTY_FUNCTION__);

    [self stopVideo];
}

#pragma mark - PlayerProgressBarDelegate

- (void)playerProgressBarDidStartScrubbing:(PlayerProgressBar *)playerProgressBar
{
    OWSAssertDebug(self.videoPlayer);
    [self.videoPlayer pause];
}

- (void)playerProgressBar:(PlayerProgressBar *)playerProgressBar scrubbedToTime:(CMTime)time
{
    OWSAssertDebug(self.videoPlayer);
    [self.videoPlayer seekToTime:time];
}

- (void)playerProgressBar:(PlayerProgressBar *)playerProgressBar
    didFinishScrubbingAtTime:(CMTime)time
        shouldResumePlayback:(BOOL)shouldResumePlayback
{
    OWSAssertDebug(self.videoPlayer);
    [self.videoPlayer seekToTime:time];

    if (shouldResumePlayback) {
        [self.videoPlayer play];
    }
}

#pragma mark - Saving images to Camera Roll

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error) {
        DDLogWarn(@"There was a problem saving <%@> to camera roll from %s ",
            error.localizedDescription,
            __PRETTY_FUNCTION__);
    }
}

#pragma mark - Recognize Image

- (void)setupRecognizeButton
{
    self.recognizeButton = [DTImageRecognizeButton new];
    self.recognizeButton.layer.cornerRadius = 18.0;
    self.recognizeButton.layer.masksToBounds = YES;
    self.recognizeButton.alpha = 0;
    
    __weak typeof(self) weakSelf = self;
    self.recognizeButton.didTapCallback = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf didPressRecognizeButton];
    };
    [self.view addSubview:self.recognizeButton];
    
    [self.recognizeButton autoSetDimension:ALDimensionWidth toSize:36.0];
    [self.recognizeButton autoSetDimension:ALDimensionHeight toSize:36.0];
    self.recognizeButtonTrailingConstraint = [self.recognizeButton autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:0];
    self.recognizeButtonBottomConstraint = [self.recognizeButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0];
}

- (void)recognizeImageIfNeed:(UIImage *)image
{
    if (self.recognizeButton == nil || image == nil) {
        return;
    }
    if (self.recognizedContentView != nil) {
        if (self.recognizeButton.alpha == 0) {
            [UIView animateWithDuration:0.25 animations:^{
                self.recognizeButton.alpha = 1.0;
            }];
        }
        return;
    }
    __weak typeof(self) weakSelf = self;
    [DTImageRecognizedContentView recognizeWithImage:image size:image.size compeletion:^(DTImageRecognizedContentView * _Nullable contentView) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (contentView) {
            [UIView animateWithDuration:0.25 animations:^{
                strongSelf.recognizeButton.alpha = 1.0;
            }];
            contentView.delegate = self;
            strongSelf.recognizedContentView = contentView;
        }
    }];
}

- (void)recognizedViewDidTapped:(DTImageRecognizedContentView *)view
{
    [self.delegate mediaDetailViewControllerDidTapMedia:self];
}

- (void)recognizedView:(DTImageRecognizedContentView *)view didTapQRCodeWith:(NSString *)payload
{
    ActionSheetController *actionSheet = [[ActionSheetController alloc] initWithTitle:nil message: payload];
    [actionSheet addAction:[OWSActionSheets cancelAction]];
    
    ActionSheetAction *openAction = [[ActionSheetAction alloc] initWithTitle:Localized(@"IMAGE_RECOGNIZATION_ACTION_OPEN_URL", @"") style:ActionSheetActionStyleDestructive handler:^(ActionSheetAction * _Nonnull action) {
        NSURL *url = [[NSURL alloc] initWithString:payload];
        if (url) {
            [self handleInternalLinkWithUrl:url];
        }
    }];
    [actionSheet addAction:openAction];
    
    ActionSheetAction *copyAction = [[ActionSheetAction alloc] initWithTitle:Localized(@"IMAGE_RECOGNIZATION_ACTION_COPY_URL", @"") style:ActionSheetActionStyleDestructive handler:^(ActionSheetAction * _Nonnull action) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = payload;
    }];
    [actionSheet addAction:copyAction];
    
    [self presentActionSheet:actionSheet];
}

@end

NS_ASSUME_NONNULL_END
