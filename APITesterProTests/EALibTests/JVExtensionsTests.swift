//
//  JVExtensionsTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 09/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import XCTest
import Foundation
@testable import APITesterPro

class JVExtensionsTests: XCTestCase {
    func testDateConversion() {
        let date = Date()
        let localDateStr = date.toLocalDateStr()
        Log.debug(localDateStr)
    }
}
