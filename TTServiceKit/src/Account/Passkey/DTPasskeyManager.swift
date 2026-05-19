//
//  DTPasskeyForLoginFinalize.swift
//  TTServiceKit
//
//  Created by hornet on 2023/7/20.
//

import AuthenticationServices
import LocalAuthentication
import Foundation


extension NSNotification.Name {
    static let userSignedIn = Notification.Name("UserSignedInNotification")
}

enum DTPasskeysAuthType: Int {
    case login = 0
    case register = 1
}

enum DTPasskeysErrorCode: NSInteger {
    case miss_user_id = 300000
    case loginInitializeRequestError = 300001
    case loginInitializeResponseError = 300002
    
    case registerInitializeRequestError = 300003
    case registerInitializeResponseError = 300004
    
    case loginFinalizeRequestError = 300005
    case loginFinalizeResponseError = 300006
    
    case registerFinalizeRequestError = 300007
    case registerFinalizeResponseError = 300008
    
    case unSoupportVersionError = 300010
    case unSoupportAuthError = 300011
    case userCancelledError = 300012
    
    case decodeBase64UrlError = 300013
    case passkeyWithunauthorized = 300014
    case passkeyAuthAcountError = 300015
    case passkeyAuthAcountRegistrationError = 300016
    case unKnowError = 400000

    var isUserCancelled: Bool {
        return self == .userCancelledError
    }

    var localizedMessage: String {
        switch self {
        case .userCancelledError:
            return ""
        case .registerInitializeRequestError, .registerInitializeResponseError:
            return Localized("PASSKEY_ERROR_REGISTER_INITIALIZE", comment: "")
        case .registerFinalizeRequestError, .registerFinalizeResponseError:
            return Localized("PASSKEY_ERROR_REGISTER_FINALIZE", comment: "")
        case .loginInitializeRequestError, .loginInitializeResponseError:
            return Localized("PASSKEY_ERROR_LOGIN_INITIALIZE", comment: "")
        case .loginFinalizeRequestError, .loginFinalizeResponseError:
            return Localized("PASSKEY_ERROR_LOGIN_FINALIZE", comment: "")
        case .unSoupportVersionError:
            return Localized("PASSKEY_ERROR_UNSUPPORTED_VERSION", comment: "")
        case .unSoupportAuthError:
            return Localized("PASSKEY_ERROR_UNSUPPORTED_AUTH", comment: "")
        case .decodeBase64UrlError, .miss_user_id:
            return Localized("PASSKEY_ERROR_DATA", comment: "")
        case .passkeyWithunauthorized:
            return Localized("SELECTED_ERROR_PASSKEY", comment: "")
        case .passkeyAuthAcountError, .passkeyAuthAcountRegistrationError:
            return Localized("PASSKEY_ERROR_ACCOUNT", comment: "")
        case .unKnowError:
            return Localized("PASSKEY_ERROR_UNKNOWN", comment: "")
        }
    }
}

@objc
public class DTPasskeyManager: NSObject, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate  {
    let registerForPasskeysApi = DTPasskeyForRegisterApi()
    let registerFinalizeForPasskeysApi = DTPasskeyRegisterFinalizeApi()
    let loginInitializeApi = DTPasskeyForLoginInitializeApi()
    let loginFinalizeApi = DTPasskeyForLoginFinalizeApi()
    let checkUserPasskeyApi = DTCheckUserPasskeyApi()
    let checkAccountExistsApi = DTCheckAccountExistsApi()
    var loginCompletionHandler : ((DTAPIMetaEntity?, Error?) -> Void)?
    var registerCompletionHandler : ((Error?) -> Void)?
    var passkeysAuthType : DTPasskeysAuthType?
    
    // TODO: insert your domain name here
    var domain: String {
        get {
            if(!TSConstants.isUsingProductionService){
                return "webauthn.test.chative.im"
            } else {
                return "chative.com"
            }
        }
    }
    var authenticationAnchor: ASPresentationAnchor?
    
