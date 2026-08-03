//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB

@objc
public class GRDBSchemaMigrator: NSObject {

    private static let _areMigrationsComplete = AtomicBool(false, lock: .sharedGlobal)
    @objc
    public static var areMigrationsComplete: Bool { _areMigrationsComplete.get() }
    public static let migrationSideEffectsCollectionName = "MigrationSideEffects"
    public static let avatarRepairAttemptCount = "Avatar Repair Attempt Count"

    // Returns true IFF incremental migrations were performed.
    @objc
    public func runSchemaMigrations() -> Bool {
        let didPerformIncrementalMigrations: Bool
        
        //MARK GRDB need to focus on
//        do {
//            Logger.info("Using newUserMigrator.")
//            try newUserMigrator.migrate(grdbStorageAdapter.pool)
//            didPerformIncrementalMigrations = false
//        } catch {
//            owsFail("New user migrator failed: \(error.grdbErrorForLogging)")
//        }
        
        if hasCreatedInitialSchema {
            do {
                Logger.info("Using incrementalMigrator.")
                didPerformIncrementalMigrations = try runIncrementalMigrations()
            } catch {
                owsFail("Incremental migrations failed: \(error.grdbErrorForLogging)")
            }
        } else {
            do {
                Logger.info("Using newUserMigrator.")
                try newUserMigrator.migrate(grdbStorageAdapter.pool)
                
                let incrementalMigrator = DatabaseMigratorWrapper()
                registerYDBDataMigrations(migrator: incrementalMigrator)
                try incrementalMigrator.migrate(grdbStorageAdapter.pool)
                
                didPerformIncrementalMigrations = false
            } catch {
                owsFail("New user migrator failed: \(error.grdbErrorForLogging)")
            }
        }
        
        
        Logger.info("Migrations complete.")

        SSKPreferences.markGRDBSchemaAsLatest()

        Self._areMigrationsComplete.set(true)

        return didPerformIncrementalMigrations
    }

    private func runIncrementalMigrations() throws -> Bool {
        let previouslyAppliedMigrations = try grdbStorageAdapter.read { transaction in
            try DatabaseMigrator().appliedIdentifiers(transaction.database)
        }

        let incrementalMigrator = DatabaseMigratorWrapper()
        // First do the schema migrations. (See the comment within MigrationId for why schema and data
        // migrations are separate.)
        registerSchemaMigrations(migrator: incrementalMigrator)
        try incrementalMigrator.migrate(grdbStorageAdapter.pool)
        
        
        registerYDBDataMigrations(migrator: incrementalMigrator)
        try incrementalMigrator.migrate(grdbStorageAdapter.pool)

        // Hack: Load the account state now, so it can be accessed while performing other migrations.
        // Otherwise one of them might indirectly try to load the account state using a sneaky transaction,
        // which won't work because migrations use a barrier block to prevent observing database state
        // before migration.
        //MARK GRDB need to focus on--
        try grdbStorageAdapter.read { transaction in
            _ = self.tsAccountManager.localNumber(with: transaction.asAnyRead)
        }

        // Finally, do data migrations.
        registerDataMigrations(migrator: incrementalMigrator)
        try incrementalMigrator.migrate(grdbStorageAdapter.pool)

        let allAppliedMigrations = try grdbStorageAdapter.read { transaction in
            try DatabaseMigrator().appliedIdentifiers(transaction.database)
        }

        return allAppliedMigrations != previouslyAppliedMigrations
    }

    private var hasCreatedInitialSchema: Bool {
        let appliedMigrations = try! grdbStorageAdapter.read { transaction in
            try! DatabaseMigrator().appliedIdentifiers(transaction.database)
        }
        Logger.info("appliedMigrations: \(appliedMigrations.sorted()).")
        return appliedMigrations.contains(MigrationId.createInitialSchema.rawValue)
    }

    // MARK: -

