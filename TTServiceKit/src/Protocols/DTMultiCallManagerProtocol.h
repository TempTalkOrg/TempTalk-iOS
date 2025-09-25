//
//  DTMultiCallManagerProtocol.h
//  Pods
//
//  Created by Ethan on 01/10/2024.
//

#import "DTMeetingConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DTMultiCallManagerProtocol <NSObject>

- (DTMeetingStatus)getCurrentMeetingStatus;

@end

NS_ASSUME_NONNULL_END
