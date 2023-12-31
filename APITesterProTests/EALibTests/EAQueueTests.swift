//
//  EAQueueTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 26/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import XCTest
import Foundation
@testable import APITesterPro

// This test needs to be run individually. Enabling from test plan is causing failure.
class EAQueueTests: XCTestCase {
    func testQueue() {
        var timer: Timer?
        var count = 0
        let exp = expectation(description: "enqueue dequeue")
        let q = EAQueue<Int>(interval: 3.0) { xs in  // execute this block after 5 seconds
            Log.debug("in queue completion handler")
            if xs.count == count { exp.fulfill() }
        }
        timer = Timer(timeInterval: 0.2, repeats: true) { _ in  // add elements to the queue with a delay
            q.enqueue(count)
            count += 1
            if count == 4 { timer?.invalidate() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        waitForExpectations(timeout: 5.0, handler: nil)
    }
}
