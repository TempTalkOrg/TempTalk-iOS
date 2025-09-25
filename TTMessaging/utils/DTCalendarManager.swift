//
//  DTCalendarManager.swift
//  TTServiceKit
//
//  Created by Ethan on 22/08/2023.
//

import UIKit
import Mantle

public
enum MeetingAttendeeRole: String {
    case host = "host",
         moderator = "moderator",
         attendee = "attendee",
         guest = "guest",
         audience = "audience",
         proxy = "proxy"
}

public
enum MeetingGoing: String {
    case yes = "yes", no = "no", maybe = "maybe"
}

public enum CalendarRequest: Int {
    case create,
         update,
         query,
         dashboard,
         delete,
         detail,
         going,
         notification,
         copy,
         freebusy,
         groupChange,
         batch_freebusy,
         group_freebusy,
         userInfo,
         addLiveStream,
         proxyPermissions
        
    public func requestUrl(eventId: String? = nil, gid: String? = nil, cid: String? = nil) -> (String, String) {
        
        let path = "v1/calendar/\(cid ?? "default")"
        switch self {
        case .create:
            return (path + "/events", "POST")
        case .detail:
            return (path + "/events" + "/\(eventId!)", "GET")
        case .query:
            return (path + "/events", "GET")
        case .dashboard:
            return ("v1/calendar/dashboard", "GET")
        case .update:
            return (path + "/events" + "/\(eventId!)", "PUT")
        case .delete:
            return (path + "/events" + "/\(eventId!)", "DELETE")
        case .going:
            return (path + "/events" + "/\(eventId!)/going", "PUT")
        case .notification:
            return (path + "/events" + "/\(eventId!)/notification", "PUT")
        case .copy:
            return (path + "/events" + "/\(eventId!)/copy", "GET")
        case .freebusy:
            if let localNumber = TSAccountManager.localNumber() {
                return ("v1/user/\(localNumber)/freebusy", "GET")
            }
            return ("", "GET")
        case .groupChange:
            return ("v1/group/change", "POST")
        case .batch_freebusy:
            return ("v1/user/freebusy", "POST")
        case .group_freebusy:
            return ("v1/group/\(gid!)/freebusy", "GET")
        case .userInfo:
            return ("v1/user/info", "GET")
        case .addLiveStream:
            return (path + "/livestream", "POST")
        case .proxyPermissions:
            return ("v1/proxy/permissions", "GET")
        }
    }
    
}

@objcMembers
public class DTCalendarManager: NSObject {
    
    let DTCalendarMeetingsKey = "meetings"
    var isRequesting = false

    @objc public static let kScheduleMeetingBarUpdate = Notification.Name("kScheduleMeetingBarUpdate")

    public static let shared = DTCalendarManager()
    
    public var isDisplayBadge = true
    
