//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OWSSearchBarStyle) { OWSSearchBarStyle_Default, OWSSearchBarStyle_SecondaryBar };

@interface OWSSearchBar : UISearchBar

@property (nonatomic, strong) NSString *customPlaceholder;

- (instancetype)initWithShowsCancel:(BOOL)showsCancel;

/// 初始化方法
/// - Parameters:
///   - showsCancel: 是否展示cancel
///   - edgeInset: 边距    ⚠️⚠️⚠️暂时只支持修改输入框距离左侧和右侧的边距
- (instancetype)initWithShowsCancel:(BOOL)showsCancel edgeInset:(UIEdgeInsets) edgeInset;
- (void)applyTheme;

@end

NS_ASSUME_NONNULL_END
