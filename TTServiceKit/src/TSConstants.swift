//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

// MARK: -

@objc
public class TSConstants: NSObject {

    private enum Environment {
        case production,
             test,
             development
    }
    
    private static var environment: Environment {
#if DEBUG_TEST || RELEASE_TEST || RELEASE_CHATIVETEST
        return .test
#else
        return .production
#endif
    }
    
    private static var sortedDomainSpeeds: [String] = []

    @objc
    public static var isUsingProductionService: Bool {
        return environment == .production
    }
    
    private static let currentBundleId = Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier")
    static let temptalkBundleId = "org.difft.chative"
    
    @objc public static var appName: DTAPPName {
        return .tempTalk
    }

    // Never instantiate this class.
    private override init() {}
    
    private static let _configLock = UnfairLock()
    private static var _cachedServerConfig: DTServersEntity?
    
    private static let _hostLock = UnfairLock()
    // Explicit chat host override, written by LastHost restore or failover path.
    // When set, serviceUrlPath(DTServerToChat) returns it instead of sortedDomainSpeeds.
    private static var _mainServiceHostOverride: String?

    @objc public static var defaultServerConfig: DTServersEntity {
        if let cached = _configLock.withLock({ _cachedServerConfig }) { return cached }
        let config = DTServersConfig.fetch()
        _configLock.withLock { _cachedServerConfig = config }
        return config
    }

    @objc public static func invalidateServerConfigCache() {
        _configLock.withLock { _cachedServerConfig = nil }
    }
        
    @objc static var defaultSchema: String {
        "https://"
    }
    
    //DEVELOPMENT environment is not available
    @objc static var defaultMainHost: String {
#if DEBUG_TEST || RELEASE_TEST || RELEASE_CHATIVETEST
            return "chat.test.chative.im"
#else
            return "chat.chative.im"
#endif
    }
        
    @objc public static var mainServiceHost: String {
        set {
            // Non-empty → set override; empty → clear (fall back to speed-test order).
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            _hostLock.withLock { _mainServiceHostOverride = trimmed.isEmpty ? nil : trimmed }
        }
        get {
            guard let result = serviceUrlPath(with: DTServerToChat) else { return defaultMainHost }
            return result.domain
        }
    }

    public static var meetingWebSocketURL: String {
        // Use the public getter so override / serviceUrlPath stays consistent
        return "wss://" + mainServiceHost + "/centrifugo/connection/websocket"
    }
    
    @objc
    public static var mainServiceURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToChat) else { return "" }
            return result.url
        }
    }
    
    @objc
    public static var mainServicePath: String {
        get {
            return TSConstants.defaultServerConfig.servURLPath(DTServerToChat)
        }
    }
    
    // Speech-to-text
    @objc
    public static var speechToTextServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToSpeech2text) else { return "" }
            return result.url
        }
    }
    
    // Avatar storage
    @objc
    public static var avatarStorageServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToAvatar) else { return "" }
            return result.url
        }
    }
    
    // Meeting / call
    @objc
    public static var callServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToCall) else { return "" }
            return result.url
        }
    }
    
    // File sharing
    @objc
    public static var fileShareServiceURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToFileSharing) else { return "" }
            return result.url
        }
    }

    // Root service (no path suffix)
    @objc
    public static var rootServiceURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToRoot) else { return "" }
            return result.url
        }
    }

    // GIF proxy service (/gifs on the chat domain)
    @objc
    public static var gifServiceURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToGIF) else { return "" }
            return result.url
        }
    }

    @objc public static var appUserAgent: String { "\(TSConstants.displayNameForUA)/\(AppVersion.shared().currentAppReleaseVersion) (\(AppVersion.shared().hardwareInfoString()); iOS \(UIDevice.current.systemVersion); Scale/\(UIScreen.main.scale); Build/\(AppVersion.shared().currentAppBuildVersion); AppId \(TSConstants.currentBundleId ?? TSConstants.temptalkBundleId))" }
    
    @objc public static var appDisplayName: String { shared.appDisplayName }
    
    @objc public static var displayNameForUA: String { shared.displayNameForUA }

    @objc public static var appLogoName: String { shared.appLogoName }
    
    @objc public static var officialBotName: String { shared.officialBotName }
    
    @objc public static var officialBotId: String { shared.officialBotId }
    
    @objc public static var applicationGroup: String { shared.applicationGroup }

    // MARK: - Shared UserDefaults Keys (main app ↔ extensions)
    @objc public static let kSharedMeetingActiveKey = "kDTMeetingIsActive"

    private static let shared: TSConstantsProtocol = sharedTemp

    private static let sharedTemp: TSConstantsProtocol = {
        switch environment {
        case .production:
            return TSConstantsTempTalkProduction()
        case .development:
            return TSConstantsTempTalkTest()
        case .test:
            return TSConstantsTempTalkTest()
        }
    }()
}

