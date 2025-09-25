//
//  Dependencies+SSK.swift
//  TTServiceKit
//
//  Created by Felix on 2022/1/18.
//

import Foundation

public protocol Dependencies {}

// MARK: - NSObject Dependencies

@objc
public extension NSObject {
    
    final var messageFetcherJob: MessageFetcherJob {
        SSKEnvironment.shared.messageFetcherJobRef
    }

    static var messageFetcherJob: MessageFetcherJob {
        SSKEnvironment.shared.messageFetcherJobRef
    }
    
    final var databaseStorage: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
    
    static var databaseStorage: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
    
    final var messageSender: MessageSender {
        SSKEnvironment.shared.messageSenderRef
    }
    
    static var messageSender: MessageSender {
        SSKEnvironment.shared.messageSenderRef
    }
    
    final var messageManager: OWSMessageManager {
        SSKEnvironment.shared.messageManagerRef
    }
    
    static var messageManager: OWSMessageManager {
        SSKEnvironment.shared.messageManagerRef
    }
    
    final var conversationPreviewManager: DTConversationPreviewManager {
        SSKEnvironment.shared.conversationPreviewManagerRef
    }
    
    static var conversationPreviewManager: DTConversationPreviewManager {
        SSKEnvironment.shared.conversationPreviewManagerRef
    }
    
    final var blockingManager: OWSBlockingManager {
        SSKEnvironment.shared.blockManagerRef
    }
    
    static var blockingManager: OWSBlockingManager {
        SSKEnvironment.shared.blockManagerRef
    }
    
    // This singleton is configured after the environments are created.
    final var notificationsManager: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManagerRef
    }

    // This singleton is configured after the environments are created.
    static var notificationsManager: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManagerRef
    }
    
    final var networkManager: NetworkManager {
        SSKEnvironment.shared.networkManagerRef
    }

    static var networkManager: NetworkManager {
        SSKEnvironment.shared.networkManagerRef
    }
    
    final var tsAccountManager: TSAccountManager {
        .shared
    }

    static var tsAccountManager: TSAccountManager {
        .shared
    }
    
    final var messageProcessor: MessageProcessor {
        SSKEnvironment.shared.messageProcessorRef
    }
    
    static var messageProcessor: MessageProcessor {
        SSKEnvironment.shared.messageProcessorRef
    }
    
    final var conversationPreviewProcessor: ConversationPreviewProcessor {
        SSKEnvironment.shared.conversationProcessorRef
    }
    
    static var conversationPreviewProcessor: ConversationPreviewProcessor {
        SSKEnvironment.shared.conversationProcessorRef
    }
    
    final var messageDecrypter: OWSMessageDecrypter {
        SSKEnvironment.shared.messageDecrypterRef
    }
    
    static var messageDecrypter: OWSMessageDecrypter {
        SSKEnvironment.shared.messageDecrypterRef
    }
    
    final var messagePipelineSupervisor: MessagePipelineSupervisor {
        SSKEnvironment.shared.messagePipelineSupervisorRef
    }
    
    static var messagePipelineSupervisor: MessagePipelineSupervisor {
        SSKEnvironment.shared.messagePipelineSupervisorRef
    }
    
    final var signalService: OWSSignalService {
        .sharedInstance()
    }

    static var signalService: OWSSignalService {
        .sharedInstance()
    }
    
    final var outageDetection: OutageDetection {
        .shared
    }
    
    static var outageDetection: OutageDetection {
        .shared
    }
    
    final var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    static var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }
    
    final var grdbStorageAdapter: GRDBDatabaseStorageAdapter {
        databaseStorage.grdbStorage
    }

    static var grdbStorageAdapter: GRDBDatabaseStorageAdapter {
        databaseStorage.grdbStorage
    }
    
    final var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }

    static var modelReadCaches: ModelReadCaches {
        SSKEnvironment.shared.modelReadCachesRef
    }
    
    final var socketManager: SocketManager {
        SSKEnvironment.shared.socketManagerRef
    }
    
    static var socketManager: SocketManager {
        SSKEnvironment.shared.socketManagerRef
    }
    
    final var webSocketFactory: WebSocketFactory {
        SSKEnvironment.shared.webSocketFactoryRef
    }
    
    static var webSocketFactory: WebSocketFactory {
        SSKEnvironment.shared.webSocketFactoryRef
    }
    
    final var notificationPresenter: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManagerRef
    }

    static var notificationPresenter: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManagerRef
    }
    
    final var phoneNumberUtil: PhoneNumberUtil {
        SSKEnvironment.shared.phoneNumberUtilRef
    }

    static var phoneNumberUtil: PhoneNumberUtil {
        SSKEnvironment.shared.phoneNumberUtilRef
    }

}


