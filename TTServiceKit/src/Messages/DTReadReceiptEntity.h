//
//  DTReadReceiptEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/30.
//

#import <Mantle/Mantle.h>
#import "TSConstants.h"
#import "TSMessageMacro.h"

NS_ASSUME_NONNULL_BEGIN

@class DTReadPositionEntity;

@interface DTReadReceiptEntity : MTLModel

@property (nonatomic, strong) NSMutableSet<NSNumber *> *timestamps;

@property (nonatomic, assign) TSWhisperMessageType whisperMessageType;

@property (nonatomic, strong) DTReadPositionEntity *readPosition;

@property (nonatomic, copy) NSString *associatedUniqueThreadId;

@property (nonatomic, assign) TSMessageModeType messageModeType;

@end

NS_ASSUME_NONNULL_END
