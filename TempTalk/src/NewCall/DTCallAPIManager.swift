//
//  DTCallAPIManager.swift
//  Signal
//
//  Created by Ethan on 13/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import Mantle

enum DTCallEndpoint {
    
    case startMeeting(type: CallType,
                      version: Int32,
                      roomId: String?,
                      conversation: String?,
                      publicKey: String?,
                      encInfos: [[String: Any]]?,
                      encMeta: [String: Any]?,
                      timestamp: UInt64,
                      notification: [String: Any]?,
                      cipherMessages: [[String: Any]]?)
    
    case inviteToCall(roomId: String,
                      publicKey: String,
                      encInfos: [[String: Any]],
                      timestamp: UInt64,
                      notification: [String: Any],
                      cipherMessages: [[String: Any]])
    
    case callList
    
    case controlMessage(roomId: String?,
                        clientCallId: String?,
                        msgType: DTCallMessageType,
                        timestamp: UInt64,
                        cipherMessages: [[String: Any]],
                        forceEndGroupMeeting: Bool = false,
                        callType: CallType = .instant)
    
    case checkCall(roomId: String)

    var method: HTTPMethod {
        switch self {
        case .startMeeting: .post
        case .inviteToCall: .post
        case .callList: .get
        case .controlMessage: .post
        case .checkCall: .get
        }
    }

    var path: String {
        switch self {
        case .startMeeting:
            return "v3/call/start"
        case .inviteToCall:
            return "v3/call/invite"
        case .callList:
            return "v3/call"
        case .controlMessage:
            return "v3/call/controlmessages"
        case .checkCall:
            return "v3/call/check"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case.startMeeting(let type,
                          let version,
                          let roomId,
                          let conversation,
                          let publicKey,
                          let encInfos,
                          let encMeta,
                          let timestamp,
                          let notification,
                          let cipherMessages):
            var params = ["type": type.rawValue,
                          "version": version,
                          "timestamp": timestamp,
            ] as [String : Any]
            
            if let roomId {
                params["roomId"] = roomId
            }
            if let conversation {
                params["conversation"] = conversation
            }
            if let publicKey {
                params["publicKey"] = publicKey
            }
            if let encInfos {
                params["encInfos"] = encInfos
            }
            if let encMeta {
                params["encMeta"] = encMeta
            }
            if let notification {
                params["notification"] = notification
            }
            if let cipherMessages {
                params["cipherMessages"] = cipherMessages
            }
            return params
        case .inviteToCall(let roomId,
                           let publicKey,
                           let encInfos,
                           let timestamp,
                           let notification,
                           let cipherMessages):
            return ["roomId": roomId,
                    "publicKey": publicKey,
                    "encInfos": encInfos,
                    "timestamp": timestamp,
                    "notification": notification,
                    "cipherMessages": cipherMessages]
        case .controlMessage(let roomId,
                             let clientCallId,
                             let msgType,
                             let timestamp,
                             let cipherMessages,
                             let forceEndGroupMeeting,
                             let callType):

            var params = ["timestamp": timestamp,
                          "cipherMessages": cipherMessages] as [String : Any]

            if let roomId, !roomId.isEmpty {
                params["roomId"] = roomId
            }
            if let clientCallId, !clientCallId.isEmpty {
                params["clientCallId"] = clientCallId
            }

            let detailMessageType: Int
            if forceEndGroupMeeting && msgType == .hangup && callType != .private {
                Logger.info("[newcall] controlMessage End Group Meeting")
                detailMessageType = 1002
            } else if [.cancel, .reject, .hangup].contains(msgType) {
                Logger.info("[newcall] controlMessage Leave Group Meeting callType \(callType)")
                detailMessageType = callType == .private ? 1001 : 0
            } else {
                Logger.info("[newcall] controlMessage other callType \(callType)")
                detailMessageType = 0
            }
            params["detailMessageType"] = detailMessageType
            
            return params
        case .checkCall(let roomId):
            return ["roomId": roomId]
        default:
            return nil
        }
    }
    