// MARK: - Obj-C Dependencies(Non-NSObject)

public extension Dependencies {
    
    var messageFetcherJob: MessageFetcherJob {
        SSKEnvironment.shared.messageFetcherJobRef
    }

    static var messageFetcherJob: MessageFetcherJob {
        SSKEnvironment.shared.messageFetcherJobRef
    }
    
    var databaseStorage: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
    
    static var databaseStorage: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
    
    var messageSender: MessageSender {
        SSKEnvironment.shared.messageSenderRef
    }
    
    static var messageSender: MessageSender {
        SSKEnvironment.shared.messageSenderRef
    }
    
    var messageManager: OWSMessageManager {
        SSKEnvironment.shared.messageManagerRef
    }
    
    static var messageManager: OWSMessageManager {
        SSKEnvironment.shared.messageManagerRef
    }
    
    var messageProcessor: MessageProcessor {
        SSKEnvironment.shared.messageProcessorRef
    }
    
    static var messageProcessor: MessageProcessor {
        SSKEnvironment.shared.messageProcessorRef
    }
    
    var messageDecrypter: OWSMessageDecrypter {
        SSKEnvironment.shared.messageDecrypterRef
    }
    
    static var messageDecrypter: OWSMessageDecrypter {
        SSKEnvironment.shared.messageDecrypterRef
    }
    
    var messagePipelineSupervisor: MessagePipelineSupervisor {
        SSKEnvironment.shared.messagePipelineSupervisorRef
    }
    
    static var messagePipelineSupervisor: MessagePipelineSupervisor {
        SSKEnvironment.shared.messagePipelineSupervisorRef
    }
    
    var blockingManager: OWSBlockingManager {
        SSKEnvironment.shared.blockManagerRef
    }
    
    static var blockingManager: OWSBlockingManager {
        SSKEnvironment.shared.blockManagerRef
    }
    
    // This singleton is configured after the environments are created.
    var notificationsManager: NotificationsProtocol? {
        SSKEnvironment.shared.notificationsManagerRef
    }

    // This singleton is configured after the environments are created.
    static var notificationsManager: NotificationsProtocol? {
        SSKEnvironment.shared.notificationsManagerRef
    }
    
    var networkManager: NetworkManager {
        .shared
    }
    
    static var networkManager: NetworkManager {
        .shared
    }
    
    var signalService: OWSSignalService {
        .sharedInstance()
    }
    
    static var signalService: OWSSignalService {
        .sharedInstance()
    }

    var outageDetection: OutageDetection {
        .shared
    }
    
    static var outageDetection: OutageDetection {
        .shared
    }
    
    var contactsManager: ContactsManagerProtocol {
        SSKEnvironment.shared.contactsManagerRef
    }

    static var contactsManager: ContactsManagerProtocol {
        SSKEnvironment.shared.contactsManagerRef
    }
    
    var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }

    static var storageCoordinator: StorageCoordinator {
        SSKEnvironment.shared.storageCoordinatorRef
    }
    
    var socketManager: SocketManager {
        SSKEnvironment.shared.socketManagerRef
    }
    
    static var socketManager: SocketManager {
        SSKEnvironment.shared.socketManagerRef
    }
    
    var webSocketFactory: WebSocketFactory {
        SSKEnvironment.shared.webSocketFactoryRef
    }
    
    static var webSocketFactory: WebSocketFactory {
        SSKEnvironment.shared.webSocketFactoryRef
    }
    
    var notificationPresenter: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManager
    }

    static var notificationPresenter: NotificationsProtocol {
        SSKEnvironment.shared.notificationsManager
    }
}


@objc
public extension NetworkManager {
    static var shared: NetworkManager {
        SSKEnvironment.shared.networkManagerRef
    }
}

@objc
public extension TSAccountManager {
    static var shared: TSAccountManager {
        SSKEnvironment.shared.tsAccountManagerRef
    }
}

// MARK: -

@objc
public extension SDSDatabaseStorage {
    static var shared: SDSDatabaseStorage {
        SSKEnvironment.shared.databaseStorageRef
    }
}

// MARK: -

@objc
public extension SSKPreferences {
    static var shared: SSKPreferences {
        SSKEnvironment.shared.sskPreferencesRef
    }
}

// MARK: -

@objc
public extension SocketManager {
    static var shared: SocketManager {
        SSKEnvironment.shared.socketManagerRef
    }
}

// MARK: -

@objc
public extension PhoneNumberUtil {
    static var shared: PhoneNumberUtil {
        SSKEnvironment.shared.phoneNumberUtilRef
    }
}
