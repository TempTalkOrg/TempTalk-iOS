//
//  Copyright (c) 2020 Difft. All rights reserved.
//

import Foundation
import SignalCoreKit
import SVProgressHUD

// This token can be used to observe the completion of a given fetch cycle.
public struct MessageFetchCycle: Hashable, Equatable {
    public let uuid = UUID()
    public let promise: Promise<Void>
    
    // MARK: Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
    
    // MARK: Equatable
    
    public static func == (lhs: MessageFetchCycle, rhs: MessageFetchCycle) -> Bool {
        return lhs.uuid == rhs.uuid
    }
}

// MARK: -
@objc(OWSMessageFetcherJob)
public class MessageFetcherJob: NSObject {
    
    private var timer: Timer?
    
    @objc
    public override init() {
        super.init()
        
        SwiftSingletons.register(self)
    }
    
    // MARK: -
    
    // This operation queue ensures that only one fetch operation is
    // running at a given time.
    private let operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.name = "MessageFetcherJob.operationQueue"
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    fileprivate var activeOperationCount: Int {
        return operationQueue.operationCount
    }
    
    private let unfairLock = UnfairLock()
        
    private let completionQueue = DispatchQueue(label: "org.signal.messageFetcherJob.completionQueue")
    
    // This property should only be accessed with unfairLock acquired.
    private var activeFetchCycles = Set<UUID>()
    private var askForPermission: Bool = false
    
    // This property should only be accessed with unfairLock acquired.
    private var completedFetchCyclesCounter: UInt = 0
    
    @objc
    public static let didChangeStateNotificationName = Notification.Name("MessageFetcherJob.didChangeStateNotificationName")
    
    @discardableResult
    public func run() -> MessageFetchCycle {
        Logger.debug("")
        
        // Use an operation queue to ensure that only one fetch cycle is done
        // at a time.
        let fetchOperation = MessageFetchOperation()
        let promise = fetchOperation.promise
        let fetchCycle = MessageFetchCycle(promise: promise)
        
        _ = self.unfairLock.withLock {
            activeFetchCycles.insert(fetchCycle.uuid)
        }
        
        // We don't want to re-fetch any messages that have
        // already been processed, so fetch operations should
        // block on "message ack" operations.  We accomplish
        // this by having our message fetch operations depend
        // on a no-op operation that flushes the "message ack"
        // operation queue.
        let shouldFlush = true //!FeatureFlags.deprecateREST
        if shouldFlush {
            let flushAckOperation = Operation()
            flushAckOperation.queuePriority = .normal
            ackOperationQueue.addOperation(flushAckOperation)
            
            fetchOperation.addDependency(flushAckOperation)
        }
        
        operationQueue.addOperation(fetchOperation)
        
        completionQueue.async {
            self.operationQueue.waitUntilAllOperationsAreFinished()
            
            self.unfairLock.withLock {
                self.activeFetchCycles.remove(fetchCycle.uuid)
                self.completedFetchCyclesCounter += 1
            }
            
            self.postDidChangeState()
        }
        
        self.postDidChangeState()
        
        return fetchCycle
    }
    
    @objc
    @discardableResult
    public func runObjc() -> AnyPromise {
        return AnyPromise(run().promise)
    }
    
    private func postDidChangeState() {
        NotificationCenter.default.postNotificationNameAsync(MessageFetcherJob.didChangeStateNotificationName, object: nil)
    }
    
    public func isFetchCycleComplete(fetchCycle: MessageFetchCycle) -> Bool {
        unfairLock.withLock {
            self.activeFetchCycles.contains(fetchCycle.uuid)
        }
    }
    
    public var areAllFetchCyclesComplete: Bool {
        unfairLock.withLock {
            self.activeFetchCycles.isEmpty
        }
    }
    
    public var completedRestFetches: UInt {
        unfairLock.withLock {
            self.completedFetchCyclesCounter
        }
    }
    
    @objc public var askForPermissionToFetch: Bool {
        get {
            unfairLock.withLock {
                self.askForPermission
            }
        }
        
        set {
            unfairLock.withLock {
                self.askForPermission = newValue
            }
        }
    }
    
