//
//  ERequestMethodData.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestMethodData: NSManagedObject, Entity {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: EACloudKit = { EACloudKit.shared }()
    public var recordType: String { return "RequestMethodData" }
    
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
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public override func willSave() {
        //if self.modified < AppState.editRequestSaveTs { self.modified = AppState.editRequestSaveTs }
    }
    
    /// Returns method data from the given record reference. If the method does not exists, one will be created.
    static func getRequestMethodDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestMethodData? {
        let methId = self.ck.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let meth = self.db.getRequestMethodData(id: methId, ctx: ctx) { return meth }
        let meth = self.db.createRequestMethodData(id: methId, wsId: wsId, name: "", checkExists: false, ctx: ctx)
        return meth
    }
    
    public static func fromDictionary(_ dict: [String: Any], ctx: NSManagedObjectContext) -> ERequestMethodData? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        guard let method = self.db.createRequestMethodData(id: id, wsId: wsId, name: "", ctx: ctx) else { return nil }
        if let x = dict["created"] as? String { method.created = Date.toUTCDate(x) }
        if let x = dict["modified"] as? String { method.modified = Date.toUTCDate(x) }
        if let x = dict["name"] as? String { method.name = x }
        if let x = dict["order"] as? NSDecimalNumber { method.order = x }
        if let x = dict["version"] as? Int64 { method.version = x }
        method.markForDelete = false
        self.db.saveMainContext()
        return method
    }
    
    static func getCKRecord(id: String, projId: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var reqMeth: ERequestMethodData!
        var ckReqMeth: CKRecord!
        guard let ckProj = EProject.getCKRecord(id: projId, wsId: wsId, ctx: ctx) else { return ckReqMeth }
        ctx.performAndWait {
            reqMeth = db.getRequestMethodData(id: id, ctx: ctx)
            let zoneID = reqMeth.getZoneID()
            let ckReqMethID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckReqMeth = self.ck.createRecord(recordID: ckReqMethID, recordType: reqMeth.recordType)
            reqMeth.updateCKRecord(ckReqMeth, project: ckProj)
        }
        return ckReqMeth
    }
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["isCustom"] = self.isCustom as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            record["order"] = self.order! as CKRecordValue
            record["shouldDelete"] = self.shouldDelete as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: project, action: .none)
            record["project"] = ref as CKRecordValue
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["isCustom"] as? Bool { self.isCustom = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["order"] as? NSDecimalNumber { self.order = x }
                if let x = record["shouldDelete"] as? Bool { self.shouldDelete = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["project"] as? CKRecord.Reference, let proj = EProject.getProjectFromReference(ref, record: record, ctx: moc) { self.project = proj }
            }
        }
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created?.toUTCStr()
        dict["modified"] = self.modified?.toUTCStr()
        dict["id"] = self.id
        dict["isCustom"] = self.isCustom
        dict["name"] = self.name
        dict["order"] = self.order
        dict["version"] = self.version
        dict["wsId"] = self.wsId
        return dict
    }
}
