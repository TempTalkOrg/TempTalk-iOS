//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSTableViewController.h"
#import "Theme.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIView+SignalUI.h"
#import <TTMessaging/TTMessaging-Swift.h>

NS_ASSUME_NONNULL_BEGIN

const CGFloat kOWSTable_DefaultCellHeight = 52.f;

@interface OWSTableContents ()

@property (nonatomic) NSMutableArray<OWSTableSection *> *sections;

@end

#pragma mark -

@implementation OWSTableContents

- (instancetype)init
{
    if (self = [super init]) {
        _sections = [NSMutableArray new];
    }
    return self;
}

- (void)addSection:(OWSTableSection *)section
{
    OWSAssertDebug(section);

    [_sections addObject:section];
}

@end

#pragma mark -

@interface OWSTableSection ()

@property (nonatomic) NSMutableArray<OWSTableItem *> *items;

@end

#pragma mark -

@implementation OWSTableSection

+ (OWSTableSection *)sectionWithTitle:(nullable NSString *)title items:(NSArray<OWSTableItem *> *)items
{
    OWSTableSection *section = [OWSTableSection new];
    section.headerTitle = title;
    section.items = [items mutableCopy];
    return section;
}

- (instancetype)init
{
    if (self = [super init]) {
        _items = [NSMutableArray new];
    }
    return self;
}

- (void)addItem:(OWSTableItem *)item
{
    OWSAssertDebug(item);

    [_items addObject:item];
}

- (void)addTableItems:(NSArray <OWSTableItem *> *)tableItems {
    [_items addObjectsFromArray:tableItems];
}

- (NSUInteger)itemCount
{
    return _items.count;
}

@end

#pragma mark -

@interface OWSTableItem ()

@property (nonatomic, nullable) NSString *title;
@property (nonatomic, nullable) OWSTableActionBlock actionBlock;
@property (nonatomic, nullable) OWSTableActionWithIndexPathBlock actionWithIndexPathBlock;
@property (nonatomic, nullable) OWSTableActionBlock deselectActionBlock;
@property (nonatomic, nullable) OWSTableActionWithIndexPathBlock deselectActionWithIndexPathBlock;
@property (nonatomic) OWSTableCustomCellBlock customCellBlock;
@property (nonatomic) UITableViewCell *customCell;
@property (nonatomic) NSNumber *customRowHeight;

@end

#pragma mark -

@implementation OWSTableItem

+ (void)configureCell:(UITableViewCell *)cell
{
    UIView *selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView = selectedBackgroundView;
    cell.backgroundColor = Theme.backgroundColor;
    cell.selectedBackgroundView.backgroundColor = Theme.tableCell2SelectedBackgroundColor;
//    cell.multipleSelectionBackgroundView.backgroundColor = Theme.tableCell2MultiSelectedBackgroundColor;

    [self configureCellLabels:cell];
}

+ (void)configureCellLabels:(UITableViewCell *)cell
{
    cell.textLabel.font = self.textLabelFont;
    cell.textLabel.textColor = self.textLabelTextColor;
    cell.detailTextLabel.textColor = self.detailTextLabelTextColor;
    cell.detailTextLabel.font = self.detailTextLabelFont;
}

+ (UITableViewCell *)newCell
{
    return [self newCellWithBackgroundColor:Theme.tableSettingCellBackgroundColor];
}

+ (UITableViewCell *)newCellWithBackgroundColor:(UIColor *)backgroundColor
{
    UITableViewCell *cell = [UITableViewCell new];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = backgroundColor;
    cell.contentView.backgroundColor = backgroundColor;
    cell.textLabel.font = self.textLabelFont;
    cell.textLabel.textColor = self.textLabelTextColor;
    
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = [Theme.cellSelectedColor colorWithAlphaComponent:0.9];
    cell.selectedBackgroundView = selectedBackgroundView;
    return cell;
}


