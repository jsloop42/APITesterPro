//
//  EditRequestTracker.swift
//  APITesterPro
//
//  Created by Jaseem V V on 03/12/23.
//  Copyright © 2023 Jaseem V V. All rights reserved.
//

import Foundation
import CoreData

/// Used to track add/edit request changes state. The request entity associated should be in a background context until saved.
public class EditRequestTracker {
    private lazy var localdb: CoreDataService = { CoreDataService.shared }()
    var ctx: NSManagedObjectContext
    var request: ERequest
    /// Used in diff check which contains the initial request data before any changes
    var requestDict: [String: Any] = [:]
    /// Holds the entites which are present in the request but deleted. Such entites will have back references removed so that it does not appear in UI. We need to manually delete such entites.
    var deletedEntites: Set<AnyHashable> = Set()
    // Entity diff check
    /// Entity diff rescheduler. If user is editing request elements, this will be called in succession and previous timer will be reset.
    var diffRescheduler = EARescheduler(interval: 0.3, type: .everyFn)
    /// Diff ids for `EAReschedulerFn`s
    private let fnIdReq = "request-fn"
    private let fnIdReqMethodIndex = "request-method-index-fn"
    private let fnIdReqMethod = "request-method-fn"
    private let fnIdAnyReqMethod = "any-request-method-fn"
    private let fnIdReqURL = "request-url-fn"
    private let fnIdReqName = "request-name-fn"
    private let fnIdReqDesc = "request-description-fn"
    private let fnIdReqMeta = "request-meta-fn"
    private let fnIdReqHeader = "request-header-fn"
    private let fnIdReqParam = "request-param-fn"
    private let fnIdReqBody = "request-body-fn"
    private let fnIdAnyReqBodyForm = "any-request-body-form-fn"
    private let fnIdReqBodyForm = "request-body-form-fn"
    private let fnIdReqBodyFormAttachment = "request-body-form-attachment-fn"
    private let fnIdReqData = "request-data-fn"
    private let fnIdReqFile =  "request-file-fn"
    private let fnIdReqImage = "request-image-fn"
    /// Edit started ts which will be used for all entities that changed
    var modified: Int64
    /// If a custom request method which was persisted is deleted this flag is set
    private var isRequestMethodDelete = false
    
    init(ctx: NSManagedObjectContext, request: ERequest) {
        self.ctx = ctx
        self.request = request
        self.modified = Date().currentTimeNanos()
        self.requestDict = self.localdb.requestToDictionary(self.request)
    }
    
    deinit {
        Log.debug("deinit edit request tracker")
        self.diffRescheduler.done()
    }
    /// Add a marked for delete entity for tracking
    func trackDeletedEntity(_ entity: any Entity) {
        if entity.objectID.isTemporaryID {  // if entity has temporary ID means it's newly added and then removed. We can safely delete such entities.
            self.localdb.deleteEntity(entity)
            return
        }
        if entity is ERequestMethodData {
            self.isRequestMethodDelete = true
        }
        _ = self.deletedEntites.insert(entity)
    }
    
    /// Remove all tracked entites. Once the context is saved this can be invoked.
    func clearTrackedEntites() {
        self.deletedEntites.removeAll()
    }
    
    func updateModified(_ x: (any Entity)?) {
        if let x = x {
            x.setModified(self.modified)
        }
    }
    
    // MARK: - Entity change tracking
    
    // Checks if any property changed in the request during edit. This is used for deleted entity tracking and enabling save button.
    