    var request: TSRequest? {
  
        guard let url = URL(string: path) else {
            return nil
        }
        return TSRequest(url: url,
                         method: method.methodName,
                         parameters: parameters)
    }
    
}

/// Result of a call/check probe.
/// `unknown` means the probe itself failed (transport/decode) and says nothing about the room.
enum CallRoomAvailability {
    case valid(anotherDeviceJoined: Bool, userStopped: Bool)
    case gone
    case unknown
}

struct DTCallAPIManager {

    /// Error domain for a server-returned business status (not a transport failure).
    static let serverStatusErrorDomain = "com.temptalk.call.serverStatus"
    
    var callUrlSession: OWSURLSession {
        OWSSignalService.signalService.urlSessionForCallService()
    }
    
    let domain = "com.temptalk.call"
    let logTag = "[DTCallAPIManager]"
    
    
    /// call相关request
    /// - Parameters:
    ///   - endpoint: endpoint
    ///   - maxRetryCount: 重试次数
    /// - Returns: Result
    func sendRequest(endpoint: DTCallEndpoint, maxRetryCount: Int = 3) async -> Result<Dictionary<String, AnyCodable>?, Error> {
        var attempt = 0
        
        while attempt < maxRetryCount {
            do {
                let token = try await requestAuthToken()
                let metaData = try await sendMetaRequestWithAuth(endpoint: endpoint, authToken: token)
                guard metaData.status == 0 || metaData.status == 11001 else {
                    let error = NSError(domain: Self.serverStatusErrorDomain,
                                        code: metaData.status,
                                        userInfo: [NSLocalizedDescriptionKey: metaData.reason])
                    throw error
                }

                return .success(metaData.data)
            } catch {
                attempt += 1
                let asNSError = error as NSError
                Logger.error("\(logTag) \(endpoint.path) attempt \(attempt) error: \(asNSError.localizedDescription)")

                if attempt == maxRetryCount {
                    return .failure(asNSError)
                }

                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            }
        }

        let error = NSError(domain: domain,
                            code: -10999,
                            userInfo: [NSLocalizedDescriptionKey: "retry upper limit."])
        return .failure(error)

    }

    private func sendMetaRequest(endpoint: DTCallEndpoint, maxRetryCount: Int = 3) async -> Result<APIMetaData, Error> {
        var attempt = 0

        while attempt < maxRetryCount {
            do {
                let token = try await requestAuthToken()
                let result = try await sendMetaRequestWithAuth(endpoint: endpoint, authToken: token)
                
                return .success(result)
            } catch {
                attempt += 1
                let asNSError = error as NSError
                Logger.error("\(logTag) \(endpoint.path) attempt \(attempt) error: \(asNSError.localizedDescription)")
                
                if attempt == maxRetryCount {
                    return .failure(asNSError)
                }
                
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            }
        }
        
        let error = NSError(domain: domain,
                            code: -10999,
                            userInfo: [NSLocalizedDescriptionKey: "retry upper limit."])
        return .failure(error)
        
    }
        
    private func sendMetaRequestWithAuth(endpoint: DTCallEndpoint, authToken: String? = nil) async throws -> APIMetaData {
        
        guard let request = endpoint.request else {
            throw NSError(domain: "\(domain).request",
                                code: -10001,
                                userInfo: [NSLocalizedDescriptionKey: "url invalid"])
        }
        request.authToken = authToken
        request.serverType = .call
        
        return try await withCheckedThrowingContinuation { continuation in
            SSKEnvironment.shared.networkManagerRef.makeRequest(request, success: { response in
                guard let responseBodyData = response.responseBodyData else {
                    let error = NSError(domain: "\(domain).response",
                                        code: -10002,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid response body"])
                    continuation.resume(throwing: error)
                    return
                }

                do {
                    let metaData = try JSONDecoder().decode(APIMetaData.self, from: responseBodyData)
                    continuation.resume(returning: metaData)
                } catch {
                    let error = NSError(domain: "\(domain).response",
                                        code: -10003,
                                        userInfo: [NSLocalizedDescriptionKey: "Response decode error"])
                    continuation.resume(throwing: error)
                }
                
            }, failure: { error in
                continuation.resume(throwing: error.asNSError)
            });
        }
        
    }
    
    /// 获取token
    /// - Returns: authToken
    private func requestAuthToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let token {
                    continuation.resume(returning: token)
                } else {
                    let invalidError = NSError(domain: "\(domain).token",
                                      code: -10000,
                                      userInfo: [NSLocalizedDescriptionKey: "token invalid"])
                    continuation.resume(throwing: invalidError)
                }
            }
        }
    }
    
}