    public class var shouldUseWebSocket: Bool {
        return CurrentAppContext().isMainApp && !signalService.isCensorshipCircumventionActive
    }
    
    // MARK: -
    
    fileprivate class func fetchMessages(future: Future<Void>) {
        Logger.info("")
        // TODO: isRegisteredAndReady
        guard tsAccountManager.isRegistered() else {
            assert(AppReadiness.isAppReady)
            Logger.warn("not registered")
            return future.resolve()
        }
        
        if shouldUseWebSocket {
            Logger.info("delegating message fetching to SocketManager since we're using normal transport.")
            self.socketManager.didReceivePush()
            return future.resolve()
        } else if CurrentAppContext().shouldProcessIncomingMessages {
            // Main app should use REST if censorship circumvention is active.
            // Notification extension that should always use REST.
        } else {
            return future.reject(NSError(domain: "message fetcher", code: 1000, userInfo: ["": "App extensions should not fetch messages."]))
        }
        
        Logger.info("Fetching messages via REST.")

        firstly {
            fetchMessagesViaRestWhenReady()
        }.done {
            Logger.info("fetchMessagesViaRest done.")
            future.resolve()
        }.catch { error in
            Logger.error("Error: \(error).")
            future.reject(error)
        }
    }
    
    // MARK: -
    
