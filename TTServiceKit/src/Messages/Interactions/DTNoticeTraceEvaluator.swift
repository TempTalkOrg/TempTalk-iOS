//
//  DTNoticeTraceEvaluator.swift
//  TTServiceKit
//
//  Single source of truth for the copy/forward "trace" (留痕) decision.
//  Unifying principle: leave a trace only when OTHERS' real content is carried
//  OUT of the source conversation AND that conversation has others who can see it.
//

import Foundation

public enum DTNoticeTraceEvaluator {

    /// - Parameters:
    ///   - sourceThread: conversation where the trace would be inserted.
    ///   - targetThreads: forward destinations; `nil` for copy (clipboard always "leaves").
    ///   - contentAuthorIds: authors of the carried messages, resolved from their outer-message
    ///     attributes. The evaluator gates only on whether any foreign author is present;
    ///     expanding nested Chat History into inner authors is a caller-side responsibility.
    /// - Returns: whether a trace system message should be sent + inserted at all.
    public static func shouldLeaveTrace(
        sourceThread: TSThread,
        targetThreads: [TSThread]?,
        contentAuthorIds: [String]
    ) -> Bool {
        let localNumber = TSAccountManager.localNumber()

        // (C) Source is Saved/Note-to-self → no one else sees the trace (PRD §2).
        if sourceThread.isNoteToSelf {
            return false
        }

        // (B) Forward whose targets are all the source itself → content never left (PRD §3).
        if let targetThreads {
            let leftSource = targetThreads.contains { $0.uniqueId != sourceThread.uniqueId }
            if !leftSource { return false }
        }

        // (A) No foreign real author among carried content → nothing leaked (PRD §1/4/5).
        for authorId in contentAuthorIds {
            guard !authorId.isEmpty else { continue }
            if localNumber == nil || authorId != localNumber {
                return true
            }
        }
        return false
    }

    /// Foreign authors first (input order preserved), the local user (self) always last (PRD §6).
    /// Skips empty ids; appends self once at the end if present.
    public static func orderForDisplay(_ authorIds: [String]) -> [String] {
        let localNumber = TSAccountManager.localNumber()
        var foreign: [String] = []
        foreign.reserveCapacity(authorIds.count)
        var hasSelf = false
        for authorId in authorIds {
            guard !authorId.isEmpty else { continue }
            if let localNumber, authorId == localNumber {
                hasSelf = true
            } else {
                foreign.append(authorId)
            }
        }
        if hasSelf, let localNumber {
            foreign.append(localNumber)
        }
        return foreign
    }
}
