//
//  EWorkspace.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public class EWorkspace: NSManagedObject, Entity {
    public var recordType: String { return "Workspace" }
    
    public func getId() -> String {
        return self.id ?? ""
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
    
    public func getChangeTag() -> Int64 {
        return self.changeTag
    }
    
    public func getVersion() -> Int64 {
        return self.version
    }
    
    public func setIsSynced(_ status: Bool) {
        self.isSynced = status
    }
    
    public func getZoneID() -> CKRecordZone.ID {
        return CloudKitService.shared.zoneID(workspaceId: self.id!)
    }
    
    public func setMarkedForDelete(_ status: Bool) {
        self.markForDelete = status
    }
    
    public func setModified(_ ts: Int64? = nil) {
        self.modified = ts ?? Date().currentTimeNanos()
    }
    
    public func setChangeTag(_ ts: Int64? = nil) {
        self.changeTag = ts ?? Date().currentTimeNanos()
    }
    
    public override func willSave() {
        //if self.modified < AppState.editRequestSaveTs { self.modified = AppState.editRequestSaveTs }
    }
    
    func updateCKRecord(_ record: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["changeTag"] = self.changeTag as CKRecordValue
        record["desc"] = (self.desc ?? "") as CKRecordValue
        record["id"] = self.id! as CKRecordValue
        record["isActive"] = self.isActive as CKRecordValue
        record["isSyncEnabled"] = self.isSyncEnabled as CKRecordValue
        record["name"] = self.name! as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    static func addProjectReference(to workspace: CKRecord, project: CKRecord) {
//        let ref = CKRecord.Reference(record: project, action: .deleteSelf)
//        var xs = workspace["projects"] as? [CKRecord.Reference] ?? [CKRecord.Reference]()
//        if !xs.contains(ref) {
//            xs.append(ref)
//            workspace["projects"] = xs as CKRecordValue
//        }
    }
    
    static func getProjectRecordIDs(_ record: CKRecord) -> [CKRecord.ID] {
//        if let xs = record["projects"] as? [CKRecord.Reference] {
//            return xs.map { ref -> CKRecord.ID in ref.recordID }
//        }
        return []
    }
    
    func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Int64 { self.created = x }
        if let x = record["modified"] as? Int64 { self.modified = x }
        if let x = record["changeTag"] as? Int64 { self.changeTag = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["isActive"] as? Bool { self.isActive = x }
        if let x = record["isSyncEnabled"] as? Bool { self.isSyncEnabled = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}