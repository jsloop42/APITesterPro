//
//  CloudSyncService.swift
//  APITesterPro
//
//  Created by Jaseem V V on 30/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

class CloudSyncService {
    static var shared = CloudSyncService()
    private lazy var ck = { EACloudKit.shared }()
    
    init() {
        Log.debug("cloudsync init")
    }
    
    deinit {
        Log.debug("cloudsync deinit")
    }
    
    /// This method should be called during app launch once so that cloudkit gets initialized.
    func bootstrap() {
        Log.debug("cloudsync bootstrap")
        self.ck.bootstrap(containerId: Const.cloudKitContainerID)
    }
    
    func saveWorkspace(_ ws: EWorkspace) {
        Log.debug("ck save workspace \(ws.getId())")
    }
}
