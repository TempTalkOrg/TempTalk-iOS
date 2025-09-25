//
//  ThreadSafeDictionary.swift
//  Difft
//
//  Created by Jaymin on 2024/7/15.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

class ThreadSafeDictionary<Key: Hashable, Value> {
    
    private var dictionary: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "com.difft.threadSafeDictionary", attributes: .concurrent)
    
    var count: Int {
        return queue.sync {
            return self.dictionary.count
        }
    }
    
    func set(value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary[key] = value
        }
    }
    
    func value(forKey key: Key) -> Value? {
        return queue.sync {
            return self.dictionary[key]
        }
    }
    
    func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary.removeValue(forKey: key)
        }
    }
}
