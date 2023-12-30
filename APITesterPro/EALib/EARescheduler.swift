//
//  EARescheduler.swift
//  APITesterPro
//
//  Created by Jaseem V V on 13/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

public enum EAReschedulerType {
    /// All functions should produce a truthy value. If any function returns false, the evaluation short circuits.
    case allSatisfies
    /// At least one function should produce a truthy value.
    case anySatisfies
    /// Executes all functions regardless of their return value.
    case everyFn
}

public protocol EAReschedulable: AnyObject {
    var interval: TimeInterval { get set }
    var type: EAReschedulerType! { get set }
    
    init(interval: TimeInterval, type: EAReschedulerType)
    func schedule()
    func schedule(fn: EAReschedulerFn)
}

public struct EAReschedulerFn: Equatable, Hashable {
    /// The block identifier
    var id: String
    /// The block which needs to be executed returning a status which is passed to the callback function
    var block: () -> Bool
    /// The callback function after executing the block
    var callback: (Bool) -> Void
    var args: [AnyHashable] = []
    
    init(id: String, block: @escaping () -> Bool, callback: @escaping (Bool) -> Void, args: [AnyHashable]) {
        self.id = id
        self.block = block
        self.callback = callback
        self.args = args
    }
    
    public static func == (lhs: EAReschedulerFn, rhs: EAReschedulerFn) -> Bool {
        lhs.id == rhs.id && lhs.args == rhs.args
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id.hashValue)
    }
}

/// A class which provides a scheduler which gets rescheduled if invoked before the schedule.
public final class EARescheduler: EAReschedulable {
    public typealias EAEquatable = String
    private var timer: DispatchSourceTimer!
    public var interval: TimeInterval = 0.3  // seconds
    public var type: EAReschedulerType!
    private var blocks: [EAReschedulerFn] = []
    private let queue = EACommon.userInteractiveQueue
    private let dispatchGroup = DispatchGroup()
    private var isLimitEnabled = false
    private var counter = 0

    private var state: EATimerState = .suspended
    
    deinit {
        Log.debug("Rescheduler deinit")
        self.done()
    }
    
    public required init(interval: TimeInterval, type: EAReschedulerType) {
        self.interval = interval
        self.type = type
    }
    
    private func initTimer() {
        Log.debug("Rescheduler: init timer")
        if self.timer != nil { self.destroy() }
        self.timer = DispatchSource.makeTimerSource()
        self.timer.schedule(deadline: .now() + self.interval)
        self.timer.setEventHandler(handler: { [weak self] in self?.eventHandler() })
        self.timer.resume()
        self.state = .resumed
    }
    
    private func destroy() {
        Log.debug("Rescheduler: destroy")
        if self.timer != nil {
            self.timer.setEventHandler {}
            if self.state == .resumed {
                self.timer.cancel()
            }
            self.timer = nil
        }
        self.state = .terminated
    }
    
    /// Clears all data that this class holds and releases resources
    public func done() {
        Log.debug("Rescheduler: done")
        self.destroy()
        self.blocks = []
    }
    
    /// Event handler function which will be invoked when timer is realized. It takes an optional completion handler which will be invoked when all functions in the block are executed. Since the functions are executed in an async queue we use completion handler.
    func eventHandler(_ completion: (() -> Void)? = nil) {
        Log.debug("Rescheduler: event handler \(self.state)")
        if self.state == .resumed && self.type == EAReschedulerType.everyFn {  // Invoke the callback function with the result of each block execution
            self.queue.async(group: self.dispatchGroup) { [weak self] in
                self?.blocks.forEach { fn in fn.callback(fn.block()) }  // The block is invoked when the timer completes
            }
            self.dispatchGroup.notify(queue: DispatchQueue.main) {
                Log.debug("Rescheduler: all tasks complete")
                self.done()  // release objects
                completion?()
            }
        }
    }
    
    public func schedule() {
        Log.debug("Rescheduler: schedule")
        self.initTimer()
        self.counter += 1
    }
    
    /// Used to set a function to be executed when the timer is realized.
    public func schedule(fn: EAReschedulerFn) {
        Log.debug("Rescheduler: schedule fn")
        self.addToBlock(fn)
        self.schedule()
    }
    
    /// Adds the given function to the block of functions to be executed when timer realizes. If the function is already present, it's replaced.
    private func addToBlock(_ fn: EAReschedulerFn) {
        Log.debug("Rescheduler: add to block")
        if let idx = (self.blocks.firstIndex { afn -> Bool in afn.id == fn.id }) {
            self.blocks[idx] = fn
        } else {
            self.blocks.append(fn)
        }
    }
}
