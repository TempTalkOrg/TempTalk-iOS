//
//  CallServiceUrlV2Api.swift
//  Difft
//
//  Created by Henry on 2026/5/7.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
public class CallServiceUrlV2Api: DTBaseAPI {

    override init() {
        super.init()
        self.serverType = .call
    }

    public override var requestMethod: String {
        get { "GET" }
        set { super.requestMethod = newValue }
    }

    public override var requestUrl: String {
        get { "/v3/call/serviceurl/v2" }
        set { super.requestUrl = newValue }
    }

    func fetchServiceUrls(success: @escaping (ServiceUrls) -> Void,
                          failure: @escaping (Error) -> Void) {
        guard let url = URL(string: requestUrl) else {
            Logger.error("[CallServiceUrlV2Api] invalid requestUrl=\(requestUrl)")
            failure(Self.makeError(code: 100_000, message: "invalid requestUrl"))
            return
        }
        let request = TSRequest(url: url, method: requestMethod, parameters: nil)
        request.shouldHaveAuthorizationHeaders = true

        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { [self] token, error in
            if let error {
                Logger.error("[CallServiceUrlV2Api] fetch token failed: \(error.localizedDescription)")
                failure(error)
                return
            }
            request.authToken = token
            self.send(request) { entity in
                if entity.status != 0 {
                    Logger.error("[CallServiceUrlV2Api] server status=\(entity.status) reason=\(entity.reason ?? "nil")")
                    failure(Self.makeError(code: entity.status, message: entity.reason ?? "server error"))
                    return
                }
                guard let dict = entity.data as? [String: Any] else {
                    Logger.error("[CallServiceUrlV2Api] entity.data missing or not dict")
                    failure(Self.makeError(code: 100_002, message: "missing data"))
                    return
                }
                do {
                    let entityTs = entity.serverTimestamp.doubleValue
                    let serverTs: TimeInterval? = entityTs > 0 ? entityTs : nil
                    let parsed = try Self.parseServiceUrls(from: dict, serverTimestamp: serverTs)
                    let pDesc = parsed.primary.map { "\(LogMask.domain($0.domain))(\($0.addrs.count)ip,\($0.region ?? "?"))" } ?? "nil"
                    let fDesc = parsed.fallback.map { "\(LogMask.domain($0.domain))(\($0.addrs.count)ip,\($0.region ?? "?"))" }
                    Logger.info("[CallServiceUrlV2Api] parsed: v=\(parsed.configVersion) ttl=\(parsed.ttl)s primary=\(pDesc) fallback(\(parsed.fallback.count))=\(fDesc.joined(separator: ", "))")
                    success(parsed)
                } catch {
                    Logger.error("[CallServiceUrlV2Api] parse failed: \(error.localizedDescription)")
                    failure(error)
                }
            } failure: { error in
                Logger.error("[CallServiceUrlV2Api] http failed: \(error.localizedDescription)")
                failure(error)
            }
        }
    }

    static func parseServiceUrls(from data: [String: Any], serverTimestamp: TimeInterval?) throws -> ServiceUrls {
        let payload: [String: Any]
        if let dict = data["serviceUrls"] as? [String: Any] {
            payload = dict
        } else if let dict = data["service_urls"] as? [String: Any] {
            payload = dict
        } else {
            throw makeError(code: 100_003, message: "serviceUrls missing or wrong type")
        }

        let json = try JSONSerialization.data(withJSONObject: payload, options: [])
        var parsed: ServiceUrls
        do {
            parsed = try JSONDecoder().decode(ServiceUrls.self, from: json)
        } catch {
            throw makeError(code: 100_004, message: "decode failed: \(error.localizedDescription)")
        }

        // server_time 缺失时用 entity 的兜底
        if parsed.serverTimestamp == nil {
            parsed = ServiceUrls(
                configVersion: parsed.configVersion,
                primary: parsed.primary,
                fallback: parsed.fallback,
                ttl: parsed.ttl,
                serverTimestamp: serverTimestamp
            )
        }
        return parsed
    }

    private static func makeError(code: Int, message: String) -> NSError {
        NSError(domain: "CallServiceUrlV2ApiError",
                code: code,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
