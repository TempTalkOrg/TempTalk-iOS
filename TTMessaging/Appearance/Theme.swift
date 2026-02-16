//
//  Theme.swift
//  SignalMessaging
//
//  Created by Jaymin on 2025/6/30.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

public extension Notification.Name {
    static let themeDidChange = Notification.Name("ThemeDidChangeNotification")
}

@objc
public extension NSNotification {
    static var ThemeDidChange: NSString { Notification.Name.themeDidChange.rawValue as NSString }
}

@objc public enum ThemeMode: UInt {
    case system
    case light
    case dark
}

final public class Theme: NSObject {
    
    private static let shared = Theme()
    
    private enum Keys {
        static let currentMode = "ThemeKeyCurrentMode"
    }
    private lazy var keyValueStore = SDSKeyValueStore(collection: "ThemeCollection")
    
    override init() {
        super.init()
        
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            // IOS-782: +[Theme shared] re-enterant initialization
            // AppReadiness will invoke the block synchronously if the app is already ready.
            // This doesn't work here, because we'll end up reenterantly calling +shared
            // if the app is in dark mode and the first call to +[Theme shared] happens
            // after the app is ready.
            //
            // It looks like that pattern is only hit in the share extension, but we're better off
            // asyncing always to ensure the dependency chain is broken. We're okay waiting, since
            // there's no guarantee that this block in synchronously executed anyway.
            DispatchQueue.main.async {
                self.notifyIfThemeModeIsNotDefault()
            }
        }
    }
    
    // MARK: - Theme Mode

    @objc public static var isDarkThemeEnabled: Bool { shared.isDarkThemeEnabled }
    
    @objc public static func getOrFetchCurrentMode() -> ThemeMode {
        return shared.getOrFetchCurrentMode()
    }
    
    @objc public static func setCurrentMode(_ mode: ThemeMode) {
        shared.setCurrentMode(mode)
    }
    
    private var cachedIsDarkThemeEnabled: Bool?
    private var cachedCurrentMode: ThemeMode?
    
    private var defaultMode: ThemeMode {
        return .system
    }

    private var isDarkThemeEnabled: Bool {
        // Don't cache this value until it reflects the data store.
        guard AppReadiness.isAppReady else {
            return isSystemDarkThemeEnabled()
        }

        // Always respect the system theme in extensions.
        guard CurrentAppContext().isMainApp else {
            return isSystemDarkThemeEnabled()
        }

        if let cachedIsDarkThemeEnabled {
            return cachedIsDarkThemeEnabled
        }

        let isDarkThemeEnabled: Bool = {
            switch getOrFetchCurrentMode() {
            case .system: return isSystemDarkThemeEnabled()
            case .dark: return true
            case .light: return false
            }
        }()
        cachedIsDarkThemeEnabled = isDarkThemeEnabled

        return isDarkThemeEnabled
    }
    
    private func isSystemDarkThemeEnabled() -> Bool {
        return UITraitCollection.current.userInterfaceStyle == .dark
    }

    private func getOrFetchCurrentMode() -> ThemeMode {
        if let cachedCurrentMode {
            return cachedCurrentMode
        }
        
        guard AppReadiness.isAppReady else {
            return defaultMode
        }
        
        var currentMode: ThemeMode = .system
        databaseStorage.read { transaction in
            if let rawValue = self.keyValueStore.getUInt(Keys.currentMode, transaction: transaction),
               let mode = ThemeMode(rawValue: rawValue) {
                currentMode = mode
            }
        }
        
        cachedCurrentMode = currentMode

        return currentMode
    }

    private func setCurrentMode(_ mode: ThemeMode) {
        AssertIsOnMainThread()
        
        let previousMode = cachedCurrentMode
        
        switch mode {
        case .light:
            cachedIsDarkThemeEnabled = false
        case .dark:
            cachedIsDarkThemeEnabled = true
        case .system:
            cachedIsDarkThemeEnabled = isSystemDarkThemeEnabled()
        }
        
        cachedCurrentMode = mode
        
        // It's safe to do an async write because all accesses check self.cachedCurrentThemeNumber first.
        databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setUInt(mode.rawValue, key: Keys.currentMode, transaction: transaction)
        }
        
        if previousMode != mode {
            themeDidChange()
        }
    }
    
    private func notifyIfThemeModeIsNotDefault() {
        if isDarkThemeEnabled || defaultMode != getOrFetchCurrentMode() {
            themeDidChange()
        }
    }
    
    // MARK: -
    
    @objc public static func systemThemeChanged(windowLevel: NSNumber) {
        shared.systemThemeChanged(windowLevel: windowLevel)
    }
    
    private func systemThemeChanged(windowLevel: NSNumber) {
        // Do nothing, since we haven't setup the theme yet.
        guard cachedIsDarkThemeEnabled != nil else { return }

        // Theme can only be changed externally when in system mode.
        guard getOrFetchCurrentMode() == .system else { return }

        // We may get multiple updates for the same change.
        let isSystemDarkThemeEnabled = isSystemDarkThemeEnabled()
        guard cachedIsDarkThemeEnabled != isSystemDarkThemeEnabled else { return }
        
        cachedIsDarkThemeEnabled = isSystemDarkThemeEnabled
        themeDidChange(windowLevel: windowLevel)
    }
    
    private func themeDidChange(windowLevel: NSNumber? = nil) {
        UIUtil.setupSignalAppearence()
        
        var userInfo: [String: Any]? = nil
        if let windowLevel {
            userInfo = ["windowLevel": windowLevel]
        }
        UIView.performWithoutAnimation {
            NotificationCenter.default.post(
                name: .themeDidChange,
                object: nil,
                userInfo: userInfo
            )
        }
    }
}

