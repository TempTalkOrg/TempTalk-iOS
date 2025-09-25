CREATE
    TABLE
        keyvalue (
            KEY TEXT NOT NULL
            ,collection TEXT NOT NULL
            ,VALUE BLOB NOT NULL
            ,PRIMARY KEY (
                KEY
                ,collection
            )
        )
;

CREATE
    TABLE
        IF NOT EXISTS "model_OWSUserProfile" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"avatarFileName" TEXT
            ,"avatarUrlPath" TEXT
            ,"profileKey" BLOB
            ,"profileName" TEXT
            ,"recipientId" TEXT
        )
;

CREATE
    TABLE
        IF NOT EXISTS "model_TSThread" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"archivalDate" DOUBLE
            ,"conversationEntity" BLOB
            ,"creationDate" DOUBLE
            ,"draftQuoteMessageId" TEXT
            ,"groupModel" BLOB
            ,"hasDismissedOffers" BOOLEAN
            ,"hasEverHadMessage" BOOLEAN
            ,"lastMessageDate" DOUBLE
            ,"lastestMsg" BLOB
            ,"messageDraft" TEXT
            ,"mutedUntilDate" DOUBLE
            ,"plainTextEnable" BOOLEAN
            ,"readPositionEntity" BLOB
            ,"removedFromConversation" BOOLEAN
            ,"stickCallingDate" DOUBLE
            ,"stickDate" DOUBLE
            ,"unreadFlag" DOUBLE
            ,"unreadState" INTEGER NOT NULL DEFAULT 0
            ,"unreadTimeStimeStamp" DOUBLE
            ,"isArchived" BOOLEAN
            ,"unreadMessageCount" INTEGER
            ,"mentionedAllMsg" BLOB
            ,"mentionedMeMsg" BLOB
            ,"shouldBeVisible" BOOLEAN
            ,"threadConfig" BLOB
            ,"mentionsDraft" BLOB
            ,"friendContactVersion" INTEGER
            ,"receivedFriendReq" BOOLEAN
            ,"translateSettingType" DOUBLE
            ,"expiresInSeconds" DOUBLE
            ,"messageClearAnchor" DOUBLE
        )
;

CREATE
    INDEX "index_model_TSThread_on_uniqueId"
        ON "model_TSThread"("uniqueId"
)
;

CREATE
    INDEX "index_thread_on_finderColumns"
        ON "model_TSThread"("shouldBeVisible", "recordType", "isArchived", "removedFromConversation", "unreadMessageCount", "unreadFlag"
)
;

CREATE
    INDEX "index_thread_on_on_recordType"
        ON "model_TSThread"("recordType"
)
;

CREATE
     INDEX "index_model_TSThread_on_messageClearAnchor"
        ON "model_TSThread"("uniqueId", "messageClearAnchor"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_DTGroupBaseInfoEntity" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"action" INTEGER
            ,"anyoneRemove" BOOLEAN
            ,"avatar" TEXT
            ,"gid" TEXT
            ,"invitationRule" DOUBLE
            ,"messageExpiry" DOUBLE
            ,"name" TEXT
            ,"rejoin" BOOLEAN
            ,"remindCycle" TEXT
            ,"ext" BOOLEAN
            ,"publishRule" INTEGER
            ,"messageClearAnchor" DOUBLE
        )
;

CREATE
    INDEX "index_model_DTGroupBaseInfoEntity_on_uniqueId"
        ON "model_DTGroupBaseInfoEntity"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_SignalRecipient" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"devices" BLOB
            ,"relay" TEXT
        )
;

CREATE
    INDEX "index_model_SignalRecipient_on_uniqueId"
        ON "model_SignalRecipient"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_OWSMessageContentJob" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"createdAt" DOUBLE NOT NULL
            ,"envelopeData" BLOB NOT NULL
            ,"plaintextData" BLOB
            ,"unsupportedFlag" BOOLEAN DEFAULT 0
            ,"lastestHandleVersion" TEXT
        )
;

