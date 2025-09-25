//
//  DTPasskeyForLoginFinalize.swift
//  TTServiceKit
//
//  Created by hornet on 2023/7/20.
//

import Foundation


class CredentialCreation : Codable {
    var publicKey: CredentialCreationPublicKey
}

class CredentialCreationPublicKey : Codable {
    var challenge: String
    var user: CredentialCreationUser
    var attestation: String?
    var authenticatorSelection: CredentialCreationAuthenticatorSelection?
}

class CredentialCreationUser : Codable {
    var id: String
    var name: String
    var displayName: String
}

class CredentialCreationAuthenticatorSelection : Codable {
    var userVerification: String?
}

class CredentialAssertion : Codable {
    var publicKey: CredentialAssertionPublicKey
}

class CredentialAssertionPublicKey : Codable {
    var challenge: String
    var userVerification: String?
}
