//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import TTServiceKit

@objc extension DebugLogger {

    func postLaunchLogCleanup(appContext: MainAppContext) {
        let shouldWipeLogs: Bool = {
            return true
        }()
        
        if shouldWipeLogs {
            wipeLogsAlways(appContext: appContext)
            Logger.warn("Wiped logs")
        }
    }

    func wipeLogsIfDisabled(appContext: MainAppContext) {
        guard !OWSPreferences.isLoggingEnabled() else { return }

        wipeLogsAlways(appContext: appContext)
    }

    func wipeLogsAlways(appContext: MainAppContext) {
        let shouldReEnable = fileLogger != nil
        disableFileLogging()

        // Only the main app can wipe logs because only the main app can access its
        // own logs. (The main app can wipe logs for the other extensions.)
        for dirPath in Self.allLogsDirPaths() {
            do {
                try FileManager.default.removeItem(atPath: dirPath)
            } catch {
                owsFailDebug("Failed to delete log directory: \(error)")
            }
        }

        if shouldReEnable {
            enableFileLogging(appContext: appContext, canLaunchInBackground: true)
        }
    }
}
