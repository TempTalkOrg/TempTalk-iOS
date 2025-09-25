//
//  DTGroupMemberController.h
//  Wea
//
//  Created by hornet on 2022/1/5.
//

#import <TTMessaging/TTMessaging.h>
NS_ASSUME_NONNULL_BEGIN

// 通话类型
typedef NS_ENUM(NSInteger, DTGroupMemberSelectedType) {
    DTGroupMemberSelectedType_MultipleChoice = 0,//多选,默认是多选
    DTGroupMemberSelectedType_SingleChoice ,// 单选
};

typedef NS_ENUM(NSInteger, DTGroupMemberControllerType) {//控制器类型
    DTGroupMemberSelectedType_AddAdminPeople = 0,//添加群管理员
    DTGroupMemberSelectedType_DeleteAdminPeople = 1,//删除群管理员
    DTGroupMemberSelectedType_TransferOwer = 2,//转让群主
    DTGroupMemberSelectedType_ShowAdminPeople = 3,//展示群管理员
};

@protocol DTGroupMemberControllerDelegate <NSObject>
- (void)memberIdsWasAdded:(NSArray *)recipientIds withType:(DTGroupMemberControllerType)type;
- (void)groupOwerWasChangedWithType:(DTGroupMemberControllerType)type;
@end

@class TSGroupThread;

@interface DTGroupMemberController : OWSTableViewController
@property(nonatomic,weak) id <DTGroupMemberControllerDelegate> memberControllerDelegate;
@property(nonatomic,assign) DTGroupMemberSelectedType selectedType;
@property(nonatomic,assign) DTGroupMemberControllerType controllerType;

- (void)configWithThread:(TSGroupThread *)thread;

@end

NS_ASSUME_NONNULL_END
