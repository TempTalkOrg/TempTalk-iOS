//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAudioPlayer.h"
#import "TSAttachmentStream.h"
#import <AVFoundation/AVFoundation.h>
#import <TTMessaging/TTMessaging-Swift.h>
#import <TTServiceKit/NSTimer+OWS.h>

NS_ASSUME_NONNULL_BEGIN

// A no-op delegate implementation to be used when we don't need a delegate.
@interface OWSAudioPlayerDelegateStub : NSObject <OWSAudioPlayerDelegate>

@property (nonatomic) AudioPlaybackState audioPlaybackState;

@end

#pragma mark -

@implementation OWSAudioPlayerDelegateStub

- (void)setAudioProgress:(CGFloat)progress duration:(CGFloat)duration
{
    // Do nothing;
}

@end

#pragma mark -

@interface OWSAudioPlayer () <AVAudioPlayerDelegate>

@property (nonatomic, readonly) NSURL *mediaUrl;
@property (nonatomic, nullable) AVAudioPlayer *audioPlayer;
@property (nonatomic, nullable) NSTimer *audioPlayerPoller;
@property (nonatomic, readonly) OWSAudioActivity *audioActivity;

@end

#pragma mark -

@implementation OWSAudioPlayer

- (instancetype)initWithMediaUrl:(NSURL *)mediaUrl
{
    return [self initWithMediaUrl:mediaUrl delegate:[OWSAudioPlayerDelegateStub new]];
}

- (instancetype)initWithMediaUrl:(NSURL *)mediaUrl delegate:(id<OWSAudioPlayerDelegate>)delegate
{
    self = [super init];
    if (!self) {
        return self;
    }

    OWSAssertDebug(mediaUrl);
    OWSAssertDebug(delegate);

    _delegate = delegate;
    _mediaUrl = mediaUrl;

    NSString *audioActivityDescription = [NSString stringWithFormat:@"%@ %@", self.logTag, self.mediaUrl];
    _audioActivity = [[OWSAudioActivity alloc] initWithAudioDescription:audioActivityDescription];

    // 如果是 call，退后台，不停止铃声
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:OWSApplicationDidEnterBackgroundNotification
                                               object:nil];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [DeviceSleepManager.shared removeBlockWithBlockObject:self];

    [self stop];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    if (!OWSAudioSession.shared.inCalling) {
        
        [self stop];
    }
}

#pragma mark - Methods

- (void)playWithCurrentAudioCategory
{
    OWSAssertIsOnMainThread();
    [OWSAudioSession.shared startAudioActivity:self.audioActivity];

    [self play];
}

- (void)playWithPlaybackAudioCategory
{
    OWSAssertIsOnMainThread();
    [OWSAudioSession.shared startPlaybackAudioActivity:self.audioActivity];

    [self play];
}

- (void)playWithPlayAndRecordAudioCategory
{
    OWSAssertIsOnMainThread();
    [OWSAudioSession.shared startPlayAndRecordAudioActivity:self.audioActivity];

    [self play];
}

- (void)play
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.mediaUrl);
    OWSAssertDebug([self.delegate audioPlaybackState] != AudioPlaybackState_Playing);

    [self.audioPlayerPoller invalidate];

    self.delegate.audioPlaybackState = AudioPlaybackState_Preparing;
    
    if (!self.audioPlayer) {
        NSError *error;
        self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.mediaUrl error:&error];
        if (error) {
            OWSLogError(@"%@ [audio] error: %@", self.logTag, error);
            [self stop];

            if ([error.domain isEqualToString:NSOSStatusErrorDomain]
                && (error.code == kAudioFileInvalidFileError || error.code == kAudioFileStreamError_InvalidFile)) {
                [OWSAlerts
                    showErrorAlertWithMessage:Localized(@"INVALID_AUDIO_FILE_ALERT_ERROR_MESSAGE",
                                                  @"Message for the alert indicating that an audio file is invalid.")];
            }

            return;
        }
        self.audioPlayer.delegate = self;
        if (self.isLooping) {
            self.audioPlayer.numberOfLoops = -1;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.audioPlayer play];
    });

    OWSLogDebug(@"%@ [audio] play", self.logTag);

    [self.audioPlayerPoller invalidate];
    self.audioPlayerPoller = [NSTimer weakScheduledTimerWithTimeInterval:.05f
                                                                  target:self
                                                                selector:@selector(audioPlayerUpdated:)
                                                                userInfo:nil
                                                                 repeats:YES];

    // Prevent device from sleeping while playing audio.
    [DeviceSleepManager.shared addBlockWithBlockObject:self];
}

- (void)pause
{
    OWSAssertIsOnMainThread();

    self.delegate.audioPlaybackState = AudioPlaybackState_Paused;
    [self.audioPlayer pause];
    [self.audioPlayerPoller invalidate];
    [self.delegate setAudioProgress:[self.audioPlayer currentTime] duration:[self.audioPlayer duration]];

    [OWSAudioSession.shared endAudioActivity:self.audioActivity force:NO];
    [DeviceSleepManager.shared removeBlockWithBlockObject:self];
}

- (void)stop
{
    OWSAssertIsOnMainThread();

    self.delegate.audioPlaybackState = AudioPlaybackState_Stopped;
    [self.audioPlayer pause];
    [self.audioPlayerPoller invalidate];
    [self.delegate setAudioProgress:0 duration:0];

    [OWSAudioSession.shared endAudioActivity:self.audioActivity force:NO];
    [DeviceSleepManager.shared removeBlockWithBlockObject:self];
}

- (void)togglePlayState
{
    OWSAssertIsOnMainThread();

    if (self.delegate.audioPlaybackState == AudioPlaybackState_Preparing) {
        OWSLogDebug(@"[audio] preparing");
    } else if (self.delegate.audioPlaybackState == AudioPlaybackState_Playing) {
        OWSLogDebug(@"[audio] pause");
        [self pause];
    } else {
        OWSLogDebug(@"[audio] play");
        [self play];
    }
}

#pragma mark - Events

- (void)audioPlayerUpdated:(NSTimer *)timer
{
    OWSAssertIsOnMainThread();

    OWSAssertDebug(self.audioPlayer);
    OWSAssertDebug(self.audioPlayerPoller);

    self.delegate.audioPlaybackState = AudioPlaybackState_Playing;
    
//    OWSLogDebug(@"[voice] c: %f, d: %f.", self.audioPlayer.currentTime, self.audioPlayer.duration);
    
    [self.delegate setAudioProgress:[self.audioPlayer currentTime] duration:[self.audioPlayer duration]];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    OWSAssertIsOnMainThread();

    [self stop];
}

- (void)setVolume:(float)volume {
    
    if (!self.audioPlayer) return;
    self.audioPlayer.volume = volume;
}

@end

NS_ASSUME_NONNULL_END