extension TSConstants {
    static func testDomains(
        _ domains: [String],
        timeout: TimeInterval = 1.0,
        globalTimeout: TimeInterval = 1.5
    ) async -> [(String, TimeInterval)] {
        // Wrap a single domain speed test
        func testDomain(_ domain: String) async -> (String, TimeInterval)? {
            guard let url = URL(string: "https://\(domain)") else { return nil }
            
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = timeout
            
            let start = Date()
            do {
                _ = try await URLSession.shared.data(for: request)
                let duration = Date().timeIntervalSince(start)
                return (domain, duration)
            } catch {
                return nil
            }
        }
        
        return await withTaskGroup(of: (String, TimeInterval)?.self) { group in
            // Launch all domain tests concurrently
            for domain in domains {
                group.addTask {
                    await testDomain(domain)
                }
            }
            
            var results = [(String, TimeInterval)]()
            let deadline = Date().addingTimeInterval(globalTimeout)
            
            // Collect results with a global timeout
            for await result in group {
                if let result = result {
                    results.append(result)
                }
                if Date() > deadline {
                    group.cancelAll() // timeout → cancel pending tasks
                    break
                }
            }
            
            return results.sorted { $0.1 < $1.1 }
        }
    }
    
    @objc public static func refreshDomainSpeeds() {
        let allDomains = defaultServerConfig.domains.map { $0.domain }
        Task {
            let results = await testDomains(allDomains)  // [(domain, speed)]
            
            // Deduplicate: keep the fastest (lowest) time per domain
            let domainSpeeds = Dictionary(results, uniquingKeysWith: { min($0, $1) })
            
            sortedDomainSpeeds = domainSpeeds
                .sorted { $0.value < $1.value }
                .map { $0.key }
        }
    }
    
    // Resolve service URL and cert type by service name
    public static func serviceUrlPath(with name: String) -> (url: String, domain: String, certType: String)? {
        // Root service shares the chat domain (with switching) but has no path suffix
        if name == DTServerToRoot {
            guard let chatResult = serviceUrlPath(with: DTServerToChat) else {
                let url = defaultSchema + defaultMainHost
                return (url, defaultMainHost, "self")
            }
            let url = defaultSchema + chatResult.domain
            return (url, chatResult.domain, chatResult.certType)
        }

        let config = defaultServerConfig

        // 1. Find the service
        guard let service = config.services.first(where: { $0.name == name }) else { return nil }

        // 2. Map domain labels to DTServerDomainEntity objects
        let matchedDomains: [DTServerDomainEntity] = service.domains.compactMap { label in
            config.domains.first(where: { $0.label == label })
        }

        // Self-hosted proxy on: services riding the chat tunnel domains (chat / call / fileSharing /
        // speech2text / grayCheck) resolve through a separate pinned-domain path. CDN / other
        // services (avatar, …) and proxy-off fall through — everything below runs exactly as before,
        // adding no branches to the original speed-test logic.
        let chatTunnelDomains = ProxyManager.shared.tunnelChatDomains()
        if ProxyManager.shared.routesThroughChatTunnel(matchedDomains: matchedDomains, tunnelDomains: chatTunnelDomains),
           let proxyResult = proxyServiceUrlPath(servicePath: service.path, matchedDomains: matchedDomains, chatDomains: chatTunnelDomains) {
            return proxyResult
        }

        // For chat: use the explicit override (set by restoreHostsToTSConstants or
        // failover) until it is explicitly cleared by markAsInvalid or replaced by
        // switchServerHost. This prevents WS reconnection from falling back to a
        // bad defaultMainHost after the override is consumed.
        if name == DTServerToChat,
           let override = _hostLock.withLock({ _mainServiceHostOverride }),
           !override.isEmpty {
            let normalizedOverride = override.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchedEntity = matchedDomains.first(where: {
                $0.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedOverride
            })
            if let matchedEntity = matchedEntity {
                return (defaultSchema + override + service.path, override, matchedEntity.certType)
            }
            // Override not in current chat domain pool — stale pointer,
            // clear it and fall back to speed-test order.
            _hostLock.withLock { _mainServiceHostOverride = nil }
            Logger.warn("[DomainSwitch] override \(override) not in matchedDomains, falling back to speed-test sort")
        }

        var fastestDomainEntity: DTServerDomainEntity? = nil
        for domain in sortedDomainSpeeds {
            if let matched = matchedDomains.first(where: {
                $0.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
                domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }) {
                fastestDomainEntity = matched
                break
            }
        }
            
        // No match found — use default
        var finalDomain = ""
        var finalCertType = ""
        if name == DTServerToAvatar {
            let fallbackDomainEntity = matchedDomains.first
            finalCertType = fastestDomainEntity?.certType ?? fallbackDomainEntity?.certType ?? "authority"
            finalDomain = fastestDomainEntity?.domain ?? fallbackDomainEntity?.domain ?? "d272r1ud4wbyy4.cloudfront.net"
        } else {
            finalCertType = fastestDomainEntity?.certType ?? "self"
            finalDomain = fastestDomainEntity?.domain ?? defaultMainHost
        }
        
        let url = defaultSchema + finalDomain + service.path
        return (url, finalDomain, finalCertType)
    }

