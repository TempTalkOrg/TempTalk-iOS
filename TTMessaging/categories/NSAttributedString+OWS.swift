//
//  NSAttributedString+OWS.swift
//  TTMessaging
//
//  Created by Ethan on 25/05/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

@objc
public extension NSAttributedString {
    
    @objc(rtlSafeAppend:attributes:)
    func rtlSafeAppend(_ text: String, _ attributes: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        
        let substring = NSAttributedString(string: text, attributes: attributes)
        return rtlSafeAppend(substring)
    }
    
    @objc(rtlSafeAppend:)
    func rtlSafeAppend(_ string: NSAttributedString) -> NSAttributedString {
        
        let result = NSMutableAttributedString()
        if CurrentAppContext().isRTL {
            result.append(string)
            result.append(self)
        } else {
            result.append(self)
            result.append(string)
        }
        
        return result.copy() as! NSAttributedString
    }
    
    @objc(covertString:withMatch:attributes:matchAttributes:)
    class func covertString(_ string: String!, match: String!, attributes: [NSAttributedString.Key: Any]?, matchAttributes: [NSAttributedString.Key: Any]?) -> NSMutableAttributedString {
        
        let mutableAttributedString = NSMutableAttributedString(string: string, attributes: attributes)
        let lowerString = mutableAttributedString.string.lowercased()
        let lowerMatch = match.lowercased()
        guard let range = lowerString.range(of: lowerMatch) else {
            return NSMutableAttributedString(string: string)
        }
        let nsRange = NSRange(range, in:lowerString)
        if let matchAttributes = matchAttributes, matchAttributes.count > 0, nsRange.location != NSNotFound &&
            nsRange.length > 0 &&
            nsRange.location + nsRange.length <= string.count {
            mutableAttributedString.addAttributes(matchAttributes, range: nsRange)
        }
        
        return mutableAttributedString
    }
      
}

