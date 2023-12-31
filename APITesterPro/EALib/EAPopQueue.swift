//
//  EAPopQueue.swift
//  APITesterPro
//
//  Created by Jaseem V V on 31/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation

/// A queue implementation which dequeues the first element after the set time interval until empty.
public final class EAPopQueue<T> {
    private var queue: [T] = []
    private var timer: DispatchSourceTimer?  // timer
    private var interval: TimeInterval = 2.0  // seconds
    /// The block that needs to be executed with the popped value when timer realizes
    public var block: ((T?) -> Void)!
    private var accessq = EACommon.defaultQueue
    /// Number of items in the queue
    public var count: Int {
        return self.queue.count
    }
    
    private var state: EATimerState = .suspended
    
    deinit {
        Log.debug("popqueue deinit")
        self.timer?.cancel()
        self.timer?.resume()
        self.timer?.setEventHandler(handler: {})
        self.queue = []
    }
    
    init(interval: TimeInterval, block: @escaping (T?) -> Void, queue: DispatchQueue) {
        self.interval = interval
        self.block = block
        self.accessq = queue
        self.initTimer()
    }
    
    init(interval: TimeInterval, block: @escaping (T?) -> Void) {
        self.interval = interval
        self.block = block
        self.initTimer()
    }
    
    init() {}
    
    public func setInterval(_ interval: TimeInterval) {
        self.interval = interval
    }
    
    public func setBlock(_ block: @escaping (T?) -> Void) {
        self.block = block
    }
    
    /// Set the dispatch queue against which the timer will run and the list gets processed
    public func setQueue(_ queue: DispatchQueue) {
        self.accessq = queue
    }
    
    /// If not using the initializer set interval and block manually and call this to start the timer.
    public func startTimer() {
        self.initTimer()
    }
    
    private func initTimer() {
        if self.timer == nil {
            self.timer = DispatchSource.makeTimerSource(queue: self.accessq)
            self.timer?.schedule(deadline: .now() + self.interval, repeating: self.interval)
            self.timer?.setEventHandler(handler: { [weak self] in self?.eventHandler() })
        }
    }
    
    private func eventHandler() {
        Log.debug("in timer queue len: \(self.queue.count)")
        self.accessq.sync { [unowned self] in
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
        Log.debug("queue state \(self.state) - count: \(self.queue.count)")
    }
    
    /// Enqueues the given list in one operation.
    public func enqueue(_ xs: [T]) {
        self.accessq.sync { [unowned self] in
            self.queue.append(contentsOf: xs); Log.debug("enqueued: \(xs)")
            self.updateTimer()
        }
    }
    
    /// Enqueues the given element.
    public func enqueue(_ x: T) {
        Log.debug("enqueue: \(x)")
        self.accessq.sync { [unowned self] in
            self.queue.append(x);
            Log.debug("enqueued: \(x)")
            self.updateTimer()
        }
    }
    
    /// Removes the last element from the queue and returns it
    public func dequeue() -> T? {
        var x: T?
        self.accessq.sync { [unowned self] in
            x = self.queue.removeFirst()
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
