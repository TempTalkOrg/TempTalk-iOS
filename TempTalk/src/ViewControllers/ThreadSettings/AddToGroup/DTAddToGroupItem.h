//
//  DTAddToGroupItem.h
//  Wea
//
//  Created by hornet on 2022/1/1.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTAddToGroupItem : UICollectionViewCell
- (void)configWithReceptId:(NSString *)receptId;
- (void)configWithImage:(nullable NSString *)imageName;
@end

NS_ASSUME_NONNULL_END
