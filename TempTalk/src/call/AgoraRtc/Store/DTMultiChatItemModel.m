//
//  DTMultiChatItemModel.m
//  Signal
//
//  Created by Felix on 2021/8/5.
//

#import "DTMultiChatItemModel.h"
#import <TTServiceKit/NSString+SSK.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSContactAvatarBuilder.h>
#import <TTMessaging/Environment.h>
#import <TTServiceKit/DTCallManager.h>

@implementation DTMultiChatItemModel

+ (instancetype)itemWithAccount:(NSString* _Nullable)account
                            uid:(NSUInteger)uid {
    DTMultiChatItemModel* chatItemModel = [[DTMultiChatItemModel alloc] init];

    chatItemModel.account = account;
    
    if (uid) {
        chatItemModel.uid = uid;
    }
    
    chatItemModel.mute = YES;
    chatItemModel.isSwithCamera = YES;
    return chatItemModel;
}

- (void)setAccount:(NSString *)account {
    if (account && account.length > 0) {
        _account = account;
        
        if ([account hasPrefix:MeetingAccoutPrefix_Web]) {
            _displayName = [account getWebUserName];
            _recipientId = account;
        } else {
            NSString *recipientId = [account transforUserAccountToCallNumber];
            _recipientId = recipientId;
            OWSContactsManager *contactManager = Environment.shared.contactsManager;
            _displayName = [contactManager displayNameForPhoneIdentifier:recipientId];
            if ([_displayName isEqualToString:recipientId]) {
                [[DTCallManager sharedInstance] getMeetingUserNameByUid:recipientId success:^(NSString * _Nonnull name) {
                    self->_displayName = name;
                    [[[OWSContactAvatarBuilder alloc] initWithSignalId:recipientId name:name diameter:48 contactsManager:contactManager] buildDefaultImageForSave];
                } failure:^(NSError * _Nonnull error) {
                    OWSLogError(@"[MeetingCell] get user name error: %@", error.localizedDescription);
                }];
            }
        }
    } else {
        _displayName = @"Unknown";
    }
}


- (void)resetStatusForLeft {
    self.inChannel = NO;
    self.mute = YES;
    self.videoEnable = NO;
    self.firstFrameDecoded = NO;
    self.speaking = NO;
    self.isSwithCamera = NO;
    self.sharing = NO;
    self.host = NO;
}

- (void)combieFromItemModel:(DTMultiChatItemModel *)itemModel {
    if (itemModel) {
        self.inChannel = itemModel.isInChannel;
        self.mute = itemModel.isMute;
        self.videoEnable = itemModel.isVideoEnable;
        self.firstFrameDecoded = itemModel.isFirstFrameDecoded;
        self.speaking = itemModel.isSpeaking;
        self.isSwithCamera = itemModel.isSwithCamera;
        self.sharing = itemModel.isSharing;
        self.host = itemModel.isHost;
    }
}

- (void)setVideoEnable:(BOOL)videoEnable {
    _videoEnable = videoEnable;
    if (!videoEnable) {
        
    }
}

@end
