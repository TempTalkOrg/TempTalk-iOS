//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import Foundation
//import PromiseKit
import TTServiceKit

public extension MessageSender {

    /**
     * Wrap message sending in a Promise for easier callback chaining.
     */
    func sendPromise(message: TSOutgoingMessage) -> Promise<Void> {
        let promise: Promise<Void> = Promise { resolver in
            self.enqueue(message, success: { resolver.resolve(()) }, failure: resolver.reject)
        }

        // Ensure sends complete before they're GC'd.
        // This *should* be redundant, since we should be calling retainUntilComplete
        // at all call sites where the promise isn't otherwise retained.
//        promise.retainUntilComplete()

        return promise
    }
}
