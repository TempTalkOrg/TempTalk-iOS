//
//  TSPinOutgoingMessage.h
//  TTServiceKit
//
//  Created by Ethan on 2022/3/31.
//

#import "TSOutgoingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface TSPinOutgoingMessage : TSOutgoingMessage

@property (nonatomic, readonly) NSString *source;
@property (nonatomic, strong) NSArray <TSMessage *> *pinMessages;

@end

NS_ASSUME_NONNULL_END
