//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Ported from Signal-iOS @ ad9893d (SignalServiceKit/Storage/Database/SDSDatabaseStorage/V2/DBTransaction.swift)
// Adapted: Signal-iOS V2 declares DBReadTransaction as a concrete @objc class that replaces
// SDSAnyReadTransaction. This fork still uses SDSAnyReadTransaction throughout, so we instead
// define DBReadTransaction as a protocol that existing transaction types can conform to.
//

import Foundation
import GRDB

/// Protocol marking a read-only database transaction.
///
/// Code that should work with both reads and writes accepts ``DBReadTransaction``;
/// code that requires write capability accepts ``DBWriteTransaction``.
///
/// ## Bridging to existing SDS types
///
/// While the long-term goal is to migrate the fork to V2-style transactions, today
/// every read/write goes through ``SDSAnyReadTransaction``/``SDSAnyWriteTransaction``.
/// This protocol bridges the new abstraction to the existing types via:
///
/// - ``database`` — direct GRDB ``Database`` access for ported V2 code that queries SQL.
/// - ``asSDSRead`` — escape hatch for callers that still need to interact with
///   legacy SDS APIs such as `anyInsert(transaction:)` or `anyFetch(uniqueId:transaction:)`.
public protocol DBReadTransaction: AnyObject {
    /// The underlying GRDB ``Database`` instance for direct SQL access.
    var database: GRDB.Database { get }

    /// Bridge to the legacy SDS read transaction. Use this when invoking existing
    /// SDS APIs that haven't been migrated to the new abstraction yet.
    var asSDSRead: SDSAnyReadTransaction { get }
}
