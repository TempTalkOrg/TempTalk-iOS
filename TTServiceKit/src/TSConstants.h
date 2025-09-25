//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#ifndef TextSecureKit_Constants_h
#define TextSecureKit_Constants_h

typedef NS_ENUM(int32_t, TSWhisperMessageType) {
    TSUnknownMessageType            = 0,
    TSEncryptedWhisperMessageType   = 1,
    TSIgnoreOnIOSWhisperMessageType = 2, // on droid this is the prekey bundle message irrelevant for us
    TSPreKeyWhisperMessageType      = 3,
    TSUnencryptedWhisperMessageType = 4,
    TSPlainTextMessageType = 7,
    TSEncryptedMessageType = 8
};

typedef NS_ENUM(NSUInteger, DTServerType) {
    DTServerTypeChat,
    DTServerTypeVoice,
    DTServerTypeUserStatus,
    DTServerTypeFileSharing,
    DTServerTypeLightTask,
    DTServerTypeTranslate,//翻译
    DTServerTypeVote,
    DTServerTypeDeviceInfo,
    DTServerTypePlatform,//openapi
    DTServerTypeDot,
    DTServerTypeConversationConfig,
    DTServerTypeGIF,
    DTServerTypeCall,
    DTServerTypeSpeech2Text,
    DTServerTypeAvatar
};

typedef NS_ENUM(NSUInteger, DTServToType) {
    DTServToTypeChat,
//    DTServToTypeFuse
};

typedef NS_ENUM(NSUInteger, DTAPPName) {
    DTAPPNameTempTalk
};

#pragma mark - e2ee

#define MESSAGE_MINIMUM_SUPPORTED_VERSION 2
#define MESSAGE_CURRENT_VERSION 2

#pragma mark - Server Address

#define textSecureHTTPTimeOut 30
#define HTTPRequestRetryCount 2

// Use same reflector for service and CDN
#define textSecureServiceReflectorHost @"textsecure-service-reflected.whispersystems.org"
#define textSecureCDNReflectorHost @"textsecure-service-reflected.whispersystems.org"


#ifndef weakify
    #ifdef DEBUG
        #if __has_feature(objc_arc)
            #define weakify(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
        #endif
    #else
        #if __has_feature(objc_arc)
            #define weakify(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
        #else
            #define weakify(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
        #endif
    #endif
#endif


#ifndef strongify
    #ifdef DEBUG
        #if __has_feature(objc_arc)
            #define strongify(object) autoreleasepool{} \
                    _Pragma("clang diagnostic push") \
                    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
                    __typeof__(object) object = weak##_##object; \
                    _Pragma("clang diagnostic pop")
        #else

            #define strongify(object) autoreleasepool{} \
                    _Pragma("clang diagnostic push") \
                    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
                    __typeof__(object) object = block##_##object; \
                    _Pragma("clang diagnostic pop")
        #endif
    #else
        #if __has_feature(objc_arc)

            #define strongify(object) try{} @finally{} \
                    _Pragma("clang diagnostic push") \
                    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
                    __typeof__(object) object = weak##_##object; \
                    _Pragma("clang diagnostic pop")
        #else
            #define strongify(object) try{} @finally{} \
                    _Pragma("clang diagnostic push") \
                    _Pragma("clang diagnostic ignored \"-Wshadow\"") \
                    __typeof__(object) object = block##_##object; \
                    _Pragma("clang diagnostic pop")
        #endif
    #endif
#endif


#endif