extension DTCallAPIManager {

    /// 启动/回前台是同步sever calls
    /// - Returns: calls
    func getActiveCallList() async throws -> [[String: Any]] {
        let result = await DTCallAPIManager().sendRequest(endpoint: .callList)
        switch result {
        case .success(let data):
            guard let calls = data?["calls"]?.value as? [[String: Any]] else {
                throw NSError(
                    domain: "\(domain).response",
                    code: -10004,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid active call list response"]
                )
            }
            return calls
        case .failure(let error):
            throw error
        }
    }
    
    /// 发送call消息
    func controlCallMessage(
        roomId: String?,
        clientCallId: String?,
        msgType: DTCallMessageType,
        cipherMessages: [[String: Any]],
        forceEndGroupMeeting: Bool = false,
        callType: CallType = .instant
    ) async -> Dictionary<String, AnyCodable> {

        let hasRoomId = roomId?.isEmpty == false
        let hasClientCallId = clientCallId?.isEmpty == false
        guard hasRoomId || hasClientCallId else {
            Logger.error("sendCallMessageError: roomId and clientCallId are both empty")
            return [:]
        }

        let timestamp = DTTrustedClock.clientStampMs()
        let endpoint: DTCallEndpoint = .controlMessage(
            roomId: roomId,
            clientCallId: clientCallId,
            msgType: msgType,
            timestamp: timestamp,
            cipherMessages: cipherMessages,
            forceEndGroupMeeting: forceEndGroupMeeting,
            callType: callType
        )
        
        let result = await sendRequest(endpoint: endpoint)
        switch result {//stale
        case .success(let data):
            guard let data, !data.isEmpty else {
                return [:]
            }
            
            return data
        case .failure(let error as NSError):
            Logger.error(
                "\(logTag) control message failed: msgType=\(msgType), " +
                "hasClientCallId=\(hasClientCallId), hasRoomId=\(hasRoomId), " +
                "error=\(error.code) - \(error.localizedDescription)"
            )
            return [:]
        }
        
    }
    
    func inviteToCall(roomId: String,
                      publicKey: String,
                      encInfos: [[String: Any]],
                      timestamp: UInt64,
                      notification: [String: Any],
                      cipherMessages: [[String: Any]]) async -> [String: AnyCodable] {
        
        let timestamp = Date.ows_millisecondTimestamp()
        let endpoint: DTCallEndpoint = .inviteToCall(
            roomId: roomId,
            publicKey: publicKey,
            encInfos: encInfos,
            timestamp: timestamp,
            notification: notification,
            cipherMessages: cipherMessages
        )
        let result = await sendRequest(endpoint: endpoint)
        switch result {
        case .success(let data):
            guard let data else {
                return [:]
            }
            
            return data
        case .failure(let error as NSError):
            Logger.error("\(logTag) invite to call error: \(error.localizedDescription)")
            return [:]
        }

    }
    
