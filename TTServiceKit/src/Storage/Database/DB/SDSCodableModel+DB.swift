//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// V2-style ``DBReadTransaction``/``DBWriteTransaction`` overload bridges for
// ``SDSCodableModel``. Existing call sites that pass ``SDSAnyReadTransaction``/
// ``SDSAnyWriteTransaction`` continue to work as before; new code (such as the
// Job framework) can pass the new abstract transaction protocols and have them
// automatically forward to the legacy SDS implementation.
//
// ## Why this layer?
//
// In Signal-iOS V2, ``SDSCodableModel`` was rewritten to take ``DBReadTransaction``/
// ``DBWriteTransaction`` directly. We can't make that change in this fork without
// rewriting every existing model. Instead, we add overload pairs that accept the
// V2-style protocols and unwrap to the legacy SDS types via the bridge methods
// ``DBReadTransaction.asSDSRead`` / ``DBWriteTransaction.asSDSWrite``.
//
// Only the surface area actually consumed by ported V2 code (Job framework, etc.)
// is bridged here; bridging more is YAGNI.
//

import Foundation

public extension SDSCodableModel {

    static func anyFetch(uniqueId: String, transaction: DBReadTransaction) -> Self? {
        return anyFetch(uniqueId: uniqueId, transaction: transaction.asSDSRead)
    }

    func anyInsert(transaction: DBWriteTransaction) {
        anyInsert(transaction: transaction.asSDSWrite)
    }

    func anyUpsert(transaction: DBWriteTransaction) {
        anyUpsert(transaction: transaction.asSDSWrite)
    }

    func anyOverwritingUpdate(transaction: DBWriteTransaction) {
        anyOverwritingUpdate(transaction: transaction.asSDSWrite)
    }

    func anyRemove(transaction: DBWriteTransaction) {
        anyRemove(transaction: transaction.asSDSWrite)
    }
}

public extension SDSCodableModel where Self: AnyObject {
    /// V2-protocol overload of ``anyUpdate(transaction:block:)``.
    func anyUpdate(transaction: DBWriteTransaction, block: (Self) -> Void) {
        anyUpdate(transaction: transaction.asSDSWrite, block: block)
    }
}
