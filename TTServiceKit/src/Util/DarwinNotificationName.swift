//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class DarwinNotificationName: NSObject, ExpressibleByStringLiteral {
    @objc public static let sdsCrossProcess: DarwinNotificationName = "org.difft.sdscrossprocess"
    @objc public static let nseDidReceiveNotification: DarwinNotificationName = "org.difft.nseDidReceiveNotification"
    @objc public static let mainAppHandledNotification: DarwinNotificationName = "org.difft.mainAppHandledNotification"
    @objc public static let mainAppLaunched: DarwinNotificationName = "org.difft.mainAppLaunched"

    public typealias StringLiteralType = String

    private let stringValue: String

    @objc
    public var cString: UnsafePointer<Int8> {
        return stringValue.withCString { $0 }
    }

    @objc
    public var isValid: Bool {
        return stringValue.isEmpty == false
    }

    public required init(stringLiteral value: String) {
        stringValue = value
    }

    @objc
    public init(_ name: String) {
        stringValue = name
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let otherName = object as? DarwinNotificationName else { return false }
        return otherName.stringValue == stringValue
    }

    public override var hash: Int {
        return stringValue.hashValue
    }
}
