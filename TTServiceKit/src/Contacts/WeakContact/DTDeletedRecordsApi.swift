//
//  DTDeletedRecordsApi.swift
//  TTServiceKit
//
//  /v3/friend/deletedRecords — GET pulls the full pending-removal set (reconcile,
//  flow ④); DELETE /:uid removes one immediately (remove-now, flow ③). Server-idempotent.
//

import Foundation

@objc
public class DTDeletedRecordsApi: DTBaseAPI {

    private static let basePath = "/v3/friend/deletedRecords"

    /// GET: full pending-removal set, anchored to the response `serverTimestamp` + device monotonic clock.
    func fetchDeletedRecords() async throws -> [DTWeakContactRecord] {
        guard let url = URL(string: Self.basePath) else {
            throw NSError(domain: "DTDeletedRecordsApi", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let request = TSRequest(url: url, method: "GET", parameters: [:])
        request.shouldHaveAuthorizationHeaders = true
        request.authToken = try await DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken()

        let response = try await networkManager.asyncRequest(request)
        guard let json = response.responseBodyJson as? [AnyHashable: Any] else {
            throw NSError(domain: "DTDeletedRecordsApi", code: 1100,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        let status = (json["status"] as? NSNumber)?.intValue ?? -1
        guard status == 0 else {
            let reason = json["reason"] as? String ?? "status \(status)"
            throw NSError(domain: "DTDeletedRecordsApi", code: status,
                          userInfo: [NSLocalizedDescriptionKey: reason])
        }

        let serverNowRaw = (json["serverTimestamp"] as? NSNumber)?.int64Value
        if serverNowRaw == nil {
            Logger.error("[WeakContact] deletedRecords missing serverTimestamp; countdown anchored to device clock")
        }
        let serverNow = serverNowRaw ?? Int64(NSDate.ows_millisecondTimeStamp())
        let uptime = ProcessInfo.processInfo.systemUptime
        let items = json["data"] as? [[AnyHashable: Any]] ?? []
        Logger.info("[WeakContact] deletedRecords parsed count=\(items.count) anchor=\(serverNow)")

        return items.compactMap { item in
            guard let uid = item["uid"] as? String, !uid.isEmpty else { return nil }
            return DTWeakContactRecord(
                uid: uid,
                reason: (item["reason"] as? NSNumber)?.intValue ?? 0,
                name: item["name"] as? String,
                avatar: item["avatar"] as? String,
                deleteTime: (item["deleteTime"] as? NSNumber)?.int64Value,
                expireAt: (item["expireTime"] as? NSNumber)?.int64Value ?? 0,
                serverNowAtRecord: serverNow,
                uptimeAtRecord: uptime
            )
        }
    }

    /// DELETE /:uid: remove one pending-removal record immediately. Idempotent.
    public func removeDeletedRecord(uid: String) async throws {
        let encoded = uid.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? uid
        guard let url = URL(string: "\(Self.basePath)/\(encoded)") else {
            throw NSError(domain: "DTDeletedRecordsApi", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        let request = TSRequest(url: url, method: "DELETE", parameters: [:])
        request.shouldHaveAuthorizationHeaders = true
        request.authToken = try await DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken()

        let response = try await networkManager.asyncRequest(request)
        guard let entity = try MTLJSONAdapter.model(
            of: DTAPIMetaEntity.self,
            fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]
        ) as? DTAPIMetaEntity else {
            throw NSError(domain: "DTDeletedRecordsApi", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response entity"])
        }

        guard entity.status == 0 else {
            throw NSError(domain: "DTDeletedRecordsApi", code: entity.status,
                          userInfo: [NSLocalizedDescriptionKey: entity.reason])
        }
    }
}
