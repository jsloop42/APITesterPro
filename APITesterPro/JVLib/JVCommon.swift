//
//  JVCommon.swift
//  APITesterPro
//
//  Created by Jaseem V V on 02/04/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

public struct JVCommon {
    static var userInteractiveQueue = DispatchQueue(label: "net.jsloop.APITesterPro.UserInteractive", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var userInitiatedQueue = DispatchQueue(label: "net.jsloop.APITesterPro.UserInitiated", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var defaultQueue = DispatchQueue(label: "net.jsloop.APITesterPro.Default", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var utilityQueue = DispatchQueue(label: "net.jsloop.APITesterPro.Utility", qos: .utility, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var backgroundQueue = DispatchQueue(label: "net.jsloop.APITesterPro.Background", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
}

public enum JVTimerState {
    case undefined
    case suspended
    case resumed
    case terminated
}
