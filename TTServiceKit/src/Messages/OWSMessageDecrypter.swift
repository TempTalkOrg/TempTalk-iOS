//
//  OWSMessageDecrypter.swift
//  TTServiceKit
//
//  Created by Felix on 2022/7/8.
//

import Foundation

public struct OWSMessageDecryptResult: Dependencies {
    public let envelope: DSKProtoEnvelope
    public let envelopeData: Data?
    public let plaintextData: Data?
//    public let identity: OWSIdentity
    
    fileprivate init(
        envelope: DSKProtoEnvelope,
        envelopeData: Data?,
        plaintextData: Data?,
//        identity: OWSIdentity,
        transaction: SDSAnyWriteTransaction
    ) {
        self.envelope = envelope
        self.envelopeData = envelopeData
        self.plaintextData = plaintextData
//        self.identity = identity
        
//        guard let sourceAddress = envelope.sourceDevice else {
//            owsFailDebug("missing source address")
//            return
//        }
//        owsAssertDebug(envelope.sourceDevice > 0)
        
        // Self-sent messages should be discarded during the decryption process.
//        let localDeviceId = Self.tsAccountManager.storedDeviceId()
//        owsAssertDebug(!(sourceAddress.isLocalAddress && envelope.sourceDevice == localDeviceId))
        
        // Having received a valid (decryptable) message from this user,
        // make note of the fact that they have a valid Signal account.
//        SignalRecipient.mark(
//            asRegisteredAndGet: sourceAddress,
//            deviceId: envelope.sourceDevice,
//            trustLevel: .high,
//            transaction: transaction
//        )
    }
}

@objc
public class OWSMessageDecrypter: OWSMessageHandler {
    
    public override init() {
        super.init()
        
        SwiftSingletons.register(self)
        
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(messageProcessorDidFlushQueue),
//            name: MessageProcessor.messageProcessorDidFlushQueue,
//            object: nil
//        )
        
    }
    
//    @objc
//    func messageProcessorDidFlushQueue() {
//        // We don't want to send additional resets until we
//        // have received the "empty" response from the WebSocket
//        // or finished at least one REST fetch.
//        guard Self.messageFetcherJob.hasCompletedInitialFetch else { return }
//    }
    
    let identityManager : OWSIdentityManager = OWSIdentityManager.shared()
    
    public func decryptEnvelope(_ envelope: DSKProtoEnvelope,
                                envelopeData: Data?,
                                transaction: SDSAnyWriteTransaction) -> Result<OWSMessageDecryptResult, Error> {
        owsAssertDebug(tsAccountManager.isRegistered())
        
        Logger.info("decrypting envelope: \(description(for: envelope))")
        
        guard envelope.hasType else {
            return .failure(OWSAssertionError("Incoming envelope is missing type."))
        }
        
        guard SDS.fitsInInt64(envelope.timestamp) else {
            return .failure(OWSAssertionError("Invalid timestamp."))
        }
        
        guard !envelope.hasSystemShowTimestamp || SDS.fitsInInt64(envelope.systemShowTimestamp) else {
            return .failure(OWSAssertionError("Invalid serverTimestamp."))
        }
        
        if !envelope.hasSource && envelope.type != .notify {
            return .failure(OWSAssertionError("envelope has no Source nor notify msg."))
        }
        
        guard let encryptedData = envelope.content else {
            owsFailDebug("no envelope content")
            return .failure(OWSAssertionError("Envelope has no content."))
        }
               
        owsAssertDebug(envelope.source != nil)
        
        if envelope.type != .unknown {
            guard let source = envelope.source, source.count > 0 else {
                return .failure(OWSAssertionError("incoming envelope has invalid source"))
            }
            
            // TODO: server 发送消息没有 sourceDevice 确认好哪种情况没有做判断过滤
//            guard envelope.hasSourceDevice(), envelope.sourceDevice > 0 else {
//                return .failure(OWSAssertionError("incoming envelope has invalid source device"))
//            }
        }
        
        let plaintextDataOrError: Result<Data, Error>
        switch envelope.type {
        case .ciphertext:
            owsProdErrorWithEnvelope("received ciphertext message.", envelope)
            let wrappedError = OWSError(error: .failedToDecryptMessage,
                                        description: "Decryption error",
                                        isRetryable: false,
                                        userInfo: [NSUnderlyingErrorKey: "ciphertext error"])
            plaintextDataOrError = .failure(wrappedError)
        case .prekeyBundle:
            owsProdErrorWithEnvelope("received prekeyBundle message.", envelope)
            let wrappedError = OWSError(error: .failedToDecryptMessage,
                                        description: "Decryption error",
                                        isRetryable: false,
                                        userInfo: [NSUnderlyingErrorKey: "prekeyBundle error"])
            plaintextDataOrError = .failure(wrappedError)
        case .notify, .plaintext:
            return .success(OWSMessageDecryptResult(
                envelope: envelope,
                envelopeData: envelopeData,
                plaintextData: envelope.content,
                transaction: transaction
            ))
        case .etoee:
            
            guard let source = envelope.source else {
                owsFailDebug("no source")
                return .failure(OWSError(error: .failedToDecryptMessage,
                                         description: "Envelope has no source address",
                                         isRetryable: false))
            }
            
            let sourceDevice = envelope.sourceDevice
            guard sourceDevice > 0 else {
                owsFailDebug("no sourceDevice")
                return .failure(OWSError(error: .failedToDecryptMessage,
                                         description: "Envelope has no source device",
                                         isRetryable: false))
            }
            
            let sessionCipher: DTSessionCipher
            let eRMKey: Data?
            if let peerContext = envelope.peerContext {
                sessionCipher = DTSessionCipher.init(recipientId: source, type: .group)
                sessionCipher.sourceDevice = sourceDevice;
                eRMKey = Data.data(FromBase64String: peerContext)
            } else {
                sessionCipher = DTSessionCipher.init(recipientId: source, type: .private)
                sessionCipher.sourceDevice = sourceDevice;
                eRMKey = nil
            }
            
            do {
                guard let identityKey = envelope.identityKey else {
                    return .failure(OWSError(error: .failedToDecryptMessage,
                                             description: "Envelope identityKey is nil",
                                             isRetryable: false))
                }
                let encryptedMessage = try DTEncryptedMessage.init(data: encryptedData, eRMKey: eRMKey)
                let plaintextData = try sessionCipher.decrypt(encryptedMessage, localTheirIdKey: identityKey, transaction: transaction)
                plaintextDataOrError = .success(plaintextData.withoutPadding())
            } catch {
                plaintextDataOrError = .failure(error)
            }
        case .receipt, .keyExchange, .unknown:
            return .success(OWSMessageDecryptResult(
                envelope: envelope,
                envelopeData: envelopeData,
                plaintextData: nil,
                transaction: transaction
            ))
        default:
            Logger.warn("Received unhandled envelope type: \(envelope.type?.rawValue ?? 0)")
            return .failure(OWSGenericError("Received unhandled envelope type: \(envelope.type?.rawValue ?? 0)"))
        }
        
        if case let .failure(error) = plaintextDataOrError {
            _ = processError(error, envelope: envelope, untrustedGroupId: nil, transaction: transaction)
        }
        
        return plaintextDataOrError.map {
            OWSMessageDecryptResult(
                envelope: envelope,
                envelopeData: envelopeData,
                plaintextData: $0,
                transaction: transaction
            )
        }
    }
    