+ (OWSTableItem *)itemWithTitle:(NSString *)title actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(title.length > 0);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.title = title;
    return item;
}

+ (OWSTableItem *)blankItemWithcustomRowHeight:(CGFloat)customRowHeight {
    return [self blankItemWithcustomRowHeight:customRowHeight backgroundColor:Theme.isDarkThemeEnabled ? Theme.darkThemeBackgroundColor : [UIColor colorWithRGBHex:0xFAFAFA]];
}

+ (OWSTableItem *)blankItemWithcustomRowHeight:(CGFloat)customRowHeight backgroundColor:(UIColor *)backgroundColor {
    UITableViewCell *customCell = [UITableViewCell new];
    customCell.backgroundColor = backgroundColor;
    customCell.contentView.backgroundColor = backgroundColor;
    customCell.selectionStyle = UITableViewCellSelectionStyleNone;
    customCell.separatorInset = UIEdgeInsetsMake(0, 0, 0, kScreenWidth);
    
//    UIView *backgroudView = [UIView newAutoLayoutView];
//    backgroudView.backgroundColor = backgroundColor;
//    [customCell.contentView addSubview:backgroudView];
//    [backgroudView autoPinEdgesToSuperviewEdges];
    
    OWSTableItem *item = [OWSTableItem new];
    item.customCell = customCell;
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)itemWithCustomCell:(UITableViewCell *)customCell
                     customRowHeight:(CGFloat)customRowHeight
                         actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(customCell);
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCell = customCell;
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [self itemWithCustomCellBlock:customCellBlock actionBlock:actionBlock];
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                              actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(customCellBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = customCellBlock;
    return item;
}

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    return [self itemWithText:text actionBlock:actionBlock accessoryType:UITableViewCellAccessoryDisclosureIndicator];
}

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              detailText:(NSString *)detailText
                         customRowHeight:(CGFloat)customRowHeight
                           accessoryType:(UITableViewCellAccessoryType)accessoryType
                             actionBlock:(nullable OWSTableActionBlock)actionBlock {

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                       reuseIdentifier:@"UITableViewCellStyleValue1"];
        cell.textLabel.text = text;
        cell.textLabel.font = self.textLabelFont;
        cell.textLabel.textColor = self.textLabelTextColor;
        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.detailTextLabel.text = detailText;
        cell.detailTextLabel.textColor = self.detailTextLabelTextColor;
        cell.detailTextLabel.font = self.detailTextLabelFont;
        if (accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
            cell.accessoryView = self.accessoryArrow;
        } else {
            [cell setAccessoryType:accessoryType];
        }
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    };
    item.customRowHeight = @(customRowHeight);
    return item;
}
//详情文字略局中展示
+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              centerDetailText:(NSString *)detailText
                         customRowHeight:(CGFloat)customRowHeight
                           accessoryType:(UITableViewCellAccessoryType)accessoryType
                             actionBlock:(nullable OWSTableActionBlock)actionBlock {

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                       reuseIdentifier:@"UITableViewCellStyleValue1"];
        cell.textLabel.text = text;
        cell.textLabel.font = self.textLabelFont;
        cell.textLabel.textColor = self.textLabelTextColor;
        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UILabel *detailTextLabel = [UILabel new];
        detailTextLabel.font = self.detailTextLabelFont;
        detailTextLabel.textColor = self.detailTextLabelTextColor;
        detailTextLabel.text = detailText;
        detailTextLabel.textAlignment = NSTextAlignmentLeft;
        [cell.contentView addSubview:detailTextLabel];
        [detailTextLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:cell.contentView withOffset:107];
        [detailTextLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:cell.contentView withOffset:-25];
        [detailTextLabel autoVCenterInSuperview];
        
        [cell setAccessoryType:accessoryType];
        return cell;
    };
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)checkmarkItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    return [self itemWithText:text actionBlock:actionBlock accessoryType:UITableViewCellAccessoryCheckmark];
}

