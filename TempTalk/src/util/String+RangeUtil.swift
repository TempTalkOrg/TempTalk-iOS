//
//  String+RangeUtil.swift
//  Wea
//
//  Created by hornet on 2021/12/25.
//
import Foundation

extension String {
    
    func matchStrRange(_ matchStr: String) -> [NSRange] {
           var selfStr = self as NSString
           var withStr = Array(repeating: "X", count: (matchStr as NSString).length).joined(separator: "") //辅助字符串
           if matchStr == withStr { withStr = withStr.lowercased() } //临时处理辅助字符串差错
           var allRange = [NSRange]()
           while selfStr.range(of: matchStr).location != NSNotFound {
               let range = selfStr.range(of: matchStr)
               allRange.append(NSRange(location: range.location,length: range.length))
               selfStr = selfStr.replacingCharacters(in: NSMakeRange(range.location, range.length), with: withStr) as NSString
           }
           return allRange
       }
    
    //Range转换为NSRange
    func toNSRange(_ range: Range<String.Index>) -> NSRange {
          guard let from = range.lowerBound.samePosition(in: utf16), let to = range.upperBound.samePosition(in: utf16) else {
              return NSMakeRange(0, 0)
          }
          return NSMakeRange(utf16.distance(from: utf16.startIndex, to: from), utf16.distance(from: from, to: to))
      }
     
    //NSRange转换为Range
    func toRange(_ range: NSRange) -> Range<String.Index>? {
        guard let from16 = utf16.index(utf16.startIndex, offsetBy: range.location, limitedBy: utf16.endIndex) else { return nil }
        guard let to16 = utf16.index(from16, offsetBy: range.length, limitedBy: utf16.endIndex) else { return nil }
        guard let from = String.Index(from16, within: self) else { return nil }
        guard let to = String.Index(to16, within: self) else { return nil }
        return from ..< to
    }
    
}
 