    private func processError(
        _ error: Error,
        envelope: DSKProtoEnvelope,
        untrustedGroupId: Data?,
        transaction: SDSAnyWriteTransaction
    ) -> Error {
        let logString = "Error while decrypting \(description(for: envelope)), error: \(error)"
        
        Logger.error(logString)
        
        let wrappedError: Error
        var exception: NSException? = nil
        
        if (error as NSError).domain == OWSTTServiceKitErrorDomain {
            wrappedError = error
        } else if ((error as NSError).domain == SCKExceptionWrapperErrorDomain) {
            exception = (error as NSError).userInfo[SCKExceptionWrapperUnderlyingExceptionKey] as? NSException
            wrappedError = error
        } else {
            wrappedError = OWSError(error: .failedToDecryptMessage,
                                    description: "Decryption error",
                                    isRetryable: false,
                                    userInfo: [NSUnderlyingErrorKey: error])
        }
        
        if let exception = exception {
            switch exception.name.rawValue {
            case NoSessionException:
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorNoSession(), envelope)
            case InvalidKeyException:
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorInvalidKey(), envelope)
            case InvalidKeyIdException:
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorInvalidKeyId(), envelope)
            case InvalidVersionException:
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorInvalidMessageVersion(), envelope)
            case UntrustedIdentityKeyException:
                // Should no longer get here, since we now record the new identity for incoming messages.
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorUntrustedIdentityKeyException(),
                                         envelope)
                owsFailDebug("Failed to trust identity on incoming message from \(envelopeAddress(envelope))")
            case DuplicateMessageException:
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageDuplicateEnvelope(), envelope)
//                preconditionFailure("checked above")
            case DTProtoDecryptMessageException:
                if let errorDes = exception.reason {
                    owsProdErrorWithEnvelope(errorDes, envelope)
                } else {
                    owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorCorruptMessage(), envelope)
                }
            default: // another SignalError, or another kind of Error altogether
                owsProdErrorWithEnvelope(OWSAnalyticsEvents.messageManagerErrorCorruptMessage(), envelope)
            }
        }
        
        return wrappedError
    }
    
    // The debug logs can be more verbose than the analytics events.
    //
    // In this case `descriptionForEnvelope` is valuable enough to
    // log but too dangerous to include in the analytics event.
    // See OWSProdErrorWEnvelope.
    private func owsProdErrorWithEnvelope(
        _ eventName: String,
        _ envelope: DSKProtoEnvelope,
        file: String = #file,
        line: Int32 = #line,
        function: String = #function
    ) {
        Logger.error("\(function):\(line) \(eventName): \(description(for: envelope))")
        OWSAnalytics.logEvent(eventName,
                              severity: .error,
                              parameters: nil,
                              location: "\((file as NSString).lastPathComponent):\(function)",
                              line: line)
    }
}


extension Data {
    
    public static func data(FromBase64String string: String) -> Data? {
        guard let data = NSData(fromBase64String : string) else {
            return nil
        }
        return data as Data
    }
}
