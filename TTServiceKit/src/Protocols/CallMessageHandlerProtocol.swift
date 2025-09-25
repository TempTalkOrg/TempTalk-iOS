//
//  CallMessageHandlerProtocol.swift
//  TTServiceKit
//
//  Created by undefined on 27/12/24.
//

import Foundation

@objc public protocol CallMessageHandlerProtocol: NSObjectProtocol {
    
    @objc func handleIncoming(envelope: DSKProtoEnvelope,
                                     callMessage: DSKProtoCallMessage,
                                     transaction: SDSAnyWriteTransaction)
}
