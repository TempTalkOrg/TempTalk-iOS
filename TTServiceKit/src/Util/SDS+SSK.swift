//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

// Any enum used by SDS extensions must be declared to conform
// to Codable and DatabaseValueConvertible.

extension TSOutgoingMessageState: Codable { }
extension TSOutgoingMessageState: DatabaseValueConvertible { }

extension TSErrorMessageType: Codable { }
extension TSErrorMessageType: DatabaseValueConvertible { }

extension TSInfoMessageType: Codable { }
extension TSInfoMessageType: DatabaseValueConvertible { }

extension OWSVerificationState: Codable { }
extension OWSVerificationState: DatabaseValueConvertible { }

extension TSGroupMetaMessage: Codable { }
extension TSGroupMetaMessage: DatabaseValueConvertible { }

extension TSAttachmentType: Codable { }
extension TSAttachmentType: DatabaseValueConvertible { }

//add
extension SDSRecordType: Codable { }
extension SDSRecordType: DatabaseValueConvertible { }

extension DTApnsMessageType: Codable { }
extension DTApnsMessageType: DatabaseValueConvertible { }

extension TSGroupChatMode: Codable { }
extension TSGroupChatMode: DatabaseValueConvertible { }

extension DTMeetingReminderType: Codable { }
extension DTMeetingReminderType: DatabaseValueConvertible { }

extension TSWhisperMessageType: Codable { }
extension TSWhisperMessageType: DatabaseValueConvertible { }

extension TSMessageModeType: Codable { }
extension TSMessageModeType: DatabaseValueConvertible { }

extension DTFolderType: Codable { }
extension DTFolderType: DatabaseValueConvertible { }

extension DTGroupNotifyAction: Codable { }
extension DTGroupNotifyAction: DatabaseValueConvertible { }

extension DSKProtoDataMessageTaskPriority: Codable { }
extension DSKProtoDataMessageTaskPriority: DatabaseValueConvertible { }

extension DSKProtoDataMessageTaskStatus: Codable { }
extension DSKProtoDataMessageTaskStatus: DatabaseValueConvertible { }

extension DSKProtoDataMessageVoteStatus: Codable { }
extension DSKProtoDataMessageVoteStatus: DatabaseValueConvertible { }

extension TSAttachmentPointerState: Codable { }
extension TSAttachmentPointerState: DatabaseValueConvertible { }

extension OWSMentionedMsgType: Codable { }
extension OWSMentionedMsgType: DatabaseValueConvertible { }
