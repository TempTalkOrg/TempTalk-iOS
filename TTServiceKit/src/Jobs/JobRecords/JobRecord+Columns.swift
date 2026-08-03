//
// Copyright 2024 Difft. All rights reserved.
//
//

import Foundation
import GRDB

extension JobRecord {
    /// All columns in the `model_SSKJobRecord` table.
    public enum JobRecordColumns: String, CodingKey, ColumnExpression, CaseIterable {

        // MARK: GRDB columns
        case id
        case recordType
        case uniqueId

        // MARK: Base columns
        case failureCount
        case label
        case status

        // MARK: Job-type columns
        case attachmentIdMap
        case contactThreadId
        case envelopeData
        case invisibleMessage
        case messageId
        case removeMessageAfterSending
        case threadId

        // MARK: Future-proof columns (Signal later migrations, added upfront)
        case exclusiveProcessIdentifier
        case isHighPriority
        case isMediaMessage
    }
}