+ (OWSTableItem *)checkmarkItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    return [self itemWithText:text customRowHeight:customRowHeight actionBlock:actionBlock accessoryType:UITableViewCellAccessoryCheckmark];
}

+ (OWSTableItem *)itemWithText:(NSString *)text
                   actionBlock:(nullable OWSTableActionBlock)actionBlock
                 accessoryType:(UITableViewCellAccessoryType)accessoryType {
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        if (accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
            cell.accessoryView = self.accessoryArrow;
        } else {
            cell.accessoryType = accessoryType;
        }
        return cell;
    };
    return item;
}

+ (OWSTableItem *)itemWithText:(NSString *)text
               customRowHeight:(CGFloat)customRowHeight
                   actionBlock:(nullable OWSTableActionBlock)actionBlock
                 accessoryType:(UITableViewCellAccessoryType)accessoryType {
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        cell.accessoryType = accessoryType;
        return cell;
    };
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)itemCustomAccessoryWithText:(NSString *)text
                                  actionBlock:(nullable OWSTableActionBlock)actionBlock {
    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 7, 11.6)];
        imageView.image = [[UIImage imageNamed:@"cell_nav_icon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        imageView.tintColor = [UIColor colorWithRGBHex:0x58585B];
        cell.accessoryView = imageView;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)itemHasSepline:(BOOL)hasSepline
                            text:(NSString *)text
                     actionBlock:(nullable OWSTableActionBlock)actionBlock
                   accessoryType:(UITableViewCellAccessoryType)accessoryType {
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        cell.accessoryType = accessoryType;
        
        if (!hasSepline) {
            CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
            cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, screenWidth);
        }
        
        return cell;
    };
    return item;
}

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                         customRowHeight:(CGFloat)customRowHeight
                             actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [self disclosureItemWithText:text actionBlock:actionBlock];
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)disclosureItemWithText:(NSString *)text
                              detailText:(NSString *)detailText
                             actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                                       reuseIdentifier:@"UITableViewCellStyleValue1"];
        cell.textLabel.text = text;
        cell.textLabel.font = self.textLabelFont;
        cell.textLabel.textColor = self.textLabelTextColor;
        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
        cell.detailTextLabel.text = detailText;
        cell.detailTextLabel.font = self.detailTextLabelFont;
        cell.detailTextLabel.textColor = self.detailTextLabelTextColor;
        cell.accessoryView = self.accessoryArrow;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        return cell;
    };
    return item;
}

+ (OWSTableItem *)subPageItemWithText:(NSString *)text actionBlock:(nullable OWSTableSubPageBlock)actionBlock
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    __weak OWSTableItem *weakItem = item;
    item.actionBlock = ^{
        OWSTableItem *strongItem = weakItem;
        OWSAssertDebug(strongItem);
        OWSAssertDebug(strongItem.tableViewController);

        if (actionBlock) {
            actionBlock(strongItem.tableViewController);
        }
    };
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        cell.accessoryView = self.accessoryArrow;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)subPageItemWithText:(NSString *)text
                      customRowHeight:(CGFloat)customRowHeight
                          actionBlock:(nullable OWSTableSubPageBlock)actionBlock
{
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [self subPageItemWithText:text actionBlock:actionBlock];
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)actionItemWithText:(NSString *)text actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)actionItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        return cell;
    };
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)actionItemWithText:(NSString *)text additionalText:(NSString *)additionalText customRowHeight:(CGFloat)customRowHeight actionBlock:(nullable OWSTableActionBlock)actionBlock
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(actionBlock);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        
        UILabel *detailTextLabel = [UILabel new];
        detailTextLabel.font = self.detailTextLabelFont;
        detailTextLabel.textColor = self.detailTextLabelTextColor;
        detailTextLabel.text = additionalText;
        detailTextLabel.textAlignment = NSTextAlignmentLeft;
        [cell.contentView addSubview:detailTextLabel];
        [detailTextLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:cell.contentView withOffset:107];
        [detailTextLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:cell.contentView withOffset:-25];
        [detailTextLabel autoVCenterInSuperview];
        return cell;
    };
    item.customRowHeight = @(customRowHeight);
    return item;
}


