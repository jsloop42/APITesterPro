//
//  JVCrypto.swift
//  APITesterPro
//
//  Created by Jaseem V V on 16/05/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CryptoKit
import CommonCrypto

// MARK: - PKCS12

public final class PKCS12 {
    var label: String?
    var keyID: Data?
    var trust: SecTrust?
    var certChain: [SecTrust]?
    var identity: SecIdentity?
    
    public init(data: Data, password: String) {
        let opts: NSDictionary = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let status: OSStatus = SecPKCS12Import(data as CFData, opts, &items)
        guard status == errSecSuccess else {
            if status == errSecAuthFailed { Log.error("Authentication failed.") }
            return
        }
        guard let itemsCFArr = items else { return }
        let itemsNSArr: NSArray = itemsCFArr as NSArray
        guard let hmxs = itemsNSArr as? [[String: AnyObject]] else { return }
           
        func f<T>(_ k: CFString) -> T? {
            for hm in hmxs {
                if let v = hm[k as String] as? T { return v }
            }
            return nil
        }

        self.label = f(kSecImportItemLabel)
        self.keyID = f(kSecImportItemKeyID)
        self.trust = f(kSecImportItemTrust)
        self.certChain = f(kSecImportItemCertChain)
        self.identity = f(kSecImportItemIdentity)
    }
}

extension URLCredential {
    convenience init?(pkcs12: PKCS12) {
        if let identity = pkcs12.identity {
            self.init(identity: identity, certificates: pkcs12.certChain, persistence: .none)
        } else { return nil }
    }
}

// MARK: - AES GCM

/// Encrypt/decrypt using AES GCM (Galois Counter Mode). Encrypted data is accompanied with an authentication tag data which is required for decryption and verification.
public struct AESGCM {
    /// A 32 bytes (256 bits) string data for AES-256. Key size must be any of 128, 192 or 256 bits.
    private let key: Data
    /// A 12 bytes string data used as nonce
    private let nonce: Data
    /// Authentication data used for data verification
    private let tag: Data
    /// Optional additional meta data that will be added to the tag which will be used for verification
    private let meta: Data?
    private let symKey: SymmetricKey
    
    /// Initialize with encryption key, nonce (initialization vector) and verification data
    init(key: Data, nonce: Data, tag: Data) throws {
        self.key = key
        self.nonce = nonce
        self.tag = tag
        self.symKey = SymmetricKey(data: self.nonce)
        self.meta = nil
        try self.validateFields()
    }
    
    /// Initialize with encryption key, nonce (initialization vector),  verification data and adiitional metadata used for verification
    init(key: Data, nonce: Data, tag: Data, meta: Data) throws {
        self.key = key
        self.nonce = nonce
        self.tag = tag
        self.symKey = SymmetricKey(data: self.nonce)
        self.meta = meta
        try self.validateFields()
    }
    
    func validateFields() throws {
        try self.validateKeySize()
        try self.validateNonceSize()
    }
    
    func validateKeySize() throws {
        let bitCount = self.symKey.bitCount
        if bitCount != SymmetricKeySize.bits128.bitCount || bitCount != SymmetricKeySize.bits192.bitCount || bitCount != SymmetricKeySize.bits256.bitCount {
            throw "Invalid key size"
        }
    }
    
    func validateNonceSize() throws {
        if nonce.count != 12 {
            throw "Nonce size must be 12 bytes"
        }
    }
    
    /// Encrpt the given string. If meta is set this data will also be added to the tag
    func encrypt(string: String) throws -> (cipher: Data, tag: Data)? {
        guard let data = string.data(using: .utf8) else { return nil }
        let sealedBox: AES.GCM.SealedBox
        if let meta = self.meta {
            sealedBox = try AES.GCM.seal(data, using: symKey, nonce: AES.GCM.Nonce(data: self.nonce), authenticating: meta)
        } else {
            sealedBox = try AES.GCM.seal(data, using: symKey, nonce: AES.GCM.Nonce(data: self.nonce))
        }
        return (cipher: sealedBox.ciphertext, tag: sealedBox.tag)
    }
    
    /// Decrypt the given data using the parameters set. If meta is set additional verification on that is also performed.
    func decrypt(data: Data?) throws -> Data? {
        guard let data = data else { return nil }
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: self.nonce), ciphertext: data, tag: self.tag)
        let decryptedData: Data?
        if let meta = self.meta {
            decryptedData = try AES.GCM.open(sealedBox, using: self.symKey, authenticating: meta)
        } else {
            decryptedData = try AES.GCM.open(sealedBox, using: self.symKey)
        }
        return decryptedData
    }
}

