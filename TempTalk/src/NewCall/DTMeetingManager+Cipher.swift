//
//  DTMeetingManager+Cipher.swift
//  Signal
//
//  Created by Ethan on 26/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import DTProto
import LiveKit

extension DTMeetingManager {
    
    func loadSessionRecords(identifiers: [String]) async -> [String: DTSessionRecord] {
        return await withCheckedContinuation { continuation in
           
            var records = [String: DTSessionRecord]()
            databaseStorage.asyncRead { transaction in
                identifiers.forEach({
                    let record = SessionStore.loadSession(identifier: $0, transaction: transaction)
                    records[$0] = record
                })
            } completion: {
                continuation.resume(returning: records)
            }
        }
    }
    
    func encryptKeyResult(sessionRecords: [String: DTSessionRecord], mKey: Data?) -> DTEncryptedKeyResult? {
       
        var pubIdKeys = [String: Data]()
        sessionRecords.forEach {
            pubIdKeys[$0] = $1.remoteIdentityKey
        }
        
        do {
            let result = try DTProtoAdapter().encryptKey(
                version: MESSAGE_CURRENT_VERSION,
                pubIdKeys: pubIdKeys,
                mKey: mKey
            )
            return result
        } catch {
            Logger.error("encryptKey error: \(error.localizedDescription)")
            return nil
        }
        
    }
    
    
    /// 判断本地是否有记录, 没有记录的identifiers从接口获取
    /// - Parameter identifiers: identifiers
    func requestPublicKeysIfNeed(identifiers: [String]) async {
        assert(!identifiers.isEmpty)

        // TODO: call throw exception
        do {
            let sessions = try await SessionFetcher.fetchSessions(identifiers: identifiers)
            if !sessions.isEmpty {
                databaseStorage.write { [self] wTransaction in
                    messageSender.storeSessions(prekeyBundles: sessions, transaction: wTransaction)
                }
            }
        } catch {
            Logger.error("requestPublicKeys error:\(error.localizedDescription)")
        }

    }
    
    
    /// 保存start call/controlmessags时返回的stale
    /// - Parameter prekeys: prekeys
    func storeFreshPrekeys(_ prekeys: [[String: Any]], completion: @escaping () -> Void) {
        do {
            let sessions = try MTLJSONAdapter.models(
                of: DTPrekeyBundle.self,
                fromJSONArray: prekeys
            ) as? [DTPrekeyBundle]
            if let sessions, !sessions.isEmpty {
                databaseStorage.write { [self] wTransaction in
                    messageSender.storeSessions(prekeyBundles: sessions, transaction: wTransaction)
                }
            }
            completion()
        } catch {
            let errorDesc = "prekeyBundles to model error!"
            OWSLogger.error(errorDesc)
        }
    }

    func parseCipherMessages(_ dictArray: [[String: Any]]) -> [Livekit_TTCipherMessages] {
        return dictArray.compactMap { dict in
            var msg = Livekit_TTCipherMessages()
            
            if let content = dict["content"] as? String {
                msg.content = content
            }
            if let uid = dict["uid"] as? String {
                msg.uid = uid
            }
            if let regID = dict["registrationId"] as? Int {
                msg.registrationID = Int32(regID)
            } else if let regID = dict["registrationId"] as? Int32 {
                msg.registrationID = regID
            } else if let regID = dict["registrationId"] as? String, let intVal = Int32(regID) {
                msg.registrationID = intVal
            }
            
            return msg
        }
    }
    
    func parseEncInfoArray(_ dictArray: [[String: Any]]) -> [Livekit_TTEncInfo] {
        return dictArray.compactMap { dict in
            var info = Livekit_TTEncInfo()
            
            if let uid = dict["uid"] as? String {
                info.uid = uid
            }
            if let emk = dict["emk"] as? String {
                info.emk = emk
            }
            
            return info
        }
    }
}
