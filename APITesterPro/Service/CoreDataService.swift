//
//  CoreDataService.swift
//  APITesterPro
//
//  Created by Jaseem V V on 01/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

/**
 Entites Association
 - EWorkspace
   - EEnv
     - EEnvVar
   - EProject
     - ERequestMethodData
     - ERequest
       - headers [ERequestData]
       - params [ERequestData]
       - body ERequestBodyData
         - forms [ERequestData]
           - files [EFile]
           - image [EImage]
         - binary ERequestData
         - multipart [ERequestData]
       - History EHistory
 */

public enum RecordType: String, Hashable {
    case file = "File"
    case image = "Image"
    case project = "Project"
    case request = "Request"
    case requestBodyData = "RequestBodyData"
    case requestData = "RequestData"
    case requestMethodData = "RequestMethodData"
    case workspace = "Workspace"
    case history = "History"
    case env = "Env"
    case envVar = "EnvVar"
    // CloudKit specific
    case zone = "Zone"
    
    static func from(id: String) -> RecordType? {
        if id == "default" { return .workspace }
        switch id.prefix(2) {
        case "ws":
            return self.workspace
        case "pj":
            return self.project
        case "rq":
            return self.request
        case "rb":
            return self.requestBodyData
        case "rd":
            return self.requestData
        case "rm":
            return self.requestMethodData
        case "fl":
            return self.file
        case "im":
            return self.image
        case "zn":
            return self.zone
        case "hs":
            return self.history
        case "en":
            return self.env
        case "ev":
            return self.envVar
        default:
            return nil
        }
    }
    
    static func prefix(for type: RecordType) -> String {
        switch type {
        case .workspace:
            return "ws"
        case .project:
            return "pj"
        case .request:
            return "rq"
        case .requestBodyData:
            return "rb"
        case .requestData:
            return "rd"
        case .requestMethodData:
            return "rm"
        case .file:
            return "fl"
        case .image:
            return "im"
        case .zone:
            return "zn"
        case .history:
            return "hs"
        case .env:
            return "en"
        case .envVar:
            return "ev"
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.rawValue)
    }
    
    static subscript(_ type: String) -> RecordType? {
        return RecordType(rawValue: type)
    }
    
    static func isWorkspace(id: String) -> Bool {
        return RecordType.from(id: id) == RecordType.workspace
    }
    
    /// All data record type
    static let allCases: [RecordType] = [RecordType.workspace, RecordType.project, RecordType.request, RecordType.requestBodyData, RecordType.requestData,
                                         RecordType.requestMethodData, RecordType.file, RecordType.image, RecordType.env, RecordType.envVar]
}

/// Entity sort order used in fetch request sort descriptor
public enum SortOrder: String {
    case order = "order"
    case created = "created"
}

public enum CoreDataContainer: String {
    case local = "local"
    case cloud = "cloud"
}

