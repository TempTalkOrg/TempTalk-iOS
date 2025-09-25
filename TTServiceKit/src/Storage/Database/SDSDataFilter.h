//
//  SDSDataFilter.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/10/28.
//

#import <Foundation/Foundation.h>
#import "YapDatabaseDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class TSThread;
@class SDSAnyReadTransaction;
@class DTChatFolderEntity;

@interface SDSDataFilter : NSObject

+ (BOOL)filterThread:(TSThread *)thread
         chartFolder:(nullable DTChatFolderEntity *)chartFolder
         transaction:(SDSAnyReadTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
