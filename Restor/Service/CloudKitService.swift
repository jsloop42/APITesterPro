//
//  CloudKitService.swift
//  Restor
//
//  Created by jsloop on 22/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitDelegate: class {
}

class CloudKitService {
    static let shared = CloudKitService()
    let cloudKitContainerId = "iCloud.com.estoapps.ios.restor8"
    private var _privateDatabase: CKDatabase!
    private var _container: CKContainer!
    var zoneIDs: Set<CKRecordZone.ID> = Set()
    var zones: Set<CKRecordZone> = Set()
    var subscriptions: Set<CKSubscription> = Set()
    var zoneSubscriptions: [CKSubscription.ID: CKRecordZone.ID] = [:]
    private let nc = NotificationCenter.default
    private let kvstore = NSUbiquitousKeyValueStore.default
    weak var delegate: CloudKitDelegate?
    
    enum PropKey: String {
        case isZoneCreated
        case serverChangeToken
    }
    
    deinit {
        self.nc.removeObserver(self)
    }

    // MARK: - KV Store
    
    func getValue(key: String) -> Any? {
        return self.kvstore.object(forKey: key)
    }
    
    func saveValue(key: String, value: Any) {
        self.kvstore.set(value, forKey: key)
    }
    
    func removeValue(key: String) {
        self.kvstore.removeObject(forKey: key)
    }
    
