//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageTextView : UITextView

@property (nonatomic) BOOL shouldIgnoreEvents;
@property (nonatomic) BOOL couldBecomeFirstResponder;
@property (nonatomic) BOOL disableSystemMenu;

@end

NS_ASSUME_NONNULL_END
