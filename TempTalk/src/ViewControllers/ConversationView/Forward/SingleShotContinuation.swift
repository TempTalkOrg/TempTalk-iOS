//
//  SingleShotContinuation.swift
//  Difft
//
//

import Foundation
import TTServiceKit

final class SingleShotContinuation<T>: @unchecked Sendable {

    private let continuation: CheckedContinuation<T, Error>
    private let lock = NSLock()
    private var fired = false

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: T) {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else {
            Logger.error("[SingleShotContinuation] ignored duplicate resume(returning:) — OC callback contract violated")
            return
        }
        fired = true
        continuation.resume(returning: value)
    }

    func resume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else {
            Logger.error("[SingleShotContinuation] ignored duplicate resume(throwing:) — OC callback contract violated: \(error)")
            return
        }
        fired = true
        continuation.resume(throwing: error)
    }
}

extension SingleShotContinuation where T == Void {
    func resume() { resume(returning: ()) }
}
