//
//  SecureTransformer.swift
//  APITesterPro
//
//  Created by Jaseem V V on 15/06/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

public struct SecureTransformerInfo {
    private static let utils = { JVUtils.shared }()
    // 32 bytes
    static var _key: [UInt8] = [102, 50, 54, 115, 49, 76, 67, 48, 100, 105, 89, 80, 71, 56, 118, 108, 99, 51, 83, 86, 110, 109, 88, 79, 103, 84, 77, 101, 55, 104, 52, 122]
    // 16 bytes
    static var _iv: [UInt8] = [101, 88, 56, 76, 102, 87, 49, 77, 115, 79, 78, 80, 108, 86, 112, 114]
    
    static var key: String {
        if let str = String(data: Data(_key), encoding: .utf8) { return str }
        return ""
    }
    static var iv: String {
        if let str = String(data: Data(_iv), encoding: .utf8) { return str }
        return ""
    }
}

/// A class that can be used for encrypting and decrypting core data `String` values on the fly.
@objc(SecureTransformerString)
public class SecureTransformerString: NSSecureUnarchiveFromDataTransformer {
    private let aes = try? AESCBC(key: SecureTransformerInfo.key, iv: SecureTransformerInfo.iv)
    
    public override class var allowedTopLevelClasses: [AnyClass] {
        return [NSString.self]
    }
    
    public override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }
    
    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    static let name = NSValueTransformerName(rawValue: String(describing: SecureTransformerString.self))
    
    public static func register() {
        // There is a bug in momc which prints the below, but can be ignored. Value gets saved to the DB.
        // CoreData: warning: no NSValueTransformer with class name 'APITesterPro.SecureTransformerString.name' was found for attribute 'value' on entity 'EEnvVar'
        let transformer = SecureTransformerString()
        ValueTransformer.setValueTransformer(transformer, forName: self.name)
    }

    /// Encrypt the value.
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let text = value as? String else { return nil }
        return self.aes?.encrypt(string: text)
    }

    /// Decrypt the value.
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        if let res = self.aes?.decrypt(data: data) {
            return String(data: res, encoding: .utf8)
        }
        return nil
    }
}

/// A class that can be used for encrypting and decrypting core data `Data` values on the fly.
@objc(SecureTransformerData)
public class SecureTransformerData: NSSecureUnarchiveFromDataTransformer {
    private let aes = try? AESCBC(key: SecureTransformerInfo.key, iv: SecureTransformerInfo.iv)
    
    public override class var allowedTopLevelClasses: [AnyClass] {
        return [NSData.self]
    }
    
    public override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    public override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    static let name = NSValueTransformerName(rawValue: String(describing: SecureTransformerData.self))
    
    public static func register() {
        let transformer = SecureTransformerData()
        ValueTransformer.setValueTransformer(transformer, forName: self.name)
    }

    /// Decrypt the value.
    /// - Parameter value: A data value
    /// - Returns: Encrypted binary data
    public override func transformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return self.aes?.encrypt(data: data)
    }

    /// Decrypt the value.
    /// - Parameter value: A transformed data value
    /// - Returns: Decrypted binary data
    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return self.aes?.decrypt(data: data)  // returns Data
    }
}