    /// Probe whether a room is still available on the server.
    /// - Returns: `.valid` when check-call returns status 0; `.gone` when check-call returns any
    ///            non-zero status; `.unknown` when the probe fails (auth/transport/decode) and the
    ///            room state cannot be inferred — callers must NOT treat `.unknown` as invalid.
    func checkRoomAvailability(_ roomId: String) async -> CallRoomAvailability {

        let result = await sendMetaRequest(endpoint: .checkCall(roomId: roomId))
        switch result {
        case .success(let metaData):
            // Match sendRequest's success whitelist: 0 and 11001 are both non-error statuses.
            // Only a status outside that set means the room is genuinely gone.
            guard metaData.status == 0 || metaData.status == 11001 else {
                Logger.info("\(logTag) roomId=\(roomId) gone status=\(metaData.status) reason=\(metaData.reason)")
                return .gone
            }

            let data = metaData.data
            guard let data else {
                return .valid(anotherDeviceJoined: false, userStopped: false)
            }
            var anotherDeviceJoined = false, userStopped = false
            if let tempJoined = data["anotherDeviceJoined"],
               let joined = tempJoined.value as? Bool {
                anotherDeviceJoined = joined
            }
            if let tempStopped = data["userStopped"],
               let stopped = tempStopped.value as? Bool {
                userStopped = stopped
            }

            Logger.info("\(logTag) roomId=\(roomId) valid anotherDeviceJoined=\(anotherDeviceJoined) userStopped=\(userStopped)")

            return .valid(anotherDeviceJoined: anotherDeviceJoined, userStopped: userStopped)
        case .failure(let error as NSError):
            Logger.error("\(logTag) roomId=\(roomId) unknown, probe failed: \(error.localizedDescription)")
            return .unknown
        }
    }

    /// 检查roomId是否可用(兼容旧调用方,`.gone`/`.unknown` 都塌为 nil)
    /// - Returns: 返回为nil roomId无效;返回不为nil roomId有效
    func checkRoomIdValid(_ roomId: String) async -> (anotherDeviceJoined: Bool, userStopped: Bool)? {
        switch await checkRoomAvailability(roomId) {
        case .valid(let anotherDeviceJoined, let userStopped):
            return (anotherDeviceJoined: anotherDeviceJoined, userStopped: userStopped)
        case .gone, .unknown:
            return nil
        }
        
    }

    func queryIdentity(_ uids: [String]) async throws -> Result<[DTPrekeyBundle], Error> {
       
        assert(uids.isEmpty == false)
      
        return try await withCheckedThrowingContinuation { continuation in
            DTQueryIdentityKeyApi().quertIdentity(uids, resetIdentityKeyTime: 0) { response in
                guard let responseObject = response.responseBodyJson as? [String: Any],
                      let data = responseObject["data"] as? [String: Any],
                      let keys = data["keys"] as? [[String: Any]] else {
                    let error = NSError(domain: "\(domain).queryIdentity",
                                        code: -10000,
                                        userInfo: [NSLocalizedDescriptionKey: "Invalid response data"])
                    continuation.resume(with: .success(.failure(error)))
                    return
                }
                do {
                    let identityKeys = try MTLJSONAdapter.models(of: DTPrekeyBundle.self, fromJSONArray: keys) as? [DTPrekeyBundle]
                    continuation.resume(with: .success(.success(identityKeys ?? [])))
                } catch {
                    continuation.resume(with: .success(.failure(error)))
                }
            } failure: { error, _ in
                continuation.resume(with: .success(.failure(error)))
            }
        }
        
    }

}

struct APIMetaData: Codable {
    
    var ver: Int
    var reason: String
    var status: Int
    var data: [String: AnyCodable]?
}

struct AnyCodable: Codable {
    let value: Any?

    init(_ value: Any?) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = nil
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictionaryValue = try? container.decode([String: AnyCodable].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if value == nil {
            try container.encodeNil()
        } else if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let arrayValue = value as? [Any?] {
            try container.encode(arrayValue.map { AnyCodable($0) })
        } else if let dictionaryValue = value as? [String: Any?] {
            try container.encode(dictionaryValue.mapValues { AnyCodable($0) })
        } else {
            throw EncodingError.invalidValue(value as Any, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}
