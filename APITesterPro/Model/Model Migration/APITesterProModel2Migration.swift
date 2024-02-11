//
//  APITesterProModel2Migration.swift
//  APITesterPro
//
//  Created by Jaseem V V on 26/01/24.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

class APITesterProModel2WorkspaceMigration: NSEntityMigrationPolicy {
    private let cdUtils = EACoreDataUtils.shared
    private lazy var app = { App.shared }()
    private lazy var localdb = { CoreDataService.shared }()
    private let nc = NotificationCenter.default
    
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        Log.debug("cd: model migration from v1 to v2")
        if (sInstance.entity.name == "EWorkspace") {
            // Since we are creating new object, we need to copy all properties from the source to the new destination object manually.
            // If we want to instead update only one property we can also use the FUNCTION in the attribute mapping in the mapping file.
            var dInstance = NSEntityDescription.insertNewObject(forEntityName: mapping.destinationEntityName!, into: manager.destinationContext)
            dInstance = cdUtils.copyAttributeValues(src: sInstance, dest: dInstance)
            // migrating this to value set as false
            dInstance.setValue(false, forKey: "isSyncEnabled")
            Log.debug("cd: model migration workspace: set isSyncEnabled to false for \(String(describing: sInstance.value(forKey: "name")))")
            AppState.currentWorkspace = nil
            self.app.saveSelectedWorkspaceId(self.localdb.defaultWorkspaceId)
            self.app.saveSelectedWorkspaceContainer(.local)
            self.nc.post(name: .workspaceDidSync, object: self)
            manager.associate(sourceInstance: sInstance, withDestinationInstance: dInstance, for: mapping)
        } else {
             Log.debug("cd: model migration: no custom change")
            try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        }
    }
}

