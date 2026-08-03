//
// Copyright 2017 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import ObjectiveC
import CryptoKit

// Stills should be loaded before full GIFs.
public enum ProxiedContentRequestPriority {
    case low, high
}

protocol ProxiedContentDownloaderDelegate: AnyObject {
    /// uses the same semantics as:
    /// URLSessionDelegate#URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler;
    func proxiedContentDownloader(willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest) -> URLRequest?
}

// MARK: -

@objc
open class ProxiedContentAssetDescription: NSObject {
    @objc
    public let url: NSURL

    @objc
    public let fileExtension: String

    public init?(url: NSURL,
                 fileExtension: String? = nil) {
        self.url = url

        if let fileExtension = fileExtension {
            self.fileExtension = fileExtension
        } else {
            guard let pathExtension = url.pathExtension else {
                owsFailDebug("URL has not path extension.")
                return nil
            }
            self.fileExtension = pathExtension
        }
    }

    /// A deterministic, filesystem-safe file name derived from the asset URL, so the same asset
    /// maps to the same on-disk file across launches — the basis of the persistent cache.
    fileprivate func persistentCacheFileName() -> String {
        let urlString = url.absoluteString ?? UUID().uuidString
        let digest = SHA256.hash(data: Data(urlString.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return (hex as NSString).appendingPathExtension(fileExtension) ?? hex
    }
}

// MARK: -

public enum ProxiedContentAssetSegmentState: UInt {
    case waiting
    case downloading
    case complete
    case failed
}

// MARK: -

public class ProxiedContentAssetSegment: NSObject {

    public let index: UInt
    public let segmentStart: UInt
    public let segmentLength: UInt
    // The amount of the segment that is overlap.  
    // The overlap lies in the _first_ n bytes of the segment data.
    public let redundantLength: UInt

    // This state should only be accessed on the main thread.
    public var state: ProxiedContentAssetSegmentState = .waiting {
        didSet {
            AssertIsOnMainThread()
        }
    }

    // This state is accessed off the main thread.
    //
    // * During downloads it will be accessed on the task delegate queue.
    // * After downloads it will be accessed on a worker queue. 
    private var segmentData = Data()

    // This state should only be accessed on the main thread.
    public weak var task: URLSessionDataTask?

    init(index: UInt,
         segmentStart: UInt,
         segmentLength: UInt,
         redundantLength: UInt) {
        self.index = index
        self.segmentStart = segmentStart
        self.segmentLength = segmentLength
        self.redundantLength = redundantLength
    }

    public func totalDataSize() -> UInt {
        return UInt(segmentData.count)
    }

    public func append(data: Data) {
        guard state == .downloading else {
            owsFailDebug("appending data in invalid state: \(state)")
            return
        }

        segmentData.append(data)
    }

    public func mergeData(assetData: inout Data) -> Bool {
        guard state == .complete else {
            owsFailDebug("merging data in invalid state: \(state)")
            return false
        }
        guard UInt(segmentData.count) == segmentLength else {
            owsFailDebug("segment data length: \(segmentData.count) doesn't match expected length: \(segmentLength)")
            return false
        }

        // In some cases the last two segments will overlap.
        // In that case, we only want to append the non-overlapping
        // tail of the segment data.
        let bytesToIgnore = Int(redundantLength)
        if bytesToIgnore > 0 {
            let subdata = segmentData.subdata(in: bytesToIgnore..<Int(segmentLength))
            assetData.append(subdata)
        } else {
            assetData.append(segmentData)
        }
        return true
    }
}

// MARK: -

public enum ProxiedContentAssetRequestState: UInt {
    // Does not yet have content length.
    case waiting
    // Getting content length.
    case requestingSize
    // Has content length, ready for downloads or downloads in flight.
    case active
    // Success
    case complete
    // Failure
    case failed
}

// MARK: -

// Represents a request to download an asset.
//
// Should be cancelled if no longer necessary.
@objc
public class ProxiedContentAssetRequest: NSObject {

    let assetDescription: ProxiedContentAssetDescription
    let priority: ProxiedContentRequestPriority
    // Exactly one of success or failure should be called once,
    // on the main thread _unless_ this request is cancelled before
    // the request succeeds or fails.
    private var success: ((ProxiedContentAssetRequest?, ProxiedContentAsset) -> Void)?
    private var failure: ((ProxiedContentAssetRequest) -> Void)?

    var wasCancelled = false
    // This property is an internal implementation detail of the download process.
    var assetFilePath: String?

    // This state should only be accessed on the main thread.
    private var segments = [ProxiedContentAssetSegment]()
    public var state: ProxiedContentAssetRequestState = .waiting
    public var contentLength: Int = 0 {
        didSet {
            AssertIsOnMainThread()
            assert(oldValue == 0)
            assert(contentLength > 0)
        }
    }
    public weak var contentLengthTask: URLSessionDataTask?

    init(assetDescription: ProxiedContentAssetDescription,
         priority: ProxiedContentRequestPriority,
         success: @escaping ((ProxiedContentAssetRequest?, ProxiedContentAsset) -> Void),
         failure: @escaping ((ProxiedContentAssetRequest) -> Void)) {
        self.assetDescription = assetDescription
        self.priority = priority
        self.success = success
        self.failure = failure

        super.init()
    }

    private func segmentSize() -> UInt {
        AssertIsOnMainThread()

        let contentLength = UInt(self.contentLength)
        guard contentLength > 0 else {
            owsFailDebug("asset missing contentLength")
            requestDidFail()
            return 0
        }

        let k1MB: UInt = 1024 * 1024
        let k500KB: UInt = 500 * 1024
        let k100KB: UInt = 100 * 1024
        let k50KB: UInt = 50 * 1024
        let k10KB: UInt = 10 * 1024
        let k1KB: UInt = 1 * 1024
        for segmentSize in [k1MB, k500KB, k100KB, k50KB, k10KB, k1KB ] {
            if contentLength >= segmentSize {
                return segmentSize
            }
        }
        return contentLength
    }

    fileprivate func createSegments(withInitialData initialData: Data) {
        AssertIsOnMainThread()

        let segmentLength = segmentSize()
        guard segmentLength > 0 else {
            return
        }
        let contentLength = UInt(self.contentLength)

        // Make the initial segment.
        let assetSegment = ProxiedContentAssetSegment(index: 0,
                                                      segmentStart: 0,
                                                      segmentLength: UInt(initialData.count),
                                                      redundantLength: 0)
        // "Download" the initial segment using the initialData.
        assetSegment.state = .downloading
        assetSegment.append(data: initialData)
        // Mark the initial segment as complete.
        assetSegment.state = .complete
        segments.append(assetSegment)

        var nextSegmentStart = UInt(initialData.count)
        var index: UInt = 1
        while nextSegmentStart < contentLength {
            var segmentStart: UInt = nextSegmentStart
            var redundantLength: UInt = 0
            // The last segment may overlap the penultimate segment
            // in order to keep the segment sizes uniform.
            if segmentStart + segmentLength > contentLength {
                redundantLength = segmentStart + segmentLength - contentLength
                segmentStart = contentLength - segmentLength
            }
            let assetSegment = ProxiedContentAssetSegment(index: index,
                                                 segmentStart: segmentStart,
                                                 segmentLength: segmentLength,
                                                 redundantLength: redundantLength)
            segments.append(assetSegment)
            nextSegmentStart = segmentStart + segmentLength
            index += 1
        }
    }

    private func firstSegmentWithState(state: ProxiedContentAssetSegmentState) -> ProxiedContentAssetSegment? {
        AssertIsOnMainThread()

        for segment in segments {
            guard segment.state != .failed else {
                owsFailDebug("unexpected failed segment.")
                continue
            }
            if segment.state == state {
                return segment
            }
        }
        return nil
    }

    public func firstWaitingSegment() -> ProxiedContentAssetSegment? {
        AssertIsOnMainThread()

        return firstSegmentWithState(state: .waiting)
    }

    public func downloadingSegmentsCount() -> UInt {
        AssertIsOnMainThread()

        var result: UInt = 0
        for segment in segments {
            guard segment.state != .failed else {
                owsFailDebug("unexpected failed segment.")
                continue
            }
            if segment.state == .downloading {
                result += 1
            }
        }
        return result
    }

    public func areAllSegmentsComplete() -> Bool {
        AssertIsOnMainThread()

        for segment in segments {
            guard segment.state == .complete else {
                return false
            }
        }
        return true
    }

    public func writeAssetToFile(downloadFolderPath: String, isPersistent: Bool = false) -> ProxiedContentAsset? {

        var assetData = Data()
        for segment in segments {
            guard segment.state == .complete else {
                owsFailDebug("unexpected incomplete segment.")
                return nil
            }
            guard segment.totalDataSize() > 0 else {
                owsFailDebug("could not merge empty segment.")
                return nil
            }
            guard segment.mergeData(assetData: &assetData) else {
                owsFailDebug("failed to merge segment data.")
                return nil
            }
        }

        guard assetData.count == contentLength else {
            owsFailDebug("asset data has unexpected length.")
            return nil
        }

        guard assetData.count > 0 else {
            owsFailDebug("could not write empty asset to disk.")
            return nil
        }

        // Persistent assets use a URL-derived name so a later launch finds the same file; ephemeral
        // assets keep a random name (deleted when evicted anyway).
        let fileName = isPersistent
            ? assetDescription.persistentCacheFileName()
            : (NSUUID().uuidString as NSString).appendingPathExtension(assetDescription.fileExtension)!
        let filePath = (downloadFolderPath as NSString).appendingPathComponent(fileName)

        do {
            try assetData.write(to: NSURL.fileURL(withPath: filePath), options: .atomicWrite)
            let asset = ProxiedContentAsset(assetDescription: assetDescription, filePath: filePath, isPersistent: isPersistent)
            return asset
        } catch let error as NSError {
            owsFailDebug("file write failed: \(filePath), \(error)")
            return nil
        }
    }

    public func cancel() {
        AssertIsOnMainThread()

        wasCancelled = true
        contentLengthTask?.cancel()
        contentLengthTask = nil
        for segment in segments {
            segment.task?.cancel()
            segment.task = nil
        }

        // Don't call the callbacks if the request is cancelled.
        clearCallbacks()
    }

    private func clearCallbacks() {
        AssertIsOnMainThread()

        success = nil
        failure = nil
    }

    public func requestDidSucceed(asset: ProxiedContentAsset) {
        AssertIsOnMainThread()

        success?(self, asset)

        // Only one of the callbacks should be called, and only once.
        clearCallbacks()
    }

    public func requestDidFail() {
        AssertIsOnMainThread()

        failure?(self)

        // Only one of the callbacks should be called, and only once.
        clearCallbacks()
    }
}

// MARK: -

// Represents a downloaded asset.
//
// The blob on disk is cleaned up when this instance is deallocated,
// so consumers of this resource should retain a strong reference to
// this instance as long as they are using the asset.
@objc
public class ProxiedContentAsset: NSObject {

    @objc
    public let assetDescription: ProxiedContentAssetDescription

    @objc
    public let filePath: String

    // Persistent assets survive relaunches and are NOT deleted on dealloc; the cache prunes them
    // by size/age instead. Ephemeral assets keep the original delete-on-dealloc behavior.
    private let isPersistent: Bool

    init(assetDescription: ProxiedContentAssetDescription,
         filePath: String,
         isPersistent: Bool = false) {
        self.assetDescription = assetDescription
        self.filePath = filePath
        self.isPersistent = isPersistent
    }

    deinit {
        guard !isPersistent else { return }
        // Clean up on the asset on disk.
        let filePathCopy = filePath
        DispatchQueue.global().async {
            do {
                let fileManager = FileManager.default
                try fileManager.removeItem(atPath: filePathCopy)
            } catch let error as NSError {
                owsFailDebug("file cleanup failed: \(filePathCopy), \(error)")
            }
        }
    }
}

// MARK: -

private var URLSessionTaskProxiedContentAssetRequest: UInt8 = 0
private var URLSessionTaskProxiedContentAssetSegment: UInt8 = 0

// This extension is used to punch an asset request onto a download task.
extension URLSessionTask {
    var assetRequest: ProxiedContentAssetRequest {
        get {
            guard let request = objc_getAssociatedObject(self, &URLSessionTaskProxiedContentAssetRequest) as? ProxiedContentAssetRequest else {
                owsFailDebug("assetRequest accessed before being set")
                preconditionFailure("assetRequest must be set before accessing URLSessionTask.assetRequest")
            }
            return request
        }
        set {
            objc_setAssociatedObject(self, &URLSessionTaskProxiedContentAssetRequest, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    var assetSegment: ProxiedContentAssetSegment {
        get {
            guard let segment = objc_getAssociatedObject(self, &URLSessionTaskProxiedContentAssetSegment) as? ProxiedContentAssetSegment else {
                owsFailDebug("assetSegment accessed before being set")
                preconditionFailure("assetSegment must be set before accessing URLSessionTask.assetSegment")
            }
            return segment
        }
        set {
            objc_setAssociatedObject(self, &URLSessionTaskProxiedContentAssetSegment, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: -

@objc
open class ProxiedContentDownloader: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {

    // MARK: - Properties

    private let downloadFolderName: String

    private var downloadFolderPath: String?

    // When true, downloads are cached persistently across launches (see ensureDownloadFolder /
    // loadPersistedAssetIfAvailable / pruneCacheFolderAsync). When false, the original ephemeral
    // behavior applies: the folder is wiped on launch and files are deleted when evicted.
    private let isPersistent: Bool

    // Force usage as a singleton
    public init(downloadFolderName: String, isPersistent: Bool = false) {
        AssertIsOnMainThread()

        self.downloadFolderName = downloadFolderName
        self.isPersistent = isPersistent

        super.init()

        SwiftSingletons.register(self)

        ensureDownloadFolder()

        if isPersistent {
            pruneCacheFolderAsync()
        }
    }

    private lazy var downloadSession: URLSession = {
        AssertIsOnMainThread()

        let configuration = URLSessionConfiguration.ephemeral
        // Don't use any caching to protect privacy of these requests.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringCacheData

        configuration.httpMaximumConnectionsPerHost = 10
        let session = URLSession(configuration: configuration,
                                 delegate: self,
                                 delegateQueue: nil)
        return session
    }()

    // 100 entries of which at least half will probably be stills.
    // Actual animated GIFs will usually be less than 3 MB so the
    // max size of the cache on disk should be ~150 MB.  Bear in mind
    // that assets are not always deleted on disk as soon as they are
    // evacuated from the cache; if a cache consumer (e.g. view) is
    // still using the asset, the asset won't be deleted on disk until
    // it is no longer in use.
    private var assetMap = LRUCache<NSURL, ProxiedContentAsset>(maxSize: 100)
    // TODO: We could use a proper queue, e.g. implemented with a linked
    // list.
    private var assetRequestQueue = [ProxiedContentAssetRequest]()

    // The success and failure callbacks are always called on main queue.
    //
    // The success callbacks may be called synchronously on cache hit, in
    // which case the ProxiedContentAssetRequest parameter will be nil.
    public func requestAsset(
        assetDescription: ProxiedContentAssetDescription,
        priority: ProxiedContentRequestPriority,
        success: @escaping ((ProxiedContentAssetRequest?, ProxiedContentAsset) -> Void),
        failure: @escaping ((ProxiedContentAssetRequest) -> Void)
    ) -> ProxiedContentAssetRequest? {
        AssertIsOnMainThread()

        if let asset = assetMap.get(key: assetDescription.url) {
            // Synchronous cache hit.
            success(nil, asset)
            return nil
        }

        // Persistent disk-cache hit: a prior launch already downloaded this asset, so serve it from
        // disk instead of re-downloading.
        if isPersistent, let asset = loadPersistedAssetIfAvailable(assetDescription) {
            assetMap.set(key: assetDescription.url, value: asset)
            success(nil, asset)
            return nil
        }

        // Cache miss.
        //
        // Asset requests are done queued and performed asynchronously.
        let assetRequest = ProxiedContentAssetRequest(
            assetDescription: assetDescription,
            priority: priority,
            success: success,
            failure: failure
        )
        assetRequestQueue.append(assetRequest)
        // Process the queue (which may start this request)
        // asynchronously so that the caller has time to store
        // a reference to the asset request returned by this
        // method before its success/failure handler is called.
        processRequestQueueAsync()
        return assetRequest
    }

    public func cancelAllRequests() {
        AssertIsOnMainThread()

        self.assetRequestQueue.forEach { $0.cancel() }
        self.assetRequestQueue = []
    }

    private func segmentRequestDidSucceed(assetRequest: ProxiedContentAssetRequest, assetSegment: ProxiedContentAssetSegment) {
        DispatchQueue.main.async {
            assetSegment.state = .complete

            if !self.tryToCompleteRequest(assetRequest: assetRequest) {
                self.processRequestQueueSync()
            }
        }
    }

    // Returns true if the request is completed.
    private func tryToCompleteRequest(assetRequest: ProxiedContentAssetRequest) -> Bool {
        AssertIsOnMainThread()

        guard assetRequest.areAllSegmentsComplete() else {
            return false
        }

        // If the asset request has completed all of its segments,
        // try to write the asset to file.
        assetRequest.state = .complete

        // Move write off main thread.
        DispatchQueue.global().async {
            guard let downloadFolderPath = self.downloadFolderPath else {
                owsFailDebug("Missing downloadFolderPath")
                return
            }
            guard let asset = assetRequest.writeAssetToFile(downloadFolderPath: downloadFolderPath, isPersistent: self.isPersistent) else {
                self.segmentRequestDidFail(assetRequest: assetRequest)
                return
            }
            self.assetRequestDidSucceed(assetRequest: assetRequest, asset: asset)
        }
        return true
    }

    private func assetRequestDidSucceed(assetRequest: ProxiedContentAssetRequest, asset: ProxiedContentAsset) {
        DispatchQueue.main.async {
            self.assetMap.set(key: assetRequest.assetDescription.url, value: asset)
            self.removeAssetRequestFromQueue(assetRequest: assetRequest)
            assetRequest.requestDidSucceed(asset: asset)
        }
    }

    private func segmentRequestDidFail(assetRequest: ProxiedContentAssetRequest, assetSegment: ProxiedContentAssetSegment? = nil) {
        DispatchQueue.main.async {
            if let assetSegment = assetSegment {
                assetSegment.state = .failed

                // TODO: If we wanted to implement segment retry, we'd do so here.
                //       For now, we just fail the entire asset request.
            }
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
        }
    }

    private func assetRequestDidFail(assetRequest: ProxiedContentAssetRequest) {

        DispatchQueue.main.async {
            self.removeAssetRequestFromQueue(assetRequest: assetRequest)
            assetRequest.requestDidFail()
        }
    }

    private func removeAssetRequestFromQueue(assetRequest: ProxiedContentAssetRequest) {
        AssertIsOnMainThread()

        guard assetRequestQueue.contains(assetRequest) else {
            Logger.warn("could not remove asset request from queue")
            return
        }

        assetRequestQueue = assetRequestQueue.filter { $0 != assetRequest }
        // Process the queue async to ensure that state in the downloader
        // classes is consistent before we try to start a new request.
        processRequestQueueAsync()
    }

    private func processRequestQueueAsync() {
        DispatchQueue.main.async {
            self.processRequestQueueSync()
        }
    }

    // * Start a segment request or content length request if possible.
    // * Complete/cancel asset requests if possible.
    //
    private func processRequestQueueSync() {
        AssertIsOnMainThread()

        guard let assetRequest = popNextAssetRequest() else {
            return
        }
        guard !assetRequest.wasCancelled else {
            // Discard the cancelled asset request and try again.
            removeAssetRequestFromQueue(assetRequest: assetRequest)
            return
        }
        guard CurrentAppContext().isMainAppAndActive else {
            // If app is not active, fail the asset request.
            assetRequest.state = .failed
            assetRequestDidFail(assetRequest: assetRequest)
            processRequestQueueSync()
            return
        }

        if let asset = assetMap.get(key: assetRequest.assetDescription.url) {
            // Deferred cache hit, avoids re-downloading assets that were
            // downloaded while this request was queued.

            assetRequest.state = .complete
            assetRequestDidSucceed(assetRequest: assetRequest, asset: asset)
            return
        }

        if assetRequest.state == .waiting {
            // If asset request hasn't yet determined the resource size,
            // try to do so now, by requesting a small initial segment.
            assetRequest.state = .requestingSize

            let segmentStart: UInt = 0
            // Vary the initial segment size to obscure the length of the response headers.
            let segmentLength = UInt.random(in: 1024..<2048)
            var request = URLRequest(url: assetRequest.assetDescription.url as URL)
            request.httpShouldUsePipelining = true
            let rangeHeaderValue = "bytes=\(segmentStart)-\(segmentStart + segmentLength - 1)"
            request.setValue(rangeHeaderValue, forHTTPHeaderField: "Range")

            let task = downloadSession.dataTask(with: request, completionHandler: { data, response, error -> Void in
                self.handleAssetSizeResponse(assetRequest: assetRequest, data: data, response: response, error: error)
            })

            assetRequest.contentLengthTask = task
            task.resume()
        } else {
            // Start a download task.

            guard let assetSegment = assetRequest.firstWaitingSegment() else {
                owsFailDebug("queued asset request does not have a waiting segment.")
                return
            }
            assetSegment.state = .downloading

            var request = URLRequest(url: assetRequest.assetDescription.url as URL)
            request.httpShouldUsePipelining = true
            let rangeHeaderValue = "bytes=\(assetSegment.segmentStart)-\(assetSegment.segmentStart + assetSegment.segmentLength - 1)"
            request.setValue(rangeHeaderValue, forHTTPHeaderField: "Range")

            let task: URLSessionDataTask = downloadSession.dataTask(with: request)
            task.assetRequest = assetRequest
            task.assetSegment = assetSegment
            assetSegment.task = task
            task.resume()
        }

        // Recurse; we may be able to start multiple downloads.
        processRequestQueueSync()
    }

    private func handleAssetSizeResponse(assetRequest: ProxiedContentAssetRequest, data: Data?, response: URLResponse?, error: Error?) {
        guard error == nil else {
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }
        guard let data = data,
        data.count > 0 else {
            owsFailDebug("Asset size response missing data.")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            owsFailDebug("Asset size response is invalid.")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            Logger.warn("invalid httpResponse.statusCode: \(httpResponse.statusCode)")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }
        var firstContentRangeString: String?
        for header in httpResponse.allHeaderFields.keys {
            guard let headerString = header as? String else {
                owsFailDebug("Invalid header: \(header)")
                continue
            }
            if headerString.lowercased() == "content-range" {
                firstContentRangeString = httpResponse.allHeaderFields[header] as? String
            }
        }
        guard let contentRangeString = firstContentRangeString else {
            owsFailDebug("Asset size response is missing content range.")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }

        // Example: content-range: bytes 0-1023/7630
        guard let contentLengthString = NSRegularExpression.parseFirstMatch(pattern: "^bytes \\d+\\-\\d+/(\\d+)$",
                                                              text: contentRangeString) else {
                                                                owsFailDebug("Asset size response has invalid content range.")
                                                                assetRequest.state = .failed
                                                                self.assetRequestDidFail(assetRequest: assetRequest)
                                                                return
        }
        guard
            !contentLengthString.isEmpty,
            let contentLength = Int(contentLengthString)
        else {
            owsFailDebug("Asset size response has unparsable content length.")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }
        guard contentLength > 0 else {
            owsFailDebug("Asset size response has invalid content length.")
            assetRequest.state = .failed
            self.assetRequestDidFail(assetRequest: assetRequest)
            return
        }

        DispatchQueue.main.async {
            assetRequest.contentLength = contentLength
            assetRequest.createSegments(withInitialData: data)
            assetRequest.state = .active

            if !self.tryToCompleteRequest(assetRequest: assetRequest) {
                self.processRequestQueueSync()
            }
        }
    }

    // Return the first asset request for which we either:
    //
    // * Need to download the content length.
    // * Need to download at least one of its segments.
    private func popNextAssetRequest() -> ProxiedContentAssetRequest? {
        AssertIsOnMainThread()

        // A grid shows ~12-16 GIFs at once; a global cap of 3 left most cells queued. Allow more
        // concurrent downloads, but keep per-asset segments low so bandwidth spreads across cells
        // (one large GIF can't monopolize all slots) and the grid fills evenly.
        let kMaxAssetRequestCount: UInt = 8
        let kMaxAssetRequestsPerAssetCount: UInt = 2

        // Prefer the first "high" priority request;
        // fall back to the first "low" priority request.
        var activeAssetRequestsCount: UInt = 0
        for priority in [ProxiedContentRequestPriority.high, ProxiedContentRequestPriority.low] {
            for assetRequest in assetRequestQueue where assetRequest.priority == priority {
                switch assetRequest.state {
                case .waiting:
                    // This asset request needs its content length.
                    return assetRequest
                case .requestingSize:
                    activeAssetRequestsCount += 1
                    // Ensure that only N requests are active at a time.
                    guard activeAssetRequestsCount < kMaxAssetRequestCount else {
                        return nil
                    }
                    continue
                case .active:
                    break
                case .complete:
                    continue
                case .failed:
                    continue
                }

                let downloadingSegmentsCount = assetRequest.downloadingSegmentsCount()
                activeAssetRequestsCount += downloadingSegmentsCount
                // Ensure that only N segment requests are active per asset at a time.
                guard downloadingSegmentsCount < kMaxAssetRequestsPerAssetCount else {
                    continue
                }
                // Ensure that only N requests are active at a time.
                guard activeAssetRequestsCount < kMaxAssetRequestCount else {
                    return nil
                }
                guard assetRequest.firstWaitingSegment() != nil else {
                    /// Asset request does not have a waiting segment.
                    continue
                }
                return assetRequest
            }
        }

        return nil
    }

    // MARK: URLSessionDataDelegate

    @nonobjc
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {

        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let assetRequest = dataTask.assetRequest
        let assetSegment = dataTask.assetSegment
        guard !assetRequest.wasCancelled else {
            dataTask.cancel()
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }
        assetSegment.append(data: data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        completionHandler(nil)
    }

    // MARK: URLSessionTaskDelegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        let assetRequest = task.assetRequest
        let assetSegment = task.assetSegment
        guard !assetRequest.wasCancelled else {
            task.cancel()
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }
        if let error = error {
            Logger.error("download failed with error: \(error)")
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }
        guard let httpResponse = task.response as? HTTPURLResponse else {
            Logger.error("missing or unexpected response: \(type(of: task.response))")
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }
        let statusCode = httpResponse.statusCode
        guard statusCode >= 200 && statusCode < 400 else {
            Logger.error("response has invalid status code: \(statusCode)")
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }
        guard assetSegment.totalDataSize() == assetSegment.segmentLength else {
            Logger.error("segment is missing data: \(statusCode)")
            segmentRequestDidFail(assetRequest: assetRequest, assetSegment: assetSegment)
            return
        }

        segmentRequestDidSucceed(assetRequest: assetRequest, assetSegment: assetSegment)
    }

    weak var delegate: ProxiedContentDownloaderDelegate?
    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let delegate = delegate else {
            completionHandler(request)
            return
        }

        let delegateRequest = delegate.proxiedContentDownloader(willPerformHTTPRedirection: response, newRequest: request)
        completionHandler(delegateRequest)
    }

    // MARK: Temp Directory

    public func ensureDownloadFolder() {
        // Persistent caches live in Caches (survive relaunch; iOS may reclaim under storage
        // pressure). Ephemeral downloads live in the temporary directory so iOS can clean them up.
        let baseDirPath = isPersistent
            ? (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? OWSTemporaryDirectory())
            : OWSTemporaryDirectory()
        let dirPath = (baseDirPath as NSString).appendingPathComponent(downloadFolderName)
        do {
            let fileManager = FileManager.default

            // Only the ephemeral variant is wiped on launch; the persistent cache is kept.
            if !isPersistent, fileManager.fileExists(atPath: dirPath) {
                try fileManager.removeItem(atPath: dirPath)
            }
            if !fileManager.fileExists(atPath: dirPath) {
                try fileManager.createDirectory(atPath: dirPath,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            }
            downloadFolderPath = dirPath

            // Don't back up ProxiedContent downloads.
            OWSFileSystem.protectFileOrFolder(atPath: dirPath)
        } catch let error as NSError {
            // Never fall back to the shared temp root: prune would then evict unrelated files, and
            // downloads would litter it. A nil path makes prune/load/write safely no-op instead.
            owsFailDebug("ensureDownloadFolder failed: \(dirPath), \(error)")
            downloadFolderPath = nil
        }
    }

    // Serializes cache-folder mutations (hit-mtime touches and prune evictions) so an eviction can
    // never race a concurrent load that is about to use the same file.
    private let cacheQueue = DispatchQueue(label: "org.difft.proxied-content-cache")

    // Returns a persisted asset for this description if its file is already on disk, else nil.
    private func loadPersistedAssetIfAvailable(_ assetDescription: ProxiedContentAssetDescription) -> ProxiedContentAsset? {
        guard let downloadFolderPath else { return nil }
        let filePath = (downloadFolderPath as NSString).appendingPathComponent(assetDescription.persistentCacheFileName())
        // Check-and-touch atomically against prune (both run on cacheQueue): if the file is present
        // we bump its mtime so a serialized prune re-stat then skips it; if prune already removed it
        // we report a miss and the caller re-downloads. No asset is returned for a file prune deletes.
        let isAvailable: Bool = cacheQueue.sync {
            let fileManager = FileManager.default
            guard let size = (try? fileManager.attributesOfItem(atPath: filePath))?[.size] as? UInt64,
                  size > 0 else {
                return false
            }
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: filePath)
            return true
        }
        guard isAvailable else { return nil }
        return ProxiedContentAsset(assetDescription: assetDescription, filePath: filePath, isPersistent: true)
    }

    // Bounds the persistent cache: when the folder exceeds the size cap, evict oldest files first.
    // Each eviction is serialized on cacheQueue with hit-mtime touches and re-stats the file, so a
    // load that just touched (or a download that just wrote) it is never evicted from under an
    // in-use asset. The scan is a plain read; only the delete decisions are serialized.
    private func pruneCacheFolderAsync() {
        guard let folderPath = downloadFolderPath else { return }
        DispatchQueue.global(qos: .utility).async {
            let maxBytes: UInt64 = 256 * 1024 * 1024
            let fileManager = FileManager.default
            guard let names = try? fileManager.contentsOfDirectory(atPath: folderPath) else { return }

            var files: [(path: String, size: UInt64, date: Date)] = []
            var totalBytes: UInt64 = 0
            for name in names {
                let path = (folderPath as NSString).appendingPathComponent(name)
                guard let attrs = try? fileManager.attributesOfItem(atPath: path) else { continue }
                let size = attrs[.size] as? UInt64 ?? 0
                let date = attrs[.modificationDate] as? Date ?? Date.distantPast
                files.append((path, size, date))
                totalBytes += size
            }

            guard totalBytes > maxBytes else { return }
            for file in files.sorted(by: { $0.date < $1.date }) {
                guard totalBytes > maxBytes else { break }
                self.cacheQueue.sync {
                    // Skip if a concurrent load touched (or removed) it since the scan above.
                    let currentDate = (try? fileManager.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
                    guard currentDate == file.date else { return }
                    if (try? fileManager.removeItem(atPath: file.path)) != nil {
                        totalBytes -= file.size
                    }
                }
            }
        }
    }
}