// MARK: - AES CBC (Cipher Block Chaining)

public struct AESCBC {
    /// A 32 bytes string data for AES256.
    private let key: Data
    /// A 16 bytes string data.
    private let iv: Data

    init?(key: String, iv: String) throws {
        guard key.count == kCCKeySizeAES128 || key.count == kCCKeySizeAES256, let keyData = key.data(using: .utf8) else {
            Log.error("Error setting key")
            throw "Invalid key size"
        }
        guard iv.count == kCCBlockSizeAES128, let ivData = iv.data(using: .utf8) else {
            Log.error("Error setting initialisation vector")
            throw "Invalid IV size"
        }
        self.key = keyData
        self.iv = ivData
    }

    /// Encrypt the given string.
    public func encrypt(string: String) -> Data? {
        return crypt(data: string.data(using: .utf8), option: CCOperation(kCCEncrypt))
    }
    
    public func encrypt(data: Data) -> Data? {
        return crypt(data: data, option: CCOperation(kCCEncrypt))
    }

    /// Decrypt the given data.
    public func decrypt(data: Data?) -> Data? {
        return crypt(data: data, option: CCOperation(kCCDecrypt))
    }

    private func crypt(data: Data?, option: CCOperation) -> Data? {
        guard let data = data else { return nil }
        let cryptLen = data.count + kCCBlockSizeAES128
        var cryptData = Data(count: cryptLen)
        let keyLen = key.count
        let options = CCOptions(kCCOptionPKCS7Padding)
        var bytesLen = Int(0)
        let status = cryptData.withUnsafeMutableBytes { cryptBytes in
            data.withUnsafeBytes { dataBytes in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        CCCrypt(option, CCAlgorithm(kCCAlgorithmAES), options, keyBytes.baseAddress, keyLen, ivBytes.baseAddress, dataBytes.baseAddress,
                                data.count, cryptBytes.baseAddress, cryptLen, &bytesLen)
                    }
                }
            }
        }
        guard UInt32(status) == UInt32(kCCSuccess) else {
            Log.error("Error in encrypt/decrypt data. Status \(status)")
            return nil
        }
        cryptData.removeSubrange(bytesLen..<cryptData.count)
        return cryptData
    }
}

public struct Hash {
    /// Generate MD5 hash of the given string
    static func md5(txt: String) -> String {
        guard let data = txt.data(using: .utf8) else { return "" }
        return self.md5(data: data)
    }
    
    /// Generate MD5 hash of the given data
    static func md5(data: Data) -> String {
        return Insecure.MD5.hash(data: data).toHex()
    }
}

// MARK: - TLS

/// An enum reflecting the tsl_cuphersuite_t enum from Security module.
public enum JVTLSCipherSuite: Int {
    case rsa_with_3des_ede_cbc_sha = 10
    case rsa_with_aes128_cbc_sha = 47
    case rsa_with_aes256_cbc_sha = 53
    case rsa_with_aes128_gcm_sha256 = 156
    case rsa_with_aes256_gcm_sha384 = 157
    case rsa_with_aes128_cbc_sha256 = 60
    case rsa_with_aes256_cbc_sha256 = 61
    case ecdhe_ecdsa_with_3des_ede_cbc_sha = 49160
    case ecdhe_ecdsa_with_aes128_cbc_sha = 49161
    case ecdhe_ecdsa_with_aes256_cbc_sha = 49162
    case ecdhe_rsa_with_3des_ede_cbc_sha = 49170
    case ecdhe_rsa_with_aes128_cbc_sha = 49171
    case ecdhe_rsa_with_aes256_cbc_sha = 49172
    case ecdhe_ecdsa_with_aes128_cbc_sha256 = 49187
    case ecdhe_ecdsa_with_aes256_cbc_sha384 = 49188
    case ecdhe_rsa_with_aes128_cbc_sha256 = 49191
    case ecdhe_rsa_with_aes256_cbc_sha384 = 49192
    case ecdhe_ecdsa_with_aes128_gcm_sha256 = 49195
    case ecdhe_ecdsa_with_aes256_gcm_sha384 = 49196
    case ecdhe_rsa_with_aes128_gcm_sha256 = 49199
    case ecdhe_rsa_with_aes256_gcm_sha384 = 49200
    case ecdhe_rsa_with_chacha20_poly1305_sha256 = 52392
    case ecdhe_ecdsa_with_chacha20_poly1305_sha256 = 52393
    case aes128_gcm_sha256 = 4865
    case aes256_gcm_sha384 = 4866
    case chacha20_poly1305_sha256 = 4867
    
