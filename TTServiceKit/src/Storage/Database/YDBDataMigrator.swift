//
//  YDBDataMigrator.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/11.
//

import Foundation
import GRDB

@objc
public class YDBDataMigrator: NSObject {
    public static let databaseUrl: URL = SDSDatabaseStorage.baseDir.appendingPathComponent("database", isDirectory: true)
    public static let databaseFileUrl: URL = databaseUrl.appendingPathComponent("difft.sqlite", isDirectory: false)
    
    @objc
    public static let shared = YDBDataMigrator()
    
    private var dbQueue: DatabaseQueue?
    
    @objc
    public var yapdatabaseRegister: Bool = false
    
    override init() {
        
        guard Self.ensureYapDatabaseExists() else {
            super.init()
            return
        }
        
        var config = Configuration()
        config.readonly = true
        config.foreignKeysEnabled = true // Default is already true
        config.label = "MyDatabase"      // Useful when your app opens multiple databases
        config.maximumReaderCount = 10   // (DatabasePool only) The default is 5
        
        config.prepareDatabase { db in
            try Self.prepareDatabase(db: db, keyspec: Self.keyspec)

            db.trace { Self.dbQueryLog("\($0)") }
        }
        
        do {
            dbQueue = try Self.buildQueue(dbURL: Self.databaseFileUrl, poolConfiguration: config)
        } catch {
            owsFailDebug("buildQueue error:\(error)")
        }
        

        super.init()
    }
    
    private static let keyServiceName: String = "TSKeyChainService"
    private static let keyName: String = "OWSDatabaseCipherKeySpec"
    public static var keyspec: YDBKeySpecSource {
        return YDBKeySpecSource(keyServiceName: keyServiceName, keyName: keyName)
    }
    
    
    static func prepareDatabase(db: Database, keyspec: YDBKeySpecSource, name: String? = nil) throws {
        let prefix: String
        if let name = name, !name.isEmpty {
            prefix = name + "."
        } else {
            prefix = ""
        }
        
        let keyspec = try keyspec.fetchString()

        try db.execute(sql: "PRAGMA \(prefix)key = \"\(keyspec)\"")
        try db.execute(sql: "PRAGMA \(prefix)cipher_plaintext_header_size = 32")
        if !CurrentAppContext().isMainApp {
            let perConnectionCacheSizeInKibibytes = 2000 / 5
            // Limit the per-connection cache size based on the number of possible readers.
            // (The default is 2000KiB per connection regardless of how many other connections there are).
            // The minus sign indicates that this is in KiB rather than the database's page size.
            // An alternative would be to use SQLite's "shared cache" mode to have a single memory pool,
            // but unfortunately that changes the locking model in a way GRDB doesn't support.
            try db.execute(sql: "PRAGMA \(prefix)cache_size = -\(perConnectionCacheSizeInKibibytes)")
        }
    }
    
    @objc
    public static func ensureYapDatabaseExists() -> Bool {

        let databaseUrl = YDBDataMigrator.databaseFileUrl
        let doesDBExist = FileManager.default.fileExists(atPath: databaseUrl.path)
        if !doesDBExist {
            return false
        }
        
        do {
            _ = try keyspec.fetchString()
            // Key exists and is valid.
            return true
        } catch {
            Logger.warn("Key not accessible: \(error)")
        }
        
        return false
    }
    
    private static func dbQueryLog(_ value: String) {
        guard DebugFlags.logSQLQueries else {
            return
        }
        Logger.info(filterForDBQueryLog(value))
    }
    
    private static func buildQueue(dbURL: URL, poolConfiguration: Configuration) throws -> DatabaseQueue {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var newQueue: DatabaseQueue?
        var dbError: Error?
        coordinator.coordinate(writingItemAt: dbURL,
                               options: .forMerging,
                               error: &coordinatorError,
                               byAccessor: { url in
            do {
                newQueue = try DatabaseQueue(path: url.path, configuration: poolConfiguration)
            } catch {
                dbError = error
            }
        })
        if let error = dbError ?? coordinatorError {
            throw error
        }
        guard let queue = newQueue else {
            throw OWSAssertionError("Missing queue.")
        }
        return queue
    }
    
