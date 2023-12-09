//
//  BackgroundWorker.swift
//  APITesterPro
//
//  Created by Jaseem V V on 10/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

public class BackgroundWorker: NSObject {
    private var thread: Thread!
    private var block: (() -> Void)!
    private let utils = JVUtils.shared
    
    @objc func runBlock() { self.block() }
    
    public func start(_ block: @escaping () -> Void) {
        self.block = block
        let threadName = String(describing: self).components(separatedBy: .punctuationCharacters)[1]
        self.thread = Thread { [weak self] in
            while self != nil && !self!.thread!.isCancelled {
                RunLoop.current.run(mode: .default, before: Date.distantFuture)
            }
            Thread.exit()
        }
        self.thread.name = "\(threadName)-\(self.utils.genRandomString())"
        Log.debug("Background worker thread name: \(self.thread.name ?? "")")
        self.thread.start()
        self.perform(#selector(self.runBlock), on: self.thread, with: nil, waitUntilDone: false, modes: [(CFRunLoopMode.defaultMode.rawValue as String)])
    }
    
    public func stop() {
        self.thread.cancel()
    }
}