+ (OWSTableItem *)softCenterLabelItemWithText:(NSString *)text
{
    OWSAssertDebug(text.length > 0);

    OWSTableItem *item = [OWSTableItem new];
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        // These cells look quite different.
        //
        // Smaller font.
        cell.textLabel.font = [UIFont ows_regularFontWithSize:15.f];
        // Soft color.
        // TODO: Theme, review with design.
        cell.textLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.f];
        // Centered.
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.userInteractionEnabled = NO;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)softCenterLabelItemWithText:(NSString *)text customRowHeight:(CGFloat)customRowHeight
{
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [self softCenterLabelItemWithText:text];
    item.customRowHeight = @(customRowHeight);
    return item;
}

+ (OWSTableItem *)labelItemWithText:(NSString *)text
{
    OWSAssertDebug(text.length > 0);

    OWSTableItem *item = [OWSTableItem new];
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;
        cell.userInteractionEnabled = NO;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)labelItemWithText:(NSString *)text accessoryText:(NSString *)accessoryText
{
    OWSAssertDebug(text.length > 0);
//    OWSAssertDebug(accessoryText.length > 0);

    OWSTableItem *item = [OWSTableItem new];
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;

        UILabel *accessoryLabel = [UILabel new];
        accessoryLabel.text = accessoryText;
        accessoryLabel.textColor = Theme.secondaryTextAndIconColor;
        accessoryLabel.font = self.textLabelFont;
        accessoryLabel.textAlignment = NSTextAlignmentRight;
        [accessoryLabel sizeToFit];
        cell.accessoryView = accessoryLabel;

        cell.userInteractionEnabled = NO;
        return cell;
    };
    return item;
}

+ (OWSTableItem *)switchItemWithText:(NSString *)text isOn:(BOOL)isOn target:(id)target selector:(SEL)selector
{
    return [self switchItemWithText:text isOn:isOn isEnabled:YES target:target selector:selector];
}

+ (OWSTableItem *)switchItemWithText:(NSString *)text
                                isOn:(BOOL)isOn
                           isEnabled:(BOOL)isEnabled
                              target:(id)target
                            selector:(SEL)selector
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(target);
    OWSAssertDebug(selector);

    OWSTableItem *item = [OWSTableItem new];
    __weak id weakTarget = target;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;

        UISwitch *cellSwitch = [UISwitch new];
        cell.accessoryView = cellSwitch;
        [cellSwitch setOn:isOn];
        [cellSwitch addTarget:weakTarget action:selector forControlEvents:UIControlEventValueChanged];
        cellSwitch.enabled = isEnabled;

        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        return cell;
    };
    return item;
}

+ (OWSTableItem *)switchOnlyDisplayItemWithText:(NSString *)text
                                           isOn:(BOOL)isOn
                                         target:(id)target
                                       selector:(SEL)selector
{
    OWSAssertDebug(text.length > 0);
    OWSAssertDebug(target);
    OWSAssertDebug(selector);

    OWSTableItem *item = [OWSTableItem new];
    __weak id weakTarget = target;
    item.customCellBlock = ^{
        UITableViewCell *cell = [OWSTableItem newCell];
        cell.textLabel.text = text;

        UISwitch *cellSwitch = [UISwitch new];
        cell.accessoryView = cellSwitch;
        [cellSwitch setOn:isOn];
//        cellSwitch.enabled = NO;
        
        UIButton *btnAction = [UIButton buttonWithType:UIButtonTypeCustom];
        [btnAction addTarget:weakTarget action:selector forControlEvents:UIControlEventTouchUpInside];
        [cellSwitch addSubview:btnAction];
        [btnAction autoPinEdgesToSuperviewEdges];

        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        return cell;
    };
    return item;
}


