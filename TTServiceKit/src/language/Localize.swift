//
//  Localize.swift
//  Localize
//
//  Created by Roy Marmelstein on 05/08/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation

/// Internal current language key
let LCLCurrentLanguageKey = "LCLCurrentLanguageKey"

/// Default language. English. If English is unavailable defaults to base localization.
let LCLDefaultLanguage = "en"

/// Base bundle as fallback.
let LCLBaseBundle = "Base"

/// Name for language change notification
public let LCLLanguageChangeNotification = "LCLLanguageChangeNotification"

// MARK: Localization Syntax

/**
Swift 1.x friendly localization syntax, replaces NSLocalizedString
- Parameter string: Key to be localized.
- Returns: The localized string.
*/
public func Localized(_ string: String) -> String {
    return string.localized()
}

public func Localized(_ string: String, comment: String) -> String {
    return string.localized()
}
/**
 Swift 1.x friendly localization syntax with format arguments, replaces String(format:NSLocalizedString)
 - Parameter string: Key to be localized.
 - Returns: The formatted localized string with arguments.
 */
public func Localized(_ string: String, arguments: CVarArg...) -> String {
    return String(format: string.localized(), arguments: arguments)
}

/**
 Swift 1.x friendly plural localization syntax with a format argument
 
 - parameter string:   String to be formatted
 - parameter argument: Argument to determine pluralisation
 
 - returns: Pluralized localized string.
 */
public func LocalizedPlural(_ string: String, argument: CVarArg) -> String {
    return string.localizedPlural(argument)
}


public extension String {
    /**
     Swift 2 friendly localization syntax, replaces NSLocalizedString
     - Returns: The localized string.
     */
     func localized() -> String {
        return localized(using: nil, in: .main)
    }
    
    static func localized(_ string: String) -> String {
        return string.localized()
    }


    /**
     Swift 2 friendly localization syntax with format arguments, replaces String(format:NSLocalizedString)
     - Returns: The formatted localized string with arguments.
     */
    func localizedFormat(_ arguments: CVarArg...) -> String {
        return String(format: localized(), arguments: arguments)
    }
    
    /**
     Swift 2 friendly plural localization syntax with a format argument
     
     - parameter argument: Argument to determine pluralisation
     
     - returns: Pluralized localized string.
     */
    func localizedPlural(_ argument: CVarArg) -> String {
        return NSString.localizedStringWithFormat(localized() as NSString, argument) as String
    }

    /**
     Add comment for NSLocalizedString
     - Returns: The localized string.
    */
    func commented(_ argument: String) -> String {
        return self
    }
}



// MARK: Language Setting Functions
@objc open class Localize: NSObject {
    
    @objc public enum LanguageMode : Int {
        case chinese
        case english
    }
    
    /**
     Swift 2 friendly localization syntax, replaces NSLocalizedString
     - Returns: The localized string.
     */
    @objc open class func localized(_ string: String) -> String {
        return string.localized()
    }
    
    /**
     List available languages
     - Returns: Array of available languages.
     */
    
    @objc open class func availableLanguages(_ excludeBase: Bool = false) -> [String] {
        var availableLanguages = Bundle.main.localizations
        // If excludeBase = true, don't include "Base" in available languages
        if let indexOfBase = availableLanguages.firstIndex(of: "Base") , excludeBase == true {
            availableLanguages.remove(at: indexOfBase)
        }
        return availableLanguages
    }
    /**
     Opreation Systerm Language
     - Returns: code ex: "en"
     */
    
    @objc open class func currentOpreationSystermLanguage() -> String {
        guard let languageCode = Locale.current.languageCode else {
            return LCLDefaultLanguage
        }
        
        if (languageCode.hasPrefix("zh")){
            return "zh_CN";
        } else {
            return LCLDefaultLanguage
        }
    }
    
    @objc open class func userPreferenceLanguage() -> String {
        if let currentLanguage = UserDefaults.standard.object(forKey: LCLCurrentLanguageKey) as? String {
            return currentLanguage
        }
        return currentOpreationSystermLanguage()
    }
    
    @objc open class func isChineseLanguage() -> Bool {
        if userPreferenceLanguage().stripped.hasPrefix("zh"){
            return true
        }
        return false
    }
    
    @objc open class func languageMode() -> LanguageMode {
        if(self.isChineseLanguage()){
            return .chinese
        } else {
            return .english
        }
    }
    
    /**
     Current language
     - Returns: The current language. String.
     */
    @objc open class func currentLanguage() -> String {
        if let currentLanguage = UserDefaults.standard.object(forKey: LCLCurrentLanguageKey) as? String {
            return currentLanguage
        }
        return currentOpreationSystermLanguage()
    }
    
    
    /**
     Change the current language
     - Parameter language: Desired language.
     */
    @objc open class func setCurrentLanguage(_ language: String) {
        let selectedLanguage = availableLanguages().contains(language) ? language : defaultLanguage()
        if (selectedLanguage != userPreferenceLanguage()){
            UserDefaults.standard.set(selectedLanguage, forKey: LCLCurrentLanguageKey)
            UserDefaults.standard.synchronize()
            NotificationCenter.default.post(name: Notification.Name(rawValue: LCLLanguageChangeNotification), object: nil)
        }
    }
    
    
    @objc open class func setCurrentLanguageMode(_ languageMode: LanguageMode) {
        if(languageMode == .chinese){
            setCurrentLanguage("zh_CN")
        } else {
            setCurrentLanguage("en")
        }
    }
    
    
    /**
     Default language
     - Returns: The app's default language. String.
     */
    @objc open class func defaultLanguage() -> String {
//        var defaultLanguage: String = String()
//        guard let preferredLanguage = Bundle.main.preferredLocalizations.first else {
//            return LCLDefaultLanguage
//        }
//        let availableLanguages: [String] = self.availableLanguages()
//        if (availableLanguages.contains(preferredLanguage)) {
//            defaultLanguage = preferredLanguage
//        }
//        else {
//            defaultLanguage = LCLDefaultLanguage
//        }
        return userPreferenceLanguage()
    }
    
    /**
     Resets the current language to the default
     */
    open class func resetCurrentLanguageToDefault() {
        setCurrentLanguage(self.defaultLanguage())
    }
    
    /**
     Get the current language's display name for a language.
     - Parameter language: Desired language.
     - Returns: The localized string.
     */
    @objc open class func displayNameForLanguage(_ language: String) -> String {
        let locale : NSLocale = NSLocale(localeIdentifier: userPreferenceLanguage() ?? defaultLanguage())
        if let displayName = locale.displayName(forKey: NSLocale.Key.identifier, value: language) {
            return displayName
        }
        return String()
    }
}

