//
//  EEnv.swift
//  APITesterPro
//
//  Created by Jaseem V V on 15/06/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class EEnv: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: JVCloudKit = JVCloudKit.shared
    public var recordType: String { return "Env" }
    
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
    
    static func getEnvFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> EEnv? {
        let envId = self.ck.entityID(recordID: ref.recordID)
        if let env = self.db.getEnv(id: envId, ctx: ctx) { return env }
        let env = self.db.createEnv(name: "", envId: envId, wsId: "", checkExists: false, ctx: ctx)
        return env
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EEnv? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        guard let env = self.db.createEnv(name: "", envId: id, wsId: wsId, checkExists: true, ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? Date { env.created = x }
        if let x = dict["modified"] as? Date { env.modified = x }
        if let x = dict["name"] as? String { env.name = x }
        if let x = dict["version"] as? Int64 { env.version = x }
        if let xs = dict["variables"] as? [[String: Any]] {
            xs.forEach { hm in
                if let envVar = EEnvVar.fromDictionary(hm) {
                    envVar.env = env
                }
            }
        }
        env.markForDelete = false
        self.db.saveMainContext()
        return env
    }
    
    static func getCKRecord(id: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var env: EEnv!
        var ckEnv: CKRecord!
        guard let ckWs: CKRecord = EWorkspace.getCKRecord(id: wsId, ctx: ctx) else { return ckEnv }
        ctx.performAndWait {
            env = db.getEnv(id: id, ctx: ctx)
            let zoneID = env.getZoneID()
            let ckEnvID = self.ck.recordID(entityId: env.getId(), zoneID: zoneID)
            ckEnv = self.ck.createRecord(recordID: ckEnvID, recordType: env.recordType)
            env.updateCKRecord(ckEnv, workspace: ckWs)
        }
        return ckEnv
    }
    
    func updateCKRecord(_ record: CKRecord, workspace: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["id"] = (self.id ?? "") as CKRecordValue
            record["wsId"] = (self.wsId ?? "") as CKRecordValue
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
                if let x = record["id"] as? String { self.id = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ws = EWorkspace.getWorkspace(record, ctx: moc) { self.workspace = ws }
            }
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["id"] = self.id
        dict["name"] = self.name
        dict["version"] = self.version
        dict["wsId"] = self.wsId
        let vars = Self.db.getEnvVars(envId: self.getId())
        var acc: [[String: Any]] = []
        vars.forEach { envVar in
            acc.append(envVar.toDictionary())
        }
        dict["variables"] = acc
        return dict
    }
}
