//
//  Zone.swift
//  APITesterPro
//
//  Created by Jaseem V V on 29/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

/// This is a zone file which will be added as a record in the default zone against each custom zone created which corresponds to each workspace
/// This helps in fetching records with a cursor instead of having to fetch all custom zone to get the workspaces list.
struct Zone {
    static var db: CoreDataService = { CoreDataService.shared }()
    static var ck: EACloudKit = { EACloudKit.shared }()
    var id: String  // The workspace Id
    /// Since zone corresponds to workspace, and we are fetching this, fields like name, desc are added here to make things faster. We don't however keep the
    /// workspace as such in the default zone because we need atomic operations and references.
    var name: String
    var desc: String
    var isSyncEnabled: Bool
    /// If a workspace is deleted if we delete the zone record in the default zone, we cannot propagate the delete change to other devices on sync. So we instead set this flag and keep the zone record.
    /// The workspace zone will be deleted on deleting the workspace. If this flag is set on sync, all local data can be deleted.
    var isDisabled: Bool
    var created: Date = Date()  // date in UTC
    var modified: Date = Date()
    var version: Int64 = CoreDataService.modelVersion
    
    static func fromWorkspace(_ ws: EWorkspace) -> Zone {
        var id = ""
        var name = ""
        var desc = ""
        var isSyncEnabled = true
        var isDisabled = false
        var created = Date()
        var modified = Date()
        let version = CoreDataService.modelVersion
        ws.managedObjectContext?.performAndWait {
            id = ws.getId()
            name = ws.getName()
            desc = ws.desc ?? ""
            isSyncEnabled = ws.isSyncEnabled
            isDisabled = ws.markForDelete
            created = ws.getCreatedUTC()
            modified = ws.getModitiedUTC()
        }
        return Zone(id: id, name: name, desc: desc, isSyncEnabled: isSyncEnabled, isDisabled: isDisabled, created: created, modified: modified, version: version)
    }
    
    /// Get zone record for the given workspace Id
    static func getCKRecord(id: String, ctx: NSManagedObjectContext) -> CKRecord? {
        var ws: EWorkspace!
        let zoneID = self.ck.defaultZoneID()
        let ckZoneID = self.ck.recordID(entityId: id, zoneID: zoneID)  // record ID
        var ckZone: CKRecord!
        ctx.performAndWait {
            ws = self.db.getWorkspace(id: id, ctx: ctx)
            let zone = Zone.fromWorkspace(ws)
            ckZone = self.ck.createRecord(recordID: ckZoneID, recordType: RecordType.zone.rawValue)
            zone.updateCKRecord(ckZone)
        }
        return ckZone
    }
    
    func updateCKRecord(_ record: CKRecord) {
        record["created"] = self.created as CKRecordValue
        record["desc"] = self.desc as CKRecordValue
        record["id"] = self.id as CKRecordValue
        record["isDisabled"] = self.isDisabled as CKRecordValue
        record["isSyncEnabled"] = self.isSyncEnabled as CKRecordValue
        record["modified"] = self.modified as CKRecordValue
        record["name"] = self.name as CKRecordValue
        record["version"] = self.version as CKRecordValue
    }
    
    mutating func updateFromCKRecord(_ record: CKRecord) {
        if let x = record["created"] as? Date { self.created = x }
        if let x = record["desc"] as? String { self.desc = x }
        if let x = record["id"] as? String { self.id = x }
        if let x = record["isDisabled"] as? Bool { self.isDisabled = x }
        if let x = record["isSyncEnabled"] as? Bool { self.isSyncEnabled = x }
        if let x = record["modified"] as? Date { self.modified = x }
        if let x = record["name"] as? String { self.name = x }
        if let x = record["version"] as? Int64 { self.version = x }
    }
}
