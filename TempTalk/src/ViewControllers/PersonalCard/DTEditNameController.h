//
//  DTPersonInfoController.h
//  Wea
//
//  Created by hornet on 2021/12/1.
//

#import <SignalMessaging/SignalMessaging.h>
// 通话类型
typedef NS_ENUM(NSInteger, DTPersonnalInfoType) {
    DTPersonnalCardTypeSelf_CanEdit,// 自己的名片可编辑
    DTPersonnalCardTypeSelf_NoneEdit,// 自己的名片无法编辑
    DTPersonnalCardTypeSelf_NoneEditWithPresentModel,// 自己的名片无法编辑
    DTPersonnalCardTypeOther,// 他人的名片
    
};


NS_ASSUME_NONNULL_BEGIN

@interface DTPersonInfoController : OWSViewController
- (void)configureWithRecipientId:(NSString *)recipientId;
@end

NS_ASSUME_NONNULL_END
