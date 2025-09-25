//
//  DTAddToGroupItem.m
//  Wea
//
//  Created by hornet on 2022/1/1.
//

#import "DTAddToGroupItem.h"
#import <PureLayout/PureLayout.h>
#import <TTServiceKit/TSAccountManager.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/Environment.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import "OWSAvatarBuilder.h"
#import "TempTalk-Swift.h"

@interface DTAddToGroupItem()
@property(nonatomic,strong) DTAvatarImageView *iconImage;
@end

@implementation DTAddToGroupItem

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self creatSubViews];
        self.layer.cornerRadius = self.frame.size.height/2.0;
//        self.layer.masksToBounds = true;
    }
    return self;
}

- (void)creatSubViews {
    [self.contentView addSubview:self.iconImage];
    [self.iconImage autoPinEdgesToSuperviewEdges];
    [self.iconImage autoSetDimensionsToSize:CGSizeMake(self.frame.size.height/2.0, self.frame.size.height/2.0)];
}

- (void)configWithReceptId:(NSString *)receptId {
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    SignalAccount *account = [contactsManager signalAccountForRecipientId:receptId];
    [self.iconImage setImageWithAvatar:account.contact.avatar recipientId:receptId displayName:account.contactFullName completion:nil];
}
- (void)configWithImage:(nullable NSString *)imageName {
    if (!imageName) {
        self.iconImage.image = nil;
    }else {
        self.iconImage.image = [UIImage imageNamed:imageName];
    }
}

- (DTAvatarImageView *)iconImage {
    if (!_iconImage ) {
        _iconImage = [DTAvatarImageView new];
        _iconImage.imageForSelfType = DTAvatarImageForSelfTypeOriginal;
    }
    return _iconImage;
}

@end
