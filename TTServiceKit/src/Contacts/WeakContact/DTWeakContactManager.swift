//
//  DTWeakContactManager.swift
//  TTServiceKit
//
//  Local mirror of the server's pending-removal ("weak contact") set; the single
//  entry point for weak-contact side effects. Server is the source of truth.
//

import Foundation

/// Three-state relation, from two mutually-exclusive sources: friend store + weak cache.
@objc
public enum DTContactRelationState: Int {
    /// Not a friend and not in the weak cache (incl. already removed — removal leaves no trace).
    case stranger = 0
    /// In the friend store.
    case friend = 1
    /// In the pending-removal cache: shown with a countdown, conversation deleted.
    case pendingRemoval = 2
}

@objc
public class DTWeakContactManager: NSObject {

    @objc
    public static let shared = DTWeakContactManager()

    /// Posted on main after any weak-cache mutation so the contacts list refreshes.
    @objc
    public static let weakContactsDidChangeNotificationName = "DTWeakContactsDidChangeNotification"
    public static let weakContactsDidChangeNotification = Notification.Name(weakContactsDidChangeNotificationName)

    private let store = SDSKeyValueStore(collection: "DTWeakContactStore")

    private let lock = NSLock()
    private var cachedRecords: [String: DTWeakContactRecord]?
    /// Bumped on every invalidation so a disk load that raced an invalidation discards its snapshot.
    private var cacheGeneration: UInt64 = 0

    private override init() {
        super.init()
    }

    // MARK: - In-memory cache

    /// Lazily loads the cache from disk on first use. UI queries hit memory only.
    /// The disk read runs WITHOUT holding `lock` (no lock-across-IO, so it can never deadlock
    /// against a writer that takes `lock`); a `cacheGeneration` guard discards the snapshot if an
    /// invalidation raced the load, so stale data is never cached.
    private func records() -> [String: DTWeakContactRecord] {
        lock.lock()
        if let cachedRecords {
            lock.unlock()
            return cachedRecords
        }
        let generationAtLoad = cacheGeneration
        lock.unlock()

        var loaded = [String: DTWeakContactRecord]()
        databaseStorage.read { transaction in
            for data in self.store.allDataValues(transaction: transaction) {
                if let record = try? JSONDecoder().decode(DTWeakContactRecord.self, from: data) {
                    loaded[record.uid] = record
                }
            }
        }

        lock.lock()
        defer { lock.unlock() }
        // Adopt the snapshot only if no invalidation raced the load and no other thread won first.
        if cachedRecords == nil, cacheGeneration == generationAtLoad {
            cachedRecords = loaded
        }
        return cachedRecords ?? loaded
    }

    /// Drop the in-memory cache; next query reloads from disk (used after writes inside a tx).
    private func invalidateCache() {
        lock.lock()
        cachedRecords = nil
        cacheGeneration &+= 1
        lock.unlock()
    }

    // MARK: - UI queries (memory-only, safe to call on main thread)

    @objc
    public func isWeakContact(recipientId: String) -> Bool {
        return records()[recipientId] != nil
    }

    /// Transaction-scoped weak check for callers already inside a write tx (no nested read).
    @objc
    public func isWeakContact(recipientId: String, transaction: SDSAnyReadTransaction) -> Bool {
        return store.hasValue(forKey: recipientId, transaction: transaction)
    }

    /// Days left until removal, or 0 when the contact is not in the weak set.
    @objc
    public func daysLeft(recipientId: String) -> Int {
        return records()[recipientId]?.daysLeft ?? 0
    }

    /// True within the final day before removal; false when the contact is not in the weak set.
    /// Drives the "Removed today" list hint, which must not collide with `daysLeft == 0` (non-weak).
    @objc
    public func isRemovingToday(recipientId: String) -> Bool {
        return records()[recipientId]?.isRemovingToday ?? false
    }