CREATE
    INDEX "index_model_OWSMessageContentJob_on_uniqueId"
        ON "model_OWSMessageContentJob"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_TSInteraction" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"associatedUniqueThreadId" TEXT
            ,"atPersons" TEXT
            ,"attachmentIds" BLOB
            ,"authorId" TEXT
            ,"body" TEXT
            ,"card" BLOB
            ,"combinedForwardingMessage" BLOB
            ,"contactShare" BLOB
            ,"customAttributedMessage" BLOB
            ,"customMessage" TEXT
            ,"editable" BOOLEAN
            ,"errorType" INTEGER
            ,"expireStartedAt" INTEGER
            ,"expiresAt" INTEGER
            ,"expiresInSeconds" INTEGER
            ,"groupChatMode" INTEGER
            ,"groupMetaMessage" INTEGER
            ,"hasSyncedTranscript" BOOLEAN
            ,"inviteCode" TEXT
            ,"isFromLinkedDevice" BOOLEAN
            ,"isPinnedMessage" BOOLEAN
            ,"isVoiceMessage" BOOLEAN
            ,"meetingDetailUrl" TEXT
            ,"meetingName" TEXT
            ,"meetingReminderType" INTEGER
            ,"messageType" INTEGER
            ,"mostRecentFailureText" TEXT
            ,"notifySequenceId" INTEGER
            ,"pinId" TEXT
            ,"quotedMessage" BLOB
            ,"rapidFiles" BLOB
            ,"reactionMap" BLOB
            ,"reactionMessage" BLOB
            ,"read" BOOLEAN
            ,"realSource" BLOB
            ,"recall" BLOB
            ,"recallPreview" TEXT
            ,"receivedAtTimestamp" INTEGER
            ,"recipientId" TEXT
            ,"recipientStateMap" BLOB
            ,"sequenceId" INTEGER
            ,"serverTimestamp" INTEGER
            ,"sourceDeviceId" INTEGER
            ,"timestamp" INTEGER
            ,"uniqueThreadId" TEXT
            ,"unregisteredRecipientId" TEXT
            ,"whisperMessageType" INTEGER
            ,"storedShouldStartExpireTimer" BOOLEAN
            ,"mentionedMsgType" INTEGER
            ,"configurationDurationSeconds" INTEGER
            ,"shouldAffectThreadSorting" BOOLEAN
            ,"mentions" mentions
            ,"storedMessageState" INTEGER
            ,"envelopSource" TEXT
            ,"cardUniqueId" TEXT
            ,"cardVersion" INTEGER NOT NULL DEFAULT 0
            ,"messageModeType" INTEGER
            ,"translateMessage" BLOB
        )
;

CREATE
    INDEX "index_model_TSInteraction_on_uniqueId"
        ON "model_TSInteraction"("uniqueId"
)
;

CREATE
    INDEX "index_interaction_on_baseColumns"
        ON "model_TSInteraction"("uniqueThreadId", "serverTimestamp", "recordType", "mentionedMsgType"
)
;

CREATE
    INDEX "index_interaction_on_timestamp"
        ON "model_TSInteraction"("timestamp"
)
;

CREATE
    INDEX "index_interaction_on_serverTimestamp"
        ON "model_TSInteraction"("serverTimestamp"
)
;

CREATE
    INDEX "index_interaction_on_storedMessageState"
        ON "model_TSInteraction"("storedMessageState"
)
;

CREATE
    INDEX "index_model_TSInteraction_on_cardUniqueId"
        ON "model_TSInteraction"("cardUniqueId"
)
;

CREATE
    INDEX "index_model_TSInteraction_on_topicActionServerTimeStamp"
        ON "model_TSInteraction"("topicActionServerTimeStamp"
)
;


CREATE
    TABLE
        IF NOT EXISTS "model_SignalAccount" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"contact" BLOB
            ,"hasMultipleAccountContact" BOOLEAN
            ,"isManualEdited" BOOLEAN
            ,"multipleAccountLabelText" TEXT
            ,"recipientId" TEXT
            ,"remarkName" TEXT
        )
;

CREATE
    INDEX "index_model_SignalAccount_on_uniqueId"
        ON "model_SignalAccount"("uniqueId"
)
;

CREATE
    INDEX "index_model_SignalAccount_on_recipientId"
        ON "model_SignalAccount"("recipientId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_DTChatFolderEntity" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"cIds" BLOB
            ,"conditions" BLOB
            ,"name" TEXT
            ,"sortIndex" INTEGER
            ,"folderType" INTEGER
            ,"excludeFromAll" BOOLEAN NOT NULL DEFAULT 0
        )
;

CREATE
    INDEX "index_model_DTChatFolderEntity_on_uniqueId"
        ON "model_DTChatFolderEntity"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_OWSRecall" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"editable" BOOLEAN
            ,"originalSource" TEXT
            ,"originalSourceDevice" INTEGER
            ,"originalTimestamp" INTEGER
            ,"source" TEXT
            ,"sourceDevice" INTEGER
            ,"timestamp" INTEGER
            ,"clearFlag" BOOLEAN NOT NULL DEFAULT 0
        )
;

CREATE
    INDEX "index_model_OWSRecall_on_uniqueId"
        ON "model_OWSRecall"("uniqueId"
)
;

CREATE
    INDEX "index_recall_on_existsRecallMessage"
        ON "model_OWSRecall"("originalTimestamp", "originalSource", "originalSourceDevice"
)
;

