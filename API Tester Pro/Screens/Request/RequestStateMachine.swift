 //
//  RequestStateMachine.swift
//  API Tester Pro
//
//  Created by Jaseem V V on 16/05/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import GameplayKit
 
 class RequestStateMachine: GKStateMachine {
    unowned var request: ERequest
    weak var manager: RequestManager?
    
    init(states: [GKState], request: ERequest, manager: RequestManager? = nil) {
        self.request = request
        self.manager = manager
        super.init(states: states)
    }
 }