    /// Time (ms) the contact entered the weak set, for a stable list tiebreak when days-left ties;
    /// 0 when not weak. Falls back to `expireAt` (server-stable and monotonic with enter time) when
    /// the server sent no unfriend time — never `serverNowAtRecord`, which reconcile re-anchors on
    /// every fetch and would collapse the tiebreak to name order after the first reconcile.
    @objc
    public func weakEnterTime(recipientId: String) -> Int64 {
        guard let record = records()[recipientId] else { return 0 }
        return record.deleteTime ?? record.expireAt
    }

    @objc
    public func weakContactRecipientIds() -> [String] {
        return Array(records().keys)
    }

    /// Display-only account built from the server snapshot, so the contacts list can render a
    /// pending-removal contact independently of the friend store (which contacts sync rebuilds
    /// and may drop/clobber the demoted account). Returns nil when the uid is not weak.
    @objc
    public func displayAccount(forWeakUid uid: String) -> SignalAccount? {
        guard let record = records()[uid] else { return nil }
        let account = SignalAccount(recipientId: uid)
        let contact: Contact
        if let name = record.name, !name.isEmpty {
            contact = Contact(fullName: name, phoneNumber: uid)
        } else {
            contact = Contact(recipientId: uid)
        }
        if let avatar = record.avatar, let avatarDict = Self.avatarDict(from: avatar) {
            contact.avatar = avatarDict
        }
        contact.isExternal = true
        // Overlay the locally-stored remark onto the server snapshot: the snapshot is the
        // original identity, remark is the user's per-contact override. Without this the edit
        // page can't prefill and the card's "original name" row never renders for weak contacts.
        if let persisted = TextSecureKitEnv.shared().contactsManager.signalAccount(forRecipientId: uid)?.contact {
            contact.remark = persisted.remark
            contact.remarkAvatar = persisted.remarkAvatar
        }
        account.contact = contact
        return account
    }

    /// Single source of truth for the three-state relation of a contact.
    /// Weak cache wins: the friend store can transiently keep a stale non-external flag
    /// after a contacts sync, so the server-driven weak set is authoritative here.
    @objc
    public func relationState(for account: SignalAccount) -> DTContactRelationState {
        if isWeakContact(recipientId: account.recipientId) { return .pendingRemoval }
        if account.isFriend { return .friend }
        return .stranger
    }

    /// Convenience by recipientId (reads the in-memory SignalAccount cache). Main-thread safe.
    @objc
    public func relationState(recipientId: String) -> DTContactRelationState {
        if isWeakContact(recipientId: recipientId) { return .pendingRemoval }
        let account = TextSecureKitEnv.shared().contactsManager.signalAccount(forRecipientId: recipientId)
        if account?.isFriend == true { return .friend }
        return .stranger
    }

    // MARK: - Notify entry (DTServerNotifyMessageHandler, notifyType 25)
    // Handler parses the Mantle entity (ObjC) and passes fields here, keeping it off the Swift umbrella.

    /// Flow ①: enter weak state from a notify (changeType=0).
    @objc
    public func enterWeakState(uid: String,
                               reason: Int,
                               name: String?,
                               avatar: String?,
                               expireTime: UInt64,
                               deleteTime: UInt64,
                               serverTimestamp: UInt64,
                               transaction: SDSAnyWriteTransaction) {
        let serverNow = serverTimestamp != 0
            ? Int64(serverTimestamp)
            : Int64(NSDate.ows_millisecondTimeStamp())
        let record = DTWeakContactRecord(
            uid: uid,
            reason: reason,
            name: name,
            avatar: avatar,
            deleteTime: deleteTime != 0 ? Int64(deleteTime) : nil,
            expireAt: Int64(expireTime),
            serverNowAtRecord: serverNow,
            uptimeAtRecord: ProcessInfo.processInfo.systemUptime
        )
        enterWeakState(record: record, transaction: transaction)
    }

    // MARK: - State transitions (run inside a write transaction)

    /// Flow ①: persist placeholder + delete local conversation + demote from friend store.
    func enterWeakState(record: DTWeakContactRecord, transaction: SDSAnyWriteTransaction) {
        enterWeakStateCore(record: record, transaction: transaction)
        notifyChange(after: transaction)
    }

