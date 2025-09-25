//
//  ConversationPreviewProcessor.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/8/8.
//

import Foundation


@objc
public class ConversationPreviewProcessor: NSObject {
    
    private static let maxConversationByteCount = 30 * 250 * 1024
    public static let largeConversationWarningByteCount = 30 * 25 * 1024
    private let serialQueue = DispatchQueue(label: "ConversationPreviewProcessor.processingQueue",
                                            autoreleaseFrequency: .workItem)
    
    private var pendingConversations = PendingConversations()
    
    private var isDrainingPendingConversations = false {
        didSet { assertOnQueue(serialQueue) }
    }
    
    public var queuedContentCount: Int {
        pendingConversations.count
    }
    
    @objc
    public func processConversationPreviewData(
        _ conversationData: Data,
        serverDeliveryTimestamp: UInt64,
        completion: @escaping (Error?) -> Void
    ) {
        guard !conversationData.isEmpty else {
            completion(OWSAssertionError("Empty conversationData."))
            return
        }
        
        // Drop any too-large messages on the floor. Well behaving clients should never send them.
        guard conversationData.count <= Self.maxConversationByteCount else {
            completion(OWSAssertionError("Oversize conversationData."))
            return
        }
        
        // Take note of any messages larger than we expect, but still process them.
        // This likely indicates a misbehaving sending client.
        if conversationData.count > Self.largeConversationWarningByteCount {
            Logger.verbose("conversationData: \(conversationData.count) > : \(Self.largeConversationWarningByteCount)")
            owsFailDebug("Unexpectedly large conversationData.")
        }
        
        let conversationPreviewProto: DSKProtoConversationPreview
        do {
            conversationPreviewProto = try DSKProtoConversationPreview(serializedData: conversationData)
        } catch {
            owsFailDebug("Failed to parse conversationPreview \(error)")
            completion(error)
            return
        }
        
        processConversation(ConversationPreview(conversationPreviewData: conversationData,
                                                     conversationPreviewProto: conversationPreviewProto,
                                                     serverDeliveryTimestamp: serverDeliveryTimestamp,
                                                     completion: completion))
    }
    
    private func processConversation(_ conversationPreview: ConversationPreview) {
        let result = pendingConversations.enqueue(conversationPreview: conversationPreview)
        switch result {
        case .duplicate:
            Logger.warn("Duplicate conversation.")
            conversationPreview.completion(ConversationProcessingError.duplicatePendingConversation)
        case .enqueued:
            drainPendingConversations()
        }
    }
    
    private func drainPendingConversations() {
        guard Self.messagePipelineSupervisor.isMessageProcessingPermitted else { return }
        guard TSAccountManager.shared.isRegistered() else { return }
        
        guard CurrentAppContext().shouldProcessIncomingMessages else { return }
        
        serialQueue.async {
            guard !self.isDrainingPendingConversations else { return }
            self.isDrainingPendingConversations = true
            while self.drainNextBatch() {}
            self.isDrainingPendingConversations = false
            if self.pendingConversations.isEmpty {
                
            }
        }
    }
    
    /// Returns whether or not to continue draining the queue.
    private func drainNextBatch() -> Bool {
        assertOnQueue(serialQueue)
        owsAssertDebug(isDrainingPendingConversations)
        
        return autoreleasepool {
            // We want a value that is just high enough to yield perf benefits.
            let kConversationBatchSize = 32
            // If the app is in the background, use batch size of 1.
            // This reduces the risk of us never being able to drain any
            // messages from the queue. We should fine tune this number
            // to yield the best perf we can get.
            let batchSize = CurrentAppContext().isInBackground() ? 1 : kConversationBatchSize
            let batch = pendingConversations.nextBatch(batchSize: batchSize)
            let batchConversations = batch.batchConversations
            let pendingConversationCount = batch.pendingConversationsCount
            
            guard !batchConversations.isEmpty, messagePipelineSupervisor.isMessageProcessingPermitted else {
                Logger.info("Processing complete: \(self.queuedContentCount) (memoryUsage: \(LocalDevice.memoryUsageString)).")
                return false
            }
            
            let startTime = CACurrentMediaTime()
            Logger.info("Processing batch of \(batchConversations.count)/\(pendingConversationCount) received conversation(s). (memoryUsage: \(LocalDevice.memoryUsageString))")
            
            var processedConversations: [PendingConversation] = []
            self.databaseStorage.write { transaction in
                for conversaion in batchConversations {
                    if Self.messagePipelineSupervisor.isMessageProcessingPermitted {
                        self.processConversation(conversaion as! ConversationPreview, transaction: transaction)
                        processedConversations.append(conversaion)
                    } else {
                        // If we're skipping one message, we have to skip them all to preserve ordering
                        // Next time around we can process the skipped messages in order
                        break
                    }
                }
            }
            pendingConversations.removeProcessedConversations(processedConversations)
            let duration = CACurrentMediaTime() - startTime
            Logger.info(String.init(format: "Processed %.0d conversations in %0.2fms -> %.2f conversations per second", batchConversations.count, duration * 1000, duration > 0 ? Double(batchConversations.count) / duration : 0))
            return true
        }
    }
    