+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionBlock:(nullable OWSTableActionBlock)actionBlock
                      deselectActionBlock:(nullable OWSTableActionBlock)deselectActionBlock
{
    OWSAssertDebug(customRowHeight > 0 || customRowHeight == UITableViewAutomaticDimension);

    OWSTableItem *item = [OWSTableItem new];
    item.actionBlock = actionBlock;
    item.customCellBlock = customCellBlock;
    item.deselectActionBlock = deselectActionBlock;
    item.customRowHeight = @(customRowHeight);
    
    return item;
}

+ (OWSTableItem *)itemWithCustomCellBlock:(OWSTableCustomCellBlock)customCellBlock
                          customRowHeight:(CGFloat)customRowHeight
                              actionWithIndexPathBlock:(nullable OWSTableActionWithIndexPathBlock)actionBlock
         deselectActionWithIndexPathBlock:(nullable OWSTableActionWithIndexPathBlock)deselectActionBlock {
    OWSTableItem *item = [OWSTableItem new];
    item.actionWithIndexPathBlock = actionBlock;
    item.customCellBlock = customCellBlock;
    item.deselectActionWithIndexPathBlock = deselectActionBlock;
    item.customRowHeight = @(customRowHeight);

    return item;
}

- (nullable UITableViewCell *)customCell
{
    if (_customCell) {
        return _customCell;
    }
    if (_customCellBlock) {
        UITableViewCell* cell = _customCellBlock();
        
//        cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
//        cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
        
        return cell;
    }
    return nil;
}

+ (UIImageView *)accessoryArrow {
    UIImage *arrow = [[UIImage imageNamed:@"ic_accessory_arrow"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *arrowView = [[UIImageView alloc] initWithImage:arrow];
    arrowView.tintColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0xB7BDC6] : [UIColor colorWithRGBHex:0x474D57];
    
    return arrowView;
}

+ (UIFont *)textLabelFont {
    return [UIFont systemFontOfSize:16];
}

+ (UIColor *)textLabelTextColor {
    return Theme.primaryTextColor;
}

+ (UIFont *)detailTextLabelFont {
    return [UIFont systemFontOfSize:16];
}

+ (UIColor *)detailTextLabelTextColor {
    return Theme.ternaryTextColor;
}

@end

#pragma mark -

@interface OWSTableViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic) UITableView *tableView;

@end

#pragma mark -

NSString *const kOWSTableCellIdentifier = @"kOWSTableCellIdentifier";

@implementation OWSTableViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self owsTableCommonInit];

    return self;
}

- (void)owsTableCommonInit
{
    _contents = [OWSTableContents new];
    self.tableViewStyle = UITableViewStyleGrouped;
    self.canEditRow = NO;
}

