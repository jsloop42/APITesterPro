//
//  CoreDataService.swift
//  Restor
//
//  Created by jsloop on 01/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import CoreData

class CoreDataService {
    static var shared = CoreDataService()
    private var storeType: String! = NSSQLiteStoreType
    var persistentContainer: NSPersistentContainer!
    lazy var mainMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    lazy var bgMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    private let fetchBatchSize: Int = 50
    private let utils = Utils.shared
    var containerName = isRunningTests ? "RestorTest" : "Restor"
    
    init() {
        self.bootstrap()
    }
    
    init(containerName: String) {
        self.containerName = containerName
        self.bootstrap()
    }
    
    func bootstrap() {
        if let modelPath = Bundle(for: type(of: self)).path(forResource: "Restor", ofType: "momd") {
            let url = URL(fileURLWithPath: modelPath)
            if let model = NSManagedObjectModel(contentsOf: url) {
                self.persistentContainer = NSPersistentContainer(name: self.containerName, managedObjectModel: model)
            }
        } else {
            self.persistentContainer = NSPersistentContainer(name: "Restor")
        }
        let desc = self.persistentContainer.persistentStoreDescriptions.first
        desc?.type = self.storeType
        self.setup()
    }
    
    func setup(storeType: String = NSSQLiteStoreType, completion: (() -> Void)? = nil) {
        if (self.persistentContainer.persistentStoreCoordinator.persistentStores.firstIndex(where: { store -> Bool in store.type == storeType })) != nil {
            completion?()
        } else {
            self.storeType = storeType
            self.loadPersistentStore { completion?() }
        }
    }
    
    private func loadPersistentStore(completion: @escaping () -> Void) {
        // Handle data migration on a different thread/queue here
        self.persistentContainer.loadPersistentStores { description, error  in
            guard error == nil else { fatalError("Unable to load store \(error!)") }
            self.persistentContainer.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            completion()
        }
    }
    
    // MARK: - Sort
    
    /// Sort the given list of dictonaries in the order of created and update the index property.
    func sortByCreated(_ hm: inout [[String: Any]]) {
        hm.sort { (hma, hmb) -> Bool in
            if let c1 = hma["created"] as? Int64, let c2 = hmb["created"] as? Int64 { return c1 < c2 }
            return false
        }
        let len = hm.count
        for i in 0..<len { hm[i]["index"] = i.toInt64() }
    }
    
    /// Sort the given list of entities in the order of created and update the index property.
    func sortByCreated(_ xs: inout [Entity]) {
        xs.sort { (a, b) -> Bool in a.getCreated() < b.getCreated() }
        xs.enumerated().forEach { arg in arg.element.setIndex(arg.offset) }
    }
    
    func sortedByCreated(_ xs: [[String: Any]]) -> [[String: Any]] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    func sortedByCreated(_ xs: [Entity]) -> [Entity] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    // MARK: - To dictionary
    
