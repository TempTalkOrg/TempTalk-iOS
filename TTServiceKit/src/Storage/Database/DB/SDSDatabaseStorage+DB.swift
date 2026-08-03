//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Adapter conformance — makes ``SDSDatabaseStorage`` satisfy the ``DB`` protocol so the
// Job framework (and any other future infrastructure) can be initialized with the
// production database without coupling to ``SDSDatabaseStorage`` directly.
//
// ## Implementation notes
//
// 1. ``SDSDatabaseStorage`` already provides synchronous ``read(block:)``/``write(block:)``
//    and async-callback ``asyncRead``/``asyncWrite`` methods that take the legacy
//    ``SDSAnyReadTransaction``/``SDSAnyWriteTransaction``. We forward through them.
// 2. ``awaitableWrite`` is the only genuinely new surface area. It bridges Swift Concurrency
//    to the existing async-write queue via a ``CheckedContinuation``. The block runs on
//    ``SDSTransactable.asyncWriteQueue`` (the same serial queue used by all writes) and
//    completes the continuation on the calling actor's queue once the transaction is
//    committed.
//

import Foundation

extension SDSDatabaseStorage: DB {

    // MARK: - Sync read/write

    public func read<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBReadTransaction) -> T
    ) -> T {
        return read(file: file, function: function, line: line) { (sdsTransaction: SDSAnyReadTransaction) -> T in
            block(sdsTransaction)
        }
    }

    public func read<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBReadTransaction) throws -> T
    ) throws -> T {
        return try read(file: file, function: function, line: line) { (sdsTransaction: SDSAnyReadTransaction) throws -> T in
            try block(sdsTransaction)
        }
    }

    public func write<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBWriteTransaction) -> T
    ) -> T {
        return write(file: file, function: function, line: line) { (sdsTransaction: SDSAnyWriteTransaction) -> T in
            block(sdsTransaction)
        }
    }

    public func write<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBWriteTransaction) throws -> T
    ) throws -> T {
        return try write(file: file, function: function, line: line) { (sdsTransaction: SDSAnyWriteTransaction) throws -> T in
            try block(sdsTransaction)
        }
    }

    // MARK: - Async (callback-based)

    public func asyncRead<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBReadTransaction) -> T,
        completionQueue: DispatchQueue,
        completion: ((T) -> Void)?
    ) {
        var capturedValue: T!
        asyncRead(
            file: file,
            function: function,
            line: line,
            block: { (sdsTransaction: SDSAnyReadTransaction) in
                capturedValue = block(sdsTransaction)
            },
            completionQueue: completionQueue,
            completion: { completion?(capturedValue) }
        )
    }

    public func asyncWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) -> T,
        completionQueue: DispatchQueue,
        completion: ((T) -> Void)?
    ) {
        var capturedValue: T!
        asyncWrite(
            file: file,
            function: function,
            line: line,
            block: { (sdsTransaction: SDSAnyWriteTransaction) in
                capturedValue = block(sdsTransaction)
            },
            completionQueue: completionQueue,
            completion: { completion?(capturedValue) }
        )
    }

    // MARK: - Awaitable (async/await)

    public func awaitableWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) -> T
    ) async -> T {
        return await withCheckedContinuation { continuation in
            // Capture box for the block's return value. The underlying asyncWrite
            // calls `block` (on the async-write queue) before invoking `completion`
            // (on `completionQueue`), so the box is written before being read.
            var capturedValue: T!
            // Use the legacy fork API (Void-returning block, no-arg completion) so
            // overload resolution doesn't recursively pick this method's own DB
            // protocol declaration.
            self.asyncWrite(
                file: file,
                function: function,
                line: line,
                block: { (sdsTransaction: SDSAnyWriteTransaction) -> Void in
                    capturedValue = block(sdsTransaction)
                },
                completionQueue: .global(),
                completion: {
                    continuation.resume(returning: capturedValue)
                }
            )
        }
    }

    public func awaitableWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            var capturedResult: Result<T, Error>!
            self.asyncWrite(
                file: file,
                function: function,
                line: line,
                block: { (sdsTransaction: SDSAnyWriteTransaction) -> Void in
                    do {
                        capturedResult = .success(try block(sdsTransaction))
                    } catch {
                        capturedResult = .failure(error)
                    }
                },
                completionQueue: .global(),
                completion: {
                    continuation.resume(with: capturedResult)
                }
            )
        }
    }
}
