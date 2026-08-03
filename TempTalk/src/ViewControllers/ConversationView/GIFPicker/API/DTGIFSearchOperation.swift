//
//  DTGIFSearchOperation.swift
//  TempTalk
//
//  Drives one page of GIF search/trending, auto-detecting offset vs next paging.
//

import Foundation
import TTServiceKit

class DTGIFSearchOperation: OWSOperation {

    /// Supports providers with different paging styles.
    /// first: the first page, regardless of provider.
    /// offset: index-based paging.
    /// next: cursor-based paging.
    ///
    /// Rule: first page always uses `.first`; later pages use whichever
    /// (offset or next) the previous response returned.
    enum Page: Equatable {
        case first
        case offset(value: Int)
        case next(value: String)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch(lhs, rhs) {
            case (.first, .first):
                return true
            case let (.offset(lhsValue), .offset(rhsValue)):
                return lhsValue == rhsValue
            case let (.next(lhsValue), .next(rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }

    let page: Page
    let limit: Int
    let query: String?
    let completionOnMainThread: (Swift.Result<(result: DTGIFSearchResult, nextPage: Page?), Error>) -> Void

    private lazy var searchApi = DTGIFSearchAPI()
    private lazy var trendingApi = DTGIFTrendingAPI()

    init(
        page: Page,
        limit: Int = 20,
        query: String?,
        completionOnMainThread: @escaping (Swift.Result<(result: DTGIFSearchResult, nextPage: Page?), Error>) -> Void
    ) {
        self.page = page
        self.limit = limit
        self.query = query
        self.completionOnMainThread = completionOnMainThread
        super.init()
    }

    override func run() {

        guard !self.isCancelled else {
            self.reportCancelled()
            return
        }

        let limit = self.limit
        var offset: Int?
        var next: String?
        switch page {
        case .offset(let value):
            offset = value
        case .next(let value):
            next = value
        default:
            break
        }

        firstly {

            if let query = self.query, !query.isEmpty {
                self.searchApi.request(query: query, limit: limit, offset: offset, next: next)
            } else {
                self.trendingApi.request(limit: limit, offset: offset, next: next)
            }

        }.done(on: DispatchQueue.main) { [weak self] result in

            guard let self else { return }
            guard !self.isCancelled else {
                self.reportCancelled()
                return
            }

            // nextPage == nil means there is no next page.
            var nextPage: Page?
            if let pagination = result.pagination {
                // Per cross-platform contract: hasMore = count + offset < total_count; offset += count.
                let nextPageIndex = pagination.offset + pagination.count
                if nextPageIndex < pagination.totalCount {
                    nextPage = .offset(value: nextPageIndex)
                }
            } else {
                if let next = result.next, !next.isEmpty {
                    nextPage = .next(value: next)
                }
            }

            guard !self.isCancelled else {
                self.reportCancelled()
                return
            }
            self.completionOnMainThread(.success((result: result, nextPage: nextPage)))
            self.reportSuccess()

        }.catch(on: DispatchQueue.main) { [weak self] error in

            guard let self else { return }
            guard !self.isCancelled else {
                self.reportCancelled()
                return
            }
            self.completionOnMainThread(.failure(error))
            self.reportError(error)
        }
    }
}