    // We want to have multiple ACKs in flight at a time.
    private let ackOperationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.name = "MessageFetcherJob.ackOperationQueue"
        operationQueue.maxConcurrentOperationCount = 5
        return operationQueue
    }()
    
    private let pendingAcks = PendingTasks(label: "Acks")
    
    private func acknowledgeDelivery(envelopeInfo: EnvelopeInfo) {
        guard let ackOperation = MessageAckOperation(envelopeInfo: envelopeInfo,
                                                     pendingAcks: pendingAcks) else {
            return
        }
        ackOperationQueue.addOperation(ackOperation)
    }
    
    public func pendingAcksPromise() -> Promise<Void> {
        // This promise blocks on all operations already in the queue,
        // but will not block on new operations added after this promise
        // is created. That's intentional to ensure that NotificationService
        // instances complete in a timely way.
        pendingAcks.pendingTasksPromise()
    }
    
    // MARK: -
    
    private struct EnvelopeJob {
        let encryptedEnvelope: DSKProtoEnvelope
        let completion: (Error?) -> Void
    }
    
    private class func fetchMessagesViaRest() -> Promise<Void> {
        Logger.info("")
        
        return firstly(on: DispatchQueue.global()) {
            fetchBatchViaRest()
        }.map(on: DispatchQueue.global()) { (batch: RESTBatch) -> ([EnvelopeJob], UInt64, Bool) in
            Logger.info("REST fetched envelopes: \(batch.envelopes.count)")
            
            let envelopeJobs: [EnvelopeJob] = batch.envelopes.map { envelope in
                let envelopeInfo = Self.buildEnvelopeInfo(envelope: envelope)
                return EnvelopeJob(encryptedEnvelope: envelope) { error in
                    MessageProcessor.handleMessageProcessingOutcome(error: error) { success, error in
                        if success {
                            Self.messageFetcherJob.acknowledgeDelivery(envelopeInfo: envelopeInfo)
                        } else {
                            Logger.info("Skipping ack of message with timestamp \(envelopeInfo.timestamp) because of error: \(String(describing: error))")
                        }
                    }
                }
            }
            
            return (envelopeJobs: envelopeJobs,
                    serverDeliveryTimestamp: batch.serverDeliveryTimestamp,
                    hasMore: batch.hasMore)
            
        }.then(on: DispatchQueue.global()) { (envelopeJobs: [EnvelopeJob],
                                 serverDeliveryTimestamp: UInt64,
                                 hasMore: Bool) -> Promise<Void> in
            let queuedContentCountOld = Self.messageProcessor.queuedContentCount
            for job in envelopeJobs {
                Self.messageProcessor.processEncryptedEnvelope(
                    job.encryptedEnvelope,
                    serverDeliveryTimestamp: serverDeliveryTimestamp,
                    hotDataDestination: nil,
                    envelopeSource: .rest,
                    completion: job.completion)
            }
            let queuedContentCountNew = Self.messageProcessor.queuedContentCount
            
//            if DebugFlags.internalLogging {
                Logger.info("messageProcessor.queuedContentCount: \(queuedContentCountOld) + \(envelopeJobs.count) -> \(queuedContentCountNew)")
//            }
            
            if hasMore {
                Logger.info("fetching more messages.")
                
                return self.fetchMessagesViaRestWhenReady()
            } else {
                // All finished
                return Promise.value(())
            }
        }
    }
    
    
    private class func fetchMessagesViaRestWhenReady() -> Promise<Void> {
        Promise<Void>.waitUntil {
            isReadyToFetchMessagesViaRest
        }.then {
            fetchMessagesViaRest()
        }
    }
    
    private class var isReadyToFetchMessagesViaRest: Bool {
        guard CurrentAppContext().isNSE else {
            // If not NSE, fetch more immediately.
            return true
        }
        
        // The NSE has tight memory constraints.
        // For perf reasons, MessageProcessor keeps its queue in memory.
        // It is not safe for the NSE to fetch more messages
        // and cause this queue to grow in an unbounded way.
        // Therefore, the NSE should wait to fetch more messages if
        // the queue has "some/enough" content.
        // However, the NSE needs to process messages with high
        // throughput.
        // Therefore we need to identify a constant N small enough to
        // place an acceptable upper bound on memory usage of the processor
        // (N + next fetched batch size, fetch size in practice is 100),
        // large enough to avoid introducing latency (e.g. the next fetch
        // will complete before the queue is empty).
        // This is tricky since there are multiple variables (e.g. network
        // perf affects fetch, CPU perf affects processing).
        let queuedContentCount = messageProcessor.queuedContentCount
        let pendingAcksCount = MessageAckOperation.pendingAcksCount
        let incompleteEnvelopeCount = queuedContentCount + pendingAcksCount
        let maxIncompleteEnvelopeCount: Int = 20
        guard incompleteEnvelopeCount < maxIncompleteEnvelopeCount else {
            if incompleteEnvelopeCount != Self.lastIncompleteEnvelopeCount.get() {
                Logger.info("queuedContentCount: \(queuedContentCount) + pendingAcksCount: \(pendingAcksCount) = \(incompleteEnvelopeCount)")
                Self.lastIncompleteEnvelopeCount.set(incompleteEnvelopeCount)
            }
            return false
        }
        
        let hasPendingEncrypedJobs = self.messageProcessor.queuedContentCount
        if hasPendingEncrypedJobs > 0 {
            return false
        }
        
        return true
    }
    
    private static let lastIncompleteEnvelopeCount = AtomicValue<Int>(0, lock: .sharedGlobal)
    
    // MARK: - Run Loop
    
    // use in DEBUG or wherever you can't receive push notifications to poll for messages.
    // Do not use in production.
    public func startRunLoop(timeInterval: Double) {
        Logger.error("Starting message fetch polling. This should not be used in production.")
        timer = WeakTimer.scheduledTimer(timeInterval: timeInterval, target: self, userInfo: nil, repeats: true) {[weak self] _ in
            _ = self?.run()
            return
        }
    }
    
    public func stopRunLoop() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: -
    
    private class func parseMessagesResponse(responseObject: Any?) -> (envelopes: [DSKProtoEnvelope], more: Bool)? {
        guard let responseObject = responseObject else {
            Logger.error("response object was unexpectedly nil")
            return nil
        }
        
        guard let responseDict = responseObject as? [String: Any] else {
            Logger.error("response object was not a dictionary")
            return nil
        }
        
        guard let messageDicts = responseDict["messages"] as? [[String: Any]] else {
            Logger.error("messages object was not a list of dictionaries")
            return nil
        }
        
        let moreMessages = { () -> Bool in
            if let responseMore = responseDict["more"] as? Bool {
                return responseMore
            } else {
                Logger.warn("more object was not a bool. Assuming no more")
                return false
            }
        }()
        
        let envelopes: [DSKProtoEnvelope] = messageDicts.compactMap { buildEnvelope(messageDict: $0) }
        
        return (
            envelopes: envelopes,
            more: moreMessages
        )
    }
    
    private class func buildEnvelope(messageDict: [String: Any]) -> DSKProtoEnvelope? {
        do {
            
            let builder = DSKProtoEnvelope.builder()
            
            let params = ParamParser(dictionary: messageDict)
            
            let typeInt: Int32 = try params.required(key: "type")
            guard let type: DSKProtoEnvelopeType = DSKProtoEnvelopeType(rawValue: typeInt) else {
                Logger.error("`type` was invalid: \(typeInt)")
                throw ParamParser.ParseError.invalidFormat("type")
            }
            builder.setType(type)
            
            // TODO: 后续 remove
            if let relay = messageDict["relay"] as? String {
                builder.setRelay(relay)
            }
            
            guard let timestamp: UInt64 = try params.required(key: "timestamp") else {
                Logger.error("`timestamp` was invalid: \(typeInt)")
                throw ParamParser.ParseError.invalidFormat("timestamp")
            }
            builder.setTimestamp(timestamp)
            
            if let systemShowTimestamp: UInt64 = try params.optional(key: "systemShowTimestamp") {
                builder.setSystemShowTimestamp(systemShowTimestamp)
            }
            
            if let sequenceId: UInt64 = try params.optional(key: "sequenceId") {
                builder.setSequenceID(sequenceId)
            }
            
            if let source: String = try params.optional(key: "source") {
                builder.setSource(source)
            }
            
            let msgType: Int32 = try params.required(key: "msgType")
            guard let msgType: DSKProtoEnvelopeMsgType = DSKProtoEnvelopeMsgType(rawValue: msgType) else {
                Logger.error("`msgType` was invalid: \(msgType)")
                throw ParamParser.ParseError.invalidFormat("msgType")
            }
            builder.setMsgType(msgType)
            
            if let msgExtra: [String : Any] = try params.optional(key: "msgExtra")  {
                
                let msgExtraBuilder = DSKProtoMsgExtra.builder()
                
                if let conversationId = msgExtra["conversationId"] as? [String : Any] {
                    
                    if let number = conversationId["number"] as? String {
                        
                        let conversationBuilder = DSKProtoConversationId.builder()
                        conversationBuilder.setNumber(number)
                        let conversationId = try conversationBuilder.build()
                        msgExtraBuilder.setConversationID(conversationId)
                        
                    }
                    
                    if let groupId_string = conversationId["groupId"] as? String, let groupId = Data.init(base64Encoded: groupId_string), groupId.count > 0  {
                        
                        let conversationBuilder = DSKProtoConversationId.builder()
                        conversationBuilder.setGroupID(groupId)
                        let conversationId = try conversationBuilder.build()
                        msgExtraBuilder.setConversationID(conversationId)
                        
                    }
                }
                
                let msgExtra = try msgExtraBuilder.build()
                builder.setMsgExtra(msgExtra)
            }
            
            if let sourceDevice: UInt32 = try params.optional(key: "sourceDevice") {
                builder.setSourceDevice(sourceDevice)
            }
            
            if let legacyMessage = try params.optionalBase64EncodedData(key: "message") {
                builder.setLegacyMessage(legacyMessage)
            }
            if let content = try params.optionalBase64EncodedData(key: "content") {
                builder.setContent(content)
            }
            
            if let identityKey: String = try params.optional(key: "identityKey") {
                builder.setIdentityKey(identityKey)
            }
            if let peerContext: String = try params.optional(key: "peerContext") {
                builder.setPeerContext(peerContext)
            }
            
            //            if let serverGuid: String = try params.optional(key: "guid") {
            //                builder.setServerGuid(serverGuid)
            //            }
            
            return try builder.build()
        } catch {
            owsFailDebug("error building envelope: \(error)")
            return nil
        }
    }
    
    private struct RESTBatch {
        let envelopes: [DSKProtoEnvelope]
        let serverDeliveryTimestamp: UInt64
        let hasMore: Bool
    }
    
    private class func fetchBatchViaRest() -> Promise<RESTBatch> {
        firstly(on: DispatchQueue.global()) { () -> Promise<HTTPResponse> in
            let request = OWSRequestFactory.getMessagesRequest()
            return self.networkManager.makePromise(request: request)
        }.map(on: DispatchQueue.global()) { response in
            guard let json = response.responseBodyJson else {
                throw OWSAssertionError("Missing or invalid JSON")
            }
            
            guard let (envelopes, more) = self.parseMessagesResponse(responseObject: json) else {
                Logger.error("response object had unexpected content")
                throw OWSAssertionError("Invalid response.")
            }
            
            var serverDeliveryTimestamp: UInt64 = 0
            if let timestampString = response.responseHeaders["x-signal-timestamp"] {
                serverDeliveryTimestamp = UInt64(timestampString) ?? 0
            }
            
            return RESTBatch(envelopes: envelopes,
                             serverDeliveryTimestamp: serverDeliveryTimestamp,
                             hasMore: more)
        }
    }
    
    fileprivate struct EnvelopeInfo {
        let source: String?
        let sourceDevice: UInt32?
        let timestamp: UInt64
        let serverTimestamp: UInt64
        let envelopType: Int32
    }
    
    private class func buildEnvelopeInfo(envelope: DSKProtoEnvelope) -> EnvelopeInfo {
        EnvelopeInfo(source: envelope.source,
                     sourceDevice: envelope.sourceDevice,
                     timestamp: envelope.timestamp,
                     serverTimestamp: envelope.systemShowTimestamp,
                     envelopType: envelope.type?.rawValue ?? 0)
    }
}

