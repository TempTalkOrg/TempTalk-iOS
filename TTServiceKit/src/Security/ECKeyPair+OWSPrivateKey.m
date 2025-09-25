//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "ECKeyPair+OWSPrivateKey.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ECKeyPair (OWSPrivateKey)

- (NSData *)ows_privateKey
{
    return self.privateKey;
}

@end

NS_ASSUME_NONNULL_END
