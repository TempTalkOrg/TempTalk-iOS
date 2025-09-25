//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
public enum ThreadMappingChange: Int {
    case delete, insert, update, move
}

@objc
public class ThreadMappingSectionChange: NSObject {

    @objc
    public let type: ThreadMappingChange

    @objc
    public let index: UInt

    init(type: ThreadMappingChange, index: UInt) {
        self.type = type
        self.index = index
    }
}

@objc
public class ThreadMappingRowChange: NSObject {

    @objc
    public let type: ThreadMappingChange

    @objc
    public let uniqueRowId: String

    /// Will be nil for inserts
    @objc
    public let oldIndexPath: IndexPath?

    /// Will be nil for deletes
    @objc
    public let newIndexPath: IndexPath?

    init(type: ThreadMappingChange, uniqueRowId: String, oldIndexPath: IndexPath?, newIndexPath: IndexPath?) {
        #if DEBUG
        switch type {
        case .delete:
            assert(oldIndexPath != nil)
            assert(newIndexPath == nil)
        case .insert:
            assert(oldIndexPath == nil)
            assert(newIndexPath != nil)
        case .update:
            assert(oldIndexPath != nil)
            assert(newIndexPath == nil)
        case .move:
            assert(oldIndexPath != nil)
            assert(newIndexPath != nil)
        }
        #endif

        self.type = type
        self.uniqueRowId = uniqueRowId
        self.oldIndexPath = oldIndexPath
        self.newIndexPath = newIndexPath
    }
}

@objc
public class ThreadMappingDiff: NSObject {

    @objc
    let sectionChanges: [ThreadMappingSectionChange]

    @objc
    let rowChanges: [ThreadMappingRowChange]

    init(sectionChanges: [ThreadMappingSectionChange], rowChanges: [ThreadMappingRowChange]) {
        self.sectionChanges = sectionChanges
        self.rowChanges = rowChanges
    }
}

// MARK: -

@objcMembers
class ThreadMapping: NSObject {
    
    // MARK: -
    
    public var currentFolder: DTChatFolderEntity? {
        set {
            threadFinder.currentFolder = newValue
        }
        get {
            threadFinder.currentFolder
        }
    }
    
    private var queue = DispatchQueue(label: "com.difft.threadMapping", attributes: .concurrent)
    
    private var _threads: [TSThread] = []
    private var threads: [TSThread] {
        get {
            queue.sync {
                return _threads
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._threads = newValue
            }
        }
    }
    
    var threadIds: [String] {
        threads.map { $0.uniqueId }
    }
    
    private var _threadsMap: [String: TSThread] = [:]
    private var threadsMap: [String: TSThread] {
        get {
            queue.sync {
                return _threadsMap
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._threadsMap = newValue
            }
        }
    }
    
    private var _virtualThreads: [DTVirtualThread] = []
    private var virtualThreads: [DTVirtualThread] {
        get {
            queue.sync {
                _virtualThreads
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._virtualThreads = newValue
            }
        }
    }
    
    var virtualThreadIds: [String] {
        virtualThreads.map { $0.uniqueId }
    }
    
    private var _virtualThreadsMap: [String: DTVirtualThread] = [:]
    private var virtualThreadsMap: [String: DTVirtualThread] {
        get {
            queue.sync {
                return _virtualThreadsMap
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._virtualThreadsMap = newValue
            }
        }
    }
    
    private var _inboxCount: UInt = 0
    private(set) var inboxCount: UInt {
        get {
            queue.sync {
                _inboxCount
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._inboxCount = newValue
            }
        }
    }
    
    private var _archiveCount: UInt = 0
    private(set) var archiveCount: UInt {
        get {
            queue.sync {
                _archiveCount
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._archiveCount = newValue
            }
        }
    }
    
    private var _virtualCount: UInt = 0
    private(set) var virtualCount: UInt {
        get {
            queue.sync {
                _virtualCount
            }
        }
        set {
            queue.async(flags: .barrier) {
                self._virtualCount = newValue
            }
        }
    }
    
    private let kConversationSection: Int = HomeViewControllerSection.conversations.rawValue
    private let kVirtualSection: Int = HomeViewControllerSection.virtualThread.rawValue

    // MARK: 仅会话thread
    @objc(indexPathForUniqueId:)
    func indexPath(uniqueId: String) -> IndexPath? {
        guard let index = (threads.firstIndex { $0.uniqueId == uniqueId}) else {
            return nil
        }
        return IndexPath(item: index, section: kConversationSection)
    }
    
    func numberOfItems(inSection section: Int) -> Int {
        if section == kConversationSection {
            return threads.count
        } else if section == kVirtualSection {
            return virtualThreads.count
        }
        
        owsFailDebug("section had unexpected value: \(section)")
        return 0
    }

    @objc(threadForIndexPath:)
    func thread(indexPath: IndexPath) -> TSThread? {
        if indexPath.section == kConversationSection {
            return threads[safe: indexPath.row]
        }
        return virtualThreads[safe: indexPath.row]
    }
    
    func thread(for uniqueId: String) -> TSThread? {
        threadsMap[uniqueId]
    }
    
    func virtualThread(for uniqueId: String) -> DTVirtualThread? {
        virtualThreadsMap[uniqueId]
    }

    let threadFinder = AnyThreadFinder()
    
    @objc
    func updateSwallowingErrors(isArchived: Bool, isCalculate: Bool = true, transaction: SDSAnyReadTransaction) {
        do {
            try update(isArchived: isArchived, isCalculate: isCalculate, transaction: transaction)
        } catch {
            owsFailDebug("error: \(error)")
        }
        if !isArchived {
            do {
                try updateVirtual(transaction: transaction)
            } catch {
                owsFailDebug("error: \(error)")
            }
        }
    }
    
    func update(isArchived: Bool, isCalculate: Bool = true, transaction: SDSAnyReadTransaction) throws {
        try Bench(title: "update thread mapping (\(isArchived ? AnyThreadFinder.archiveGroup : AnyThreadFinder.inboxGroup))") {
            inboxCount = threadFinder.visibleThreadCount(isArchived: false, transaction: transaction)
            archiveCount = threadFinder.visibleThreadCount(isArchived: true, transaction: transaction)
            var newThreads: [TSThread] = []
            var newThreadsMap: [String: TSThread] = [:]
            try threadFinder.enumerateVisibleThreads(isArchived: isArchived, transaction: transaction) {
        
                if self.currentFolder == nil,  DTChatFolderManager.shared().excludeVegaFromAll, let grouThread = $0 as? TSGroupThread, grouThread.businessFromVega(){
                    return
                }
                newThreads.append($0)
                newThreadsMap[$0.uniqueId] = $0
                
            }
            Logger.info("##### \(newThreads.count)")
            if isCalculate {
                threads = newThreads
                threadsMap = newThreadsMap
            }
        }
    }
    
    func updateVirtual(transaction: SDSAnyReadTransaction) throws {
        try Bench(title: "update thread mapping DTVirtualThreadGroup") {
            var newVirtualThreads: [DTVirtualThread] = []
            var newVirtualThreadsMap: [String: DTVirtualThread] = [:]
            try threadFinder.enumerateVirtualThreads(transaction: transaction) {
                newVirtualThreads.append($0)
                newVirtualThreadsMap[$0.uniqueId] = $0
            }
            virtualThreads = newVirtualThreads
            virtualThreadsMap = newVirtualThreadsMap
        }
    }
}