// MARK: -

private class MessageAckOperation: OWSOperation {
    
    fileprivate typealias EnvelopeInfo = MessageFetcherJob.EnvelopeInfo
    
    private let envelopeInfo: EnvelopeInfo
    private let pendingAck: PendingTask
    
    // A heuristic to quickly filter out multiple ack attempts for the same message
    // This doesn't affect correctness, just tries to guard against backing up our operation queue with repeat work
    static private var inFlightAcks = AtomicSet<String>(lock: .sharedGlobal)
    private var didRecordAckId = false
    private let inFlightAckId: String
    
    public static var pendingAcksCount: Int {
        inFlightAcks.count
    }
    
    private static func inFlightAckId(forEnvelopeInfo envelopeInfo: EnvelopeInfo) -> String {
        // All messages *should* have a guid, but we'll handle things correctly if they don't
//        owsAssertDebug(envelopeInfo.serverGuid?.nilIfEmpty != nil)
        if let source = envelopeInfo.source, let sourceDevice = envelopeInfo.sourceDevice {
            return "\(source)_\(sourceDevice)_\(envelopeInfo.timestamp)"
        } else {
            // This *could* collide, but we don't have enough info to ack the message anyway. So it should be fine.
            return "\(envelopeInfo.serverTimestamp)"
        }
    }
    
