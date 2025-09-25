//
//  MessageProcessor.swift
//  TTServiceKit
//
//  Created by Felix on 2022/7/7.
//

import Foundation
import SignalCoreKit

@objc
public class MessageProcessor: NSObject {
    
    @objc
    public static let messageProcessorDidFlushQueue = Notification.Name("messageProcessorDidFlushQueue")
    
    @objc
    public var hasPendingEnvelopes: Bool {
        !pendingEnvelopes.isEmpty
    }
    
    @objc
    @available(swift, obsoleted: 1.0)
    public func processingCompletePromise() -> AnyPromise {
        return AnyPromise(processingCompletePromise())
    }
    
    public func processingCompletePromise() -> Promise<Void> {
        guard CurrentAppContext().shouldProcessIncomingMessages else {
            Logger.verbose("!shouldProcessIncomingMessages")
            
            return Promise.value(())
        }
        
        if self.hasPendingEnvelopes {
            Logger.info("hasPendingEnvelopes, queuedContentCount: \(self.queuedContentCount)")
            
            return NotificationCenter.default.observe(
                once: Self.messageProcessorDidFlushQueue
            ).then { _ in self.processingCompletePromise() }.asVoid()
        } else {
            Logger.verbose("!hasPendingEnvelopes && !hasPendingJobs")
            return Promise.value(())
        }
    }
    
    
    public override init() {
        super.init()

        SwiftSingletons.register(self)
        //Kris: handle unsupportted msgs
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            SDSDatabaseStorage.shared.read { transaction in
                OWSMessageContentJob.anyEnumerate(transaction: transaction,
                                                  batched: true,
                                                  block: { (jobRecord : OWSMessageContentJob, _) in
                    let completion: (Error?) -> Void = { error in
                        if !jobRecord.unsupportedFlag || (error != nil) {
                            SDSDatabaseStorage.shared.write { jobRecord.anyRemove(transaction: $0) }
                        }
                    }
                    guard jobRecord.unsupportedFlag else {
                        completion(OWSError(error: .failedToDecryptMessage,
                                            description: "supported envelope",
                                            isRetryable: false,
                                            userInfo: [NSUnderlyingErrorKey: "supported envelope"]))
                        return
                    }
                    
                    guard (!jobRecord.lastestHandleVersion.isEmpty && AppVersion.shared().currentAppReleaseVersion.compare(jobRecord.lastestHandleVersion, options: .numeric) == .orderedDescending) else {
                        return
                    }
                    
                    do {
                        let envelope = try DSKProtoEnvelope(serializedData: jobRecord.envelopeData)
                        
                        self.processEncryptedEnvelope(EncryptedEnvelope(unsupporttedMsgJob: jobRecord,
                                                                        encryptedEnvelopeData: nil,
                                                                        encryptedEnvelope: envelope,
                                                                        envelopeSource: .unsupporttedMsg,
                                                                        hotDataDestination: nil,
                                                                        serverDeliveryTimestamp: 0,
                                                                        completion: completion),
                                                      envelopeSource: .unsupporttedMsg)

                    } catch {//MARK GRDB need to focus on
                        completion(OWSError(error: .failedToDecryptMessage,
                                            description: "new unsupportted envelope error",
                                            isRetryable: false,
                                            userInfo: [NSUnderlyingErrorKey: "new unsupportted envelope error"]))
                    }
                });
                
            }
        }
    }
    
    @objc
    public func processEncryptedEnvelopeData(
        _ encryptedEnvelopeData: Data,
        serverDeliveryTimestamp: UInt64,
        envelopeSource: EnvelopeSource,
        hotDataDestination: String?,
        hotdataMsgFlag: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        guard !encryptedEnvelopeData.isEmpty else {
            completion(OWSAssertionError("Empty envelope, envelopeSource: \(envelopeSource)."))
            return
        }
        
        // Drop any too-large messages on the floor. Well behaving clients should never send them.
        guard encryptedEnvelopeData.count <= Self.maxEnvelopeByteCount else {
            completion(OWSAssertionError("Oversize envelope, envelopeSource: \(envelopeSource)."))
            return
        }
        
        // Take note of any messages larger than we expect, but still process them.
        // This likely indicates a misbehaving sending client.
        if encryptedEnvelopeData.count > Self.largeEnvelopeWarningByteCount {
            Logger.verbose("encryptedEnvelopeData: \(encryptedEnvelopeData.count) > : \(Self.largeEnvelopeWarningByteCount)")
            Logger.warn("Unexpectedly large envelope, envelopeSource: \(envelopeSource).")
        }
        
        let encryptedEnvelopeProto: DSKProtoEnvelope
        do {
            encryptedEnvelopeProto = try DSKProtoEnvelope(serializedData: encryptedEnvelopeData)
            
        } catch {
            owsFailDebug("Failed to parse encrypted envelope \(error), envelopeSource: \(envelopeSource)")
            completion(error)
            return
        }
        
        processEncryptedEnvelope(EncryptedEnvelope(unsupporttedMsgJob: nil,
                                                   encryptedEnvelopeData: encryptedEnvelopeData,
                                                   encryptedEnvelope: encryptedEnvelopeProto,
                                                   envelopeSource: envelopeSource,
                                                   hotDataDestination: hotDataDestination,
                                                   serverDeliveryTimestamp: serverDeliveryTimestamp,
                                                   completion: completion),
                                 envelopeSource: envelopeSource)
    }
    
    @objc public func processEncryptedEnvelopeData(
            _ encryptedEnvelopeData: Data,
            serverDeliveryTimestamp: UInt64,
            envelopeSource: EnvelopeSource,
            hotDataDestination: String? = nil,
            hotdataMsgFlag: Bool,
            transaction: SDSAnyWriteTransaction,
            completion: @escaping (Error?) -> Void
    ) {
        guard !encryptedEnvelopeData.isEmpty else {
            completion(OWSAssertionError("Empty envelope, envelopeSource: \(envelopeSource)."))
            return
        }
        
        // Drop any too-large messages on the floor. Well behaving clients should never send them.
        guard encryptedEnvelopeData.count <= Self.maxEnvelopeByteCount else {
            completion(OWSAssertionError("Oversize envelope, envelopeSource: \(envelopeSource)."))
            return
        }
        
        // Take note of any messages larger than we expect, but still process them.
        // This likely indicates a misbehaving sending client.
        if encryptedEnvelopeData.count > Self.largeEnvelopeWarningByteCount {
            Logger.verbose("encryptedEnvelopeData: \(encryptedEnvelopeData.count) > : \(Self.largeEnvelopeWarningByteCount)")
            Logger.warn("Unexpectedly large envelope, envelopeSource: \(envelopeSource).")
        }
        
        let encryptedEnvelopeProto: DSKProtoEnvelope
        do {
            encryptedEnvelopeProto = try DSKProtoEnvelope(serializedData: encryptedEnvelopeData)
            
        } catch {
            owsFailDebug("Failed to parse encrypted envelope \(error), envelopeSource: \(envelopeSource)")
            completion(error)
            return
        }
        
        self.processEnvelope(EncryptedEnvelope(unsupporttedMsgJob: nil,
                                               encryptedEnvelopeData: encryptedEnvelopeData,
                                               encryptedEnvelope: encryptedEnvelopeProto,
                                               envelopeSource: envelopeSource,
                                               hotDataDestination: hotDataDestination,
                                               serverDeliveryTimestamp: serverDeliveryTimestamp,
                                               completion: completion),
                             transaction: transaction)
    }
    
    public func processEncryptedEnvelope(
        _ encryptedEnvelopeProto: DSKProtoEnvelope,
        serverDeliveryTimestamp: UInt64,
        hotDataDestination: String?,
        envelopeSource: EnvelopeSource,
        completion: @escaping (Error?) -> Void
    ) {
        processEncryptedEnvelope(EncryptedEnvelope(unsupporttedMsgJob: nil,
                                                   encryptedEnvelopeData: nil,
                                                   encryptedEnvelope: encryptedEnvelopeProto,
                                                   envelopeSource: envelopeSource,
                                                   hotDataDestination: hotDataDestination,
                                                   serverDeliveryTimestamp: serverDeliveryTimestamp,
                                                   completion: completion),
                                 envelopeSource: envelopeSource)
    }
    
    private func processEncryptedEnvelope(_ encryptedEnvelope: EncryptedEnvelope,
                                          envelopeSource: EnvelopeSource) {
        let result = pendingEnvelopes.enqueue(encryptedEnvelope: encryptedEnvelope)
        switch result {
        case .duplicate:
            Logger.warn("Duplicate envelope \(encryptedEnvelope.encryptedEnvelope.timestamp). Server timestamp: \(encryptedEnvelope.serverTimestamp), EnvelopeSource: \(envelopeSource).")
            encryptedEnvelope.completion(MessageProcessingError.duplicatePendingEnvelope)
        case .enqueued:
            drainPendingEnvelopes()
        }
    }
    
    
    public var queuedContentCount: Int {
        pendingEnvelopes.count
    }
    
    private static let maxEnvelopeByteCount = 1024 * 1024 //pin最大支持1M
    public static let largeEnvelopeWarningByteCount = 25 * 1024
    private let serialQueue = DispatchQueue(label: "MessageProcessor.processingQueue",
                                            autoreleaseFrequency: .workItem)
    
    private var pendingEnvelopes = PendingEnvelopes()
    private var isDrainingPendingEnvelopes = false {
        didSet { assertOnQueue(serialQueue) }
    }
    
    private func drainPendingEnvelopes() {
        guard Self.messagePipelineSupervisor.isMessageProcessingPermitted else { return }
        guard TSAccountManager.shared.isRegistered() else { return }
        
        guard CurrentAppContext().shouldProcessIncomingMessages else { return }
        
        serialQueue.async {
            guard !self.isDrainingPendingEnvelopes else { return }
            self.isDrainingPendingEnvelopes = true
            while self.drainNextBatch() {}
            self.isDrainingPendingEnvelopes = false
            if self.pendingEnvelopes.isEmpty {
                NotificationCenter.default.postNotificationNameAsync(Self.messageProcessorDidFlushQueue, object: nil)
            }
        }
    }
    
    /// Returns whether or not to continue draining the queue.
    private func drainNextBatch() -> Bool {
        assertOnQueue(serialQueue)
        owsAssertDebug(isDrainingPendingEnvelopes)
        
        return autoreleasepool {
            // We want a value that is just high enough to yield perf benefits.
            let kIncomingMessageBatchSize = 32
            // If the app is in the background, use batch size of 1.
            // This reduces the risk of us never being able to drain any
            // messages from the queue. We should fine tune this number
            // to yield the best perf we can get.
            let batchSize = CurrentAppContext().isInBackground() ? 1 : kIncomingMessageBatchSize
            let batch = pendingEnvelopes.nextBatch(batchSize: batchSize)
            let batchEnvelopes = batch.batchEnvelopes
            let pendingEnvelopesCount = batch.pendingEnvelopesCount
            
            guard !batchEnvelopes.isEmpty, messagePipelineSupervisor.isMessageProcessingPermitted else {
                if DebugFlags.internalLogging {
                    Logger.info("Processing complete: \(self.queuedContentCount) (memoryUsage: \(LocalDevice.memoryUsageString)).")
                }
                return false
            }
            
            let startTime = CACurrentMediaTime()
            Logger.info("Processing batch of \(batchEnvelopes.count)/\(pendingEnvelopesCount) received envelope(s). (memoryUsage: \(LocalDevice.memoryUsageString))")
            
            var processedEnvelopes: [PendingEnvelope] = []
            self.databaseStorage.write { transaction in
                for envelope in batchEnvelopes {
                    if Self.messagePipelineSupervisor.isMessageProcessingPermitted {
                        self.processEnvelope(envelope, transaction: transaction)
                        processedEnvelopes.append(envelope)
                    } else {
                        // If we're skipping one message, we have to skip them all to preserve ordering
                        // Next time around we can process the skipped messages in order
                        break
                    }
                }
            }
            pendingEnvelopes.removeProcessedEnvelopes(processedEnvelopes)
            let duration = CACurrentMediaTime() - startTime
            Logger.info(String.init(format: "Processed %.0d envelopes in %0.2fms -> %.2f envelopes per second. (memoryUsage: \(LocalDevice.memoryUsageString))", batchEnvelopes.count, duration * 1000, duration > 0 ? Double(batchEnvelopes.count) / duration : 0))
            return true
        }
    }
    
    private func processEnvelope(_ pendingEnvelope: PendingEnvelope, transaction: SDSAnyWriteTransaction) {
//        assertOnQueue(serialQueue)
        
        switch pendingEnvelope.decrypt(transaction: transaction) {
        case .success(let result):
            // NOTE: We use the envelope from the decrypt result, not the pending envelope,
            // since the envelope may be altered by the decryption process in the UD case.
            guard let sourceAddress = result.envelope.source else {
                owsFailDebug("Successful decryption with no source address; discarding message")
                transaction.addAsyncCompletionOffMain {
                    pendingEnvelope.completion(OWSAssertionError("successful decryption with no source address"))
                }
                return
            }
                        
            enum ProcessingStep {
                case discard
                case enqueueForGroupProcessing
                case processNow(shouldDiscardVisibleMessages: Bool)
            }
            let processingStep = { () -> ProcessingStep in
                guard let plaintextData = result.plaintextData else {
                    // Non-v2-group messages can be processed immediately.
                    return .processNow(shouldDiscardVisibleMessages: false)
                }
                
            
                return .processNow(shouldDiscardVisibleMessages: false)
            }()
            
            switch processingStep {
            case .discard:
                // Do nothing.
                Logger.verbose("Discarding job.")
            case .enqueueForGroupProcessing:
                Logger.verbose("enqueueForGroupProcessing job.")
            case .processNow(let shouldDiscardVisibleMessages):
                // Envelopes can be processed immediately if they're:
                // 1. Not a GV2 message.
                // 2. A GV2 message that doesn't require updating the group.
                //
                // The advantage to processing the message immediately is that
                // we can full process the message in the same transaction that
                // we used to decrypt it. This results in a significant perf
                // benefit verse queueing the message and waiting for that queue
                // to open new transactions and process messages. The downside is
                // that if we *fail* to process this message (e.g. the app crashed
                // or was killed), we'll have to re-decrypt again before we process.
                // This is safe, since the decrypt operation would also be rolled
                // back (since the transaction didn't finalize) and should be rare.
                
                var job: OWSMessageContentJob?
                if let envelopeData = result.envelopeData {
                    job = OWSMessageContentJob(envelopeData: envelopeData, plaintextData: result.plaintextData)
                }
                
                if let encryptedEnvelope = pendingEnvelope as? EncryptedEnvelope {
                    if let unsupporttedMsgJob = encryptedEnvelope.unsupporttedMsgJob {
                        job = unsupporttedMsgJob;
                    }
                } else if let decryptedEnvelope = pendingEnvelope as? DecryptedEnvelope {
                    if let unsupporttedMsgJob = decryptedEnvelope.unsupporttedMsgJob {
                        job = unsupporttedMsgJob;
                    }
                }
                
                Self.messageManager.processEnvelopeJob(
                    job,
                    envelope: result.envelope,
                    plaintextData: result.plaintextData,
                    hotDataDestination: result.hotDataDestination,
                    transaction: transaction)
                
            }
            
            transaction.addAsyncCompletionOffMain {
                pendingEnvelope.completion(nil)
            }
        case .failure(let error):
            transaction.addAsyncCompletionOffMain {
                pendingEnvelope.completion(error)
            }
        }
    }
    
