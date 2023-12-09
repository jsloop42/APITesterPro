//
//  JVQueueTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 26/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import XCTest
import Foundation
@testable import APITesterPro

// This test needs to be run individually. Enabling from test plan is causing failure.
class JVQueueTests: XCTestCase {
    private var timer: Timer?
    private let ck = JVCloudKit.shared
    private let opq = JVOperationQueue()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testQueue() {
        var count = 0
        var flag = 0
        let exp = expectation(description: "enqueue dequeue")
        let q = JVQueue<Int>(interval: 1.0) { xs in
            flag += 1
            if flag == 2 { exp.fulfill() }
        }
        self.timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            q.enqueue(count)
            count += 1
            if count >= 10 { self.timer?.invalidate() }
        }
        RunLoop.main.add(self.timer!, forMode: .common)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testOpQueue() {
        let exp = expectation(description: "test operation queue")
        let op = JVCloudOperation {op in
            op?.finish()
            exp.fulfill()
        }
        XCTAssertTrue(self.opq.add(op))
        waitForExpectations(timeout: 1.0, handler: nil)
    }
}
