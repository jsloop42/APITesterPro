//
//  ERequest.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequest: NSManagedObject, Entity {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: EACloudKit = { EACloudKit.shared }()
    public var recordType: String { return "Request" }
    
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
    
    static func updateRequestDataReference(to request: CKRecord, requestData: CKRecord, type: RequestDataType) {
        let key: String = {
            if type == .header { return "headers" }
            if type == .param { return "params" }
            return ""
        }()
        guard !key.isEmpty else { Log.error("Wrong request data type passed: \(type.rawValue)"); return }
        let ref = CKRecord.Reference(record: requestData, action: .deleteSelf)
        var xs = request[key] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
        if !xs.contains(ref) {
            xs.append(ref)
            request[key] = xs as CKRecordValue
        }
    }
    
    static func updateBodyReference(_ request: CKRecord, body: CKRecord) {
        let ref = CKRecord.Reference(record: body, action: .deleteSelf)
        request["body"] = ref as CKRecordValue
    }
    
    static func getRequestFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequest? {
        let reqId = self.ck.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let req = self.db.getRequest(id: reqId, ctx: ctx) { return req }
        let req = self.db.createRequest(id: reqId, wsId: wsId, name: "", checkExists: false, ctx: ctx)
        return req
    }
    
    public static func fromDictionary(_ dict: [String: Any], ctx: NSManagedObjectContext) -> ERequest? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String else { return nil }
        guard let req = self.db.createRequest(id: id, wsId: wsId, name: "", ctx: ctx) else { return nil }
        if let x = dict["created"] as? String { req.created = Date.toUTCDate(x) }
        if let x = dict["modified"] as? String { req.modified = Date.toUTCDate(x) }
        if let x = dict["envId"] as? String { req.envId = x }
        if let x = dict["desc"] as? String { req.desc = x }
        if let x = dict["name"] as? String { req.name = x }
        if let x = dict["order"] as? NSDecimalNumber { req.order = x }
        if let x = dict["validateSSL"] as? Bool { req.validateSSL = x }
        if let x = dict["url"] as? String { req.url = x }
        if let x = dict["version"] as? Int64 { req.version = x }
        if let dict = dict["method"] as? [String: Any] {
            if let method = ERequestMethodData.fromDictionary(dict, ctx: ctx) {
                req.method = method
            }
        }
        if let dict = dict["body"] as? [String: Any] {
            if let body = ERequestBodyData.fromDictionary(dict, ctx: ctx) {
                req.body = body
            }
        }
        if let xs = dict["headers"] as? [[String: Any]] {
            xs.forEach { dict in
                if let reqData = ERequestData.fromDictionary(dict, ctx: ctx) {
                    reqData.header = req
                }
            }
        }
        if let xs = dict["params"] as? [[String: Any]] {
            xs.forEach { dict in
                if let reqData = ERequestData.fromDictionary(dict, ctx: ctx) {
                    reqData.param = req
                }
            }
        }
        req.markForDelete = false
        self.db.saveMainContext()
        return req
    }
    
    static func getCKRecord(id: String, projId: String, wsId: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var req: ERequest!
        var ckReq: CKRecord!
        guard let ckProj = EProject.getCKRecord(id: projId, wsId: wsId, ctx: ctx) else { return ckReq }
        var methId: String?
        ctx.performAndWait {
            req = db.getRequest(id: id, ctx: ctx)
            methId = req.method?.getId()
        }
        guard let methId = methId else { return ckReq }
        guard let ckMeth = ERequestMethodData.getCKRecord(id: methId, projId: projId, wsId: wsId, ctx: ctx) else { return ckReq }
        ctx.performAndWait {
            let zoneID = req.getZoneID()
            let ckReqID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckReq = self.ck.createRecord(recordID: ckReqID, recordType: req.recordType)
            req.updateCKRecord(ckReq, project: ckProj, method: ckMeth)
        }
        return ckReq
    }
    
    func updateCKRecord(_ record: CKRecord, project: CKRecord, method: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["envId"] = (self.envId ?? "") as CKRecordValue
            record["name"] = self.name! as CKRecordValue
            record["order"] = self.order! as CKRecordValue
            record["validateSSL"] = self.validateSSL as CKRecordValue
            record["url"] = (self.url ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let projRef = CKRecord.Reference(record: project, action: .deleteSelf)
            record["project"] = projRef
            let methRef = CKRecord.Reference(record: method, action: .none)
            record["method"] = methRef
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["wsId"] as? String { self.wsId = x }
                if let x = record["desc"] as? String { self.desc = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["envId"] as? String { self.envId = x }
                if let x = record["order"] as? NSDecimalNumber { self.order = x }
                if let x = record["validateSSL"] as? Bool { self.validateSSL = x }
                if let x = record["url"] as? String { self.url = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["project"] as? CKRecord.Reference, let proj = EProject.getProjectFromReference(ref, record: record, ctx: moc) { self.project = proj }
                if let ref = record["method"] as? CKRecord.Reference, let meth = ERequestMethodData.getRequestMethodDataFromReference(ref, record: record, ctx: ctx) { self.method = meth }
            }
        }
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created?.toUTCStr()
        dict["modified"] = self.modified?.toUTCStr()
        dict["id"] = self.id
        dict["wsId"] = self.wsId
        dict["desc"] = self.desc
        dict["name"] = self.name
        dict["envId"] = self.envId
        dict["order"] = self.order
        dict["validateSSL"] = self.validateSSL
        dict["url"] = self.url
        dict["version"] = self.version
        if let meth = self.method {
            dict["method"] = meth.toDictionary()
        }
        if let body = self.body {
            dict["body"] = body.toDictionary()
        }
        let headers = Self.db.getHeadersRequestData(self.getId())
        var xs: [[String: Any]] = []
        headers.forEach { header in
            xs.append(header.toDictionary())
        }
        dict["headers"] = xs
        xs = []
        let params = Self.db.getParamsRequestData(self.getId())
        params.forEach { param in
            xs.append(param.toDictionary())
        }
        dict["params"] = xs
        xs = []
        return dict
    }
}