    private enum MigrationId: String, CaseIterable {
        case createInitialSchema
        case yapdatabaseData
        case addTranslateMessageColum  // model_TSInteraction
        case addTranslateSettingTypeColum  //model_TSThread
        case addTranslateArchivedMessageColum  //model_TSInteraction_archived
        case addVoiceColumsToAttachment
        case addResetIdentifyKeyRecord
        case addExpiresInSecondsAndMessageClearAnchor
        case addRemarkNameToSignalAccountSecondary
        case addGroupManagerCriticalAlert
        case addWidthHeightOnAttachment
        case addMentionCriticalMsgColum
        case addArchiveMessageIndex  // Add index for archive message query optimization
        case fixArchiveMessageIndex  // Fix the archive message index (remove WHERE clause with wrong type)
        case addMigrationOutgoingIndex  // Add index for TSMessageReadPositionMigrator query optimization
        case addGroupCryptoKeyRecord   // New table for group encryption root keys
        case addGroupCryptoFields      // Add groupCryptoMode/encryptedName/encryptedAvatar to DTGroupBaseInfoEntity
        case createSSKJobRecordV2       // Persistent JobRecord table with payload-based design
        case addGroupCryptoKeyVersion   // Add keyVersion column to model_DTGroupCryptoKeyRecord
        case addIncomingCallMessageFields   // Add callState/roomId to model_TSInteraction

        //MARK GRDB need to focus on

        // NOTE: Every time we add a migration id, consider
        // incrementing grdbSchemaVersionLatest.
        // We only need to do this for breaking changes.

        // MARK: Data Migrations
        //
        // Any migration which leverages SDSModel serialization must occur *after* changes to the
        // database schema complete.
        //
        // Otherwise, for example, consider we have these two pending migrations:
        //  - Migration 1: resaves all instances of Foo (Foo is some SDSModel)
        //  - Migration 2: adds a column "new_column" to the "model_Foo" table
        //
        // Migration 1 will fail, because the generated serialization logic for Foo expects
        // "new_column" to already exist before Migration 2 has even run.
        //
        // The solution is to always split logic that leverages SDSModel serialization into a
        // separate migration, and ensure it runs *after* any schema migrations. That is, new schema
        // migrations must be inserted *before* any of these Data Migrations.
        //
        // Note that account state is loaded *before* running data migrations, because many model objects expect
        // to be able to access that without a transaction.

        case dataMigration_readPosition
        case dataMigration_remark
        case dataMigration_cleanupRecallInfo
    }

    public static let grdbSchemaVersionDefault: UInt = 0

    /// Attention: matters
    ///model_TSMessageSecondary_virtual 虚表，集成自定义 FTS5 分词器 simple
    public static let grdbSchemaVersionLatest: UInt = 9

