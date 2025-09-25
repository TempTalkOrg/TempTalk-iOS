//
//  DTTranslateApi.h
//  Wea
//
//  Created by hornet on 2022/1/13.
//

#import "DTBaseAPI.h"
#import "DTTranslateProcessor.h"

@class TSMessage;
NS_ASSUME_NONNULL_BEGIN

//{
//            "translatedText": "hello, who is your father",
//            "sourceText": "你好，你爸爸是谁",
//            "sourceLanguage": "zh-CN"
//        }
@interface DTTranslateSingleEntity : MTLModel <MTLJSONSerializing>
@property (nonatomic, copy) NSString * translatedText;//翻译的结果
//@property (nonatomic, copy) NSString * sourceText;//源文字
@property (nonatomic, copy) NSString * sourceLanguage;//源语言
@end


@interface DTTranslateEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger ver;

@property (nonatomic, assign) NSInteger status;

@property (nonatomic, copy) NSString *reason;

@property (nonatomic, strong) DTTranslateSingleEntity *data;

@end


typedef void (^DTTranslateSuccessBlock)(DTTranslateEntity *entity);
typedef void (^DTTranslateFailureBlock)(NSError *error);

typedef enum : NSUInteger {
    DTTranslateMsgSourceUnknown,
    DTTranslateMsgSource1On1,
    DTTranslateMsgSourceGroup,
    DTTranslateMsgSourceAnnouncement,
    DTTranslateMsgSourceNormalBot
} DTTranslateMsgSource;

@interface DTTranslateApi : DTBaseAPI

- (void)sendRequestWithSourceLang:(nullable NSString *)sourceLang
                       targetLang:(DTTranslateMessageType)type
                         contents:(NSString *)contents
                           thread:(TSThread *)thread
                     attachmentId:(NSString *)attachmentId
                          success:(DTTranslateSuccessBlock)success
                          failure:(DTTranslateFailureBlock)failure;
//通过message获取带翻译内容
- (NSString *)getTargetTranferContents:(TSMessage *)message;

@end

NS_ASSUME_NONNULL_END