//    public enum MessageAckBehavior {
//        case shouldAck
//        case shouldNotAck(error: Error)
//    }
    
    @objc
    public static func handleMessageProcessingOutcome(error: Error?,
                                                      completion: @escaping (Bool, Error?) -> Void) {
        guard let error = error else {
            // Success.
            return completion(true, nil)
        }
        if case MessageProcessingError.duplicatePendingEnvelope = error {
            // _DO NOT_ ACK if de-duplicated before decryption.
            return completion(false, error)
        } else if case MessageProcessingError.blockedSender = error {
            return completion(true, error)
        } else if let owsError = error as? OWSError,
                  owsError.errorCode == OWSErrorCode.failedToDecryptDuplicateMessage.rawValue {
            // _DO_ ACK if de-duplicated during decryption.
            return completion(true, error)
        } else {
            Logger.warn("Failed to process message: \(error)")
            // This should only happen for malformed envelopes. We may eventually
            // want to show an error in this case.
            return completion(true, error)
        }
    }
}

// MARK: -

extension MessageProcessor: MessageProcessingPipelineStage {
    public func supervisorDidResumeMessageProcessing(_ supervisor: MessagePipelineSupervisor) {
        drainPendingEnvelopes()
    }
}

// MARK: -

private protocol PendingEnvelope {
    var completion: (Error?) -> Void { get }
//    var wasReceivedByUD: Bool { get }
    func decrypt(transaction: SDSAnyWriteTransaction) -> Swift.Result<DecryptedEnvelope, Error>
    func isDuplicateOf(_ other: PendingEnvelope) -> Bool
}

