//
//  APITesterProTests.swift
//  APITesterProTests
//
//  Created by Jaseem V V on 02/12/19.
//  Copyright © 2019 Jaseem V V. All rights reserved.
//

import XCTest
@testable import APITesterPro
import CoreData

class APITesterProTests: XCTestCase {
    private lazy var localdb = { CoreDataService.shared }()
    // private var dbSvc = PersistenceService.shared
    private let utils = EAUtils.shared
    private let serialQueue = DispatchQueue(label: "serial-queue")
    private let app = App.shared

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - CoreData tests
    
    func destroyPersistenceStore() throws {
        let pc = self.localdb.persistentContainer.persistentStoreCoordinator
        let url = pc.url(for: pc.persistentStores.first!)
        if #available(iOS 15, *) {
            try pc.destroyPersistentStore(at: url, type: .sqlite)
        } else {
            try pc.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: [:])
        }
    }
    
    func testCoreDataSetupCompletion() {
        let exp = expectation(description: "CoreData setup completion")
        self.localdb.setup { exp.fulfill() }
        waitForExpectations(timeout: 1.0) { _ in XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0) }
    }
    
    func testCoreDataPersistenceStoreCreated() {
        let exp = expectation(description: "CoreData setup create store")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            XCTAssertTrue(self.localdb.persistentContainer.persistentStoreCoordinator.persistentStores.count > 0)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreDataPersistenceLoadedOnDisk() {
        let exp = expectation(description: "CoreData persistence container loaded on disk")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.persistentContainer.persistentStoreDescriptions.first?.type, NSSQLiteStoreType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0) { _ in
            do {
                try self.destroyPersistenceStore()
            } catch {
                XCTFail("Error deleting persistence store: \(error)")
            }
        }
    }
    
    func testCoreDataBackgroundContextConcurrencyType() {
        let exp = expectation(description: "background context")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.bgMOC.concurrencyType, .privateQueueConcurrencyType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreDataMainContextConcurrencyType() {
        let exp = expectation(description: "main context")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                XCTAssertEqual(self.localdb.mainMOC.concurrencyType, .mainQueueConcurrencyType)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testCoreData() {
        let exp = expectation(description: "test core data")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let lws = self.localdb.createWorkspace(id: "test-ws", name: "test-ws", desc: "", isSyncEnabled: false)
                XCTAssertNotNil(lws)
                guard let ws = lws else { return }
                XCTAssertEqual(ws.name, "test-ws")
                self.localdb.saveBackgroundContext()
                self.localdb.deleteEntity(ws)
                let aws = self.localdb.getWorkspace(id: "test-ws")
                XCTAssertNil(aws)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testEntitySorting() {
        let exp = expectation(description: "test core data sorting")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let wsname = "test-ws"
                let wsId = wsname
                let ctx = self.localdb.bgMOC
                let rws = self.localdb.createWorkspace(id: wsId, name: wsname, desc: "", isSyncEnabled: false, ctx: ctx)
                XCTAssertNotNil(rws)
                guard let ws = rws else { return }
                ws.name = wsname
                ws.desc = "test description"
                let wproj1 = self.localdb.createProject(id: "test-project-22", wsId: wsId, name: "test-project-22", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj1)
                guard let proj1 = wproj1 else { return }
                let wproj2 = self.localdb.createProject(id: "test-project-11", wsId: wsId, name: "test-project-11", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj2)
                guard let proj2 = wproj2 else { return }
                let wproj3 = self.localdb.createProject(id: "test-project-33", wsId: wsId, name: "test-project-33", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj3)
                guard let proj3 = wproj3 else { return }
                ws.projects = NSSet(array: [proj1, proj2, proj3])
                self.localdb.saveBackgroundContext()
                
                // ws2
                let wsname2 = "test-ws-2"
                let wsId2 = wsname2
                let rws2 = self.localdb.createWorkspace(id: wsId2, name: wsname2, desc: "", isSyncEnabled: false, ctx: ctx)
                XCTAssertNotNil(rws2)
                guard let ws2 = rws2 else { return }
                ws2.name = wsname2
                ws2.desc = "test description 2"
                let wproj21 = self.localdb.createProject(id: "ws2-test-project-22", wsId: wsId2, name: "ws2-test-project-22", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj21)
                guard let proj21 = wproj21 else { return }
                let wproj22 = self.localdb.createProject(id: "ws2-test-project-11", wsId: wsId2, name: "ws2-test-project-11", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj22)
                guard let proj22 = wproj22 else { return }
                let wproj23 = self.localdb.createProject(id: "ws2-test-project-33", wsId: wsId2, name: "ws2-test-project-33", desc: "", ctx: ctx)
                XCTAssertNotNil(wproj23)
                guard let proj23 = wproj23 else { return }
                ws2.projects = NSSet(array: [proj21, proj22, proj23])
                self.localdb.saveBackgroundContext()
                
                let lws = self.localdb.getWorkspace(id: wsname, ctx: ctx)
                XCTAssertNotNil(lws)
                let projxs = self.localdb.getProjects(wsId: ws.getId(), ctx: ctx)
                XCTAssert(projxs.count == 3)
                Log.debug("projxs: \(projxs)")
                XCTAssertEqual(projxs[0].name, "test-project-22")
                XCTAssertEqual(projxs[1].name, "test-project-11")
                XCTAssertEqual(projxs[2].name, "test-project-33")
                
                let lws2 = self.localdb.getWorkspace(id: wsname2, ctx: ctx)
                XCTAssertNotNil(lws2)
                let projxs2 = self.localdb.getProjects(wsId: ws2.getId(), ctx: ctx)
                XCTAssert(projxs2.count == 3)
                Log.debug("projxs: \(projxs2)")
                XCTAssertEqual(projxs2[0].name, "ws2-test-project-22")
                XCTAssertEqual(projxs2[1].name, "ws2-test-project-11")
                XCTAssertEqual(projxs2[2].name, "ws2-test-project-33")
                
                // cleanup
                projxs.forEach { p in self.localdb.deleteEntity(p, ctx: ctx) }
                projxs2.forEach { p in self.localdb.deleteEntity(p, ctx: ctx) }
                self.localdb.deleteEntity(ws, ctx: ctx)
                self.localdb.deleteEntity(ws, ctx: ctx)
                self.localdb.saveBackgroundContext()
                self.localdb.discardChanges(in: self.localdb.bgMOC)
                self.localdb.discardChanges(in: self.localdb.mainMOC)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testEntityCRUD() {
        let exp = expectation(description: "Test core data CRUD")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let moc = self.localdb.bgMOC
                let wsId = "test-ws"
                let mreq = self.localdb.createRequest(id: "edit-req", wsId: wsId, name: "Edit request", ctx: moc)
                XCTAssertNotNil(mreq)
                guard let req = mreq else { XCTFail(); return }
                guard let reqId = req.id else { XCTFail(); return }
                let ctx = req.managedObjectContext!
                let mh0 = self.localdb.createRequestData(id: "header-data-0", wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh0)
                guard let h0 = mh0 else { XCTFail(); return }
                h0.key = "h0"
                h0.value = "v0"
                req.addToHeaders(h0)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 1)
                let mh1 = self.localdb.createRequestData(id: "header-data-1", wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh1)
                guard let h1 = mh1 else { XCTFail(); return }
                h1.key = "h1"
                h1.value = "v1"
                req.addToHeaders(h1)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 2)
                let mh2 = self.localdb.createRequestData(id: "header-data-2", wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(mh2)
                guard let h2 = mh2 else { XCTFail(); return }
                h2.key = "h2"
                h2.value = "v2"
                req.addToHeaders(h2)
                XCTAssertNotNil(req.headers)
                XCTAssertEqual(req.headers!.count, 3)
                var x = self.localdb.getRequestData(at: 1, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h1.id!)
                x = self.localdb.getRequestData(at: 0, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h0.id!)
                x = self.localdb.getRequestData(at: 2, reqId: reqId, type: .header, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id!, h2.id!)
                XCTAssertNoThrow(self.localdb.saveBackgroundContext())
                var id = h1.id!
                let _header = self.localdb.getRequestData(id: id, ctx: ctx)
                self.localdb.deleteEntity(_header, ctx: ctx)
                XCTAssertEqual(req.headers!.count, 2)
                x = self.localdb.getRequestData(id: id, ctx: ctx)
                XCTAssertNil(x)
                id = h2.id!
                x = self.localdb.getRequestData(id: id, ctx: ctx)
                XCTAssertNotNil(x)
                XCTAssertEqual(x!.id, id)
                self.localdb.deleteEntity(req)
                XCTAssertNil(self.localdb.getRequest(id: reqId, ctx: ctx))
                // cleaup
                self.localdb.deleteEntity(h0)
                self.localdb.deleteEntity(h1)
                self.localdb.deleteEntity(h2)
                XCTAssertNoThrow(ctx.reset())
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testGetImageType() {
        let filePrivJPEG = "file:///private/var/mobile/Containers/Data/Application/0BD3B416-B9D5-4498-9781-08127199163F/tmp/60FA8CBF-2F96-464D-8DE4-C1D7FF59F698.jpeg"  // simulator
        let filePrivPNG = "file:///private/var/mobile/Containers/Data/Application/0BD3B416-B9D5-4498-9781-08127199163F/tmp/60FA8CBF-2F96-464D-8DE4-C1D7FF59F698.png"
        let filePrivJPEG1 = "file:///private/var/mobile/Containers/Data/Application/33784EF2-28F4-44A3-9278-F066DACD1717/tmp/8A0D19B0-2D08-47C3-BACD-AC788CBCD33E.jpeg"  // device
        var url = URL(fileURLWithPath: filePrivJPEG)
        var type = self.app.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .jpeg)
        url = URL(fileURLWithPath: filePrivPNG)
        type = self.app.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .png)
        url = URL(fileURLWithPath: filePrivJPEG1)
        type = self.app.getImageType(url)
        XCTAssertNotNil(type)
        XCTAssertEqual(type!, .jpeg)
    }
    
    func testFileRead() {
        let exp = expectation(description: "read file")
        if let path = Bundle.init(for: type(of: self)).path(forResource: "IMG_6109", ofType: "jpeg") {
            Log.debug("path: \(path)")
            let fm = EAFileManager(url: URL(fileURLWithPath: path))
            fm.readToEOF { result in
                switch result {
                case .success(let data):
                    Log.debug("data: \(data)")
                    XCTAssert(data.count > 0)
                case .failure(let error):
                    Log.error("error: \(error)")
                    XCTFail()
                }
                exp.fulfill()
            }
        }
        self.waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testBackgroundWorker() {
        let exp = self.expectation(description: "test background worker")
        let w = EABackgroundWorker()
        w.start {
            var acc: [Bool] = []
            for _ in 0...4 {
                acc.append(true)
            }
            w.stop()
            XCTAssertEqual(acc.count, 5)
            exp.fulfill()
        }
        self.waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testRequestToDictionary() {
        let exp = expectation(description: "Test core data CRUD")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let ctx = self.localdb.bgMOC
                let wsId = "test-ws"
                let file = self.localdb.createFile(data: Data(), wsId: wsId, name: "test-file", path: URL(fileURLWithPath: "/tmp"), checkExists: false, ctx: ctx)
                XCTAssertNotNil(file)
                let req = self.localdb.createRequest(id: self.localdb.requestId(), wsId: wsId, name: "test-request", project: nil, checkExists: true, ctx: ctx)
                XCTAssertNotNil(req)
                let reqData = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: wsId, type: .form, fieldFormat: .file, checkExists: false, ctx: ctx)
                XCTAssertNotNil(reqData)
                file!.requestData = reqData
                req!.body = self.localdb.createRequestBodyData(id: self.localdb.requestBodyDataId(), wsId: wsId, checkExists: false, ctx: ctx)
                XCTAssertNotNil(req!.body)
                req!.body!.addToForm(reqData!)
                let hm = self.localdb.requestToDictionary(req!)
                XCTAssertTrue(hm.count > 10)
                XCTAssertNotNil(hm["body"])
                XCTAssertTrue((hm["body"] as! [String: Any]).count > 10)
                XCTAssertEqual(((hm["body"] as! [String: Any])["form"] as! [[String: Any]]).count, 1)
                XCTAssertTrue((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]).count > 10)
                XCTAssertEqual((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]["files"] as! [[String: Any]]).count, 1)
                XCTAssertTrue(((((hm["body"] as! [String: Any])["form"] as! [[String: Any]])[0]["files"] as! [[String: Any]])[0]).count >= 10)
                self.localdb.discardChanges(in: ctx)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testRequestDidChange() {
        let exp = expectation(description: "Test request did change")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let ctx = self.localdb.bgMOC
                let wsId = "test-ws"
                let req = self.localdb.createRequest(id: self.localdb.requestId(), wsId: wsId, name: "test-request-change", project: nil, checkExists: false, ctx: ctx)
                XCTAssertNotNil(req)
                let tracker = EditRequestTracker(ctx: ctx, request: req!)
                let reqhma = self.localdb.requestToDictionary(req!)
                XCTAssertNotNil(reqhma)
                XCTAssert(reqhma.count > 0)
                let areq = req!
                var status = tracker.didRequestChangeImp(areq)
                XCTAssertFalse(status)
                areq.url = "https://example.com"
                status = tracker.didRequestURLChangeImp(areq.url ?? "")
                XCTAssertTrue(status)
                status = tracker.didRequestChangeImp(areq)
                XCTAssertTrue(status)
                let breq = areq
                let reqhmb = self.localdb.requestToDictionary(breq)
                XCTAssertNotNil(reqhmb)
                XCTAssert(reqhmb.count > 0)
                status = tracker.didRequestChangeImp(areq)
                XCTAssertTrue(status)
                let reqData = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(reqData)
                breq.addToHeaders(reqData!)
                XCTAssertNotNil(breq.headers)
                let reqDataxs = breq.headers!.allObjects as! [APITesterPro.ERequestData]
                XCTAssertTrue(tracker.didAnyRequestHeaderChangeImp(reqDataxs))
                XCTAssertTrue(tracker.didRequestChangeImp(areq))
                breq.removeFromHeaders(reqData!)
                XCTAssertTrue(tracker.didRequestChangeImp(areq))
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testFileAttachmentDelete() {
        let exp = expectation(description: "Test setting to-many to a new set deletes the contained entities")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            self.serialQueue.async {
                let moc = self.localdb.bgMOC
                let wsId = "test-ws"
                let mreq = self.localdb.createRequest(id: "edit-req", wsId: wsId, name: "Edit request", ctx: moc)
                XCTAssertNotNil(mreq)
                guard let req = mreq, let ctx = req.managedObjectContext else { XCTFail(); return }
                let abody = self.localdb.createRequestBodyData(id: "edit-req-body", wsId: wsId, checkExists: false, ctx: ctx)
                XCTAssertNotNil(abody)
                guard let body = abody else { XCTFail(); return }
                let mf0 = self.localdb.createRequestData(id: "body-form-data-0", wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                body.request = req
                XCTAssertNotNil(mf0)  // managed form object 0
                guard let f0 = mf0 else { XCTFail(); return }
                body.addToForm(f0)
                XCTAssertNotNil(body.form)
                XCTAssertEqual(body.form!.count, 1)
                let mfile0 = self.localdb.createFile(data: Data(), wsId: wsId, name: "file-0", path: URL(fileURLWithPath: "/tmp"), checkExists: false, ctx: ctx)
                XCTAssertNotNil(mfile0)
                f0.addToFiles(mfile0!)
                XCTAssertNotNil(f0.files)
                XCTAssertEqual(f0.files!.count, 1)
                f0.files = NSSet()  // Removing the to-many relation, does not delete the entities in it.
                XCTAssertEqual(f0.files!.count, 0)
                let xfile0 = self.localdb.getFileData(id: "file-0", ctx: ctx)
                XCTAssertNil(xfile0)
                let ereq = self.localdb.getRequest(id: "edit-req", ctx: ctx)
                XCTAssertNotNil(ereq)
                self.localdb.discardChanges(in: moc)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testWritingToFile() {
        let exp = expectation(description: "Copy contents of a the source file to destination")
        let str = "ok"
        let url = EAFileManager.getTemporaryURL("source.txt")
        EAFileManager.createFileIfNotExists(url)
        let fm = EAFileManager(url: url)
        fm.openFile(for: FileIOMode.write)
        XCTAssertTrue(fm.isFileOpened)
        fm.write(str)
        fm.close()
        if let docURL = EAFileManager.getDocumentDirectoryURL("dest.txt") {
            if EAFileManager.copy(source: url, destination: docURL) {
                XCTAssertTrue(EAFileManager.delete(url: url))
                let fm = EAFileManager(url: docURL)
                fm.openFile(for: .read)
                XCTAssertTrue(fm.isFileOpened)
                fm.readToEOF { result in
                    switch result {
                    case .success(let data):
                        let content = String(data: data, encoding: .utf8)!
                        XCTAssertEqual(content, str)
                    case .failure(let err):
                        Log.error(err)
                        XCTFail()
                    }
                    fm.close()
                    XCTAssertTrue(EAFileManager.delete(url: docURL))
                    exp.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 2.0, handler: nil)
    }
    
    func testCoreDataEnvVarSecureTransformer() {
        let exp = expectation(description: "test core data envvar secure transformer")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            let ctx = self.localdb.mainMOC
            ctx.perform {
                let lws = self.localdb.createWorkspace(id: "test-ws", name: "test-ws", desc: "", isSyncEnabled: false, ctx: ctx)
                XCTAssertNotNil(lws)
                guard let ws = lws else { return }
                XCTAssertEqual(ws.name, "test-ws")
                self.localdb.saveMainContext()
                let env = self.localdb.createEnv(name: "stag-test", envId: "env-1", wsId: ws.getId(), checkExists: false, ctx: ctx)
                XCTAssertNotNil(env)
                self.localdb.saveMainContext()
                let envVar = self.localdb.createEnvVar(name: "server", value: "example.com", ctx: ctx)
                XCTAssertNotNil(envVar)
                envVar?.env = env
                self.localdb.saveMainContext()
                let envs = self.localdb.getEnvs(wsId: ws.getId(), ctx: ctx) as [EEnv]
                XCTAssertNotNil(envs)
                XCTAssertEqual(envs.count, 1)
                let envVars = envs[0].variables?.allObjects as? [EEnvVar]
                XCTAssertNotNil(envVars)
                XCTAssertEqual(envVars!.count, 1)
                XCTAssertEqual(envVars![0].value as? NSString, "example.com")
                self.localdb.deleteEntity(envVar, ctx: ctx)
                self.localdb.deleteEntity(env, ctx: ctx)
                self.localdb.deleteEntity(ws, ctx: ctx)
                let aws = self.localdb.getWorkspace(id: "test-ws", ctx: ctx)
                XCTAssertNil(aws)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    func testGetCKRecordForWorspace() {
        let exp = expectation(description: "test getting CKRecord from EWorkspace")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            let ctx = self.localdb.mainMOC
            ctx.perform {
                let wsId = "ws-ck-record-get-test"
                let ws = self.localdb.createWorkspace(id: wsId, name: wsId, desc: "", isSyncEnabled: true, ctx: ctx)
                XCTAssertNotNil(ws)
                self.localdb.saveMainContext()
                let wsCKRecord = EWorkspace.getCKRecord(id: wsId, ctx: ctx)
                XCTAssertNotNil(wsCKRecord)
                XCTAssertEqual(wsCKRecord!.id(), wsId)
                XCTAssertTrue(wsCKRecord!.isSyncEnabled())
                // cleanup
                self.localdb.deleteEntity(ws, ctx: ctx)
                self.localdb.saveMainContext()
                let ws1 = self.localdb.getWorkspace(id: wsId, ctx: ctx)
                XCTAssertNil(ws1)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }
    
    /// Check if adding entity to the set will add a back reference to the parent automatically
    func testEntityReference() {
        let exp = expectation(description: "test core data entity referencing")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            let ctx = self.localdb.mainMOC
            ctx.perform {
                let wsId = "ws-backref-test"
                let projId = "pj-backref-test"
                let ws = self.localdb.createWorkspace(id: wsId, name: wsId, desc: "", isSyncEnabled: false, ctx: ctx)
                XCTAssertNotNil(ws)
                let proj = self.localdb.createProject(id: projId, wsId: wsId, name: projId, desc: "", ctx: ctx)
                XCTAssertNotNil(proj)
                if ws!.projects == nil {
                    ws!.projects = NSSet()
                }
                ws!.addToProjects(proj!)
                self.localdb.saveMainContext()
                XCTAssertNotNil(proj!.workspace)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0) { _ in
            do {
                try self.destroyPersistenceStore()
            } catch let error {
                XCTFail("\(error)")
            }
        }
    }
    
    func testCascadeDeleteTest() {
        let exp = expectation(description: "test core data entities cascade delete")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            let ctx = self.localdb.mainMOC
            ctx.perform {
                /*
                 ws (ws delete should cascade delete all *) - direct delete
                   - proj  (proj delete should cascade delete all referenced entities) - direct delete
                     - req method
                     - req
                       - req data (header)
                       - req data (param)
                       - req body data
                         - req data (form)
                           - file
                     - req 1 (req 1 delete should delete all referenced entities) - direct delete
                       - req body data
                         - req data (form)
                           - image
                       - history
                   - proj 1 (*)
                     - req 2 (*)
                   - env (env delete should delete env var) - direct delete
                     - env var
                   - env 1 (*)
                     - env var (*)
                 */
                let wsId = "ws-cascade-delete-test"
                let projId = "pj-cascade-delete-test"  // will be deleted directly
                let reqMethId = "rm-cascade-delete-test"  // will be casade deleted with project
                let reqId = "rq-cascade-delete-test"  // will be cascade deleted with project
                let reqDataHeaderId = "rd-cascade-delete-test-header"  // will be cascade deleted with project
                let reqDataParamId = "rd-cascade-delete-test-param"  // will be cascade deleted with project
                let reqBodyDataId = "rb-cascade-delete-test"  // will be cascade deleted with project
                let reqDataFormId = "rd-cascade-delete-test-form"  // will be cascade deleted with project
                let fileId = "fl-cascade-delete-test"  // will be cascade deleted with project
                
                let reqId1 = "rq-cascade-delete-test-1"  // will be deleted directly
                let reqBodyDataId1 = "rb-cascade-delete-test-1"  // will be cascade deleted with request 1
                let reqDataFormId1 = "rd-cascade-delete-test-form-1"  // will be cascade deleted with request 1
                let imageId = "im-cascade-delete-test"  // will be cascade deleted with request 1
                let historyId = "hs-cascade-delete-test"  // will be cascade delted with request 1
                
                let projId1 = "pj-cascade-delete-test-1"  // will be cascade deleted with workspace
                let reqId2 = "rq-cascade-delete-test-2"  // will be cascade deleted with workspace
                
                let envId = "en-cascade-delete-test"  // will be deleted directly
                let envVarId = "ev-cascade-delete-test"  // will be cascade deleted with env
                
                let envId1 = "en-cascade-delete-test-1"  // will be cascade deleted with workspace
                let envVarId1 = "ev-cascade-delete-test-1"  // will be cascade deleted with workspace
                
                let ws = self.localdb.createWorkspace(id: wsId, name: wsId, desc: "", isSyncEnabled: false, ctx: ctx)
                XCTAssertNotNil(ws)
                self.localdb.saveMainContext()
                
                // project - deleted directly
                let proj = self.localdb.createProject(id: projId, wsId: wsId, name: projId, desc: "", ctx: ctx)
                XCTAssertNotNil(proj)
                proj!.workspace = ws
                // request method - cascade delete with project
                let reqMeth = self.localdb.createRequestMethodData(id: reqMethId, wsId: wsId, name: reqMethId, ctx: ctx)
                XCTAssertNotNil(reqMeth)
                reqMeth!.project = proj
                // request - cascade deleted with project
                let req = self.localdb.createRequest(id: reqId, wsId: wsId, name: reqId, ctx: ctx)
                XCTAssertNotNil(req)
                req!.project = proj
                // header - cascade deleted with project
                let header = self.localdb.createRequestData(id: reqDataHeaderId, wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(header)
                header!.header = req
                // param - cascade deleted with project
                let param = self.localdb.createRequestData(id: reqDataParamId, wsId: wsId, type: .param, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(param)
                param!.param = req
                // body - cascade deleted with project
                let body = self.localdb.createRequestBodyData(id: reqBodyDataId, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(body)
                body!.request = req
                // form - cascade delete with project
                let form = self.localdb.createRequestData(id: reqDataFormId, wsId: wsId, type: .form, fieldFormat: .file)
                XCTAssertNotNil(form)
                form!.form = body
                // file - cascade delete with project
                let fileContent = "file".data(using: .utf8)
                XCTAssertNotNil(fileContent)
                let path = URL(fileURLWithPath: "/tmp/test.txt")
                let file = self.localdb.createFile(fileId: fileId, data: fileContent!, wsId: wsId, name: fileId, path: path, type: .form, ctx: ctx)
                XCTAssertNotNil(file)
                file!.requestData = form
                self.localdb.saveMainContext()
                // delete proj
                self.localdb.deleteEntity(proj, ctx: ctx)
                self.localdb.saveMainContext()
                // test for cascade delete
                let _file = self.localdb.getFileData(id: fileId, ctx: ctx)
                XCTAssertNil(_file)
                let _form = self.localdb.getRequestData(id: reqDataFormId, ctx: ctx)
                XCTAssertNil(_form)
                let _body = self.localdb.getRequestBodyData(id: reqBodyDataId, ctx: ctx)
                XCTAssertNil(_body)
                let _param = self.localdb.getRequestData(id: reqDataParamId, ctx: ctx)
                XCTAssertNil(_param)
                let _header = self.localdb.getRequestData(id: reqDataHeaderId, ctx: ctx)
                XCTAssertNil(_header)
                let _reqMeth = self.localdb.getRequestMethodData(id: reqMethId, ctx: ctx)
                XCTAssertNil(_reqMeth)
                let _proj = self.localdb.getProject(id: projId, ctx: ctx)
                XCTAssertNil(_proj)
                
                // request 1 - deleted directly
                let req1 = self.localdb.createRequest(id: reqId1, wsId: wsId, name: reqId1, ctx: ctx)
                XCTAssertNotNil(req1)
                // body cascade delete with request 1
                let body1 = self.localdb.createRequestBodyData(id: reqBodyDataId1, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(body1)
                body1!.request = req1
                // form cascade delete with request 1
                let form1 = self.localdb.createRequestData(id: reqDataFormId1, wsId: wsId, type: .form, fieldFormat: .file)
                XCTAssertNotNil(form1)
                form1!.form = body1
                // image cascade delete with request 1
                let img = self.localdb.createImage(imageId: imageId, data: Data(), wsId: wsId, name: imageId, type: "png", ctx: ctx)
                XCTAssertNotNil(img)
                img!.requestData = form1
                // history cascade delete with request 1
                let history = self.localdb.createHistory(id: historyId, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(history)
                history!.request = req1
                self.localdb.saveMainContext()
                // delete request 1
                self.localdb.deleteEntity(req1, ctx: ctx)
                self.localdb.saveMainContext()
                // test cascade delete of request 1
                let _history = self.localdb.getHistory(id: historyId, ctx: ctx)
                XCTAssertNil(_history)
                let _img = self.localdb.getImageData(id: imageId, ctx: ctx)
                XCTAssertNil(_img)
                let _form1 = self.localdb.getRequestData(id: reqDataFormId1, ctx: ctx)
                XCTAssertNil(_form1)
                let _body1 = self.localdb.getRequestBodyData(id: reqBodyDataId1, ctx: ctx)
                XCTAssertNil(_body1)
                let _req1 = self.localdb.getRequest(id: reqId1, ctx: ctx)
                XCTAssertNil(_req1)
                
                // env - deleted directly
                let env = self.localdb.createEnv(name: envId, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(env)
                env!.workspace = ws
                let envVar = self.localdb.createEnvVar(name: envVarId, value: "server", id: envVarId, ctx: ctx)
                XCTAssertNotNil(envVar)
                envVar!.env = env
                self.localdb.saveMainContext()
                XCTAssertNotNil(envVar!.env)
                // delete env and ensure envVar is also deleted
                self.localdb.deleteEntity(env, ctx: ctx)
                self.localdb.saveMainContext()
                let _env = self.localdb.getEnv(id: envId, ctx: ctx)
                XCTAssertNil(_env)
                let _envVar = self.localdb.getEnvVar(id: envVarId, ctx: ctx)
                XCTAssertNil(_envVar)
                
                // project 1 - cascade deleted with workspace
                let proj1 = self.localdb.createProject(id: projId1, wsId: wsId, name: projId1, desc: "", ctx: ctx)
                XCTAssertNotNil(proj1)
                proj1!.workspace = ws
                // request 2 - cascade delete with workspace
                let req2 = self.localdb.createRequest(id: reqId2, wsId: wsId, name: reqId2, ctx: ctx)
                XCTAssertNotNil(req2)
                req2!.project = proj1
                // env 1 - cascade deleted with workspace
                let env1 = self.localdb.createEnv(name: envId1, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(env1)
                env1!.workspace = ws
                let envVar1 = self.localdb.createEnvVar(name: envVarId1, value: "server", id: envVarId1, ctx: ctx)
                XCTAssertNotNil(envVar1)
                envVar1!.env = env1
                XCTAssertNotNil(envVar1!.env)
                self.localdb.saveMainContext()
                // delete workspace
                self.localdb.deleteEntity(ws)
                self.localdb.saveMainContext()
                // ensure rest of the referenced entities are also deleted
                let _envVar1 = self.localdb.getEnvVar(id: envVarId1, ctx: ctx)
                XCTAssertNil(_envVar1)
                let _env1 = self.localdb.getEnv(id: envId1, ctx: ctx)
                XCTAssertNil(_env1)
                let _req2 = self.localdb.getRequest(id: reqId2, ctx: ctx)
                XCTAssertNil(_req2)
                let _proj1 = self.localdb.getProject(id: projId1, ctx: ctx)
                XCTAssertNil(_proj1)
                let _ws = self.localdb.getWorkspace(id: wsId, ctx: ctx)
                XCTAssertNil(_ws)
                
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0)
    }
    
    func testEntitiesDeletionOnDisabledZoneSync() {
        let exp = expectation(description: "test deletion of workspace and all entities in it when a disabled zone record gets synced")
        self.localdb.setup(storeType: NSSQLiteStoreType) {
            let ctx = self.localdb.mainMOC
            ctx.perform {
                let wsId = "ws-sync-delete-test"
                let envId = "en-sync-delete-test"
                let envVarId = "ev-sync-delete-test"
                let projId = "pj-sync-delete-test"
                let reqId = "rq-sync-delete-test"
                let headerId = "rd-header-sync-delete-test"
                let fileId = "fl-sync-delete-test"
                let formId = "rd-form-sync-delete-test"
                let bodyId = "rb-body-with-file-sync-delete-test"
                let ws = self.localdb.createWorkspace(id: wsId, name: wsId, desc: "", isSyncEnabled: true, ctx: ctx)
                XCTAssertNotNil(ws)
                self.localdb.saveMainContext()
                let env = self.localdb.createEnv(name: envId, wsId: wsId, ctx: ctx)
                XCTAssertNotNil(env)
                self.localdb.saveMainContext()
                let envVar = self.localdb.createEnvVar(name: envVarId, value: "server", id: envVarId, checkExists: false, ctx: ctx)
                XCTAssertNotNil(envVar)
                envVar?.env = env
                self.localdb.saveMainContext()
                let proj = self.localdb.createProject(id: projId, wsId: wsId, name: projId, desc: "", ctx: ctx)
                XCTAssertNotNil(proj)
                proj?.workspace = ws
                self.localdb.saveMainContext()
                let req = self.localdb.createRequest(id: reqId, wsId: wsId, name: reqId, ctx: ctx)
                XCTAssertNotNil(req)
                req?.project = proj
                self.localdb.saveMainContext()
                let header = self.localdb.createRequestData(id: headerId, wsId: wsId, type: .header, fieldFormat: .text, ctx: ctx)
                XCTAssertNotNil(header)
                header!.key = "name"
                header!.value = "value"
                req!.addToHeaders(header!)
                XCTAssertNotNil(req!.headers)
                XCTAssertEqual(req!.headers!.count, 1)
                self.localdb.saveMainContext()
                let file = self.localdb.createFile(fileId: fileId, data: Data(), wsId: wsId, name: fileId, path: URL(fileURLWithPath: "/tmp"), type: .form, checkExists: false, ctx: ctx)
                XCTAssertNotNil(file)
                let fileReqData = self.localdb.createRequestData(id: formId, wsId: wsId, type: .form, fieldFormat: .file, checkExists: false, ctx: ctx)
                XCTAssertNotNil(fileReqData)
                file!.requestData = fileReqData!
                req!.body = self.localdb.createRequestBodyData(id: bodyId, wsId: wsId, checkExists: false, ctx: ctx)
                XCTAssertNotNil(req!.body)
                req!.body!.request = req
                XCTAssertNotNil(req!.body!.request)
                req!.body!.addToForm(fileReqData!)
                XCTAssertNotNil(req!.body!.form)
                XCTAssertEqual(req!.body!.form!.count, 1)
                self.localdb.saveMainContext()
                // delete entities starting from workspace
                // TODO: fix me
                // self.dbSvc.deleteDataMarkedForDelete(ws!, isDeleteFromCloud: false, ctx: ctx)
                // ensure entities are deleted
                let ws1 = self.localdb.getWorkspace(id: wsId, ctx: ctx)
                XCTAssertNil(ws1)
                let env1 = self.localdb.getEnv(id: envId, ctx: ctx)
                XCTAssertNil(env1)
                let envVar1 = self.localdb.getEnvVar(id: envVarId, ctx: ctx)
                XCTAssertNil(envVar1)
                let proj1 = self.localdb.getProject(id: projId, ctx: ctx)
                XCTAssertNil(proj1)
                let req1 = self.localdb.getRequest(id: reqId, ctx: ctx)
                XCTAssertNil(req1)
                let header1 = self.localdb.getRequestData(id: headerId, ctx: ctx)
                XCTAssertNil(header1)
                let file1 = self.localdb.getFileData(id: fileId, ctx: ctx)
                XCTAssertNil(file1)
                let fileReqData1 = self.localdb.getRequestData(id: formId, ctx: ctx)
                XCTAssertNil(fileReqData1)
                let reqBody1 = self.localdb.getRequestBodyData(id: bodyId, ctx: ctx)
                XCTAssertNil(reqBody1)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.0) { _ in
            do {
                try self.destroyPersistenceStore()
            } catch {
                XCTFail("Error deleting persistence store: \(error)")
            }
        }
    }
    
    func testTemp() {
        let exp = expectation(description: "test")
        let printerOperation = BlockOperation()

        printerOperation.addExecutionBlock { print("I") }
        printerOperation.addExecutionBlock { print("am") }
        printerOperation.addExecutionBlock { print("printing") }
        printerOperation.addExecutionBlock { print("block") }
        printerOperation.addExecutionBlock { print("operation") }

        printerOperation.completionBlock = {
            print("I'm done printing")
            exp.fulfill()
        }

        let operationQueue = OperationQueue()
        operationQueue.addOperation(printerOperation)
        waitForExpectations(timeout: 10.0, handler: nil)
    }

    // Test Case '-[APITesterProTests.APITesterProTests testArrayHeadInsertOpPerformance]' measured [Time, seconds] average: 0.384, relative standard deviation: 50.964%, values: [0.075234, 0.140064, 0.218556, 0.280060, 0.357666, 0.415854, 0.488974, 0.570821, 0.598408, 0.694492], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
    // Test Case '-[APITesterProTests.APITesterProTests testArrayHeadInsertOpPerformance]' passed (4.148 seconds).
    // Test Suite 'APITesterProTests' passed at 2020-04-30 00:50:22.581.
    //      Executed 1 test, with 0 failures (0 unexpected) in 4.148 (4.149) seconds
    // Test Suite 'APITesterProTests.xctest' passed at 2020-04-30 00:50:22.581.
    //      Executed 1 test, with 0 failures (0 unexpected) in 4.148 (4.150) seconds
    // Test Suite 'Selected tests' passed at 2020-04-30 00:50:22.582.
    //      Executed 1 test, with 0 failures (0 unexpected) in 4.148 (4.151) seconds
    func notestArrayHeadInsertOpPerformance() {
        var xs: [Int] = []
        self.measure {
            for i in 0..<10_000 {
                xs.insert(i, at: 0)
            }
        }
    }
    
    // Test Case '-[APITesterProTests.APITesterProTests testArrayTailAppendOpPerformance]' measured [Time, seconds] average: 0.010, relative standard deviation: 35.236%, values: [0.015567, 0.014334, 0.013879, 0.011954, 0.009574, 0.007280, 0.006812, 0.007016, 0.006218, 0.006473], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
    // Test Case '-[APITesterProTests.APITesterProTests testArrayTailAppendOpPerformance]' passed (0.399 seconds).
    // Test Suite 'APITesterProTests' passed at 2020-04-30 00:49:32.807.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.399 (0.400) seconds
    // Test Suite 'APITesterProTests.xctest' passed at 2020-04-30 00:49:32.807.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.399 (0.401) seconds
    // Test Suite 'Selected tests' passed at 2020-04-30 00:49:32.808.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.399 (0.402) seconds
    func notestArrayTailAppendOpPerformance() {
        var xs: [Int] = []
        self.measure {
            for i in 0..<10_000 {
                xs.append(i)
            }
        }
    }

    // Test Case '-[APITesterProTests.APITesterProTests testArrayHeadRemoveOpPerformance]' measured [Time, seconds] average: 0.007, relative standard deviation: 299.468%, values: [0.070026, 0.000037, 0.000010, 0.000009, 0.000009, 0.000009, 0.000009, 0.000009, 0.000009, 0.000009], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
    // Test Case '-[APITesterProTests.APITesterProTests testArrayHeadRemoveOpPerformance]' passed (0.384 seconds).
    // Test Suite 'APITesterProTests' passed at 2020-04-30 00:45:50.401.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.384 (0.385) seconds
    // Test Suite 'APITesterProTests.xctest' passed at 2020-04-30 00:45:50.401.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.384 (0.386) seconds
    // Test Suite 'Selected tests' passed at 2020-04-30 00:45:50.402.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.384 (0.388) seconds
    func notestArrayHeadRemoveOpPerformance() {
        var xs: [Int] = []
        for i in 0..<10_000 { xs.append(i) }
        self.measure {
            while true {
                if xs.isEmpty { break }
                xs.remove(at: 0)
            }
        }
    }
    
    // Test Case '-[APITesterProTests.APITesterProTests testArrayTailPopOpPerformance]' measured [Time, seconds] average: 0.000, relative standard deviation: 286.638%, values: [0.004537, 0.000049, 0.000019, 0.000018, 0.000017, 0.000017, 0.000017, 0.000017, 0.000017, 0.000017], performanceMetricID:com.apple.XCTPerformanceMetric_WallClockTime, baselineName: "", baselineAverage: , maxPercentRegression: 10.000%, maxPercentRelativeStandardDeviation: 10.000%, maxRegression: 0.100, maxStandardDeviation: 0.100
    // Test Case '-[APITesterProTests.APITesterProTests testArrayTailPopOpPerformance]' passed (0.337 seconds).
    // Test Suite 'APITesterProTests' passed at 2020-04-30 00:47:52.335.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.337 (0.338) seconds
    // Test Suite 'APITesterProTests.xctest' passed at 2020-04-30 00:47:52.336.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.337 (0.339) seconds
    // Test Suite 'Selected tests' passed at 2020-04-30 00:47:52.337.
    //      Executed 1 test, with 0 failures (0 unexpected) in 0.337 (0.342) seconds
    func testArrayTailPopOpPerformance() {
        var xs: [Int] = []
        for i in 0..<10_000 { xs.append(i) }
        self.measure {
            while true {
                if xs.isEmpty { break }
                _ = xs.popLast()
            }
        }
    }
}

public extension NSManagedObject {
    /// Change init to method to use insertInto method.
    convenience init(usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }
}
