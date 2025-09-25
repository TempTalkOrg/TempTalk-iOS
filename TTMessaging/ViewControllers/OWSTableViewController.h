//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <TTMessaging/OWSViewController.h>

NS_ASSUME_NONNULL_BEGIN

extern const CGFloat kOWSTable_DefaultCellHeight;

@class OWSTableItem;
@class OWSTableSection;

@interface OWSTableContents : NSObject

@property (nonatomic) NSString *title;
@property (nonatomic, nullable) NSInteger (^sectionForSectionIndexTitleBlock)(NSString *title, NSInteger index);
@property (nonatomic, nullable) NSArray<NSString *> * (^sectionIndexTitlesForTableViewBlock)(void);

@property (nonatomic, readonly) NSArray<OWSTableSection *> *sections;
- (void)addSection:(OWSTableSection *)section;

@end

#pragma mark -

@interface OWSTableSection : NSObject

@property (nonatomic, nullable) NSString *headerTitle;
@property (nonatomic, nullable) NSString *footerTitle;

@property (nonatomic, nullable) NSAttributedString *headerAttributedTitle;
@property (nonatomic, nullable) NSAttributedString *footerAttributedTitle;

@property (nonatomic, nullable) UIView *customHeaderView;
@property (nonatomic, nullable) UIView *customFooterView;
@property (nonatomic, nullable) NSNumber *customHeaderHeight;
@property (nonatomic, nullable) NSNumber *customFooterHeight;

+ (OWSTableSection *)sectionWithTitle:(nullable NSString *)title items:(NSArray<OWSTableItem *> *)items;

- (void)addItem:(OWSTableItem *)item;
- (void)addTableItems:(NSArray <OWSTableItem *> *)tableItems;

- (NSUInteger)itemCount;

@end

#pragma mark -
typedef void (^OWSTableActionWithIndexPathBlock)(NSIndexPath *);
typedef void (^OWSTableActionBlock)(void);
typedef void (^OWSTableSubPageBlock)(UIViewController *viewController);
typedef UITableViewCell *_Nonnull (^OWSTableCustomCellBlock)(void);
//typedef void (^OWSTableMoveActionBlock)(NSIndexPath *sourceIndexPath, NSIndexPath *destinationIndexPath);

@interface OWSTableItem : NSObject

@property (nonatomic, weak) UIViewController *tableViewController;

@property (nonatomic, assign) BOOL canEdit;
@property (nonatomic, assign) BOOL canMove;

+ (UIFont *)textLabelFont;

+ (UITableViewCell *)newCell;

+ (UITableViewCell *)newCellWithBackgroundColor:(UIColor *)backgroundColor;

+ (OWSTableItem *)itemWithTitle:(NSString *)title actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)blankItemWithcustomRowHeight:(CGFloat)customRowHeight;

+ (OWSTableItem *)blankItemWithcustomRowHeight:(CGFloat)customRowHeight backgroundColor:(UIColor *)backgroundColor;

+ (OWSTableItem *)itemWithCustomCell:(UITableViewCell *)customCell
                     customRowHeight:(CGFloat)customRowHeight
                         actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                              actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              detailText:(NSString *)detailText
                             actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                         customRowHeight:(CGFloat)customRowHeight
                             actionBlock:(nullable OWSTableActionBlock)actionBlock;
+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              detailText:(NSString *)detailText
                         customRowHeight:(CGFloat)customRowHeight
                           accessoryType:(UITableViewCellAccessoryType)accessoryType
                             actionBlock:(nullable OWSTableActionBlock)actionBlock;

//详情文字略局中展示
+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              centerDetailText:(NSString *)detailText
                         customRowHeight:(CGFloat)customRowHeight
                           accessoryType:(UITableViewCellAccessoryType)accessoryType
                             actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)checkmarkItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)checkmarkItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)itemWithText:(NSString *)text
                   actionBlock:(nullable OWSTableActionBlock)actionBlock
                 accessoryType:(UITableViewCellAccessoryType)accessoryType;

+ (OWSTableItem *)itemHasSepline:(BOOL)hasSepline
                            text:(NSString *)text
                     actionBlock:(nullable OWSTableActionBlock)actionBlock
                   accessoryType:(UITableViewCellAccessoryType)accessoryType;

