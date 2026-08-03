//
//  DTGIFTrendingAPI.swift
//  TempTalk
//
//  GIF trending list (proxy over GIPHY).
//

import Foundation
import TTServiceKit

class DTGIFTrendingAPI: DTBaseAPI {

    override var requestMethod: String {
        get { "GET" }
        set { super.requestMethod = newValue }
    }

    override var requestUrl: String {
        get { return "/v1/gifs/trending" }
        set { super.requestUrl = newValue }
    }

    override init() {
        super.init()
        self.serverType = .GIF
    }

    func request(limit: Int, offset: Int?, next: String?) -> Promise<DTGIFSearchResult> {
        return firstly {
            self.requestAuthToken()
        }.then { token in
            self.requestGIF(
                token: token,
                limit: limit,
                offset: offset,
                next: next
            )
        }
    }

    private func requestGIF(token: String, limit: Int, offset: Int?, next: String?) -> Promise<DTGIFSearchResult> {
        guard let url = URL(string: requestUrl), !token.isEmpty else {
            return Promise(error: OWSErrorWithCodeDescription(.invalidMethodParameters, "Invalid parameters."))
        }

        var parameters: [String: Any] = ["limit": limit]
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
                            domain: "com.temptalk.gifs.trending",
                            code: responseEntity?.status ?? -1003,
                            userInfo: [NSLocalizedDescriptionKey: responseEntity?.reason ?? .empty]
                        )
                        future.reject(error)
                        return
                    }

                    guard let result = try MTLJSONAdapter.model(of: DTGIFSearchResult.self, fromJSONDictionary: responseEntity.data) as? DTGIFSearchResult else {
                        let error = NSError(
                            domain: "com.temptalk.gifs.trending",
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

    private func requestAuthToken() -> Promise<String> {
        Promise { future in
            DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
                guard let token, error == nil else {
                    let err = NSError(
                        domain: "com.temptalk.gifs.trending",
                        code: -10002,
                        userInfo: [NSLocalizedDescriptionKey: "token invalid"]
                    )
                    future.reject(err)
                    return
                }
                future.resolve(token)
            }
        }
    }
}
