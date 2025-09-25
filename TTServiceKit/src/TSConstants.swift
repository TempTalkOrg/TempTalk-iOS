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
    
    @objc public static var defaultServerConfig: DTServersEntity { DTServersConfig.fetch() }
        
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
            shared.mainServiceHost = newValue
        }
        get {
            guard let result = serviceUrlPath(with: DTServerToChat) else { return defaultMainHost }
            return result.domain
        }
    }
    
    public static var meetingWebSocketURL: String {
        return "wss://" + shared.mainServiceHost + "/centrifugo/connection/websocket"
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
    
    // 语音转文字
    @objc
    public static var speechToTextServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToSpeech2text) else { return "" }
            return result.url
        }
    }
    
    // 头像服务
    @objc
    public static var avatarStorageServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToAvatar) else { return "" }
            return result.url
        }
    }
    
    // 会议相关的路径
    @objc
    public static var callServerURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToCall) else { return "" }
            return result.url
        }
    }
    
    // 文件分享的路径
    @objc
    public static var fileShareServiceURL: String {
        get {
            guard let result = serviceUrlPath(with: DTServerToFileSharing) else { return "" }
            return result.url
        }
    }
    
    @objc public static var appUserAgent: String { "\(TSConstants.displayNameForUA)/\(AppVersion.shared().currentAppReleaseVersion) (\(UIDevice.current.model); iOS \(UIDevice.current.systemVersion); Scale/\(UIScreen.main.scale))" }
    
    @objc public static var appDisplayName: String { shared.appDisplayName }
    
    @objc public static var displayNameForUA: String { shared.displayNameForUA }

    @objc public static var appLogoName: String { shared.appLogoName }
    
    @objc public static var officialBotName: String { shared.officialBotName }
    
    @objc public static var officialBotId: String { shared.officialBotId }
    
    @objc public static var applicationGroup: String { shared.applicationGroup }
    
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
        // 包装单个域名测试
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
            // 并发启动所有域名测试
            for domain in domains {
                group.addTask {
                    await testDomain(domain)
                }
            }
            
            var results = [(String, TimeInterval)]()
            let deadline = Date().addingTimeInterval(globalTimeout)
            
            // 收集结果，带全局超时
            for await result in group {
                if let result = result {
                    results.append(result)
                }
                if Date() > deadline {
                    group.cancelAll() // 超时 -> 取消未完成任务
                    break
                }
            }
            
            return results.sorted { $0.1 < $1.1 }
        }
    }
    
    @objc public static func refreshDomainSpeeds() {
        let allDomains = defaultServerConfig.domains.map { $0.domain }
        Task {
            let results = await testDomains(allDomains)
            let domainSpeeds = Dictionary(uniqueKeysWithValues: results)
            sortedDomainSpeeds = domainSpeeds
                .sorted { $0.value < $1.value }
                .map { $0.key }
        }
    }
    
    // 根据name获取对应的url和认证类型
    public static func serviceUrlPath(with name: String) -> (url: String, domain: String, certType: String)? {
        // 1. 找到服务
        guard let service = defaultServerConfig.services.first(where: { $0.name == name }) else { return nil }
        
        // 2. 找到对应的 DTServerDomainEntity 对象
        let matchedDomains: [DTServerDomainEntity] = service.domains.compactMap { label in
            defaultServerConfig.domains.first(where: { $0.label == label })
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
            
        // 如果没有找到匹配，就走默认
        var finalDomain = ""
        var finalCertType = ""
        if name == DTServerToAvatar {
            finalCertType = fastestDomainEntity?.certType ?? "authority"
            finalDomain = fastestDomainEntity?.domain ?? "d272r1ud4wbyy4.cloudfront.net"
        } else {
            finalCertType = fastestDomainEntity?.certType ?? "self"
            finalDomain = fastestDomainEntity?.domain ?? defaultMainHost
        }
        
        let url = defaultSchema + finalDomain + service.path
        return (url, finalDomain, finalCertType)
    }
}

// MARK: -

// attention: 养成好习惯，加一套服务，每一步严格保持顺序一致，方便维护
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

    public let appDisplayName = "TempTalk"
    public let displayNameForUA = "TempTalk"
    public let appLogoName: String = "logoTempTalk"
    public let officialBotName: String = "TempTalkBot"
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

    public let appDisplayName = "TempTalkTest"
    public let displayNameForUA = "TempTalkTest"
    public let appLogoName: String = "logoTempTalk"
    public let officialBotName: String = "TempTalkBot"
    public let officialBotId: String = "+10000"

    public let applicationGroup = "group.org.difft.chativetest"
}

