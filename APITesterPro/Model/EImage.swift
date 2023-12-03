//
//  EImage.swift
//  APITesterPro
//
//  Created by Jaseem V V on 22/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EImage: NSManagedObject, Entity {
    static let db: CoreDataService = CoreDataService.shared
    static let ck: EACloudKit = EACloudKit.shared
    public var recordType: String { return "Image" }
    
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
    
    public func getCreated() -> Int64 {
        return self.created
    }
    
    public func getModified() -> Int64 {
        return self.modified
    }
    
    public func setModified(_ ts: Int64? = nil) {
        self.modified = ts ?? Date().currentTimeNanos()
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
    
    static func addRequestDataReference(_ reqData: CKRecord, image: CKRecord) {
        let ref = CKRecord.Reference(record: reqData, action: .none)
        image["requestData"] = ref
    }
    
    static func getRequestData(_ record: CKRecord, ctx: NSManagedObjectContext) -> ERequestData? {
        if let ref = record["requestData"] as? CKRecord.Reference {
            return self.db.getRequestData(id: self.ck.entityID(recordID: ref.recordID), ctx: ctx)
        }
        return nil
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> EImage? {
        guard let id = dict["id"] as? String, let wsId = dict["wsId"] as? String, let data = dict["data"] as? String,
        let name = dict["name"] as? String, let type = dict["type"] as? String else { return nil }
        guard let data1 = EAUtils.shared.stringToImageData(data) else { return nil }
        guard let image = self.db.createImage(imageId: id, data: data1, wsId: wsId, name: name, type: type, ctx: self.db.mainMOC) else { return nil }
        if let x = dict["created"] as? Int64 { image.created = x }
        if let x = dict["modified"] as? Int64 { image.modified = x }
        if let x = dict["isCameraMode"] as? Bool { image.isCameraMode = x }
        if let x = dict["version"] as? Int64 { image.version = x }
        image.markForDelete = false
        return image
    }
    
    /// EImage belongs to ERequestData with belongs to ERequestBodyData. ERequestData can be form or binary type.
    static func getCKRecord(id: String, reqBodyId: String, reqDataId: String, reqId: String, projId: String, wsId: String, reqType: RequestDataType, ctx: NSManagedObjectContext) -> CKRecord? {
        var image: EImage!
        var ckImage: CKRecord!
        // We fetch ERequestData which belongs to body
        guard let ckReqData = ERequestData.getCKRecord(id: reqDataId, reqBodyId: reqBodyId, reqId: reqId, projId: projId, wsId: wsId, reqType: reqType, ctx: ctx) else { return ckImage }
        ctx.performAndWait {
            image = db.getImageData(id: id, ctx: ctx)
            let zoneID = image.getZoneID()
            let ckImageID = self.ck.recordID(entityId: id, zoneID: zoneID)
            ckImage = self.ck.createRecord(recordID: ckImageID, recordType: image.recordType)
            image.updateCKRecord(ckImage, requestData: ckReqData)
        }
        return ckImage
    }
    
    func updateCKRecord(_ record: CKRecord, requestData: CKRecord) {
        self.managedObjectContext?.performAndWait {
            record["created"] = self.created as CKRecordValue
            record["modified"] = self.modified as CKRecordValue
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
            record["isCameraMode"] = self.isCameraMode as CKRecordValue
            record["name"] = (self.name ?? "") as CKRecordValue
            record["type"] = (self.type ?? "") as CKRecordValue
            record["version"] = self.version as CKRecordValue
            let ref = CKRecord.Reference(record: requestData, action: .deleteSelf)
            record["requestData"] = ref
        }
    }
    
    func updateFromCKRecord(_ record: CKRecord, ctx: NSManagedObjectContext) {
        if let moc = self.managedObjectContext {
            moc.performAndWait {
                if let x = record["created"] as? Int64 { self.created = x }
                if let x = record["modified"] as? Int64 { self.modified = x }
                if let x = record["data"] as? CKAsset, let url = x.fileURL {
                    do { self.data = try Data(contentsOf: url) } catch let error { Log.error("Error getting data from file url: \(error)") }
                }
                if let x = record["id"] as? String { self.id = x }
                if let x = record["isCameraMode"] as? Bool { self.isCameraMode = x }
                if let x = record["name"] as? String { self.name = x }
                if let x = record["type"] as? String { self.type = x }
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
        dict["wsId"] = self.wsId
        dict["name"] = self.name
        dict["type"] = self.type
        dict["data"] = EAUtils.shared.imageDataToString(self.data)
        dict["version"] = self.version
        return dict
    }
}