    func addKVChangeObserver() {
        self.nc.addObserver(self, selector: #selector(self.kvStoreDidChange(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: self.kvstore)
    }
    
    @objc func kvStoreDidChange(_ notif: Notification) {
        Log.debug("kv store did change")
    }
    
    // MARK: - CloudKit setup
    
    func currentUsername() -> String {
        return CKCurrentUserDefaultName
    }
    
    func container() -> CKContainer {
        if self._container == nil { self._container = CKContainer(identifier: self.cloudKitContainerId) }
        return self._container
    }
    
    func privateDatabase() -> CKDatabase {
        if self._privateDatabase == nil { self._privateDatabase = self.container().privateCloudDatabase }
        return self._privateDatabase
    }
    
    // MARK: - Helper methods
    
    func accountStatus(completion: @escaping (Result<CKAccountStatus, Error>) -> Void) {
        CKContainer.default().accountStatus { status, error in
            if let err = error { completion(.failure(err)); return }
            completion(.success(status))
        }
    }
    
    func isZoneCreated(_ zoneID: CKRecordZone.ID) -> Bool {
        let key = "\(zoneID.zoneName)-created"
        return self.kvstore.bool(forKey: key)
    }
    
    func setZoneCreated(_ zoneID: CKRecordZone.ID) {
        let key = "\(zoneID.zoneName)-created"
        self.kvstore.set(true, forKey: key)
    }
    
    func removeZoneCreated(_ zoneID: CKRecordZone.ID) {
        let key = "\(zoneID.zoneName)-created"
        self.kvstore.removeObject(forKey: key)
    }
    
    func zoneID(with name: String) -> CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: name, ownerName: self.currentUsername())
    }
    
    func zoneID(workspaceId: String) -> CKRecordZone.ID {
        return CKRecordZone.ID(zoneName: "ws-\(workspaceId)", ownerName: self.currentUsername())
    }
    
    func recordID(entityId: String, zoneID: CKRecordZone.ID) -> CKRecord.ID {
        return CKRecord.ID(recordName: "\(entityId).\(zoneID.zoneName)", zoneID: zoneID)
    }
    
    func handleNotification(zoneID: CKRecordZone.ID) {
        var changeToken: CKServerChangeToken? = nil
        if let changeTokenData = UserDefaults.standard.data(forKey: PropKey.serverChangeToken.rawValue) {
            changeToken = NSKeyedUnarchiver.unarchiveObject(with: changeTokenData) as? CKServerChangeToken
        }
        let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
        options.previousServerChangeToken = changeToken
        let optionsMap = [zoneID: options]
        let op = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zoneID], optionsByRecordZoneID: optionsMap)
        op.fetchAllChanges = true
        op.qualityOfService = .utility
        op.recordChangedBlock = { record in
            Log.debug("record changed: \(record)")
        }
        op.recordZoneChangeTokensUpdatedBlock = { zoneID, changeToken, data in
            guard let changeToken = changeToken else { return }
            Log.debug("record zone change tokens updated")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            UserDefaults.standard.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.recordZoneFetchCompletionBlock = { zoneID, changeToken, data, more, error in
            guard error == nil else { return }
            guard let changeToken = changeToken else { return }
            Log.debug("record zone fetch completion")
            let changeTokenData = NSKeyedArchiver.archivedData(withRootObject: changeToken)
            UserDefaults.standard.set(changeTokenData, forKey: PropKey.serverChangeToken.rawValue)
        }
        op.fetchRecordZoneChangesCompletionBlock = { error in
            guard error == nil else { return }
            Log.debug("fetch record zone changes completion")
        }
        self.privateDatabase().add(op)
    }
    
    // MARK: - Create
    
    func createZone(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        let z = CKRecordZone(zoneID: recordZoneId)
        if !self.zones.contains(z) {
            let op = CKModifyRecordZonesOperation(recordZonesToSave: [z], recordZoneIDsToDelete: [])
            op.modifyRecordZonesCompletionBlock = { _, _, error in
                if let err = error {
                    Log.error("Error saving zone: \(err)")
                    completion(.failure(err))
                    return
                }
                Log.info("Zone created successfully: \(recordZoneId.zoneName)")
                self.zones.insert(z)
                completion(.success(z))
            }
            op.qualityOfService = .utility
            self.privateDatabase().add(op)
        } else {
            completion(.success(z))
        }
    }
    
    func fetchZone(recordZoneIDs: [CKRecordZone.ID], completion: @escaping (Result<[CKRecordZone.ID: CKRecordZone], Error>) -> Void) {
        let op = CKFetchRecordZonesOperation(recordZoneIDs: recordZoneIDs)
        op.qualityOfService = .utility
        op.fetchRecordZonesCompletionBlock = { res, error in
            if let err = error { completion(.failure(err)); return }
            if let hm = res { completion(.success(hm)) }
        }
        self.privateDatabase().add(op)
    }
    
    func createZoneIfNotExist(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<CKRecordZone, Error>) -> Void) {
        self.fetchZone(recordZoneIDs: [recordZoneId], completion: { result in
            switch result {
            case .success(let hm):
                if let zone = hm[recordZoneId] {
                    self.zones.insert(zone)
                    completion(.success(zone))
                } else {
                    completion(.failure(AppError.error))
                }
            case .failure(let error):
                if let err = error as? CKError, err.isZoneNotFound() {
                    self.createZone(recordZoneId: recordZoneId) { result in
                        switch result {
                        case .success(let zone):
                            completion(.success(zone))
                        case .failure(let err):
                            completion(.failure(err))
                        }
                    }
                }
            }
        })
    }
    
    // MARK - Save
    
    /// Saves the given record. If the record does not exists, then creates a new one, else updates the existing one after conflict resolution.
    func saveRecord(_ record: CKRecord, recordType: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: [])
        op.qualityOfService = .utility
        op.modifyRecordsCompletionBlock = { _, _, error in
            guard error == nil else {
                guard let ckerror = error as? CKError else { completion(.failure(error!)); return }
                if ckerror.isZoneNotFound() {  // Zone not found, create one
                    self.createZone(recordZoneId: record.recordID.zoneID) { result in
                        switch result {
                        case .success(_):
                            self.saveRecord(record, recordType: recordType, completion: completion)
                        case .failure(let error):
                            completion(.failure(error)); return
                        }
                    }
                } else if ckerror.isRecordExists() {
                    // TODO: merge in the changes, save the new record
                    completion(.failure(ckerror)); return
                }
                return
            }
            // Create subscription on the first record write, which will only subscribe if not done already.
            //self.saveSubscription(recordType: recordType)
            Log.info("Record saved successfully: \(record.recordID.recordName)")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
    }
    
    func getZoneNameFromSubscriptionID(_ subID: CKSubscription.ID) -> String {
        let name = subID.description
        let xs = name.components(separatedBy: ".")
        return xs.last ?? ""
    }
    
    /// Save subscription will be made only once for the given type.
    func saveSubscription(_ subId: String, recordType: String, zoneID: CKRecordZone.ID) {
        let subSavedKey = "\(recordType)-subscription-saved.\(zoneID.zoneName)"
        let isSaved = UserDefaults.standard.bool(forKey: subSavedKey)
        guard !isSaved else { return }
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: recordType, predicate: predicate, subscriptionID: subId,
                                               options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion,
                                                         CKQuerySubscription.Options.firesOnRecordUpdate])
        let notifInfo = CKSubscription.NotificationInfo()
        notifInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notifInfo
        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            guard error == nil else { return }
            UserDefaults.standard.set(true, forKey: subSavedKey)
            self.subscriptions.insert(subscription)
            self.zoneSubscriptions[subscription.subscriptionID] = zoneID
            Log.info("Subscribed to events successfully: \(recordType) with ID: \(subscription.subscriptionID.description)")
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    // MARK: - Delete
    
    func deleteZone(recordZoneId: CKRecordZone.ID, completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifyRecordZonesOperation(recordZonesToSave: [], recordZoneIDsToDelete: [recordZoneId])
        op.modifyRecordZonesCompletionBlock = { _, _, error in
            if let err = error {
                Log.error("Error deleting zone: \(err)")
                completion(.failure(err))
                return
            }
            Log.info("Zone deleted successfully: \(recordZoneId.zoneName)")
            if let idx = (self.zoneIDs.firstIndex { id -> Bool in id == recordZoneId }) {
                self.zoneIDs.remove(at: idx)
            }
            if let idx = (self.zones.firstIndex { zone -> Bool in zone.zoneID == recordZoneId }) {
                self.zones.remove(at: idx)
            }
            completion(.success(true))
        }
        op.qualityOfService = .utility
        self.privateDatabase().add(op)
    }
    
    func deleteRecord(recordID: CKRecord.ID, completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: [recordID])
        op.qualityOfService = .utility
        op.modifyRecordsCompletionBlock = { _, _, error in
            if let err = error { completion(.failure(err)); return }
            Log.info("Record deleted successfully: \(recordID.recordName)")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
    }
    
    func deleteSubscription(subscriptionID: CKSubscription.ID, completion: @escaping (Result<Bool, Error>) -> Void) {
        let op = CKModifySubscriptionsOperation.init(subscriptionsToSave: [], subscriptionIDsToDelete: [subscriptionID])
        op.qualityOfService = .utility
        op.modifySubscriptionsCompletionBlock = { _, _, error in
            if let err = error { completion(.failure(err)); return }
            self.zoneSubscriptions.removeValue(forKey: subscriptionID)
            Log.info("Subscription deleted successfully: \(subscriptionID.description)")
            completion(.success(true))
        }
        self.privateDatabase().add(op)
    }
}

