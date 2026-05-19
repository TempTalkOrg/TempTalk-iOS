import Foundation

@objc
public final class DTBundleConfigLoader: NSObject {

    private static var bundleFileName: String {
        #if POD_CONFIGURATION_RELEASE_CHATIVETEST || RELEASE_TEST || DEBUG_TEST
        return "default_global_config_test"
        #else
        return "default_global_config_production"
        #endif
    }

    @objc public static func loadBundleConfig() -> Data {
        let bundle = Bundle(for: DTBundleConfigLoader.self)
        guard let url = bundle.url(forResource: bundleFileName, withExtension: "json"),
              let rawData = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
              let data = json["data"],
              let result = try? JSONSerialization.data(withJSONObject: data) else {
            Logger.error("[BundleConfig] Bundle config not found: \(bundleFileName)")
            return "{}".data(using: .utf8)!
        }
        return result
    }
}
