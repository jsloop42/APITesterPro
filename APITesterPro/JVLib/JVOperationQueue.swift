//
//  JVOperationQueue.swift
//  APITesterPro
//
//  Created by Jaseem V V on 14/04/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

/// An operation queue class to work with operation objects with dynamic limits.
public final class JVOperationQueue {
    private var opqueue: OperationQueue!
    public var count: Int { opqueue.operationCount }
    
    public init() {
        self.opqueue = OperationQueue()
        self.opqueue.qualityOfService = .utility
        self.opqueue.maxConcurrentOperationCount = self.maxConcurrentOpCount()
    }
    
    public func add(_ op: Operation) -> Bool {
        if !self.canAdd() { return false }
        self.opqueue.maxConcurrentOperationCount = self.maxConcurrentOpCount()
        self.opqueue.addOperation(op)
        return true
    }
    
    public func canAdd() -> Bool {
        return self.opqueue.operationCount < self.opqueue.maxConcurrentOperationCount
    }
    
    public func maxConcurrentOpCount() -> Int {
        let used: Double = (JVSystem.memoryFootprint() ?? 0.0).toDouble()
        let total: Double = JVSystem.totalMemory().toDouble()
        let avail: Double =  used / total
        if avail >= 0.5 { return 128 }
        if avail >= 0.25 { return 32 }
        return 16
    }
}