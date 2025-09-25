//
//  ConversationItemMacro.h
//  Signal
//
//  Created by hornet on 2022/3/12.
//

#ifndef ConversationItemMacro_h
#define ConversationItemMacro_h

//NSString * const kUpdateVoteInfoNotification = @"kUpdateVoteInfoNotification";

typedef NS_ENUM(int, ConversationViewMode) {
    ConversationViewMode_Main = 0,//主Conversation
    ConversationViewMode_NormalPresent,//X关闭按钮，threadName居中显示，例：会议反馈bot
    ConversationViewMode_Confidential,//机密消息模式
    ConversationViewMode_UnKnow = 100,
};

typedef NS_ENUM(NSUInteger, ConversationViewAction) {
    ConversationViewActionNone,
    ConversationViewActionCompose,
    ConversationViewActionAudioCall,
};

#endif /* ConversationItemMacro_h */
