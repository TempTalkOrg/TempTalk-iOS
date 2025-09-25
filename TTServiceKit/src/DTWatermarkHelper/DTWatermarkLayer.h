//
//  DTWatermarkLayer.h
//  TTServiceKit
//
//  Created by hornet on 2021/11/24.
//

#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTWatermarkLayer : CALayer

- (instancetype)initWithFrame:(CGRect)frame LayeString:(NSString *) message;
@end

NS_ASSUME_NONNULL_END
