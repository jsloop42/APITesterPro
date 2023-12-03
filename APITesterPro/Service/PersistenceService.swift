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
    
    // MARK: - Delete entities
    
    // These methods are called when delete operation is performed from the listing screens
    // TODO: currently entity is directly deleted. With CloudKit sync, first mark it a deleted, save context and add it to cloudkit delete queue. And on cloudkit delete, delete from core data.
    
    /// Delete workspace
    func deleteEntity(ws: EWorkspace) {
        self.db.deleteEntity(ws)
        self.db.saveMainContext()
    }
    
    /// Delete environment
    func deleteEntity(env: EEnv) {
        self.db.deleteEntity(env)
        self.db.saveMainContext()
    }
    
    /// Delete environment variable
    func deleteEntity(envVar: EEnvVar) {
        self.db.deleteEntity(envVar)
        self.db.saveMainContext()
    }
    
    /// Delete project
    func deleteEntity(proj: EProject) {
        self.db.deleteEntity(proj)
        self.db.saveMainContext()
    }
    
    /// Delete request method data
    func deleteEntity(reqMethodData: ERequestMethodData) {
        self.db.deleteEntity(reqMethodData)
        self.db.saveMainContext()
    }
    
    /// Delete request
    func deleteEntity(req: ERequest) {
        self.db.deleteEntity(req)
        self.db.saveMainContext()
    }
    
    /// Delete request data - header, params, forms
    func deleteEntity(reqData: ERequestData) {
        self.db.deleteEntity(reqData)
        self.db.saveMainContext()
    }
    
    /// Delete request body
    func deleteEntity(reqBodyData: ERequestBodyData) {
        self.db.deleteEntity(reqBodyData)
        self.db.saveMainContext()
    }
    
    /// Delete file
    func deleteEntity(file: EFile) {
        self.db.deleteEntity(file)
        self.db.saveMainContext()
    }
    
    /// Delete image
    func deleteEntity(image: EImage) {
        self.db.deleteEntity(image)
        self.db.saveMainContext()
    }
    
    ///Delete history
    func deleteEntity(history: EHistory) {
        self.db.deleteEntity(history)
        self.db.saveMainContext()
    }
    
    // MARK: - Mark data for delete in editing request
    
    // These methods are used when entites are deleted when editing a request. These shouldn't persist until the background context is saved. On save the stale entites needs to be deleted manually.
    
    /// Mark request data for deletion - header, params, forms
    func markEntityForDelete(reqData: ERequestData, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (reqData.managedObjectContext != nil ? reqData.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            if let xs = reqData.files?.allObjects as? [EFile] {
                xs.forEach { file in self.markEntityForDelete(file: file, ctx: ctx) }
            }
            if let img = reqData.image { self.markEntityForDelete(image: img, ctx: ctx) }
            //self.localdb.markEntityForDelete(reqData, ctx: ctx)
            reqData.header = nil
            reqData.param = nil
            reqData.form = nil
            reqData.multipart = nil
            reqData.binary = nil
            reqData.image = nil
            //self.app.addEditRequestDeleteObject(reqData)
        }
    }
    
    /// Mark request body for deletion
    func markEntityForDelete(reqBodyData: ERequestBodyData, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (reqBodyData.managedObjectContext != nil ? reqBodyData.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            if let xs = reqBodyData.form?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData, ctx: ctx) }
            }
            if let xs = reqBodyData.multipart?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData, ctx: ctx) }
            }
            if let bin = reqBodyData.binary { self.markEntityForDelete(reqData: bin, ctx: ctx) }
            reqBodyData.request = nil
            // self.localdb.markEntityForDelete(body, ctx: ctx)
            //AppState.editRequest?.body = nil
            //self.app.addEditRequestDeleteObject(body)
        }
    }
    
    /// Mark file for deletion
    func markEntityForDelete(file: EFile, ctx: NSManagedObjectContext?) {
        
    }
    
    /// Delete image
    func markEntityForDelete(image: EImage, ctx: NSManagedObjectContext?) {
        
    }
    
    ///Delete history
    func markEntityForDelete(history: EHistory, ctx: NSManagedObjectContext?) {
        
    }
    
}
