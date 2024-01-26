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
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {
        Log.debug("cd: model migration from v1 to v2")
        if (sInstance.entity.name == "EWorkspace") {
            // Since we are creating new object, we need to copy all properties from the source to the new destination object manually.
            // If we want to instead update only one property we can also use the FUNCTION in the attribute mapping in the mapping file.
            let dInstance = NSEntityDescription.insertNewObject(forEntityName: mapping.destinationEntityName!, into: manager.destinationContext)
            dInstance.setValue(sInstance.value(forKey: "created"), forKey: "created")
            dInstance.setValue(sInstance.value(forKey: "desc"), forKey: "desc")
            dInstance.setValue(sInstance.value(forKey: "id"), forKey: "id")
            dInstance.setValue(sInstance.value(forKey: "isActive"), forKey: "isActive")
            // migrating this to value set as false
            dInstance.setValue(false, forKey: "isSyncEnabled")
            dInstance.setValue(sInstance.value(forKey: "markForDelete"), forKey: "markForDelete")
            dInstance.setValue(sInstance.value(forKey: "modified"), forKey: "modified")
            dInstance.setValue(sInstance.value(forKey: "name"), forKey: "name")
            dInstance.setValue(sInstance.value(forKey: "order"), forKey: "order")
            dInstance.setValue(sInstance.value(forKey: "saveResponse"), forKey: "saveResponse")
            dInstance.setValue(sInstance.value(forKey: "syncDisabled"), forKey: "syncDisabled")
            dInstance.setValue(sInstance.value(forKey: "version"), forKey: "version")
            Log.debug("cd: model migration workspace: set isSyncEnabled to false for \(String(describing: sInstance.value(forKey: "name")))")
            manager.associate(sourceInstance: sInstance, withDestinationInstance: dInstance, for: mapping)
        } else {
             Log.debug("cd: model migration: no custom change")
            try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)
        }
    }
}

