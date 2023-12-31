//
//  EAQueue.swift
//  APITesterPro
//
//  Created by Jaseem V V on 26/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

/// A queue implementation which dequeues based on time elapsed since enqueue.
public final class EAQueue<T> {
    private var queue: [T] = []
    private var timer: DispatchSourceTimer?  // timer
    private var interval: TimeInterval = 4.0  // seconds
    /// Block that will be executed passing in all the elements of the queue when the timer realizes
    public var completion: (([T]) -> Void)!
    private var accessq = EACommon.defaultQueue
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
    
    init(interval: TimeInterval, completion: @escaping ([T]) -> Void, queue: DispatchQueue) {
        self.interval = interval
        self.completion = completion
        self.accessq = queue
        self.initTimer()
    }
    
    init(interval: TimeInterval, completion: @escaping ([T]) -> Void) {
        self.interval = interval
        self.completion = completion
        self.initTimer()
    }
    
    init() {}
    
    public func setInterval(_ interval: TimeInterval) {
        self.interval = interval
    }
    
    public func setCompletion(_ completion: @escaping ([T]) -> Void) {
        self.completion = completion
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
            self.completion(self.queue)
            Log.debug("Queue processed \(self.queue.count) items")
            self.queue = []
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
    
    /// Removes the first element from the queue and returns it
    public func dequeue() -> T? {
        var x: T?
        self.accessq.sync { [unowned self] in
            if !self.queue.isEmpty {
                x = self.queue.removeFirst()
            }
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