    @available(iOS 16.0, *)
    /// passkey登录
    /// - Parameters:
    ///   - uid: uid
    ///   - anchor: window
    ///   - completionHandler: 完成回调
    @objc public func signInWith(uid: String?, anchor: ASPresentationAnchor, completionHandler: @escaping (DTAPIMetaEntity?, Error?) -> Void) {
        self.passkeysAuthType = .login
        self.authenticationAnchor = anchor
        self.loginCompletionHandler = completionHandler
        guard let user_id = uid else {
            let error = NSError(domain: self.domain, code: DTPasskeysErrorCode.loginInitializeResponseError.rawValue ,userInfo: [NSLocalizedDescriptionKey:"response error"])
            if let loginCompletionHandler = self.loginCompletionHandler {
                loginCompletionHandler(nil,error)
            }
            return
        }
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        loginInitializeApi.loginInitializeForPasskeys(user_id) { entity in
            guard let entity = entity else {
                let error = NSError(domain: self.domain, code: DTPasskeysErrorCode.miss_user_id.rawValue ,userInfo: [NSLocalizedDescriptionKey:"miss user_id"])
                if let loginCompletionHandler = self.loginCompletionHandler {
                    loginCompletionHandler(nil,error)
                }
                return
            }
            
            let creationRequest = entity.data
            guard let publicKey = creationRequest["publicKey"] as? [String : Any ],
                  let challenge_str = publicKey["challenge"] as? String else {
                
                let error = NSError(domain: self.domain, code: DTPasskeysErrorCode.loginInitializeResponseError.rawValue ,userInfo: [NSLocalizedDescriptionKey:"response error"])
                if let loginCompletionHandler = self.loginCompletionHandler {
                    loginCompletionHandler(nil,error)
                }
                Logger.error("[Passkeys module] authorizationController completionHandler loginInitializeApi response error --- publicKey or challenge_str error")
                return
            }
            guard let challenge = challenge_str.decodeBase64Url() else {
                let error = NSError(domain: self.domain, code: DTPasskeysErrorCode.decodeBase64UrlError.rawValue ,userInfo: [NSLocalizedDescriptionKey:"decode base64Url fail"])
                if let loginCompletionHandler = self.loginCompletionHandler {
                    loginCompletionHandler(nil,error)
                }
                return
            }
            let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
            //                if let userVerification = assertionRequestOptions.publicKey.userVerification {
            //                    assertionRequest.userVerificationPreference = ASAuthorizationPublicKeyCredentialUserVerificationPreference.init(rawValue: userVerification)
            //                }
            let authController = ASAuthorizationController(authorizationRequests: [ assertionRequest ] )
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
            
        } failure: { error, entity in
            Logger.info("entity = \(String(describing: entity?.signal_modelToJSONString()))")
            if let loginCompletionHandler = self.loginCompletionHandler {
                loginCompletionHandler(nil,error)
            }
            Logger.error("[Passkeys module] Error: loginInitializeApi fail")
        }
    }
    
