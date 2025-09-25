//
//  DTPatternHelper.swift
//  TTServiceKit
//
//  Created by Ethan on 05/07/2024.
//

import Foundation

@objc
public extension DTPatternHelper {
    
    static func replacingFormatSchema(body: String?, pattern: String = kFormatSchemaPattern, given: String) -> String? {
        
        guard let body, !body.isEmpty else {
            return body
        }
        
        return body.replacingOccurrences(of: pattern, with: given)
        
    }
    
}