// MARK: -

private struct EncryptedEnvelope: PendingEnvelope, Dependencies {
    let unsupporttedMsgJob : OWSMessageContentJob?
    let encryptedEnvelopeData: Data?
    let encryptedEnvelope: DSKProtoEnvelope
    let envelopeSource: EnvelopeSource
    let hotDataDestination: String?
    let serverDeliveryTimestamp: UInt64
    let completion: (Error?) -> Void
    
    public var serverTimestamp: UInt64 {
        encryptedEnvelope.systemShowTimestamp
    }
    
    func decrypt(transaction: SDSAnyWriteTransaction) -> Swift.Result<DecryptedEnvelope, Error> {
                
        if let unsupporttedMsgJob = unsupporttedMsgJob {
            
            return .success(DecryptedEnvelope(
                unsupporttedMsgJob: unsupporttedMsgJob,
                envelope: encryptedEnvelope,
                envelopeData: unsupporttedMsgJob.envelopeData,
                plaintextData: unsupporttedMsgJob.plaintextData,
                envelopeSource: envelopeSource,
                hotDataDestination: hotDataDestination,
                serverDeliveryTimestamp: serverDeliveryTimestamp,
                completion: completion
            ))
        }
        
        let result = Self.messageDecrypter.decryptEnvelope(
            encryptedEnvelope,
            envelopeData: encryptedEnvelopeData,
            transaction: transaction
        )
        switch result {
        case .success(let result):
            return .success(DecryptedEnvelope(
                unsupporttedMsgJob: nil,
                envelope: result.envelope,
                envelopeData: result.envelopeData,
                plaintextData: result.plaintextData,
                envelopeSource: envelopeSource,
                hotDataDestination: hotDataDestination,
                serverDeliveryTimestamp: serverDeliveryTimestamp,
                completion: completion
            ))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func isDuplicateOf(_ other: PendingEnvelope) -> Bool {
        guard let other = other as? EncryptedEnvelope else {
            return false
        }

        return encryptedEnvelope.source == other.encryptedEnvelope.source &&
        encryptedEnvelope.sourceDevice == other.encryptedEnvelope.sourceDevice &&
        encryptedEnvelope.timestamp == other.encryptedEnvelope.timestamp &&
        encryptedEnvelope.systemShowTimestamp == other.encryptedEnvelope.systemShowTimestamp &&
        encryptedEnvelope.sequenceID == other.encryptedEnvelope.sequenceID &&
        encryptedEnvelope.notifySequenceID == other.encryptedEnvelope.notifySequenceID &&
        encryptedEnvelope.lastestMsgFlag == other.encryptedEnvelope.lastestMsgFlag &&
        encryptedEnvelope.criticalLevel == other.encryptedEnvelope.criticalLevel
    }
}

// MARK: -

private struct DecryptedEnvelope: PendingEnvelope {
    let unsupporttedMsgJob : OWSMessageContentJob?
    let envelope: DSKProtoEnvelope
    let envelopeData: Data?
    let plaintextData: Data?
    let envelopeSource: EnvelopeSource
    let hotDataDestination: String?
    let serverDeliveryTimestamp: UInt64
    let completion: (Error?) -> Void
    
    func decrypt(transaction: SDSAnyWriteTransaction) -> Swift.Result<DecryptedEnvelope, Error> {
        return .success(self)
    }
    
    func isDuplicateOf(_ other: PendingEnvelope) -> Bool {
        // This envelope is only used for legacy envelopes.
        // We don't need to de-duplicate.
        false
    }
}

// MARK: -

@objc
public enum EnvelopeSource: UInt, CustomStringConvertible {
    case unknown
    case websocketIdentified
    case websocketUnidentified
    case unsupporttedMsg
    case rest
    case restHotdata
    // We re-decrypt incoming messages after accepting a safety number change.
    case identityChangeError
    case debugUI
    case tests
    case websocketConversationIdentified
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .websocketIdentified:
            return "websocketIdentified"
        case .websocketUnidentified:
            return "websocketUnidentified"
        case .rest:
            return "rest"
        case .restHotdata:
            return "restHotdata"
        case .unsupporttedMsg:
            return "unsupporttedMsg"
        case .identityChangeError:
            return "identityChangeError"
        case .debugUI:
            return "debugUI"
        case .tests:
            return "tests"
        case .websocketConversationIdentified:
            return "websocketConversationIdentified"
        }
    }
}

