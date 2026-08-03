//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Adapter conformance — makes the fork's existing transaction types satisfy the
// new V2-style ``DBReadTransaction``/``DBWriteTransaction`` protocols. With this in
// place, ported Signal-iOS code that takes ``DBReadTransaction``/``DBWriteTransaction``
// can be invoked with the existing ``SDSAnyReadTransaction``/``SDSAnyWriteTransaction``
// values without any boilerplate at the call site.
//

import Foundation
import GRDB

extension SDSAnyReadTransaction: DBReadTransaction {
    public var database: GRDB.Database {
        return unwrapGrdbRead.database
    }

    public var asSDSRead: SDSAnyReadTransaction {
        return self
    }
}

extension SDSAnyWriteTransaction: DBWriteTransaction {
    public var asSDSWrite: SDSAnyWriteTransaction {
        return self
    }

    // ``addSyncCompletion(_:)`` is already defined on ``SDSAnyWriteTransaction``
    // with the same signature, so no additional implementation is required for
    // protocol conformance.
}
