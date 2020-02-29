//
//  Project.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Project {
    var created: Int64
    var desc: String = ""
    var name: String
    var modified: Int64
    weak var workspace: Workspace?
    var requests: [Request] = []
    var version: Int64
    
    init(name: String, desc: String, workspace: Workspace) {
        self.name = name
        self.desc = desc
        self.workspace = workspace
        self.created = Date().currentTimeMillis()
        self.modified = self.created
        self.version = 0
    }
}
