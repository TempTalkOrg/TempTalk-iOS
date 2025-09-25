//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSSoundSettingsViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <SignalMessaging/OWSAudioPlayer.h>
#import <SignalMessaging/OWSSounds.h>
#import <SignalServiceKit/Localize_Swift.h>
#import <SignalServiceKit/SignalServiceKit-Swift.h>
#import <SignalServiceKit/OWSRequestFactory.h>
#import <SignalServiceKit/DTParamsBaseUtils.h>
#import <SignalServiceKit/TSConstants.h>
#import <SignalServiceKit/DTToastHelper.h>
#import <SignalServiceKit/TSAccountManager.h>
#import <SignalServiceKit/DTBaseAPI.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSSoundSettingsViewController ()

@property (nonatomic) BOOL isDirty;

@property (nonatomic) OWSSound currentSound;

@property (nonatomic, nullable) OWSAudioPlayer *audioPlayer;

@end

#pragma mark -

@implementation OWSSoundSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setTitle:Localized(@"SETTINGS_ITEM_NOTIFICATION_SOUND",
                       @"Label for settings view that allows user to change the notification sound.")];
    self.currentSound = (self.thread ? [OWSSounds notificationSoundForThread:self.thread] : [OWSSounds globalNotificationSound]);

    [self updateTableContents];
    
    [self updateNavigationItems];
    
#ifdef DEBUG
    
    [self fetchApnSound];
#endif
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateTableContents];
}

- (void)updateNavigationItems
{
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(cancelWasPressed:)];

    if (self.isDirty) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                          target:self
                                                          action:@selector(saveWasPressed:)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSTableContents *contents = [OWSTableContents new];

    __weak OWSSoundSettingsViewController *weakSelf = self;

    OWSTableSection *soundsSection = [OWSTableSection new];
    soundsSection.headerTitle = Localized(
        @"NOTIFICATIONS_SECTION_SOUNDS", @"Label for settings UI that allows user to change the notification sound.");

    NSArray<NSNumber *> *allSounds = [OWSSounds allNotificationSounds];
    for (NSNumber *nsValue in allSounds) {
        OWSSound sound = (OWSSound)nsValue.intValue;
        OWSTableItem *item;

        NSString *soundLabelText = ^{
            NSString *baseName = [OWSSounds displayNameForSound:sound];
            if (sound == OWSSound_Note) {
                NSString *noteStringFormat = Localized(@"SETTINGS_AUDIO_DEFAULT_TONE_LABEL_FORMAT",
                    @"Format string for the default 'Note' sound. Embeds the system {{sound name}}.");
                return [NSString stringWithFormat:noteStringFormat, baseName];
            } else {
                return [OWSSounds displayNameForSound:sound];
            }
        }();

        if (sound == self.currentSound) {
            item = [OWSTableItem checkmarkItemWithText:soundLabelText
                                           actionBlock:^{
                                               [weakSelf soundWasSelected:sound];
                                           }];
        } else {
            item = [OWSTableItem actionItemWithText:soundLabelText
                                        actionBlock:^{
                                            [weakSelf soundWasSelected:sound];
                                        }];
        }
        [soundsSection addItem:item];
    }

    [contents addSection:soundsSection];

    self.contents = contents;
}

#pragma mark - Events

- (void)soundWasSelected:(OWSSound)sound
{
    [self.audioPlayer stop];
    self.audioPlayer = [OWSSounds audioPlayerForSound:sound];
    // Suppress looping in this view.
    self.audioPlayer.isLooping = NO;
    [self.audioPlayer playWithPlaybackAudioCategory];

    if (self.currentSound == sound) {
        return;
    }

    self.currentSound = sound;
    self.isDirty = YES;
    [self updateTableContents];
    [self updateNavigationItems];
}

- (void)cancelWasPressed:(id)sender
{
    // TODO: Add "discard changes?" alert.
    [self.audioPlayer stop];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveWasPressed:(id)sender
{
    if (self.thread) {
        [OWSSounds setNotificationSound:self.currentSound forThread:self.thread];
    } else {
        
        // to server
        [self configApnSound];
    }

    [self.audioPlayer stop];
    [self.navigationController popViewControllerAnimated:true];
}

- (void)configApnSound {
    NSString *soundFilename = [OWSSounds filenameForSound:self.currentSound];
    
    if (!DTParamsUtils.validateString(soundFilename)) {
        
        [OWSSounds setGlobalNotificationSound:self.currentSound];
        soundFilename = @"";
    }
    
    [DTToastHelper svShow];
    
    @weakify(self)
    // TODO: refactor to requestApi class and combine with notificationManager syncIfNeeded
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:@{@"privateConfigs" : @{@"notificationSound" : soundFilename}}];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        
        @strongify(self)
        NSDictionary *responseJson = response.responseBodyJson;
        if (DTParamsUtils.validateDictionary(responseJson)) {
            
            NSError *error;
            DTAPIMetaEntity *entity = [MTLJSONAdapter modelOfClass:[DTAPIMetaEntity class]
                                                fromJSONDictionary:responseJson
                                                             error:&error];
            if (error) {
                
                OWSLogError(@"set apn sound fail: %@.", error);
                [DTToastHelper dismissWithInfo:@"Failed, please try again."];
                
            } else {
                
                if (entity.status == DTAPIRequestResponseStatusOK){
                    
                    OWSLogInfo(@"set apn sound success, current %@, response: %@.", soundFilename, response.responseBodyJson);
                    [OWSSounds setGlobalNotificationSound:self.currentSound];
                    [DTToastHelper dismiss];
                    [self.navigationController popViewControllerAnimated:YES];
                    
                } else{
                    
                    error = DTErrorWithCodeDescription(entity.status, entity.reason);
                    OWSLogError(@"set apn sound fail: %@.", error);
                    [DTToastHelper dismissWithInfo:@"Failed, please try again."];
                    
                }
            }
            
        } else {
            
            OWSLogError(@"set apn sound fail: response data error.");
            [DTToastHelper dismissWithInfo:@"Failed, please try again."];
            
        }
        
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        
        [DTToastHelper dismissWithInfo:@"Failed, please try again."];
        OWSLogError(@"%@ set apn sound fail: %@", self.logTag, error);
        
    }];
}

#ifdef DEBUG
- (void)fetchApnSound {
    @weakify(self)
    NSString *localNumber = [TSAccountManager localNumber];
    
    OWSRequestMaker *requestMaker = [[OWSRequestMaker alloc] initWithLabel:@"set apn sound" requestFactoryBlock:^TSRequest * _Nullable{
        return [OWSRequestFactory getV1ContactMessage:@[localNumber]];
    } udAuthFailureBlock:^{
        
    } websocketFailureBlock:^{
        
    }];
    
    requestMaker.makeRequestObjc.doneOn(dispatch_get_main_queue(), ^(OWSRequestMakerResult *result) {
        
        @strongify(self)
        [DTToastHelper dismiss];
        
        
        NSDictionary *resultJson = result.responseJson;
        [OWSSounds setGlobalNotificationSound:self.currentSound];
        
        OWSLogInfo(@"fetch apn sound success, current %@", resultJson);
    }).catch(^(NSError * _Nonnull error) {
        [DTToastHelper dismiss];
        OWSLogError(@"%@ set apn sound fail: %@", self.logTag, error.localizedDescription);
    });
}

#endif

@end

NS_ASSUME_NONNULL_END
