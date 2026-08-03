//
//  DTGIFSearchAPI.swift
//  TempTalk
//
//  GIF keyword search (proxy over GIPHY).
//

import Foundation
import TTServiceKit

enum DTGIFSearchError: Error {
    case assertionError(description: String)
    case fetchFailure
}

class DTGIFSearchAPI: DTBaseAPI {

    override var requestMethod: String {
        get { "GET" }
        set { super.requestMethod = newValue }
    }

    override var requestUrl: String {
        get { return "/v1/gifs/search" }
        set { super.requestUrl = newValue }
    }

    override init() {
        super.init()
        self.serverType = .GIF
    }

    func request(query: String, limit: Int, offset: Int?, next: String?) -> Promise<DTGIFSearchResult> {
        return firstly {
            DTTokenHelper.sharedInstance.fetchGlobalAuthToken()
        }.then { token in
            self.requestGIF(
                token: token,
                query: query,
                limit: limit,
                offset: offset,
                next: next
            )
        }
    }

    private func requestGIF(token: String, query: String, limit: Int, offset: Int?, next: String?) -> Promise<DTGIFSearchResult> {
        guard let url = URL(string: requestUrl), !query.isEmpty, !token.isEmpty else {
            return Promise(error: OWSErrorWithCodeDescription(.invalidMethodParameters, "Invalid parameters."))
        }

        var parameters: [String: Any] = [
            "q": query,
            "limit": limit,
            "lang": Locale.current.languageCode ?? "en"
        ]
        if let offset {
            parameters["offset"] = offset
        } else if let next {
            parameters["next"] = next
        } else {
            // First page: send neither offset nor next.
        }
        let request = TSRequest(
            url: url,
            method: requestMethod,
            parameters: parameters
        )
        request.authToken = token
        request.shouldHaveAuthorizationHeaders = true

        return Promise { future in
            let urlSession = OWSSignalService.signalService.urlSessionForGIF()
            urlSession.performNonmainRequest(request) { response in
                do {
                    let responseEntity = try MTLJSONAdapter.model(
                        of: DTAPIMetaEntity.self,
                        fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]
                    ) as? DTAPIMetaEntity

                    guard let responseEntity, responseEntity.status == 0 else {
                        let error = NSError(
                            domain: "com.temptalk.gifs.search",
                            code: responseEntity?.status ?? -1003,
                            userInfo: [NSLocalizedDescriptionKey: responseEntity?.reason ?? .empty]
                        )
                        future.reject(error)
                        return
                    }

                    guard let result = try MTLJSONAdapter.model(of: DTGIFSearchResult.self, fromJSONDictionary: responseEntity.data) as? DTGIFSearchResult else {
                        let error = NSError(
                            domain: "com.temptalk.gifs.search",
                            code: -1004,
                            userInfo: [NSLocalizedDescriptionKey: "convert model failed"]
                        )
                        future.reject(error)
                        return
                    }

                    future.resolve(result)

                } catch _ {
                    let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription)
                    future.reject(error)
                }

            } failure: { error in
                future.reject(error.asNSError)
            }
        }
    }
}
