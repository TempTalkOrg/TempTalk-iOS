//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

extension DateUtil {
    @objc
    public enum DateType: Int {
        case system
        case hours12
        case hours24
    }

    @objc
    public static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    /// 返回时间 formatter，支持跟随 app 设置的语言进行本地化，eg: 15:00  or  3:00 PM or 下午 3:00
    ///
    /// - parameter dateType: 12小时制、24小时制或者跟随系统设置，默认跟随系统设置
    @objc
    public static func localizedTimeFormatter(dateType: DateType = .system) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        
        var formatTemplate: String
        switch dateType {
        case .hours12:
            formatTemplate = "hh:mm a"
        case .hours24:
            formatTemplate = "HH:mm a"
        default:
            formatTemplate = is24HourFormat() ? "HH:mm a" : "hh:mm a"
        }
        formatter.setLocalizedDateFormatFromTemplate(formatTemplate)
        return formatter
    }

    // Returns the difference in days, ignoring hours, minutes, seconds.
    // If both dates are the same date, returns 0.
    // If firstDate is a day before secondDate, returns 1.
    //
    // Note: Assumes both dates use the "current" calendar.
    @objc
    public static func daysFrom(firstDate: Date, toSecondDate secondDate: Date) -> Int {
        let calendar = Calendar.current
        guard let days = calendar.dateComponents([.day],
                                                 from: calendar.startOfDay(for: firstDate),
                                                 to: calendar.startOfDay(for: secondDate)).day else {
            owsFailDebug("Invalid result.")
            return 0
        }
        return days
    }

    // Returns the difference in years, ignoring shorter units of time.
    // If both dates fall in the same year, returns 0.
    // If firstDate is from the year before secondDate, returns 1.
    //
    // Note: Assumes both dates use the "current" calendar.
    @objc
    public static func yearsFrom(firstDate: Date, toSecondDate secondDate: Date) -> Int {
        let calendar = Calendar.current
        let units: Set<Calendar.Component> = [.era, .year]
        var components1 = calendar.dateComponents(units, from: firstDate)
        var components2 = calendar.dateComponents(units, from: secondDate)
        components1.hour = 12
        components2.hour = 12
        guard let date1 = calendar.date(from: components1),
              let date2 = calendar.date(from: components2) else {
            owsFailDebug("Invalid date.")
            return 0
        }
        guard let result = calendar.dateComponents([.year], from: date1, to: date2).year else {
            owsFailDebug("Missing result.")
            return 0
        }
        return result
    }
    
    @objc
    public static func monthsFrom(firstDate: Date, toSecondDate secondDate: Date) -> Int {
        let calendar = Calendar.current
        let units: Set<Calendar.Component> = [.era, .year, .month]
        var components1 = calendar.dateComponents(units, from: firstDate)
        var components2 = calendar.dateComponents(units, from: secondDate)
        components1.hour = 12
        components2.hour = 12
        guard let date1 = calendar.date(from: components1),
              let date2 = calendar.date(from: components2) else {
            owsFailDebug("Invalid date.")
            return 0
        }
        guard let result = calendar.dateComponents([.month], from: date1, to: date2).month else {
            owsFailDebug("Missing result.")
            return 0
        }
        return result
    }


    // We might receive a message "from the future" due to a bug or
    // malicious sender or a sender whose device time is misconfigured,
    // etc. Clamp message and date headers dates to the past & present.
    private static func clampBeforeNow(_ date: Date) -> Date {
        let nowDate = Date()
        return date < nowDate ? date : nowDate
    }

    @objc
    public static func formatMessageTimestampForCVC(_ timestamp: UInt64,
                                                    shouldUseLongFormat: Bool) -> String {
        let date = clampBeforeNow(Date(millisecondsSince1970: timestamp))
        let calendar = Calendar.current
        let minutesDiff = calendar.dateComponents([.minute], from: date, to: Date()).minute ?? 0
        if minutesDiff < 1 {
            return OWSLocalizedString("DATE_NOW",
                                     comment: "The present; the current time.")
        } else if shouldUseLongFormat && minutesDiff == 1 {
            // Long format has a distinction between singular and plural
            return OWSLocalizedString("DATE_ONE_MINUTE_AGO_LONG",
                                     comment: "Full string for a relative time of one minute ago.")
        } else if minutesDiff <= 60 {
            let shortFormat = OWSLocalizedString("DATE_MINUTES_AGO_FORMAT",
                                                comment: "Format string for a relative time, expressed as a certain number of minutes in the past. Embeds {{The number of minutes}}.")
            let longFormat = OWSLocalizedString("DATE_MINUTES_AGO_LONG_FORMAT",
                                               comment: "Full format string for a relative time, expressed as a certain number of minutes in the past. Embeds {{The number of minutes}}.")
            let format = shouldUseLongFormat ? longFormat : shortFormat
            let minutesString = OWSFormat.formatInt(minutesDiff)
            return String(format: format, minutesString)
        } else {
            return timeFormatter.string(from: date)
        }
    }
    
    /// 格式化会话页消息时间
    /// 规则：展示时分，不包含日期，eg: 15:20 or 3:20 PM （根据系统设置展示 12 或 24 小时制）
    @objc
    public static func formatTimestampForConversationMessage(_ timestamp: UInt64) -> String {
        let date = clampBeforeNow(Date(millisecondsSince1970: timestamp))
        return localizedTimeFormatter().string(from: date)
    }
    
    /// 格式化会话列表消息时间
    /// 规则：
    /// 消息时间距离现在 >= 1年，eg: Oct 20 2023
    /// 消息时间距离现在 >= 1天，eg: Oct 20
    /// 消息发送时间在今天，eg: 15:20 or 3:20 PM （根据系统设置展示 12 或 24 小时制）
    @objc
    public static func formatDateForConversationList(_ date: Date) -> String {
        let date = clampBeforeNow(date)
        let nowTimestamp = Date.ows_millisecondTimestamp()
        let now = Date(millisecondsSince1970: nowTimestamp)
        let yearsDiff = yearsFrom(firstDate: date, toSecondDate: now)
        let daysDiff = daysFrom(firstDate: date, toSecondDate: now)
        
        switch (yearsDiff >= 1, daysDiff >= 1) {
        case (true, _):
            return normalYearMonthAndDayFormatter.string(from: date)
        case (_, true):
            return localizedMothAndDayFormatter.string(from: date)
        default:
            return localizedTimeFormatter().string(from: date)
        }
    }
    
    /// 格式化会话页分割线时间
    /// 规则：
    /// 消息时间距离现在 >= 1年，eg: Oct 20 2023
    /// 消息时间距离现在 > 1天，eg: Fir, Oct 20
    /// 消息时间距离现在 <= 1天，eg: YesterDay or Today
    @objc
    public static func formatDateForConversationHeader(_ date: Date) -> String {
        let date = clampBeforeNow(date)
        let nowTimestamp = Date.ows_millisecondTimestamp()
        let now = Date(millisecondsSince1970: nowTimestamp)
        let yearsDiff = yearsFrom(firstDate: date, toSecondDate: now)
        let daysDiff = daysFrom(firstDate: date, toSecondDate: now)
        
        switch (yearsDiff >= 1, daysDiff > 1) {
        case (true, _):
            // 正常 format 后，英式日期是 "Dec 20, 2023" 格式，Marina 要求不显示 ","，特殊处理下
            return localizedYearMonthAndDayFormatter.string(from: date)
        case (_, true):
            return localizedWeekMothAndDayFormatter.string(from: date)
        default:
            return localizedRecentFormatter.string(from: date)
        }
    }
    

    @objc
    public static func formatDateHeaderForCVC(_ date: Date) -> String {
        let date = clampBeforeNow(date)
        let calendar = Calendar.current
        let monthsDiff = calendar.dateComponents([.month], from: date, to: Date()).month ?? 0
        if monthsDiff >= 6 {
            // Mar 8, 2017
            return dateHeaderOldDateFormatter.string(from: date)
        } else if dateIsOlderThanYesterday(date) {
            // Wed, Mar 3
            return dateHeaderRecentDateFormatter.string(from: date)
        } else {
            // Today / Yesterday
            return dateHeaderRelativeDateFormatter.string(from: date)
        }
    }

    public static func formatTimestampRelatively(_ timestamp: UInt64) -> String {
        let date = clampBeforeNow(Date(millisecondsSince1970: timestamp))
        let calendar = Calendar.current
        let minutesDiff = calendar.dateComponents([.minute], from: date, to: Date()).minute ?? 0
        if minutesDiff < 1 {
            return OWSLocalizedString("DATE_NOW", comment: "The present; the current time.")
        } else {
            let secondsDiff = calendar.dateComponents([.second], from: date, to: Date()).second ?? 0
            return String.formatDurationLossless(durationSeconds: UInt32(secondsDiff))
        }
    }

    private static let dateHeaderRecentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        // Tue, Jun 6
        formatter.setLocalizedDateFormatFromTemplate("EE, MMM d")
        return formatter
    }()

    private static let dateHeaderOldDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        // Mar 8, 2017
        formatter.dateStyle = .medium
        return formatter
    }()

    private static let dateHeaderRelativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        // Today / Yesterday
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    /// 根据当前 app 设置的语言获取对应的 local
    private static var userPerferLocale: Locale {
        if Localize.isChineseLanguage() {
            return Locale(identifier: "zh_Hans_CN")
        } else {
            return Locale(identifier: "en_US_POSIX")
        }
    }
    
    /// 判断当前系统是 24 小时制还是 12 小时制
    private static func is24HourFormat() -> Bool {
        let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)
        if dateFormat?.range(of: "a") == nil {
            return true
        }
        return false
    }
    
    private static var localizedMothAndDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        if formatter.locale.languageCode == "zh" {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter
    }
    
    private static var localizedWeekMothAndDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        formatter.setLocalizedDateFormatFromTemplate("EE, MMM d")
        return formatter
    }
    
    /// 日期 Formatter，支持跟随 app 设置的语言进行本地化，eg: Oct 30, 2023  or 2023年10月30日
    private static var localizedYearMonthAndDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        return formatter
    }
    
    //2024/2/10
    private static var normalYearMonthAndDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }
    
    /// 日期 Formatter，支持跟随 app 设置的语言进行本地化，eg: Yesterday or Today or 昨天 or 今天
    private static var localizedRecentFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = userPerferLocale
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }

    @objc(isSameDayWithTimestamp:timestamp:)
    public static func isSameDay(timestamp timestamp1: UInt64, timestamp timestamp2: UInt64) -> Bool {
        isSameDay(date: NSDate.ows_date(withMillisecondsSince1970: timestamp1),
                  date: NSDate.ows_date(withMillisecondsSince1970: timestamp2))
    }

    @objc(isSameDayWithDate:date:)
    public static func isSameDay(date date1: Date, date date2: Date) -> Bool {
        0 == daysFrom(firstDate: date1, toSecondDate: date2)
    }

    public static func format(interval: TimeInterval) -> String {
        String(format: "%0.3f", interval)
    }
    
    public static func currentTimeZoneInfo() -> (String, String) {
        
        let timeZone = TimeZone.current
        let identifier = timeZone.identifier
        
        let tmpTimeZone = "\(Float(timeZone.secondsFromGMT()) / Float(3600))"
        var utc: String!
        if let timeZoneInt = Int(tmpTimeZone) {
            if tmpTimeZone.contains("-") {
                utc = "UTC\(timeZoneInt)"
            } else {
                utc = "UTC+\(timeZoneInt)"
            }
        } else if let timeZoneFloat = Float(tmpTimeZone) {
            let timeZoneInt = Int(timeZoneFloat)
            let isInt = timeZoneFloat == Float(timeZoneInt)
            if tmpTimeZone.contains("-") {
                utc = isInt ? "UTC\(timeZoneInt)" : "UTC\(timeZoneFloat)"
            } else {
                utc = isInt ? "UTC+\(timeZoneInt)" : "UTC+\(timeZoneFloat)"
            }
        }

        return (identifier, utc)
    }
    
    @objc public static func currentTimeZone() -> Float {
        
        let timeZone = TimeZone.current
        
        let utc = Float(timeZone.secondsFromGMT()) / Float(3600)
        return utc
    }
    
    @objc public static func currentTimeZoneString() -> String {
        return "\(Self.currentTimeZone())"
    }
    
    @objc
    public static func secondsLeftToday() -> TimeInterval {

        return secondsLeftOneDay(Date())
    }
    
    @objc
    public static func secondsPassedToday() -> TimeInterval {

        return secondsPassedOneDay(Date())
    }

    @objc
    public static func secondsLeftOneDay(_ date: Date) -> TimeInterval {
        
        let aDaySeconds: TimeInterval = 24 * 60 * 60
        return aDaySeconds - secondsPassedOneDay(date)
    }
    
    @objc
    public static func secondsPassedOneDay(_ date: Date) -> TimeInterval {
        
        let calendar: Calendar = Calendar(identifier: .gregorian)
        var components: DateComponents = DateComponents()
        components = calendar.dateComponents([.hour, .minute,.second], from: date)
        let passSeconds = TimeInterval(components.hour! * 60 * 60) + TimeInterval(components.minute! * 60) + TimeInterval(components.second!)

        return passSeconds
    }
        
    @objc
    public static func replacingFormatTime(body: String?, pattern: String = kBotTimeIntervalPattern) -> String? {
              
        guard let body, !body.isEmpty else {
            return body
        }

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return body
        }
        
        var matchs = [(String, String)]()
        regex.enumerateMatches(in: body, range: NSMakeRange(0, body.utf16.count)) { result, flags, stop in
            guard let result = result else {
                return
            }
            let string = (body as NSString).substring(with: result.range) as String
            
            let r = result.range(at: 1)
            if let range = Range(r, in: body) {
                matchs.append((string, String(body[range])))
            }
        }
        guard !matchs.isEmpty else {
            return body
        }

        var resultBody = body
        for match in matchs {
            let nsMatchInterval = match.1 as NSString
            let stringDate = schedulerFormatTime(timeInterval: TimeInterval(nsMatchInterval.longLongValue), isDisplayUTC: true)
            resultBody = resultBody.replacingOccurrences(of: match.0, with: stringDate)
        }

        return resultBody
    }
    
    @objc
    public static func schedulerFormatTime(timeInterval: TimeInterval, isDisplayUTC: Bool = false) -> String {

        let targetDate = Date(timeIntervalSince1970: timeInterval)

        let calendar = Calendar(identifier: .gregorian)
        let isToday = calendar.isDateInToday(targetDate)
        let isTomorrow = calendar.isDateInTomorrow(targetDate)
        var components = DateComponents()
        components = calendar.dateComponents([.hour], from: targetDate)
        let hour = components.hour!

        let formatter = DateFormatter()
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var result = ""
        if isToday == true {
            result = "Today \(formatter.string(from: targetDate))"
        } else if isTomorrow == true {
            result = "Tomorrow \(formatter.string(from: targetDate))"
        } else {
            formatter.dateFormat = "EEE, MMM d h:mm a"
            result = formatter.string(from: targetDate)
        }
        
        if hour == 0 {
            result = result.replacingOccurrences(of: "AM", with: "MIDNIGHT")
        } else if hour == 12 {
            result = result.replacingOccurrences(of: "PM", with: "NOON")
        }
        
        if isDisplayUTC == false {
            return result
        }

        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        let utc = "UTC+\(secondsFromGMT / 3600)"
        
        return result + " (\(utc))"
    }

}
