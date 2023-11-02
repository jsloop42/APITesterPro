//
//  EACommon.swift
//  API Tester Pro
//
//  Created by Jaseem V V on 02/04/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation

public struct EACommon {
    static var userInteractiveQueue = DispatchQueue(label: "net.jsloop.api-tester-pro.user-interactive", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var userInitiatedQueue = DispatchQueue(label: "net.jsloop.api-tester-pro.ios.user-initiated", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var defaultQueue = DispatchQueue(label: "net.jsloop.api-tester-pro.default", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var utilityQueue = DispatchQueue(label: "net.jsloop.api-tester-pro.utility", qos: .utility, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    static var backgroundQueue = DispatchQueue(label: "net.jsloop.api-tester-pro.background", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
}

public enum EATimerState {
    case undefined
    case suspended
    case resumed
    case terminated
}
