//
//  DTBaseAPI.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/1.
//

#import <Foundation/Foundation.h>
#import "OWSRequestFactory.h"
#import <Mantle/Mantle.h>
#import "OWSError.h"
#import "DTDisappearanceTimeIntervalConfig.h"
#import "TSRequest.h"
#import "DTParamsBaseUtils.h"
#import "TSConstants.h"

NS_ASSUME_NONNULL_BEGIN

/*
 0    OK
 1    Invalid parameter
 2    No permission
 3    No such group
 4    No such group member
 5    Invalid token
 6    Server Internal Error
 7    NO SUCH GROUP ANNOUNCEMENT
 8    GROUP EXISTS
 9    No Such File
 99    OTHER ERROR
 */



@class DTAPIMetaEntity;

typedef NS_ENUM(NSInteger, DTAPIRequestResponseStatus) {
    DTAPIRequestResponseStatusOK                         = 0,
    DTAPIRequestResponseStatusInvalidParameter           = 1,
    DTAPIRequestResponseStatusNoPermission               = 2,
    DTAPIRequestResponseStatusNoSuchGroup                = 3,
    DTAPIRequestResponseStatusNoSuchGroupMember          = 4,
    DTAPIRequestResponseStatusInvalidToken               = 5,
    DTAPIRequestResponseStatusServerInternalError        = 6,
    DTAPIRequestResponseStatusNoSuchGroupAnnouncement    = 7,
    DTAPIRequestResponseStatusGroupExists                = 8,
    DTAPIRequestResponseStatusNoSuchFile                 = 9,
    DTAPIRequestResponseStatusGroupIsFull                = 10,
    DTAPIRequestResponseStatusNoSuchGroupTask            = 11,
    DTAPIRequestResponseStatusOperateError               = 12,
    DTAPIRequestResponseStatusOtherError                 = 99,
    DTAPIRequestResponseStatusHttpError                  = 1000,
    DTAPIRequestResponseStatusDataError                  = 1100,
    DTAPIRequestResponseStatusParamsError                = 1200,
    DTAPIRequestResponseStatusFrequencyLimit             = 1201,
    DTAPIRequestResponseStatusInvalidIdentifier          = 11001,
    DTAPIRequestResponseStatusUnsupportedMsgVersion      = 11002,
    DTAPIRequestResponseStatusDeletedIdentifier          = 10110,
    DTAPIRequestResponseStatusCreateGroupFailed          = 10125,
};

typedef NS_ENUM(NSInteger, DTAPIRequestStatus) {
    DTAPIRequestURLError                = 2001
};

extern NSString *const DTServerErrorDomain;
extern NSString *const kDTAPIRequestHttpErrorDescription;
extern NSString *const kDTAPIDataErrorDescription;
extern NSString *const kDTAPITokenErrorDescription;
extern NSString *const kDTAPIParamsErrorDescription;

extern NSString *const DTLocalRequestErrorDomain;
extern NSString *const kDTAPIRequestURLErrorDescription;

extern NSError *DTErrorWithCodeDescription(DTAPIRequestResponseStatus code, NSString *description);
extern NSError *DTRequestErrorWithCodeDescription(DTAPIRequestStatus code, NSString *description);

typedef void (^DTAPISuccessBlock)(DTAPIMetaEntity *entity);
typedef void (^DTAPIFailureBlock)(NSError *error);

@interface DTAPIMetaEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSInteger ver;

@property (nonatomic, assign) NSInteger status;

@property (nonatomic, copy) NSString *reason;

@property (nonatomic, strong) NSDictionary *data;

@end

@interface DTBaseAPI : NSObject

@property (nonatomic, assign) BOOL isSyncRequest;
@property (nonatomic, copy) NSString *requestMethod;
@property (nonatomic, copy) NSString *requestUrl;

@property (nonatomic, assign) DTServerType serverType;
//开启限频
@property (nonatomic, assign) BOOL frequencyLimitEnable;
//开启限频后，可以自定义相同请求的特征, default is nil;
@property (nonatomic, copy) BOOL (^sameRequestFilter)(void);

- (void)sendRequest:(TSRequest *)request
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure;

- (void)sendRequest:(TSRequest *)request
    completionQueue:(dispatch_queue_t)completionQueue
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
