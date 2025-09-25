//
//  String+Markdown.swift
//  Signal
//
//  Created by Jaymin on 2024/1/23.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public extension String {
    func removeMarkdownStyle() -> String {
        guard !self.isEmpty else {
            return self
        }
        
        let removedSpaceString = replacingOccurrences(of: " ", with: "")
        guard !removedSpaceString.isEmpty else {
            return self
        }
        
        let result = replacingOccurrences(of: "\\\n", with: "\n")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replaceMatches(pattern: "(#+\\s+)(.*?)(\\s*\\1)?", replacement: "$2") // resolve `#xxx` which is not markdown syntax
            .replaceMatches(pattern: "^(-\\s*?|\\*\\s*?|_\\s*?){3,}\\s*", replacement: "") // remove horizontal rules
            .replaceMatches(pattern: "^([\\s\\t]*)([\\*\\-\\+]|\\d+\\.)\\s+", replacement: "$1") // remove strip list `-`
            .replaceMatches(pattern: "\\n={2,}", replacement: "\\n") // replace `/n/n` with `/n`
            .replaceMatches(pattern: "~{3}.*\\n", replacement: "") // remove fenced codeblocks (github flavored markdown)
            .replaceMatches(pattern: "~~", replacement: "") // remove strikethrough (github flavored markdown)
            .replaceMatches(pattern: "`{3}.*\\n", replacement: "") // remove fenced codeblocks (github flavored markdown)
            .replaceMatches(pattern: "<[^>]*>", replacement: "") // remove html tags
            .replaceMatches(pattern: "^[=\\-]{2,}\\s*$", replacement: "") // remove setext-style headers
            .replaceMatches(pattern: "\\[\\^.+?\\](\\: .*?$)?", replacement: "") // remove footnotes
            .replaceMatches(pattern: "\\s{0,2}\\[.*?\\]: .*?$", replacement: "") // remove footnotes
            .replaceMatches(pattern: "\\!\\[(.*?)\\][\\[\\(].*?[\\]\\)]", replacement: "[image]") // replace image with `[image]`
            .replaceMatches(pattern: "\\[([^\\]]*?)\\][\\[\\(].*?[\\]\\)]", replacement: "$1") // replace `[link](htts://test.com)` with `link`
            .replaceMatches(pattern: "^(\\n)?\\s{0,3}>\\s?", replacement: "$1") // remove blockquotes `>`
            .replaceMatches(pattern: "^(\\n)?\\s{0,}#{1,6}\\s*( (.+))? +#+$|^(\\n)?\\s{0,}#{1,6}\\s*( (.+))?$", replacement: "$1$3$4$6") // remove `#` `##`
            .replaceMatches(pattern: "([\\*]+)(\\S)(.*?\\S)??\\1", replacement: "$2$3") // replace `**123**` with `123`
            .replaceMatches(pattern: "(^|\\W)([_]+)(\\S)(.*?\\S)??\\2($|\\W)", replacement: "$1$3$4$5") // replace `_italics_` with `italics`
            .replaceMatches(pattern: "(`{3,})(.*?)\\1", replacement: "$2") // remove code blocks
            .replaceMatches(pattern: "`(.+?)`", replacement: "$1") // remove inline code
            .replaceMatches(pattern: "~(.*?)~", replacement: "$1") // remove strike through
        
        return result
    }
    
    private func replaceMatches(pattern: String, replacement: String) -> String {
        guard !pattern.isEmpty else {
            return self
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) else {
            return self
        }
        let range = NSRange(location: 0, length: self.utf16.count)
        let result = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: replacement)
        return result
    }
}
