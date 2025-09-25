//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import TTServiceKit

@objc
public class NoopCallMessageHandler: NSObject, CallMessageHandlerProtocol {
    
    public func handleIncoming(envelope: TTServiceKit.DSKProtoEnvelope, callMessage: TTServiceKit.DSKProtoCallMessage, transaction: TTServiceKit.SDSAnyWriteTransaction) {
        
        owsFailDebug("\(self.logTag)")
    }
    
}
