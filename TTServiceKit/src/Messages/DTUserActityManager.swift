//
//  DTUserActityManager.swift
//  TTServiceKit
//
//  Created by Ethan on 2022/9/14.
//

import UIKit

@objcMembers
public class DTUserActityManager: NSObject {
    
    public static let shared = DTUserActityManager()
    
    public var threadActityMap: [String : NSOrderedSet]?
    
//    private timer: Timer =
    
    func updateUserActity(groupThread: TSGroupThread, uid: String) {
        
//        var threadActityMap = DTUserActityManager.shared.threadActityMap ?? [String : NSOrderedSet]()
//        
//        let oldUserActity = groupThread.groupModel.userActivity ?? NSOrderedSet()
//        let tmpUserActity = oldUserActity.mutableCopy() as! NSMutableOrderedSet
//        tmpUserActity.insert(uid, at: 0)
//        
//        threadActityMap[groupThread.uniqueId] = tmpUserActity.copy() as? NSOrderedSet
//        DTUserActityManager.shared.threadActityMap = threadActityMap
    }
}
