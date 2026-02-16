//
//  DTGrayReleaseAPI.swift
//  TempTalk
//
//  Created by Henry on 2026-01-12.
//

import Foundation
import TTServiceKit

@objc
public class DTGrayReleaseAPI: DTBaseAPI {

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
            return "/grayCheck/v1/grayCheck"
        }
        set {
            super.requestUrl = newValue
        }
    }
    
    public func fetchGrayConfig(sources: [String]?,
                                success: @escaping (GrayReleaseResponse) -> Void,
                                failure: @escaping (Error) -> Void) {

        guard let url = URL(string: self.requestUrl) else {
            Logger.info("Gray release params abnormal")
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.paramsError,
                                              kDTAPIParamsErrorDescription))
            return
        }

        var parameters: [String: Any] = [:]
        if let sources = sources, !sources.isEmpty {
            parameters["sources"] = sources
        }

        let request: TSRequest = TSRequest(url: url, method: self.requestMethod, parameters: parameters)
        request.shouldHaveAuthorizationHeaders = true
        request.serverType = .root  // Use root serverType for empty path

        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { [weak self] token, error in
            guard let weakSelf = self else {
                Logger.info("Api released")
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.invalidToken,
                                                  kDTAPIParamsErrorDescription))
                return
            }

            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    // Parse the entire response as GrayReleaseResponse
                    if let responseDict = response.responseBodyJson as? [String: Any],
                       let jsonData = try? JSONSerialization.data(withJSONObject: responseDict) {
                        do {
                            let result = try JSONDecoder().decode(GrayReleaseResponse.self, from: jsonData)
                            if result.status != 0 {
                                let error = NSError(domain: "Gray release error", code: result.status,
                                                  userInfo: [NSLocalizedDescriptionKey: result.reason])
                                failure(error)
                            } else {
                                success(result)
                            }
                        } catch {
                            Logger.error("Failed to decode GrayReleaseResponse: \(error)")
                            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                              kDTAPIDataErrorDescription))
                        }
                    } else {
                        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                          kDTAPIDataErrorDescription))
                    }
                } catch {
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                      kDTAPIDataErrorDescription))
                }
            }, failure: { errorWrapper in
                Logger.info("Gray release failure")
                let error = errorWrapper.asNSError
                failure(error)
            })
        }
    }
}

// MARK: - Response Models

@objc
public class GrayReleaseItem: NSObject, Codable {

    /// Feature source key (e.g., "quic")
    @objc public let source: String

    /// Whether the feature is enabled in gray release
    @objc public let isInGray: Bool

    @objc
    public init(source: String, isInGray: Bool) {
        self.source = source
        self.isInGray = isInGray
        super.init()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case source
        case isInGray
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        isInGray = try container.decode(Bool.self, forKey: .isInGray)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encode(isInGray, forKey: .isInGray)
    }
}

@objc
public class GrayReleaseResponse: NSObject, Codable {

    /// API version
    @objc public let ver: Int

    /// Status code (0 = success)
    @objc public let status: Int

    /// Reason message
    @objc public let reason: String

    /// Gray release items
    @objc public let data: [GrayReleaseItem]

    @objc
    public var isSuccess: Bool {
        return status == 0
    }

    @objc
    public init(ver: Int, status: Int, reason: String, data: [GrayReleaseItem]) {
        self.ver = ver
        self.status = status
        self.reason = reason
        self.data = data
        super.init()
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case ver
        case status
        case reason
        case data
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ver = try container.decode(Int.self, forKey: .ver)
        status = try container.decode(Int.self, forKey: .status)
        reason = try container.decode(String.self, forKey: .reason)
        data = try container.decode([GrayReleaseItem].self, forKey: .data)
        super.init()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ver, forKey: .ver)
        try container.encode(status, forKey: .status)
        try container.encode(reason, forKey: .reason)
        try container.encode(data, forKey: .data)
    }
}

