//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAudioMessageView.h"
#import "ConversationViewItem.h"
#import "TempTalk-Swift.h"
#import "UIColor+OWS.h"
#import "ViewControllerUtils.h"
#import <TTMessaging/UIColor+OWS.h>
#import <TTServiceKit/MIMETypeUtil.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSAudioMessageView ()

@property (nonatomic) TSAttachmentStream *attachmentStream;
@property (nonatomic) BOOL isIncoming;
@property (nonatomic, weak) id<ConversationViewItem>viewItem;
@property (nonatomic, readonly) ConversationStyle *conversationStyle;

@property (nonatomic, nullable) UIButton *audioPlayPauseButton;
@property (nonatomic, nullable) UILabel *audioBottomLabel;
@property (nonatomic, nullable) AudioWaveformProgressView *audioProgressView;

@property (nonatomic, strong) UIImageView *voiceAttachmentImageView;
@property (nonatomic, strong) UILabel *voiceAttachmentLabel;

@end

#pragma mark -

@implementation OWSAudioMessageView

- (instancetype)initWithAttachment:(TSAttachmentStream *)attachmentStream
                        isIncoming:(BOOL)isIncoming
                          viewItem:(id<ConversationViewItem>)viewItem
                 conversationStyle:(ConversationStyle *)conversationStyle
{
    self = [super init];

    if (self) {
        _attachmentStream = attachmentStream;
        _isIncoming = isIncoming;
        _viewItem = viewItem;
        _conversationStyle = conversationStyle;
    }

    return self;
}

- (void)updateContents
{
    [self updateAudioProgressView];
    [self updateAudioBottomLabel];

    if (self.audioPlaybackState == AudioPlaybackState_Playing) {
        [self setAudioIconToPause];
    } else {
        [self setAudioIconToPlay];
    }
}

- (CGFloat)audioProgressSeconds
{
    return [self.viewItem audioProgressSeconds];
}

- (CGFloat)audioDurationSeconds
{
    OWSAssertDebug(self.viewItem.audioDurationSeconds > 0.f);

    return self.viewItem.audioDurationSeconds;
}

- (AudioPlaybackState)audioPlaybackState
{
    return [self.viewItem audioPlaybackState];
}

- (BOOL)isAudioPlaying
{
    return self.audioPlaybackState == AudioPlaybackState_Playing;
}

- (void)updateAudioBottomLabel
{
    if (self.isAudioPlaying && self.audioProgressSeconds > 0 && self.audioDurationSeconds > 0) {
        self.audioBottomLabel.text =
        [NSString stringWithFormat:@"%@", [OWSFormat formatDurationSeconds:(long)round(self.audioDurationSeconds - self.audioProgressSeconds)]];
    } else {
        self.audioBottomLabel.text =
            [NSString stringWithFormat:@"%@", [OWSFormat formatDurationSeconds:(long)round(self.audioDurationSeconds)]];
        OWSLogInfo(@"audio bottom time: %@", [NSString stringWithFormat:@"%@", [OWSFormat formatDurationSeconds:(long)round(self.audioDurationSeconds)]]);
    }
}

- (void)setAudioIcon:(UIImage *)icon
{
    OWSAssertDebug(icon.size.height == self.iconSize);

    [_audioPlayPauseButton setImage:icon forState:UIControlStateNormal];
    [_audioPlayPauseButton setImage:icon forState:UIControlStateDisabled];
    _audioPlayPauseButton.imageView.tintColor = [UIColor ows_signalBlueColor];
}

- (void)setAudioIconToPlay
{
    [self setAudioIcon:[UIImage imageNamed:@"audio_play"]];
}

- (void)setAudioIconToPause
{
    [self setAudioIcon:[UIImage imageNamed:@"audio_stop"]];
}

- (void)updateAudioProgressView
{
    OWSLogDebug(@"[voice] c: %f, d: %f.", self.audioProgressSeconds, self.audioDurationSeconds);
    
    self.audioProgressView.value = self.audioDurationSeconds > 0 ? self.audioProgressSeconds / self.audioDurationSeconds : 0.f;

    UIColor *playedColor = self.isIncoming ? Theme.themeBlueColor2 : Theme.secondaryTextColor;
    self.audioProgressView.playedColor = playedColor;
}

#pragma mark -

- (CGFloat)hSpacing
{
    return 12.f;
}

+ (CGFloat)iconSize
{
    return 32.f;
}

- (CGFloat)iconSize
{
    return [OWSAudioMessageView iconSize];
}

- (BOOL)isVoiceMessage
{
    return self.attachmentStream.isVoiceMessage;
}

- (UIColor *)audioMaximumTrackTintColor
{
    return Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x5E6673] : [UIColor colorWithRGBHex:0xEAECEF];
}

