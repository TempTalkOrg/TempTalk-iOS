//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Ported from Signal-iOS @ ad9893d (SignalServiceKit/Storage/Database/SDSDatabaseStorage/V2/DB.swift)
// Adapted:
//   - Removed project-specific surface area (`touch(interaction:)`, `touch(thread:)`, `touch(storyMessage:)`)
//     to keep the protocol decoupled from this fork's domain types. The Job framework only needs
//     read/write/asyncRead/asyncWrite/awaitableWrite.
//   - Removed `throws(E)` typed-throws syntax (Swift 6) to remain compatible with the fork's
//     Swift 5.9 toolchain. Plain `throws` is used instead.
//   - Removed `writeWithRollbackIfThrows`/`awaitableWriteWithRollbackIfThrows`. The Jobs framework
//     does not currently use them; they can be added later if a future client requires rollback semantics.
//

import Foundation

/// A database protocol that abstracts over the concrete storage implementation.
///
/// The Job framework (and any future infrastructure that wants to be storage-agnostic and
/// testable in isolation) talks to ``DB`` rather than directly to ``SDSDatabaseStorage``.
/// Production code uses an adapter that forwards to ``SDSDatabaseStorage``; tests can
/// substitute an in-memory implementation.
public protocol DB: AnyObject {

    // MARK: - Sync read/write

    func read<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBReadTransaction) -> T
    ) -> T

    func read<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBReadTransaction) throws -> T
    ) throws -> T

    func write<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBWriteTransaction) -> T
    ) -> T

    func write<T>(
        file: String,
        function: String,
        line: Int,
        block: (DBWriteTransaction) throws -> T
    ) throws -> T

    // MARK: - Async (callback-based)

    func asyncRead<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBReadTransaction) -> T,
        completionQueue: DispatchQueue,
        completion: ((T) -> Void)?
    )

    func asyncWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) -> T,
        completionQueue: DispatchQueue,
        completion: ((T) -> Void)?
    )

    // MARK: - Awaitable (async/await)

    func awaitableWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) -> T
    ) async -> T

    func awaitableWrite<T>(
        file: String,
        function: String,
        line: Int,
        block: @escaping (DBWriteTransaction) throws -> T
    ) async throws -> T
}

// MARK: - Default arguments

public extension DB {

    func read<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: (DBReadTransaction) -> T
    ) -> T {
        return read(file: file, function: function, line: line, block: block)
    }

    func read<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: (DBReadTransaction) throws -> T
    ) throws -> T {
        return try read(file: file, function: function, line: line, block: block)
    }

    func write<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: (DBWriteTransaction) -> T
    ) -> T {
        return write(file: file, function: function, line: line, block: block)
    }

    func write<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: (DBWriteTransaction) throws -> T
    ) throws -> T {
        return try write(file: file, function: function, line: line, block: block)
    }

    func asyncRead<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: @escaping (DBReadTransaction) -> T,
        completionQueue: DispatchQueue = .main,
        completion: ((T) -> Void)? = nil
    ) {
        asyncRead(file: file, function: function, line: line, block: block, completionQueue: completionQueue, completion: completion)
    }

    func asyncWrite<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: @escaping (DBWriteTransaction) -> T,
        completionQueue: DispatchQueue = .main,
        completion: ((T) -> Void)? = nil
    ) {
        asyncWrite(file: file, function: function, line: line, block: block, completionQueue: completionQueue, completion: completion)
    }

    func awaitableWrite<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: @escaping (DBWriteTransaction) -> T
    ) async -> T {
        return await awaitableWrite(file: file, function: function, line: line, block: block)
    }

    func awaitableWrite<T>(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        block: @escaping (DBWriteTransaction) throws -> T
    ) async throws -> T {
        return try await awaitableWrite(file: file, function: function, line: line, block: block)
    }
}
