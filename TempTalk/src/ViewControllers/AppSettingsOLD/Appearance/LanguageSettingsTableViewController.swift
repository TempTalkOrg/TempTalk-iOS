//
//  LanguageSettingsTableViewController.swift
//  Signal
//
//  Created by hornet on 2023/9/7.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import SignalMessaging

@objc
class LanguageSettingsTableViewController: OWSTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = Localized("LANGUAGE",
                                  comment: "The title for the theme section in the appearance settings.")

        updateTableContents()
    }

    func updateTableContents() {
        let contents = OWSTableContents()

        let languageSection = OWSTableSection()
//        languageSection.headerTitle = Localized("LANGUAGE",
//                                                     comment: "The title for the theme section in the appearance settings.")

        languageSection.add(languageItem(.chinese))
        languageSection.add(languageItem(.english))
        contents.addSection(languageSection)
        self.contents = contents
    }

    override func applyLanguage() {
        super.applyLanguage()
        title = Localized("LANGUAGE",
                                  comment: "The title for the theme section in the appearance settings.")
        updateTableContents()
    }
    
    func languageItem(_ languageMode: Localize.LanguageMode) -> OWSTableItem {
        return OWSTableItem(
            text: languageMode == .chinese ? Localized("APPEARANCE_SETTINGS_LANGUAGE_ZH",comment: "Action title Notification") : Localized("APPEARANCE_SETTINGS_LANGUAGE_EN",comment: "Action title Notification"),
            actionBlock: { [weak self] in
                self?.changeLanguage(languageMode)
            },
            accessoryType: Localize.languageMode() == languageMode ? .checkmark : .none
        )
    }

    func changeLanguage(_ languageMode: Localize.LanguageMode) {
        Localize.setCurrentLanguageMode(languageMode)
        updateTableContents()
    }

    static var currentThemeName: String {
        return nameForTheme(Theme.getOrFetchCurrentTheme())
    }

    static func nameForTheme(_ mode: ThemeMode) -> String {
        switch mode {
        case .dark:
            return Localized("APPEARANCE_SETTINGS_DARK_THEME_NAME",
                                     comment: "Name indicating that the dark theme is enabled.")
        case .light:
            return Localized("APPEARANCE_SETTINGS_LIGHT_THEME_NAME",
                                     comment: "Name indicating that the light theme is enabled.")
        case .system:
            return Localized("APPEARANCE_SETTINGS_SYSTEM_THEME_NAME",
                                     comment: "Name indicating that the system theme is enabled.")
        }
    }
}
