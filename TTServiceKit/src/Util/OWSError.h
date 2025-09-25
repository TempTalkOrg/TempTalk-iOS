//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSString *const OWSTTServiceKitErrorDomain;

typedef NS_ENUM(NSInteger, OWSErrorCode) {
    OWSErrorCodeInvalidMethodParameters = 11,
    OWSErrorCodeUnableToProcessServerResponse = 12,
    OWSErrorCodeFailedToDecodeJson = 13,
    OWSErrorCodeFailedToEncodeJson = 14,
    OWSErrorCodeFailedToDecodeQR = 15,
    OWSErrorCodePrivacyVerificationFailure = 20,
    OWSErrorCodeUntrustedIdentity = 25,
    OWSErrorCodeFailedToSendOutgoingMessage = 30,
    OWSErrorCodeAssertionFailure = 31,
    OWSErrorCodeAttachmentExceedsLimit = 50,
    OWSErrorCodeAttachmentCheckFailed = 51,
    OWSErrorCodeFailedToDecryptMessage = 100,
    OWSErrorCodeFailedToEncryptMessage = 110,
    OWSErrorCodeSignalServiceFailure = 1001,
    OWSErrorCodeSignalServiceRateLimited = 1010,
    OWSErrorCodeUserError = 2001,
    OWSErrorCodeNoSuchSignalRecipient = 777404,
    OWSErrorCodeMessageSendDisabledDueToPreKeyUpdateFailures = 777405,
    OWSErrorCodeMessageSendFailedToBlockList = 777406,
    OWSErrorCodeMessageSendNoValidRecipients = 777407,
    OWSErrorCodeContactsUpdaterRateLimit = 777408,
    OWSErrorCodeCouldNotWriteAttachmentData = 777409,
    OWSErrorCodeMessageDeletedBeforeSent = 777410,
    OWSErrorCodeDatabaseConversionFatalError = 777411,
    OWSErrorCodeMoveFileToSharedDataContainerError = 777412,
    OWSErrorCodeRegistrationMissing2FAPIN = 777413,
    OWSErrorCodeDebugLogUploadFailed = 777414,
    // A non-recoverable error occured while exporting a backup.
    OWSErrorCodeExportBackupFailed = 777415,
    // A possibly recoverable error occured while exporting a backup.
    OWSErrorCodeExportBackupError = 777416,
    // A non-recoverable error occured while importing a backup.
    OWSErrorCodeImportBackupFailed = 777417,
    // A possibly recoverable error occured while importing a backup.
    OWSErrorCodeImportBackupError = 777418,
    // A non-recoverable while importing or exporting a backup.
    OWSErrorCodeBackupFailure = 777419,
    OWSErrorCodeLocalAuthenticationError = 777420,
    OWSErrorCodeMessageRequestFailed = 777421,
    OWSErrorCodeMessageResponseFailed = 777422,
    OWSErrorCodeFailedToDecryptDuplicateMessage,
};

extern NSString *const OWSErrorRecipientIdentifierKey;

extern NSError *OWSErrorWithCodeDescription(OWSErrorCode code, NSString *description);
extern NSError *OWSErrorMakeUntrustedIdentityError(NSString *description, NSString *recipientId);
extern NSError *OWSErrorMakeUnableToProcessServerResponseError(void);
extern NSError *OWSErrorMakeFailedToSendOutgoingMessageError(void);
extern NSError *OWSErrorAttachmentExceedsLimitError(void);
extern NSError *OWSErrorCheckAttachmentError(NSString *description);
extern NSError *OWSErrorMakeNoSuchSignalRecipientError(void);
extern NSError *OWSErrorMakeAssertionError(NSString *description);
extern NSError *OWSErrorMakeMessageSendDisabledDueToPreKeyUpdateFailuresError(void);
extern NSError *OWSErrorMakeMessageSendFailedToBlockListError(void);
extern NSError *OWSErrorMakeWriteAttachmentDataError(void);

extern NSError *OWSErrorMeeingError(NSInteger errorCode, NSString *description);

NS_ASSUME_NONNULL_END
