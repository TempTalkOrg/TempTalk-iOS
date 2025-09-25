//
//  DTLinkDeviceURLParser.swift
//  Signal
//
//  Created by User on 2023/2/9.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTLinkDeviceURLParser {
    enum LinkError: Swift.Error {
        case unfindKey
        case unfindNumber
    }
    
    private static let deviceIdKey: String = "uuid"
    private static let pubKey: String = "pub_key"
    private static let scheme: String = "tsdevice"
    
    public static let shared = DTLinkDeviceURLParser()
    
    private init() {
    }
    
    private func removeKeyType(_ data: Data) -> Data? {
        guard data.count == 33 else { return data }
        guard let range = Range(NSMakeRange(0, 1)) else {
            return nil
        }
        
        let subData = data.subdata(in: range)
        
        var byte = 0x05
        
        let type = Data(bytes: withUnsafePointer(to: &byte, { $0 }), count: 1)
        
        guard type == subData, let toCutRange = Range(NSMakeRange(1, 32)) else { return nil }

        return data.subdata(in: toCutRange)
    }
    
    func isValidLink(_ urlString: String) -> Bool {
        guard let url = NSURL.init(string: urlString) else {
            return false
        }
        if(url.host == "device/link"){
            return true
        }
       return parse(urlString) != nil
    }
    
    func parse(_ urlString: String) -> (deviceId: String, pubKey: Data)? {
        guard let components = URLComponents(string: urlString), let queryItems = components.queryItems, !queryItems.isEmpty else { return nil }
        
        guard components.scheme == Self.scheme || components.scheme == AppLinkNotificationHandler.kURLSchemeChative || components.scheme == AppLinkNotificationHandler.kURLSchemeTempTalk  else { return nil }
        
        var uuid: String? = nil
        var pubKey: String? = nil
    
        for queryItem in queryItems {
            if queryItem.name == Self.deviceIdKey {
                uuid = queryItem.value
            } else if queryItem.name == Self.pubKey {
                pubKey = queryItem.value
            }
        }
        
        guard let uuid = uuid, let pubKey = pubKey else { return nil }
        
        guard let pubData = Data(base64Encoded: pubKey, options: .ignoreUnknownCharacters), let result = removeKeyType(pubData) else { return nil }
        
        return (deviceId: uuid, pubKey: result)
    }
    
    func linkDevice(deviceId: String, pubKey: Data) -> Promise<Void> {
        
        OWSDeviceManager.shared().setMayHaveLinkedDevices()
        
        guard let identityKeyPair = OWSIdentityManager.shared().identityKeyPair() else {
            return .init(error: LinkError.unfindKey)
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            return .init(error: LinkError.unfindNumber)
        }
        
        return .init { future in
            
            let provisioner = OWSDeviceProvisioner(
                myPublicKey: identityKeyPair.publicKey,
                myPrivateKey: identityKeyPair.ows_privateKey(),
                theirPublicKey: pubKey,
                theirEphemeralDeviceId: deviceId,
                accountIdentifier: localNumber,
                profileKey: OWSProfileManager.shared().localProfileKey().keyData,
                readReceiptsEnabled: OWSReadReceiptManager.shared().areReadReceiptsEnabled()
            )
            
            provisioner.provision {
                future.resolve(())
            } failure: {
                future.reject($0)
            }
        }
    }
}
