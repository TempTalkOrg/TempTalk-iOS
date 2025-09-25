//
//  DTStickMeetingManager.swift
//  Wea
//
//  Created by Ethan on 2022/10/8.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

@objcMembers
open class DTStickMeetingManager: NSObject {
    
    static let shared = DTStickMeetingManager()
    
    static let kMeetingDurationUpdateNotification = Notification.Name("kMeetingDurationUpdateNotification")
    
    /// [channelName : duration]
    var allStickMeetings = AtomicDictionary<String, DTStickCallModel>(lock: .init())
    var timer: Timer?
    var isObservering = false
    var _timing = 0
    
    func startObserving() {
   
        if isObservering {
            Logger.info("\(logTag) meeting duration timer isObservering")
            return
        }
        DispatchMainThreadSafe { [self] in
            invalidate()
            Logger.info("\(logTag) meeting duration timer start")
            _timing = 0
            timer = Timer.weakTimer(withTimeInterval: 1, target: self, selector: #selector(loopObservingAction), userInfo: nil, repeats: true)
            RunLoop.current.add(timer!, forMode: .common)
        }
    }
    
    func stopObserving() {
        Logger.info("\(logTag) meeting duration timer stop")
        
        isObservering = false
        _timing = 0
        if !allStickMeetings.isEmpty {
            removeAllStickMeetings()
        }
        invalidate()
    }
    
    func invalidate() {
        guard let timer = timer else { return }
        timer.invalidate()
        self.timer = nil
    }
    
    @objc
    func loopObservingAction() {
        if allStickMeetings.isEmpty && isObservering {
            stopObserving()
            postNotificationNameAsync()
            return
        }
        
        isObservering = true
        _timing += 1
        allStickMeetings.allValues.forEach { model in
            model.duration = NSNumber(value: model.duration.intValue + 1)
        }
        
        postNotificationNameAsync(_timing)
    }
    
    func postNotificationNameAsync(_ timing: Int = 0) {
        NotificationCenter.default.postNotificationNameAsync(DTStickMeetingManager.kMeetingDurationUpdateNotification, object: NSNumber(value: timing))
    }
        
    func set(stickModel: DTStickCallModel, for channelName: String) {
        guard let oldStickModel = allStickMeetings[channelName] else {
            allStickMeetings[channelName] = stickModel
            return
        }
        let maxDuration = max(stickModel.duration.intValue, oldStickModel.duration.intValue)
        stickModel.duration = NSNumber(value: maxDuration)
        allStickMeetings[channelName] = stickModel
    }
    
    func stickModel(channelName: String) -> DTStickCallModel? {
        
        guard let model = allStickMeetings[channelName] else {
            return nil
        }
        return model
    }
    
    func removeStickModel(channelName: String) {
        allStickMeetings.removeValue(forKey: channelName)
    }
    
    func removeAllStickMeetings() {
        allStickMeetings.removeAllValues()
    }
    
    func stickModel(uniqueId: String) -> DTStickCallModel? {
        let allStickModels = allStickMeetings.allValues
        for stickModel in allStickModels {
            if stickModel.uniqueId == uniqueId {
                return stickModel
            }
        }
        return nil
    }
    
    func removeStickModel(uniqueId: String) {
        guard let stickModel = stickModel(uniqueId: uniqueId) else {
            return
        }
        removeStickModel(channelName: stickModel.channelName)
    }
    
    func allStickMeetingsDictory() -> [String: DTStickCallModel] {
        allStickMeetings.get()
    }
    
    func allStickMeetingsCount() -> Int {
        allStickMeetings.count
    }
    
    
    //MARK: 预约join start/end监控
    static let kMeetingBarJoinNotification = Notification.Name("kMeetingBarJoinNotification")
    private var scheduleTimer: Timer?
    var loopScheduleMeetingsHandler: ( (TimeInterval) -> Void )?
    var observeSchedules = [DTListMeeting]()
    var isObserveringSchedule = false
    var _scheduleTiming: TimeInterval = 0

    func startObservingSchedule() {
        if (isObserveringSchedule) {
            Logger.info("\(logTag) scheduleTimer already start")
            return
        }
        
        _scheduleTiming = 0
        DispatchMainThreadSafe { [self] in
            invalidateScheduleTimer()
            loopObservingScheduleAction(nil)
            
            scheduleTimer = Timer.weakTimer(withTimeInterval: 3, target: self, selector: #selector(loopObservingScheduleAction(_:)), userInfo: nil, repeats: true)
            RunLoop.current.add(scheduleTimer!, forMode: .common)
        }
    }
    
    func stopObservingSchedule() {
        Logger.info("\(logTag) scheduleTimer stop")
        isObserveringSchedule = false
        invalidateScheduleTimer()
        _scheduleTiming = 0
    }
    
    func invalidateScheduleTimer() {
        guard let timer = scheduleTimer else { return }
        timer.invalidate()
        self.scheduleTimer = nil
    }
    
    @objc
    func loopObservingScheduleAction(_ s_timer: Timer?) {
        
        if let _ = s_timer {
            isObserveringSchedule = true
            _scheduleTiming += 3
        }
        guard let loopScheduleMeetingsHandler else {
            return
        }
        loopScheduleMeetingsHandler(_scheduleTiming)
    }
    
    @objc
    func getScheduleMeeting(_ channelName: String) -> DTListMeeting? {
        
        guard !observeSchedules.isEmpty else {
            return nil
        }
        
        var tmpMeeting: DTListMeeting?
        for observeSchedule in observeSchedules {
            if observeSchedule.channelName == channelName {
                tmpMeeting = observeSchedule
                break
            }
        }
        
        return tmpMeeting
    }
            
}
