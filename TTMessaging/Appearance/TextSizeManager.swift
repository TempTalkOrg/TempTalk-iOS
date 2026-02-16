//
//  TextSizeManager.swift
//  TTMessaging
//
//  Created by Henry on 2026/01/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import UIKit

public extension Notification.Name {
    static let textSizeDidChange = Notification.Name("TextSizeDidChangeNotification")
}

@objc
public extension NSNotification {
    static var TextSizeDidChange: NSString {
        Notification.Name.textSizeDidChange.rawValue as NSString
    }
}

/// 文字大小级别
@objc public enum TextSizeLevel: Int {
    case `default` = 0   // 默认（系统标准大小）
    case larger = 1      // 大字体

    /// 显示名称
    public var displayName: String {
        switch self {
        case .default: return Localized("TEXT_SIZE_DEFAULT")
        case .larger: return Localized("TEXT_SIZE_LARGER")
        }
    }

    /// 字体缩放比例
    public var scaleFactor: CGFloat {
        switch self {
        case .default: return 1.0
        case .larger: return 1.4  // 大字体放大 40%
        }
    }
}

/// 文字大小管理器
/// 参考 Theme 的实现，提供全局字体大小管理和通知机制
final public class TextSizeManager: NSObject {

    @objc public static let shared = TextSizeManager()

    private enum Keys {
        static let currentLevel = "TextSizeKeyCurrentLevel"
    }

    private lazy var keyValueStore = SDSKeyValueStore(collection: "TextSizeCollection")

    private var cachedCurrentLevel: TextSizeLevel?

    // 标记是否正在加载，防止多个线程同时读取数据库
    private var isLoadingCache = false

    // 条件变量：保护 cachedCurrentLevel 和 isLoadingCache 的读写，并协调线程等待
    private let cacheLoadedCondition = NSCondition()

    private var defaultLevel: TextSizeLevel {
        return .default
    }

    // MARK: - Public API

    /// 获取当前文字大小级别
    @objc public static func getCurrentLevel() -> TextSizeLevel {
        return shared.getCurrentLevel()
    }

    /// 获取当前文字大小级别（支持传入 transaction，避免数据库重入）
    @objc public static func getCurrentLevel(transaction: SDSAnyReadTransaction) -> TextSizeLevel {
        return shared.getCurrentLevel(transaction: transaction)
    }

    /// 设置文字大小级别
    @objc public static func setCurrentLevel(_ level: TextSizeLevel) {
        shared.setCurrentLevel(level)
    }

    /// 获取当前的缩放比例
    @objc public static var currentScaleFactor: CGFloat {
        return shared.getCurrentLevel().scaleFactor
    }

    // MARK: - Private Methods

    /// 获取当前级别（无 transaction，会创建新的读事务）
    private func getCurrentLevel() -> TextSizeLevel {
        cacheLoadedCondition.lock()

        // 快速路径：如果缓存已存在，直接返回
        if let cachedCurrentLevel {
            cacheLoadedCondition.unlock()
            return cachedCurrentLevel
        }

        // 如果另一个线程正在加载，等待它完成
        while isLoadingCache {
            cacheLoadedCondition.wait()
            // 被唤醒后，检查缓存是否已加载
            if let cachedCurrentLevel {
                cacheLoadedCondition.unlock()
                return cachedCurrentLevel
            }
        }

        // 检查 App 是否准备好
        guard AppReadiness.isAppReady else {
            cacheLoadedCondition.unlock()
            return defaultLevel
        }

        // 标记正在加载，防止其他线程重复加载
        isLoadingCache = true
        cacheLoadedCondition.unlock()

        // 在锁外执行数据库操作，避免死锁
        var currentLevel: TextSizeLevel = defaultLevel
        databaseStorage.read { transaction in
            if let rawValue = self.keyValueStore.getInt(Keys.currentLevel, transaction: transaction),
               let level = TextSizeLevel(rawValue: rawValue) {
                currentLevel = level
            }
        }

        // 更新缓存并通知等待的线程
        cacheLoadedCondition.lock()
        cachedCurrentLevel = currentLevel
        isLoadingCache = false
        cacheLoadedCondition.broadcast()  // 唤醒所有等待的线程
        cacheLoadedCondition.unlock()

        return currentLevel
    }

    /// 获取当前级别（使用已有的 transaction，避免重入）
    private func getCurrentLevel(transaction: SDSAnyReadTransaction) -> TextSizeLevel {
        cacheLoadedCondition.lock()

        // 快速路径：如果缓存已存在，直接返回
        if let cachedCurrentLevel {
            cacheLoadedCondition.unlock()
            return cachedCurrentLevel
        }

        // 如果另一个线程正在加载，等待它完成
        while isLoadingCache {
            cacheLoadedCondition.wait()
            // 被唤醒后，检查缓存是否已加载
            if let cachedCurrentLevel {
                cacheLoadedCondition.unlock()
                return cachedCurrentLevel
            }
        }

        // 检查 App 是否准备好
        guard AppReadiness.isAppReady else {
            cacheLoadedCondition.unlock()
            return defaultLevel
        }

        // 标记正在加载，防止其他线程重复加载
        isLoadingCache = true
        cacheLoadedCondition.unlock()

        // 在锁外执行数据库操作，避免死锁
        var currentLevel: TextSizeLevel = defaultLevel
        if let rawValue = self.keyValueStore.getInt(Keys.currentLevel, transaction: transaction),
           let level = TextSizeLevel(rawValue: rawValue) {
            currentLevel = level
        }

        // 更新缓存并通知等待的线程
        cacheLoadedCondition.lock()
        cachedCurrentLevel = currentLevel
        isLoadingCache = false
        cacheLoadedCondition.broadcast()  // 唤醒所有等待的线程
        cacheLoadedCondition.unlock()

        return currentLevel
    }

