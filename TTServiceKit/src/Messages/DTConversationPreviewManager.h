//
//  DTConversationPreviewManager.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/8/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SDSAnyWriteTransaction;
@class TSThread;
@class DSKProtoConversationPreview;

@interface DTConversationPreviewManager : NSObject

@property (nonatomic, assign) BOOL needReportConversation;
@property (nonatomic, strong, nullable) TSThread *currentThread;

+ (instancetype)sharedManager;

- (void)processConversationPreviewProto:(DSKProtoConversationPreview *)conversationPreviewProto
                            transaction:(SDSAnyWriteTransaction *)writeTransaction;

- (void)reportConversationWithThread:(nullable TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