    private static let unfairLock = UnfairLock()
    private static var successfulAckSet = OrderedSet<String>()
    private static func didAck(inFlightAckId: String) {
        unfairLock.withLock {
            successfulAckSet.append(inFlightAckId)
            // REST fetches are batches of 100.
            let maxAckCount: Int = 128
            while successfulAckSet.count > maxAckCount,
                  let firstAck = successfulAckSet.first {
                successfulAckSet.remove(firstAck)
            }
        }
    }
    private static func hasAcked(inFlightAckId: String) -> Bool {
        unfairLock.withLock {
            successfulAckSet.contains(inFlightAckId)
        }
    }
    
    fileprivate required init?(envelopeInfo: EnvelopeInfo, pendingAcks: PendingTasks) {
        
        let inFlightAckId = Self.inFlightAckId(forEnvelopeInfo: envelopeInfo)
        self.inFlightAckId = inFlightAckId
        
        guard !Self.hasAcked(inFlightAckId: inFlightAckId) else {
            Logger.info("Skipping new ack operation for \(envelopeInfo). Duplicate ack already complete")
            return nil
        }
        guard !Self.inFlightAcks.contains(inFlightAckId) else {
            Logger.info("Skipping new ack operation for \(envelopeInfo). Duplicate ack already enqueued")
            return nil
        }
        
        let pendingAck = pendingAcks.buildPendingTask(label: "Ack, timestamp: \(envelopeInfo.timestamp), serviceTimestamp: \(envelopeInfo.serverTimestamp)")
        
        self.envelopeInfo = envelopeInfo
        self.pendingAck = pendingAck
        
        super.init()
        
        self.remainingRetries = 3
        
        // MessageAckOperation must have a higher priority than than the
        // operations used to flush the ack operation queue.
        self.queuePriority = .high
        Self.inFlightAcks.insert(inFlightAckId)
        didRecordAckId = true
    }
    