// MARK: -

public class PendingEnvelopes {
    private let unfairLock = UnfairLock()
    private var pendingEnvelopes = [PendingEnvelope]()
    
    @objc
    public var isEmpty: Bool {
        unfairLock.withLock { pendingEnvelopes.isEmpty }
    }
    
    public var count: Int {
        unfairLock.withLock { pendingEnvelopes.count }
    }
    
    fileprivate struct Batch {
        let batchEnvelopes: [PendingEnvelope]
        let pendingEnvelopesCount: Int
    }
    
    fileprivate func nextBatch(batchSize: Int) -> Batch {
        unfairLock.withLock {
            Batch(batchEnvelopes: Array(pendingEnvelopes.prefix(batchSize)),
                  pendingEnvelopesCount: pendingEnvelopes.count)
        }
    }
    
    fileprivate func removeProcessedEnvelopes(_ processedEnvelopes: [PendingEnvelope]) {
        unfairLock.withLock {
            guard pendingEnvelopes.count >= processedEnvelopes.count else {
                pendingEnvelopes = []
                return
            }
            let oldCount = pendingEnvelopes.count
            pendingEnvelopes = Array(pendingEnvelopes.suffix(from: processedEnvelopes.count))
            let newCount = pendingEnvelopes.count
//            if DebugFlags.internalLogging {
                Logger.info("\(oldCount) -> \(newCount)")
//            }
        }
    }
    
