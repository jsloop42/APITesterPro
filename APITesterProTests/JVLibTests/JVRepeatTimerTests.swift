//
//  JVRetryTimerTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 17/04/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import XCTest
@testable import APITesterPro

class JVRepeatTimerTests: XCTestCase {
    var timer: JVRepeatTimer!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testRepeatTimer() {
        let exp = expectation(description: "repeat timer execution")
        var c = 0
        var done = false
        self.timer = JVRepeatTimer(block: {
            c += 1
        }, interval: 1.0, limit: 5)
        self.timer.done = {
            XCTAssertEqual(c, 5)
            if !done { done = true; exp.fulfill() }
        }
        self.timer.resume()
        waitForExpectations(timeout: 10, handler: nil)
    }
}