    private let keyValueStore = SDSKeyValueStore(collection: "DTCalendarKeyValueCollection")
    private var scheduleMeetingURL: URL? {
        guard let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            return nil
        }
        return  directory.appendingPathComponent("scheduleMeetings.txt")
    }
    
    public typealias Success = ([String: Any]) -> Void
    public typealias Failure = (String) -> Void

    let schedulerUrlSession = OWSSignalService.sharedInstance().urlSessionForNoneService()
        
    public func getMeeting(_ parameters: [String: Any],
                           success: Success?,
                           failure: Failure?) {
        calendarRequest(.detail,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func deleteMeeting(_ parameters: [String: Any],
                              success: Success?,
                              failure: Failure?) {
        calendarRequest(.delete,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func goingMeeting(_ parameters: [String: Any],
                             success: Success?,
                             failure: Failure?) {
        calendarRequest(.going,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func recieveNotification(_ parameters: [String: Any],
                                    success: Success?,
                                    failure: Failure?) {
        calendarRequest(.notification,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getMeetingList(_ parameters: [String: Any],
                               success: Success?,
                               failure: Failure?) {
        calendarRequest(.dashboard,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getCopyString(_ parameters: [String: Any],
                              success: Success?,
                              failure: Failure?) {
        calendarRequest(.copy,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getIsNowFree(_ parameters: [String: Any],
                             success: Success?,
                             failure: Failure?) {
        calendarRequest(.freebusy,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func batchFreeBusy(_ parameters: [String: Any],
                              success: Success?, failure: Failure?) {
        calendarRequest(.batch_freebusy,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getGroupFreeBusy(_ parameters: [String: Any],
                                 success: Success?,
                                 failure: Failure?) {
        calendarRequest(.group_freebusy,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getUsersInfo(_ parameters: [String: Any],
                             success: Success?,
                             failure: Failure?) {
        calendarRequest(.userInfo,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func addLiveStream(_ parameters: [String: Any],
                              success: Success?,
                              failure: Failure?) {
        calendarRequest(.addLiveStream,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func getProxyPermissions(_ parameters: [String: Any],
                                    success: Success?,
                                    failure: Failure?) {
        calendarRequest(.proxyPermissions,
                        parameters,
                        success: success,
                        failure: failure)
    }
    
    public func groupChange(gid: String, actionCode: Int, target: [String]=[]) {
        
        var parameters: [String : Any] = ["gid": gid,
                                          "actionCode": actionCode]
        if !target.isEmpty {
            let availableTarget = target.filter{ $0.count > 6 }
            guard !availableTarget.isEmpty else {
                //MARK: 只有bot引起的群成员更新不请求
                return
            }
            parameters["target"] = availableTarget
        }
        calendarRequest(.groupChange, parameters) {[weak self] responseObject in
            guard let self else { return }
            guard let status = responseObject["status"] as? Int else {
                return
            }
            if status != 0, let reason = responseObject["reason"] as? String {
                Logger.error("\(logTag) report change error, gid:\(gid), action code:\(actionCode), reason:\(reason)")
                return
            }
            Logger.info("\(logTag) report change success, gid:\(gid), action code:\(actionCode)")
        } failure: { [weak self] error in
            guard let self else { return }
            Logger.error("\(logTag) report change error, gid:\(gid), action code:\(actionCode)")
        }
        
    }

    public func calendarRequest(_ requestType: CalendarRequest, _ parameters: [String: Any], success: Success?, failure: Failure?)  {
        
        var tmpParameters = parameters
        let eventId = parameters["eventId"] as? String
        let cid = parameters["cid"] as? String
        var request: (String, String)!
        if let gid = parameters["gid"] as? String {
            request = requestType.requestUrl(eventId: eventId, gid: gid, cid: cid)
        } else {
            request = requestType.requestUrl(eventId: eventId, cid: cid)
        }
        
        if requestType == .freebusy, request.0.isEmpty {
            Logger.error("\(logTag) uid is nil")
            return
        }

        if parameters["eventId"] != nil {
            tmpParameters.removeValue(forKey: "eventId")
        }
        if parameters["cid"] != nil {
            tmpParameters.removeValue(forKey: "cid")
        }

        calendarRequest(request.0, request.1, tmpParameters, success: success, failure: failure)
    }
    
    func calendarRequest(_ urlString: String, _ method: String, _ parameters: [String: Any]?, success: Success?, failure: Failure?) {
        
        DTFileServiceContext.sharedInstance().fetchAuthToken { [weak self] token in
            guard let self else { return }
            var urlString = urlString
            if method == "DELETE" {
                guard let parameters = parameters, let isRecurring = parameters["isRecurring"], let isAllEvent = parameters["isAllEvent"] else {
                    Logger.debug("\(logTag) parameters and values can't be nil")
                    if let failure = failure {
                        failure("parameters and values can't be nil")
                    }
                    return
                }
                urlString += "?isRecurring=\(isRecurring)&isAllEvent=\(isAllEvent)"
            }
            guard let url = URL(string: urlString) else {
                Logger.error("\(self.logTag) url error: \(urlString)")
                if let failure = failure {
                    failure("invalid url")
                }
                return
            }
            let request = TSRequest(url: url, method: method, parameters: parameters)
            request.authToken = token
            self.schedulerUrlSession.performNonmainRequest(request) { response in
                guard let responseObject = response.responseBodyJson as? [String: Any] else {
                    let error = OWSErrorMakeUnableToProcessServerResponseError() as NSError
                    Logger.error("\(self.logTag) \(error.localizedDescription)")
                    guard let failure = failure else { return }
                    return failure(error.localizedDescription)
                }
                
                guard let success = success else { return }
                success(responseObject)
            } failure: { errorWrapper in
                let nsError = errorWrapper.asNSError
                Logger.error("\(self.logTag) request \(urlString) error, code: \(nsError.code), descri: \(nsError.localizedDescription))")
                guard let failure = failure else { return }
                failure(nsError.localizedDescription)
            }
        } failure: { error in
            guard let error = error as? NSError else { return }
            Logger.error("\(self.logTag) fetch token failure, code: \(error.code) descri: \(error.localizedDescription)")
            guard let failure = failure else { return }
            failure(error.localizedDescription)
        }

    }
    
    public func getMeetingDetail(cid: String?, eventId: String, success: Success?, failure: Failure?) {
        var parameters = ["eventId": eventId, "type": "difft"]
        if let cid {
            parameters["cid"] = cid
        }
        getMeeting(parameters) { [weak self] responseObject in
            guard let self else { return }
            guard let status = responseObject["status"] as? Int else {
                return
            }
            var debugDesc = "\(status), "
            if status != 0, let reason = responseObject["reason"] as? String {
                debugDesc += "reason: \(reason)"
                if let failure = failure {
                    failure(reason)
                }
                Logger.error("\(self.logTag) getMeetingError: \(debugDesc)")
                return
            }
            guard let meetingData = responseObject["data"] as? [String: Any] else {
                Logger.error("\(self.logTag) getMeetingError: data is nil")
                if let failure = failure {
                    failure("not found")
                }
                return
            }
            Logger.debug("\(self.logTag) getMeeting: \(meetingData)")
            
            guard let success = success else {
                return
            }
            success(meetingData)
        } failure: { error in
            if let failure = failure {
                failure(error)
            }
        }

    }
    
    public func getProxyPermissions(success: Success?, failure: Failure?) {

        getProxyPermissions(["type": "own"]) { [weak self] responseObject in
            guard let self else { return }
            guard let status = responseObject["status"] as? Int else {
                return
            }
            var debugDesc = "\(status), "
            if status != 0, let reason = responseObject["reason"] as? String {
                debugDesc += "reason: \(reason)"
                if let failure = failure {
                    failure(reason)
                }
                Logger.error("\(self.logTag) getProxyPermissions: \(debugDesc)")
                return
            }
            guard let meetingData = responseObject["data"] as? [String: Any] else {
                Logger.error("\(self.logTag) getProxyPermissions: data is nil")
                if let failure = failure {
                    failure("not found")
                }
                return
            }
            Logger.info("\(self.logTag) getProxyPermissions: \(meetingData)")
            
            guard let success else {
                return
            }
            success(meetingData)
        } failure: { error in
            if let failure {
                failure(error)
            }
        }

    }
    
    public func requestUpdateLocalNotification(_ completion: @escaping( ([DTListMeeting]?) -> (Void) )) {
        
        guard !isRequesting else {
            completion(nil)
            return
        }

        isRequesting = true
        let startOfDay = Calendar(identifier: .gregorian).startOfDay(for: Date())
        let start = startOfDay.timeIntervalSince1970
        let end = start + 14 * 24 * 3600 - 1
        
        let parameters: [String: Any] = ["start": start, "end": end]
        DTCalendarManager.shared.getMeetingList(parameters) { [weak self] responseObject in
            guard let self else { return }
            isRequesting = false

            guard let status = responseObject["status"] as? Int else {
                completion(nil)
                return
            }
            
            guard status == 0 else {
                if let reason = responseObject["reason"] as? String {
                    Logger.error("\(logTag) status:\(status), reason:\(reason)")
                }
                completion(nil)
                return
            }
            
            guard let data = responseObject["data"] as? [String: Any] else {
                Logger.error("\(logTag) data is nil")
                completion(nil)
                return
            }
                        
            guard let myCalendar = data["myCalendar"] as? [[String: Any]] else {
                Logger.error("\(logTag) myCalendar is nil")
                completion(nil)
                return
            }
            
            var serverVersion: Int = -1
            if let storedItem = calendarStoredItem() {
                let storedVersion = storedItem.version
                if let version = data["version"] as? Int {
                    serverVersion = version
                }
                
                Logger.info("\(logTag) localVersion(\(storedVersion)), serverVersion(\(serverVersion))")
                guard serverVersion >= storedVersion else {
                    completion(nil)
                    return
                }
            }
            
            var allEventsDict = [[String: Any]]()
            for user_calendar in myCalendar {
                guard var events = user_calendar["events"] as? [[String: Any]], !events.isEmpty else {
                    continue
                }
                
                events = events.map({ event in
                    var updatedEvent = event
                    updatedEvent["c_role"] = user_calendar["role"]
                       
                    return updatedEvent
                })
                                
                allEventsDict = allEventsDict + events
            }
            
            DTCalendarManager.shared.cacheMeetings(allEventsDict)
                        
            guard let flatEvents = try? MTLJSONAdapter.models(of: DTListMeeting.self, fromJSONArray: allEventsDict) as? [DTListMeeting] else {
                Logger.error("\(logTag) JSONSerialization error")
                completion(nil)
                return
            }
            
            completion(flatEvents)
        } failure: { [weak self] error in
            guard let self else { return }
            Logger.error("\(logTag) error: \(error)")
            isRequesting = false

            completion(nil)
        }
        
    }
    
    /// 获取两周内每天起始时间戳
    /// - Returns: 起始时间戳
    public class func twoWeeksEveryDayInterval(_ startDate: Date) -> [(TimeInterval, TimeInterval)] {

        var timeIntervals = [(TimeInterval, TimeInterval)]()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let start = startOfDay.timeIntervalSince1970
        
        var end: TimeInterval!
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1)
        if let endOfDay {
            end = endOfDay.timeIntervalSince1970
        } else {
            end = start + DateUtil.secondsLeftToday()

        }
        timeIntervals.append((start, end))
        
        for i in 0..<13 {
            let nextDayStart = end + TimeInterval((24 * 60 * 60) * i)
            let nextDayEnd = nextDayStart + TimeInterval(24 * 60 * 60)
            let nextDayIntenval = (nextDayStart + 1, nextDayEnd)
            
            timeIntervals.append(nextDayIntenval)
        }
        
        return timeIntervals
    }

}

//MARK: cache calendar
public extension DTCalendarManager {
    
    /// 预约会议数据本地化
    /// - Parameters:
    ///   - scheduleMeetings: 会议数组
    ///   - version: 数据版本
    ///   - relatedNames: link其他账号用户名
    func cacheMeetings(_ scheduleMeetings: [[String: Any]]) {
        
        guard scheduleMeetings.isEmpty == false else {
            removeLocalMeetings()
            return
        }
        
        guard let url = scheduleMeetingURL else {
            return
        }
        
        let tmpDictionary = [DTCalendarMeetingsKey: scheduleMeetings] as [String : Any]

        do {
            let data = try JSONSerialization.data(withJSONObject: tmpDictionary, options: [.fragmentsAllowed])
            try data.base64EncodedData().write(to: url, options: .atomic)

        } catch {
            Logger.error("\(logTag) json to data failure:\(error.localizedDescription)")
        }

    }
    
    func readLocalMeetings(completion: @escaping ([DTListMeeting]) -> Void) {
        guard let url = scheduleMeetingURL else {
            return
        }
        
        guard let base64Encoded = try? String(contentsOf: url) else {
            Logger.error("\(logTag) read json from file failure")
            return
        }
        guard let decodedData = Data(base64Encoded: base64Encoded) else {
            return
        }
        
        do {
            let dictionary = try JSONSerialization.jsonObject(with: decodedData, options: .mutableContainers) as? [String: Any]
            guard let dictionary, let jsonMeetings = dictionary[DTCalendarMeetingsKey] as? [[String: Any]] else {
                return
            }
            guard let cacheMeetings = try? MTLJSONAdapter.models(of: DTListMeeting.self, fromJSONArray: jsonMeetings) as? [DTListMeeting] else {
                Logger.error("\(self.logTag) getMeetingListError: JSONSerialization error")
                return
            }
            Logger.info("\(logTag) read meetings from local succeed")
            completion(cacheMeetings)
        } catch {
            Logger.error("\(logTag) read json to dictionary failure:\(error.localizedDescription)")
        }
        
    }
    
    func registerMeetingLocalNotification(_ event: DTListMeeting) {
             
        var userInfo: [AnyHashable: Any]?
        do {
            let dictionary = try MTLJSONAdapter.jsonDictionary(fromModel: event)
            userInfo = dictionary
        } catch {
            Logger.error("\(logTag) Error converting event to dictionary: \(error)")
        }

        let timeInterval = event.start - Date().timeIntervalSince1970
        
        guard let userInfo else {
            Logger.error("\(logTag) userInfo is nil")
            return
        }
        guard timeInterval > 0 else {
            Logger.error("\(logTag) timeInterval <= 0")
            return
        }
        var alertTitle: String!, alertBody: String!
        if let channelName = event.channelName, !channelName.isEmpty, !event.isLiveStream || (event.isLiveStream && event.role != MeetingAttendeeRole.audience.rawValue) {
            alertTitle = TSConstants.appDisplayName
            alertBody = "\(event.topic)\nhas started"
        } else {
            alertTitle = event.topic
            alertBody = "Now"
        }
        
        func replaceMiddlePart(of string: String) -> String {
            let length = string.count
            
            if length == 1 {
                return "***"
            } else if length <= 3 {
                return "***" + String(string.suffix(1))
            }
            
            let start = string.index(string.startIndex, offsetBy: length / 3)
            let end = string.index(string.endIndex, offsetBy: -(length / 3))
            
            let replacedString = string[..<start] + "***" + string[end...]
            
            return String(replacedString)
        }
        
//        var notificationPresenter = self.notificationPresenter
//        if notificationPresenter == nil {
//            notificationPresenter = NotificationPresenter()
//        } else {
//            notificationPresenter = self.notificationPresenter as? NotificationPresenter
//        }
        
        self.notificationPresenter.notifyForScheduleMeeting(withTitle: alertTitle,
                                                            body: alertBody,
                                                            userInfo: userInfo,
                                                            replacingIdentifier: nil,
                                                            triggerTimeInterval: timeInterval) { [self] error in
            let insensitiveTopic = replaceMiddlePart(of: event.topic)
 
            if error != nil {
                if let channelName = event.channelName {
                    Logger.info("\(logTag) regisiter local notification fail: \(insensitiveTopic), \(channelName)")
                } else {
                    Logger.info("\(logTag) regisiter local notification fail: \(insensitiveTopic), \(event.type)")
                }
                return
            }
            
            if let channelName = event.channelName {
                Logger.info("\(logTag) regisiter local notification success: \(insensitiveTopic), \(channelName)")
            } else {
                Logger.info("\(logTag) regisiter local notification success: \(insensitiveTopic), \(event.type)")
            }
            
        }
    }

    
    /// 是否移除预约本地推送
    func removeLocalMeetings() {
        guard let url = scheduleMeetingURL else {
            return
        }
        
        do {
            let isReachable = try url.checkPromisedItemIsReachable()
            if isReachable {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    Logger.error("\(logTag) remove file failure:\(error.localizedDescription)")
                }
            }
        } catch {
            Logger.error("\(logTag) remove file failure:\(error.localizedDescription)")
            return
        }
    }
    
    func cancelEventLocalNotification(_ completionHandler: (() -> Void)? = nil) {
        
        Logger.debug("\(logTag) cancel all local notification")
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendingRequests in
            var needRemoveIdentifiers = [String]()
            for pendingRequest in pendingRequests {
                let needRemove = pendingRequest.content.categoryIdentifier == AppNotificationCategory.scheduleMeetingWithoutActions.identifier
                if (needRemove) {
                    needRemoveIdentifiers.append(pendingRequest.identifier)
                }
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: needRemoveIdentifiers)
            
            guard let completionHandler else {
                return
            }
            
            DispatchMainThreadSafe {
                completionHandler()
            }
        }

    }
    
    func updateLocalNotification(serverVersion: Int, completion: @escaping( () -> (Void) )) {
        
        guard let storedItem = calendarStoredItem() else {
            requestUpdateLocalNotification { [weak self] events in
                if let self, let events {
                    registerLocalNotification(events)
                }
                completion()
            }
            return
        }
        
        let storedVersion = storedItem.version
        Logger.debug("\(serverVersion) -- \(storedVersion)")
        
        guard serverVersion >= storedVersion || serverVersion == 1 else {
            completion()
            return
        }
                
        requestUpdateLocalNotification { [weak self] events in
            if let self, let events {
                registerLocalNotification(events)
            }
            completion()
        }
        
    }
    
    func registerLocalNotification(_ events: [DTListMeeting]) {
        
        let meetingNotificationMax = 20
        var needRegisterEvents = [DTListMeeting]()
        for event in events {
            if event.isEventAllowRegisterNotification() {
                needRegisterEvents.append(event)
            }
            
            if needRegisterEvents.count == meetingNotificationMax {
                Logger.info("\(logTag) regisiter meeting notification max")
                break
            }
        }
        
        Logger.debug("\(logTag) \(needRegisterEvents.count)")
        DTCalendarManager.shared.cancelEventLocalNotification {
            for needRegisterEvent in needRegisterEvents {
                DTCalendarManager.shared.registerMeetingLocalNotification(needRegisterEvent)
            }
        }

    }
    
    static let CalendarStoreItemKey = "CalendarStoreItemKey"
    func saveCalendarStoreItem(_ storeItem: CalendarStoreItem,
                               completion: ( () -> Void )? = nil )  {
     
        databaseStorage.asyncWrite { [self] transaction in
            do {
                try DTCalendarManager.shared.keyValueStore.setCodable(storeItem, key: DTCalendarManager.CalendarStoreItemKey, transaction: transaction)
            } catch {
                Logger.error("\(logTag) store calendar item error \(error.localizedDescription).")
            }
        } completion: {
            guard let completion else { return }
            completion()
        }
        
    }
    
    func calendarStoredItem() -> CalendarStoreItem? {
        
        var storedItem: CalendarStoreItem?
        databaseStorage.read { [self] transaction in
            do {
                storedItem = try DTCalendarManager.shared.keyValueStore.getCodableValue(forKey: DTCalendarManager.CalendarStoreItemKey, transaction: transaction)
            } catch {
                Logger.error("\(logTag) read calendar item error \(error.localizedDescription).")
            }
        }

        return storedItem
    }
    
}

public struct CalendarStoreItem: Codable {
    public let version: Int
    public var mergedUsers: [CalendarMergeUser]
    
    public init(version: Int, mergedUsers: [CalendarMergeUser]) {
        self.version = version
        self.mergedUsers = mergedUsers
    }
}

public struct CalendarMergeUser: Codable {
    public let recipientId: String
    public var name: String
    public var isSelected: Bool
    
    public init(recipientId: String, name: String, isSelected: Bool) {
        self.recipientId = recipientId
        self.name = name
        self.isSelected = isSelected
    }
}


public extension DTListMeeting {
    
    /// 提醒包含join bar / 本地提醒
    /// - Parameter needLog: 是否打印日志
    /// - Returns: result
    func isEventShowJoin(_ needLog: Bool = false) -> Bool {
        var isMeetingEvent = false
        if let channelName, !channelName.isEmpty {
            isMeetingEvent = true
        }
        let belongUserId = cid.recipientId()
        var isLocalNumber = false
        if let localNumber = TSAccountManager.localNumber() {
            isLocalNumber = (belongUserId == localNumber)
        }
        let isMeetingGoing = (going as String) != MeetingGoing.no.rawValue
        
        //MARK: 是会议(google event、google web meeting不提醒) & 自己的 & 要参加 & 收通知
        let shouldJoin = isMeetingEvent && isLocalNumber && isMeetingGoing && receiveNotification
        if needLog, !shouldJoin, let channelName {
            Logger.info("\(logTag) no join bar: \(channelName), \(isMeetingEvent ? "is" : "not") meeting, \(isLocalNumber ? "is" : "not") self, going: \(going), \(receiveNotification ? "is" : "not") recieve")
        }
        
        return shouldJoin
    }
    
    ///  客户端本地提醒弹窗：
    ///  1. 无论type是什么，有channelName的一律弹窗，用户可以点击入会；
    ///  2. 无channelName，type=gg，则不弹窗；
    ///  3. 无channelName, type!=gg，则弹窗，用户可以点击跳转到详情页面；
    
    /// 是否需要注册本地提醒
    /// - Parameter needLog: 是否打印日志
    /// - Returns: result
    func isEventAllowRegisterNotification() -> Bool {
        
        let now = Date().timeIntervalSince1970
        guard start > now else {
            return false
        }
        
        var isMeetingEvent = false
        if let channelName = channelName, !channelName.isEmpty {
            isMeetingEvent = true
        }
        let belongUserId = cid.recipientId()
        var isLocalNumber = false
        if let localNumber = TSAccountManager.localNumber() {
            isLocalNumber = (belongUserId == localNumber)
        }
        
        if isMeetingEvent {
            //MARK: 是会议(google event、google web meeting不提醒) & 自己的 & 要参加 & 收通知
            let isMeetingGoing = going as String != MeetingGoing.no.rawValue
            let shouldAlert = isMeetingEvent && isLocalNumber && isMeetingGoing && receiveNotification
            if shouldAlert, let channelName {
                Logger.info("\(logTag) meeting alert: \(channelName), going: \(going), \(receiveNotification ? "is" : "not") recieve notification")
            }
            return shouldAlert
        }
        
        let shouldAlert = isLocalNumber && receiveNotification
        if shouldAlert {
            Logger.info("\(logTag) event alert: \(eid), \(receiveNotification ? "is" : "not") recieve notification")
        }
        
        return shouldAlert
    }

}

public
extension String {
    
    // cid -> recipientId
    func recipientId() -> String {
        return self.replacingOccurrences(of: "user_", with: "+")
    }

}
