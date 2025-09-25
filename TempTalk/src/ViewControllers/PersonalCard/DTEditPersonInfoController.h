//
//  DTEditPersonInfoController.h
//  Wea
//
//  Created by hornet on 2021/12/1.
//

#import <TTMessaging/TTMessaging.h>
// 通话类型
typedef NS_ENUM(NSInteger, DTEditPersonInfoType) {
    DTEditPersonInfoTypeName,// 编辑名字
    DTEditPersonInfoTypeSignature,// 编辑签名
};

extern NSUInteger const kDTUserNameMaxLength;
extern NSUInteger const kDTUserSignatureLength;

NS_ASSUME_NONNULL_BEGIN

@interface DTEditPersonInfoController : OWSViewController
- (void)configureWithRecipientId:(NSString *)recipientId withType:(DTEditPersonInfoType)edittype defaultEditText:(NSString *)editText;
@end

NS_ASSUME_NONNULL_END