- (void)loadView
{
    [super loadView];

    OWSAssertDebug(self.contents);

    if (self.contents.title.length > 0) {
        self.title = self.contents.title;
    }

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:self.tableViewStyle];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.tableView];

    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    
    if (!self.customTableConstraints) {
        if ([self.tableView applyScrollViewInsetsFix]) {
            // if applyScrollViewInsetsFix disables contentInsetAdjustmentBehavior,
            // we need to pin to the top and bottom layout guides since UIKit
            // won't adjust our content insets.
            [self.tableView autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
            [self.tableView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
            [self.tableView autoPinWidthToSuperview];

            // We don't need a top or bottom insets, since we pin to the top and bottom layout guides.
            self.automaticallyAdjustsScrollViewInsets = NO;
        } else {
            [self.tableView autoPinEdgesToSuperviewEdges];
        }
    }

    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kOWSTableCellIdentifier];

//    [self applyTheme];
    self.view.backgroundColor = Theme.backgroundColor;
    self.tableView.backgroundColor = Theme.isDarkThemeEnabled ? Theme.darkThemeBackgroundColor : [UIColor colorWithRGBHex:0xFAFAFA];
    self.tableView.separatorColor = Theme.cellSeparatorColor;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

- (OWSTableSection *)sectionForIndex:(NSInteger)sectionIndex
{
    OWSAssertDebug(self.contents);
    OWSAssertDebug(sectionIndex >= 0 && sectionIndex < (NSInteger)self.contents.sections.count);

    OWSTableSection *section = self.contents.sections[(NSUInteger)sectionIndex];
    return section;
}

- (OWSTableItem *)itemForIndexPath:(NSIndexPath *)indexPath
{
    OWSAssertDebug(self.contents);
    OWSAssertDebug(indexPath.section >= 0 && indexPath.section < (NSInteger)self.contents.sections.count);

    OWSTableSection *section = self.contents.sections[(NSUInteger)indexPath.section];
    OWSAssertDebug(indexPath.item >= 0 && indexPath.item < (NSInteger)section.items.count);
    OWSTableItem *item = section.items[(NSUInteger)indexPath.item];

    return item;
}

- (void)setContents:(OWSTableContents *)contents
{
    OWSAssertDebug(contents);
    OWSAssertIsOnMainThread();

    _contents = contents;

    [self.tableView reloadData];
    [self.tableView layoutIfNeeded];
//    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.delegate && [self.delegate respondsToSelector:@selector(tableViewDidRenderCompleteWithTableView:)]){
            [self.delegate tableViewDidRenderCompleteWithTableView:self.tableView];
        }
            
//    });
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    OWSAssertDebug(self.contents);
    return (NSInteger)self.contents.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    OWSTableSection *section = [self sectionForIndex:sectionIndex];
    OWSAssertDebug(section.items);
    return (NSInteger)section.items.count;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)sectionIndex
{
    OWSTableSection *section = [self sectionForIndex:sectionIndex];
    return section.headerTitle;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    // Background color
    view.tintColor = Theme.secondaryBackgroundColor;
    
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        // Text Color
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        [header.textLabel setTextColor:Theme.primaryTextColor];
   }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if(self.delegate && [self.delegate respondsToSelector:@selector(originalTableView:willDisplayCell:forRowAtIndexPath:)]){
        [self.delegate originalTableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)sectionIndex
{
    OWSTableSection *section = [self sectionForIndex:sectionIndex];
    return section.footerTitle;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OWSTableItem *item = [self itemForIndexPath:indexPath];

    item.tableViewController = self;

    UITableViewCell *customCell = [item customCell];
    if (customCell) {
        return customCell;
    }

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kOWSTableCellIdentifier];
    OWSAssertDebug(cell);

    cell.textLabel.text = item.title;

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OWSTableItem *item = [self itemForIndexPath:indexPath];
    if (item.customRowHeight) {
        return [item.customRowHeight floatValue];
    }
    return kOWSTable_DefaultCellHeight;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)sectionIndex
{
    OWSTableSection *section = [self sectionForIndex:sectionIndex];
    return section.customHeaderView;
    
//    UIView *tempView=[[UIView alloc]initWithFrame:CGRectMake(0,200,300,244)];
//    tempView.backgroundColor=[UIColor redColor];
//    return tempView;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)sectionIndex
{
    OWSTableSection *section = [self sectionForIndex:sectionIndex];
    return section.customFooterView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)sectionIndex
{
    OWSTableSection *_Nullable section = [self sectionForIndex:sectionIndex];

    if (!section) {
        OWSFailDebug(@"Section index out of bounds.");
        return 0;
    }

    if (section.customHeaderHeight) {
        OWSAssertDebug([section.customHeaderHeight floatValue] > 0);
        return [section.customHeaderHeight floatValue];
    } else if (section.headerTitle.length > 0) {
        return UITableViewAutomaticDimension;
    } else {
        return 0;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)sectionIndex
{
    OWSTableSection *_Nullable section = [self sectionForIndex:sectionIndex];
    if (!section) {
        OWSFailDebug(@"Section index out of bounds.");
        return 0;
    }

    if (section.customFooterHeight) {
        OWSAssertDebug([section.customFooterHeight floatValue] > 0);
        return [section.customFooterHeight floatValue];
    } else if (section.footerTitle.length > 0) {
        return UITableViewAutomaticDimension;
    } else {
        return 0;
    }
}

// Called before the user changes the selection. Return a new indexPath, or nil, to change the proposed selection.
- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OWSTableItem *item = [self itemForIndexPath:indexPath];
    if (!item.actionBlock && !item.actionWithIndexPathBlock) {
        return nil;
    }
//    if (item.deselectActionBlock && self.isMaxSelected) {
//        return nil;
//    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    OWSTableItem *item = [self itemForIndexPath:indexPath];
    if (item.actionBlock) {
        item.actionBlock();
    }
    if (item.actionWithIndexPathBlock) {
        item.actionWithIndexPathBlock(indexPath);
    }
    if (!item.deselectActionWithIndexPathBlock && !item.deselectActionBlock) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }else {
        if (self.isMaxSelected) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    }
    if(self.delegate && [self.delegate respondsToSelector:@selector(originalTableView:didSelectRowAtIndexPath:)]){
        [self.delegate originalTableView:tableView didSelectRowAtIndexPath:indexPath];
    }

}

