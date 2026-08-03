//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Ported from Signal-iOS @ ad9893d (SignalServiceKit/Storage/Database/SDSDatabaseStorage/V2/DBTransaction.swift)
// Adapted: see the note in ``DBReadTransaction``. Same protocol-instead-of-class adaptation
// applies here.
//

import Foundation

/// Protocol marking a read/write database transaction. Inherits all read capabilities
/// from ``DBReadTransaction``.
///
/// Pass to APIs that may insert, update, or delete database rows.
public protocol DBWriteTransaction: DBReadTransaction {
    /// Bridge to the legacy SDS write transaction. Use this when invoking existing
    /// SDS APIs that haven't been migrated to the new abstraction yet.
    var asSDSWrite: SDSAnyWriteTransaction { get }

    /// Schedule a block to run synchronously after the transaction commits.
    /// Mirrors ``SDSAnyWriteTransaction.addSyncCompletion(_:)``.
    func addSyncCompletion(_ block: @escaping () -> Void)
}