extension CKError {
    public func isRecordNotFound() -> Bool {
        return self.isZoneNotFound() || self.isUnknownItem()
    }
    
    /// If a record already exists or a newer version of the record already exists.
    public func isRecordExists() -> Bool {
        return self.isSpecificErrorCode(code: .serverRecordChanged)
    }
    
    public func isZoneNotFound() -> Bool {
        return self.isSpecificErrorCode(code: .zoneNotFound)
    }
    
    public func isUnknownItem() -> Bool {
        return self.isSpecificErrorCode(code: .unknownItem)
    }
    
    public func isConflict() -> Bool {
        return self.isSpecificErrorCode(code: .serverRecordChanged)
    }
    
    public func isSpecificErrorCode(code: CKError.Code) -> Bool {
        var match = false
        if self.code == code {
            match = true
        } else if self.code == .partialFailure {
            // Error contains multiple issues. Check the underlying array of errors.
            guard let errors = self.partialErrorsByItemID else { return false }
            for (_, error) in errors {
                if let cke = error as? CKError {
                    if cke.code == code {
                        match = true
                        break
                    }
                }
            }
        }
        return match
    }
    
    public func getMergeRecords() -> (CKRecord?, CKRecord?) {
        if self.code == .serverRecordChanged { return (self.clientRecord, self.serverRecord) }
        guard self.code == .partialFailure else { return (nil, nil) }
        guard let errors = self.partialErrorsByItemID else { return (nil, nil) }
        for (_, error) in errors {
            if let cke = error as? CKError {
                if cke.code ==  .serverRecordChanged {
                    // Server record error within a partial failure error
                    return cke.getMergeRecords()
                }
            }
        }
        return (nil, nil)
    }
}
