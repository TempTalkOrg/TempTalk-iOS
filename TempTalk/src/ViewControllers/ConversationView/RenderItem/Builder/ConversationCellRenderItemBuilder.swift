//
//  ConversationCellRenderItemBuilder.swift
//  Difft
//
//  Created by Jaymin on 2024/7/15.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

// MARK: - Builder

class ConversationCellRenderItemBuilder: NSObject {
    
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        queue.qualityOfService = .userInteractive
        return queue
    }()
    
    private lazy var cachedRenderItems = ThreadSafeDictionary<String, ConversationCellRenderItem>()
    
    func build(
        viewItems: [ConversationViewItem],
        forceRebuildIds: [String],
        style: ConversationStyle
    ) -> Promise<([ConversationCellRenderItem], [String: ConversationCellRenderItem])> {
        
        operationQueue.cancelAllOperations()
        
        guard !viewItems.isEmpty else {
            return .value(([], [:]))
        }
        
        var operations: [OWSOperation] = []
        var renderItems: [ConversationCellRenderItem] = []
        var renderItemsMap: [String: ConversationCellRenderItem] = [:]
        viewItems.forEach { viewItem in
            let uniqueId = viewItem.interaction.uniqueId
            if !forceRebuildIds.contains(uniqueId), let cacheItem = cachedRenderItems.value(forKey: uniqueId) {
                renderItems.append(cacheItem)
                renderItemsMap[uniqueId] = cacheItem
            } else {
                let operation = CreateRenderItemOperation(viewItem: viewItem, style: style) { [weak self] renderItem in
                    guard let self else { return }
                    self.cachedRenderItems.set(value: renderItem, forKey: renderItem.uniqueId)
                }
                operation.qualityOfService = .userInteractive
                operations.append(operation)
            }
        }
        
        if operations.isEmpty {
            return .value((renderItems, renderItemsMap))
        }
        
        return Promise { future in
            let finalOperation = FinalOperation { [weak self] in
                guard let self else { return }
                
                var renderItems: [ConversationCellRenderItem] = []
                var renderItemsMap: [String: ConversationCellRenderItem] = [:]
                viewItems.forEach {
                    let uniqueId = $0.interaction.uniqueId
                    if let renderItem = self.cachedRenderItems.value(forKey: uniqueId) {
                        renderItems.append(renderItem)
                        renderItemsMap[uniqueId] = renderItem
                    }
                }
                future.resolve((renderItems, renderItemsMap))
                
            } didCancelled: {
                future.reject(PromiseError.cancelled)
            }
            finalOperation.qualityOfService = .userInteractive
            operations.forEach { operation in
                finalOperation.addDependency(operation)
            }
            var allOperations = operations
            allOperations.append(finalOperation)
            self.operationQueue.addOperations(allOperations, waitUntilFinished: false)
        }
    }
    
    /// 同步创建 cell render item
    /// 注意：仅适用于数据量非常小的场景，例如 pin message list & combined forwarding message list
    func syncBuild(viewItems: [ConversationViewItem], forceRebuildIds: [String], style: ConversationStyle) -> [ConversationCellRenderItem] {
        guard !viewItems.isEmpty else {
            return []
        }
        
        var renderItems: [ConversationCellRenderItem] = []
        viewItems.forEach { viewItem in
            let uniqueId = viewItem.interaction.uniqueId
            if !forceRebuildIds.contains(uniqueId), let cacheItem = cachedRenderItems.value(forKey: uniqueId) {
                renderItems.append(cacheItem)
            } else {
                var renderItem: ConversationCellRenderItem
                switch viewItem.interaction.interactionType() {
                case .incomingMessage:
                    renderItem = ConversationIncomingMessageRenderItem(viewItem: viewItem, conversationStyle: style)
                case .outgoingMessage:
                    renderItem = ConversationOutgoingMessageRenderItem(viewItem: viewItem, conversationStyle: style)
                case .error, .info:
                    renderItem = ConversationSystemRenderItem(viewItem: viewItem, conversationStyle: style)
                case .unreadIndicator:
                    renderItem = ConversationUnreadRenderItem(viewItem: viewItem, conversationStyle: style)
                default:
                    renderItem = ConversationCellRenderItem(viewItem: viewItem, conversationStyle: style)
                }
                renderItems.append(renderItem)
                self.cachedRenderItems.set(value: renderItem, forKey: uniqueId)
            }
        }
        
        return renderItems
    }
}

// MARK: - Operation

private class CreateRenderItemOperation: OWSOperation {
    
    private let style: ConversationStyle
    private let viewItem: ConversationViewItem
    private let completion: (ConversationCellRenderItem) -> Void
    
    init(viewItem: ConversationViewItem, style: ConversationStyle, completion: @escaping (ConversationCellRenderItem) -> Void) {
        self.style = style
        self.viewItem = viewItem
        self.completion = completion
        super.init()
    }
    
    override func run() {
        if self.isCancelled {
            reportCancelled()
            return
        }
        
        var renderItem: ConversationCellRenderItem
        switch viewItem.interaction.interactionType() {
        case .incomingMessage:
            renderItem = ConversationIncomingMessageRenderItem(viewItem: viewItem, conversationStyle: style)
        case .outgoingMessage:
            renderItem = ConversationOutgoingMessageRenderItem(viewItem: viewItem, conversationStyle: style)
        case .error, .info:
            renderItem = ConversationSystemRenderItem(viewItem: viewItem, conversationStyle: style)
        case .unreadIndicator:
            renderItem = ConversationUnreadRenderItem(viewItem: viewItem, conversationStyle: style)
        default:
            renderItem = ConversationCellRenderItem(viewItem: viewItem, conversationStyle: style)
        }
        
        if self.isCancelled {
            reportCancelled()
            return
        }
        
        completion(renderItem)
        reportSuccess()
    }
}

private class FinalOperation: OWSOperation {
    
    let didFinished: () -> Void
    let didCancelled: () -> Void
    
    init(didFinished: @escaping () -> Void, didCancelled: @escaping () -> Void) {
        self.didFinished = didFinished
        self.didCancelled = didCancelled
        
        super.init()
    }
    
    override func run() {
        if self.isCancelled {
            reportCancelled()
            return
        }
        
        reportSuccess()
    }
    
    override func didCancel() {
        didCancelled()
    }
    
    override func didSucceed() {
        didFinished()
    }
}
