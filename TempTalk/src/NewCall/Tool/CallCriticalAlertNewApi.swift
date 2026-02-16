//
//  CallCriticalAlertNewApi.swift
//  Difft
//
//  Created by henry on 2026/01/29.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation

/// 目标用户信息
@objc
public class CriticalAlertDestination: NSObject {
    let number: String
    let timestamp: UInt64

    @objc
    public init(number: String, timestamp: UInt64) {
        self.number = number
        self.timestamp = timestamp
        super.init()
    }

    func toDictionary() -> [String: Any] {
        return [
            "number": number,
            "timestamp": timestamp
        ]
    }
}

/// 群组信息
@objc
public class CriticalAlertGroup: NSObject {
    let gid: String
    let timestamp: UInt64

    @objc
    public init(gid: String, timestamp: UInt64) {
        self.gid = gid
        self.timestamp = timestamp
        super.init()
    }

    func toDictionary() -> [String: Any] {
        return [
            "gid": gid,
            "timestamp": timestamp
        ]
    }
}

/// Critical Alert New API 响应数据
@objc
public class CriticalAlertNewResponseData: NSObject {
    let result: Bool
    let delivers: [String]

    init?(dictionary: [String: Any]) {
        guard let result = dictionary["result"] as? Bool else {
            return nil
        }
        self.result = result
        self.delivers = dictionary["delivers"] as? [String] ?? []
        super.init()
    }
}

@objc
public class CallCriticalAlertNewApi: DTBaseAPI {

    override init() {
        super.init()
    }

    public override var requestMethod: String {
        get {
            return "POST"
        }
        set {
            super.requestMethod = newValue
        }
    }

    public override var requestUrl: String {
        get {
            return "/v3/messages/criticalAlertNew"
        }
        set {
            super.requestUrl = newValue
        }
    }

    /// 发送 Critical Alert New 请求
    /// - Parameters:
    ///   - destinations: 目标用户列表（1on1 or instant or group会议邀请群外人员时传）
    ///   - group: 群组信息（group时传）
    ///   - roomId: 房间ID（用于限频及获取会议中的成员）
    ///   - success: 成功回调
    ///   - failure: 失败回调
    func criticalAlertNewServers(
        destinations: [CriticalAlertDestination]?,
        group: CriticalAlertGroup?,
        roomId: String,
        success: @escaping ((DTAPIMetaEntity?, CriticalAlertNewResponseData?) -> Void),
        failure: ((Error, DTAPIMetaEntity?) -> Void)? = nil
    ) {
        guard let url = URL(string: self.requestUrl) else {
            return
        }

        // 构建请求参数
        var params: [String: Any] = [
            "roomId": roomId
        ]

        // 添加 destinations 参数
        if let destinations = destinations, !destinations.isEmpty {
            params["destinations"] = destinations.map { $0.toDictionary() }
        }

        // 添加 group 参数
        if let group = group {
            params["group"] = group.toDictionary()
        }
        
        // 参数验证
        guard DTParamsUtils.validateDictionary(params).boolValue == true else {
            if let failure = failure {
                failure(DTErrorWithCodeDescription(.invalidParameter, kDTAPIParamsErrorDescription), nil)
            }
            return
        }

        let request = TSRequest(url: url, method: self.requestMethod, parameters: params)
        request.shouldHaveAuthorizationHeaders = true

        self.networkManager.makeRequest(request, success: { response in
            do {
                guard let entity = try MTLJSONAdapter.model(
                    of: DTAPIMetaEntity.self,
                    fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]
                ) as? DTAPIMetaEntity else {
                    guard let failure = failure else { return }
                    failure(DTErrorWithCodeDescription(.dataError, kDTAPIDataErrorDescription), nil)
                    return
                }

                if entity.status != 0 {
                    guard let failure = failure else { return }
                    let error = NSError(
                        domain: "criticalAlertNew",
                        code: entity.status,
                        userInfo: [NSLocalizedDescriptionKey: entity.reason]
                    )
                    failure(error, entity)
                } else {
                    // 解析 data 字段
                    var responseData: CriticalAlertNewResponseData?
                    if let dataDict = entity.data as? [String: Any] {
                        responseData = CriticalAlertNewResponseData(dictionary: dataDict)
                    }
                    success(entity, responseData)
                }
            } catch {
                guard let failure = failure else { return }
                failure(DTErrorWithCodeDescription(.dataError, kDTAPIDataErrorDescription), nil)
            }
        }, failure: { errorWrapper in
            guard let failure = failure else { return }

            // 处理 413 频率限制错误
            if errorWrapper.error.httpStatusCode == 413 {
                DTToastHelper.toast(withText: Localized("MEETING_CRITICAL_ALERT_FREQUENTLY"), durationTime: 2.0)
                return
            }

            let error = errorWrapper.asNSError
            failure(error, nil)
        })
    }
}
