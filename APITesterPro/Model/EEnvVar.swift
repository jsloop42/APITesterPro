//
//  EEnvVar.swift
//  APITesterPro
//
//  Created by Jaseem V V on 16/06/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public class EEnvVar: NSManagedObject, Entity {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: JVCloudKit = { JVCloudKit.shared }()
    public var recordType: String { return "EnvVar" }
    private let secureTrans = SecureTransformerString()
    
    public func getId() -> String {
        return self.id ?? ""
    }
    
    public func getWsId() -> String {
        return self.env?.getWsId() ?? ""
    }
    
    public func setWsId(_ id: String) {
        fatalError("Not implemented")
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
    
    public static func fromDictionary(_ dict: [String: Any]) -> EEnvVar? {
        guard let id = dict["id"] as? String else { return nil }
        guard let envVar = self.db.createEnvVar(name: "", value: "", id: id, checkExists: true, ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? Date { envVar.created = x }
        if let x = dict["modified"] as? Date { envVar.modified = x }
        if let x = dict["name"] as? String { envVar.name = x }
        if let x = dict["value"] as? String { envVar.value = x as NSObject }
        if let x = dict["version"] as? Int64 { envVar.version = x }
        envVar.markForDelete = false
        return envVar
    }
    
    static func getCKRecord(id: String, envId: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var envVar: EEnvVar!
        var ckEnvVar: CKRecord!
        guard let ckEnv: CKRecord = EEnv.getCKRecord(id: envId, wsId: wsId, ctx: ctx) else { return ckEnvVar }
        ctx.performAndWait {
            envVar = db.getEnvVar(id: id, ctx: ctx)
            let zoneID = envVar.getZoneID()
            let ckEnvVarID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckEnvVar = self.ck.createRecord(recordID: ckEnvVarID, recordType: envVar.recordType)
            envVar.updateCKRecord(ckEnvVar, env: ckEnv)
        }
        return ckEnvVar
    }
    
    func updateCKRecord(_ record: CKRecord, env: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            if let name = self.name, let str = self.value as? String, let data = self.secureTrans.transformedValue(str) as? Data {
                let url = JVFileManager.getTemporaryURL(name)
                do {
                    try data.write(to: url)
                    record["value"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: env, action: .deleteSelf)
            record["env"] = ref
        }
    }
        
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["value"] as? CKAsset, let url = x.fileURL {
                    do {
                        let data = try Data(contentsOf: url)
                        if let str = self.secureTrans.reverseTransformedValue(data) as? String {
                            self.value = str as NSObject
                        }
                        
                    } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["env"] as? CKRecord.Reference, let env = EEnv.getEnvFromReference(ref, record: record, ctx: moc) {
                    self.env = env
                }
            }
        }
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["id"] = self.id
        dict["name"] = self.name
        dict["value"] = self.value as? String ?? ""
        return dict
    }
}
