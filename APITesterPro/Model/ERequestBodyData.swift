//
//  ERequestBodyData.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestBodyData: NSManagedObject, Entity {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: JVCloudKit = { JVCloudKit.shared }()
    public var recordType: String { return "RequestBodyData" }
    
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
        return self.id ?? ""
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
    
    static func getRequestBodyDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestBodyData? {
        let reqBodyDataId = self.ck.entityID(recordID: ref.recordID)
        if let bodyData = self.db.getRequestBodyData(id: reqBodyDataId, ctx: ctx) { return bodyData }
        let bodyData = self.db.createRequestBodyData(id: reqBodyDataId, wsId: record.getWsId(), checkExists: false, ctx: ctx)
        return bodyData
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ERequestBodyData? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        guard let body = self.db.createRequestBodyData(id: id, wsId: wsId, ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? String { body.created = Date.toUTCDate(x) }
        if let x = dict["modified"] as? String { body.modified = Date.toUTCDate(x) }
        if let x = dict["json"] as? String { body.json = x }
        if let x = dict["raw"] as? String { body.raw = x }
        if let x = dict["selected"] as? Int64 { body.selected = x }
        if let x = dict["xml"] as? String { body.xml = x }
        if let x = dict["version"] as? Int64 { body.version = x }
        if let hm = dict["binary"] as? [String: Any] {
            body.binary = ERequestData.fromDictionary(hm)
            body.binary?.binary = body
        }
        if let xs = dict["form"] as? [[String: Any]] {
            xs.forEach { hm in
                if let form = ERequestData.fromDictionary(hm) {
                    form.form = body
                }
            }
        }
        if let xs = dict["multipart"] as? [[String: Any]] {
            xs.forEach { hm in
                if let mp = ERequestData.fromDictionary(hm) {
                    mp.multipart = body
                }
            }
        }
        body.markForDelete = false
        self.db.saveMainContext()
        return body
    }
    
    static func getCKRecord(id: String, reqId: String, projId: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var reqBodyData: ERequestBodyData!
        var ckReqBodyData: CKRecord!
        guard let ckReq = ERequest.getCKRecord(id: reqId, projId: projId, wsId: wsId, ctx: ctx) else { return ckReqBodyData }
        ctx.performAndWait {
            reqBodyData = db.getRequestBodyData(id: id, ctx: ctx)
            let zoneID = reqBodyData.getZoneID()
            let ckReqBodyDataID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckReqBodyData = self.ck.createRecord(recordID: ckReqBodyDataID, recordType: reqBodyData.recordType)
            reqBodyData.updateCKRecord(ckReqBodyData, request: ckReq)
        }
        return ckReqBodyData
    }
    
    func updateCKRecord(_ record: CKRecord, request: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["json"] = (self.json ?? "") as CKRecordValue
            record["raw"] = (self.raw ?? "") as CKRecordValue
            record["selected"] = self.selected as CKRecordValue
            record["version"] = self.version as CKRecordValue
            record["xml"] = (self.xml ?? "") as CKRecordValue
            let ref = CKRecord.Reference(record: request, action: .deleteSelf)
            record["request"] = ref as CKRecordValue
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            if let x = record["created"] as? Date { self.created = x }
            if let x = record["modified"] as? Date { self.modified = x }
            if let x = record["id"] as? String { self.id = x }
            if let x = record["json"] as? String { self.json = x }
            if let x = record["raw"] as? String { self.raw = x }
            if let x = record["selected"] as? Int64 { self.selected = x }
            if let x = record["version"] as? Int64 { self.version = x }
            if let x = record["xml"] as? String { self.xml = x }
            if let ref = record["request"] as? CKRecord.Reference, let req = ERequest.getRequestFromReference(ref, record: record, ctx: moc) { self.request = req }
        }
    }
    
    public func toDictionary() -> [String : Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created?.toUTCStr()
        dict["modified"] = self.modified?.toUTCStr()
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["json"] = self.json
        dict["raw"] = self.raw
        dict["selected"] = self.selected
        dict["xml"] = self.xml
        dict["version"] = self.version
        if let bin = self.binary {
            dict["binary"] = bin.toDictionary()
        }
        var acc: [[String: Any]] = []
        if let xs = self.form?.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.markForDelete { acc.append(reqData.toDictionary()) }
            }
            dict["form"] = acc
        }
        acc = []
        if let xs = self.multipart?.allObjects as? [ERequestData] {
            xs.forEach { reqData in
                if !reqData.markForDelete { acc.append(reqData.toDictionary()) }
            }
            dict["multipart"] = acc
        }
        return dict
    }
}
