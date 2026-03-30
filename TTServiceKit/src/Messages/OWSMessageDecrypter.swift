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
    
    fileprivate init(
        envelope: DSKProtoEnvelope,
        envelopeData: Data?,
        plaintextData: Data?,
        transaction: SDSAnyWriteTransaction
    ) {
        self.envelope = envelope
        self.envelopeData = envelopeData
        self.plaintextData = plaintextData
    }
}

@objc
public class OWSMessageDecrypter: OWSMessageHandler {
    
    public override init() {
        super.init()
        
        SwiftSingletons.register(self)
    }
    
    let identityManager : OWSIdentityManager = OWSIdentityManager.shared()
    
    public func decryptEnvelope(_ envelope: DSKProtoEnvelope,
                                envelopeData: Data?,
                                transaction: SDSAnyWriteTransaction) -> Result<OWSMessageDecryptResult, Error> {
        owsAssertDebug(tsAccountManager.isRegistered())
        
        Logger.info("decrypting envelope: \(description(for: envelope))")
        
        guard envelope.hasType else {
            return .failure(OWSAssertionError("Incoming envelope is missing type."))
        }
        
        let builder = envelope.asBuilder()
        if !SDS.fitsInInt64(envelope.timestamp) {
            owsFailDebug("Invalid timestamp, will use 0.")
            builder.setTimestamp(0)
        }
        if envelope.hasSystemShowTimestamp && !SDS.fitsInInt64(envelope.systemShowTimestamp) {
            owsFailDebug("Invalid systemShowTimestamp, will use 0.")
            builder.setSystemShowTimestamp(0)
        }
        if envelope.hasSequenceID && !SDS.fitsInInt64(envelope.sequenceID) {
            owsFailDebug("Invalid sequenceID, will use 0.")
            builder.setSequenceID(0)
        }
        if envelope.hasNotifySequenceID && !SDS.fitsInInt64(envelope.notifySequenceID) {
            owsFailDebug("Invalid notifySequenceID, will use 0.")
            builder.setNotifySequenceID(0)
        }
        let fixedEnvelope = (try? builder.build()) ?? envelope

        if !fixedEnvelope.hasSource && fixedEnvelope.type != .notify {
            return .failure(OWSAssertionError("envelope has no Source nor notify msg."))
        }
        
        guard let encryptedData = fixedEnvelope.content else {
            owsFailDebug("no envelope content")
            return .failure(OWSAssertionError("Envelope has no content."))
        }

        owsAssertDebug(fixedEnvelope.source != nil)

        if fixedEnvelope.type != .unknown {
            guard let source = fixedEnvelope.source, source.count > 0 else {
                return .failure(OWSAssertionError("incoming envelope has invalid source"))
            }
        }
        
        let plaintextDataOrError: Result<Data, Error>
        switch fixedEnvelope.type {
        case .ciphertext:
            owsProdErrorWithEnvelope("received ciphertext message.", fixedEnvelope)
            let wrappedError = OWSError(error: .failedToDecryptMessage,
                                        description: "Decryption error",
                                        isRetryable: false,
                                        userInfo: [NSUnderlyingErrorKey: "ciphertext error"])
            plaintextDataOrError = .failure(wrappedError)
        case .prekeyBundle:
            owsProdErrorWithEnvelope("received prekeyBundle message.", fixedEnvelope)
            let wrappedError = OWSError(error: .failedToDecryptMessage,
                                        description: "Decryption error",
                                        isRetryable: false,
                                        userInfo: [NSUnderlyingErrorKey: "prekeyBundle error"])
            plaintextDataOrError = .failure(wrappedError)
        case .notify, .plaintext:
            return .success(OWSMessageDecryptResult(
                envelope: fixedEnvelope,
                envelopeData: envelopeData,
                plaintextData: fixedEnvelope.content,
                transaction: transaction
            ))
        case .etoee:

            guard let source = fixedEnvelope.source else {
                owsFailDebug("no source")
                return .failure(OWSError(error: .failedToDecryptMessage,
                                         description: "Envelope has no source address",
                                         isRetryable: false))
            }

            let sourceDevice = fixedEnvelope.sourceDevice
            guard sourceDevice > 0 else {
                owsFailDebug("no sourceDevice")
                return .failure(OWSError(error: .failedToDecryptMessage,
                                         description: "Envelope has no source device",
                                         isRetryable: false))
            }

            let sessionCipher: DTSessionCipher
            let eRMKey: Data?
            if let peerContext = fixedEnvelope.peerContext {
                sessionCipher = DTSessionCipher.init(recipientId: source, type: .group)
                sessionCipher.sourceDevice = sourceDevice;
                eRMKey = Data.data(FromBase64String: peerContext)
            } else {
                sessionCipher = DTSessionCipher.init(recipientId: source, type: .private)
                sessionCipher.sourceDevice = sourceDevice;
                eRMKey = nil
            }

            do {
                guard let identityKey = fixedEnvelope.identityKey else {
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
                envelope: fixedEnvelope,
                envelopeData: envelopeData,
                plaintextData: nil,
                transaction: transaction
            ))
        default:
            Logger.warn("Received unhandled envelope type: \(fixedEnvelope.type?.rawValue ?? 0)")
            return .failure(OWSGenericError("Received unhandled envelope type: \(fixedEnvelope.type?.rawValue ?? 0)"))
        }

        if case let .failure(error) = plaintextDataOrError {
            _ = processError(error, envelope: fixedEnvelope, untrustedGroupId: nil, transaction: transaction)
        }

        return plaintextDataOrError.map {
            OWSMessageDecryptResult(
                envelope: fixedEnvelope,
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