CREATE
    INDEX "index_recall_on_duplicateRecallMessage"
        ON "model_OWSRecall"("timestamp", "source", "sourceDevice"
)
;

CREATE
    INDEX "index_recall_on_editable"
        ON "model_OWSRecall"("editable"
)
;

CREATE
    INDEX "index_recall_on_clearFlag"
        ON "model_OWSRecall"("clearFlag"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_TSAttachment" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"attachmentSchemaVersion" INTEGER
            ,"attachmentType" INTEGER
            ,"byteCount" INTEGER
            ,"cachedAudioDurationSeconds" INTEGER
            ,"cachedImageHeight" INTEGER
            ,"cachedImageWidth" INTEGER
            ,"contentType" TEXT
            ,"creationTimestamp" Double
            ,"digest" BLOB
            ,"encryptedDatalength" INTEGER
            ,"encryptionKey" BLOB
            ,"isDownloaded" BOOLEAN
            ,"isUploaded" BOOLEAN
            ,"lazyRestoreFragmentId" TEXT
            ,"localRelativeFilePath" TEXT
            ,"mostRecentFailureLocalizedText" TEXT
            ,"relay" TEXT
            ,"serverAttachmentId" TEXT
            ,"serverId" INTEGER
            ,"sourceFilename" TEXT
            ,"state" INTEGER
            ,"albumId" TEXT
            ,"albumMessageId" TEXT
            ,"appearInMediaGallery" BOOLEAN
            ,"decibelSamples" BLOB
        )
;

CREATE
    INDEX "index_model_TSAttachment_on_uniqueId"
        ON "model_TSAttachment"("uniqueId"
)
;

CREATE
    INDEX "index_model_TSAttachment_on_albumId"
        ON "model_TSAttachment"("albumId"
)
;

CREATE
    INDEX "index_model_TSAttachment_on_albumMessageId"
        ON "model_TSAttachment"("albumMessageId"
)
;

CREATE
    INDEX "index_attachment_on_recordType_state"
        ON "model_TSAttachment"("recordType", "state"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_DTPinnedMessage" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"groupId" TEXT
            ,"incomingMessage" BLOB
            ,"outgoingMessage" BLOB
            ,"pinId" TEXT
            ,"realSource" BLOB
            ,"timestampForSorting" INTEGER
        )
;

CREATE
    INDEX "index_model_DTPinnedMessage_on_uniqueId"
        ON "model_DTPinnedMessage"("uniqueId"
)
;

CREATE
    INDEX "index_model_DTPinnedMessage_on_groupId"
        ON "model_DTPinnedMessage"("groupId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_SignalAccountSecondary" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"buName" TEXT
            ,"email" TEXT
            ,"fullName" TEXT
            ,"signature" TEXT
            ,"remarkName" TEXT
        )
;

CREATE
    INDEX "index_model_SignalAccountSecondary_on_uniqueId"
        ON "model_SignalAccountSecondary"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_TSGroupThreadSecondary" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"groupName" TEXT
            ,"lastMessageDate" TEXT
            ,"members" TEXT
        )
;

CREATE
    INDEX "index_model_TSGroupThreadSecondary_on_uniqueId"
        ON "model_TSGroupThreadSecondary"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_TSMessageSecondary" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"display" BOOLEAN
            ,"message" TEXT
            ,"thread" TEXT
            ,"timestamp" TEXT
        )
;

CREATE
    INDEX "index_model_TSMessageSecondary_on_uniqueId"
        ON "model_TSMessageSecondary"("uniqueId"
)
;

CREATE
    VIRTUAL TABLE
        IF NOT EXISTS model_TSMessageSecondary_virtual USING FTS5(
            uniqueId,
            display,
            message,
            thread,
            timestamp,
            content='model_TSMessageSecondary',
            content_rowid='id',
            tokenize='simple'
        )
;

CREATE TRIGGER model_TSMessageSecondary_ai AFTER INSERT ON model_TSMessageSecondary BEGIN
  INSERT INTO model_TSMessageSecondary_virtual(rowid, uniqueId, display, message, timestamp) VALUES (new.id, new.uniqueId, new.display, new.message, new.timestamp);
END;

CREATE TRIGGER model_TSMessageSecondary_ad AFTER DELETE ON model_TSMessageSecondary BEGIN
  INSERT INTO model_TSMessageSecondary_virtual(model_TSMessageSecondary_virtual, rowid, uniqueId, display, message, timestamp) VALUES('delete', old.id, old.uniqueId, old.display, old.message, old.timestamp);
END;

