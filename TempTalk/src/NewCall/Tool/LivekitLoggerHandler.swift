//
//  LivekitLoggerHandler.swift
//  Difft
//
//  Created by Henry on 2025/4/22.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit

open class OSLogger: LiveKit.Logger, @unchecked Sendable {
    private static let subsystem = "io.livekit.sdk"

    private let queue = DispatchQueue(label: "io.livekit.oslogger", qos: .utility)

    public func log(
        _ message: @autoclosure () -> CustomStringConvertible,
        _ level: LogLevel,
        source _: @autoclosure () -> String?,
        file _: StaticString,
        type: Any.Type,
        function: StaticString,
        line _: UInt,
        metaData: ScopedMetadataContainer,
        ptr: String? = nil
    ) {
        guard level >= .debug else { return }

        let message = message().description

        func buildScopedMetadataString() -> String {
            guard !metaData.isEmpty else { return "" }
            return " [\(metaData.map { "\($0): \($1)" }.joined(separator: ", "))]"
        }

        let metadata = buildScopedMetadataString()
        let ptr = ptr ?? String(describing: Unmanaged.passUnretained(self as AnyObject).toOpaque())

        queue.async {
            Logger.info("[livekit]: debug: \(type).\(function) [\(ptr)] \(message)\(metadata)")
        }
    }
}