+ (OWSTableItem *)subPageItemWithText:(NSString *)text actionBlock:(nullable OWSTableSubPageBlock)actionBlock;

+ (OWSTableItem *)subPageItemWithText:(NSString *)text
                      customRowHeight:(CGFloat)customRowHeight
                          actionBlock:(nullable OWSTableSubPageBlock)actionBlock;

+ (OWSTableItem *)actionItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)actionItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)actionItemWithText:(NSString *)text additionalText:(NSString *)additionalText customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock;

+ (OWSTableItem *)softCenterLabelItemWithText:(NSString *)text;

+ (OWSTableItem *)softCenterLabelItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight;

+ (OWSTableItem *)labelItemWithText:(NSString *)text;

+ (OWSTableItem *)labelItemWithText:(NSString *)text accessoryText:(NSString *)accessoryText;

+ (OWSTableItem *)switchItemWithText:(NSString *)text isOn:(BOOL)isOn target:(id)target selector:(SEL)selector;

+ (OWSTableItem *)switchItemWithText:(NSString *)text
                                isOn:(BOOL)isOn
                           isEnabled:(BOOL)isEnabled
                              target:(id)target
                            selector:(SEL)selector;

+ (OWSTableItem *)switchOnlyDisplayItemWithText:(NSString *)text
                                           isOn:(BOOL)isOn
                                         target:(id)target
                                       selector:(SEL)selector;

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionBlock:(nullable OWSTableActionBlock)actionBlock
                      deselectActionBlock:(nullable OWSTableActionBlock)deselectActionBlock;

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionWithIndexPathBlock:(nullable OWSTableActionWithIndexPathBlock)actionBlock
                      deselectActionWithIndexPathBlock:(nullable OWSTableActionWithIndexPathBlock)deselectActionBlock;

+ (OWSTableItem *)itemCustomAccessoryWithText:(NSString *)text
                                  actionBlock:(nullable OWSTableActionBlock)actionBlock;
- (nullable UITableViewCell *)customCell;
- (NSNumber *)customRowHeight;

+ (void)configureCell:(UITableViewCell *)cell;

@end

#pragma mark -

@protocol OWSTableViewControllerDelegate <NSObject>

// ⚠️: 代理方法不能和系统代理方法重名，会造成循环引用

@optional
- (void)tableViewWillBeginDragging;

- (void)tableViewDidScroll:(UITableView *)tableView;

- (void)tableViewDidRenderCompleteWithTableView:(UITableView *)tableView;

- (void)tableViewDidEndDecelerating:(UITableView *)tableView;

- (void)tableViewDidEndDragging:(UITableView *)scrollView willDecelerate:(BOOL)decelerate;

- (void)originalTableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

- (void)originalTableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)originalTableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

//MARK: swipeAction
- (nullable UISwipeActionsConfiguration *)_tableView:(UITableView *)tableView
 trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UISwipeActionsConfiguration *)_tableView:(UITableView *)tableView
 leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath;

@end

#pragma mark -

@interface OWSTableViewController : OWSViewController

@property (nonatomic, weak) id<OWSTableViewControllerDelegate> delegate;

@property (nonatomic) OWSTableContents *contents;
@property (nonatomic, readonly) UITableView *tableView;

@property (nonatomic) UITableViewStyle tableViewStyle;

/*
 Both properties are for the entire tableView, which defaults to NO. If you need to be for section, set NO and the section's canEdit / canMove property to YES
 */
@property (nonatomic) BOOL canEditRow;
@property (nonatomic) BOOL canMoveRow;

/// 重写tableView布局，初始化页面时赋值才生效
@property (nonatomic) BOOL customTableConstraints;

@property (nonatomic, getter=isMaxSelected) BOOL maxSelected;

#pragma mark - Presentation

- (void)presentFromViewController:(UIViewController *)fromViewController;

- (UITableViewCell *)cellWithName:(NSString *)name
                       isSwitchOn:(BOOL)isOn
                     switchAction:(SEL)selector;

- (UITableViewCell *)cellWithName:(NSString *)name
                         subviews:(nullable NSArray <__kindof UIView *> *)subviews
                       isSwitchOn:(BOOL)isOn
                     switchAction:(SEL)selector;

@end

NS_ASSUME_NONNULL_END
