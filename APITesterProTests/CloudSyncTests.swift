//
//  CloudSyncTest.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 31/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import XCTest
@testable import APITesterPro
import CloudKit
import CoreData

class CloudSyncTests: XCTestCase {
    private lazy var ckSvc = { CloudSyncService.shared }()
    private lazy var dbSvc = { PersistenceService.shared }()
    private lazy var db = { CoreDataService.shared }()
    var wsId1 = "ck-ws-1"
    var wsIdSchemaGen = "ck-ws-schema-gen"
    var isInitialized = false
    
    override func setUp() {
        super.setUp()
        Log.debug("cloud sync test init")
        self.ckSvc.bootstrap()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSaveWorkspace() {
        Log.debug("\(#function)")
    }
    
    func testCreateSchema() {
        Log.debug("\(#function)")
    }
}