    private func setCurrentLevel(_ level: TextSizeLevel) {
        AssertIsOnMainThread()

        // 使用条件变量保护缓存读取
        cacheLoadedCondition.lock()
        let previousLevel = cachedCurrentLevel
        cacheLoadedCondition.unlock()

        // 先同步写入数据库，确保数据持久化
        databaseStorage.write { transaction in
            self.keyValueStore.setInt(level.rawValue, key: Keys.currentLevel, transaction: transaction)
        }

        // 数据库写入成功后，再更新缓存（使用条件变量保护）
        cacheLoadedCondition.lock()
        cachedCurrentLevel = level
        cacheLoadedCondition.unlock()

        // 如果级别发生变化，立即发送通知
        if previousLevel != level {
            textSizeDidChange()
        }
    }

    private func textSizeDidChange() {
        // 立即在主线程发送通知（不使用 async）
        AssertIsOnMainThread()

        NotificationCenter.default.post(
            name: .textSizeDidChange,
            object: nil
        )
    }
}

// MARK: - UIFont Extensions for Scalable Fonts

public extension UIFont {

    /// 根据当前字体大小设置返回缩放后的字体
    /// - Parameter shouldScale: 是否应用大字体缩放，默认为 true
    /// - Returns: 缩放后的字体
    @objc func scaled(shouldScale: Bool = true) -> UIFont {
        let scaleFactor = TextSizeManager.currentScaleFactor

        guard shouldScale else {
            return self
        }

        guard scaleFactor != 1.0 else {
            return self
        }

        return self.withSize(self.pointSize * scaleFactor)
    }

    // MARK: - Dynamic Type Fonts (支持选择性缩放)

    /// 获取固定大小的字体（忽略系统 Dynamic Type）
    private static func fixedSizeFont(forTextStyle textStyle: UIFont.TextStyle) -> UIFont {
        let baseSize: CGFloat
        switch textStyle {
        case .largeTitle:
            baseSize = 34.0
        case .title1:
            baseSize = 28.0
        case .title2:
            baseSize = 22.0
        case .title3:
            baseSize = 20.0
        case .headline:
            baseSize = 17.0
        case .body:
            baseSize = 17.0
        case .callout:
            baseSize = 16.0
        case .subheadline:
            baseSize = 15.0
        case .footnote:
            baseSize = 13.0
        case .caption1:
            baseSize = 12.0
        case .caption2:
            baseSize = 11.0
        default:
            baseSize = 17.0
        }
        return UIFont.systemFont(ofSize: baseSize)
    }

    /// Body text (17pt default) - 支持大字体
    @objc static func ows_dynamicTypeBody(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .body).scaled(shouldScale: scaled)
    }

    /// Body text (17pt default) - Objective-C 友好版本，默认支持大字体
    @objc static func ows_dynamicTypeBodyFont() -> UIFont {
        return ows_dynamicTypeBody(scaled: true)
    }

    /// Body text (17pt default) - Objective-C 友好版本，不支持大字体缩放
    @objc static func ows_dynamicTypeBodyFontUnscaled() -> UIFont {
        return ows_dynamicTypeBody(scaled: false)
    }

    /// Subheadline text (15pt default) - Objective-C 友好版本，不支持大字体缩放
    @objc static func ows_dynamicTypeSubheadlineFontUnscaled() -> UIFont {
        return ows_dynamicTypeSubheadline(scaled: false)
    }

    /// Footnote text (13pt default) - Objective-C 友好版本，不支持大字体缩放
    @objc static func ows_dynamicTypeFootnoteFontUnscaled() -> UIFont {
        return ows_dynamicTypeFootnote(scaled: false)
    }

    /// Headline text (17pt semibold default) - 支持大字体
    @objc static func ows_dynamicTypeHeadline(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .headline).scaled(shouldScale: scaled)
    }

    /// Subheadline text (15pt default) - 支持大字体
    @objc static func ows_dynamicTypeSubheadline(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .subheadline).scaled(shouldScale: scaled)
    }

    /// Footnote text (13pt default) - 支持大字体
    @objc static func ows_dynamicTypeFootnote(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .footnote).scaled(shouldScale: scaled)
    }

    /// Caption 1 text (12pt default) - 支持大字体
    @objc static func ows_dynamicTypeCaption1(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .caption1).scaled(shouldScale: scaled)
    }

    /// Caption 2 text (11pt default) - 支持大字体
    @objc static func ows_dynamicTypeCaption2(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .caption2).scaled(shouldScale: scaled)
    }

    /// Title 1 text (28pt default) - 支持大字体
    @objc static func ows_dynamicTypeTitle1(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .title1).scaled(shouldScale: scaled)
    }

    /// Title 2 text (22pt default) - 支持大字体
    @objc static func ows_dynamicTypeTitle2(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .title2).scaled(shouldScale: scaled)
    }

    /// Title 3 text (20pt default) - 支持大字体
    @objc static func ows_dynamicTypeTitle3(scaled: Bool = true) -> UIFont {
        return fixedSizeFont(forTextStyle: .title3).scaled(shouldScale: scaled)
    }

    // MARK: - Regular System Fonts (支持选择性缩放)

    /// Regular font with size - 支持大字体
    @objc static func ows_regularFont(withSize size: CGFloat, scaled: Bool = true) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .regular).scaled(shouldScale: scaled)
    }

    /// Semibold font with size - 支持大字体
    @objc static func ows_semiboldFont(withSize size: CGFloat, scaled: Bool = true) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .semibold).scaled(shouldScale: scaled)
    }
}
