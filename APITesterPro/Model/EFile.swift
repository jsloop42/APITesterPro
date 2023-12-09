//
//  EFile.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EFile: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: EACloudKit = EACloudKit.shared
    public var recordType: String { return "File" }
    
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
    
    static func getRequestData(_ record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        if let ref = record["requestData"] as? CKRecord.Reference {
            return self.db.getRequestData(id: self.ck.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EFile? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String, let _data = dict["data"] as? String,
            let name = dict["name"] as? String, let _type = dict["type"] as? Int64, let type = RequestDataType(rawValue: _type.toInt()) else { return nil }
        var data: Data?
        if let aData = _data.data(using: .utf8) {
            data = aData
        } else {
            data = EAUtils.shared.stringToImageData(_data)
        }
        guard let data1 = data else { return nil }
        guard let file = self.db.createFile(fileId: id, data: data1, wsId: wsId, name: name, path: URL(fileURLWithPath: "/tmp/"), type: type, checkExists: true, ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? Date { file.created = x }
        if let x = dict["modified"] as? Date { file.modified = x }
        if let x = dict["version"] as? Int64 { file.version = x }
        file.markForDelete = false
        return file
    }
    
    /// EFile belongs to ERequestData with belongs to ERequestBodyData
    static func getCKRecord(id: String, reqBodyId: String, reqDataId: String, reqId: String, projId: String, wsId: String, reqType: RequestDataType, ctx: NSManagedObjectContext) -> CKRecord? {
        var file: EFile!
        var ckFile: CKRecord!
        // We fetch ERequestData which belongs to body
        guard let ckReqData = ERequestData.getCKRecord(id: reqDataId, reqBodyId: reqBodyId, reqId: reqId, projId: projId, wsId: wsId, reqType: reqType, ctx: ctx) else { return ckFile }
        ctx.performAndWait {
            file = db.getFileData(id: id, ctx: ctx)
            let zoneID = file.getZoneID()
            let ckFileID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckFile = self.ck.createRecord(recordID: ckFileID, recordType: file.recordType)
            file.updateCKRecord(ckFile, requestData: ckReqData)
        }
        return ckFile
    }
    
    func updateCKRecord(_ record: CKRecord, requestData: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created! as CKRecordValue
            record["modified"] = self.modified! as CKRecordValue
            if let name = self.name, let data = self.data {
                let url = EAFileManager.getTemporaryURL(name)
                do {
                    try data.write(to: url)
                    record["data"] = CKAsset(fileURL: url)
                } catch let error {
                    Log.error("Error: \(error)")
                }
            }
            record["id"] = self.getId() as CKRecordValue
            record["wsId"] = self.getWsId() as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            record["type"] = self.type as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: requestData, action: .deleteSelf)
            record["requestData"] = ref
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Date { self.created = x }
                if let x = record["modified"] as? Date { self.modified = x }
                if let x = record["data"] as? CKAsset, let url = x.fileURL {
                    do { self.data = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["type"] as? Int64 { self.type = x }
                if let x = record["version"] as? Int64 { self.version = x }
                if let ref = record["requestData"] as? CKRecord.Reference, let reqData = ERequestData.getRequestDataFromReference(ref, record: record, ctx: moc) {
                    self.requestData = reqData
                }
            }
        }
    }
    
    public func toDictionary() -> [String : Any] {
        var dict: [String: Any] = [:]
        dict["created"] = self.created
        dict["modified"] = self.modified
        dict["id"] = self.id
        dict["name"] = self.name
        dict["type"] = self.type
        dict["version"] = self.version
        if let data = self.data {
            if let str = String(data: data, encoding: .utf8) {
                dict["data"] = str
            } else {
                dict["data"] = EAUtils.shared.imageDataToString(data)
            }
        }
        dict["wsId"] = self.wsId
        return dict
    }
}
