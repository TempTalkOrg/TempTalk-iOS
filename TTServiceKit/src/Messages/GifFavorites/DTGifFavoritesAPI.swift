//
//  DTGifFavoritesAPI.swift
//  TTServiceKit
//
//  GET/PUT /gifs/v1/gifs/favorites — encrypted favorites list transport.
//  Reuses urlSessionForGIF() + global auth token, same as search/trending.
//

import Foundation

public enum FavoritesAPIError: Error {
    case invalidResponse
    case server(status: Int, reason: String)
}

public final class DTGifFavoritesAPI {

    private static let path = "/v1/gifs/favorites"

    public init() {}

    public func getFavorites() async throws -> FavoritesResponse {
        let token = try await DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken()
        guard let url = URL(string: Self.path) else { throw FavoritesAPIError.invalidResponse }
        let request = TSRequest(url: url, method: "GET", parameters: nil)
        request.authToken = token
        request.shouldHaveAuthorizationHeaders = true
        return try await send(request)
    }

    public func putFavorites(_ body: FavoritesPutRequest) async throws -> FavoritesResponse {
        let token = try await DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken()
        guard let url = URL(string: Self.path) else { throw FavoritesAPIError.invalidResponse }
        let request = TSRequest(url: url, method: "PUT", parameters: try Self.parameters(from: body))
        request.authToken = token
        request.shouldHaveAuthorizationHeaders = true
        return try await send(request)
    }

    // MARK: - Private

    private func send(_ request: TSRequest) async throws -> FavoritesResponse {
        let response: HTTPResponse = try await withCheckedThrowingContinuation { continuation in
            let urlSession = OWSSignalService.signalService.urlSessionForGIF()
            urlSession.performNonmainRequest(request) { response in
                continuation.resume(returning: response)
            } failure: { error in
                continuation.resume(throwing: error.asNSError)
            }
        }

        guard let json = response.responseBodyJson as? [AnyHashable: Any] else {
            throw FavoritesAPIError.invalidResponse
        }
        // Common envelope: { ver, status, reason, data }
        let status = (json["status"] as? Int) ?? -1
        let reason = (json["reason"] as? String) ?? ""
        guard status == 0 else {
            throw FavoritesAPIError.server(status: status, reason: reason)
        }
        guard let dataObject = json["data"] else {
            throw FavoritesAPIError.invalidResponse
        }
        let data = try JSONSerialization.data(withJSONObject: dataObject)
        return try JSONDecoder().decode(FavoritesResponse.self, from: data)
    }

    private static func parameters(from body: FavoritesPutRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(body)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FavoritesAPIError.invalidResponse
        }
        return dict
    }
}