    public init?(_ t: UInt16) {
        self.init(rawValue: Int(t))
    }
    
    func toString() -> String {
        switch self {
        case .aes128_gcm_sha256: return "AES128 GCM SHA256"
        case .aes256_gcm_sha384: return "AES256 GCM SHA384"
        case .chacha20_poly1305_sha256: return "ChaCha20 Poly1305 SHA256"
        case .ecdhe_ecdsa_with_3des_ede_cbc_sha: return "ECDHE-ECDSA with 3DES EDE CBC SHA"
        case .ecdhe_ecdsa_with_aes128_cbc_sha: return "ECDHE-ECDSA with AES128 CBC SHA"
        case .ecdhe_ecdsa_with_aes256_cbc_sha: return "ECDHE-ECDSA with AES256 CBC SHA"
        case .ecdhe_ecdsa_with_aes128_cbc_sha256: return "ECDHE-ECDSA with AES128 CBC SHA256"
        case .ecdhe_ecdsa_with_aes256_cbc_sha384: return "ECDHE-ECDSA with AES256 CBC SHA384"
        case .ecdhe_rsa_with_3des_ede_cbc_sha: return "ECDHE RSA with 3DES EDE CBC SHA"
        case .ecdhe_rsa_with_aes128_cbc_sha: return "ECDHE RSA with AES128 CBC SHA"
        case .ecdhe_rsa_with_aes256_cbc_sha: return "ECDHE RSA with AES256 CBC SHA"
        case .ecdhe_rsa_with_aes128_cbc_sha256: return "ECDHE RSA with AES128 CBC SHA256"
        case .ecdhe_rsa_with_aes256_cbc_sha384: return "ECDHE RSA with AES256 CBC SHA384"
        case .ecdhe_ecdsa_with_aes128_gcm_sha256: return "ECDHE-ECDSA with AES128 GCM SHA256"
        case .ecdhe_ecdsa_with_aes256_gcm_sha384: return "ECDHE-ECDSA with AES256 GCM SHA384"
        case .ecdhe_rsa_with_aes128_gcm_sha256: return "ECDHE RSA with AES128 GCM SHA256"
        case .ecdhe_rsa_with_aes256_gcm_sha384: return "ECDHE RSA with AES256 GCM SHA384"
        case .ecdhe_rsa_with_chacha20_poly1305_sha256: return "ECDHE RSA with ChaCha20 Poly1305 SHA256"
        case .ecdhe_ecdsa_with_chacha20_poly1305_sha256: return "ECDHE-ECDSA with ChaCha20 Poly1305 SHA256"
        case .rsa_with_3des_ede_cbc_sha: return "RSA with 3DES EDE CBC SHA"
        case .rsa_with_aes128_cbc_sha: return "RSA with AES128 CBC SHA"
        case .rsa_with_aes256_cbc_sha: return "RSA with AES256 CBC SHA"
        case .rsa_with_aes128_gcm_sha256: return "RSA with AES128 GCM SHA256"
        case .rsa_with_aes256_gcm_sha384: return "RSA with AES256 GCM SHA384"
        case .rsa_with_aes128_cbc_sha256: return "RSA with AES128 CBC SHA256"
        case .rsa_with_aes256_cbc_sha256: return "RSA with AES256 CBC SHA256"
        }
    }
}

/// An enum reflecting the tls_protocol_version_t enum from Security module.
public enum JVTLSProtocolVersion: Int {
    case tls10 = 769
    case tls11 = 770
    case tls12 = 771
    case tls13 = 772
    case dtls10 = 65279
    case dtls12 = 65277
    
    public init?(_ t: UInt16) {
        self.init(rawValue: Int(t))
    }
    
    func toString() -> String {
        switch self {
        case .tls10: return "TLS v1.0"
        case .tls11: return "TLS v1.1"
        case .tls12: return "TLS v1.2"
        case .tls13: return "TLS v1.3"
        case .dtls10: return "DTLS v1.0"
        case .dtls12: return "DTLS v1.2"
        }
    }
}