    fileprivate func enqueue(decryptedEnvelope: DecryptedEnvelope) {
        unfairLock.withLock {
            let oldCount = pendingEnvelopes.count
            pendingEnvelopes.append(decryptedEnvelope)
            let newCount = pendingEnvelopes.count
//            if DebugFlags.internalLogging {
                Logger.info("\(oldCount) -> \(newCount)")
//            }
        }
    }
    
    public enum EnqueueResult {
        case duplicate
        case enqueued
    }
    
    fileprivate func enqueue(encryptedEnvelope: EncryptedEnvelope) -> EnqueueResult {
        unfairLock.withLock {
            let oldCount = pendingEnvelopes.count
            
            for pendingEnvelope in pendingEnvelopes {
                if pendingEnvelope.isDuplicateOf(encryptedEnvelope) {
                    return .duplicate
                }
            }
            pendingEnvelopes.append(encryptedEnvelope)
            
            let newCount = pendingEnvelopes.count
//            if DebugFlags.internalLogging {
                Logger.info("\(oldCount) -> \(newCount)")
//            }
            return .enqueued
        }
    }
}

// MARK: -

public enum MessageProcessingError: Error {
    case wrongDestinationUuid
    case invalidMessageTypeForDestinationUuid
    case duplicatePendingEnvelope
    case blockedSender
}
