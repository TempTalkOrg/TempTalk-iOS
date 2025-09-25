//
//  DTTranslateMessage.h
//  TTServiceKit
//
//  Created by hornet on 2022/1/13.
//

#import <Mantle/Mantle.h>

typedef NS_ENUM(NSInteger, DTTranslateMessageStateType) {
    DTTranslateMessageStateTypeTranslating = 0,//0,翻译中
    DTTranslateMessageStateTypeSucessed = 1,// 1:成功
    DTTranslateMessageStateTypeFailed = 2,//2:翻译失败
};

NS_ASSUME_NONNULL_BEGIN

@interface DTTranslateMessage : MTLModel
@property (nonatomic,copy) NSString *translateTipMessage;//状态文案
@property (nonatomic,strong) NSNumber *translatedState;//0,翻译中 1:成功 2:翻译失败 DTTranslateMessageStateType
@property (nonatomic,strong) NSNumber *translatedType;//翻译的结果的类型 DTTranslateMessageType
@property (nonatomic,copy) NSString *tranEngLishResult;//翻译成英语的结果
@property (nonatomic,copy) NSString *tranChinseResult;//翻译成中文的结果
@property (nonatomic,strong) NSString *tranCurrentLanguageResult;//翻译成当前系统语言的结果
@property (nonatomic, assign) uint32_t cardVersion;//卡片消息版本号
@end

NS_ASSUME_NONNULL_END
