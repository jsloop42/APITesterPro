//
//  EAPopQueueTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 31/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import XCTest
@testable import APITesterPro

final class EAPopQueueTests: XCTestCase {
    func testPopQueue() {
        let exp = expectation(description: "dequeue every second until empty")
        let xs = [1,2,3,4]
        var acc: [Int] = []
        let popQueue = EAPopQueue<Int>(interval: 1) { elem in
            Log.debug("popqueue block")
            acc.append(elem!)
            if xs.count == acc.count {
                XCTAssertEqual(xs, acc)
                exp.fulfill()
            }
        }
        popQueue.enqueue(xs)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testPopQueueTimerRestart() {
        let exp = expectation(description: "dequeue every second until empty, enqueue and ensure that the timer resumes")
        let xs = [1,2]
        var acc: [Int] = []
        let popQueue = EAPopQueue<Int>()
        popQueue.setInterval(1)
        popQueue.setBlock { elem in
            Log.debug("popqueue block")
            acc.append(elem!)
            if xs.count == acc.count {  // at this stage the timer will be suspended
                XCTAssertEqual(xs, acc)
                popQueue.enqueue(3)  // add one more element to check if timer will resume
            } else if xs.count < acc.count {  // timer resumed
                XCTAssert(acc.last == 3)
                exp.fulfill()
            }
        }
        popQueue.startTimer()
        popQueue.enqueue(xs)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
}
