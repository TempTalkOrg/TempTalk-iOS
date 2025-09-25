//
//  DTTransLateTool.m
//  TempTalk
//
//  Created by Henry on 2025/3/6.
//  Copyright © 2025 Difft. All rights reserved.
//

#import "DTTransLateTool.h"
@import MLKit;

@interface DTTransLateTool()

@property(nonatomic, strong) MLKTranslator *translator;
@property(nonatomic, strong) MLKLanguageIdentification *languageId;

@end

@implementation DTTransLateTool
- (void)translateWithContent:(NSString *)content
                        type:(DTTranslateMessageType)type
                    callback:(Callback)callback {
    MLKTranslateRemoteModel *chineseModel = [MLKTranslateRemoteModel translateRemoteModelWithLanguage: MLKTranslateLanguageChinese];
    MLKTranslateRemoteModel *englishModel = [MLKTranslateRemoteModel translateRemoteModelWithLanguage: MLKTranslateLanguageEnglish];
    MLKModelManager *modelManager = [MLKModelManager modelManager];
    MLKModelDownloadConditions *conditions =
        [[MLKModelDownloadConditions alloc] initWithAllowsCellularAccess:YES
                                             allowsBackgroundDownloading:YES];
    if (![modelManager isModelDownloaded:chineseModel]) {
        [modelManager downloadModel:chineseModel conditions:conditions];
    }
    
    if (![modelManager isModelDownloaded:englishModel]) {
        [modelManager downloadModel:englishModel conditions:conditions];
    }
    
    self.languageId = [MLKLanguageIdentification languageIdentification];
    [self.languageId identifyLanguageForText:content completion:^(NSString * _Nullable languageTag, NSError * _Nullable error) {
        DTTranslateMessageType contentType = DTTranslateMessageTypeEnglish;
        if ([languageTag isEqualToString:@"en"]) {
            contentType = DTTranslateMessageTypeEnglish;
        } else if ([languageTag isEqualToString:@"zh"]){
            contentType = DTTranslateMessageTypeChinese;
        } else {
            contentType = DTTranslateMessageTypeEnglish;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (type == DTTranslateMessageTypeChinese &&
                contentType == DTTranslateMessageTypeEnglish) {
                
                MLKTranslatorOptions *options = [[MLKTranslatorOptions alloc] initWithSourceLanguage:MLKTranslateLanguageEnglish
                                                                                      targetLanguage:MLKTranslateLanguageChinese];
                self.translator = [MLKTranslator translatorWithOptions:options];
                [self.translator translateText:content
                                    completion:^(NSString *_Nullable result, NSError *_Nullable error) {
                    if (callback){
                        callback(result);
                    }
                }];
            } else if (type == DTTranslateMessageTypeEnglish &&
                       contentType == DTTranslateMessageTypeChinese) {
                MLKTranslatorOptions *options = [[MLKTranslatorOptions alloc] initWithSourceLanguage:MLKTranslateLanguageChinese
                                                                                      targetLanguage:MLKTranslateLanguageEnglish];
                self.translator = [MLKTranslator translatorWithOptions:options];
                [self.translator translateText:content
                                    completion:^(NSString *_Nullable result, NSError *_Nullable error) {
                    if (callback){
                        callback(result);
                    }
                }];
            } else {
                if (callback){
                    callback(content);
                }
            }
        });
    }];
}

@end
