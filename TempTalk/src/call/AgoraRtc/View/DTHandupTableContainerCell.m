//
//  DTHandupTableContainerCell.m
//  TempTalk
//
//  Created by Henry on 2025/7/4.
//  Copyright © 2025 Difft. All rights reserved.
//

#import "DTHandupTableContainerCell.h"
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/OWSContactsManager.h>
#import <TTMessaging/OWSContactAvatarBuilder.h>
#import <TTMessaging/Environment.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTMessaging/UIImageView+ContactAvatar.h>
#import "OWSAvatarBuilder.h"
#import <TTServiceKit/TSAccountManager.h>
#import "TempTalk-Swift.h"

@interface DTHandupTableContainerCell () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSString *> *data;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, assign) NSInteger maxCount;
@property (nonatomic, copy) void (^onToggle)(BOOL);
@property (nonatomic, strong) UILabel *countLabel;

@end

@implementation DTHandupTableContainerCell

+ (NSString *)reuseIdentifier {
    return @"DTHandupTableContainerCell";
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupTableView];
        [self setupHeaderView];
    }
    return self;
}

- (void)setupHeaderView {
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = [UIColor clearColor];

    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tabler_hand_lower"]];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    [iconView.widthAnchor constraintEqualToConstant:20].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:20].active = YES;

    self.countLabel = [[UILabel alloc] init];
    self.countLabel.font = [UIFont systemFontOfSize:16];
    self.countLabel.textColor = UIColor.labelColor;
    self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[iconView, self.countLabel]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.headerView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:0],
        [stack.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:0],
        [stack.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:8],
        [stack.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:0]
    ]];
    self.headerView.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, 44);
    self.tableView.tableHeaderView = self.headerView;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.scrollEnabled = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 44;
    self.tableView.layer.cornerRadius = 8;
    self.tableView.layer.masksToBounds = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor colorWithRGBHex:0x474D57];
    self.tableView.alpha = 0.9;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.tableView];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = 8.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:inset],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-inset]
    ]];
}

- (void)configureWithHandupList:(NSArray<NSString *> *)handups
                     isExpanded:(BOOL)isExpanded
                       maxCount:(NSInteger)maxCount
                       onToggle:(void(^)(BOOL))onToggle {
    self.data = handups;
    self.isExpanded = isExpanded;
    self.maxCount = maxCount;
    self.onToggle = onToggle;
    self.countLabel.text = [NSString stringWithFormat:@"%@ (%lu)", Localized(@"RAISE_HANDS_TITLE", @""), (unsigned long)self.data.count];
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger total = self.data.count;
    if (total > self.maxCount) {
        return self.isExpanded ? total + 1 : self.maxCount + 1;
    }
    return total;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.data.count > self.maxCount && indexPath.row == (self.isExpanded ? self.data.count : self.maxCount)) {
        return [self toggleCell];
    }
    return [self participantCellAt:indexPath.row];
}

- (UITableViewCell *)toggleCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = UIColor.clearColor;
    [cell removeAllSubviews];

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:self.isExpanded ? @"tabler_chevron-up" : @"tabler_chevron-down"]];
    [cell addSubview:imageView];
    [imageView autoSetDimensionsToSize:CGSizeMake(20, 20)];
    [imageView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [imageView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:0];
    return cell;
}

- (UITableViewCell *)participantCellAt:(NSInteger)index {
    static NSString *reuseId = @"HandupCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:reuseId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseId];
    }
    [cell removeAllSubviews];
    cell.backgroundColor = UIColor.clearColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *participantId = self.data[index];
    OWSContactsManager *contactsManager = Environment.shared.contactsManager;
    NSString *displayName = [contactsManager displayNameForPhoneIdentifier:participantId];

    AvatarImageView *avatarView = [[AvatarImageView alloc] init];
    avatarView.contentMode = UIViewContentModeScaleAspectFill;
    avatarView.clipsToBounds = YES;
    avatarView.layer.cornerRadius = 16;
    [avatarView setImageWithRecipientId:participantId displayName:displayName asyncMaxSize:5 * 1024 * 1024];
    [cell addSubview:avatarView];
    [avatarView autoSetDimensionsToSize:CGSizeMake(32, 32)];
    [avatarView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:8];
    [avatarView autoAlignAxisToSuperviewAxis:ALAxisHorizontal];

    UILabel *nameLabel = [[UILabel alloc] init];
    nameLabel.font = [UIFont systemFontOfSize:14];
    nameLabel.textColor = UIColor.labelColor;
    nameLabel.numberOfLines = 1;
    nameLabel.text = displayName;
    [cell addSubview:nameLabel];
    [nameLabel autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [nameLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:avatarView withOffset:8];

    UIButton *lowerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [lowerButton setTitle:@"Lower" forState:UIControlStateNormal];
    [lowerButton setTitleColor:[UIColor colorWithRGBHex:0xB7BDC6] forState:UIControlStateNormal];
    lowerButton.titleLabel.font = [UIFont systemFontOfSize:12];
    lowerButton.tag = index;
    [lowerButton addTarget:self action:@selector(lowerHandTapped:) forControlEvents:UIControlEventTouchUpInside];
    [cell addSubview:lowerButton];
    [lowerButton autoAlignAxisToSuperviewAxis:ALAxisHorizontal];
    [lowerButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:8];
    [NSLayoutConstraint autoSetPriority:UILayoutPriorityRequired forConstraints:^{
        [lowerButton autoSetContentCompressionResistancePriorityForAxis:ALAxisHorizontal];
        [lowerButton autoSetContentHuggingPriorityForAxis:ALAxisHorizontal];
    }];
    [nameLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:lowerButton withOffset:-8 relation:NSLayoutRelationLessThanOrEqual];

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger showCount = self.isExpanded ? self.data.count : MIN(self.maxCount, self.data.count);
    if (indexPath.row == showCount && self.onToggle) {
        self.onToggle(!self.isExpanded);
    }
}

- (void)lowerHandTapped:(UIButton *)sender {
    NSInteger index = sender.tag;
    [[DTMeetingManager shared] handCancelRemoteSyncStatusWithParticipantId:self.data[index] completionHandler:^{}];
}

@end