    /// Checks if the request changed.
    /// - Parameters:
    ///   - x: The request object.
    ///   - callback: The callback function.
    func didRequestChange(_ x: ERequest, callback: @escaping (Bool) -> Void) {
        // If a custom request method is deleted, we need to save
        if isRequestMethodDelete { callback(true); return }
        // We need to check the whole object for change because, if a element changes, we set true, if another element did not change, we cannot
        // set false. So we would then have to keep track of which element changed the status and such.
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReq, block: { [weak self] () -> Bool in
            guard let self else { return true }
            var status = true
            x.managedObjectContext?.performAndWait { status = self.didRequestChangeImp(x) }
            return status
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request changed.
    /// - Parameters:
    ///   - x: The request object.
    ///   - request: The initial request dictionary.
    func didRequestChangeImp(_ x: ERequest) -> Bool {
        if x.markForDelete != self.requestDict["markForDelete"] as? Bool { x.isSynced = false; self.updateModified(x); return true }
        if x.url == nil || x.url!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if x.validateSSL != self.requestDict["validateSSL"] as? Bool { self.updateModified(x); return true }
        if self.didRequestURLChangeImp(x.url ?? "") { self.updateModified(x); return true }
        if self.didRequestMetaChangeImp(name: x.name ?? "", desc: x.desc ?? "") { self.updateModified(x); return true }
        if self.didRequestMethodIndexChangeImp(x.selectedMethodIndex) { self.updateModified(x); return true }
        if (x.method == nil && self.requestDict["method"] != nil) || (x.method != nil && (x.method!.isInserted || x.method!.isDeleted) && requestDict["method"] == nil) { return true }
        if let hm = self.requestDict["method"] as? [String: Any], let ida = x.id, let idb = hm["id"] as? String, ida != idb { return true }
        guard let projId = x.project?.getId() else { return true }
        let methods = self.localdb.getRequestMethodData(projId: projId, ctx: x.managedObjectContext)
        if self.didAnyRequestMethodChangeImp(methods) { return true }
        if self.didRequestBodyChangeImp(x.body) { return true }
        if let headers = x.headers?.allObjects as? [ERequestData] {
            if self.didAnyRequestHeaderChangeImp(headers) { return true }
        } else {
            if let headers = self.requestDict["headers"] as? [[String: Any]], headers.count > 0 { return true }
        }
        if let params = x.params?.allObjects as? [ERequestData] {
            if self.didAnyRequestParamChangeImp(params) { return true }
        } else {
            if let params = self.requestDict["params"] as? [[String: Any]], params.count > 0 { return true }
        }
        return false
    }
    
    /// Checks if the selected request method changed.
    /// - Parameters:
    ///   - x: The selected request method index.
    ///   - callback: The callback function.
    func didRequestMethodIndexChange(_ x: Int64, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMethodIndex, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestMethodIndexChangeImp(x)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the selected request method changed.
    /// - Parameters:
    ///   - x: The selected request method index.
    func didRequestMethodIndexChangeImp(_ x: Int64) -> Bool {
        if let index = self.requestDict["selectedMethodIndex"] as? Int64 { return x != index }
        return false
    }
    
    /// Checks if the request method changed.
    /// - Parameters:
    ///   - x: The request method.
    ///   - y: The initial request method dictionary.
    ///   - callback: The callback function.
    func didRequestMethodChange(_ x: ERequestMethodData, reqMethDict: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMethod, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestMethodChangeImp(x, reqMethDict: reqMethDict)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request method changed.
    /// - Parameters:
    ///   - x: The request method.
    ///   - reqMethDict: The initial request method dictionary.
    func didRequestMethodChangeImp(_ x: ERequestMethodData, reqMethDict: [String: Any]) -> Bool {
        if x.created != reqMethDict["created"] as? Int64 ||
            x.isCustom != reqMethDict["isCustom"] as? Bool ||
            x.name != reqMethDict["name"] as? String ||
            x.markForDelete != reqMethDict["markForDelete"] as? Bool {
            self.updateModified(x)
            return true
        }
        return false
    }
    
    /// Checks if any request method changed.
    /// - Parameters:
    ///   - xs: The list of request methods.
    ///   - callback: The callback function.
    func didAnyRequestMethodChange(_ xs: [ERequestMethodData], request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdAnyReqMethod, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didAnyRequestMethodChangeImp(xs)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Checks if any custom request method changed.
    /// - Parameters:
    ///   - xs: The list of request methods.
    func didAnyRequestMethodChangeImp(_ xs: [ERequestMethodData]) -> Bool {
        let xsa = xs.filter { x -> Bool in
            let flag = x.isCustom && x.hasChanges
            return flag
        }
        let xsb = (self.requestDict["methods"] as? [[String: Any]])?.filter({ hm -> Bool in
            if let isCustom = hm["isCustom"] as? Bool { return isCustom }
            return false
        })
        let len = xsa.count
        if xsb == nil && len > 0 { return true }
        if xsb != nil && xsb!.count != len { return true }
        if xsb != nil {
            for i in 0..<len {
                if self.didRequestMethodChangeImp(xsa[i], reqMethDict: xsb![i]) { return true }
            }
        }
        return false
    }
    
    /// Checks if the request URL changed.
    /// - Parameters:
    ///   - url: The request url.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestURLChange(_ url: String, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqURL, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestURLChangeImp(url)
        }, callback: { status in
            callback(status)
        }, args: [url]))
    }
    
    /// Checks if the request URL changed.
    /// - Parameters:
    ///   - url: The request url.
    func didRequestURLChangeImp(_ url: String) -> Bool {
        if let aUrl = self.requestDict["url"] as? String { return aUrl != url }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request name changed.
    /// - Parameters:
    ///   - name: The request name
    ///   - callback: The callback function.
    func didRequestNameChange(_ name: String, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqName, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestNameChangeImp(name)
        }, callback: { status in
            callback(status)
        }, args: [name]))
    }
    
    /// Checks if the request name changed.
    /// - Parameters:
    ///   - name: The request name
    func didRequestNameChangeImp(_ name: String) -> Bool {
        if let aName = self.requestDict["name"] as? String { return aName != name }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request description changed.
    /// - Parameters:
    ///   - desc: The request description.
    ///   - callback: The callback function.
    func didRequestDescriptionChange(_ desc: String, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqDesc, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestDescriptionChangeImp(desc)
        }, callback: { status in
            callback(status)
        }, args: [desc]))
    }
    
    /// Checks if the request description changed.
    /// - Parameters:
    ///   - desc: The request description.
    func didRequestDescriptionChangeImp(_ desc: String) -> Bool {
        if let aDesc = self.requestDict["desc"] as? String { return aDesc != desc }
        return !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if any of the request's metadata (name, desc) changed.
    func didRequestMetaChange(name: String, desc: String, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMeta, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestMetaChangeImp(name: name, desc: desc)
        }, callback: { status in
            callback(status)
        }, args: [name, desc]))
    }
    
    func didRequestMetaChangeImp(name: String, desc: String) -> Bool {
        return self.didRequestNameChangeImp(name) || self.didRequestDescriptionChangeImp(desc)
    }
    
    func didAnyRequestHeaderChange(_ xs: [ERequestData], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqHeader, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didAnyRequestHeaderChangeImp(xs)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Check if any of the request headers changed.
    func didAnyRequestHeaderChangeImp(_ xs: [ERequestData]) -> Bool {
        var xs: [any Entity] = xs
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (self.requestDict["headers"] as! [[String: Any]]).count { return true }
        let headers: [[String: Any]] = self.requestDict["headers"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChangeImp(x: xs[i] as! ERequestData, reqData: headers[i], type: .header) { return true }
        }
        return false
    }

    func didAnyRequestParamChange(_ xs: [ERequestData], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqParam, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didAnyRequestParamChangeImp(xs)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Check if any of the request params changed.
    func didAnyRequestParamChangeImp(_ xs: [ERequestData]) -> Bool {
        var xs: [any Entity] = xs
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (self.requestDict["params"] as! [[String: Any]]).count { return true }
        let params: [[String: Any]] = self.requestDict["params"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChangeImp(x: xs[i] as! ERequestData, reqData: params[i], type: .param) { return true }
        }
        return false
    }
    
    func didRequestBodyChange(_ x: ERequestBodyData?, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBody, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestBodyChangeImp(x)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request body changed
    func didRequestBodyChangeImp(_ x: ERequestBodyData?) -> Bool {
        if (x == nil && self.requestDict["body"] != nil) || (x != nil && self.requestDict["body"] == nil) { x?.isSynced = false; return true }
        if let body = self.requestDict["body"] as? [String: Any] {
            if x?.json != body["json"] as? String ||
                x?.raw != body["raw"] as? String ||
                x?.selected != body["selected"] as? Int64 ||
                x?.xml != body["xml"] as? String ||
                // x?.markForDelete != self.requestDict["markForDelete"] as? Bool {  // TODO: check this is correct - orig
                x?.markForDelete != body["markForDelete"] as? Bool {
                x?.isSynced = false
                self.updateModified(x)
                return true
            }
            if x != nil && self.didAnyRequestBodyFormChangeImp(x!) { return true }
        }
        return false
    }
    
    func didAnyRequestBodyFormChange(_ x: ERequestBodyData, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdAnyReqBodyForm, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didAnyRequestBodyFormChangeImp(x)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the any of the request body form elements changed.
    func didAnyRequestBodyFormChangeImp(_ x: ERequestBodyData) -> Bool {
        if self.requestDict["body"] == nil { x.isSynced = false; return true }
        if let body = self.requestDict["body"] as? [String: Any] {
            if (x.form != nil && body["form"] == nil) || (x.form == nil && body["form"] != nil) { return true }
            if (x.multipart != nil && body["multipart"] == nil) || (x.multipart == nil && body["multipart"] != nil) { return true }
            var formxsa: [any Entity] = []
            var formxsb: [[String: Any]] = []
            let selectedType = RequestBodyType(rawValue: x.selected.toInt()) ?? .form
            var reqDataType = RequestDataType.form
            if selectedType == .form {
                formxsa = x.form!.allObjects as! [any Entity]
                formxsb = body["form"] as! [[String: Any]]
                reqDataType = .form
            } else if selectedType == .multipart {
                formxsa = x.multipart?.allObjects as! [any Entity]
                formxsb = body["multipart"] as! [[String: Any]]
                reqDataType = .multipart
            } else if selectedType == .binary {
                return self.didRequestBodyBinaryChangeImp(x.binary, body: body)
            }
            if formxsa.count != formxsb.count { return true }
            self.localdb.sortByCreated(&formxsa)
            
            let len = formxsa.count
            for i in 0..<len {
                if self.didRequestDataChangeImp(x: formxsa[i] as! ERequestData, reqData: formxsb[i], type: reqDataType) { return true }
            }
        }
        return false
    }
    
    func didRequestBodyBinaryChangeImp(_ reqData: ERequestData?, body: [String: Any]) -> Bool {
        let obin = body["binary"] as? [String: Any]
        if (obin == nil && reqData != nil) || (obin != nil && reqData == nil) { reqData?.isSynced = false; self.updateModified(reqData); return true }
        guard let lbin = reqData, let rbin = obin else { reqData?.isSynced = false; self.updateModified(reqData); return true }
        if lbin.created != rbin["created"] as? Int64 || lbin.markForDelete != rbin["markForDelete"] as? Bool { reqData?.isSynced = false; self.updateModified(reqData); return true }
        if self.didRequestBodyFormAttachmentChangeImp(lbin, reqData: rbin) { reqData?.isSynced = false; self.updateModified(reqData); return true }
        return false
    }
    
    func didRequestBodyFormChange(_ body: ERequestBodyData, reqData: ERequestData, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBodyForm, block: { () -> Bool in
            return self.didRequestBodyFormChangeImp(body, reqData: reqData)
        }, callback: { status in
            callback(status)
        }, args: [body]))
    }
    
    // TODO: add unit test
    func didRequestBodyFormChangeImp(_ body: ERequestBodyData, reqData: ERequestData) -> Bool {
        if let reqDataId = reqData.id, let set = body.form, let xs = set.allObjects as? [ERequestData], let _ = xs.first(where: { x -> Bool in
            x.id == reqDataId
        }) {
            // Check if form and request data are the same
            if let type = RequestDataType(rawValue: reqData.type.toInt()) {
                if let bodyDict = self.requestDict["body"] as? [String: Any], let formsList = bodyDict["form"] as? [[String: Any]],
                   let formDict = formsList.first(where: { dict in
                       dict["id"] as! String == reqDataId
                   }) {
                    // if self.didRequestDataChangeImp(x: reqData, y: request, type: type) { body.isSynced = false; return true }  // TODO: check if this is correct - orig
                    if self.didRequestDataChangeImp(x: reqData, reqData: formDict, type: type) { body.isSynced = false; return true }
                }
                
            }
        } else {  // No request data found in forms => added
            return true
        }
        return false
    }
    
    func didRequestBodyFormAttachmentChange(_ x: ERequestData, reqData: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBodyFormAttachment, block: { () -> Bool in
            return self.didRequestBodyFormAttachmentChangeImp(x, reqData: reqData)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the given form's attachments changed.
    func didRequestBodyFormAttachmentChangeImp(_ x: ERequestData, reqData: [String: Any]) -> Bool {
        if (x.image != nil && reqData["image"] == nil) || (x.image == nil && reqData["image"] != nil) { x.isSynced = false; self.updateModified(x); return true }
        if let ximage = x.image, let yimage = reqData["image"] as? [String: Any]  {
            if self.didRequestImageChangeImp(x: ximage, img: yimage) { x.isSynced = false; self.updateModified(x); return true }
        }
        if (x.files != nil && reqData["files"] == nil) || (x.files == nil && reqData["file"] != nil) { return true }
        let yfiles = reqData["files"] as! [[String: Any]]
        if x.files!.count != yfiles.count { x.isSynced = false; return true }
        if let set = x.files, var xs = set.allObjects as? [any Entity] {
            self.localdb.sortByCreated(&xs)
            let len = xs.count
            for i in 0..<len {
                if self.didRequestFileChangeImp(x: xs[i] as! EFile, file: yfiles[i]) { return true }
            }
        }
        return false
    }
    
    func didRequestDataChange(x: ERequestData, reqData: [String: Any], type: RequestDataType, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqData, block: { () -> Bool in
            return self.didRequestDataChangeImp(x: x, reqData: reqData, type: type)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestDataChangeImp(x: ERequestData, reqData: [String: Any], type: RequestDataType) -> Bool {
        if x.created != reqData["created"] as? Int64 ||
            x.fieldFormat != reqData["fieldFormat"] as? Int64 ||
            x.key != reqData["key"] as? String ||
            x.type != reqData["type"] as? Int64 ||
            x.value != reqData["value"] as? String ||
            x.markForDelete != reqData["markForDelete"] as? Bool {
            x.isSynced = false
            self.updateModified(x)
            return true
        }
        if type == .form {
            if self.didRequestBodyFormAttachmentChangeImp(x, reqData: reqData) { return true }
        }
        return false
    }
    
    func didRequestFileChange(x: EFile, file: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqFile, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestFileChangeImp(x: x, file: file)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestFileChangeImp(x: EFile, file: [String: Any]) -> Bool {
        if x.created != file["created"] as? Int64 ||
            x.name != file["name"] as? String ||
            x.type != file["type"] as? Int64 ||
            x.markForDelete != file["markForDelete"] as? Bool {
            x.isSynced = false
            self.updateModified(x)
            return true
        }
        if let id = x.id, let xdata = x.data, let _file = self.localdb.getFileData(id: id), let ydata = _file.data {
            if xdata != ydata { x.isSynced = false; self.updateModified(x); return true }
        }
        return false
    }
    
    func didRequestImageChange(x: EImage, img: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqImage, block: { [weak self] () -> Bool in
            guard let self else { return true }
            return self.didRequestImageChangeImp(x: x, img: img)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestImageChangeImp(x: EImage, img: [String: Any]) -> Bool {
        if x.created != img["created"] as? Int64 ||
            x.name != img["name"] as? String ||
            x.isCameraMode != img["isCameraMode"] as? Bool ||
            x.type != img["type"] as? String ||
            x.markForDelete != img["markForDelete"] as? Bool {
            x.isSynced = false
            self.updateModified(x)
            return true
        }
        if let id = x.id, let xdata = x.data, let image = self.localdb.getImageData(id: id), let ydata = image.data {
            if xdata != ydata { x.isSynced = false; self.updateModified(x); return true }
        }
        return false
    }
    
    
}
