//
//  EProject.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EProject: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: EACloudKit = EACloudKit.shared
    public var recordType: String { return "Project" }
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.wsId ?? ""
    }
    
    public func setWsId(_ id: String) {
        self.wsId = id
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
    
    /// Returns project from the given record reference. If the project does not exists, one will be created.
    static func getProjectFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> EProject? {
        let projId = self.ck.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let proj = self.db.getProject(id: projId, ctx: ctx) { return proj }
        let proj = self.db.createProject(id: projId, wsId: wsId, name: "", desc: "", checkExists: false, ctx: ctx)
        return proj
    }
    
    static func getRequestRecordIDs(_ record: CKRecord) -> [CKRecord.ID] {
        if let xs = record["requests"] as? [CKRecord.Reference] {
            return xs.map { ref -> CKRecord.ID in ref.recordID }
        }
        return []
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EProject? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        guard let proj = self.db.createProject(id: id, wsId: wsId, name: "", desc: "", ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? Date { proj.created = x }
        if let x = dict["modified"] as? Date { proj.modified = x }
        if let x = dict["desc"] as? String { proj.desc = x }
        if let x = dict["name"] as? String { proj.name = x }
        if let x = dict["version"] as? Int64 { proj.version = x }
        if let xs = dict["requests"] as? [[String: Any]] {
            xs.forEach { dict in
                if let req = ERequest.fromDictionary(dict) {
                    req.project = proj
                }
            }
        }
        if let xs = dict["methods"] as? [[String: Any]] {
            xs.forEach { dict in
                if let method = ERequestMethodData.fromDictionary(dict) {
                    method.project = proj
                }
            }
        }
        proj.markForDelete = false
        self.db.saveMainContext()
        return proj
    }
    
    static func getCKRecord(id: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var proj: EProject!
        var ckProj: CKRecord!
        guard let ckWs = EWorkspace.getCKRecord(id: wsId, ctx: ctx) else { return ckProj }
        ctx.performAndWait {
            proj = db.getProject(id: id, ctx: ctx)
            let zoneID = proj.getZoneID()
            let ckProjID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckProj = self.ck.createRecord(recordID: ckProjID, recordType: proj.recordType)
            proj.updateCKRecord(ckProj, workspace: ckWs)
        }
        return ckProj
    }
    
    func updateCKRecord(_ record: CKRecord, workspace: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: workspace, action: .deleteSelf)
            record["workspace"] = ref
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["desc"] as? String { self.desc = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ws = EWorkspace.getWorkspace(record, ctx: moc) { self.workspace = ws }
            }
        }
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["desc"] = self.desc
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["name"] = self.name
        dict["version"] = self.version
        var xs: [[String: Any]] = []
        // requests
        let reqs = Self.db.getRequests(projectId: self.getId())
        reqs.forEach { req in
            xs.append(req.toDictionary())
        }
        dict["requests"] = xs
        xs = []
        // request methods
        let reqMethods = Self.db.getRequestMethodData(projId: self.getId())
        reqMethods.forEach { method in
            xs.append(method.toDictionary())
        }
        dict["methods"] = xs
        return dict
    }
}
