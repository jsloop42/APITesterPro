//
//  PersistenceService.swift
//  APITesterPro
//
//  Created by Jaseem V V on 26/11/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

class PersistenceService {
    static var shared = PersistenceService()
    private lazy var db = { CoreDataService.shared }()
    
    // TODO: currently entity is directly deleted. With CloudKit sync, first mark it a deleted, save context and add it to cloudkit delete queue. And on cloudkit delete, delete from core data.
    
    /// Delete workspace
    func markEntityForDelete(_ ws: EWorkspace) {
        self.db.deleteEntity(ws)
        self.db.saveMainContext()
    }
    
    /// Delete environment
    func markEntityForDelete(_ env: EEnv) {
        self.db.deleteEntity(env)
        self.db.saveMainContext()
    }
    
    
    /// Delete environment variable
    func markEntityForDelete(_ envVar: EEnvVar) {
        self.db.deleteEntity(envVar)
        self.db.saveMainContext()
    }
    
    /// Delete project
    func markEntityForDelete(_ proj: EProject) {
        self.db.deleteEntity(proj)
        self.db.saveMainContext()
    }
    
    /// Delete request method data
    func markEntityForDelete(_ reqMethodData: ERequestMethodData) {
        self.db.deleteEntity(reqMethodData)
        self.db.saveMainContext()
    }
    
    /// Delete request
    func markEntityForDelete(_ req: ERequest) {
        self.db.deleteEntity(req)
        self.db.saveMainContext()
    }
    
    /// Delete request data
    func markEntityForDelete(_ reqData: ERequestData) {
        self.db.deleteEntity(reqData)
        self.db.saveMainContext()
    }
    
    func markEntityForDelete(_ reqBodyData: ERequestBodyData) {
        self.db.deleteEntity(reqBodyData)
        self.db.saveMainContext()
    }
    
    func markEntityForDelete(_ file: EFile) {
        self.db.deleteEntity(file)
        self.db.saveMainContext()
    }
    
    func markEntityForDelete(_ image: EImage) {
        self.db.deleteEntity(image)
        self.db.saveMainContext()
    }
    
    func markEntityForDelete(_ history: EHistory) {
        self.db.deleteEntity(history)
        self.db.saveMainContext()
    }
}
