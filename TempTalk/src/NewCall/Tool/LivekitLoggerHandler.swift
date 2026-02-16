//
//  LivekitLoggerHandler.swift
//  Difft
//
//  Created by Henry on 2025/4/22.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit
internal import LiveKitWebRTC
import OSLog

typealias LivekitLogger = LiveKit.Logger
typealias LivekitLogLevel = LiveKit.LogLevel

extension LivekitLogLevel {
    @inlinable
    var ddLogFlag: DDLogFlag {
        switch self {
        case .debug: .info
        case .info: .info
        case .warning: .warning
        case .error: .error
        }
    }
    
    var rtcSeverity: LKRTCLoggingSeverity {
        switch self {
        case .debug: .verbose
        case .info: .info
        case .warning: .warning
        case .error: .error
        }
    }
}

extension LKRTCLoggingSeverity {
    var ddLogFlag: DDLogFlag {
        switch self {
        case .verbose: .info
        case .info: .info
        case .warning: .warning
        case .error: .error
        case .none: .debug
        @unknown default:
                .debug
        }
    }
}

open class OSLogger: LivekitLogger, @unchecked Sendable {
    private let minLevel: LogLevel
    
    private var rtcLogger: LKRTCCallbackLogger?
    
    public init(minLevel: LogLevel = .debug, webrtc: Bool = false) {
        self.minLevel = minLevel
        
        guard webrtc else { return }

        rtcLogger = LKRTCCallbackLogger()
        rtcLogger?.severity = minLevel.rtcSeverity
        rtcLogger?.start { message, severity in
            let cleanMessage = message.trimmingCharacters(in: .newlines)
            Logger.log("[WebRTC] \(cleanMessage)", flag: severity.ddLogFlag, file: "", function: "", line: 0)
        }
    }
    
    deinit {
        rtcLogger?.stop()
    }
    
    public func log(
        _ message: @autoclosure () -> CustomStringConvertible,
        _ level: LogLevel,
        source _: @autoclosure () -> String?,
        file: StaticString,
        type: Any.Type,
        function: StaticString,
        line: UInt,
        metaData: ScopedMetadataContainer,
        ptr: String? = nil
    ) {
        guard level >= minLevel else { return }

        let message = message().description

        func buildScopedMetadataString() -> String {
            guard !metaData.isEmpty else { return "" }
            return " [\(metaData.map { "\($0): \($1)" }.joined(separator: ", "))]"
        }

        let metadata = buildScopedMetadataString()
        let ptr = ptr ?? String(describing: Unmanaged.passUnretained(self as AnyObject).toOpaque())

        Logger.log("[\(type).\(ptr)] \(message)\(metadata)", flag: level.ddLogFlag, file: String(describing: file), function: String(describing: function), line: Int(line))
    }
}
