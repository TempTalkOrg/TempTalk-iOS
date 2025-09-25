//
//  DTTokenHelper.swift
//  TTServiceKit
//
//  Created by Jaymin on 2024/12/30.
//

import Foundation

@objcMembers
public class DTTokenHelper: NSObject {
    
    private enum Constants {
        static let globalAuthToken = "authTokenEntity"
    }
    
    @objc
    public static let sharedInstance = DTTokenHelper()
    
    public override class func logTag() -> String {
        "[DTTokenHelper]"
    }
    
    private var globalTokenEnity: DTTokenEntity?
    
    /// 是否已经缓存了全局通用 token
    @objc
    public func isLogged() -> Bool {
        return getAuthTokenFromLocalCache(appId: "") != nil
    }
    
    /// 同步获取 appId 对应的 token，先从本地缓存获取，若没有或缓存过期，再从网络获取（会阻塞当前线程，直到请求完成）
    /// - Note: appId 不能为空
    @objc
    public func syncFetchAuthTokenForApplication(appId: String) -> String? {
        guard !appId.isEmpty else {
            Logger.error("\(self.logTag) syncFetchAuthToken failed, appId is empty")
            return nil
        }
        
        if let tokenEntityCache = getAuthTokenFromLocalCache(appId: appId), !tokenEntityCache.isExpired {
            return tokenEntityCache.authToken
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var token: String?
        var error: NSError?
        requestAuthToken(appId: appId) { authToken, requestError in
            if let authToken {
                token = authToken
            } else {
                error = requestError
            }
            semaphore.signal()
        }
        // 等待请求完成
        semaphore.wait()
        
        if let token {
            Logger.info("\(self.logTag) Successfully fetched authToken")
            return token
        } else {
            Logger.error("\(self.logTag) Failed to fetch authToken: \(error?.localizedDescription ?? "")")
            return nil
        }
    }
    
    /// 异步获取全局 token，先从本地缓存获取，若没有或缓存过期，再从网络获取
    @objc
    public func asyncFetchGlobalAuthToken(completion: @escaping (String?, NSError?) -> Void) {
        asyncFetchAuthToken(appId: "", completion: completion)
    }
    
    /// 异步获取 appId 对应的 token，先从本地缓存获取，若没有或缓存过期，再从网络获取
    @objc
    public func asyncFetchAuthToken(appId: String, completion: @escaping (String?, NSError?) -> Void) {
        if let tokenEntity = globalTokenEnity, !tokenEntity.isExpired {
            // 如果内存中的 token 有效，直接返回
            Logger.info("\(self.logTag) Using token from memory for appId: \(appId)")
            if appId.isEmpty {
                TSAccountManager.sharedInstance().authtoken = tokenEntity.authToken
            }
            completion(tokenEntity.authToken, nil)
            return
        }
        
        guard let tokenEntity = getAuthTokenFromLocalCache(appId: appId) else {
            Logger.info("\(self.logTag) There is no local token cache, fetch token for appId: \(appId)")
            requestAuthToken(appId: appId, completion: completion)
            return
        }
        
        // 过期重新获取 token
        guard !tokenEntity.isExpired else {
            Logger.info("\(self.logTag) The local token cache is expired, fetch token for appId: \(appId)")
            requestAuthToken(appId: appId, completion: completion)
            return
        }
        
        // appId 为空表示获取的是 app 通用 token
        if appId.isEmpty {
            TSAccountManager.sharedInstance().authtoken = tokenEntity.authToken
        }
        // 能正确获取缓存就保存一份到内存
        globalTokenEnity = tokenEntity
        completion(tokenEntity.authToken, nil)
    }
    
    /// 异步获取全局 token (Promise 版本)
    public func fetchGlobalAuthToken() -> Promise<String> {
        return fetchAuthToken(appId: "")
    }
    
    /// 异步获取 appId 对应的 token (Promise 版本)
    public func fetchAuthToken(appId: String) -> Promise<String> {
        return Promise { [weak self] future in
            guard let self else { return }
            self.asyncFetchAuthToken(appId: appId) { token, error in
                guard let token, !token.isEmpty else {
                    if let error {
                        future.reject(error)
                    } else {
                        let error = NSError(
                            domain: "AuthTokenError",
                            code: -20000,
                            userInfo: [NSLocalizedDescriptionKey: "token is empty"]
                        )
                        future.reject(error)
                    }
                    return
                }
                future.resolve(token)
            }
        }
    }
    
    /// 请求 auth token
    private func requestAuthToken(appId: String, completion: @escaping (String?, NSError?) -> Void) {
        Logger.info("\(self.logTag) Request authToken for appId: \(appId)")
        
        let request = OWSRequestFactory.userStateWSTokenAuthRequest(withAppId: appId)
        self.networkManager.makeRequest(request) { [weak self] response in
            guard let self else { return }
            let responseObj = response.responseBodyJson
            Logger.debug("\(self.logTag) appid = \(appId), response = \(responseObj ?? "")")
            
            guard let responseDic = responseObj as? [String: Any], let status = responseDic["status"] as? Int else {
                let error = NSError(domain: "AuthTokenError", code: -20000, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                completion(nil, error)
                return
            }
            
            guard status == 0 else {
                let reason = (responseDic["reason"] as? String) ?? "Unknown error"
                let error = NSError(domain: "AuthTokenError", code: status, userInfo: [NSLocalizedDescriptionKey: reason])
                completion(nil, error)
                return
            }
            
            guard let data = responseDic["data"] as? [String: Any], let token = data["token"] as? String, !token.isEmpty else {
                let error = NSError(domain: "AuthTokenError", code: -20000, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                completion(nil, error)
                return
            }
            
            // 缓存 token
            self.cacheAuthToken(token, appId: appId)
            
            completion(token, nil)
            
        } failure: { error in
            completion(nil, error.asNSError)
        }
    }
    
    /// 删除全局通用的 token 缓存
    @objc
    public func removeGlobalAuthTokenFormLocalCache() {
        DTTokenKeychainStore.setPassword("", forAccount: Constants.globalAuthToken)
    }
    
    /// 根据 appId 删除本地缓存的 token（为了和之前实现方式对齐，这里只能删除指定 appId 的 token，不支持删除全局的 token）
    @objc
    public func removeAuthTokenFromLocalCache(appId: String) {
        guard !appId.isEmpty else {
            Logger.error("\(self.logTag) remove auth token failed, appId is empty")
            return
        }
        DTTokenKeychainStore.setPassword("", forAccount: appId)
    }
    
    /// 根据 appId 获取本地缓存的 token，如果 appId 为空，则获取全局通用的 token 缓存
    private func getAuthTokenFromLocalCache(appId: String) -> DTTokenEntity? {
        let key = appId.isEmpty ? Constants.globalAuthToken : appId
        guard let json = DTTokenKeychainStore.loadPassword(withAccountKey: key), !json.isEmpty else {
            return nil
        }
        guard let result = DTTokenEntity.signal_model(withJSON: json) else {
            return nil
        }
        return result
    }
    
    /// 缓存 token，如果 appId 为空，则缓存全局 token
    private func cacheAuthToken(_ token: String, appId: String) {
        Logger.info("\(self.logTag) cache auth token for appId: \(appId)")
        
        TSAccountManager.sharedInstance().authtoken = token
        
        guard let dict = decodeJWTString(token), let tokenEntity = DTTokenEntity.signal_model(with: dict) else {
            Logger.error("\(self.logTag) cache auth token failed for appId: \(appId), reason: decode jwt string failed")
            return
        }
        let localCurrentTime = Date().timeIntervalSince1970
        let expTimeInterval = tokenEntity.exp.doubleValue - tokenEntity.iat.doubleValue
        tokenEntity.expLocalTime = Int(localCurrentTime + expTimeInterval)
        tokenEntity.authToken = token
        globalTokenEnity = tokenEntity
        guard let tokenEntityJson = tokenEntity.signal_modelToJSONString() else {
            Logger.error("\(self.logTag) cache auth token failed for appId: \(appId), reason: convert model to json failed")
            return
        }
        Logger.debug("\(self.logTag) cache auth token for appId: \(appId), tokenEntityJson: \(tokenEntityJson)")
        
        if appId.isEmpty {
            DTTokenKeychainStore.setPassword(tokenEntityJson, forAccount: Constants.globalAuthToken)
        } else {
            DTTokenKeychainStore.setPassword(tokenEntityJson, forAccount: appId)
        }
    }
    
    /// 解码 JWT String
    private func decodeJWTString(_ jwtString: String) -> [String: Any]? {
        let segments = jwtString.components(separatedBy: ".")
        guard segments.count == 3 else {
            Logger.error("\(self.logTag) Invalid format JWT string: \(jwtString)")
            return nil
        }
        
        let payloadSegment = segments[1]
        
        var base64String = String(payloadSegment)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // 补充 Base64 的 "=" 以使长度符合要求
        while base64String.count % 4 != 0 {
            base64String.append("=")
        }
        
        guard let data = Data(base64Encoded: base64String) else {
            Logger.error("\(self.logTag) Base64 string encode failed, string: \(base64String)")
            return nil
        }
        
        guard let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []) else {
            Logger.error("\(self.logTag) Json serialization failed, string: \(base64String)")
            return nil
        }
        
        guard let result = jsonObj as? [String: Any] else {
            Logger.error("\(self.logTag) Json serialization failed, string: \(base64String)")
            return nil
        }
        
        return result
    }
}

extension DTTokenEntity {
    
    static let safeTimeInterval: TimeInterval = 60 * 2
    
    // token 是否过期了
    var isExpired: Bool {
        // 设置弹性安全时间，防止 token 临近过期，在执行后续动作过程中过期了
        let localCurrentTime = Date().timeIntervalSince1970 + Self.safeTimeInterval
        return localCurrentTime >= Double(expLocalTime)
    }
}

fileprivate extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
