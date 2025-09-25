//
//  GroupNotifyDonotTrackVersionHander.swift
//  TTServiceKit
//
//  Created by user on 2024/10/14.
//

import Foundation

class GroupNotifyDonotTrackVersionHandler : GroupNotifyDonotTrackHandler {
    
    static func handleDonotTrackVersio(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                oldGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.groupNotifyType == .callEndFeedback {
            if DTGroupMeetingRecord.shared().meetingRecordSet.contains(groupNotifyEntity.gid) {
                // Meeting end feedback
                DTGroupMeetingRecord.shared().meetingRecordSet.remove(groupNotifyEntity.gid)
                
                var durationDescription: String?
                let duration = groupNotifyEntity.duration
                
                if duration <= 0 || duration == NSNotFound {
                    durationDescription = ""
                } else if duration < 60 {
                    durationDescription = String(format: " %lds", duration)
                } else {
                    durationDescription = String(format: " %ldm %lds", duration / 60, duration % 60)
                }
                
                DTCallEndProcessor.sendCallEndInfoMessage(thread: newGroupThread,
                                                          duration: durationDescription ?? "",
                                                          serverTimestamp: envelope.systemShowTimestamp,
                                                          transaction: transaction)
                
            }

        } else if groupNotifyEntity.groupNotifyType == .groupCycleReminder {
            
            let remindCycle = groupNotifyEntity.groupRemind.remindCycle
            Logger.info("[group remind] cycle reminder, \(remindCycle)")

            DTGroupUtils.sendGroupReminderMessage(
                withSource: groupNotifyEntity.source,
                serverTimestamp: envelope.systemShowTimestamp,
                isChanged: false,
                thread: newGroupThread,
                remindCycle: remindCycle,
                transaction: transaction
            )

        } else if groupNotifyEntity.groupNotifyType == .meetingReminder {
            
            Logger.info("[group remind] meeting reminder organizer: \(groupNotifyEntity.organizer), meeting name: \(groupNotifyEntity.meetingName)")
            DTGroupUtils.sendMeetingReminderInfoMessageGroupNotifyEntity(groupNotifyEntity,
                                                                         serverTimestamp: envelope.systemShowTimestamp,
                                                                         thread: newGroupThread,
                                                                         transaction: transaction)
            
        } else {
            
            if groupNotifyEntity.groupNotifyDetailedType == .groupInactive {
                
                DTPinnedDataSource.shared().removeAllPinnedMessage(groupNotifyEntity.gid)
                DTGroupUtils.removeGroupBaseInfo(withGid: groupNotifyEntity.gid, transaction: transaction)
                
                if newGroupThread.isSticked {
                    newGroupThread.unstickThread(with: transaction)
                }

                newGroupThread.clearDraft(with: transaction)

            } else if groupNotifyEntity.groupNotifyDetailedType == .archive {
                
                if let group = groupNotifyEntity.group, group.archive {
                    newGroupThread.anyUpdate(transaction: transaction) { gthread in
                        gthread.archiveThread(with: transaction)
                    }
                }
                
            }
        }
        
    }
    
    static func isNeedTrackVersion(groupNotifyEntity: DTGroupNotifyEntity) -> Bool {
        
        if groupNotifyEntity.groupNotifyType == .callEndFeedback,
           groupNotifyEntity.groupNotifyType == .groupCycleReminder,
           groupNotifyEntity.groupNotifyType == .meetingReminder {
            return false
        }
        
        if groupNotifyEntity.groupNotifyDetailedType == .groupInactive {
            return false
        } else if groupNotifyEntity.groupNotifyDetailedType == .archive {
            return false
        }
        
        return true
    }
    
}