    /// Flow ③: removed (expired/immediate) — second-delete conversation + drop placeholder.
    @objc
    public func removeFromWeakState(uid: String, transaction: SDSAnyWriteTransaction) {
        guard removeFromWeakStateCore(uid: uid, transaction: transaction) else { return }
        notifyChange(after: transaction)
    }

    /// Flow ⑤ (weak → friend): drop the placeholder only; friend recovery is done by the add-friend flow.
    @objc
    public func clearWeakPlaceholder(uid: String, transaction: SDSAnyWriteTransaction) {
        guard clearWeakPlaceholderCore(uid: uid, transaction: transaction) else { return }
        notifyChange(after: transaction)
    }

    // Core variants skip the notify; reconcile applies many in one tx then notifies once.

    private func enterWeakStateCore(record: DTWeakContactRecord, transaction: SDSAnyWriteTransaction) {
        Logger.info("[WeakContact] enter weak state hasAvatar=\(record.avatar?.isEmpty == false)")
        persist(record: record, transaction: transaction)
        deleteLocalConversation(uid: record.uid, transaction: transaction)
        demoteToExternal(uid: record.uid, name: record.name, avatar: record.avatar, transaction: transaction)
    }

    /// True if the contact was weak and got removed. Gate: never destroy data for a uid that
    /// is not pending-removal, so a stray/out-of-order notify25 changeType=1 for a normal friend
    /// can't wipe their conversation. Gates via the passed tx (no nested read).
    @discardableResult
    private func removeFromWeakStateCore(uid: String, transaction: SDSAnyWriteTransaction) -> Bool {
        guard store.hasValue(forKey: uid, transaction: transaction) else { return false }
        Logger.info("[WeakContact] remove weak state")
        deleteLocalConversation(uid: uid, transaction: transaction)
        removeRecord(uid: uid, transaction: transaction)
        // Purge the residual demoted account: the contact is now neither friend nor weak, so it
        // must leave the contacts list at once instead of lingering until a manual refresh.
        TextSecureKitEnv.shared().contactsManager.removeAccount(withRecipientId: uid, transaction: transaction)
        return true
    }

    /// True if a placeholder existed and was cleared. Gates via the passed tx (no nested read).
    @discardableResult
    private func clearWeakPlaceholderCore(uid: String, transaction: SDSAnyWriteTransaction) -> Bool {
        guard store.hasValue(forKey: uid, transaction: transaction) else { return false }
        Logger.info("[WeakContact] clear placeholder")
        removeRecord(uid: uid, transaction: transaction)
        return true
    }

    // MARK: - Reconcile (flow ④, fallback for missed notifications)

    /// Pulls the full pending-removal set and reconciles the local cache with it.
    /// Triggered on cold start and after a full contacts sync. Fire-and-forget.
    @objc
    public func reconcileFromServer() {
        Task { await self.reconcile() }
    }