- (nullable NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    OWSTableItem *item = [self itemForIndexPath:indexPath];
    if (!item.deselectActionBlock && !item.deselectActionWithIndexPathBlock) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    OWSTableItem *item = [self itemForIndexPath:indexPath];
    if (item.deselectActionBlock) {
        item.deselectActionBlock();
    }
    if (item.deselectActionWithIndexPathBlock) {
        item.deselectActionWithIndexPathBlock(indexPath);
    }
}

-(void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
//    [self performSelector:@selector(updateCellsUserState) withObject:nil afterDelay:0 inModes:@[NSDefaultRunLoopMode]];
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewDidEndDecelerating:)]) {
        [self.delegate tableViewDidEndDecelerating:self.tableView];
    }
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate  {
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewDidEndDragging:willDecelerate:)]) {
        [self.delegate tableViewDidEndDragging:self.tableView willDecelerate:decelerate];
    }
}
#pragma mark Index

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    if (self.contents.sectionForSectionIndexTitleBlock) {
        return self.contents.sectionForSectionIndexTitleBlock(title, index);
    } else {
        return 0;
    }
}

- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if (self.contents.sectionIndexTitlesForTableViewBlock) {
        return self.contents.sectionIndexTitlesForTableViewBlock();
    } else {
        return 0;
    }
}

- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) API_UNAVAILABLE(tvos)
 {
//     Localized(@"TXT_DELETE_TITLE", nil)
     
     UISwipeActionsConfiguration *actionsConfig = nil;
     if (self.delegate && [self.delegate respondsToSelector:@selector(_tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:)]) {
         actionsConfig = [self.delegate _tableView:tableView trailingSwipeActionsConfigurationForRowAtIndexPath:indexPath];
     }
     return actionsConfig;
}

- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UISwipeActionsConfiguration *actionsConfig = nil;
    if (self.delegate && [self.delegate respondsToSelector:@selector(_tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:)]) {
        actionsConfig = [self.delegate _tableView:tableView leadingSwipeActionsConfigurationForRowAtIndexPath:indexPath];
    }
    return actionsConfig;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.canEditRow) {
        return self.contents.sections[(NSUInteger)indexPath.section].items[(NSUInteger)indexPath.row].canEdit;
    }
    
    return self.canEditRow;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (!self.canMoveRow) {
        BOOL canMove = self.contents.sections[(NSUInteger)indexPath.section].items[(NSUInteger)indexPath.row].canMove;
        return canMove;
    }
    
    return self.canMoveRow;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {

    if (self.delegate && [self.delegate respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)]) {
        [self.delegate originalTableView:tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    
    //不能移动到其他分区
    if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
        return sourceIndexPath;
    }
    NSUInteger section = (NSUInteger)proposedDestinationIndexPath.section;
    NSUInteger row = (NSUInteger)proposedDestinationIndexPath.row;
    OWSTableItem *tableItem = self.contents.sections[section].items[row];
    BOOL canMove = tableItem.canMove;
    if (!canMove) {
        return sourceIndexPath;
    }
    return proposedDestinationIndexPath;
}

#pragma mark - Presentation

- (void)presentFromViewController:(UIViewController *)fromViewController
{
    OWSAssertDebug(fromViewController);

    OWSNavigationController *navigationController = [[OWSNavigationController alloc] initWithRootViewController:self];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                      target:self
                                                      action:@selector(donePressed:)];

    [fromViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)donePressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewDidScroll:)]) {
        
        [self.delegate tableViewDidScroll:self.tableView];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(tableViewWillBeginDragging)]) {
        
        [self.delegate tableViewWillBeginDragging];
    }
}

#pragma mark - Theme

- (void)applyTheme
{
    OWSAssertIsOnMainThread();

    [super applyTheme];
    [self.tableView reloadData];

    self.view.backgroundColor = Theme.backgroundColor;
    self.tableView.backgroundColor = Theme.isDarkThemeEnabled ? Theme.darkThemeBackgroundColor : [UIColor colorWithRGBHex:0xFAFAFA];
    self.tableView.separatorColor = Theme.cellSeparatorColor;
}

-(BOOL)hidesBottomBarWhenPushed
{
    return YES;
}

- (UITableViewCell *)cellWithName:(NSString *)name
                       isSwitchOn:(BOOL)isOn
                     switchAction:(SEL)selector {
        
    return [self cellWithName:name subviews:nil isSwitchOn:isOn switchAction:selector];
}

- (UITableViewCell *)cellWithName:(NSString *)name
                         subviews:(nullable NSArray <__kindof UIView *> *)subviews
                       isSwitchOn:(BOOL)isOn
                     switchAction:(SEL)selector {
    
    OWSAssertDebug(name.length > 0);
    
    UITableViewCell *cell = [UITableViewCell new];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.preservesSuperviewLayoutMargins = YES;
    cell.contentView.preservesSuperviewLayoutMargins = YES;
    cell.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.contentView.backgroundColor = Theme.tableSettingCellBackgroundColor;
    cell.separatorInset = UIEdgeInsetsMake(0, 50, 0, 0);
    
    UILabel *rowLabel = [UILabel new];
    rowLabel.text = name;
    rowLabel.textColor = Theme.primaryTextColor;
    rowLabel.font = [UIFont systemFontOfSize:16];
    rowLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    rowLabel.numberOfLines = 0;
    
    UIStackView *contentRow = [[UIStackView alloc] initWithArrangedSubviews:@[ rowLabel ]];
    [cell.contentView addSubview:contentRow];

    if (DTParamsUtils.validateArray(subviews)) {
        contentRow.spacing = 5;
        [subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [contentRow addArrangedSubview:obj];
        }];
        [contentRow autoPinEdgeToSuperviewMargin:ALEdgeTop];
        [contentRow autoPinEdgeToSuperviewMargin:ALEdgeLeading];
        [contentRow autoPinEdgeToSuperviewMargin:ALEdgeBottom];
    } else {
        [contentRow autoPinEdgesToSuperviewMargins];
    }
    
    UISwitch *stickSwitch = [UISwitch new];
    stickSwitch.on = isOn;
    [stickSwitch addTarget:self
                    action:selector
          forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = stickSwitch;
    
    return cell;
}

@end

NS_ASSUME_NONNULL_END
