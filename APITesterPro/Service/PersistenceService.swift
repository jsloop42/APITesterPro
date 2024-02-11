//
//  PersistenceService.swift
//  APITesterPro
//
//  Created by Jaseem V V on 26/11/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

/// Class for persisting entities. Created entities are first saved to local and then synced to cloud. Deleted entites needs to be first removed from iCloud and then from local.
class PersistenceService {
    static var shared = PersistenceService()
    private lazy var db = { CoreDataService.shared }()
    
    // MARK: - Create entities
    
    func createWorkspace(name: String, desc: String, isSyncEnabled: Bool) {
        let ctx = isSyncEnabled ? self.db.ckMainMOC : self.db.localMainMOC
        let order = self.db.getOrderOfLastWorkspace(ctx: ctx).inc()
        if let ws = self.db.createWorkspace(id: self.db.workspaceId(), name: name, desc: desc, isSyncEnabled: isSyncEnabled, ctx: ctx) {
            ws.order = order
            self.db.saveMainContext()
        }
    }
    
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
    
    func deleteEntity(_ x: any Entity) {
        switch (x.recordType) {
        case RecordType.requestBodyData.rawValue:
            self.deleteEntity(reqBodyData: x as! ERequestBodyData)
        case RecordType.requestData.rawValue:
            self.deleteEntity(reqData: x as! ERequestData)
        case RecordType.requestMethodData.rawValue:
            self.deleteEntity(reqMethodData: x as! ERequestMethodData)
        case RecordType.file.rawValue:
            self.deleteEntity(file: x as! EFile)
        case RecordType.image.rawValue:
            self.deleteEntity(image: x as! EImage)
        default:
            break
        }
    }
    
    // MARK: - Mark data for delete in editing request
    
    // These methods are used when entites are deleted when editing a request. These shouldn't persist until the background context is saved. On save the stale entites needs to be deleted manually.
    
    /// Mark request data for deletion - header, params, forms, multipart, binary
    func markEntityForDelete(reqData: ERequestData, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (reqData.managedObjectContext != nil ? reqData.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            reqData.setMarkedForDelete(true)
            // remove backreferences
            reqData.header = nil
            reqData.param = nil
            reqData.form = nil
            reqData.multipart = nil
            reqData.binary = nil
        }
    }
    
    /// Mark request body for deletion
    func markEntityForDelete(reqBodyData: ERequestBodyData, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (reqBodyData.managedObjectContext != nil ? reqBodyData.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            reqBodyData.setMarkedForDelete(true)
            // remove backreference
            reqBodyData.request = nil
        }
    }
    
    /// Mark file for deletion
    func markEntityForDelete(file: EFile, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (file.managedObjectContext != nil ? file.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            file.setMarkedForDelete(true)
            // remove backreference
            file.requestData = nil
        }
    }
    
    /// Delete image
    func markEntityForDelete(image: EImage, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (image.managedObjectContext != nil ? image.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            image.setMarkedForDelete(true)
            // remove backreference
            image.requestData = nil
        }
    }
    
    ///Delete request method data
    func markEntityForDelete(reqMeth: ERequestMethodData, ctx: NSManagedObjectContext?) {
        let ctx = ctx != nil ? ctx : (reqMeth.managedObjectContext != nil ? reqMeth.managedObjectContext : nil)
        guard let ctx = ctx else { return }
        ctx.performAndWait {
            reqMeth.setMarkedForDelete(true)
            // remove backreference
            reqMeth.project = nil
        }
    }
}
