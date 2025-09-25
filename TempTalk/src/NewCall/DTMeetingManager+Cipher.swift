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

}
