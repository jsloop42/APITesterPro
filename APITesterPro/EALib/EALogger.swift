//
//  EALogger.swift
//  APITesterPro
//
//  Created by Jaseem V V on 03/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation

class Log {
    static func debug(_ msg: Any) {
        #if DEBUG
        print("[DEBUG] \(msg)")
        #endif
    }
    
    static func error(_ msg: Any) {
        print("[ERROR] \(msg)")
    }
    
    static func info(_ msg: Any) {
        print("[INFO] \(msg)")
    }
}