    private func processConversation(_ conversationPreview: ConversationPreview, transaction: SDSAnyWriteTransaction) {
        assertOnQueue(serialQueue)
        
        Self.conversationPreviewManager.processConversationPreviewProto(conversationPreview.conversationPreviewProto, transaction: transaction)
        
        transaction.addAsyncCompletionOffMain {
            conversationPreview.completion(nil)
        }
        
    }
    
    @objc
    public static func handleConversationProcessingOutcome(error: Error?,
                                                      completion: @escaping (Bool, Error?) -> Void) {
        guard let error = error else {
            // Success.
            return completion(true, nil)
        }
        if case ConversationProcessingError.duplicatePendingConversation = error {
            // _DO NOT_ ACK if de-duplicated before decryption.
            return completion(false, error)
        }
    }
    
}


// MARK: -

private protocol PendingConversation {
    var completion: (Error?) -> Void { get }
    
    func isDuplicateOf(_ other: PendingConversation) -> Bool
}


// MARK: -

private struct ConversationPreview: PendingConversation, Dependencies {
    let conversationPreviewData: Data?
    let conversationPreviewProto: DSKProtoConversationPreview
    let serverDeliveryTimestamp: UInt64
    
    let completion: (Error?) -> Void
    
    func isDuplicateOf(_ other: PendingConversation) -> Bool {
//        guard let other = other as? ConversationPreview else {
//            return false
//        }

        //TODO:deduplication
        return false
//        return encryptedEnvelope.source == other.encryptedEnvelope.source && encryptedEnvelope.sourceDevice == other.encryptedEnvelope.sourceDevice && encryptedEnvelope.timestamp == other.encryptedEnvelope.timestamp
    }
}


// MARK: -

public class PendingConversations {
    private let unfairLock = UnfairLock()
    private var pendingConversations = [PendingConversation]()
    
    @objc
    public var isEmpty: Bool {
        unfairLock.withLock { pendingConversations.isEmpty }
    }
    
    public var count: Int {
        unfairLock.withLock { pendingConversations.count }
    }
    
    fileprivate struct Batch {
        let batchConversations: [PendingConversation]
        let pendingConversationsCount: Int
    }
    
    fileprivate func nextBatch(batchSize: Int) -> Batch {
        unfairLock.withLock {
            Batch(batchConversations: Array(pendingConversations.prefix(batchSize)),
                  pendingConversationsCount: pendingConversations.count)
        }
    }
    
    fileprivate func removeProcessedConversations(_ processedConversations: [PendingConversation]) {
        unfairLock.withLock {
            guard pendingConversations.count > processedConversations.count else {
                pendingConversations = []
                return
            }
            let oldCount = pendingConversations.count
            pendingConversations = Array(pendingConversations.suffix(from: processedConversations.count))
            let newCount = pendingConversations.count
            Logger.info("\(oldCount) -> \(newCount)")
        }
    }
    
    public enum EnqueueResult {
        case duplicate
        case enqueued
    }
    
    fileprivate func enqueue(conversationPreview: ConversationPreview) -> EnqueueResult {
        unfairLock.withLock {
            let oldCount = pendingConversations.count
            
            for pendingConversation in pendingConversations {
                if pendingConversation.isDuplicateOf(conversationPreview) {
                    return .duplicate
                }
            }
            
            pendingConversations.append(conversationPreview)
            let newCount = pendingConversations.count
            Logger.info("\(oldCount) -> \(newCount)")
            
            return .enqueued
        }
    }
}


// MARK: -

public enum ConversationProcessingError: Error {
    case duplicatePendingConversation
}