    public override func run() {
        Logger.debug("")
        
        let request: TSRequest
        if let source = envelopeInfo.source, envelopeInfo.timestamp > 0 {
            request = OWSRequestFactory.acknowledgeMessageDeliveryRequest(withSource: source, timestamp: envelopeInfo.timestamp)
        } else {
            let error = OWSAssertionError("Cannot ACK message which has neither source, nor server GUID and timestamp.")
            reportError(error)
            return
        }
        
        let envelopeInfo = self.envelopeInfo
        let inFlightAckId = self.inFlightAckId
        firstly(on: DispatchQueue.global()) {
            self.networkManager.makePromise(request: request)
        }.done(on: DispatchQueue.global()) { _ in
            Self.didAck(inFlightAckId: inFlightAckId)
            
//            if DebugFlags.internalLogging {
                Logger.info("acknowledged delivery for message at timestamp: \(envelopeInfo.timestamp), serviceTimestamp: \(envelopeInfo.serverTimestamp)")
//            } else {
//                Logger.debug("acknowledged delivery for message at timestamp: \(envelopeInfo.timestamp), serviceTimestamp: \(envelopeInfo.serviceTimestamp)")
//            }
            self.reportSuccess()
        }.catch(on: DispatchQueue.global()) { error in
//            if DebugFlags.internalLogging {
                Logger.info("acknowledging delivery for message at timestamp: \(envelopeInfo.timestamp), serviceTimestamp: \(envelopeInfo.serverTimestamp) " + " failed with error: \(error)")
//            } else {
//                Logger.debug("acknowledging delivery for message at timestamp: \(envelopeInfo.timestamp), serviceTimestamp: \(envelopeInfo.serviceTimestamp) " + " failed with error: \(error)")
//            }
            self.reportError(error)
        }
    }
    
    @objc
    public override func didComplete() {
        super.didComplete()
        if didRecordAckId {
            Self.inFlightAcks.remove(inFlightAckId)
        }
        pendingAck.complete()
    }
}


// MARK: -

private class MessageFetchOperation: OWSOperation {
    
    let promise: Promise<Void>
    let future: Future<Void>
    
    override required init() {
        
        let (promise, future) = Promise<Void>.pending()
        self.promise = promise
        self.future = future
        super.init()
        self.remainingRetries = 3
    }
    
    public override func run() {
        Logger.info("")
        
        MessageFetcherJob.fetchMessages(future: future)
        _ = promise.ensure {
            self.reportSuccess()
        }
    }
}

// MARK: -

extension Promise {
    public static func waitUntil(checkFrequency: TimeInterval = 0.01,
                                 dispatchQueue: DispatchQueue = .global(),
                                 conditionBlock: @escaping () -> Bool) -> Promise<Void> {
        
        let (promise, future) = Promise<Void>.pending()
        fulfillWaitUntil(future: future,
                         checkFrequency: checkFrequency,
                         dispatchQueue: dispatchQueue,
                         conditionBlock: conditionBlock)
        return promise
    }
    
    private static func fulfillWaitUntil(future: Future<Void>,
                                         checkFrequency: TimeInterval,
                                         dispatchQueue: DispatchQueue,
                                         conditionBlock: @escaping () -> Bool) {
        if conditionBlock() {
            future.resolve()
            return
        }
        dispatchQueue.asyncAfter(deadline: .now() + checkFrequency) {
            fulfillWaitUntil(future: future,
                             checkFrequency: checkFrequency,
                             dispatchQueue: dispatchQueue,
                             conditionBlock: conditionBlock)
        }
    }
}


extension String {
    
    func compare(with version: String) -> ComparisonResult {
        compare(version, options: .numeric)
    }
    
    func isNewer(than version: String) -> Bool {
        compare(with: version) == .orderedDescending
    }
    
    func isOlder(than version: String) -> Bool {
        compare(with: version) == .orderedAscending
    }
}
