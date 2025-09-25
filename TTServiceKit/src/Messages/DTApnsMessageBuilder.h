//
//  DTApnsMessageBuilder.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/26.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DTApnsMessageType) {
    DTApnsMessageType_PERSONAL_NORMAL,               //0:1V1普通消息
    DTApnsMessageType_PERSONAL_FILE,                 //1:1V1文件消息
    DTApnsMessageType_PERSONAL_REPLY,                //2:1V1回复消息
    DTApnsMessageType_PERSONAL_CALL,                 //3:1V1Call消息
    DTApnsMessageType_PERSONAL_CALL_CANCEL,          //4:1V1Call取消
    DTApnsMessageType_PERSONAL_CALL_TIMEOUT,         //5:1V1Call超时
    
    DTApnsMessageType_GROUP_NORMAL,                  //6:group普通消息
    DTApnsMessageType_GROUP_FILE,                    //7:group文件消息
    DTApnsMessageType_GROUP_MENTIONS_DESTINATION,    //8:group@消息（@消息接收者）
    DTApnsMessageType_GROUP_MENTIONS_OTHER,          //9:group@消息（@其他人）
    DTApnsMessageType_GROUP_MENTIONS_ALL,            //10:group@消息（@All）
    DTApnsMessageType_GROUP_REPLY_DESTINATION,       //11:group回复消息
    DTApnsMessageType_GROUP_REPLY_OTHER,             //12:group回复消息（回复其他人）
    DTApnsMessageType_GROUP_CALL,                    //13:group call消息
    DTApnsMessageType_GROUP_CALL_COLSE,              //14:group Call close
    DTApnsMessageType_GROUP_CALL_OVER,               //15:group Call over
    DTApnsMessageType_GROUP_ADD_ANNOUNCEMENT,        //16:group 新增公告
    DTApnsMessageType_GROUP_UPDATE_ANNOUNCEMENT,     //17:group 更新公告
    DTApnsMessageType_RECALL_MSG,                    //18:recall撤回
    DTApnsMessageType_RECALL_MENTIONS_MSG,           //19:recall @
    DTApnsMessageType_TASK_MSG,                      //20:task
    DTApnsMessageType_VOTE_MSG,                      //21:vote
    DTApnsMessageType_ENC_CALL                       //22:新版加密会议
};

@class TSOutgoingMessage;
@class TSThread;
@class SignalRecipient;

@interface DTApnsMessageInfo : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) DTApnsMessageType messageType;

@property (nonatomic, copy) NSString *groupName;

@property (nonatomic, copy) NSString *groupID;

@property (nonatomic, copy) NSString *passthrough;

@property (nonatomic, strong) NSArray *mentionedPersons;

@property (nonatomic, copy) NSString *collapseId;

@end

@interface DTApnsMessageBuilder : NSObject

@property (nonatomic, strong) DTApnsMessageInfo *apnsMessageInfo;

- (instancetype)initWithMessage:(TSOutgoingMessage *)message
                         thread:(TSThread *)thread
                   forRecipient:(SignalRecipient *)recipient;

- (NSDictionary *)build;

@end

NS_ASSUME_NONNULL_END
