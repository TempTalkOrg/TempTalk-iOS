//
//  DTCallManager.swift
//  TTServiceKit
//
//  Created by Ethan on 11/06/2024.
//

import Foundation
import Mantle

public extension DTCallManager {
    
    func getLiveToken(channelName: String,
                      eid: String,
                      completion: @escaping(Result<[AnyHashable: Any], Error>) -> Void) {
        
        guard let url = URL(string: OWSRequestFactory.LiveRTCChannelTokenPath_V1), !channelName.isEmpty else {
            return
        }
        
        let request = TSRequest(url: url,
                                method: HTTPMethod.get.methodName,
                                parameters: ["channelName": channelName,
                                             "eid": eid])
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                
                if let responseBodyJson = response.responseBodyJson {
                    Logger.debug("\(self.logTag) getLiveToken response:\(responseBodyJson)")
                }

                do {
                    let responseEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                                  fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as? DTAPIMetaEntity
                    
                    guard let responseEntity else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, 
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    guard responseEntity.status == 0 else {
                        let error = NSError(domain: "com.liveStreamDomain",
                                            code: responseEntity.status,
                                            userInfo: [NSLocalizedDescriptionKey: responseEntity.reason]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(responseEntity.data))
                } catch _ {
                    
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                }
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }
    
    
    /// 直播开始(暂时只有mac可以开始直播)
    /// - Parameters:
    ///   - channelName: channelName
    ///   - completion: 完成回调
    func postLiveStart(channelName: String,
                       completion: @escaping(Result<Void, Error>) -> Void) {
        
        guard let url = URL(string: OWSRequestFactory.LiveStartPath_V1), !channelName.isEmpty else {
            return
        }
        
        let request = TSRequest(url: url,
                                method: HTTPMethod.post.methodName,
                                parameters: ["channelName": channelName])
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                do {
                    let responseEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                                  fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as? DTAPIMetaEntity
                    
                    guard let responseEntity else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    guard responseEntity.status == 0 else {
                        let error = NSError(domain: "com.meetingStreamDomain",
                                            code: responseEntity.status,
                                            userInfo: [NSLocalizedDescriptionKey: responseEntity.reason]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(()))
                } catch _ {
                    
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                }
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }

    func setLiveUserRole(uid: String,
                         role: LiveStreamRole,
                         channelName: String,
                         completion: @escaping(Result<Void, Error>) -> Void) {
        
        guard !uid.isEmpty && !channelName.isEmpty else {
            return
        }
        
        guard let url = URL(string: OWSRequestFactory.LiveSetRolePath_V1), !uid.isEmpty else {
            return
        }
        
        let stringRole = (role == .broadcaster ? "broadcaster" : "audience")
        let request = TSRequest(url: url,
                                method: HTTPMethod.put.methodName,
                                parameters: ["uid": uid,
                                             "channelName": channelName,
                                             "role": stringRole])
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                do {
                    let responseEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                                  fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as? DTAPIMetaEntity
                    
                    guard let responseEntity else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    guard responseEntity.status == 0 else {
                        let error = NSError(domain: "com.meetingDomain",
                                            code: responseEntity.status,
                                            userInfo: [NSLocalizedDescriptionKey: responseEntity.reason]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(()))
                } catch _ {
                    
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                }
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }

    func getLiveAudiences(channelName: String,
                          completion: @escaping(Result<[[AnyHashable: Any]], Error>) -> Void) {
        
        guard let url = URL(string: OWSRequestFactory.LiveRTCChannelTokenPath_V1), !channelName.isEmpty else {
            return
        }
        
        let request = TSRequest(url: url,
                                method: HTTPMethod.get.methodName,
                                parameters: ["channelName": channelName])
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                do {
                    let responseEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                                  fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as? DTAPIMetaEntity
                    
                    guard let responseEntity else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    guard responseEntity.status == 0 else {
                        let error = NSError(domain: "com.meetingDomain",
                                            code: responseEntity.status,
                                            userInfo: [NSLocalizedDescriptionKey: responseEntity.reason]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    guard let audiences = responseEntity.data["audiences"] as? [[AnyHashable: Any]] else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(audiences))
                } catch _ {
                    
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                }
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }
    
    
    /// 1on1会议结束上报(可变消息推送)
    /// - Parameters:
    ///   - channelName: channelName
    ///   - reason: canceled / missed / refused
    ///   - cardId: cardId
    ///   - completion: completion
    func postPrivateCallEnd(channelName: String,
                            reason: String,
                            cardId: String,
                       completion: @escaping(Result<Void, Error>) -> Void) {
        
        guard let url = URL(string: OWSRequestFactory.MeetingPrivateEnd_V1), 
                !channelName.isEmpty,
                !reason.isEmpty,
                !cardId.isEmpty else {
            return
        }
        
        let request = TSRequest(url: url,
                                method: HTTPMethod.post.methodName,
                                parameters: [
                                    "channelName": channelName,
                                    "reason" : reason,
                                    "cardId" : cardId
                                ])
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                
                guard let responseBodyJson = response.responseBodyJson as? [AnyHashable: Any], let reason = responseBodyJson["reason"] as? String, let status = responseBodyJson["status"] as? Int else {
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                    return
                }
                
                guard status == 0 else {
                    let error = NSError(domain: "com.meetingDomain",
                                        code: status,
                                        userInfo: [NSLocalizedDescriptionKey: reason]
                    )
                    completion(.failure(error))
                    return
                }
                
                completion(.success(()))
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }

    func getCentrifugoToken(type: Int,
                            channelName: String?,
                            completion: @escaping(Result<[AnyHashable: Any], Error>) -> Void) {
        
        guard let url = URL(string: OWSRequestFactory.MeetingCenRTMTokenPath_V1) else {
            return
        }
        
        var parameters = ["type": type] as [String: Any]
        if let channelName {
            parameters["channelName"] = channelName
        }
        
        let request = TSRequest(url: url,
                                method: HTTPMethod.post.methodName,
                                parameters: parameters)
        request.shouldHaveAuthorizationHeaders = false
        
        getMeetingAuthSuccess { authToken in
            request.authToken = authToken
            self.meetingUrlSession().performNonmainRequest(request) { response in
                
                if let responseBodyJson = response.responseBodyJson {
                    Logger.debug("\(self.logTag) getCenRtmToken response:\(responseBodyJson)")
                }

                do {
                    let responseEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                                  fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as? DTAPIMetaEntity
                    
                    guard let responseEntity else {
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                               kDTAPIDataErrorDescription)
                        completion(.failure(error))
                        return
                    }
                    guard responseEntity.status == 0 else {
                        let error = NSError(domain: "com.liveStreamDomain",
                                            code: responseEntity.status,
                                            userInfo: [NSLocalizedDescriptionKey: responseEntity.reason]
                        )
                        completion(.failure(error))
                        return
                    }
                    
                    completion(.success(responseEntity.data))
                } catch _ {
                    
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                           kDTAPIDataErrorDescription)
                    completion(.failure(error))
                }
            } failure: { error in
                completion(.failure(error.asNSError))
            }
        } failure: { error in
            completion(.failure(error))
        }

    }

    
}