    /// Service URL while the self-hosted proxy is on, for a service that rides the chat tunnel
    /// domains: pinned to the whitelisted `proxy.tunnelDomains.chat` list — no speed-test order, no
    /// fallback to non-listed origins (those would go direct and leak the real IP). Picks the current
    /// override if it's one of the proxy domains (failover rotation pointer), else the first listed
    /// domain. The caller has already confirmed the service rides the chat tunnel
    /// (`routesThroughChatTunnel`); returns nil only if the whitelist became empty meanwhile.
    private static func proxyServiceUrlPath(servicePath: String,
                                            matchedDomains: [DTServerDomainEntity],
                                            chatDomains: [String]) -> (url: String, domain: String, certType: String)? {
        guard !chatDomains.isEmpty else { return nil }
        let override = _hostLock.withLock { _mainServiceHostOverride }
        let selected = override.flatMap { ov in
            chatDomains.first(where: { $0.caseInsensitiveCompare(ov) == .orderedSame })
        } ?? chatDomains[0]
        let normalized = selected.lowercased()
        let certType = matchedDomains.first(where: {
            $0.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        })?.certType ?? "self"
        return (defaultSchema + selected + servicePath, selected, certType)
    }
}

// MARK: -

// NOTE: When adding a new service, keep all steps in consistent order for maintainability.
// example: 1. s1,s2,s3 -> s1,s2,s3,s4(new) ✅
//          2. s1,s2,s3 -> s1,s2,s4(new),s3 ❌
private protocol TSConstantsProtocol: AnyObject {
    var mainServiceHost: String { get set }
    var mainServicePath: String { get set }
    var avatarStorageServerURL: String { get set }
    var callServerPath: String { get set }
    var fileShareServicePath: String { get set }
    
    var appDisplayName: String { get }
    var displayNameForUA: String { get }
    var appLogoName: String { get }
    var officialBotName: String { get }
    var officialBotId: String { get }

    var applicationGroup: String { get }
}


// MARK: - Production Release/Debug
private class TSConstantsTempTalkProduction: TSConstantsProtocol {
    var mainServiceHost: String = TSConstants.defaultMainHost
    
    public var mainServicePath = DTServerToChat
    public var avatarStorageServerURL = "https://d272r1ud4wbyy4.cloudfront.net"
    public var callServerPath = DTServerToCall
    public var fileShareServicePath = DTServerToFileSharing

    public let appDisplayName = "Quicall"
    public let displayNameForUA = "Quicall"
    public let appLogoName: String = "logoTempTalk"
    public let officialBotName: String = "Support Team"
    public let officialBotId: String = "+10000"

    public let applicationGroup = "group.org.difft.chative"
}

// MARK: - Test Release_test/Debug_test
private class TSConstantsTempTalkTest: TSConstantsProtocol {
    var mainServiceHost: String = TSConstants.defaultMainHost
    
    public var mainServicePath = DTServerToChat
    public var avatarStorageServerURL = "https://d272r1ud4wbyy4.cloudfront.net"
    public var callServerPath = DTServerToCall
    public var fileShareServicePath = DTServerToFileSharing

    public let appDisplayName = "QuicallTest"
    public let displayNameForUA = "QuicallTest"
    public let appLogoName: String = "logoTempTalk"
    public let officialBotName: String = "Support Team"
    public let officialBotId: String = "+10000"

    public let applicationGroup = "group.org.difft.chativetest"
}

