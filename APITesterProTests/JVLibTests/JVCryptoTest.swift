//
//  JVCryptoTest.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 25/11/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import XCTest
import Foundation
@testable import APITesterPro

class JVCryptoTests: XCTestCase {
    private let utils = JVUtils.shared
    
    /// This function can be used to generate a random AES key string
    func testGenRandomAES256Key() {
        let len = 32
        let key = self.utils.generateUniqueString(len)
        XCTAssertEqual(key.count, len)
        Log.info("key: \(key)")
        let data = key.data(using: .utf8)
        XCTAssertNotNil(data)
        let bytes = data!.toBytes()
        XCTAssertEqual(bytes.count, len)
        Log.info("key bytes: \(bytes)")
    }
    
    /// This function can be used to generate a random IV for AES 256. The IV is 16 bytes of AES CBC.
    func testGenRandomAES256IV() {
        let len = 16
        let iv = self.utils.generateUniqueString(len)
        XCTAssertEqual(iv.count, len)
        Log.info("iv: \(iv)")
        let data = iv.data(using: .utf8)
        XCTAssertNotNil(data)
        let bytes = data!.toBytes()
        XCTAssertEqual(bytes.count, len)
        Log.info("iv bytes: \(bytes)")
    }
    
    /// Test that the SecureTransformerInfo converts the key and iv bytes to string properly
    func testSecureTransformerInfo() {
        let key = self.utils.generateUniqueString(32)
        let keyBytes = key.data(using: .utf8)?.toBytes()
        XCTAssertNotNil(keyBytes)
        let iv = self.utils.generateUniqueString(16)
        let ivBytes = iv.data(using: .utf8)?.toBytes()
        XCTAssertNotNil(ivBytes)
        SecureTransformerInfo._key = keyBytes!
        SecureTransformerInfo._iv = ivBytes!
        let stiKey = SecureTransformerInfo.key
        XCTAssertEqual(stiKey, key)
        let stiIV = SecureTransformerInfo.iv
        XCTAssertEqual(stiIV, iv)
    }
    
    func testMD5Hash() {
        let str = "hello world"
        let hash = Hash.md5(txt: str)
        XCTAssertEqual(hash, "5eb63bbbe01eeed093cb22bb8f5acdc3")
        XCTAssertEqual(Hash.md5(txt: "api tester pro"), "4880382417348f9f442d17dcc45762c6")
    }
    
    /// Tests encryption and decryiption using key and iv defined in SecureTransformerInfo
    func testAESCBCEncryptionDecryption() {
        let txt = "api tester pro"
        XCTAssertEqual(SecureTransformerInfo._key.count, 32)  // 32 bytes
        XCTAssertEqual(SecureTransformerInfo._iv.count, 16)  // 16 bytes
        let encryptedData = SecureTransformerString().transformedValue(txt)
        XCTAssertNotNil(encryptedData)
        let decryptedData = SecureTransformerString().reverseTransformedValue(encryptedData)
        XCTAssertNotNil(decryptedData)
        XCTAssertEqual(decryptedData as! String, txt)
    }
}
