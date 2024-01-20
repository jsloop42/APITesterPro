//
//  CloudSyncService.swift
//  APITesterPro
//
//  Created by Jaseem V V on 30/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

/// Holds cloudkit records to be saved and the completion handler. This model is passed to the save queue.
struct SaveQueueRecord {
    var records: [CKRecord] = []
    var completion: (Result<[CKRecord], Error>) -> Void
}

class CloudSyncService {
    static var shared = CloudSyncService()
    private lazy var ck = { EACloudKit.shared }()
    private var saveQueue: EAPopQueue<SaveQueueRecord>
    private let saveQueueSweepInterval = 1.0  // 1 second
    private let dispatchQueue = DispatchQueue(label: "net.jsloop.APITesterPro.CKSaveQueue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    
    init() {
        Log.debug("cloudsync init")
        self.saveQueue = EAPopQueue()
        self.saveQueue.setInterval(self.saveQueueSweepInterval)
        self.saveQueue.setBlock(self.saveToCloudHandler(_:))  // If the queue has save records, it will call this block at regular interval until the queue is empty.
        self.saveQueue.setQueue(self.dispatchQueue)
        self.saveQueue.startTimer()
    }
    
    deinit {
        Log.debug("cloudsync deinit")
    }
    
    /// This method should be called during app launch once so that cloudkit gets initialized.
    func bootstrap() {
        Log.debug("cloudsync bootstrap")
        self.ck.bootstrap(containerId: Const.cloudKitContainerID)
    }
    
    /// Save queue callback function with save record which needs to be saved to iCloud immediately.
    func saveToCloudHandler(_ saveRecord: SaveQueueRecord?) {
        guard let saveRecord else { return }
        self.ck.saveRecords(saveRecord.records, completion: saveRecord.completion)
    }
    
    /// Saves the given workspace to cloud. A corresponding Zone record will also be saved.
    func saveWorkspace(_ ws: EWorkspace) {
        // TODO: check icloud account status
        Task {
            let accStatus = try? await self.ck.accountStatus()
//            if !status {
//                Log.info("iCloud account fail: \(status)")
//                return
//            }
            Log.debug("ck save workspace \(ws.getId())")
            let ctx = ws.managedObjectContext!
            guard let ckWs = EWorkspace.getCKRecord(id: ws.getId(), ctx: ctx) else { Log.error("Error getting ckWs"); return }
            guard let ckZone = Zone.getCKRecord(id: ws.getId(), ctx: ctx) else { Log.error("Error getting ckZone"); return }
            // save queue record which takes a struct which holds ck records and a completion block to execute on save
            let saveRecord = SaveQueueRecord(records: [ckZone, ckWs], completion: self.workspaceSaveHandler(_:))
            self.saveQueue.enqueue(saveRecord)
        }
    }
    
    func workspaceSaveHandler(_ result: Result<[CKRecord], Error>) {
        switch result {
        case .success(_):
            Log.debug("workspace and zone saved to cloud")
        case .failure(let error):
            Log.error("error saving workspace or zone to cloud: \(error)")
            
        }
    }
    
}