    /// Can be used to get the initial value of the request before modification during edit
    func requestToDictionary(_ x: ERequest) -> [String: Any] {
        let attrs = ERequest.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.headers, let xs = set.allObjects as? [ERequestData] {
            dict["headers"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let set = x.params, let xs = set.allObjects as? [ERequestData] {
            dict["params"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        // TODO:
//        if let set = x.methods, let xs = set.allObjects as? [ERequestMethodData] {
//            dict["methods"] =  self.sortedByCreated(xs.map { y -> [String: Any] in self.requestMethodDataToDictionary(y) })
//        }
        if let body = x.body { dict["body"] = self.requestBodyDataToDictionary(body) }
        return dict
    }
    
    func requestMethodDataToDictionary(_ x: ERequestMethodData) -> [String: Any] {
        let attrs = ERequestMethodData.entity().attributesByName.map { arg -> String in arg.key }
        return x.dictionaryWithValues(forKeys: attrs)
    }
    
    func requestDataToDictionary(_ x: ERequestData) -> [String: Any] {
        let attrs = ERequestData.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.files, let xs = set.allObjects as? [EFile] {
            dict["files"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.fileToDictionary(y) })
        }
        if let image = x.image { dict["image"] = self.imageToDictionary(image) }
        return dict
    }
    
    func requestBodyDataToDictionary(_ x: ERequestBodyData) -> [String: Any] {
        let attrs = ERequestBodyData.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let set = x.form, let xs = set.allObjects as? [ERequestData] {
            dict["form"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let set = x.multipart, let xs = set.allObjects as? [ERequestData] {
            dict["multipart"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        return dict
    }
    
    func fileToDictionary(_ x: EFile) -> [String: Any] {
        let attrs = EFile.entity().attributesByName.compactMap { arg -> String? in
            if arg.key != "data" { return arg.key }  // The data is avoided to reduce memory footprint
            return nil
        }
        return x.dictionaryWithValues(forKeys: attrs)
    }
    
    func imageToDictionary(_ x: EImage) -> [String: Any] {
        let attrs = EImage.entity().attributesByName.compactMap { arg -> String? in
            if arg.key != "data" { return arg.key }
            return nil
        }
        let dict = x.dictionaryWithValues(forKeys: attrs)
        return dict
    }
    
    // MARK: - Get
    
    /// Get managed object with the given object Id with the given context.
    /// - Parameters:
    ///   - moId: The managed object Id of the entity.
    ///   - context: The managed object context used to access.
    func getManagedObject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> NSManagedObject {
        return context.object(with: moId)
    }
    
    // MARK: EWorkspace
    
    func getWorkspace(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EWorkspace? {
        var x: EWorkspace?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getAllWorkspaces(ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EWorkspace] {
        var xs: [EWorkspace] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return xs
    }
    
    /// Default entities will have the id "default"
    func getDefaultWorkspace(with project: Bool? = false) -> EWorkspace {
        var x: EWorkspace!
        self.bgMOC.performAndWait {
            if let ws = self.getWorkspace(id: "default") { x = ws; return }
            let ws: EWorkspace! = self.createWorkspace(id: "default", index: 0, name: "Default workspace", desc: "The default workspace")
            if let isProj = project, isProj {
                ws.projects = NSSet()
                ws.projects!.adding(self.getDefaultProject() as Any)
            }
            x = ws
        }
        return x
    }
    
    // MARK: EProject
    
    func getProject(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
        var x: EProject?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the project at the given index in the workspace.
    /// - Parameters:
    ///   - index: The project index.
    ///   - wsId: The workspace id.
    ///   - ctx: The managed object context.
    func getProject(at index: Int, wsId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
        var x: EProject?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "workspace.id == %@", wsId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting entities - \(error)")
            }
        }
        return x
    }
    
    /// Get project with the given managed object Id with the given context.
    /// - Parameters:
    ///   - moId: The managed object Id of the entity.
    ///   - context: The managed object context used to access.
    func getProject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> EProject? {
        return context.object(with: moId) as? EProject
    }
    
    /// Retrieves the projects belonging to the given workspace.
    /// - Parameters:
    ///   - wsId: The workspace id.
    ///   - ctx: The managed object context.
    func getProjects(wsId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "workspace.id == %@", wsId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entities - \(error)")
            }
        }
        return xs
    }
    
    func getDefaultProject() -> EProject {
        var x: EProject!
        self.bgMOC.performAndWait {
            if let proj = self.getProject(id: "default") { x = proj; return }
            x = self.createProject(id: "default", index: 0, name: "default", desc: "The default project")
        }
        return x
    }
    
    // MARK: ERequest
    
    func getRequest(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the requests in the given project.
    /// - Parameters:
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequests(projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequest] {
        var xs: [ERequest] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieve request at the given index for the project.
    /// - Parameters:
    ///   - index: The order index.
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequest(at index: Int, projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve the total requests count in the given project
    /// - Parameters:
    ///   - projectId: The project id.
    ///   - ctx: The managed object context.
    func getRequestsCount(projectId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id == %@", projectId)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
            }
        }
        return x
    }
    
    // MARK: ERequestData
    
    func getRequestData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestData(at index: Int, reqId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let typeKey: String = {
                switch type {
                case .header:
                    return "headers.id"
                case .param:
                    return "params.id"
                case .form:
                    return "form.request.id"
                case .multipart:
                    return "multipart.request.id"
                }
            }()
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "%K == %@", typeKey, reqId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    func getLastRequestData(type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "type == %d", type.rawValue.toInt32())
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Get the total request data count of the given type belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - type: The request data type.
    ///   - ctx: The managed object context.
    func getRequestDataCount(reqId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let typeKey: String = {
                switch type {
                case .header:
                    return "headers.id"
                case .param:
                    return "params.id"
                case .form:
                    return "form.request.id"
                case .multipart:
                    return "multipart.request.id"
                }
            }()
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "%K == %@", typeKey, reqId)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve form data for the given request body.
    /// - Parameters:
    ///   - bodyDataId: The request body data id.
    ///   - ctx: The managed object context of the request body data object.
    func getFormRequestData(_ bodyDataId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "form.id == %@ AND type == %d", bodyDataId, type.rawValue.toInt32())  // ERequestBodyData.id
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching form request data: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the form at the given index.
    /// - Parameters:
    ///   - index: The index of the form.
    ///   - bodyDataId: The request body data id.
    ///   - type: The request data type (form, multipart)
    ///   - ctx: The managed object context.
    func getFormRequestData(at index: Int, bodyDataId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC)
        -> ERequestData? {
        var x: ERequestData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let typeKey: String = {
                if type == .form {
                    return "form.id"
                }
                return "multipart.id"
            }()
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "%K == %@ AND type == %d", typeKey, bodyDataId, type.rawValue.toInt32())
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves the headers belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - ctx: The managed object context.
    func getHeadersRequestData(_ reqId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "headers.id == %@", reqId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching headers request data: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the params belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - ctx: The managed object context.
    func getParamsRequestData(_ reqId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = NSPredicate(format: "params.id == %@", reqId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error fetching params request data: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequestMethodData
    
    /// Retrieve the request method data for the given id.
    /// - Parameters:
    ///   - id: The request method data id.
    ///   - ctx: The managed object context.
    func getRequestMethodData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Retrieves request method data belonging to the given request.
    /// - Parameters:
    ///   - reqId: The request id.
    ///   - ctx: The managed object context.
    func getRequestMethodData(reqId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "request.id == %@", reqId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves request method data belonging to the given project.
    /// - Parameters:
    ///   - projId: The project id.
    ///   - ctx: The managed object context.
    func getRequestMethodData(projId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "project.id == %@", projId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieve the request method data.
    /// - Parameters:
    ///   - index: The index of the method.
    ///   - projId: The project id.
    ///   - ctx: The managed object context.
    func getRequestMethodData(at index: Int, projId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "project.id == %@", projId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error getting request method data: \(error)")
            }
        }
        return x
    }
    
    /// Get the count for requests with the given request method data selected.
    /// - Parameters:
    ///   - methodDataId: The request method data id.
    ///   - index: The method index which will be the selected method index in the request.
    ///   - ctx: The managed object context.
    func getRequestsCountForRequestMethodData(index: Int64? = Const.defaultRequestMethodsCount.toInt64(), ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "selectedMethodIndex == %ld", index!)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting getting request count for the method: \(error)")
            }
        }
        return x
    }
    
    // MARK: ERequestBodyData
    
    func getRequestBodyData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    // MARK: EFile
    
    /// Get the total number of files in the given request data.
    /// - Parameters:
    ///   - reqDataId: The request data id.
    ///   - type: The `RequestDataType` indicating whether it is a `file` or a `multipart`
    ///   - ctx: The managed object context of the request data.
    func getFilesCount(_ reqDataId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> Int {
        var x: Int = 0
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@ AND type == %d", reqDataId, type.rawValue.toInt32())
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting files count: \(error)")
            }
        }
        return x
    }
    
    /// Get files for the given request data.
    /// - Parameters:
    ///   - reqDataId: The request data id.
    ///   - type: The `RequestDataType` indicating whether it is a `file` or a `multipart`
    ///   - ctx: The managed object context of the request data.
    func getFiles(_ reqDataId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@ AND type == %d", reqDataId, type.rawValue.toInt32())
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting files: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves the file at the given index.
    /// - Parameters:
    ///   - index: The index of the file in the request data list.
    ///   - reqDataId: The request data id.
    ///   - ctx: The managed object context.
    func getFile(at index: Int, reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EFile? {
        var x: EFile?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData.id == %@", reqDataId)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                let xs = try moc.fetch(fr)
                if xs.count > index { x = xs[index] }
            } catch let error {
                Log.error("Error fetching request: \(error)")
            }
        }
        return x
    }
    
    /// Retrieve file object for the given file id.
    /// - Parameters:
    ///   - id: The file object id.
    ///   - ctx: The managed object context.
    func getFileData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EFile? {
        var x: EFile?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching file: \(error)")
            }
        }
        return x
    }
    
    // MARK: EImage
    
    /// Retrieve image object for the given image id.
    /// - Parameters:
    ///   - id: The image object id.
    ///   - ctx: The managed object context.
    func getImageData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EImage? {
        var x: EImage?
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fr = NSFetchRequest<EImage>(entityName: "EImage")
            fr.predicate = NSPredicate(format: "id == %@", id)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching image: \(error)")
            }
        }
        return x
    }
    
    // MARK: - Create
    
    /// Create workspace.
    /// - Parameters:
    ///   - id: The workspace id.
    ///   - index: The order of the workspace.
    ///   - name: The workspace name.
    ///   - name: The workspace description.
    ///   - checkExists: Check whether the workspace exists before creating.
    func createWorkspace(id: String, index: Int, name: String, desc: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC)  -> EWorkspace? {
        var x: EWorkspace?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExist = checkExists, isExist, let ws = self.getWorkspace(id: id, ctx: ctx) { x = ws }
            let ws = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "EWorkspace", into: moc) as! EWorkspace
            ws.id = id
            ws.index = index.toInt64()
            ws.name = name
            ws.desc = desc
            ws.created = x == nil ? ts : x!.created
            ws.modified = ts
            ws.version = x == nil ? 0 : x!.version + 1
            x = ws
        }
        return x
    }
    
    /// Create project.
    /// - Parameters:
    ///   - id: The project id.
    ///   - index: The order of the project.
    ///   - name: The project name.
    ///   - desc: The project description.
    ///   - ws: The workspace to which the project belongs.
    ///   - checkExists: Check if the given project exists before creating.
    func createProject(id: String, index: Int, name: String, desc: String, ws: EWorkspace? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EProject? {
        var x: EProject?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExist = checkExists, isExist, let proj = self.getProject(id: id, ctx: ctx) { x = proj }
            let proj = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "EProject", into: moc) as! EProject
            proj.id = id
            proj.index = index.toInt64()
            proj.name = name
            proj.desc = desc
            proj.created = x == nil ? ts : x!.created
            proj.modified = ts
            proj.version = x == nil ? 0 : x!.version + 1
            ws?.addToProjects(proj)
            _ = self.genDefaultRequestMethods(proj, ctx: moc)
            x = proj
        }
        return x
    }
    
    
    /// Create a request
    /// - Parameters:
    ///   - id: The request id.
    ///   - name: The name of the request.
    ///   - project: The project to which the request belongs to.
    ///   - checkExists: Check if the request exists before creating one.
    ///   - ctx: The managed object context
    func createRequest(id: String, index: Int, name: String, project: EProject? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequest? {
        var x: ERequest?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let req = self.getRequest(id: id, ctx: ctx) { x = req }
            let req = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "ERequest", into: moc) as! ERequest
            req.id = id
            req.index = index.toInt64()
            req.name = name
            req.created = x == nil ? ts : x!.created
            req.modified = ts
            req.version = x == nil ? 0 : x!.version + 1
            project?.addToRequests(req)
//            if req.methods == nil { req.methods = NSSet() }
//            if req.methods!.count == 0 {
//                req.methods?.addingObjects(from: self.genDefaultRequestMethods(req, ctx: moc))
//            }
            x = req
        }
        return x
    }
        
    /// Create request data.
    /// - Parameters:
    ///   - id: The request data id.
    ///   - index: The index of the request data.
    ///   - type: The request data type.
    ///   - checkExists: Check for existing request data object.
    ///   - ctx: The managed object context.
    func createRequestData(id: String, index: Int, type: RequestDataType, fieldFormat: RequestBodyFormFieldFormatType, checkExists: Bool? = true,
                           ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestData? {
        var x: ERequestData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "ERequestData", into: moc) as! ERequestData
            data.id = id
            data.index = index.toInt64()
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.version = x == nil ? 0 : x!.version + 1
            data.fieldFormat = fieldFormat.rawValue.toInt64()
            data.type = type.rawValue.toInt64()
            x = data
            Log.debug("RequestData \(x == nil ? "created" : "updated"): \(x!)")
        }
        return x
    }
    
    func genDefaultRequestMethods(_ proj: EProject, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> [ERequestMethodData] {
        let names = ["GET", "POST", "PUT", "PATCH", "DELETE"]
        guard let projId = proj.id else { return [] }
        return names.enumerated().compactMap { arg -> ERequestMethodData? in
            let (offset, element) = arg
            let x = self.createRequestMethodData(id: self.genRequestMethodDataId(projId, methodName: element), index: offset, name: element, isCustom: false, ctx: ctx)
            x?.project = proj
            return x
        }
    }
    
    /// Crate request method data
    /// - Parameters:
    ///   - id: The request method data id.
    ///   - index: The order of the request method data.
    ///   - name: The name of the request method data.
    ///   - checkExists: Check if the request method data exists
    ///   - ctx: The managed object context
    func createRequestMethodData(id: String, index: Int, name: String, isCustom: Bool? = true, checkExists: Bool? = true,
                                 ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestMethodData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "ERequestMethodData", into: moc) as! ERequestMethodData
            data.id = id
            data.isCustom = isCustom ?? true
            data.index = index.toInt64()
            data.name = name
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.version = x == nil ? 0 : x!.version + 1
            x = data
        }
        return x
    }
    
    /// Create request body data.
    /// - Parameters:
    ///   - id: The request body data id.
    ///   - index: The order of the request body data.
    ///   - checkExists: Check if the request body data exists before creating.
    ///   - ctx: The managed object context.
    func createRequestBodyData(id: String, index: Int, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestBodyData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "ERequestBodyData", into: moc) as! ERequestBodyData
            data.id = id
            data.index = index.toInt64()
            data.created = x == nil ? ts : x!.created
            data.modified = ts
            data.version = x == nil ? 0 : x!.version + 1
            x = data
        }
        return x
    }
    
    /// Create an image object with the given image data.
    /// - Parameters:
    ///   - data: The image data
    ///   - index: The image index
    ///   - type: The image type (png, jpg, etc.)
    ///   - checkExists: Check if the image exists already before creating
    ///   - ctx: The managed object context
    func createImage(data: Data, index: Int, type: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EImage? {
        var x: EImage?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let imageId = self.genImageId(data)
            if let isExists = checkExists, isExists, let data = self.getImageData(id: imageId, ctx: ctx) { x = data }
            let image = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "EImage", into: moc) as! EImage
            image.id = imageId
            image.data = data
            image.type = type
            image.created = x == nil ? ts : x!.created
            image.modified = ts
            image.version = x == nil ? 0 : x!.version + 1
            image.index = index.toInt64()
            x = image
        }
        return x
    }
    
    func createFile(data: Data, index: Int, name: String, path: URL, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EFile? {
        return self.createFile(data: data, index: index, name: name, path: path, type: .form, checkExists: checkExists, ctx: ctx)
    }
    
    func createFile(data: Data, index: Int, name: String, path: URL, type: RequestDataType, checkExists: Bool? = true,
                    ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) -> EFile? {
        var x: EFile?
        let ts = Date().currentTimeNanos()
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            let fileId = self.genFileId(data)
            if let isExists = checkExists, isExists, let data = self.getFileData(id: fileId, ctx: ctx) { x = data }
            let file = x != nil ? x! : NSEntityDescription.insertNewObject(forEntityName: "EFile", into: moc) as! EFile
            file.id = fileId
            file.data = data
            file.created = x == nil ? ts : x!.created
            file.modified = ts
            file.index = index.toInt64()
            file.name = name
            file.path = path
            file.type = type.rawValue.toInt64()
            file.version = x == nil ? 0 : x!.version + 1
            x = file
        }
        return x
    }
    
    // MARK: - Generate Id
    
    func genRequestMethodDataId(_ reqId: String, methodName: String) -> String {
        return "\(reqId)-\(methodName)"
    }
    
    /// Generates the image id for the given image data.
    /// - Parameter data: The image data
    func genImageId(_ data: Data) -> String {
        return self.utils.md5(data: data)
    }
    
    /// Generates the file id for the given file data.
    /// - Parameter data: The file data
    func genFileId(_ data: Data) -> String {
        return self.utils.md5(data: data)
    }
    
    // MARK: - Save
    
    func saveMainContext(_ callback: ((Bool) -> Void)? = nil) {
        Log.debug("save main context")
        if self.mainMOC.hasChanges {
            self.mainMOC.perform {
                do {
                    Log.debug("main context has changes")
                    try self.mainMOC.save()
                    self.mainMOC.processPendingChanges()
                    Log.debug("main context saved")
                } catch {
                    let nserror = error as NSError
                    Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                    if let cb = callback { cb(false) }
                    return
                }
            }
        } else {
            if let cb = callback { cb(true) }
        }
    }
    
    /// Save the managed object context associated with the given entity and remove it from the cache.
    func saveBackgroundContext(isForce: Bool? = false, callback: ((Bool) -> Void)? = nil) {
        Log.debug("save bg context")
        var status = true
        let isForceSave = isForce ?? false
        if self.bgMOC.hasChanges {
            let fn: () -> Void = {
                do {
                    Log.debug("bg context has changes")
                    try self.bgMOC.save()
                    self.bgMOC.processPendingChanges()
                    Log.debug("bg context saved")
                    if isForceSave {
                        self.saveMainContext()
                    } else {
                        Log.debug("scheduling main context save")
                        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { t in
                            t.invalidate()
                            self.saveMainContext()
                        }
                    }
                } catch {
                    status = false
                    let nserror = error as NSError
                    Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                    if let cb = callback { cb(status) }
                    return
                }
            }
            isForceSave ? self.bgMOC.performAndWait { fn() } : self.bgMOC.perform { fn() }
        } else {
            if let cb = callback { cb(status) }
        }
    }
        
    // MARK: - Delete
    
    /// Resets the context to its base state if there are any changes.
    func discardChanges(in context: NSManagedObjectContext) {
        if context.hasChanges { context.performAndWait { context.rollback() } }
    }
    
    /// Discard changes to the given entity in the managed object context.
    /// - Parameters:
    ///   - entity: The managed object
    ///   - context: The managed object context.
    func discardChanges(for entity: NSManagedObject, inContext context: NSManagedObjectContext) {
        context.performAndWait { context.refresh(entity, mergeChanges: false) }
    }
    
    func discardChanges(for objects: Set<NSManagedObjectID>, inContext context: NSManagedObjectContext) {
        context.performAndWait { objects.forEach { oid in self.discardChanges(for: context.object(with: oid), inContext: context) } }
    }
    
    func deleteEntity(_ entity: NSManagedObject?) {
        Log.debug("delete entity: \(String(describing: entity))")
        if let x = entity, let moc = x.managedObjectContext {
            moc.performAndWait { moc.delete(x) }
        }
    }
    
    func deleteRequestData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) {
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        if let x = self.getRequestData(id: id, ctx: moc) {
            moc.performAndWait { moc.delete(x) }
        }
    }
    
    func deleteRequestData(at index: Int, req: ERequest, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) {
        guard let reqId = req.id else { return }
        Log.debug("delete request data: \(index) reqBodyId \(reqId)")
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            var x: ERequestData?
            // Since deleting in-between elems can change the table count, we cannot fetch by index. Instead we fetch the whole list and get the element at the
            // given index and removes it
            switch type {
            case .header:
                let xs = self.getHeadersRequestData(reqId, ctx: ctx)
                if xs.count > index { x = xs[index] }
                if x != nil { req.removeFromHeaders(x!) }
            case .param:
                let xs = self.getParamsRequestData(reqId, ctx: ctx)
                if xs.count > index { x = xs[index] }
                if x != nil { req.removeFromParams(x!) }
            case .form:
                if let bodyId = req.body?.id {
                    let xs = self.getFormRequestData(bodyId, type: .form, ctx: ctx)
                    if xs.count > index { x = xs[index] }
                    if x != nil { req.body?.removeFromForm(x!) }
                }
            case .multipart:
                if let bodyId = req.body?.id {
                    let xs = self.getFormRequestData(bodyId, type: .multipart, ctx: ctx)
                    if xs.count > index { x = xs[index] }
                    if x != nil { req.body?.removeFromMultipart(x!) }
                }
                break
            }
            if x != nil { moc.delete(x!) }
        }
    }
    
    /// Delete the entity with the given id.
    /// - Parameters:
    ///   - dataId: The entity id. If the entity could be `RequestData` or `RequestBodyData`.
    ///   - req: The request to which the entity belongs.
    ///   - type: The entity type.
    ///   - ctx: The managed object context.
    func deleteRequestData(dataId: String, req: ERequest, type: RequestCellType, ctx: NSManagedObjectContext? = CoreDataService.shared.bgMOC) {
        let moc: NSManagedObjectContext = {
            if ctx != nil { return ctx! }
            return self.bgMOC
        }()
        moc.performAndWait {
            var x: Entity?
            switch type {
            case .header:
                x = self.getRequestData(id: dataId, ctx: moc)
                if let y = x as? ERequestData { req.removeFromHeaders(y) }
            case .param:
                x = self.getRequestData(id: dataId, ctx: ctx)
                if let y = x as? ERequestData { req.removeFromParams(y) }
            case .body:
                x = self.getRequestBodyData(id: dataId, ctx: moc)
                if x != nil { req.body = nil }
            default:
                break
            }
            if let y = x { moc.delete(y) }
            Log.debug("Deleted data id: \(dataId)")
        }
    }
}