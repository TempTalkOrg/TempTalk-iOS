//
//  DTTransLateTool.h
//  TempTalk
//
//  Created by Henry on 2025/3/6.
//  Copyright © 2025 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>
@import TTServiceKit;

typedef void (^Callback)(NSString *response);

NS_ASSUME_NONNULL_BEGIN

@interface DTTransLateTool : NSObject

- (void)translateWithContent:(NSString *)content
                        type:(DTTranslateMessageType)type
                    callback:(Callback)callback;

@end

NS_ASSUME_NONNULL_END
