//
//  EAPopQueue.swift
//  APITesterPro
//
//  Created by Jaseem V V on 31/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation

/// A queue implementation which dequeues the last element after the set time interval until empty.
public final class EAPopQueue<T> {
    private var queue: [T] = []
    private var timer: DispatchSourceTimer?  // timer
    private var interval: TimeInterval = 2.0  // seconds
    /// The block that needs to be executed with the popped value
    public var block: (T?) -> Void
    private let accessq = EACommon.userInteractiveQueue
    /// Number of items in the queue
    public var count: Int {
        return self.queue.count
    }
    
    private var state: EATimerState = .suspended
    
    deinit {
        Log.debug("Queue deinit")
        self.timer?.cancel()
        self.timer?.resume()
        self.timer?.setEventHandler(handler: {})
        self.queue = []
    }
    
    init(interval: TimeInterval, block: @escaping (T?) -> Void) {
        self.interval = interval
        self.block = block
        self.initTimer()
    }
    
    private func initTimer() {
        self.timer = DispatchSource.makeTimerSource()
        self.timer?.schedule(deadline: .now() + self.interval, repeating: self.interval)
        self.timer?.setEventHandler(handler: { [weak self] in self?.eventHandler() })
    }
    
    private func eventHandler() {
        Log.debug("in timer queue len: \(self.queue.count)")
        // self.updateTimer()
        self.accessq.sync {
            self.block(self.dequeue())
            Log.debug("Queue processed. Remaining \(self.queue.count) items")
            self.updateTimer()
        }
    }
        
    public func updateTimer() {
        if !self.isEmpty() && self.state == .suspended {
            self.timer?.resume()
            self.state = .resumed
        } else if self.isEmpty() && self.state == .resumed {
            self.timer?.suspend()
            self.state = .suspended
        }
        Log.debug("Queue state \(self.state) - count: \(self.queue.count)")
    }
    
    /// Enqueues the given list in one operation.
    public func enqueue(_ xs: [T]) {
        self.accessq.sync {
            self.queue.append(contentsOf: xs); Log.debug("enqueued: \(xs)")
            self.updateTimer()
        }
    }
    
    /// Enqueues the given element.
    public func enqueue(_ x: T) {
        Log.debug("enqueue: \(x)")
        self.accessq.sync {
            self.queue.append(x);
            Log.debug("enqueued: \(x)")
            self.updateTimer()
        }
    }
    
    /// Removes the last element from the queue and returns it
    public func dequeue() -> T? {
        var x: T?
        self.accessq.sync {
            x = self.queue.popLast()
        }
        Log.debug("dequeued: \(String(describing: x))")
        return x
    }
    
    func isEmpty() -> Bool {
        return self.queue.isEmpty
    }
    
    func peek() -> T? {
        return self.queue.first
    }
}
