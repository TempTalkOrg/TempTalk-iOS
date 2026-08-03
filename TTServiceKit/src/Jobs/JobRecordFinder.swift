//
// Copyright 2024 Difft. All rights reserved.
//
//
// Job record finder for querying persisted jobs by label and status.
// (SignalServiceKit/Jobs/JobRecordFinder.swift)
//
// Adaptations for this fork:
//   - Uses fork's ``DBReadTransaction``/``DBWriteTransaction`` protocols (with
//     `tx.database` accessor) instead of Signal V2's concrete transaction classes.
//   - Removed the `MessageSenderJobRecord.removeMessageAfterSending` special-case
//     in ``fetchAndPruneSomePersistedJobs`` — that subclass doesn't exist in this
//     fork. Future clients that need similar gating can subclass and override.
//

import Foundation
import GRDB

public protocol JobRecordFinder<JobRecordType> {
    associatedtype JobRecordType: JobRecord

    /// Fetches a single JobRecord from the database. Returns `nil` if no
    /// JobRecord exists for `rowId`.
    func fetchJob(rowId: JobRecord.RowId, tx: DBReadTransaction) throws -> JobRecordType?

    /// Removes a single JobRecord from the database.
    func removeJob(_ jobRecord: JobRecordType, tx: DBWriteTransaction)

    /// Fetches all runnable jobs.
    ///
    /// This method may use multiple transactions, may use write transactions,
    /// and may delete jobs that can't ever be run. It returns all jobs that
    /// can be run (and invokes the block for each job).
    ///
    /// Conforming types should avoid long-running write transactions.
    func loadRunnableJobs(updateRunnableJobRecord: @escaping (JobRecordType, DBWriteTransaction) -> Void) async throws -> [JobRecordType]
}

private enum Constants {
    /// The number of JobRecords to fetch in a batch.
    ///
    /// Most job queues won't ever have more than a few records at the same
    /// time. Other times, a job queue may build up a huge backlog, and this
    /// value can help prune it efficiently.
    static let batchSize = 400
}

public class JobRecordFinderImpl<JobRecordType>: JobRecordFinder where JobRecordType: JobRecord {
    private let db: any DB

    public init(db: any DB) {
        self.db = db
    }

    public func fetchJob(rowId: JobRecord.RowId, tx: DBReadTransaction) throws -> JobRecordType? {
        do {
            let database = tx.database
            return try JobRecordType.fetchOne(database, key: rowId)
        } catch {
            throw error.grdbErrorForLogging
        }
    }

    public func removeJob(_ jobRecord: JobRecordType, tx: DBWriteTransaction) {
        jobRecord.anyRemove(transaction: tx)
    }

    public func loadRunnableJobs(updateRunnableJobRecord: @escaping (JobRecordType, DBWriteTransaction) -> Void) async throws -> [JobRecordType] {
        var allRunnableJobs = [JobRecordType]()
        var afterRowId: JobRecord.RowId?
        while true {
            let (runnableJobs, hasMoreAfterRowId): ([JobRecordType], JobRecord.RowId?) = try await db.awaitableWrite { tx in
                try self.fetchAndPruneSomePersistedJobs(afterRowId: afterRowId, updateRunnableJobRecord: updateRunnableJobRecord, tx: tx)
            }
            allRunnableJobs.append(contentsOf: runnableJobs)
            guard let hasMoreAfterRowId else {
                break
            }
            afterRowId = hasMoreAfterRowId
        }
        return allRunnableJobs
    }

    private func fetchAndPruneSomePersistedJobs(
        afterRowId: JobRecord.RowId?,
        updateRunnableJobRecord: (JobRecordType, DBWriteTransaction) -> Void,
        tx: DBWriteTransaction
    ) throws -> ([JobRecordType], JobRecord.RowId?) {
        let (jobs, hasMore) = try fetchSomeJobs(afterRowId: afterRowId, tx: tx)
        var runnableJobs = [JobRecordType]()
        for job in jobs {
            let canRunJob: Bool = {
                // ``exclusiveProcessIdentifier`` is reserved for cross-process scenarios
                // (e.g. NSE persisting a job that the host app should pick up). If it's
                // set we currently treat the job as obsolete on app start. Future fork
                // clients that need this can extend the gating logic.
                if job.exclusiveProcessIdentifier != nil {
                    return false
                }
                // If a job has failed permanently or been marked obsolete, it's not
                // runnable. We don't currently distinguish `.ready` from `.running`
                // when restarting jobs.
                switch job.status {
                case .unknown, .permanentlyFailed, .obsolete:
                    return false
                case .ready, .running:
                    break
                }
                return true
            }()
            if canRunJob {
                updateRunnableJobRecord(job, tx)
                runnableJobs.append(job)
            } else {
                removeJob(job, tx: tx)
            }
        }
        return (runnableJobs, hasMore ? jobs.last!.id! : nil)
    }

    private func fetchSomeJobs(
        afterRowId: JobRecord.RowId?,
        tx: DBReadTransaction
    ) throws -> ([JobRecordType], hasMore: Bool) {
        var sql = """
            SELECT * FROM \(JobRecordType.databaseTableName)
            WHERE "\(JobRecordType.columnName(.label))" = ?
        """
        var arguments: StatementArguments = [JobRecordType.jobRecordType.jobRecordLabel]
        if let afterRowId {
            sql += """
                AND "\(JobRecordType.columnName(.id))" > ?
            """
            arguments += [afterRowId]
        }
        sql += """
            ORDER BY "\(JobRecordType.columnName(.id))"
            LIMIT \(Constants.batchSize)
        """
        do {
            let database = tx.database
            let results = try JobRecordType.fetchAll(database, sql: sql, arguments: arguments)
            return (results, results.count == Constants.batchSize)
        } catch {
            throw error.grdbErrorForLogging
        }
    }
}
