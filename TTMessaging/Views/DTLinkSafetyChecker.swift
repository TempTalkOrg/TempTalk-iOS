import Foundation

/// Detects deceptive (homograph / spoofing) links so the user can confirm before opening.
/// Only meaningful for http/https URLs.
@objc
public class DTLinkSafetyChecker: NSObject {

    @objc
    public static func isSuspicious(_ url: URL) -> Bool {
        // Dangerous bidi / zero-width control characters anywhere in the URL.
        if containsDangerousScalars(url.absoluteString) {
            return true
        }
        guard let host = url.host, !host.isEmpty else {
            return false
        }
        // Cross-platform parity with desktop `isSneakyLink`: only a pure-ASCII host is
        // treated as safe. Any non-ASCII character, or a Punycode (`xn--`) label — which
        // is merely the ASCII encoding of a non-ASCII domain — triggers the confirmation
        // prompt. This is an intentional conservative choice: it does warn on every
        // internationalized domain (including legitimate ones such as münchen.de), but in
        // exchange no homograph, mixed-script, or whole-script confusable can open
        // silently, and iOS / desktop / Android stay aligned. Because the result is a
        // user-confirmable alert rather than a hard block, the false-positive cost is one
        // extra tap on non-ASCII domains.
        for scalar in host.unicodeScalars where scalar.value > 0x7F {
            return true
        }
        for label in host.split(separator: ".") where label.lowercased().hasPrefix("xn--") {
            return true
        }
        return false
    }

    private static func containsDangerousScalars(_ string: String) -> Bool {
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\u{202A}"..."\u{202E}",  // bidi embeddings / overrides
                 "\u{2066}"..."\u{2069}",  // bidi isolates
                 "\u{200B}"..."\u{200F}",  // zero-width / directional marks
                 "\u{FEFF}":               // zero-width no-break space
                return true
            default:
                continue
            }
        }
        return false
    }
}