CREATE TRIGGER model_TSMessageSecondary_au AFTER UPDATE ON model_TSMessageSecondary BEGIN
  INSERT INTO model_TSMessageSecondary_virtual(model_TSMessageSecondary_virtual, rowid, uniqueId, display, message, timestamp) VALUES('delete', old.id, old.uniqueId, old.display, old.message, old.timestamp);
  INSERT INTO model_TSMessageSecondary_virtual(rowid, uniqueId, display, message, timestamp) VALUES (new.id, new.uniqueId, new.display, new.message, new.timestamp);
END;

CREATE
    TABLE
        IF NOT EXISTS "model_TSMessageReadPosition" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"maxNotifySequenceId" INTEGER
            ,"maxServerTime" INTEGER
            ,"readAt" INTEGER
            ,"recipientId" TEXT
            ,"uniqueThreadId" TEXT
            ,"creationTimestamp" INTEGER
            ,"updateCount" INTEGER
        )
;

CREATE
    INDEX "index_readPosition_on_uniqueId"
        ON "model_TSMessageReadPosition"("uniqueId"
)
;


CREATE
    INDEX "index_model_TSMessageReadPosition_on_maxServerTime"
        ON "model_TSMessageReadPosition"("maxServerTime"
)
;

CREATE
    INDEX "index_readPosition_on_uniqueThreadId_recipientId"
        ON "model_TSMessageReadPosition"("uniqueThreadId", "recipientId"
)
;

CREATE
    INDEX "index_readPosition_on_recipientId_creationTimestamp"
        ON "model_TSMessageReadPosition"("recipientId", "creationTimestamp"
)
;

CREATE
    INDEX index_model_TSMessageReadPosition_on_readAt
       ON "model_TSMessageReadPosition"("uniqueThreadId", "recipientId", "readAt", "maxServerTime"
)
;


CREATE
    TABLE
        IF NOT EXISTS "model_DTReactionMessage" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"conversationId" TEXT
            ,"emoji" TEXT
            ,"ownSource" BLOB
            ,"source" BLOB
            ,"removeAction" BOOLEAN
            ,"originalUniqueId" TEXT
        )
;

CREATE
    INDEX "index_model_DTReactionMessage_on_uniqueId"
        ON "model_DTReactionMessage"("uniqueId"
)
;

CREATE
    INDEX "index_model_DTReactionMessage_on_originalUniqueId"
        ON "model_DTReactionMessage"("originalUniqueId"
)
;


CREATE
    TABLE
        IF NOT EXISTS "model_OWSRecipientIdentity" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"createdAt" DOUBLE
            ,"identityKey" BLOB
            ,"isFirstKnownKey" BOOLEAN
            ,"recipientId" TEXT
            ,"verificationState" INTEGER
        )
;

CREATE
    INDEX "index_model_OWSRecipientIdentity_on_uniqueId"
        ON "model_OWSRecipientIdentity"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_OWSDevice" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"createdAt" DOUBLE
            ,"deviceId" INTEGER
            ,"lastSeenAt" Double
            ,"name" TEXT
        )
;

CREATE
    INDEX "index_model_OWSDevice_on_uniqueId"
        ON "model_OWSDevice"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_DTCardMessageEntity" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"appId" TEXT NOT NULL
            ,"cardId" TEXT NOT NULL
            ,"content" TEXT NOT NULL
            ,"contentType" INTEGER NOT NULL DEFAULT 0
            ,"creator" TEXT
            ,"fixedWidth" BOOLEAN NOT NULL DEFAULT 0
            ,"timestamp" INTEGER NOT NULL DEFAULT 0
            ,"version" INTEGER NOT NULL DEFAULT 0
        )
;

CREATE
    INDEX "index_model_DTCardMessageEntity_on_uniqueId"
        ON "model_DTCardMessageEntity"("uniqueId"
)
;

CREATE TABLE model_TSInteraction_archived AS SELECT * FROM model_TSInteraction WHERE 0;

CREATE
    INDEX "index_model_TSInteraction_archived_on_uniqueId"
        ON "model_TSInteraction_archived"("uniqueId"
)
;

CREATE
    TABLE
        IF NOT EXISTS "model_ResetIdentifyKeyRecord" (
            "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL
            ,"recordType" INTEGER NOT NULL
            ,"uniqueId" TEXT NOT NULL UNIQUE
                ON CONFLICT FAIL
            ,"operatorId" TEXT NOT NULL
            ,"resetIdentifyKeyTime" INTEGER NOT NULL DEFAULT 0
            ,"isCompleted" BOOLEAN NOT NULL DEFAULT 0
            ,"createdAt" DOUBLE NOT NULL
        )
;

CREATE
    INDEX "index_model_ResetIdentifyKeyRecord_on_uniqueId"
        ON "model_ResetIdentifyKeyRecord"("uniqueId"
)
;
