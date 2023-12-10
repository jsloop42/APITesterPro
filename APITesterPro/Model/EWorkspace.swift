//
//  EWorkspace.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EWorkspace: NSManagedObject, Entity {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: JVCloudKit = { JVCloudKit.shared }()
    public var recordType: String { return "Workspace" }
    
    /// Checks if the default workspace does not have any change or is just after a reset (is new)
    var isInDefaultMode: Bool {
        return self.id == Self.db.defaultWorkspaceId && self.name == Self.db.defaultWorkspaceName && self.desc == Self.db.defaultWorkspaceDesc && (self.projects == nil || self.projects!.isEmpty)
    }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.getId()
    }
    
    public func setWsId(_ id: String) {
        self.id = id
    }
    
    public func getName() -> String {
        return self.name ?? ""
    }
    
    public func getCreated() -> Date {
        return self.created!.toLocalDate()
    }
    
    public func getCreatedUTC() -> Date {
        return self.created!
    }
    
    public func getModified() -> Date {
        return self.modified!.toLocalDate()
    }
    
    public func getModitiedUTC() -> Date {
        return self.modified!
    }
    
    public func setModified(_ date: Date) {
        self.modified = date.toUTC()
    }
    
    public func setModifiedUTC(_ date: Date) {
        self.modified = date
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public override func willSave() {
        //if self.modified < AppState.editRequestSaveTs { self.modified = AppState.editRequestSaveTs }
    }
    
    static func getWorkspace(_ record: CKRecord, ctx: NSManagedObjectContext) -> EWorkspace? {
        if let ref = record["workspace"] as? CKRecord.Reference {
            return self.db.getWorkspace(id: JVCloudKit.shared.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EWorkspace? {
        guard let id = dict["id"] as? String else { return nil }
        let ctx = self.db.mainMOC
        guard let ws = self.db.createWorkspace(id: id, name: "", desc: "", isSyncEnabled: false, ctx: ctx) else { return nil }
        if let x = dict["created"] as? Date { ws.created = x }
        if let x = dict["modified"] as? Date { ws.modified = x }
        if let x = dict["isActive"] as? Bool { ws.isActive = x }
        if let x = dict["isSyncEnabled"] as? Bool { ws.isSyncEnabled = x }
        if let x = dict["name"] as? String { ws.name = x }
        if let x = dict["desc"] as? String { ws.desc = x }
        if let x = dict["saveResponse"] as? Bool { ws.saveResponse = x }
        if let x = dict["version"] as? Int64 { ws.version = x }
        self.db.saveMainContext()
        if let xs = dict["projects"] as? [[String: Any]] {
            xs.forEach { x in
                if let proj = EProject.fromDictionary(x) {
                    proj.workspace = ws
                }
            }
        }
        if let xs = dict["envs"] as? [[String: Any]] {
            xs.forEach { dict in
                _ = EEnv.fromDictionary(dict)
            }
        }
        ws.markForDelete = false
        self.db.saveMainContext()
        self.db.mainMOC.refreshAllObjects()
        return ws
    }
    
    static func getCKRecord(id: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var ws: EWorkspace!
        let zoneID = self.ck.zoneID(workspaceId: id)
        let ckWsID = self.ck.recordID(entityId: id, zoneID: zoneID)
        var ckWs: CKRecord!
        ctx.performAndWait {
            ws = db.getWorkspace(id: id, ctx: ctx)
            ckWs = self.ck.createRecord(recordID: ckWsID, recordType: ws.recordType)
            ws.updateCKRecord(ckWs)
        }
        return ckWs
    }
    
    func updateCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["isActive"] = self.isActive as CKRecordValue
            record["isSyncEnabled"] = self.isSyncEnabled as CKRecordValue
            record["name"] = self.name! as CKRecordValue
            record["saveResponse"] = self.saveResponse as CKRecordValue
            record["version"] = self.version as CKRecordValue
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            if let x = record["created"] as? Date { self.created = x }
            if let x = record["modified"] as? Date { self.modified = x }
            if let x = record["id"] as? String { self.id = x }
            if let x = record["isActive"] as? Bool { self.isActive = x }
            if let x = record["isSyncEnabled"] as? Bool { self.isSyncEnabled = x }
            if let x = record["name"] as? String { self.name = x }
            if let x = record["desc"] as? String { self.desc = x }
            if let x = record["saveResponse"] as? Bool { self.saveResponse = x }
            if let x = record["version"] as? Int64 { self.version = x }
        }
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["id"] = self.id
        dict["isActive"] = self.isActive
        dict["isSyncEnabled"] = self.isSyncEnabled
        dict["name"] = self.name
        dict["desc"] = self.desc
        dict["saveResponse"] = self.saveResponse
        dict["version"] = self.version
        var xs: [[String: Any]] = []
        let projs = Self.db.getProjects(wsId: self.getId())
        projs.forEach { proj in
            xs.append(proj.toDictionary())
        }
        dict["projects"] = xs
        let envxs = Self.db.getEnvs(wsId: self.getWsId())
        xs = []
        envxs.forEach { env in
            xs.append(env.toDictionary())
        }
        dict["envs"] = xs
        return dict
    }
}
