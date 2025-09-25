//
//  HomeViewController+ChatFolder.h
//  Wea
//
//  Created by Ethan on 2022/4/14.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "HomeViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface HomeViewController (ChatFolder)

- (BOOL)isSelectedFolder;
- (BOOL)isSelectedRecommendFolder;
- (BOOL)shouldShowFolderBar;

- (void)updateFiltering;

- (void)removeFolderThread:(TSThread *)thread;

@end

NS_ASSUME_NONNULL_END