    // An optimization for new users, we have the first migration import the latest schema
    // and mark any other migrations as "already run".
    private lazy var newUserMigrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(MigrationId.createInitialSchema.rawValue) { db in
            Logger.info("importing latest schema")
            guard let sqlFile = Bundle(for: GRDBSchemaMigrator.self).url(forResource: "schema", withExtension: "sql") else {
                owsFail("sqlFile was unexpectedly nil")
            }
            let sql = try String(contentsOf: sqlFile)
            try db.execute(sql: sql)

            // After importing the initial schema, we want to skip the remaining
            // incremental migrations, so we manually mark them as complete.
            for migrationId in (MigrationId.allCases.filter { $0 != .createInitialSchema && $0 != .yapdatabaseData  }) {
                if !CurrentAppContext().isRunningTests {
                    Logger.info("skipping migration: \(migrationId) for new user.")
                }
                insertMigration(migrationId.rawValue, db: db)
            }
        }
        return migrator
    }()

    private class DatabaseMigratorWrapper {
        var migrator = DatabaseMigrator()

        func registerMigration(_ identifier: MigrationId, migrate: @escaping (Database) -> Void) {
            // Run with immediate foreign key checks so that pre-existing dangling rows
            // don't cause unrelated migrations to fail. We also don't perform schema
            // alterations that would necessitate disabling foreign key checks.
            migrator.registerMigration(identifier.rawValue, foreignKeyChecks: .immediate) { (database: Database) in
                let startTime = CACurrentMediaTime()
                Logger.info("Running migration: \(identifier)")
                migrate(database)
                let timeElapsed = CACurrentMediaTime() - startTime
                let formattedTime = String(format: "%0.2fms", timeElapsed * 1000)
                Logger.info("Migration completed: \(identifier), duration: \(formattedTime)")
            }
        }

        func migrate(_ database: DatabaseWriter) throws {
            try migrator.migrate(database)
        }
    }

    private func registerSchemaMigrations(migrator: DatabaseMigratorWrapper) {

        // The migration blocks should never throw. If we introduce a crashing
        // migration, we want the crash logs reflect where it occurred.

        //        migrator.registerMigration(.createInitialSchema) { _ in
        //            owsFail("This migration should have already been run by the last YapDB migration.")
        //        }
        
        // MARK: - Schema Migration Insertion Point
        migrator.registerMigration(.addTranslateMessageColum) { db in
            do {
                try db.alter(table: "model_TSInteraction") { (table: TableAlteration) -> Void in
                    table.add(column: "translateMessage", .blob)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addTranslateSettingTypeColum) { db in
            do {
                try db.alter(table: "model_TSThread") { (table: TableAlteration) -> Void in
                    table.add(column: "translateSettingType", .double).notNull().defaults(to: 0)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addTranslateArchivedMessageColum) { db in
            do {
                // 检查列是否已经存在
                let query = """
                PRAGMA table_info(model_TSInteraction_archived);
                """
                let rows = try Row.fetchAll(db, sql: query)

                let columnExists = rows.contains { row in
                    row["name"] as? String == "translateMessage"
                }

                // 如果列不存在，则添加
                if !columnExists {
                    try db.alter(table: "model_TSInteraction_archived") { (table: TableAlteration) in
                        table.add(column: "translateMessage", .blob)
                    }
                }
            } catch {
                Logger.error("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addVoiceColumsToAttachment) { db in
            do {
                try db.alter(table: "model_TSAttachment") { (table: TableAlteration) -> Void in
                    table.add(column: "decibelSamples", .blob)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addResetIdentifyKeyRecord) { db in
            do {
                try db.create(table: "model_ResetIdentifyKeyRecord") { table in
                    table.autoIncrementedPrimaryKey("id")
                        .notNull()
                    table.column("recordType", .integer)
                        .notNull()
                    table.column("uniqueId", .text)
                        .notNull()
                        .unique(onConflict: .fail)
                    
                    table.column("operatorId", .text)
                        .notNull()
                    table.column("resetIdentifyKeyTime", .integer)
                        .notNull()
                    table.column("isCompleted", .boolean)
                        .notNull()
                    table.column("createdAt", .double)
                        .notNull()
                }
                try db.create(index: "index_model_ResetIdentifyKeyRecord_on_uniqueId",
                              on: "model_ResetIdentifyKeyRecord",
                              columns: ["uniqueId"])
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addExpiresInSecondsAndMessageClearAnchor) { db in
            do {
                try db.alter(table: "model_TSThread") { (table: TableAlteration) -> Void in
                    table.add(column: "expiresInSeconds", .integer).defaults(to: 0)
                    table.add(column: "messageClearAnchor", .integer).defaults(to: 0)
                }
                
                try db.alter(table: "model_DTGroupBaseInfoEntity") { (table: TableAlteration) -> Void in
                    table.add(column: "messageClearAnchor", .integer).defaults(to: 0)
                }
                
                try db.create(index: "index_model_TSThread_on_messageClearAnchor",
                              on: "model_TSThread",
                              columns: ["uniqueId", "messageClearAnchor"])
                
                try db.create(index: "index_model_TSMessageReadPosition_on_readAt",
                              on: "model_TSMessageReadPosition",
                              columns: ["uniqueThreadId", "recipientId", "readAt", "maxServerTime"])
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addRemarkNameToSignalAccountSecondary) { db in
            do {
                try db.alter(table: "model_SignalAccountSecondary") { (table: TableAlteration) -> Void in
                    table.add(column: "remarkName", .text).defaults(to: "")
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addGroupManagerCriticalAlert) { db in
            do {
                try db.alter(table: "model_DTGroupBaseInfoEntity") { (table: TableAlteration) -> Void in
                    table.add(column: "criticalAlert", .boolean).defaults(to: false)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addWidthHeightOnAttachment) { db in
            do {
                try db.alter(table: "model_TSAttachment") { (table: TableAlteration) -> Void in
                    table.add(column: "height", .integer).notNull().defaults(to: 0)
                    table.add(column: "width", .integer).notNull().defaults(to: 0)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }
        
        migrator.registerMigration(.addMentionCriticalMsgColum) { db in
            do {
                try db.alter(table: "model_TSThread") { (table: TableAlteration) -> Void in
                    table.add(column: "mentionedCriticalMsg", .blob)
                }
            } catch {
                owsFail("Error: \(error)")
            }
        }

        migrator.registerMigration(.addArchiveMessageIndex) { db in
            do {
                // Create index for efficient archive message query (without WHERE clause - will be fixed in next migration)
                try db.create(index: "idx_interaction_archive_message",
                              on: "model_TSInteraction",
                              columns: ["uniqueThreadId", "recordType", "messageType"],
                              options: .ifNotExists,
                              condition: Column("recordType") == 27)
                Logger.info("Created index for archive message query optimization")
            } catch {
                owsFail("Error creating archive message index: \(error)")
            }
        }

        migrator.registerMigration(.fixArchiveMessageIndex) { db in
            do {
                Logger.info("Fixing archive message index - dropping old index if exists")
                try db.execute(sql: """
                    DROP INDEX IF EXISTS idx_interaction_archive_message
                """)

                Logger.info("Fixing archive message index - creating corrected index with WHERE clause")
                try db.create(index: "index_interaction_archive_message",
                              on: "model_TSInteraction",
                              columns: ["uniqueThreadId", "recordType", "messageType"],
                              options: .ifNotExists,
                              condition: Column("recordType") == 27)
                Logger.info("Successfully fixed archive message index")
            } catch {
                owsFail("Error fixing archive message index: \(error)")
            }
        }

        migrator.registerMigration(.addMigrationOutgoingIndex) { db in
            do {
                Logger.info("Creating index for TSMessageReadPositionMigrator query optimization")
                try db.create(index: "index_interaction_migration_outgoing",
                              on: "model_TSInteraction",
                              columns: ["recordType", "timestamp", "uniqueThreadId"],
                              options: .ifNotExists,
                              condition: Column("recordType") == 14)
                Logger.info("Successfully created migration outgoing index")
            } catch {
                owsFail("Error creating migration outgoing index: \(error)")
            }
        }

        migrator.registerMigration(.addGroupCryptoKeyRecord) { db in
            do {
                try db.create(table: "model_DTGroupCryptoKeyRecord") { table in
                    table.autoIncrementedPrimaryKey("id").notNull()
                    table.column("recordType", .integer).notNull()
                    table.column("uniqueId", .text).notNull().unique(onConflict: .fail)
                    table.column("gid", .text).notNull()
                    table.column("rGroup", .text).notNull()
                }
                try db.create(index: "index_model_DTGroupCryptoKeyRecord_on_uniqueId",
                              on: "model_DTGroupCryptoKeyRecord",
                              columns: ["uniqueId"])
            } catch {
                owsFail("Error creating group_crypto_keys table: \(error)")
            }
        }

        migrator.registerMigration(.addGroupCryptoFields) { db in
            do {
                try db.alter(table: "model_DTGroupBaseInfoEntity") { (table: TableAlteration) -> Void in
                    table.add(column: "groupCryptoMode", .integer).notNull().defaults(to: 0)
                    table.add(column: "encryptedName", .text)
                    table.add(column: "encryptedAvatar", .text)
                }
            } catch {
                owsFail("Error adding group crypto fields: \(error)")
            }
        }

        // MARK: Job framework
        //
        // Persistent backing store for the V2 ``JobRecord`` family. Multiple ``JobRecord``
        // Persistent JobRecord table for the V2 job queue framework.
        migrator.registerMigration(.createSSKJobRecordV2) { db in
            do {
                try db.create(table: "model_SSKJobRecord") { table in
                    table.autoIncrementedPrimaryKey("id").notNull()
                    table.column("recordType", .integer).notNull()
                    table.column("uniqueId", .text).notNull().unique(onConflict: .fail)
                    table.column("failureCount", .integer).notNull()
                    table.column("label", .text).notNull()
                    table.column("status", .integer).notNull()
                    table.column("attachmentIdMap", .blob)
                    table.column("contactThreadId", .text)
                    table.column("envelopeData", .blob)
                    table.column("invisibleMessage", .blob)
                    table.column("messageId", .text)
                    table.column("removeMessageAfterSending", .integer)
                    table.column("threadId", .text)
                    table.column("exclusiveProcessIdentifier", .text)
                    table.column("isHighPriority", .integer).notNull().defaults(to: false)
                    table.column("isMediaMessage", .integer).notNull().defaults(to: false)
                }
                try db.create(
                    index: "index_model_SSKJobRecord_on_label_and_status",
                    on: "model_SSKJobRecord",
                    columns: ["label", "status"]
                )
                try db.create(
                    index: "index_model_SSKJobRecord_on_exclusiveProcessIdentifier",
                    on: "model_SSKJobRecord",
                    columns: ["exclusiveProcessIdentifier"]
                )
            } catch {
                owsFail("Error creating SSKJobRecord table: \(error)")
            }
        }

        migrator.registerMigration(.addGroupCryptoKeyVersion) { db in
            do {
                try db.alter(table: "model_DTGroupCryptoKeyRecord") { (table: TableAlteration) -> Void in
                    table.add(column: "keyVersion", .integer).notNull().defaults(to: 0)
                }
            } catch {
                owsFail("Error adding group crypto keyVersion column: \(error)")
            }
        }

        // Incoming call message (recordType 64) compatibility fields.
        // Nullable additive columns with defaults so backfilled existing rows
        // read a stable value instead of NULL.
        migrator.registerMigration(.addIncomingCallMessageFields) { db in
            do {
                try db.alter(table: "model_TSInteraction") { (table: TableAlteration) -> Void in
                    table.add(column: "callState", .integer).defaults(to: 0)
                    table.add(column: "roomId", .text).defaults(to: "")
                }
            } catch {
                owsFail("Error adding incoming call message fields: \(error)")
            }
        }
    }
    
    


    private func registerDataMigrations(migrator: DatabaseMigratorWrapper) {
        // The migration blocks should never throw. If we introduce a crashing
        // migration, we want the crash logs reflect where it occurred.

        migrator.registerMigration(.dataMigration_readPosition) { transaction in
            let wTransaction = GRDBWriteTransaction(database: transaction)
            guard let localNumber = TSAccountManager.shared.localNumber(with: wTransaction.asAnyRead) else {
                OWSLogger.info("dataMigration_readPosition localNumber is empty!")
                return
            }
            let interactionFinder = InteractionFinder(threadUniqueId: TSContactThread.threadId(fromContactId: localNumber))
            do {
                try interactionFinder.enumerateRecentWithoutNoteOutgoingMessages(transaction: wTransaction.asAnyRead) { interaction, stop in
                    guard let outgoingMessage = interaction as? TSOutgoingMessage,
                            let recipientStateMap = outgoingMessage.recipientStateMap else {
                        return
                    }
                    for (number, state) in recipientStateMap {
                        guard let readTimestamp = state.readTimestamp, Int(truncating: readTimestamp) > 0 else {
                            break
                        }
                        var groupId: Data? = nil
                        let threadId = outgoingMessage.uniqueThreadId
                        if threadId.hasPrefix("g") {
                            groupId = TSGroupThread.groupId(fromThreadId: threadId)
                        }
                        let readPosition = DTReadPositionEntity(groupId: groupId, readAt: UInt64(truncating: readTimestamp), maxServerTime: outgoingMessage.serverTimestamp, notifySequenceId: outgoingMessage.notifySequenceId, maxSequenceId: outgoingMessage.sequenceId)
                        let messageReadPosition = TSMessageReadPosition(uniqueThreadId: outgoingMessage.uniqueThreadId,
                                                                        recipientId: number,
                                                                        readPosition: readPosition)
                        messageReadPosition.updateOrInsert(with: wTransaction.asAnyWrite)
                    }
                }
            } catch {
                OWSLogger.error("dataMigration_readPosition error: \(error)")
            }
        }
        
        migrator.registerMigration(.dataMigration_remark) { database in
            
            let wTransaction = GRDBWriteTransaction(database: database)
            defer { wTransaction.finalizeTransaction() }
            
            let updateSQL = """
                UPDATE model_SignalAccountSecondary 
                SET remarkName = ? 
                WHERE uniqueId = ?
            """
            
            SignalAccount.anyEnumerate(transaction: wTransaction.asAnyRead) { account, stop in
                // Only process accounts that have a non-empty remarkName
                guard let remarkName = account.remarkName, !remarkName.isEmpty else {
                    return
                }
                
                // Execute the update
                do {
                    try database.execute(sql: updateSQL, arguments: [remarkName.lowercased(), account.uniqueId])
                } catch {
                    Logger.warn("Failed to update remarkName for account \(account.uniqueId): \(error)")
                }
            }
            
            Logger.info("dataMigration_remark completed successfully")
        }

        migrator.registerMigration(.dataMigration_cleanupRecallInfo) { database in
            let wTransaction = GRDBWriteTransaction(database: database)
            defer { wTransaction.finalizeTransaction() }

            let deletedCount = GRDBInteractionFinderAdapter.deleteAllRecallInfoMessages(transaction: wTransaction)
            Logger.info("dataMigration_cleanupRecallInfo completed successfully, deleted \(deletedCount) recall info messages")
        }
    }
    
    private func registerYDBDataMigrations(migrator: DatabaseMigratorWrapper) {
        // The migration blocks should never throw. If we introduce a crashing
        // migration, we want the crash logs reflect where it occurred.

        //MARK GRDB need to focus on
        
        migrator.registerMigration(.yapdatabaseData) { db in
            
            //delete old debug db files----
            let dbBaseUrl = SDSDatabaseStorage.baseDir
            let containerPathItems: [String]
            do {
                containerPathItems = try FileManager.default.contentsOfDirectory(atPath: dbBaseUrl.path)
            } catch {
                owsFailDebug("Failed to fetch other directory items: \(error)")
                containerPathItems = []
            }
            
            let currentFolderName = GRDBDatabaseStorageAdapter.DirectoryMode.primary.folderName
            
            let targetPathItems = containerPathItems.filter { ($0.hasPrefix("grdb-") && $0 != currentFolderName ) }.map { dbBaseUrl.appendingPathComponent($0) }
            
            for folderPath in targetPathItems {
                do {
                    try FileManager.default.removeItem(atPath: folderPath.path)
                    Logger.info("remove debug db item!")
                } catch {
                    owsFailDebug("Failed to remove item: \(error)")
                }
            }
            //-----
            
            guard YDBDataMigrator.ensureYapDatabaseExists() else {
                Logger.info("Migrator YDB not exists or Key not accessible!")
                return
            }
            
            do {
                let transaction = GRDBWriteTransaction(database: db)
                defer { transaction.finalizeTransaction() }

                let ydbMigrator = YDBDataMigrator.shared
                
                var localNumber: String = ""
                try ydbMigrator.tSStorageRegisteredNumberKey { number in
                    localNumber = number
                    TSAccountManager.shared.storeLocalNumber(number, transaction: transaction.asAnyWrite)
                }
                
                guard (localNumber.count != 0) else {
                    Logger.info("YDBDataMigrator localNumber is nil!")
                    return
                }
                
                
                var authToken: String = ""
                try ydbMigrator.tSStorageServerAuthToken(block: { token in
                    authToken = token
                })
                
                guard (authToken.count != 0) else {
                    Logger.info("YDBDataMigrator authToken is nil!")
                    return
                }
                
                var signalingKey: String = ""
                try ydbMigrator.tSStorageServerSignalingKey(block: { key in
                    signalingKey = key
                })
                
                guard (signalingKey.count != 0) else {
                    Logger.info("YDBDataMigrator signalingKey is nil!")
                    return
                }
                
                TSAccountManager.shared.storeServerAuthToken(authToken, signalingKey:signalingKey, transaction:transaction.asAnyWrite)
                
                
                var registrationId: UInt32 = 0
                try ydbMigrator.tSStorageLocalRegistrationId(block: { registerId in
                    registrationId = registerId
                })
                
                guard (registrationId > 0) else {
                    Logger.info("YDBDataMigrator registrationId is nil!")
                    return
                }
                
                TSAccountManager.shared.setRegistrationId(registrationId, transaction: transaction.asAnyWrite)
                
                var identityKey: ECKeyPair?
                try ydbMigrator.tSStorageManagerIdentityKeyStoreIdentityKey(block: { idKey in
                    identityKey = idKey
                })
                
                guard let identityKey = identityKey else {
                    Logger.info("YDBDataMigrator identityKey is nil!")
                    return
                }
                
                OWSIdentityManager.shared().migratorIdentityKey(identityKey, transaction: transaction.asAnyWrite)
                
                
                var threadCount: UInt = 0
                
                try ydbMigrator.threads(block: { thread in
                    guard !thread.isRemovedFromConversation else {
                        return
                    }
                    if (thread.lastestMsg != nil) {
                        thread.lastestMsg?.updateRowId(100)
                    }
                    if thread.hasEverHadMessage || thread.isSticked {
                        thread.shouldBeVisible = true
                    }
                    thread.anyInsert(transaction: transaction.asAnyWrite)
                    threadCount += 1
                })
                

                Logger.info("YDBDataMigrator \(threadCount) threads.")
                
                var attachments: [String] = []
                var messageCount: UInt = 0
                try ydbMigrator.enumerateAllMessges(block: { message in
                    if(message.serverTimestamp == 0) {
                        message.serverTimestamp = message.timestamp
                    }
                    message.anyInsert(transaction: transaction.asAnyWrite)
                    messageCount += 1
                    if let attachmentId = message.attachmentIds.first {
                        attachments.append(attachmentId)
                    }
                    if let combinedForwardingMessage = message.combinedForwardingMessage {
                        let attachmentIds = combinedForwardingMessage.allForwardingAttachmentIds()
                        attachments.append(contentsOf: attachmentIds)
                    }
                    
                });
                Logger.info("YDBDataMigrator \(messageCount) messages.")
                
                var attachmentCount: UInt = 0
                for attachmentId in attachments {
                    try ydbMigrator.attachment(attachmentId: attachmentId,
                                               block: { attachment in
                        attachment.anyInsert(transaction: transaction.asAnyWrite)
                        attachmentCount += 1
                    })
                }
                Logger.info("YDBDataMigrator \(attachmentCount) attachments.")
                
                ydbMigrator.yapdatabaseRegister = true
                
//                try ydbMigrator.close()
//                
//                Logger.info("YDBDataMigrator close")
                                
            } catch {
                owsFailDebug("YDBDataMigrator Error: \(error)")
            }
        }

    }
}

private func hasRunMigration(_ identifier: String, transaction: GRDBReadTransaction) -> Bool {
    do {
        return try String.fetchOne(transaction.database, sql: "SELECT identifier FROM grdb_migrations WHERE identifier = ?", arguments: [identifier]) != nil
    } catch {
        owsFail("Error: \(error)")
    }
}

private func insertMigration(_ identifier: String, db: Database) {
    do {
        try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
    } catch {
        owsFail("Error: \(error)")
    }
}
