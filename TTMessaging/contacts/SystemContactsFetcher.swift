//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit

enum Result<T, ErrorType> {
    case success(T)
    case error(ErrorType)
}

@objc
public enum ContactStoreAuthorizationStatus: UInt {
    case notDetermined,
         restricted,
         denied,
         authorized
}

@objc public protocol SystemContactsFetcherDelegate: AnyObject {
    func systemContactsFetcher(_ systemContactsFetcher: SystemContactsFetcher, updatedContacts contacts: [Contact], isUserRequested: Bool)
}

@objc
public class SystemContactsFetcher: NSObject {

    private let serialQueue = DispatchQueue(label: "SystemContactsFetcherQueue")

    var lastContactUpdateHash: Int?
    var lastDelegateNotificationDate: Date?

    @objc
    public weak var delegate: SystemContactsFetcherDelegate?
    
    @objc
    public private(set) var systemContactsHaveBeenRequestedAtLeastOnce = false
    private var hasSetupObservation = false

    @objc
    public func userRequestedRefresh(isUserRequested: Bool = false, completion: @escaping (Error?) -> Void) {
        // 不是主应用不拉取通讯录信息
        if !CurrentAppContext().isMainApp {
            return
        }

        Logger.info("request full contacts, isUserRequested: \(isUserRequested)")
        updateContacts(completion: completion, isUserRequested: isUserRequested)
    }

    private func updateContacts(completion completionParam: ((Error?) -> Void)?, isUserRequested: Bool = false) {
        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)", completionBlock: { [weak self] status in
            AssertIsOnMainThread()

            guard status == .expired else {
                return
            }

            guard let _ = self else {
                return
            }
            Logger.error("background task time ran out before contacts fetch completed.")
        })

        // Ensure completion is invoked on main thread.
        let completion: (Error?) -> Void = { error in
            DispatchMainThreadSafe({
                completionParam?(error)

                assert(backgroundTask != nil)
                backgroundTask = nil
            })
        }

        systemContactsHaveBeenRequestedAtLeastOnce = true

        serialQueue.async {
            Logger.info("\(self.logTag) fetching contacts")

            // load interal contacts.
            var fetchedContacts: [Contact]?
            var loadError: Error?
            Environment.shared.contactsManager.loadInternalContactsSuccess({ (internalContacts) in
                fetchedContacts = internalContacts as? [Contact]
                
                guard let contacts = fetchedContacts else {
                    owsFailDebug("\(self.logTag) contacts was unexpectedly not set.")
                    completion(loadError)
                    return
                }
                
                Logger.info("\(self.logTag) fetched \(contacts.count) contacts.")
                let contactsHash  = HashableArray(contacts).hashValue
                
                DispatchMainThreadSafe {
                    var shouldNotifyDelegate = false
                    
                    if self.lastContactUpdateHash != contactsHash {
                        Logger.info("\(self.logTag) contact hash changed. new contactsHash: \(contactsHash)")
                        shouldNotifyDelegate = true
                    } else if isUserRequested {
                        Logger.info("\(self.logTag) ignoring debounce due to user request")
                        shouldNotifyDelegate = true
                    } else {
                        
                        // If nothing has changed, only notify delegate (to perform contact intersection) every N hours
                        if let lastDelegateNotificationDate = self.lastDelegateNotificationDate {
                            let kDebounceInterval = TimeInterval(12 * 60 * 60)
                            
                            let expiresAtDate = Date(timeInterval: kDebounceInterval, since: lastDelegateNotificationDate)
                            if  Date() > expiresAtDate {
                                Logger.info("\(self.logTag) debounce interval expired at: \(expiresAtDate)")
                                shouldNotifyDelegate = true
                            } else {
                                Logger.info("\(self.logTag) ignoring since debounce interval hasn't expired")
                            }
                        } else {
                            Logger.info("\(self.logTag) first contact fetch. contactsHash: \(contactsHash)")
                            shouldNotifyDelegate = true
                        }
                    }
                    
                    guard shouldNotifyDelegate else {
                        Logger.info("\(self.logTag) no reason to notify delegate.")
                        
                        completion(nil)
                        
                        return
                    }
                    
                    self.lastDelegateNotificationDate = Date()
                    self.lastContactUpdateHash = contactsHash
                    
                    self.delegate?.systemContactsFetcher(self, updatedContacts: contacts, isUserRequested: isUserRequested)
                    completion(nil)
                }
                
            }, failure: { (error) in
                loadError = error
                Logger.error("\(self.logTag) load internal contacts failed: \(String(describing: error))")
                completion(error)
            })
        }
    }
}

struct HashableArray<Element: Hashable>: Hashable {
    var elements: [Element]
    init(_ elements: [Element]) {
        self.elements = elements
    }

    var hashValue: Int {
        // random generated 32bit number
        let base = 224712574
        var position = 0
        return elements.reduce(base) { (result, element) -> Int in
            // Make sure change in sort order invalidates hash
            position += 1
            return result ^ element.hashValue + position
        }
    }

    static func == (lhs: HashableArray, rhs: HashableArray) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
}