- (void)createContents
{
    self.axis = UILayoutConstraintAxisVertical;
    self.alignment = UIStackViewAlignmentFill;
    self.spacing = 0;
    self.layoutMarginsRelativeArrangement = YES;
    
    // 文件名部分
    if ([_attachmentStream isAudio] && !_attachmentStream.isVoiceMessage) {
        self.voiceAttachmentLabel.text = self.attachmentStream.sourceFilename;
        UIStackView *filenameStack = [[UIStackView alloc] init];
        filenameStack.axis = UILayoutConstraintAxisHorizontal;
        filenameStack.alignment = UIStackViewAlignmentLeading;
        filenameStack.spacing = 6;
        filenameStack.distribution = UIStackViewDistributionFill;
        filenameStack.translatesAutoresizingMaskIntoConstraints = NO;

        // 添加图片和文本
        [filenameStack addArrangedSubview:self.voiceAttachmentImageView];
        [filenameStack addArrangedSubview:self.voiceAttachmentLabel];

        // 添加一个 spacer 占据剩余空间，强制左对齐
        UIView *spacer = [[UIView alloc] init];
        [spacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [spacer setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [filenameStack addArrangedSubview:spacer];

        // 设置 label 不拉伸
        [self.voiceAttachmentLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self.voiceAttachmentLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        // 添加到主 vertical stack 中
        [self addArrangedSubview:filenameStack];
    }
    
    UIStackView *audioStack = [[UIStackView alloc] init];
    audioStack.axis = UILayoutConstraintAxisHorizontal;
    audioStack.alignment = UIStackViewAlignmentCenter;
    audioStack.spacing = self.hSpacing;
    audioStack.translatesAutoresizingMaskIntoConstraints = NO;
    audioStack.layoutMarginsRelativeArrangement = YES;
    
    _audioPlayPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.audioPlayPauseButton.enabled = NO;
    [audioStack addArrangedSubview:self.audioPlayPauseButton];
    [self.audioPlayPauseButton autoSetDimensionsToSize:CGSizeMake(self.iconSize, self.iconSize)];
    [self.audioPlayPauseButton setContentHuggingHigh];

    // TODO: audio wave async
    NSError *error;
    AudioWaveform *waveform = nil;
    if (self.attachmentStream.decibelSamples.count >= 10) {
        waveform = [[AudioWaveform alloc] initWithDecibelSamples:self.attachmentStream.decibelSamples];
    } else {
        if(self.attachmentStream.isVoiceMessage){
            [OWSAttachmentsProcessor decryptVoiceAttachment:self.attachmentStream];
        }
        waveform = [AudioWaveformManagerImpl.shared audioWaveformSyncForAudioPath:[self.attachmentStream filePath] error:&error];
        OWSLogInfo(@"get attachmentStream file path: %@", [self.attachmentStream filePath]);
        OWSLogInfo(@"get attachmentStream file byteCount: %d", [self.attachmentStream byteCount]);
        if (error) {
            OWSLogError(@"voice draw error:%@.", error);
        }
        if(self.attachmentStream.isVoiceMessage){
            [self.attachmentStream removeVoicePlaintextFile];
        }
    }
    AudioWaveformProgressView *audioProgressView = [[AudioWaveformProgressView alloc] initWithWaveform:waveform];

    self.audioProgressView = audioProgressView;
    audioProgressView.cachedAudioDuration = self.audioDurationSeconds;
    [self updateAudioProgressView];

    [audioProgressView autoSetDimension:ALDimensionHeight toSize:[OWSAudioMessageView audioProgressViewHeight]];
    [audioProgressView autoSetDimension:ALDimensionWidth toSize:[OWSAudioMessageView audioProgressViewWidth]];
    [audioStack addArrangedSubview:audioProgressView];
    
    UILabel *timeLabel = [UILabel new];
    self.audioBottomLabel = timeLabel;

    [self updateAudioBottomLabel];
    timeLabel.textColor = self.isIncoming ? ConversationStyle.bubbleTextColorIncoming : ConversationStyle.bubbleTextColorOutgoing;
    timeLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    timeLabel.textAlignment = NSTextAlignmentCenter;
    timeLabel.font = [OWSAudioMessageView labelFont];
    [timeLabel autoSetDimensionsToSize:CGSizeMake(40, 20)];
    [audioStack addArrangedSubview:timeLabel];
    
    [self addArrangedSubview:audioStack];

    [self updateContents];
}

+ (CGFloat)audioProgressViewHeight
{
    return 32.f;
}

+ (CGFloat)audioProgressViewWidth
{
    return 300;
}

+ (UIFont *)labelFont
{
    return [UIFont systemFontOfSize:14];
}

+ (CGFloat)labelHSpacing
{
    return 12.f;
}

- (UIImageView *)voiceAttachmentImageView {
    if (!_voiceAttachmentImageView) {
        _voiceAttachmentImageView = [[UIImageView alloc] init];
        _voiceAttachmentImageView.image = [UIImage imageNamed:@"voice_attachment_top_icon"];
        _voiceAttachmentImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    
    return _voiceAttachmentImageView;
}

- (UILabel *)voiceAttachmentLabel {
    if (!_voiceAttachmentLabel) {
        _voiceAttachmentLabel = [[UILabel alloc] init];
        _voiceAttachmentLabel.textColor = Theme.primaryTextColor;
        _voiceAttachmentLabel.font = [UIFont systemFontOfSize:14.f];
    }
    return _voiceAttachmentLabel;
}

@end

NS_ASSUME_NONNULL_END