    public func tSStorageLocalRegistrationId(block: @escaping (UInt32) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageUserAccountCollection", "TSStorageLocalRegistrationId"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSNumber.self, from: serializedData)
                    if let number = object {
                        block(UInt32(number.intValue))
                    }
                }
            }
        }
        
    }
    
    public func tSAccountManager_ReregisteringPhoneNumberKey(block: @escaping (String) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageUserAccountCollection", "TSAccountManager_ReregisteringPhoneNumberKey"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: serializedData)
                    if let string = object as? String {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    
    public func tSAccountManager_IsDeregisteredKey(block: @escaping (String) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageUserAccountCollection", "TSAccountManager_IsDeregisteredKey"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: serializedData)
                    if let string = object as? String {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    
    public func tSStorageRegisteredNumberKey(block: @escaping (String) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments: ["TSStorageUserAccountCollection", "TSStorageRegisteredNumberKey"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: serializedData)
                    if let string = object as? String {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    public func tSStorageServerAuthToken(block: @escaping (String) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageUserAccountCollection", "TSStorageServerAuthToken"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: serializedData)
                    if let string = object as? String {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    public func tSStorageServerSignalingKey(block: @escaping (String) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageUserAccountCollection", "TSStorageServerSignalingKey"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: serializedData)
                    if let string = object as? String {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    public func tSStorageManagerIdentityKeyStoreIdentityKey(block: @escaping (ECKeyPair) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSStorageManagerIdentityKeyStoreCollection", "TSStorageManagerIdentityKeyStoreIdentityKey"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: ECKeyPair.self, from: serializedData)
                    if let string = object {
                        block(string)
                    }
                }
            }
        }
        
    }
    
    public func enumerateNoteMessges(block: @escaping (TSMessage) -> Void) throws {
        
        guard let localNumber = TSAccountManager.localNumber() else {
            return
        }
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE rowid IN
            (SELECT rowid FROM view_TSMessageDatabaseViewExtensionName_map WHERE pageKey IN
            (SELECT pageKey
            FROM view_TSMessageDatabaseViewExtensionName_page
            WHERE \"group\" = ?)
            ORDER BY rowid)
            """
        
        let group = "c" + localNumber
        let arguments: StatementArguments = [group]
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments: arguments).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = YDBDataMigratorUtils.unarchivedObject(serializedData)
                    if let message = object as? TSMessage {
                        block(message)
                    }
                }
            }
        }

        
    }
    
    public func enumerateAllMessges(block: @escaping (TSMessage) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE rowid IN
            (SELECT rowid FROM view_TSMessageDatabaseViewExtensionName_map WHERE pageKey IN
            (SELECT pageKey
            FROM view_TSMessageDatabaseViewExtensionName_page)
            ORDER BY rowid)
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments: []).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = YDBDataMigratorUtils.unarchivedObject(serializedData)
                    if let message = object as? TSMessage {
                        block(message)
                    }
                }
            }
        }

        
    }
    
    public func attachment(attachmentId: String, block: @escaping (TSAttachment) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE collection = ? AND key = ? LIMIT 1
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSAttachements", attachmentId]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = YDBDataMigratorUtils.unarchivedObject(serializedData)
                    if let attachment = object as? TSAttachment {
                        block(attachment)
                    }
                }
            }
        }
        
    }
    
    public func threads(block: @escaping (TSThread) -> Void) throws {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        let sql = """
            SELECT data FROM database2 WHERE rowid IN
            (SELECT rowid FROM view_TSThreadDatabaseViewExtensionName2_map WHERE pageKey IN
            (SELECT pageKey
            FROM view_TSThreadDatabaseViewExtensionName2_page
            WHERE \"group\" = ?)
            ORDER BY rowid)
            """
        
        try dbQueue.read { db in
            try Data.fetchCursor(db, sql: sql, arguments:["TSInboxGroup"]).forEach { serializedData in
                if (serializedData.count != 0) {
                    let object = YDBDataMigratorUtils.unarchivedObject(serializedData)
                    if let thread = object as? TSThread {
                        block(thread)
                    }
                }
            }
        }
        
    }
    
    public func close() throws -> Void {
        
        guard let dbQueue = self.dbQueue else {
            return
        }
        
        try dbQueue.close()
        
    }
    

}


public struct YDBKeySpecSource {

    private var kSQLCipherKeySpecLength: UInt {
        48
    }

    let keyServiceName: String
    let keyName: String

    func fetchString() throws -> String {
        // Use a raw key spec, where the 96 hexadecimal digits are provided
        // (i.e. 64 hex for the 256 bit key, followed by 32 hex for the 128 bit salt)
        // using explicit BLOB syntax, e.g.:
        //
        // x'98483C6EB40B6C31A448C22A66DED3B5E5E8D5119CAC8327B655C8B5C483648101010101010101010101010101010101'
        let data = try fetchData()

        guard data.count == kSQLCipherKeySpecLength else {
            owsFail("unexpected keyspec length")
        }

        let passphrase = "x'\(data.hexadecimalString)'"
        return passphrase
    }

    public func fetchData() throws -> Data {
        return try CurrentAppContext().keychainStorage().data(forService: keyServiceName, key: keyName)
    }

    func clear() throws {
        try CurrentAppContext().keychainStorage().remove(service: keyServiceName, key: keyName)
    }

    func generateAndStore() {
        Logger.info("")

        do {
            let keyData = Randomness.generateRandomBytes(Int32(kSQLCipherKeySpecLength))
            try store(data: keyData)
        } catch {
            owsFail("Could not generate key for GRDB: \(error)")
        }
    }

    public func store(data: Data) throws {
        guard data.count == kSQLCipherKeySpecLength else {
            owsFail("unexpected keyspec length")
        }
        try CurrentAppContext().keychainStorage().set(data: data, service: keyServiceName, key: keyName)
    }
}
