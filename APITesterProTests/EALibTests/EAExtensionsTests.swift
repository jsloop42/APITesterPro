//
//  EAExtensionsTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 09/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import XCTest
import Foundation
@testable import APITesterPro

class EAExtensionsTests: XCTestCase {
    func testDateConversion() {
        let date = Date()  // date in UTC
        let localStr = date.toLocalDateStr()  // convert to local date string
        Log.debug(localStr)
        let d1 = Date.toDate(localStr)  // convert to local date
        let localStr1 = d1.toLocalDateStr()  // convert to local date string
        XCTAssertEqual(localStr1, localStr)
    }
    
    func testDateToTimeZoneConversion() {
        let d = "2023-12-09 00:00:00 +0000"
        let localDate = Date.toDate(d)
        let localStr = localDate.toLocalDateStr()
        Log.debug(localStr)
        XCTAssertEqual(localStr, "2023-12-09 05:30:00 +0530")
    }
}
