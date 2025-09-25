//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

class DebugUICalling: DebugUIPage {

    // MARK: Overrides
    /*

    override func name() -> String {
        return "Calling"
    }

    override func section(thread aThread: TSThread?) -> OWSTableSection? {
        guard let thread = aThread as? TSContactThread else {
            owsFailDebug("Calling is only valid for contact thread, got thread: \(String(describing: aThread))")
            return nil
        }

        let sectionItems = [
            OWSTableItem(title: "Send 'hangup' for old call") { [weak self] in
                guard let strongSelf = self else { return }

                let kFakeCallId = UInt64(12345)
                let hangupMessage = OWSCallHangupMessage(callId: kFakeCallId)
                let callMessage = OWSOutgoingCallMessage(thread: thread, hangupMessage: hangupMessage)

                strongSelf.messageSender.sendPromise(message: callMessage).done {
                    Logger.debug("\(strongSelf.logTag) Successfully sent hangup call message to \(thread.contactIdentifier())")
                }.catch { error in
                    Logger.error("\(strongSelf.logTag) failed to send hangup call message to \(thread.contactIdentifier()) with error: \(error)")
                }
            },
            OWSTableItem(title: "Send 'busy' for old call") { [weak self] in
                guard let strongSelf = self else { return }

                let kFakeCallId = UInt64(12345)
                let busyMessage = OWSCallBusyMessage(callId: kFakeCallId)
                let callMessage = OWSOutgoingCallMessage(thread: thread, busyMessage: busyMessage)

                strongSelf.messageSender.sendPromise(message: callMessage).done {
                    Logger.debug("\(strongSelf.logTag) Successfully sent busy call message to \(thread.contactIdentifier())")
                }.catch { error in
                    Logger.error("\(strongSelf.logTag) failed to send busy call message to \(thread.contactIdentifier()) with error: \(error)")
                }
            }
        ]

        return OWSTableSection(title: "Call Debug", items: sectionItems)
    }
     */
}