    @available(iOS 16.0, *)
    /// 注册
    /// - Parameters:
    ///   - userName: 用户名
    ///   - anchor: window
    ///   - completionHandler: 成功回调
    @objc public func signUpWith(userName: String, anchor: ASPresentationAnchor, completionHandler: @escaping (Error?) -> Void){
        self.authenticationAnchor = anchor
        self.registerCompletionHandler = completionHandler
        self.passkeysAuthType = .register
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        registerForPasskeysApi.registerForPasskeys { entity in
            guard let entity = entity else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.registerInitializeResponseError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerInitializeResponseError.localizedMessage])
                self.registerCompletionHandler?(error)
                return
            }
            let creationRequest = entity.data
            guard let publicKey = creationRequest["publicKey"] as? [String : Any ],
                  let challenge_str = publicKey["challenge"] as? String else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.registerInitializeResponseError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerInitializeResponseError.localizedMessage])
                self.registerCompletionHandler?(error)
                return
            }
            guard let challenge = challenge_str.decodeBase64Url() else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.decodeBase64UrlError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.decodeBase64UrlError.localizedMessage])
                self.registerCompletionHandler?(error)
                return
            }
            
            guard let publicKey = creationRequest["publicKey"] as? [String : Any],
                    let user = publicKey["user"] as? [String : Any],
                    let userId = user["id"] as? String else {
                
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.registerInitializeResponseError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerInitializeResponseError.localizedMessage])
                self.registerCompletionHandler?(error)
                return
            }
            guard let userID = userId.decodeBase64Url() else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.decodeBase64UrlError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.decodeBase64UrlError.localizedMessage])
                self.registerCompletionHandler?(error)
                return
            }
            let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge,
                                                                                                      name: userName,
                                                                                                      userID: userID)
            let authController = ASAuthorizationController(authorizationRequests: [ registrationRequest ] )
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        } failure: { error, entity in
            let wrappedError = NSError(domain: self.domain,
                                       code: DTPasskeysErrorCode.registerInitializeRequestError.rawValue,
                                       userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerInitializeRequestError.localizedMessage])
            self.registerCompletionHandler?(wrappedError)
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if #available(iOS 16.0, *) {
            switch authorization.credential {
            case let credentialRegistration as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                Logger.info("[Passkeys module] A new credential was registered: \(credentialRegistration)")
                sendRegistrationResponse(params: credentialRegistration) { [weak self] error in
                    guard let registerCompletionHandler = self?.registerCompletionHandler else {
                        return
                    }
                    registerCompletionHandler(error)
                }
            case let credentialAssertion as ASAuthorizationPlatformPublicKeyCredentialAssertion:
                Logger.info("[Passkeys module] A credential was used to authenticate: \(credentialAssertion)")
                // After the server has verified the assertion, sign the user in.
                sendAuthenticationResponse(params: credentialAssertion) { [weak self] response, error  in
                    guard let loginCompletionHandler = self?.loginCompletionHandler else {
                        return
                    }
                    loginCompletionHandler(response, error)
                }
            default:
                if(self.passkeysAuthType == .login){
                    let error = NSError(domain: self.domain,
                                        code: DTPasskeysErrorCode.unSoupportAuthError.rawValue ,
                                        userInfo: [NSLocalizedDescriptionKey:"unsoupport auth type"])
                    guard let loginCompletionHandler = self.loginCompletionHandler else {
                        return
                    }
                    loginCompletionHandler(nil, error)
                    Logger.error("[Passkeys module] authorizationController didCompleteWithAuthorization received unknown authorization type. --> login")
                } else if (self.passkeysAuthType == .register){
                    let error = NSError(domain: self.domain,
                                        code: DTPasskeysErrorCode.unSoupportAuthError.rawValue ,
                                        userInfo: [NSLocalizedDescriptionKey:"unsoupport auth type"])
                    guard let registerCompletionHandler = self.registerCompletionHandler else {
                        return
                    }
                    registerCompletionHandler(error)
                    Logger.error("[Passkeys module] authorizationController didCompleteWithAuthorization received unknown authorization type. --> register")
                } else {
                    Logger.error("[Passkeys module] authorizationController didCompleteWithAuthorization received unknown authorization type. ")
                }
            }
        } else {
            Logger.error("[Passkeys module] authorizationController didCompleteWithAuthorization OS version unsoupported")
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let authorizationError = ASAuthorizationError.Code(rawValue: (error as NSError).code) else {
            Logger.error("[Passkeys module] Unexpected authorization error: \(error.localizedDescription)")
            return
        }
        
        if authorizationError == .canceled {
            // Either no credentials were found and the request silently ended, or the user canceled the request.
            // Consider asking the user to create an account.
            if(self.passkeysAuthType == .login){
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.userCancelledError.rawValue ,
                                    userInfo: [NSLocalizedDescriptionKey:"User cancelled use passkey login"])
                guard let loginCompletionHandler = self.loginCompletionHandler else {
                    return
                }
                loginCompletionHandler(nil, error)
                Logger.error("[Passkeys module] didCompleteWithError User cancelled use passkey --> login")
            } else if (self.passkeysAuthType == .register){
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.userCancelledError.rawValue ,
                                    userInfo: [NSLocalizedDescriptionKey:"User cancelled use passkey register"])
                guard let registerCompletionHandler = self.registerCompletionHandler else {
                    return
                }
                registerCompletionHandler(error)
                Logger.info("[Passkeys module] didCompleteWithError User cancelled use passkey --> register")
            } else {
                Logger.info("[Passkeys module] user cancelled use passkey.")
            }
            
        } else {
            // Other ASAuthorization error.
            // The userInfo dictionary should contain useful information.
            Logger.error("[Passkeys module] Error: \((error as NSError).userInfo)")
            if(self.passkeysAuthType == .login){
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.unKnowError.rawValue ,
                                    userInfo: [NSLocalizedDescriptionKey:"unsupported authType"])
                Logger.error("[Passkeys module] didCompleteWithError response error message = \(error.localizedDescription)")
                guard let loginCompletionHandler = self.loginCompletionHandler else {
                    return
                }
                loginCompletionHandler(nil, error)
            } else if (self.passkeysAuthType == .register){
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.unKnowError.rawValue ,
                                    userInfo: [NSLocalizedDescriptionKey:"unsupported AuthType"])
                Logger.error("[Passkeys module] didCompleteWithError response error message = \(error.localizedDescription)")
                guard let registerCompletionHandler = self.registerCompletionHandler else {
                    return
                }
                registerCompletionHandler(error)
            } else {
                Logger.error("[Passkeys module] didCompleteWithError response other ASAuthorization error = \(error.localizedDescription)")
            }
            
        }
    }
    
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return authenticationAnchor!
    }
    
    func didFinishSignIn() {
        NotificationCenter.default.post(name: .userSignedIn, object: nil)
    }
    
    // Finalize the user account and credential registration
    // see https://github.com/teamhanko/apple-wwdc21-webauthn-example/blob/master/main.go
    @available(iOS 16.0, *)
    func sendRegistrationResponse(params: ASAuthorizationPlatformPublicKeyCredentialRegistration, completionHandler: @escaping (Error?) -> Void) {
        guard let attestationObject = params.rawAttestationObject else {
            let error = NSError(domain: self.domain,
                                code: DTPasskeysErrorCode.registerFinalizeRequestError.rawValue,
                                userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerFinalizeRequestError.localizedMessage])
            completionHandler(error)
            return
        }
        let response = [
            "attestationObject": attestationObject.toBase64Url(),
            "clientDataJSON": params.rawClientDataJSON.toBase64Url()
        ]
        let parameters: [String : Any] = [
            "id": params.credentialID.toBase64Url(),
            "rawId": params.credentialID.toBase64Url(),
            "type": "public-key",
            "response": response
        ]
        self.registerFinalizeForPasskeysApi.registerFinalizeForPasskeys(parameters) { entity in
            guard let entity = entity else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.registerFinalizeResponseError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerFinalizeResponseError.localizedMessage])
                completionHandler(error)
                return
            }
            if(entity.status == 0){
                completionHandler(nil)
            } else {
                let error = NSError(domain: self.domain,
                                    code: DTPasskeysErrorCode.registerFinalizeResponseError.rawValue,
                                    userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerFinalizeResponseError.localizedMessage])
                completionHandler(error)
                Logger.error("[Passkeys module] error FinalizeForPasskeysApi status=\(entity.status)")
            }
        } failure: { error, entity in
            let finalError = NSError(domain: self.domain,
                                     code: DTPasskeysErrorCode.registerFinalizeRequestError.rawValue,
                                     userInfo: [NSLocalizedDescriptionKey: DTPasskeysErrorCode.registerFinalizeRequestError.localizedMessage])
            completionHandler(finalError)
            Logger.error("[Passkeys module] registerFinalize error: \(error.localizedDescription)")
        }
    }
    func getAuthenticationOptions(completionHandler: @escaping (CredentialAssertion) -> Void) {
    }
    
    @available(iOS 16.0, *)
    func sendAuthenticationResponse(params: ASAuthorizationPlatformPublicKeyCredentialAssertion, completionHandler: @escaping (DTAPIMetaEntity?, Error?) -> Void) {
        let response = [
            "authenticatorData": params.rawAuthenticatorData.toBase64Url(),
            "clientDataJson": params.rawClientDataJSON.toBase64Url(),
            "signature": params.signature.toBase64Url(),
            "userHandle": params.userID.toBase64Url()
        ]
        let parameters: [String : Any] = [
            "id": params.credentialID.toBase64Url(),
            "rawId": params.credentialID.toBase64Url(),
            "type": "public-key",
            "response": response,
            "supportTransfer": 1,
        ]
        
        self.loginFinalizeApi.loginFinalizeForPasskeys(parameters) { entity in
            guard let entity = entity else {return}
            completionHandler(entity,nil)
        } failure: { error, entity in
            var  error_t : Error?
            if let entity = entity {
                if( entity.status == 12001){
                    error_t = NSError(domain: self.domain,
                                        code: DTPasskeysErrorCode.passkeyAuthAcountError.rawValue ,
                                      userInfo: [NSLocalizedDescriptionKey:entity.reason])
                }else if (entity.status == 12002){
                    error_t = NSError(domain: self.domain,
                                        code: DTPasskeysErrorCode.passkeyAuthAcountRegistrationError.rawValue ,
                                      userInfo: [NSLocalizedDescriptionKey:entity.reason ])
                } else if( entity.status == 12003){
                    error_t = NSError.init(domain:entity.reason,
                                           code: DTPasskeysErrorCode.passkeyWithunauthorized.rawValue
                                           ,userInfo: [NSLocalizedDescriptionKey: Localized("SELECTED_ERROR_PASSKEY", comment:"")  ])
                } else {
                    error_t = error
                }
            } else {
                error_t = error
            }
            completionHandler(entity,error_t)
            Logger.error("[Passkeys module] error: \(error.localizedDescription)")
        }
    }
    
    @objc
    public func checkPasskeys(email: String?, phoneNumber: String?, sucess: @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil) {
        self.checkUserPasskeyApi.checkPasskeys(email: email, phoneNumber: phoneNumber, sucess: sucess, failure: failure )
    }
    
    @objc
    public func checkAccountExists(email: String?, phoneNumber: String?, sucess: @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil) {
        self.checkAccountExistsApi.checkAccountExists(email: email, phoneNumber: phoneNumber, sucess: sucess, failure: failure )
    }
    
    @objc
    public static func isUserCancelledError(_ error: Error?) -> Bool {
        guard let nsError = error as? NSError else { return false }
        return nsError.code == DTPasskeysErrorCode.userCancelledError.rawValue
    }

    @objc
    public static func localizedPasskeyErrorMessage(_ error: Error?) -> String {
        guard let nsError = error as? NSError else {
            return DTPasskeysErrorCode.unKnowError.localizedMessage
        }
        if let errorCode = DTPasskeysErrorCode(rawValue: nsError.code) {
            return errorCode.localizedMessage
        }
        return DTPasskeysErrorCode.unKnowError.localizedMessage
    }

    @objc
    public func isPasskeySupported() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let supportedTypes: [LAPolicy] = [.deviceOwnerAuthenticationWithBiometrics, .deviceOwnerAuthentication]
            let availableTypes = supportedTypes.filter { context.canEvaluatePolicy($0, error: nil) }

            if #available(iOS 16.0, *), availableTypes.contains(.deviceOwnerAuthentication), context.biometryType == .faceID {
                return true
            } else {
                return false
            }
        } else {
            if let error = error {
                Logger.error("无法评估设备验证策略：\(error.localizedDescription)")
            }
            return false
        }
    }
    
    func deviceSupportsPasskeyAuthentication() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let supportedTypes: [LAPolicy] = [.deviceOwnerAuthenticationWithBiometrics, .deviceOwnerAuthentication]
            let availableTypes = supportedTypes.filter { context.canEvaluatePolicy($0, error: nil) }

            if availableTypes.contains(.deviceOwnerAuthentication) {
                return true
            } else {
                return false
            }
        } else {
            if let error = error {
                Logger.error("无法评估设备验证策略：\(error.localizedDescription)")
            }
            return false
        }
    }
}

extension String {
    func decodeBase64Url() -> Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return Data(base64Encoded: base64)
    }
}

extension Data {
    func toBase64Url() -> String {
        return self.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

