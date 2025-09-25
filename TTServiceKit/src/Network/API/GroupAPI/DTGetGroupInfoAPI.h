//
//  DTGetGroupInfoAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/2.
//

#import "DTBaseAPI.h"
#import "DTGroupMemberEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTGetGroupInfoDataEntity : DTAPIMetaEntity

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, strong) NSNumber *messageExpiry;
@property (nonatomic, copy) NSString *avatar;
@property (nonatomic, strong) NSArray<DTGroupMemberEntity *> *members;
@property (nonatomic, strong) NSNumber *invitationRule;
@property (nonatomic, copy) NSString *remindCycle;
@property (nonatomic, assign) BOOL anyoneRemove;
@property (nonatomic, assign) BOOL rejoin;
@property (nonatomic, strong) NSNumber *publishRule;
@property (nonatomic, assign) BOOL ext;

@property (nonatomic, assign) BOOL anyoneChangeName;
@property (nonatomic, assign) BOOL anyoneChangeAutoClear;
@property (nonatomic, assign) BOOL autoClear;
@property (nonatomic, assign) BOOL privilegeConfidential;

@end

@interface DTGetGroupInfoAPI : DTBaseAPI

@property (atomic, assign) NSInteger version;

- (void)sendRequestWithGroupId:(NSString *)groupId
                       success:(void(^)(DTGetGroupInfoDataEntity *entity))success
                       failure:(DTAPIFailureBlock)failure;

- (void)sendRequestWithGroupId:(NSString *)groupId
                 targetVersion:(NSInteger)targetVersion
                       success:(void(^)(DTGetGroupInfoDataEntity *entity))success
                       failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