    private func reconcile() async {
        let serverRecords: [DTWeakContactRecord]
        do {
            serverRecords = try await DTDeletedRecordsApi().fetchDeletedRecords()
        } catch {
            // Gate: only reconcile when the pull fully succeeds.
            Logger.error("[WeakContact] reconcile fetch failed: \(error)")
            return
        }

        let serverMap = Dictionary(serverRecords.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let serverSet = Set(serverMap.keys)
        let cacheBefore = Set(records().keys)
        Logger.info("[WeakContact] reconcile server=\(serverSet.count) cache=\(cacheBefore.count)")

        databaseStorage.write { transaction in
            let contactsManager = TextSecureKitEnv.shared().contactsManager
            // Overwrite cache with the server mirror, applying diffs.
            for (uid, record) in serverMap {
                if cacheBefore.contains(uid) {
                    // Already weak: refresh record, then re-apply the snapshot so older
                    // records (persisted before demote ran) pick up name/avatar too.
                    self.persist(record: record, transaction: transaction)
                    self.demoteToExternal(uid: uid, name: record.name, avatar: record.avatar, transaction: transaction)
                } else {
                    // New (incl. backfilling a missed enter): placeholder + delete + demote.
                    self.enterWeakStateCore(record: record, transaction: transaction)
                }
            }
            for uid in cacheBefore.subtracting(serverSet) {
                let isFriend = contactsManager.signalAccount(forRecipientId: uid, transaction: transaction)?.isFriend ?? false
                if isFriend {
                    // Re-friended (friend sync already ran): clear placeholder, keep conversation.
                    self.clearWeakPlaceholderCore(uid: uid, transaction: transaction)
                } else {
                    // Removed: second-delete conversation + drop placeholder.
                    self.removeFromWeakStateCore(uid: uid, transaction: transaction)
                }
            }
            // Single post-commit invalidate + notify for the whole batch.
            self.notifyChange(after: transaction)
        }
    }

    // MARK: - Persistence

    private func persist(record: DTWeakContactRecord, transaction: SDSAnyWriteTransaction) {
        guard let data = try? JSONEncoder().encode(record) else {
            Logger.error("[WeakContact] encode failed")
            return
        }
        store.setData(data, key: record.uid, transaction: transaction)
        // Cache is invalidated post-commit (notifyChange); a pre-commit invalidate here
        // would let a concurrent read reload the stale (uncommitted) snapshot and poison it.
    }

    private func removeRecord(uid: String, transaction: SDSAnyWriteTransaction) {
        store.removeValue(forKey: uid, transaction: transaction)
    }

    // MARK: - Side effects

    /// Idempotent delete of the 1:1 conversation and all its messages.
    private func deleteLocalConversation(uid: String, transaction: SDSAnyWriteTransaction) {
        guard let thread = TSContactThread.getThread(contactId: uid, transaction: transaction) else {
            return
        }
        thread.removeAllThreadInteractions(with: transaction)
        thread.anyUpdate(transaction: transaction) { t in
            t.isRemovedFromConversation = true
        }
        thread.unstickThread(with: transaction)
    }

    /// Demote out of the friend store: keep the SignalAccount (name/avatar still resolve) but set isExternal.
    private func demoteToExternal(uid: String,
                                  name: String?,
                                  avatar: String?,
                                  transaction: SDSAnyWriteTransaction) {
        let contactsManager = TextSecureKitEnv.shared().contactsManager
        let account = contactsManager.signalAccount(forRecipientId: uid, transaction: transaction)
            ?? SignalAccount(recipientId: uid)
        // Section index collates on firstName; set it so the contact sorts by name, not the UID fallback ("T").
        let firstNameEmpty = account.contact?.firstName?.isEmpty ?? true
        if let name, !name.isEmpty, firstNameEmpty {
            if let contact = account.contact {
                // firstName is readonly; configWithFullName sets it in place without touching avatar/remark.
                contact.config(withFullName: name, phoneNumber: uid)
            } else {
                account.contact = Contact(fullName: name, phoneNumber: uid)
            }
        } else if account.contact == nil {
            account.contact = Contact(recipientId: uid)
        } else if let name, !name.isEmpty {
            // firstName already set (real friend being demoted): just refresh the display name.
            account.contact?.fullName = name
        }
        if let avatar, let avatarDict = Self.avatarDict(from: avatar) {
            account.contact?.avatar = avatarDict
        }
        account.contact?.isExternal = true
        contactsManager.updateSignalAccount(withRecipientId: uid,
                                            withNewSignalAccount: account,
                                            with: transaction)
    }

    private static func avatarDict(from jsonString: String) -> [AnyHashable: Any]? {
        guard !jsonString.isEmpty, let data = jsonString.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [AnyHashable: Any]
    }

    /// Invalidate the cache and notify listeners AFTER the write commits, so the next
    /// records() reload reads committed data instead of poisoning the cache with a
    /// pre-commit snapshot (the cause of weak contacts intermittently not showing).
    private func notifyChange(after transaction: SDSAnyWriteTransaction) {
        transaction.addAsyncCompletionOnMain { [weak self] in
            self?.invalidateCache()
            NotificationCenter.default.post(name: Self.weakContactsDidChangeNotification, object: nil)
        }
    }
}