extension Theme: ThemeProtocol {
    
    // MARK: Light & Dark
    // Scenes using only the dark theme: Theme.dark.primaryColor
    // Scenes using only the light theme: Theme.light.primaryColor
    @objc public static var dark: ThemeProtocol.Type { DarkTheme.self }
    @objc public static var light: ThemeProtocol.Type { LightTheme.self }
    
    private static var current: ThemeProtocol.Type { isDarkThemeEnabled ? dark : light }
    
    // MARK: Brand Color & Function Color
    @objc public static var primaryColor: UIColor { current.primaryColor }
    @objc public static var successColor: UIColor { current.successColor }
    @objc public static var warningColor: UIColor { current.warningColor }
    @objc public static var errorColor: UIColor { current.errorColor }
    @objc public static var cautionColor: UIColor { current.cautionColor }
    @objc public static var secondaryColor: UIColor { current.secondaryColor }
    @objc public static var lineColor: UIColor { current.lineColor }
    @objc public static var iconColor: UIColor { current.iconColor }
    @objc public static var dividerColor: UIColor { current.dividerColor }
    
    // MARK: Text Color
    @objc public static var tprimaryColor: UIColor { current.tprimaryColor }
    @objc public static var tsecondaryColor: UIColor { current.tsecondaryColor }
    @objc public static var tthirdColor: UIColor { current.tthirdColor }
    @objc public static var tdisableColor: UIColor { current.tdisableColor }
    @objc public static var twhiteColor: UIColor  { current.twhiteColor }
    @objc public static var tblackColor: UIColor  { current.tblackColor }
    @objc public static var twarningColor: UIColor  { current.twarningColor }
    @objc public static var terrorColor: UIColor  { current.terrorColor }
    @objc public static var tsuccessColor: UIColor  { current.tsuccessColor }
    @objc public static var tinfoColor: UIColor  { current.tinfoColor }
    @objc public static var tcautionColor: UIColor  { current.tcautionColor }
    
    // MARK: Background Color
    @objc public static var bg1Color: UIColor  { current.bg1Color }
    @objc public static var bg2Color: UIColor  { current.bg2Color }
    @objc public static var bg3Color: UIColor  { current.bg3Color }
    @objc public static var bg4Color: UIColor  { current.bg4Color }
    @objc public static var bg5Color: UIColor  { current.bg5Color }
    @objc public static var bgdisableColor: UIColor  { current.bgdisableColor }
    @objc public static var bgtooltipColor: UIColor  { current.bgtooltipColor }
    @objc public static var bgmodalColor: UIColor  { current.bgmodalColor }
    @objc public static var bgpopupColor: UIColor  { current.bgpopupColor }
    @objc public static var bgelevateColor: UIColor  { current.bgelevateColor }
    @objc public static var bgskyColor: UIColor  { current.bgskyColor }
    @objc public static var bgspaceColor: UIColor  { current.bgspaceColor }
    @objc public static var defaultColor: UIColor  { current.defaultColor }
    @objc public static var bgpagePrimaryColor: UIColor  { current.bgpagePrimaryColor }
    @objc public static var bgpageSecondaryColor: UIColor  { current.bgpageSecondaryColor }
    
    // MARK: Other Style
    @objc public static var barStyle: UIBarStyle  { current.barStyle }
    @objc public static var barBlurEffect: UIBlurEffect  { current.barBlurEffect }
    @objc public static var keyboardAppearance: UIKeyboardAppearance  { current.keyboardAppearance }
    @objc public static var accentBlueColor: UIColor  { current.accentBlueColor }
}
