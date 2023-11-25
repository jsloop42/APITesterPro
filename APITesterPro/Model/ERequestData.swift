//
//  ERequestData.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class ERequestData: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: EACloudKit = EACloudKit.shared
    public var recordType: String { return "RequestData" }
    
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
    
    public func getCreated() -> Int64 {
        return self.created
    }
    
    public func getModified() -> Int64 {
        return self.modified
    }
    
    public func setModified(_ ts: Int64? = nil) {
        self.modified = ts ?? Date().currentTimeNanos()
    }
    
    public func getChangeTag() -> Int64 {
        return self.changeTag
    }
    
    public func setChangeTag(_ ts: Int64? = nil) {
        self.changeTag = ts ?? Date().currentTimeNanos()
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
    
    static func getRecordType(_ record: CKRecord) -> RequestDataType? {
        guard let x = record["type"] as? Int64, let type = RequestDataType(rawValue: x.toInt()) else { return nil }
        return type
    }
    
    static func getFormFieldFormatType(_ record: CKRecord) -> RequestBodyFormFieldFormatType {
        guard let x = record["fieldFormat"] as? Int64, let type = RequestBodyFormFieldFormatType(rawValue: x.toInt()) else { return .text }
        return type
    }
    
    static func getRequestDataFromReference(_ ref: CKRecord.Reference, record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        let reqDataId = self.ck.entityID(recordID: ref.recordID)
        let wsId = record.getWsId()
        if let reqData = self.db.getRequestData(id: reqDataId, ctx: ctx) { return reqData }
        let reqData = self.db.createRequestData(id: reqDataId, wsId: wsId, type: .form, fieldFormat: .file, checkExists: false, ctx: ctx)
        reqData?.changeTag = 0
        return reqData
    }
    
    /// Adds back reference to CoreData entity.
    static func addBackReference(record: CKRecord, reqData: ERequestData, ctx: NSManagedObjectContext) {
        if let ref = record["header"] as? CKRecord.Reference {
            reqData.header = ERequest.getRequestFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.header.rawValue.toInt64()
            return
        }
        if let ref = record["param"] as? CKRecord.Reference {
            reqData.param = ERequest.getRequestFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.param.rawValue.toInt64()
            return
        }
        if let ref = record["form"] as? CKRecord.Reference {
            reqData.form = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.form.rawValue.toInt64()
            return
        }
        if let ref = record["multipart"] as? CKRecord.Reference {
            reqData.multipart = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.multipart.rawValue.toInt64()
            return
        }
        if let ref = record["binary"] as? CKRecord.Reference {
            reqData.binary = ERequestBodyData.getRequestBodyDataFromReference(ref, record: record, ctx: ctx)
            reqData.type = RequestDataType.binary.rawValue.toInt64()
            return
        }
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ERequestData? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String, let _type = dict["type"] as? Int64,
            let type = RequestDataType(rawValue: _type.toInt()), let _format = dict["fieldFormat"] as? Int64,
            let format = RequestBodyFormFieldFormatType(rawValue: _format.toInt())
            else { return nil }
        guard let reqData = self.db.createRequestData(id: id, wsId: wsId, type: type, fieldFormat: format, ctx: db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { reqData.created = x }
        if let x = dict["modified"] as? Int64 { reqData.modified = x }
        if let x = dict["changeTag"] as? Int64 { reqData.changeTag = x }
        if let x = dict["key"] as? String { reqData.key = x }
        if let x = dict["value"] as? String { reqData.value = x }
        if let x = dict["version"] as? Int64 { reqData.version = x }
        if let files = dict["files"] as? [[String: Any]] {
            files.forEach { hm in
                if let file = EFile.fromDictionary(hm) {
                    file.requestData = reqData
                }
            }
        }
        if let image = dict["image"] as? [String: Any] {
            if let img = EImage.fromDictionary(image) {
                img.requestData = reqData
            }
        }
        reqData.markForDelete = false
        db.saveMainContext()
        return reqData
    }
    
    /// Get RequestData CKRecord of type header or param. This is backreferenced to Request record.
    static func getCKRecord(id: String, reqId: String, projId: String, wsId: String, reqType: RequestDataType, ctx: NSManagedObjectContext) -> CKRecord? {
        var reqData: ERequestData!
        var ckReqData: CKRecord!
        guard let ckReq = ERequest.getCKRecord(id: reqId, projId: projId, wsId: wsId, ctx: ctx) else { return ckReqData }
        ctx.performAndWait {
            reqData = db.getRequestData(id: id, ctx: ctx)
            let zoneID = reqData.getZoneID()
            let ckReqDataID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckReqData = self.ck.createRecord(recordID: ckReqDataID, recordType: reqData.recordType)
            reqData.updateCKRecord(ckReqData, request: ckReq, reqType: reqType)
        }
        return ckReq
    }
    
    /// Get RequestData CKRecord of type form, multipart or binary. This is backreferenced to RequestBodyData record.
    static func getCKRecord(id: String, reqBodyId: String, reqId: String, projId: String, wsId: String, reqType: RequestDataType, ctx: NSManagedObjectContext) -> CKRecord? {
        var reqData: ERequestData!
        var ckReqData: CKRecord!
        guard let ckReqBodyData = ERequestBodyData.getCKRecord(id: reqBodyId, reqId: reqId, projId: projId, wsId: wsId, ctx: ctx) else { return ckReqData }
        ctx.performAndWait {
            reqData = db.getRequestData(id: id, ctx: ctx)
            let zoneID = reqData.getZoneID()
            let ckReqDataID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckReqData = self.ck.createRecord(recordID: ckReqDataID, recordType: reqData.recordType)
            reqData.updateCKRecord(ckReqData, reqBodyData: ckReqBodyData, reqType: reqType)
        }
        return ckReqData
    }
    
    private func updateCKRecord(_ record: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
            record["changeTag"] = self.changeTag as CKRecordValue
            record["desc"] = (self.desc ?? "") as CKRecordValue
            record["fieldFormat"] = self.fieldFormat as CKRecordValue
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["key"] = (self.key ?? "") as CKRecordValue
            record["type"] = self.type as CKRecordValue
            record["value"] = (self.value ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
        }
    }
    
    /// RequestData can either belong to a Request (header, param) or RequestBodyData (form, multipart or binary)
    func updateCKRecord(_ record: CKRecord, request: CKRecord, reqType: RequestDataType) {
        self.updateCKRecord(record)
        let ref = CKRecord.Reference(record: request, action: .deleteSelf)
        if reqType == .header {
            record["header"] = ref
        } else if reqType == .param {
            record["param"] = ref
        }
    }
    
    /// RequestData can either belong to a Request (header, param) or RequestBodyData (form, multipart or binary)
    func updateCKRecord(_ record: CKRecord, reqBodyData: CKRecord, reqType: RequestDataType) {
        self.updateCKRecord(record)
        let ref = CKRecord.Reference(record: reqBodyData, action: .deleteSelf)
        if reqType == .form {
            record["form"] = ref
        } else if reqType == .multipart {
            record["multipart"] = ref
        } else if reqType == .binary {
            record["binary"] = ref
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["changeTag"] as? Int64 { self.changeTag = x }
                if let x = record["desc"] as? String { self.desc = x }
                if let x = record["fieldFormat"] as? Int64 { self.fieldFormat = x }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["key"] as? String { self.key = x }
                if let x = record["type"] as? Int64 { self.type = x }
                if let x = record["value"] as? String { self.value = x }
                if let x = record["version"] as? Int64 { self.version = x }
                ERequestData.addBackReference(record: record, reqData: self, ctx: moc)
            }
        }
    }
    
    public func toDictionary() -> [String : Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["changeTag"] = self.changeTag
        dict["desc"] = self.desc
        dict["fieldFormat"] = self.fieldFormat
        dict["id"] = self.id
        dict["key"] = self.key
        dict["type"] = self.type
        dict["value"] = self.value
        dict["version"] = self.version
        dict["wsId"] = self.wsId
        var acc: [[String: Any]] = []
        if let xs = self.files?.allObjects as? [EFile] {
            xs.forEach { file in
                if !file.markForDelete { acc.append(file.toDictionary()) }
            }
        }
        dict["files"] = acc
        acc = []
        if let image = self.image {
            dict["image"] = image.toDictionary()
        }
        return dict
    }
}
