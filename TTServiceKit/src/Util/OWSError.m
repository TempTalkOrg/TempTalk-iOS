//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSError.h"
#import <TTServiceKit/Localize_Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSTTServiceKitErrorDomain = @"DTServiceKitErrorDomain";
NSString *const OWSErrorRecipientIdentifierKey = @"DTErrorKeyRecipientIdentifier";

NSError *OWSErrorWithCodeDescription(OWSErrorCode code, NSString *description)
{
    return [NSError errorWithDomain:OWSTTServiceKitErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

NSError *OWSErrorMakeUnableToProcessServerResponseError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeUnableToProcessServerResponse,
        Localized(@"ERROR_DESCRIPTION_SERVER_FAILURE", @"Generic server error"));
}

NSError *OWSErrorMakeFailedToSendOutgoingMessageError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeFailedToSendOutgoingMessage,
        Localized(@"ERROR_DESCRIPTION_CLIENT_SENDING_FAILURE", @"Generic notice when message failed to send."));
}

NSError *OWSErrorAttachmentExceedsLimitError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeAttachmentExceedsLimit,
        Localized(@"ERROR_ATTACHMENT_EXCEEDS_LIMIT", nil));
}

NSError *OWSErrorMakeNoSuchSignalRecipientError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeNoSuchSignalRecipient,
        Localized(
            @"ERROR_DESCRIPTION_UNREGISTERED_RECIPIENT", @"Error message when attempting to send message"));
}

NSError *OWSErrorMakeAssertionError(NSString *description)
{
    OWSCFailDebug(@"Assertion failed: %@", description);
    return OWSErrorWithCodeDescription(OWSErrorCodeAssertionFailure,
        Localized(@"ERROR_DESCRIPTION_UNKNOWN_ERROR", @"Worst case generic error message"));
}

NSError *OWSErrorMakeUntrustedIdentityError(NSString *description, NSString *recipientId)
{
    return [NSError
        errorWithDomain:OWSTTServiceKitErrorDomain
                   code:OWSErrorCodeUntrustedIdentity
               userInfo:@{ NSLocalizedDescriptionKey : description, OWSErrorRecipientIdentifierKey : recipientId }];
}

NSError *OWSErrorMakeMessageSendDisabledDueToPreKeyUpdateFailuresError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeMessageSendDisabledDueToPreKeyUpdateFailures,
        Localized(@"ERROR_DESCRIPTION_MESSAGE_SEND_DISABLED_PREKEY_UPDATE_FAILURES",
            @"Error message indicating that message send is disabled due to prekey update failures"));
}

NSError *OWSErrorMakeMessageSendFailedToBlockListError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeMessageSendFailedToBlockList,
        Localized(@"ERROR_DESCRIPTION_MESSAGE_SEND_FAILED_DUE_TO_BLOCK_LIST",
            @"Error message indicating that message send failed due to block list"));
}

NSError *OWSErrorMakeWriteAttachmentDataError(void)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeCouldNotWriteAttachmentData,
        Localized(@"ERROR_DESCRIPTION_MESSAGE_SEND_FAILED_DUE_TO_FAILED_ATTACHMENT_WRITE",
            @"Error message indicating that message send failed due to failed attachment write"));
}

NSError *OWSErrorMeeingError(NSInteger errorCode, NSString *description)
{
    return [NSError errorWithDomain:OWSTTServiceKitErrorDomain
                               code:errorCode
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

NSError *OWSErrorCheckAttachmentError(NSString *description)
{
    return OWSErrorWithCodeDescription(OWSErrorCodeAttachmentCheckFailed, description);
}

NS_ASSUME_NONNULL_END
