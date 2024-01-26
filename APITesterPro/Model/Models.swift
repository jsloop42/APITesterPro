//
//  Models.swift
//  APITesterPro
//
//  Created by Jaseem V V on 17/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CloudKit

/// Used to hold the current attachment details being processed to avoid duplicates
struct AttachmentInfo {
    /// List of URLs for document attachment type
    var docs: [URL] = []
    /// Contains the file name for comparison. Cannot compare URL as the path gets auto generated each time.
    var docNames: [String] = []
    /// Photo or camera attachment
    var image: UIImage?
    /// kUTTypeImage
    var imageType: String = "png"
    /// If camera is chosen
    var isCameraMode: Bool = false
    /// The index of data in the model
    var modelIndex: Int = 0
    /// The body form field model `RequestData` id.
    var reqDataId = ""
    
    mutating func copyFromState() {
        self.docs = DocumentPickerState.docs
        self.docNames = self.docs.map({ url -> String in App.shared.getFileName(url) })
        self.image = DocumentPickerState.image
        self.imageType = DocumentPickerState.imageType
        self.isCameraMode = DocumentPickerState.isCameraMode
        self.modelIndex = DocumentPickerState.modelIndex
        self.reqDataId = DocumentPickerState.reqDataId
    }
    
    /// Checks if the current state is same as the picker state
    func isSame() -> Bool {
        if DocumentPickerState.image != nil {
            return self.image == DocumentPickerState.image
        } else {
            if self.image == nil && DocumentPickerState.docs.isEmpty { return true }
        }
        let len = DocumentPickerState.docs.count
        if self.docs.count != len { return false }
        for i in 0..<len {
            if self.docNames[i] != App.shared.getFileName(DocumentPickerState.docs[i]) { return false }
        }
        return true
    }
    
    mutating func clear() {
        self.docs = []
        self.docNames = []
        self.image = nil
        self.imageType = "png"
        self.isCameraMode = false
        self.modelIndex = 0
        self.reqDataId = ""
    }
}

public protocol Entity: NSManagedObject, Hashable {
    var recordType: String { get }
    func getId() -> String
    func getWsId() -> String
    func setWsId(_ id: String)
    func getName() -> String
    /// Returns date converted to user's local time zone
    func getCreated() -> Date
    func getCreatedUTC() -> Date
    /// Returns date converted to user's local time zone
    func getModified() -> Date
    func getModitiedUTC() -> Date
    /// The modified fields get update on changing any property or relation. The date is in user's time zone.
    func setModified(_ date: Date)
    func setModifiedUTC(_ date: Date)
    func getVersion() -> Int64
    func getZoneID() -> CKRecordZone.ID
    func getRecordID() -> CKRecord.ID
    func setMarkedForDelete(_ status: Bool)
    func willSave()
//    func fromDictionary(_ dict: [String: Any])
//    func toDictionary() -> [String: Any]
}

extension Entity {
    public func getZoneID() -> CKRecordZone.ID {
        return EACloudKit.shared.zoneID(workspaceId: self.getWsId())
    }
    
    public func getRecordID() -> CKRecord.ID {
        return EACloudKit.shared.recordID(entityId: self.getId(), zoneID: self.getZoneID())
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }
    
    // Hashable conformance
    public static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.isEqual(rhs)
    }
}

