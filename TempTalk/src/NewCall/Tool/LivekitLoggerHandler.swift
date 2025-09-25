//
//  LivekitLoggerHandler.swift
//  Difft
//
//  Created by Henry on 2025/4/22.
//  Copyright © 2025 Difft. All rights reserved.
//

import Logging

// 自定义 LogHandler
struct LivekitLoggerHandler: LogHandler {
    // 元数据存储
    var metadata: Logging.Logger.Metadata = [:]
    // 日志级别
    var logLevel: Logging.Logger.Level = .debug

    // 拦截并处理日志
    func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        Logger.info("[livekit] \(level): \(message.description)")
    }

    // 处理元数据
    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}