class CoreDataService {
    static let shared = CoreDataService()
    private var storeType: String! = NSSQLiteStoreType
    lazy var peristentContainerTest: NSPersistentContainer = {
        return NSPersistentContainer(name: self.containerName, managedObjectModel: self.model)
    }()
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: self.containerName, managedObjectModel: self.model)
        let localStoreDescription: NSPersistentStoreDescription!
        if let desc = container.persistentStoreDescriptions.first {
            localStoreDescription = desc
        } else {
            localStoreDescription = NSPersistentStoreDescription()
        }
        localStoreDescription.type = NSSQLiteStoreType
        localStoreDescription.shouldMigrateStoreAutomatically = true
        localStoreDescription.shouldInferMappingModelAutomatically = true
        // localStoreDescription.configuration = self.localConfigurationName  // Existing default is PF_DEFAULT_CONFIGURATION_NAME. To prevent any issues this is not set now.
        if (container.persistentStoreDescriptions.first == nil) {
            container.persistentStoreDescriptions = [localStoreDescription]
        }
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load local persistent store: \(error)")
            }
        }
        return container
    }()
    lazy var ckPersistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: self.ckContainerName, managedObjectModel: self.model)
        let cloudStoreDescription: NSPersistentStoreDescription!
        if let desc = container.persistentStoreDescriptions.first {
            cloudStoreDescription = desc
        } else {
            cloudStoreDescription = NSPersistentStoreDescription()
        }
        cloudStoreDescription.type = NSSQLiteStoreType
        cloudStoreDescription.shouldMigrateStoreAutomatically = true
        cloudStoreDescription.shouldInferMappingModelAutomatically = true
        cloudStoreDescription.configuration = self.cloudConfigurationName
        cloudStoreDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: self.cloudKitContainerId)
        if (container.persistentStoreDescriptions.first == nil) {
            container.persistentStoreDescriptions = [cloudStoreDescription]
        }
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load cloud persistent store: \(error)")
            }
        }
        return container
    }()
    lazy var model: NSManagedObjectModel = {
        let modelPath = Bundle(for: type(of: self)).path(forResource: self.modelName, ofType: "momd")
        let url = URL(fileURLWithPath: modelPath!)
        return NSManagedObjectModel(contentsOf: url)!
    }()
    /// Get local store main managed object context
    lazy var localMainMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    /// Get local store background managed object context
    lazy var localBgMOC: NSManagedObjectContext = {
        let ctx = self.persistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    /// Get cloud store main managed object context. Cloud store is the default container for new workspaces unless sync is disabled during create.
    lazy var ckMainMOC: NSManagedObjectContext = {
        let ctx = self.ckPersistentContainer.viewContext
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    /// Get cloud store background managed object context
    lazy var ckBgMOC: NSManagedObjectContext = {
        let ctx = self.ckPersistentContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()
    private let fetchBatchSize: Int = 50
    private let utils = EAUtils.shared
    var containerName = isRunningTests ? "APITesterProTest" : "APITesterPro"
    let ckContainerName = "APITesterProCloud"
    let modelName = "APITesterPro"  // core data model name
    let localConfigurationName = "Default"  // core data configuration name as defined in the model
    let cloudConfigurationName = "Cloud"  // core data configuration name as defined in the model
    let defaultWorkspaceId = "default"
    let defaultWorkspaceName = "Default workspace"
    let defaultWorkspaceDesc = "The default workspace"
    let cloudKitContainerId = Const.cloudKitContainerID
    static let modelVersion: Int64 = 2
    
    init() {
        self.bootstrap()
    }
    
    init(containerName: String) {
        self.containerName = containerName
        self.bootstrap()
    }

    func bootstrap() {
        #if DEBUG
        self.initCloudKitSchema()
        #endif
        try? self.ckMainMOC.save()
        // end test
    }
    
    func initCloudKitSchema() {
        #if DEBUG
//        do {
//            // Use the cloud container to initialize the development schema.
//            Log.debug("ck: initializing cloudkit schema in dev mode")
//            try self.ckPersistentContainer.initializeCloudKitSchema(options: [])
//        } catch let error {
//            Log.error(error)
//        }
        #endif
    }
    
    /// Returns the context if present or the cloudkit main context
    private func getMainMOC(ctx: NSManagedObjectContext?) -> NSManagedObjectContext {
        if ctx != nil { return ctx! }
        return self.ckMainMOC
    }
    
    /// Returns the context if present or the cloudkit background context
    private func getBgMOC(ctx: NSManagedObjectContext?) -> NSManagedObjectContext {
        if ctx != nil { return ctx! }
        return self.ckBgMOC
    }
    
    /// Returns a child managed object context.
    func getChildMOC(container: CoreDataContainer) -> NSManagedObjectContext {
        let moc = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        moc.parent = container == .cloud ? self.ckMainMOC : self.localMainMOC
        moc.automaticallyMergesChangesFromParent = true
        moc.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return moc
    }
    
    /// Return the Core Data container for the given managed object context
    func getContainer(_ moc: NSManagedObjectContext) -> CoreDataContainer {
        if moc == self.ckMainMOC || moc == self.ckBgMOC {
            return CoreDataContainer.cloud
        }
        return CoreDataContainer.local
    }
    
    func workspaceId() -> String {
        return "\(RecordType.prefix(for: .workspace))\(self.utils.genRandomString())"
    }
    
    func projectId() -> String {
        return "\(RecordType.prefix(for: .project))\(self.utils.genRandomString())"
    }
    
    func requestId() -> String {
        return "\(RecordType.prefix(for: .request))\(self.utils.genRandomString())"
    }
    
    func requestBodyDataId() -> String {
        return "\(RecordType.prefix(for: .requestBodyData))\(self.utils.genRandomString())"
    }
    
    func requestDataId() -> String {
        return "\(RecordType.prefix(for: .requestData))\(self.utils.genRandomString())"
    }
    
    func requestMethodDataId() -> String {
        return "\(RecordType.prefix(for: .requestMethodData))\(self.utils.genRandomString())"
    }
    
    func requestMethodDataId(_ projId: String, methodName: String) -> String {
        return "\(RecordType.prefix(for: .requestMethodData))\(projId)-\(methodName)"
    }
    
    func fileId() -> String {
        return "\(RecordType.prefix(for: .file))\(self.utils.genRandomString())"
    }
    
    func fileId(_ data: Data) -> String {
        return  "\(RecordType.prefix(for: .file))\(Hash.md5(data: data))"
    }
    
    func imageId() -> String {
        return "\(RecordType.prefix(for: .image))\(self.utils.genRandomString())"
    }
    
    func imageId(_ data: Data) -> String {
        return "\(RecordType.prefix(for: .image))\(Hash.md5(data: data))"
    }
    
    func historyId() -> String {
        return "\(RecordType.prefix(for: .history))\(self.utils.genRandomString())"
    }
    
    func envId() -> String {
        return "\(RecordType.prefix(for: .env))\(self.utils.genRandomString())"
    }
    
    func envVarId() -> String {
        return "\(RecordType.prefix(for: .envVar))\(self.utils.genRandomString())"
    }
    
    // MARK: - Sort
    
    /// Sort the given list of dictonaries in the order of created and update the index property.
    func sortByCreated(_ hm: inout [[String: Any]]) {
        hm.sort { (hma, hmb) -> Bool in
            if let c1 = hma["created"] as? Int64, let c2 = hmb["created"] as? Int64 { return c1 < c2 }
            return false
        }
    }
    
    /// Sort the given list of entities in the order of created and update the index property.
    func sortByCreated(_ xs: inout [any Entity]) {
        xs.sort { (a, b) -> Bool in a.getCreated() < b.getCreated() }
    }
    
    func sortedByCreated(_ xs: [[String: Any]]) -> [[String: Any]] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    func sortedByCreated(_ xs: [any Entity]) -> [any Entity] {
        var xs = xs
        self.sortByCreated(&xs)
        return xs
    }
    
    // MARK: - To dictionary
    
    /// Can be used to get the initial value of the request before modification during edit.
    func requestToDictionary(_ x: ERequest) -> [String: Any] {
        let attrs = ERequest.entity().attributesByName.map { arg -> String in arg.key }
        var dict = x.dictionaryWithValues(forKeys: attrs)
        if let method = x.method { dict["method"] = self.requestMethodDataToDictionary(method) }
        if let set = x.headers, let xs = set.allObjects as? [ERequestData] {
            dict["headers"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
        if let set = x.params, let xs = set.allObjects as? [ERequestData] {
            dict["params"] = self.sortedByCreated(xs.map { y -> [String: Any] in self.requestDataToDictionary(y) })
        }
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
        if let binary = x.binary { dict["binary"] = self.requestDataToDictionary(binary) }
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
    /// - Returns: The managed object.
    func getManagedObject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> NSManagedObject {
        return context.object(with: moId)
    }
    
    /// Returns a fetch results controller with the given entity type.
    /// - Parameters:
    ///   - obj: The entity type.
    ///   - predicate: An optional fetch predicate.
    ///   - ctx: The managed object context.
    /// - Returns: The fetch results controller.
    func getFetchResultsController(obj: any Entity.Type, predicate: NSPredicate? = nil, sortDesc: [NSSortDescriptor]? = nil, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        let moc = self.getMainMOC(ctx: ctx)
        var frc: NSFetchedResultsController<NSFetchRequestResult>!
        moc.performAndWait {
            let fr = obj.fetchRequest()
            if sortDesc != nil {
                fr.sortDescriptors = sortDesc!
            } else {
                fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            }
            if let x = predicate {
                fr.predicate = x
            } else {
                fr.predicate = NSPredicate(format: "markForDelete == %hhd AND name != %@", false, "")
            }
            fr.fetchBatchSize = self.fetchBatchSize
            frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        }
        return frc
    }
        
    /// Updates the given fetch results controller predicate.
    /// - Parameters:
    ///   - frc: The fetch results controller.
    ///   - predicate: A fetch predicate.
    ///   - ctx: The managed object context.
    /// - Returns: The fetch results controller.
    func updateFetchResultsController(_ frc: NSFetchedResultsController<NSFetchRequestResult>, predicate: NSPredicate, ctx: NSManagedObjectContext = CoreDataService.shared.localMainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        ctx.performAndWait { frc.fetchRequest.predicate = predicate }
        return frc
    }
    
    func getEntity(recordType: RecordType, id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> (any Entity)? {
        let moc = self.getMainMOC(ctx: ctx)
        switch recordType {
        case .workspace:
            return self.getWorkspace(id: id, ctx: moc)
        case .project:
            return self.getProject(id: id, ctx: moc)
        case .request:
            return self.getRequest(id: id, ctx: moc)
        case .requestData:
            return self.getRequestData(id: id, ctx: moc)
        case .requestBodyData:
            return self.getRequestBodyData(id: id, ctx: moc)
        case .requestMethodData:
            return self.getRequestMethodData(id: id, ctx: moc)
        case .file:
            return self.getFileData(id: id, ctx: moc)
        case .image:
            return self.getImageData(id: id, ctx: moc)
        default:
            return nil
        }
    }
    
    // MARK: EWorkspace
    
    func getWorkspace(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EWorkspace? {
        var x: EWorkspace?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            do {
                let xs = try moc.fetch(fr)
                x = xs.first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    /// Returns workspaces list batched or as per the given offset and limit.
    /// - Parameters:
    ///   - offset: The start index to begin with
    ///   - limit: The maximum number of results to fetch
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context
    /// - Returns: A list of workspaces
    func getAllWorkspaces(offset: Int? = 0, limit: Int? = 0, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EWorkspace] {
        var xs: [EWorkspace] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            if isMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", isMarkForDelete!) }
            var shouldFetchInBatch = true
            if let _offset = offset { fr.fetchOffset = _offset; shouldFetchInBatch = false }
            if let _limit = limit { fr.fetchLimit = _limit; shouldFetchInBatch = false }
            if shouldFetchInBatch { fr.fetchBatchSize = self.fetchBatchSize }
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return xs
    }
    
    func getWorkspaces(offset: Int? = 0, limit: Int? = 0, isMarkForDelete: Bool? = false, completion: @escaping (Result<[EWorkspace], Error>) -> Void, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) {
        var xs: [EWorkspace] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.perform {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            if isMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", isMarkForDelete!) }
            if let _offset = offset { fr.fetchOffset = _offset }
            if let _limit = limit { fr.fetchLimit = _limit }
            do {
                xs = try moc.fetch(fr)
                completion(.success(xs))
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Returns the total count of workspaces
    /// - Parameters:
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context
    /// - Returns: The count of workspaces
    func getWorkspaceCount(isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            if isMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hdd", isMarkForDelete!) }
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting workspaces: \(error)")
            }
        }
        return x
    }
    
    /// Default entities will have the id `default`.
    func getDefaultWorkspace(ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EWorkspace {
        var x: EWorkspace!
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let ws = self.getWorkspace(id: self.defaultWorkspaceId) {
                x = ws
            } else {
                // We create the default workspace with active flag as false. Only if any change by the user gets made, the flag is enabled. This helps in syncing from cloud.
                let ws: EWorkspace! = self.createWorkspace(id: self.defaultWorkspaceId, name: self.defaultWorkspaceName, desc: self.defaultWorkspaceDesc, isSyncEnabled: true, isActive: false, ctx: moc)
                ws.order = 0
                self.saveMainContext()
                x = ws
            }
        }
        return x
    }
    
    /// Get the order of the last workspace. The default value is 0 as there will be the default workspace all the time.
    /// - Parameter ctx: The managed object context
    /// - Returns: The order
    func getOrderOfLastWorkspace(ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> NSDecimalNumber {
        var order: NSDecimalNumber = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EWorkspace>(entityName: "EWorkspace")
            fr.sortDescriptors = [NSSortDescriptor(key: SortOrder.order.rawValue, ascending: false)]
            fr.fetchLimit = 1
            do {
                order = try moc.fetch(fr).first?.order ?? 0
            } catch let error {
                Log.error("Error getting last workspace order: \(error)")
            }
        }
        return order
    }
    
    // MARK: EProject
    
    func getProject(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EProject? {
        var x: EProject?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The project.
    func getProject(at index: Int, wsId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EProject? {
        var x: EProject?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "workspace.id == %@", wsId) : NSPredicate(format: "workspace.id == %@ AND markForDelete == %hhd", wsId, isMarkForDelete!)
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
    /// - Returns: The project.
    func getProject(moId: NSManagedObjectID, withContext context: NSManagedObjectContext) -> EProject? {
        return context.object(with: moId) as? EProject
    }
    
    /// Retrieves the projects belonging to the given workspace.
    /// - Parameters:
    ///   - wsId: The workspace id.
    ///   - isMarkForDelete: Whether to return only entities marked for deletion
    ///   - ctx: The managed object context.
    /// - Returns: A list of projects.
    func getProjects(wsId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EProject] {
        var xs: [EProject] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "workspace.id == %@", wsId) : NSPredicate(format: "workspace.id == %@ AND markForDelete = %hhd", wsId, isMarkForDelete!)
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
    
    /// Get the order of the last project in the given workspace. If no projects are found the order will be -1 so that inc() will work properly throughout.
    /// - Parameter wsId: The workspace Id
    /// - Parameter ctx: The managed object context
    /// - Returns: The order
    func getOrderOfLastProject(wsId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> NSDecimalNumber {
        var order: NSDecimalNumber = -1
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EProject>(entityName: "EProject")
            fr.predicate = NSPredicate(format: "workspace.id = %@", wsId)
            fr.sortDescriptors = [NSSortDescriptor(key: SortOrder.order.rawValue, ascending: false)]
            fr.fetchLimit = 1
            do {
                order = try moc.fetch(fr).first?.order ?? -1
            } catch let error {
                Log.error("Error getting last project order: \(error)")
            }
        }
        return order
    }
    
    // MARK: ERequest
    
    func getRequest(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequest? {
        var x: ERequest?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of requests.
    func getRequests(projectId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequest] {
        var xs: [ERequest] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projectId): NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request.
    func getRequest(at index: Int, projectId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequest? {
        var x: ERequest?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projectId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of requests.
    func getRequestsCount(projectId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = isMarkForDelete == nil ?  NSPredicate(format: "project.id == %@", projectId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projectId, isMarkForDelete!)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting requests count: \(error)")
            }
        }
        return x
    }
    
    /// Get the order of the last request. If no requests are found the order will be -1 so that inc() will work properly throughout.
    /// - Parameter projId: The project Id in which the request order needs to be checked
    /// - Parameter ctx: The managed object context
    /// - Returns: The order
    func getOrderOfLastRequest(projId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> NSDecimalNumber {
        var order: NSDecimalNumber = -1
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = NSPredicate(format: "project.id = %@", projId)
            fr.sortDescriptors = [NSSortDescriptor(key: SortOrder.order.rawValue, ascending: false)]
            fr.fetchLimit = 1
            do {
                order = try moc.fetch(fr).first?.order ?? -1
            } catch let error {
                Log.error("Error getting last request order: \(error)")
            }
        }
        return order
    }
    
    // MARK: ERequestData
    
    func getRequestData(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity with id: \(id) - \(error)")
            }
        }
        return x
    }
    
    func getRequestReferenceKey(_ reqDataType: RequestDataType) -> String {
        switch reqDataType {
        case .header:
            return "header.id"
        case .param:
            return "param.id"
        case .form:
            return "form.request.id"
        case .multipart:
            return "multipart.request.id"
        case .binary:
            return "binary.request.id"
        }
    }
    
    func getRequestData(at index: Int, reqId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, isMarkForDelete!)
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
    
    func getLastRequestData(type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "type == %d", _type) : NSPredicate(format: "type == %d AND markForDelete == %hhd", _type, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of request data entities.
    func getRequestDataCount(reqId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, isMarkForDelete!)
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
    ///   - type: The request data type.
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request body data object.
    /// - Returns: A list of request data entities.
    func getFormRequestData(_ bodyDataId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            let relKey: String = {
                switch type {
                case .form:
                    return "form.id"
                case .multipart:
                    return "multipart.id"
                case .binary:
                    return "binary.id"
                default:
                    return "form.id"
                }
            }()
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "%K == %@ AND type == %d", relKey, bodyDataId, _type)
                : NSPredicate(format: "%K == %@ AND type == %d AND markForDelete == %hhd", relKey, bodyDataId, _type, isMarkForDelete!)  // ERequestBodyData.id
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request data entity.
    func getFormRequestData(at index: Int, bodyDataId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC)
        -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey: String = {
                if type == .form {
                    return "form.id"
                }
                return "multipart.id"
            }()
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let _type = type.rawValue.toInt32()
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "%K == %@ AND type == %d", typeKey, bodyDataId, _type)
                : NSPredicate(format: "%K == %@ AND type == %d AND markForDelete == %hhd", typeKey, bodyDataId, _type, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getHeadersRequestData(_ reqId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "header.id == %@", reqId) : NSPredicate(format: "header.id == %@ AND markForDelete == %hhd", reqId, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getParamsRequestData(_ reqId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "param.id == %@", reqId) : NSPredicate(format: "param.id == %@ AND markForDelete == %hhd", reqId, isMarkForDelete!)
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
    
    func getRequestData(reqId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestData? {
        var x: ERequestData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let typeKey = self.getRequestReferenceKey(type)
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "%K == %@", typeKey, reqId) : NSPredicate(format: "%K == %@ AND markForDelete == %hhd", typeKey, reqId, isMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error getting entity: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves request data marked for delete for a request
    /// - Parameters:
    ///   - reqId: The request Id
    ///   - type: The request data type
    ///   - ctx: The managed object context.
    /// - Returns: A list of request data entities.
    func getRequestDataMarkedForDelete(reqId: String, type: RequestDataType, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestData] {
        var xs: [ERequestData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestData>(entityName: "ERequestData")
            let type = self.getRequestReferenceKey(type)
            fr.predicate = NSPredicate(format: "%K == %@ AND markForDelete == %hhd", type, reqId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequestMethodData
    
    /// Retrieve the request method data for the given id.
    /// - Parameters:
    ///   - id: The request method data id.
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request method data entity.
    func getRequestMethodData(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
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
    ///   - sortOrder: The sort order for fetch
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request method data entities.
    func getRequestMethodData(reqId: String, sortOrder: SortOrder? = SortOrder.order, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "request.id == %@", reqId) : NSPredicate(format: "request.id == %@ AND markForDelete == %hhd", reqId, isMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: sortOrder!.rawValue, ascending: true)]
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
    ///   - sortOrder: The sort order for fetch
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: A list of request method data entities.
    func getRequestMethodData(projId: String, sortOrder: SortOrder? = SortOrder.order, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projId) : NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, isMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: sortOrder!.rawValue, ascending: true)]
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
    ///   - sortOrder: The sort order for fetch
    ///   - projId: The project id.
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The request method data entity.
    func getRequestMethodData(at index: Int, projId: String, sortOrder: SortOrder? = SortOrder.order, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "project.id == %@", projId): NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, isMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: sortOrder!.rawValue, ascending: true)]
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
    ///   - projId: The project Id under which the requests belongs to.
    ///   - index: The method index which will be the selected method index in the request.
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The count of entities.
    func getRequestsCountForRequestMethodData(projId: String, reqMethId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequest>(entityName: "ERequest")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@ AND project.id == %@", reqMethId, projId)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd AND project.id == %@", reqMethId, isMarkForDelete!, projId)
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting getting request count for the method: \(error)")
            }
        }
        return x
    }
    
    /// Get the total request methods count for the given project. This can be used to set the order of newly created request method data.
    /// - Parameters:
    ///   - proj: The project for which the count needs to be checked
    ///   - ctx: The managed object context
    /// - Returns: The integer count
    func getRequestMethodDataCount(_ proj: EProject, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "project.id == %@", proj.getId())
            do {
                x = try moc.count(for: fr)
            } catch let error {
                Log.error("Error getting method data count: \(error)")
            }
        }
        return x
    }
    
    /// Generates the default HTTP methods for a project
    func genDefaultRequestMethods(_ proj: EProject, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestMethodData] {
        let names = ["GET", "POST", "PUT", "PATCH", "DELETE"]
        return names.enumerated().compactMap { seq -> ERequestMethodData? in
            let elem = seq.element
            let idx = seq.offset
            if let x = self.createRequestMethodData(id: self.requestMethodDataId(proj.getId(), methodName: elem), wsId: proj.getWsId(), name: elem, isCustom: false, ctx: ctx) {
                x.created = proj.getCreated().adjust(.second, offset: idx)
                x.modified = x.created
                x.order = idx.toNSDecimal()
                x.project = proj
                return x
            }
            return nil
        }
    }
    
    func getRequestMethodDataMarkedForDelete(projId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [ERequestMethodData] {
        var xs: [ERequestMethodData] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestMethodData>(entityName: "ERequestMethodData")
            fr.predicate = NSPredicate(format: "project.id == %@ AND markForDelete == %hhd", projId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: ERequestBodyData
    
    func getRequestBodyData(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<ERequestBodyData>(entityName: "ERequestBodyData")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id) : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request data.
    /// - Returns: The count of files.
    func getFilesCount(_ reqDataId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> Int {
        var x: Int = 0
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            let _type = type.rawValue.toInt32()
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@ AND type == %d", reqDataId, _type)
                : NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hdd", reqDataId, _type, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context of the request data.
    /// - Returns: A list of file entities.
    func getFiles(_ reqDataId: String, type: RequestDataType, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            let _type = type.rawValue.toInt32()
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hhd", reqDataId, _type)
                : NSPredicate(format: "requestData.id == %@ AND type == %d AND markForDelete == %hhd", reqDataId, type.rawValue.toInt32(), isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The file entity.
    func getFile(at index: Int, reqDataId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EFile? {
        var x: EFile?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "requestData.id == %@", reqDataId)
                : NSPredicate(format: "requestData.id == %@ AND markForDelete == %hhd", reqDataId, isMarkForDelete!)
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
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The file entity.
    func getFileData(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EFile? {
        var x: EFile?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = isMarkForDelete == nil ?  NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching file: \(error)")
            }
        }
        return x
    }
    
    func getFilesMarkedForDelete(reqDataId: String, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EFile] {
        var xs: [EFile] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EFile>(entityName: "EFile")
            fr.predicate = NSPredicate(format: "requestData == %@ AND markForDelete == %hhd", reqDataId, true)
            fr.fetchBatchSize = 8
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting markForDelete entites: \(error)")
            }
        }
        return xs
    }
    
    // MARK: EImage
    
    /// Retrieve image object for the given image id.
    /// - Parameters:
    ///   - id: The image object id.
    ///   - isMarkForDelete: Whether to include entities marked for deletion.
    ///   - ctx: The managed object context.
    /// - Returns: The image entity.
    func getImageData(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EImage? {
        var x: EImage?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EImage>(entityName: "EImage")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching image: \(error)")
            }
        }
        return x
    }
    
    // MARK: EHistory
    
    func getHistory(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EHistory? {
        var x: EHistory?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EHistory>(entityName: "EHistory")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching history: \(error)")
            }
        }
        return x
    }
    
    func getLatestHistory(reqId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EHistory? {
        var x: EHistory?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EHistory>(entityName: "EHistory")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "request.id == %@", reqId)
                : NSPredicate(format: "request.id == %@ AND markForDelete == %hhd", reqId, isMarkForDelete!)
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching latest history: \(error)")
            }
        }
        return x
    }
    
    // MARK: EEnv
    
    func getEnv(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EEnv? {
        var x: EEnv?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching env: \(error)")
            }
        }
        return x
    }

    func getEnvs(isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EEnv] {
        var xs: [EEnv] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            if isMarkForDelete != nil { fr.predicate = NSPredicate(format: "markForDelete == %hhd", isMarkForDelete!) }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting envs: \(error)")
            }
        }
        return xs
    }
    
    /// Retrieves envs belonging to the given workspace.
    func getEnvs(wsId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EEnv] {
        var xs: [EEnv] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnv>(entityName: "EEnv")
            if isMarkForDelete != nil {
                fr.predicate = NSPredicate(format: "markForDelete == %hhd AND wsId == %@", isMarkForDelete!, wsId)
            } else {
                fr.predicate = NSPredicate(format: "wsId == %@", wsId)
            }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting envs: \(error)")
            }
        }
        return xs
    }
    
    // MARK: EEnvVar
    
    func getEnvVar(id: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnvVar>(entityName: "EEnvVar")
            fr.predicate = isMarkForDelete == nil ? NSPredicate(format: "id == %@", id)
                : NSPredicate(format: "id == %@ AND markForDelete == %hhd", id, isMarkForDelete!)
            fr.fetchLimit = 1
            do {
                x = try moc.fetch(fr).first
            } catch let error {
                Log.error("Error fetching env: \(error)")
            }
        }
        return x
    }
    
    /// Retrieves env variables belonging to the given env.
    func getEnvVars(envId: String, isMarkForDelete: Bool? = false, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> [EEnvVar] {
        var xs: [EEnvVar] = []
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let fr = NSFetchRequest<EEnvVar>(entityName: "EEnvVar")
            if isMarkForDelete != nil {
                fr.predicate = NSPredicate(format: "env.id == %@ AND markForDelete == %hhd", envId, isMarkForDelete!)
            } else {
                fr.predicate = NSPredicate(format: "env.id == %@", envId)
            }
            fr.fetchBatchSize = self.fetchBatchSize
            do {
                xs = try moc.fetch(fr)
            } catch let error {
                Log.error("Error getting env vars: \(error)")
            }
        }
        return xs
    }
    
    func getDataMarkedForDelete(obj: any Entity.Type, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> NSFetchedResultsController<NSFetchRequestResult> {
        let moc = self.getMainMOC(ctx: ctx)
        var frc: NSFetchedResultsController<NSFetchRequestResult>!
        moc.performAndWait {
            let fr = obj.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "created", ascending: true)]
            fr.predicate = NSPredicate(format: "markForDelete == %hhd", true)
            fr.fetchBatchSize = self.fetchBatchSize
            frc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
            do {
                try frc.performFetch()
            } catch let error {
                Log.error("Error performing fetch: \(error)")
            }
        }
        return frc
    }
    
    // MARK: - Create
    
    /// Create workspace.
    /// - Parameters:
    ///   - id: The workspace id.
    ///   - name: The workspace name.
    ///   - desc: The workspace description.
    ///   - isSyncEnabled: Is syncing with iCloud enabled.
    ///   - isActive: Is the workspace active (applies to default workspace only). If a project is added to the default workspace, isActive is enabled. Only then we need to sync the default workspace since it will be created automatically on app launch.
    ///   - checkExists: Check whether the workspace exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A workspace.
    func createWorkspace(id: String, name: String, desc: String, isSyncEnabled: Bool, isActive: Bool? = true, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC)  -> EWorkspace? {
        var x: EWorkspace?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExist = checkExists, isExist, let ws = self.getWorkspace(id: id, ctx: ctx) { x = ws }
            let ws = x != nil ? x! : EWorkspace(context: moc)
            ws.id = id
            ws.name = name
            ws.desc = desc
            ws.isActive = isActive!
            ws.isSyncEnabled = isSyncEnabled
            if !isSyncEnabled { ws.syncDisabled = date }
            ws.created = x == nil ? date : x!.created
            ws.modified = date
            ws.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = ws
        }
        return x
    }
    
    func setWorkspaceSyncEnabled(_ state: Bool, ws: EWorkspace, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) {
        let moc = self.getMainMOC(ctx: ctx)
        let date = Date()
        moc.performAndWait {
            if !state { ws.syncDisabled = date }
            ws.modified = date
            ws.isSyncEnabled = state
            do {
                if !AppState.isRequestEdit {  try moc.save() }
            } catch let error {
                Log.error("Error saving workspace with active flag set: \(error)")
            }
        }
    }
    
    /// Create project.
    /// - Parameters:
    ///   - id: The project id.
    ///   - wsId: The workspace id.
    ///   - name: The project name.
    ///   - desc: The project description.
    ///   - ws: The workspace to which the project belongs.
    ///   - checkExists: Check if the given project exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A project.
    func createProject(id: String, wsId: String, name: String, desc: String, ws: EWorkspace? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EProject? {
        var x: EProject?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExist = checkExists, isExist, let proj = self.getProject(id: id, ctx: ctx) { x = proj }
            let proj = x != nil ? x! : EProject(context: moc)
            proj.id = id
            proj.wsId = wsId
            proj.name = name
            proj.desc = desc
            proj.created = x == nil ? date : x!.created
            proj.modified = date
            proj.version = x == nil ? CoreDataService.modelVersion : x!.version
            _ = self.genDefaultRequestMethods(proj, ctx: moc)
            ws?.addToProjects(proj)
            ws?.isActive = true
            x = proj
        }
        return x
    }
    
    /// Create a request
    /// - Parameters:
    ///   - id: The request Id.
    ///   - wsId: The workspace Id.
    ///   - name: The name of the request.
    ///   - project: The project to which the request belongs to.
    ///   - checkExists: Check if the request exists before creating one.
    ///   - ctx: The managed object context.
    /// - Returns: A request.
    func createRequest(id: String, wsId: String, name: String, project: EProject? = nil, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequest? {
        var x: ERequest?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let req = self.getRequest(id: id, ctx: ctx) { x = req }
            let req = x != nil ? x! : ERequest(context: moc)
            req.id = id
            req.wsId = wsId
            req.name = name
            req.created = x == nil ? date : x!.created
            req.modified = date
            req.version = x == nil ? CoreDataService.modelVersion : x!.version
            project?.addToRequests(req)
            x = req
        }
        return x
    }
        
    /// Create request data.
    /// - Parameters:
    ///   - id: The request data Id.
    ///   - wsId: The workspace Id.
    ///   - type: The request data type.
    ///   - fieldFormat: The request body form field format.
    ///   - checkExists: Check for existing request data object.
    ///   - ctx: The managed object context.
    /// - Returns: A request data.
    func createRequestData(id: String, wsId: String, type: RequestDataType, fieldFormat: RequestBodyFormFieldFormatType, checkExists: Bool? = true,
                           ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestData? {
        var x: ERequestData?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestData(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? date : x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            data.fieldFormat = fieldFormat.rawValue.toInt64()
            data.type = type.rawValue.toInt64()
            x = data
            Log.debug("RequestData \(x == nil ? "created" : "updated"): \(x!)")
        }
        return x
    }
    
    /// Create request method data.
    /// - Parameters:
    ///   - id: The request method data Id.
    ///   - wsId: The workspace Id.
    ///   - name: The name of the request method data.
    ///   - isCustom: If the request method is user created.
    ///   - checkExists: Check if the request method data exists.
    ///   - ctx: The managed object context.
    /// - Returns: A request method data.
    func createRequestMethodData(id: String, wsId: String, name: String, isCustom: Bool? = true, checkExists: Bool? = true,
                                 ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestMethodData? {
        var x: ERequestMethodData?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestMethodData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestMethodData(context: moc)
            data.id = id
            data.wsId = wsId
            data.isCustom = isCustom ?? true
            data.name = name
            data.created = x == nil ? date : x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    /// Create request body data.
    /// - Parameters:
    ///   - id: The request body data Id.
    ///   - wsId: The workspace Id.
    ///   - checkExists: Check if the request body data exists before creating.
    ///   - ctx: The managed object context.
    /// - Returns: A request body data.
    func createRequestBodyData(id: String, wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> ERequestBodyData? {
        var x: ERequestBodyData?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getRequestBodyData(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : ERequestBodyData(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? date : x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    /// Create an image object with the given image data.
    /// - Parameters:
    ///   - data: The image data.
    ///   - wsId: The workspace Id.
    ///   - name: The image name.
    ///   - type: The image type (png, jpg, etc.).
    ///   - checkExists: Check if the image exists already before creating.
    ///   - ctx: The managed object context.
    /// - Returns: An image entity.
    func createImage(imageId: String? = CoreDataService.shared.imageId(), data: Data, wsId: String, name: String, type: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EImage? {
        var x: EImage?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getImageData(id: imageId!, ctx: ctx) { x = data }
            let image = x != nil ? x! : EImage(context: moc)
            image.id = imageId!
            image.wsId = wsId
            image.data = data
            image.name = name
            image.type = type
            image.created = x == nil ? date : x!.created
            image.modified = date
            image.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = image
        }
        return x
    }
    
    func createFile(data: Data, wsId: String, name: String, path: URL, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EFile? {
        return self.createFile(data: data, wsId: wsId, name: name, path: path, type: .form, checkExists: checkExists, ctx: ctx)
    }
    
    func createFile(fileId: String? = CoreDataService.shared.fileId(), data: Data, wsId: String, name: String, path: URL, type: RequestDataType, checkExists: Bool? = true,
                    ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EFile? {
        var x: EFile?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getFileData(id: fileId!, ctx: ctx) { x = data }
            let file = x != nil ? x! : EFile(context: moc)
            file.id = fileId!
            file.wsId = wsId
            file.data = data
            file.created = x == nil ? date : x!.created
            file.modified = date
            file.name = name
            file.path = path
            file.type = type.rawValue.toInt64()
            file.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = file
        }
        return x
    }
    
    
    // FIXME: Probably remove as it's not used
    func createHistory(id: String, wsId: String, urlRequest: String, responseData: Data?, responseHeaders: Data?, statusCode: Int64, elapsed: Int64,
                       responseBodyBytes: Int64, url: String, method: String, isSecure: Bool, checkExists: Bool? = true,
                       ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EHistory? {
        var x: EHistory?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getHistory(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : EHistory(context: moc)
            data.id = id
            data.wsId = wsId
            data.urlRequest = urlRequest
            data.responseData = responseData
            data.responseHeaders = responseHeaders
            data.statusCode = statusCode
            data.elapsed = elapsed
            data.responseBodyBytes = responseBodyBytes
            data.url = url
            data.method = method
            data.isSecure = isSecure
            data.created = x == nil ? date : x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    func createHistory(id: String, wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EHistory? {
        var x: EHistory?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getHistory(id: id, ctx: ctx) { x = data }
            let data = x != nil ? x! : EHistory(context: moc)
            data.id = id
            data.wsId = wsId
            data.created = x == nil ? date : x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    func createEnv(name: String, envId: String? = CoreDataService.shared.envId(), wsId: String, checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EEnv? {
        var x: EEnv?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            if let isExists = checkExists, isExists, let data = self.getEnv(id: envId!, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnv(context: moc)
            data.id = envId
            data.wsId = wsId
            data.name = name
            data.created = x == nil ? date: x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }

    func createEnvVar(name: String, value: String, id: String? = CoreDataService.shared.envVarId(), checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let envVarId = id == nil ? self.envVarId() : id!
            if let isExists = checkExists, isExists, let data = self.getEnvVar(id: envVarId, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnvVar(context: moc)
            data.id = envVarId
            data.name = name
            data.value = value
            data.created = x == nil ? date: x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    func createEnvVar(id: String? = CoreDataService.shared.envVarId(), checkExists: Bool? = true, ctx: NSManagedObjectContext? = CoreDataService.shared.ckMainMOC) -> EEnvVar? {
        var x: EEnvVar?
        let date = Date()
        let moc = self.getMainMOC(ctx: ctx)
        moc.performAndWait {
            let envVarId = id == nil ? self.envVarId() : id!
            if let isExists = checkExists, isExists, let data = self.getEnvVar(id: envVarId, ctx: ctx) { x = data }
            let data = x != nil ? x! : EEnvVar(context: moc)
            data.id = envVarId
            data.created = x == nil ? date: x!.created
            data.modified = date
            data.version = x == nil ? CoreDataService.modelVersion : x!.version
            x = data
        }
        return x
    }
    
    // MARK: - Save
    
    func refreshAllCKManagedObjects() {
        self.ckMainMOC.refreshAllObjects()
    }
    
    func refreshAllLocalManagedObjects() {
        self.localMainMOC.refreshAllObjects()
    }
    
    func saveMainContext(_ callback: ((Bool) -> Void)? = nil) {
        Task {
            let ckStatus = await saveCKMainContext()
            let localStatus = await saveLocalMainContext()
            callback?(ckStatus && localStatus)
        }
    }
    
    func saveCKMainContext() async -> Bool {
        await withCheckedContinuation { continuation in
            self.saveCKMainContext { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    func saveCKMainContext(_ callback: ((Bool) -> Void)? = nil) {
        Log.debug("ck save main context")
        self.ckMainMOC.perform {
            do {
                if !self.ckMainMOC.hasChanges { Log.debug("ck main context does not have changes"); callback?(true); return }
                Log.debug("main context has changes")
                try self.ckMainMOC.save()
                self.ckMainMOC.processPendingChanges()
                Log.debug("ck main context saved")
                callback?(true)
            } catch {
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(false)
            }
        }
    }
    
    func saveLocalMainContext() async -> Bool {
        await withCheckedContinuation { continuation in
            self.saveLocalMainContext { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    func saveLocalMainContext(_ callback: ((Bool) -> Void)? = nil) {
        Log.debug("local save main context")
        // TODO: remove this global check
        // if AppState.isRequestEdit { Log.debug("Edit request in progress. Skipping main context save."); callback?(false); return }
        self.localMainMOC.perform {
            do {
                if !self.localMainMOC.hasChanges { Log.debug("local main context does not have changes"); callback?(true); return }
                Log.debug("local main context has changes")
                try self.localMainMOC.save()
                self.localMainMOC.processPendingChanges()
                Log.debug("main context saved")
                callback?(true)
            } catch {
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(false)
            }
        }
    }
    
    func saveBackgroundContext(isForce: Bool? = false, callback: ((Bool) -> Void)? = nil) {
        Task {
            let ckStatus = await saveCKBackgroundContext(isForce: isForce)
            let localStatus = await saveLocalBackgroundContext(isForce: isForce)
            callback?(ckStatus && localStatus)
        }
    }
    
    func saveCKBackgroundContext(isForce: Bool? = false) async -> Bool {
        await withCheckedContinuation { continuation in
            self.saveCKBackgroundContext(isForce: isForce) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Save the cloud managed object context associated with the given entity.
    func saveCKBackgroundContext(isForce: Bool? = false, callback: ((Bool) -> Void)? = nil) {
        Log.debug("ck save bg context")
        var status = true
        let isForceSave = isForce ?? false
        let fn: () -> Void = {
            do {
                Log.debug("ck bg context has changes")
                try self.localBgMOC.save()
                self.localBgMOC.processPendingChanges()
                callback?(true)
            } catch {
                status = false
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(status)
                return
            }
        }
        isForceSave ? self.localBgMOC.performAndWait { fn() } : self.localBgMOC.perform { fn() }
    }
    
    func saveLocalBackgroundContext(isForce: Bool? = false) async -> Bool {
        await withCheckedContinuation { continuation in
            self.saveLocalBackgroundContext(isForce: isForce) { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    /// Save the local managed object context associated with the given entity.
    func saveLocalBackgroundContext(isForce: Bool? = false, callback: ((Bool) -> Void)? = nil) {
        Log.debug("save local bg context")
        var status = true
        let isForceSave = isForce ?? false
        let fn: () -> Void = {
            do {
                Log.debug("bg local context has changes")
                try self.localBgMOC.save()
                self.localBgMOC.processPendingChanges()
                callback?(true)
            } catch {
                status = false
                let nserror = error as NSError
                Log.error("Persistence error \(nserror), \(nserror.userInfo)")
                callback?(status)
                return
            }
        }
        isForceSave ? self.localBgMOC.performAndWait { fn() } : self.localBgMOC.perform { fn() }
    }
    
    func saveChildContext(_ ctx: NSManagedObjectContext) {
        ctx.performAndWait {
            do {
                try ctx.save()
                self.saveBackgroundContext(isForce: true)
            } catch let error { Log.error("Error saving child context: \(error)") }
        }
    }
        
    // MARK: - Delete
    
//    func markEntityForDelete(_ entity: (any Entity)?) {
//        guard let entity = entity else { return }
//        entity.managedObjectContext?.performAndWait {
//            entity.setMarkedForDelete(true)
//            let ts = Date().currentTimeNanos()
//            entity.setModified(ts)
//        }
//    }
    
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
    
    func discardChanges(for ids: Set<EditRequestInfo>, inContext context: NSManagedObjectContext) {
        Log.debug("Discard changes for: \(ids)")
        context.performAndWait {
            ids.toArray().forEach { info in
                let elem = self.getManagedObject(moId: info.moID, withContext: context)
                Log.debug("discard changes in obj: \(elem)")
                self.discardChanges(for: elem, inContext: context)
            }
        }
    }
    
    func deleteEntity(_ entity: NSManagedObject?, ctx: NSManagedObjectContext? = nil) {
        if let x = entity, let moc = ctx != nil ? ctx! : x.managedObjectContext {
            moc.performAndWait { moc.delete(x) }
        }
    }
    
//    func deleteWorkspace(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getWorkspace(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteProject(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getProject(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteRequest(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getRequest(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteRequestBodyData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getRequestBodyData(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteRequestData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getRequestData(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteRequestMethodData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getRequestMethodData(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteFileData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getFileData(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteImageData(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getImageData(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteHistory(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getHistory(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteEnv(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getEnv(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    func deleteEnvVar(id: String, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        self.deleteEntity(self.getEnvVar(id: id, isMarkForDelete: nil, ctx: moc))
//    }
//    
//    /// Delete the entity with the given id.
//    /// - Parameters:
//    ///   - dataId: The entity id. If the entity could be `RequestData` or `RequestBodyData`.
//    ///   - req: The request to which the entity belongs.
//    ///   - type: The entity type.
//    ///   - ctx: The managed object context.
//    func deleteRequestData(dataId: String, req: ERequest, type: RequestCellType, ctx: NSManagedObjectContext? = CoreDataService.shared.mainMOC) {
//        let moc = self.getMainMOC(ctx: ctx)
//        moc.performAndWait {
//            var x: Entity?
//            switch type {
//            case .header:
//                x = self.getRequestData(id: dataId, isMarkForDelete: nil, ctx: moc)
//                if let y = x as? ERequestData { req.removeFromHeaders(y) }
//            case .param:
//                x = self.getRequestData(id: dataId, isMarkForDelete: nil, ctx: ctx)
//                if let y = x as? ERequestData { req.removeFromParams(y) }
//            case .body:
//                x = self.getRequestBodyData(id: dataId, isMarkForDelete: nil, ctx: moc)
//                if x != nil { req.body = nil }
//            default:
//                break
//            }
//            if let y = x { moc.delete(y) }
//            Log.debug("Deleted data id: \(dataId)")
//        }
//    }
}
