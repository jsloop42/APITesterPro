//
//  EACoreDataUtils.swift
//  APITesterPro
//
//  Created by Jaseem V V on 27/01/24.
//  Copyright © 2024 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

/// Helper methods to work with CoreData 
class EACoreDataUtils {
    static let shared = EACoreDataUtils()
    
    /// Copies all attribute values from the source object to destination object for the attributes in destination object
    func copyAttributeValues(src: NSManagedObject, dest: NSManagedObject) -> NSManagedObject {
        let srcAttribKeys = Array(src.entity.attributesByName.keys)
        let srcAttribValues = src.dictionaryWithValues(forKeys: srcAttribKeys)
        let destAttribKeys = Array(dest.entity.attributesByName.keys)
        for key in destAttribKeys {
            dest.setValue(srcAttribValues[key], forKey: key)
        }
        return dest
    }
}
