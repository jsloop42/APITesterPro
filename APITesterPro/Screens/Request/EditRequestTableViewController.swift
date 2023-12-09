//
//  EditRequestTableViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 09/12/19.
//  Copyright © 2019 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData

typealias RequestVC = EditRequestTableViewController

extension Notification.Name {
    static let requestDidChange = Notification.Name("request-did-change")
    static let validateSSLDidChange = Notification.Name("validate-ssl-did-change")
    static let editRequestVCShouldPresent = Notification.Name("edit-request-vc-should-present")
}

class ValidateSSLCell: UITableViewCell {
    @IBOutlet weak var validateSwitch: UISwitch!
    private let nc = NotificationCenter.default
    var requestId = ""
    
    @IBAction func validateSwitchDidChange(_ sender: Any) {
        Log.debug("validate switch did change: \(self.validateSwitch.isOn)")
        self.nc.post(name: .validateSSLDidChange, object: self, userInfo: ["requestId": self.requestId, "shouldValidateSSL": self.validateSwitch.isOn])
    }
}

class EditRequestTableViewController: APITesterProTableViewController, UITextFieldDelegate, UITextViewDelegate {
    @IBOutlet weak var titleLabel: UILabel!
    // @IBOutlet weak var cancelBtn: UIButton!
    // @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var methodView: UIView!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var urlTextField: JVTextField!
    @IBOutlet weak var nameTextField: JVTextField!
    @IBOutlet weak var descTextView: JVTextView!
    @IBOutlet var headerKVTableViewManager: KVEditTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVEditTableViewManager!
    @IBOutlet var bodyKVTableViewManager: KVEditTableViewManager!
    @IBOutlet weak var headersTableView: UITableView!
    @IBOutlet weak var paramsTableView: UITableView!
    @IBOutlet weak var bodyTableView: UITableView!
    @IBOutlet weak var urlCellView: UIView!
    @IBOutlet weak var nameCellView: UIView!
    @IBOutlet weak var headerCellView: UIView!
    @IBOutlet weak var paramsCellView: UIView!
    @IBOutlet weak var bodyCellView: UIView!
    @IBOutlet weak var urlCell: UITableViewCell!
    @IBOutlet weak var nameCell: UITableViewCell!
    @IBOutlet weak var headerCell: UITableViewCell!
    @IBOutlet weak var paramsCell: UITableViewCell!
    @IBOutlet weak var bodyCell: UITableViewCell!
    @IBOutlet weak var validateSSLCell: ValidateSSLCell!
    weak var docPickerVC: UIDocumentPickerViewController?
    /// Whether the request is running, in which case, we don't remove any listeners
    var isActive = false
    private let nc = NotificationCenter.default
    let app = App.shared
    var isEndEditing = false
    var isOptionFromNotif = false
    private let docPicker = JVDocumentPicker.shared
    private let utils = JVUtils.shared
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    /// The projectId to which the request belongs
    var projectId: String!
    /// The project to which the request belongs. We need to load the project using the background context to assign it to request.
    var project: EProject!
    /// The request Id of the request that is in edit. This needs to be set before pushing this VC.
    var requestId: String!
    /// On view will appear, if request is not populated, we load the request in a background context.
    var request: ERequest!
    /// The background context used for editing
    var ctx: NSManagedObjectContext!
    var requestTracker: EditRequestTracker!
    private lazy var doneBtn: UIButton = {
        let btn = UI.getNavbarTopDoneButton()
        btn.addTarget(self, action: #selector(self.doneDidTap(_:)), for: .touchUpInside)
        return btn
    }()
    /// Indicates if the request is valid for saving (any changes made).
    private var isDirty = false
    var entityDict: [String: Any] = [:]
    /// Used in getting child managed object context.
    private var reqName = ""
    private var methods: [ERequestMethodData] = []
    var isEditMode = false
    /// This will be set when the discard change is tapped from the popup. The popup cancels the navigation back if there are unsaved changes. In this case  we need to manually navigate back by calling pop on nav vc.
    /// Same when user taps done. Once request changes are saved, we navigate back by calling close. For that we need to set this variable.
    var shouldPop = false
    
    enum CellId: Int {
        case navbar = 0
        case spaceAfterTop = 1
        case url = 2
        case spacerAfterUrl = 3
        case name = 4
        case spacerAfterName = 5
        case header = 6
        case spacerAfterHeader = 7
        case params = 8
        case spacerAfterParams = 9
        case body = 10
        case spacerAfterBody = 11
        case validateSSL = 12
        case spacerAfterValidateSSL = 13
    }
    
    deinit {
        Log.debug("request tableview deinit")
        self.destroy()
    }
    
    func destroy() {
        self.headerKVTableViewManager.destroy()
        self.paramsKVTableViewManager.destroy()
        self.bodyKVTableViewManager.destroy()
        self.request = nil
        self.nc.removeObserver(self)
        self.requestTracker = nil
    }
    
    override func didReceiveMemoryWarning() {
        self.app.didReceiveMemoryWarning()
        super.didReceiveMemoryWarning()
    }
    
    func discardContextChanges() {
        if let ctx = self.ctx {
            self.localdb.discardChanges(in: ctx)
            self.isDirty = false
            self.close()
        }
    }
    
    public override func shouldPopOnBackButton() -> Bool {
        self.endEditing()
        if self.isDirty {
            UI.viewActionSheet(
                vc: self, message: "Are you sure you want to discard your changes?", cancelText: "Keep Editing", otherButtonText: "Discard Changes", cancelStyle: UIAlertAction.Style.default, otherStyle: UIAlertAction.Style.destructive,
                // keep editing
                cancelCallback: {
                    Log.debug("cancel callback")
                    self.enableDoneButton()
                },
                // discard changes
                otherCallback: {
                    self.shouldPop = true
                    self.discardContextChanges()
                }
            )
            return false
        } else {
            if let req = self.request, let url = req.url, url.isEmpty {  // New request and user taps back button without any change, so we discard.
                // self.localdb.deleteEntity(data)
                self.discardContextChanges()
            }
        }
        self.destroy()
        return true
    }
    
    // Handle the pop gesture
    override func willMove(toParent parent: UIViewController?) {
        Log.debug("will move")
        if parent == nil { // When the user swipe to back, the parent is nil. When navigating forward, parent is present
            if !self.isDirty { self.destroy() }
            return
        }
        super.willMove(toParent: parent)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.editRequest)
        Log.debug("edit request view will appear")
    }
    
    func bootstrap(projectId: String, requestId: String? = nil) {
        self.projectId = projectId
        self.requestId = requestId
        if self.ctx == nil {
            self.ctx = self.localdb.getChildMOC()
        }
        if self.project == nil {
            self.project = self.localdb.getProject(id: self.projectId, ctx: self.ctx)
        }
        if self.requestId == nil {  // add new request mode
            Log.debug("new request")
            self.requestId = self.localdb.requestId()
            let order = self.localdb.getOrderOfLastRequest(projId: self.project.getId(), ctx: self.ctx).inc()
            self.request = self.localdb.createRequest(id: self.requestId, wsId: self.project.getWsId(), name: self.app.getNewRequestName(), ctx: self.ctx)
            self.request.order = order
        }
        if self.request == nil {  // edit request mode, load the request using background context
            Log.debug("request not present loading..")
            self.request = self.localdb.getRequest(id: self.requestId, ctx: self.ctx)
        }
        self.entityDict = self.localdb.requestToDictionary(self.request)
        Log.debug("initial entity dic: \(self.entityDict)")
        self.requestTracker = EditRequestTracker(ctx: self.ctx, request: self.request)
    }
    
    func loadData() {
        if self.request == nil && self.requestId != nil {  // loading edit for the first time
            Log.debug("request not present loading..")
            if self.ctx == nil {
                self.ctx = self.localdb.getChildMOC()
            }
            self.request = self.localdb.getRequest(id: self.requestId, ctx: self.ctx)
            self.entityDict = self.localdb.requestToDictionary(self.request)  // FIXME: remove
            Log.debug("initial entity dic: \(self.entityDict)")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request table vc view did load")
        self.initUI()
        self.initEvents()
        self.updateData()
        self.reloadAllTableViews()
    }
        
    func initUI() {
        if let nc = self.navigationController as? APITesterProNavigationController {
            nc.navDelegate = self
        }
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        if #available(iOS 13.0, *) { self.isModalInPresentation = true }
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.urlTextField.delegate = self
        self.nameTextField.delegate = self
        self.descTextView.delegate = self
        self.addDoneButton()
        // Color
        self.urlTextField.isColor = false
        self.nameTextField.isColor = false
        // clear storyboard debug helpers
        self.urlCell.borderColor = .clear
        self.nameCell.borderColor = .clear
        self.headerCell.borderColor = .clear
        self.paramsCell.borderColor = .clear
        self.bodyCell.borderColor = .clear
        self.validateSSLCell.borderColor = .clear
        // end clear
        self.reqName = self.request.name ?? ""
        if let data = self.request {
            if data.objectID.isTemporaryID {
                self.titleLabel.text = "Add Request"
                self.isEditMode = false
            } else {
                self.titleLabel.text = "Edit Request"
                self.isEditMode = true
            }
            
        }
        self.renderTheme()
    }
    
    func initEvents() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
        self.urlTextField.addTarget(self, action: #selector(self.updateStateForTextField(_:)), for: .editingChanged)
        self.nameTextField.addTarget(self, action: #selector(self.updateStateForTextField(_:)), for: .editingChanged)
        self.nc.addObserver(self, selector: #selector(self.reloadTableView), name: .requestTableViewReload, object: nil)
        self.nc.addObserver(self, selector: #selector(self.clearEditing), name: .requestViewClearEditing, object: nil)
        let methodTap = UITapGestureRecognizer(target: self, action: #selector(self.methodViewDidTap))
        self.methodView.addGestureRecognizer(methodTap)
        self.nc.addObserver(self, selector: #selector(self.requestMethodDidChange(_:)), name: .requestMethodDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.customRequestMethodDidAdd(_:)), name: .customRequestMethodDidAdd, object: nil)
        self.nc.addObserver(self, selector: #selector(self.customRequestMethodShouldDelete(_:)), name: .customRequestMethodShouldDelete, object: nil)
        self.nc.addObserver(self, selector: #selector(self.requestBodyDidChange(_:)), name: .requestBodyTypeDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentOptionsScreen(_:)), name: .optionScreenShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentMenuPicker(_:)), name: .documentPickerMenuShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentDocumentPicker(_:)), name: .documentPickerShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.presentImagePicker(_:)), name: .imagePickerShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.validateSSLDidChange(_:)), name: .validateSSLDidChange, object: nil)
        // self.cancelBtn.addTarget(self, action: #selector(self.cancelDidTap(_:)), for: .touchUpInside)
        // self.doneBtn.addTarget(self, action: #selector(self.doneDidTap(_:)), for: .touchUpInside)
    }

    func updateData() {
        if let data = self.request, let ctx = data.managedObjectContext {
            self.validateSSLCell.requestId = data.getId()
            self.validateSSLCell.validateSwitch.isOn = data.validateSSL
            self.urlTextField.text = data.url
            self.nameTextField.text = data.name
            self.descTextView.text = data.desc
            if let projId = self.project.id {
                self.methods = self.localdb.getRequestMethodData(projId: projId, ctx: ctx)
                if let meth = data.method {  // in case of edit, there will be method
                    self.methodLabel.text = meth.name
                } else {  // for new request, use GET
                    let getMethod = self.methods.first
                    self.methodLabel.text = getMethod?.name
                    data.method = getMethod  // for new request, set GET as the default method
                }
            }
        }
    }
    
    func initHeadersTableViewManager() {
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func initBodyTableViewManager() {
        self.bodyKVTableViewManager.kvTableView = self.bodyTableView
        self.bodyKVTableViewManager.delegate = self
        self.bodyKVTableViewManager.tableViewType = .body
        self.bodyKVTableViewManager.bootstrap()
        self.bodyKVTableViewManager.reloadData()
    }
    
    func renderTheme() {
        //self.methodView.backgroundColor = App.Color.requestMethodBg
    }
    
    func addDoneButton() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: self.doneBtn)
        self.disableDoneButton()
    }
    
    func enableDoneButton() {
        DispatchQueue.main.async {
            self.doneBtn.setTitleColor(self.doneBtn.tintColor, for: .normal)
            self.doneBtn.isEnabled = true
            self.isDirty = true
        }
    }
    
    func disableDoneButton() {
        DispatchQueue.main.async {
            self.doneBtn.setTitleColor(App.Color.requestEditDoneBtnDisabled, for: .normal)
            self.doneBtn.isEnabled = false
            self.isDirty = false
        }
    }
    
    func updateDoneButton(_ enabled: Bool) {
        DispatchQueue.main.async { enabled ? self.enableDoneButton() : self.disableDoneButton() }
    }
    
    func close() {
        DispatchQueue.main.async {
            self.endEditing()
            self.destroy()
            if self.shouldPop { self.navigationController?.popViewController(animated: true) }
        }
    }
    
    @objc func validateSSLDidChange(_ notif: Notification) {
        Log.debug("validate ssl did change")
        if let info = notif.userInfo, let reqId = info["requestId"] as? String, reqId == self.request.getId(), let shouldValidateSSL = info["shouldValidateSSL"] as? Bool {
            self.request.validateSSL = shouldValidateSSL
            self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
        }
    }
    
    @objc func doneDidTap(_ sender: Any) {
        Log.debug("Done did tap")
        self.endEditing()
        self.requestTracker.diffRescheduler.done()
        if self.isDirty, let data = self.request, let proj = self.project {
            self.request.project = proj
            data.isSynced = false
//            if let set = proj.requestMethods, let xs = set.allObjects as? [ERequestMethodData] {
//                xs.forEach { method in
//                    if method.shouldDelete {
//                        // TODO: ck: mark entities for delete
//                        // self.db.markEntityForDelete(reqMethodData: method, ctx: method.managedObjectContext)
//                    }
//                }
//            }
            // delete entities marked for delete
            self.requestTracker.deletedEntites.forEach { elem in
                self.localdbSvc.deleteEntity(elem as! any Entity)
            }
            self.localdb.saveChildContext(self.ctx)
            self.localdb.saveMainContext()
            self.requestTracker.deletedEntites.removeAll()
            self.isDirty = false
            if let tabvc = self.tabBarController as? RequestTabBarController {
                tabvc.updateRequest(reqId: data.getId())
            }
            // TODO: save to cloud
            // self.db.saveRequestToCloud(data)
            // TODO: delete data marked for delete
            // self.db.deleteDataMarkedForDelete(self.app.editReqDelete)
            self.nc.post(name: .requestDidChange, object: self, userInfo: ["request": data])
            self.shouldPop = true
            self.close()
            
        }
    }
    
    @objc func methodViewDidTap() {
        Log.debug("method view did tap")
        guard let data = self.request else { return }
        let model: [String] = self.methods.compactMap { reqData -> String? in reqData.name }
        var selectedIdx: Int = 0
        if let meth = data.method {
            selectedIdx = self.methods.firstIndex(of: meth) ?? 0
        }
        self.app.presentOptionPicker(type: .requestMethod, title: "Request Method", modelIndex: 0, selectedIndex: selectedIdx, data: model,
                                     modelxs: self.methods, project: self.project, storyboard: self.storyboard!, navVC: self.navigationController!)
    }
    
    @objc func requestMethodDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String,
            let idx = info[Const.optionSelectedIndexKey] as? Int {
            DispatchQueue.main.async {
                self.methodLabel.text = name
                self.request.method = self.methods[idx]
                self.requestTracker.didRequestChange(self.request) { status in
                    self.updateDoneButton(status)
                }
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
            }
        }
    }
    
    @objc func customRequestMethodDidAdd(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let name = info[Const.requestMethodNameKey] as? String,
           let data = self.request, let ctx = data.managedObjectContext {
            if let method = self.localdb.createRequestMethodData(id: self.localdb.requestMethodDataId(), wsId: data.getWsId(), name: name, checkExists: true, ctx: ctx) {
                method.order = self.methods.last!.order!.inc().int()
                data.method = method
                self.methods.append(method)
                method.project = self.project
                self.requestTracker.trackNewRequestMethod(method)
                self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.nc.post(name: .optionPickerShouldReload, object: self,
                             userInfo: [Const.optionModelKey: method, Const.optionDataActionKey: OptionDataAction.add])
            }
        }
    }
    
    @objc func customRequestMethodShouldDelete(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let data = info[Const.optionModelKey] as? ERequestMethodData, let ctx = data.managedObjectContext {
            if let id = data.id {
                var selectedIdx = self.methods.firstIndex(of: self.request.method!) ?? 0
                if self.request.method == data {  // deleting the selected request method => choose GET as the selected
                  selectedIdx = 0
                }
                if let idx = self.methods.firstIndex(of: data) { self.methods.remove(at: idx) }
                self.localdbSvc.markEntityForDelete(reqMeth: data, ctx: ctx)
                self.requestTracker.trackDeletedEntity(data)
                if let method = self.methods.first { self.methodLabel.text = method.name }
                self.request.method = self.methods.first
                self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.nc.post(name: .optionPickerShouldReload, object: self,
                             userInfo: [Const.optionDataActionKey: OptionDataAction.delete, Const.dataKey: id, Const.optionSelectedIndexKey: selectedIdx])
            }
        }
    }
 
    @objc func requestBodyDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let idx = info[Const.optionSelectedIndexKey] as? Int {
            let wsId = self.request.getWsId()
            // If form is selected and there are no fields add one
            if idx == RequestBodyType.form.rawValue, let xs = self.request.body?.form, xs.isEmpty {
                if let req = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: wsId, type: .form, fieldFormat: .text,
                                                            ctx: self.request.managedObjectContext) {
                    self.request.body?.addToForm(req)
                }
            } else if idx == RequestBodyType.multipart.rawValue, let xs = self.request.body?.multipart, xs.isEmpty {
                if let req = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: wsId, type: .multipart, fieldFormat: .text,
                                                            ctx: self.request.managedObjectContext) {
                    self.request.body?.addToMultipart(req)
                }
            } else if idx == RequestBodyType.binary.rawValue {
                if let data = self.request, let body = data.body {
                    if body.binary == nil {
                        if let req = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: wsId, type: .binary, fieldFormat: .file,
                                                                    ctx: self.request.managedObjectContext) {
                            body.binary = req
                        }
                    }
                }
            }
            self.request.body?.selected = idx.toInt64()
            DispatchQueue.main.async {
                // NB: Calling within main thread seem to only work in this case
                self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
                self.tableView.reloadRows(at: [IndexPath(row: RequestCellType.body.rawValue, section: 0)], with: .none)
                self.bodyKVTableViewManager.reloadData()
                if idx == RequestBodyType.binary.rawValue {
                    self.reloadData()
                    self.reloadAllTableViews()
                }
            }
        }
    }
    
    @objc func presentOptionsScreen(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any] {
            let opt = info[Const.optionTypeKey] as? Int ?? 0
            guard let type = OptionPickerType(rawValue: opt) else { return }
            let modelIndex = info[Const.modelIndexKey] as? Int ?? 0
            let selectedIndex = info[Const.optionSelectedIndexKey] as? Int ?? 0
            let data = info[Const.optionDataKey] as? [String] ?? []
            let title = info[Const.optionTitleKey] as? String ?? ""
            let model = info[Const.optionModelKey]
            DispatchQueue.main.async {
                self.app.presentOptionPicker(type: type, title: title, modelIndex: modelIndex, selectedIndex: selectedIndex, data: data, model: model,
                                             storyboard: self.storyboard!, navVC: self.navigationController!)
            }
        }
    }
    
    @objc func presentDocumentMenuPicker(_ notif: Notification) {
        var isMultiSelect = true
        if let info = notif.userInfo, let multiSelect = info["isMultiSelect"] as? Bool { isMultiSelect = multiSelect }
        self.docPicker.presentDocumentMenu(navVC: self.navigationController!, imagePickerDelegate: self, documentPickerDelegate: self, isMultiSelect: isMultiSelect)
    }
    
    @objc func presentDocumentPicker(_ notif: Notification) {
        var isMultiSelect = true
        if let info = notif.userInfo, let multiSelect = info["isMultiSelect"] as? Bool { isMultiSelect = multiSelect }
        self.docPicker.presentDocumentPicker(navVC: self.navigationController!, vc: self, isMultiSelect: isMultiSelect, completion: nil)
    }
    
    @objc func presentImagePicker(_ notif: Notification) {
        self.docPicker.presentPhotoPicker(navVC: self.navigationController!, isCamera: DocumentPickerState.isCameraMode, vc: self, completion: nil)
    }
    
    @objc func endEditing() {
        Log.debug("end editing")
        self.isEndEditing = true
        UI.endEditing()
        self.clearEditing()
        DispatchQueue.main.async {
            self.isEndEditing = false
        }
    }
    
    @objc func clearEditing(_ completion: (() -> Void)? = nil) {
        var status = ["header": false, "params": false, "body": false]
        let cb: () -> Void = {
            if status.values.allSatisfy({ flag -> Bool in return flag }) {
                if completion != nil { completion!() }
            }
        }
        self.headerKVTableViewManager.clearEditing { _ in
            status["header"] = true
            cb()
        }
        self.paramsKVTableViewManager.clearEditing { _ in
            status["params"] = true
            cb()
        }
        self.bodyKVTableViewManager.clearEditing { _ in
            status["body"] = true
            cb()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("request table view did select")
        self.clearEditing()
        if indexPath.row == CellId.header.rawValue {
            if let tv = self.headerKVTableViewManager.kvTableView { self.headerKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        } else if indexPath.row == CellId.params.rawValue {
            if let tv = self.paramsKVTableViewManager.kvTableView {
                self.paramsKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        } else if indexPath.row == CellId.body.rawValue {
            if let tv = self.bodyKVTableViewManager.kvTableView {
                self.bodyKVTableViewManager.tableView(tv, didSelectRowAt: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat!
        if indexPath.row == CellId.navbar.rawValue {
            height = 0
        } else if indexPath.row == CellId.spaceAfterTop.rawValue {
            height = 12
        } else if indexPath.row == CellId.url.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            height = 167
        } else if indexPath.row == CellId.spacerAfterName.rawValue {
            height = 16
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterHeader.rawValue {
            height = 12
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterParams.rawValue {
            height = 12
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if let body = self.request.body, !body.markForDelete, (body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue) {
                return self.bodyFormCellHeight()
            }
            if let body = self.request.body, !body.markForDelete, body.selected == RequestBodyType.binary.rawValue {
                return 60  // Only this one gets called.
            }
            height = self.bodyKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterBody.rawValue {
            height = 12
        } else if indexPath.row == CellId.validateSSL.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterValidateSSL.rawValue {
            height = 12
        } else {
            height = UITableView.automaticDimension
        }
//        Log.debug("height: \(height) for index: \(indexPath)")
        return height
    }
    
    @objc func reloadTableView() {
        Log.debug("request table view reload")
        self.bodyKVTableViewManager.reloadData()
        self.reloadData()
    }
    
    func reloadAllTableViews() {
        self.headerKVTableViewManager.reloadData()
        self.paramsKVTableViewManager.reloadData()
        self.bodyKVTableViewManager.reloadData()
        self.tableView.reloadData()
    }
    
    @objc func updateStateForTextField(_ textField: UITextField) {
        if self.request == nil { return }
        if textField == self.urlTextField {
            self.request.url = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if textField == self.nameTextField {
            self.request.name = textField.text ?? ""
        }
        self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.clearEditing()
        //self.updateStateForTextField(textField)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        self.updateStateForTextField(textField)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        UI.endEditing()
        return false
    }
        
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.clearEditing()
        // TODO
        // self.updateDoneButton(self.app.didRequestDescriptionChange(textView.text ?? "", request: self.entityDict))
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if textView == self.descTextView {
            self.request.desc = textView.text ?? ""
            self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
        }
    }
    
    func addRequestBodyToState() {
        if let data = self.request, let ctx = data.managedObjectContext {
            if data.body == nil {
                data.body = self.localdb.createRequestBodyData(id: self.localdb.requestBodyDataId(), wsId: data.getWsId(), ctx: ctx)
                data.body?.request = self.request
            }
        }
        self.requestTracker.didRequestChange(self.request, callback: { [weak self] status in self?.updateDoneButton(status) })
    }
    
    func bodyFormCellHeight() -> CGFloat {
        if let body = request.body, let ctx = request.managedObjectContext {
            var n = 0
            if body.selected == RequestBodyType.form.rawValue {
                n = self.localdb.getRequestDataCount(reqId: request.getId(), type: .form, ctx: ctx)
            } else if body.selected == RequestBodyType.multipart.rawValue {
                n = self.localdb.getRequestDataCount(reqId: request.getId(), type: .multipart, ctx: ctx)
            } else if body.selected == RequestBodyType.binary.rawValue {
                return 60  // TODO: remove
            }
            let count: Double = n == 0 ? 1 : Double(n)
            return CGFloat(count * 92.5) + 57  // field cell + title cell
        }
        return 92.5 + 57  // 84 + 77
    }
}

extension EditRequestTableViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        Log.debug("image picker controller delegate")
        self.docPicker.imagePickerController(picker, didFinishPickingMediaWithInfo: info)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Log.debug("image picker did cancel")
        self.docPicker.imagePickerControllerDidCancel(picker)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension EditRequestTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.docPicker.documentPicker(controller, didPickDocumentsAt: urls)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.docPicker.documentPickerWasCancelled(controller)
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension EditRequestTableViewController: KVEditTableViewDelegate {
    func reloadData() {
        self.tableView.reloadData()
    }
    
    func getRequest() -> ERequest {
        return self.request
    }
    
    func getRequestTracker() -> EditRequestTracker {
        return self.requestTracker
    }
    
    func getEntityDict() -> [String : Any] {
        return self.entityDict
    }
    
    func getVC() -> EditRequestTableViewController {
        return self
    }
    
    func didRequestChange(_ x: ERequest, callback: @escaping (Bool) -> Void) {
        self.requestTracker.didRequestChange(x, callback: callback)
    }
}

enum KVTableViewType {
    case header
    case params
    case body
}

protocol KVEditTableViewDelegate: AnyObject {
    func reloadData()
    func getRequest() -> ERequest
    func getRequestTracker() -> EditRequestTracker
    func getEntityDict() -> [String: Any]
    func getVC() -> EditRequestTableViewController
    func didRequestChange(_ x: ERequest, callback: @escaping (Bool) -> Void)
}

protocol KVEditContentCellDelegate: AnyObject {
    func enableEditing(indexPath: IndexPath)
    func disableEditing(indexPath: IndexPath)
    func clearEditing(completion: ((Bool) -> Void)?)
    func deleteRow(_ reqDataId: String, type: RequestCellType)
    func dataDidChange(key: String, value: String, reqDataId: String, row: Int)
    func refreshCell(indexPath: IndexPath, cell: KVEditContentCellType)
}

protocol KVEditContentCellType: AnyObject {
    var isEditingActive: Bool { get set }
    var editingIndexPath: IndexPath? { get set }
    func getDeleteView() -> UIView
    func getContainerView() -> UIView
}


class KVEditHeaderCell: UITableViewCell {
    @IBOutlet weak var headerTitleBtn: UIButton!
}

// MARK: - Key-Value content cell

class KVEditContentCell: UITableViewCell, KVEditContentCellType, UITextFieldDelegate {
    @IBOutlet weak var keyTextField: JVTextField!
    @IBOutlet weak var valueTextField: JVTextField!
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var containerView: UIView!
    weak var delegate: KVEditContentCellDelegate?
    weak var editTVDelegate: KVEditTableViewDelegate?
    private let app = App.shared
    var editingIndexPath: IndexPath?
    var isEditingActive = false
    var reqDataId: String = ""
    var type: RequestCellType = .header
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvEditContentCell awake from nib")
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.deleteView.isHidden = true
        self.keyTextField.isColor = false
        self.valueTextField.isColor = false
    }
    
    func initEvents() {
        let deleteBtnTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteBtnDidTap))
        deleteBtnTap.cancelsTouchesInView = false
        self.deleteBtn.addGestureRecognizer(deleteBtnTap)
        let deleteViewTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteViewDidTap))
        self.deleteView.addGestureRecognizer(deleteViewTap)
        self.keyTextField.addTarget(self, action: #selector(self.updateState(_:)), for: .editingChanged)
        self.valueTextField.addTarget(self, action: #selector(self.updateState(_:)), for: .editingChanged)
    }
    
    @objc func deleteBtnDidTap() {
        Log.debug("delete row did tap")
        guard let editTVDelegate = self.editTVDelegate else { return }
        editTVDelegate.getVC().clearEditing({
            let idxPath = IndexPath(row: self.tag, section: 0)
            self.editingIndexPath = idxPath
            self.delegate?.enableEditing(indexPath: idxPath)
            UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
                self.deleteView.isHidden = false
            }, completion: nil)
        })
    }
    
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(reqDataId, type: self.type)
    }
    
    func getDeleteView() -> UIView {
        return self.deleteView
    }
    
    func getContainerView() -> UIView {
        return self.containerView
    }
    
    // MARK: - Delegate
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let editTVDelegate = self.editTVDelegate else { return }
        editTVDelegate.getVC().clearEditing()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        UI.endEditing()
        return false
    }
    
    @objc func updateState(_ textField: UITextField) {
        let key = self.keyTextField.text ?? ""
        let value = self.valueTextField.text ?? ""
        self.delegate?.dataDidChange(key: key, value: value, reqDataId: reqDataId, row: self.tag)
    }
}

// MARK: - Body cell

class KVEditBodyContentCell: UITableViewCell, KVEditContentCellType, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var deleteBtn: UIButton!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var typeNameBtn: UIButton!
    @IBOutlet weak var rawTextViewContainer: UIView!
    @IBOutlet weak var rawTextView: JVTextView!
    @IBOutlet var bodyLabelViewWidth: NSLayoutConstraint!
    @IBOutlet weak var typeLabel: UILabel!
    @IBOutlet weak var bodyFieldTableView: KVEditBodyFieldTableView!
    // binary fields
    @IBOutlet weak var binaryTextFieldView: UIView!
    @IBOutlet weak var binaryTextField: JVTextField!
    @IBOutlet var bodyLabelContainerBottom: NSLayoutConstraint!
    @IBOutlet var typeNameBtnTop: NSLayoutConstraint!
    @IBOutlet weak var imageFileView: UIImageView!  // binary image attachment
    @IBOutlet weak var fileCollectionView: UICollectionView!  // binary file attachment
    weak var delegate: KVEditContentCellDelegate?
    weak var editTVDelegate: KVEditTableViewDelegate? {
        didSet {
            self.bodyFieldTableView.editTVDelegate = self.editTVDelegate
        }
    }
    var optionsData: [String] = ["json", "xml", "raw", "form", "multipart", "binary"]
    var isEditingActive: Bool = false
    var editingIndexPath: IndexPath?
    var bodyDataId = ""
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    private let app = App.shared
    private var rawTextViewPrevHeight: CGFloat = 89
    private var rawTextViewText = ""
    private let monospaceFont = App.Font.monospace13
    private lazy var textViewAttrs: [NSAttributedString.Key: Any]  = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 1.35
        let attributes = [NSAttributedString.Key.paragraphStyle: style, NSAttributedString.Key.font: self.monospaceFont,
                          NSAttributedString.Key.foregroundColor: App.Color.textViewFg]
        return attributes as [NSAttributedString.Key : Any]
    }()
    
    deinit {
        Log.debug("KVBodyContentCell deinits")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        Log.debug("kvEditContentCell awake from nib")
        self.rawTextView.delegate = self
        self.initUI()
        self.initEvents()
        if let editTVDelegate = self.editTVDelegate {
            editTVDelegate.getVC().addRequestBodyToState()
            self.updateState(editTVDelegate.getRequest().body!)
        }
        self.fileCollectionView.delegate = self
        self.fileCollectionView.dataSource = self
    }
    
    func initUI() {
        self.bodyFieldTableView.isHidden = true
        // raw text view
        self.rawTextViewContainer.isHidden = false
        self.rawTextView.placeholderFont = self.monospaceFont
        self.rawTextView.backgroundColor = UIColor(named: "table-view-cell-bg")
        self.updateTextViewText(self.rawTextView, text: self.rawTextView.text)
        // binary text field
        self.binaryTextField.borderStyle = .none
        self.binaryTextField.isColor = false
        self.binaryTextField.placeholder = "select file"
        self.imageFileView.isHidden = true
    }
            
    func initEvents() {
        let deleteBtnTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteBtnDidTap))
        deleteBtnTap.cancelsTouchesInView = false
        self.deleteBtn.addGestureRecognizer(deleteBtnTap)
        let deleteViewTap = UITapGestureRecognizer(target: self, action: #selector(self.deleteViewDidTap))
        self.deleteView.addGestureRecognizer(deleteViewTap)
        let typeLabelTap = UITapGestureRecognizer(target: self, action: #selector(self.typeBtnDidTap(_:)))
        self.typeLabel.addGestureRecognizer(typeLabelTap)
        let binTap = UITapGestureRecognizer(target: self, action: #selector(self.binaryFieldViewDidTap(_:)))
        self.binaryTextFieldView.addGestureRecognizer(binTap)
    }
    
    @objc func binaryFieldViewDidTap(_ recog: UITapGestureRecognizer) {
        Log.debug("binary field view did tap")
        self.presentDocPicker()
    }
    
    // The left delete cirle button
    @objc func deleteBtnDidTap() {
        Log.debug("delete row did tap")
        guard let editTVDelegate = self.editTVDelegate else { return }
        editTVDelegate.getVC().clearEditing({
            self.delegate?.enableEditing(indexPath: IndexPath(row: self.tag, section: 0))
            UIView.transition(with: self, duration: 0.5, options: .curveEaseIn, animations: {
                self.deleteView.isHidden = false
            }, completion: nil)
        })
    }
    
    // The right delete cell view
    @objc func deleteViewDidTap() {
        Log.debug("delete view did tap")
        self.delegate?.deleteRow(self.bodyDataId, type: .body)
        self.bodyFieldTableView.reloadData()
    }
    
    func presentDocPicker() {
        DocumentPickerState.modelIndex = 0
        self.nc.post(name: .documentPickerMenuShouldPresent, object: self, userInfo: ["isMultiSelect": false])
    }
    
    @IBAction func typeBtnDidTap(_ sender: Any) {
        Log.debug("type name did tap")
        var selected: Int! = 0
        guard let editTVDelegate = self.editTVDelegate else { return }
        let request = editTVDelegate.getRequest()
        guard let ctx = request.managedObjectContext, let body = request.body else { return }
        selected = Int(body.selected)
        self.nc.post(name: .optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyForm.rawValue,
                                Const.modelIndexKey: self.tag,
                                Const.optionSelectedIndexKey: selected as Any,
                                Const.optionDataKey: RequestBodyType.allCases as [Any],
                                Const.optionModelKey: self.localdb.getRequestBodyData(id: self.bodyDataId, ctx: ctx) as Any])
    }
    
    func getDeleteView() -> UIView {
        return self.deleteView
    }
    
    func getContainerView() -> UIView {
        return self.containerView
    }
    
    func updateTextViewText(_ textView: UITextView, text: String) {
        textView.attributedText = NSAttributedString(string: text, attributes: self.textViewAttrs)
    }
    
    func displayFormFields() {
        self.bodyFieldTableView.isHidden = false
        self.rawTextViewContainer.isHidden = true
        self.binaryTextFieldView.isHidden = true
        if let editTVDelegate = self.editTVDelegate {
            editTVDelegate.getVC().addRequestBodyToState()
            let request = editTVDelegate.getRequest()
            if let body = request.body, let type = RequestBodyType(rawValue: body.selected.toInt()) {
                self.bodyFieldTableView.selectedType = type
            }
        }
        self.fileCollectionView.isHidden = true
        self.imageFileView.isHidden = true
        self.resetConstraints()
        self.bodyFieldTableView.reloadData()
    }
    
    func hideFormFields() {  // Called for displaying raw textview
        self.bodyFieldTableView.isHidden = true
        self.binaryTextFieldView.isHidden = true
        self.rawTextViewContainer.isHidden = false
        self.rawTextView.isHidden = false
        self.fileCollectionView.isHidden = true
        self.imageFileView.isHidden = true
        self.resetConstraints()
    }
    
    /// Resets constraints to their default values
    func resetConstraints() {
        self.bodyLabelContainerBottom.isActive = true
        self.typeNameBtnTop.priority = UILayoutPriority.defaultHigh
        self.typeNameBtnTop.isActive = false
    }
    
    /// Update constraints for binary field
    func updateConstraintsForBinaryField() {
        // For binary field, we don't need to expand the label to the center of the cell. So we deactivate the bottom constraint and set the top constraint
        // to get the label to align to cell height. This is because the default constraints are set with top, bottom and this will make the delete label to
        // align to the cell center as it grows, in case of raw, form fields. This senario is encountered if we enter values in say json field, switch the type
        // to binary.
        self.typeNameBtnTop.priority = UILayoutPriority.required
        self.typeNameBtnTop.isActive = true
        self.bodyLabelContainerBottom.isActive = false
    }
    
    func displayBinaryField() {
        self.bodyFieldTableView.isHidden = true
        self.rawTextViewContainer.isHidden = true
        self.rawTextViewContainer.isHidden = true
        self.rawTextView.isHidden = true
        self.rawTextViewText = self.rawTextView.text
        self.rawTextView.text = ""
        self.binaryTextFieldView.isHidden = false
        self.fileCollectionView.isHidden = true
        self.imageFileView.isHidden = true
        self.updateConstraintsForBinaryField()
        self.fileCollectionView.reloadData()
    }
    
    func updateState(_ data: ERequestBodyData) {
        if data.markForDelete { return }
        let idx: Int = Int(data.selected)
        if let editTVDelegate = self.editTVDelegate {
            editTVDelegate.getRequest().body!.selected = Int64(idx)
        }
        self.typeLabel.text = "(\(self.optionsData[idx]))"
        self.bodyLabelViewWidth.isActive = false
        switch idx {
        case 0:  // json
            self.rawTextView.text = data.json
            self.rawTextView.placeholder = "{}"
            self.bodyLabelViewWidth.constant = 60
        case 1:  // xml
            self.rawTextView.text = data.xml
            self.rawTextView.placeholder = "<element/>"
            self.bodyLabelViewWidth.constant = 60
        case 2:  // raw
            self.rawTextView.text = data.raw
            self.rawTextView.placeholder = "{}"
            self.bodyLabelViewWidth.constant = 60
        case 3:  // form
            self.displayFormFields()
            self.bodyLabelViewWidth.constant = 63
        case 4:  // multipart
            self.displayFormFields()
            self.bodyLabelViewWidth.constant = 78
        case 5:  // binary
            self.bodyLabelViewWidth.constant = 63
            Log.debug("bin: update state")
            if let binary = data.binary {
                if let image = binary.image, let imageData = image.data {
                    Log.debug("bin: image")
                    self.imageFileView.image = UIImage(data: imageData)
                    self.imageFileView.isHidden = false
                    self.binaryTextField.isHidden = true
                    break
                } else {
                    Log.debug("bin: files")
                    self.fileCollectionView.isHidden = false
                    self.fileCollectionView.reloadData()
                    self.binaryTextField.isHidden = true
                }
            }
        default:
            break
        }
        self.bodyLabelViewWidth.isActive = true
        if let editTVDelegate = self.editTVDelegate {
            let request = editTVDelegate.getRequest()
            editTVDelegate.didRequestChange(request, callback: { status in editTVDelegate.getVC().updateDoneButton(status) })
        }
    }
    
    // MARK: - Delegate collection view
    
    func getFile() -> EFile? {
        guard let editTVDelegate = self.editTVDelegate else { return nil }
        return editTVDelegate.getRequest().body?.binary?.files?.allObjects.first as? EFile
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.getFile() == nil ? 0 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("binary file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        var name = ""
        if let file = self.getFile() { Log.debug("file: \(file)"); name = file.name ?? "" }
        cell.nameLabel.text = name
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.nameLabel.textWidth()
        } else {
            let name = self.getFile()?.name ?? ""
            let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
            lbl.text = name
            lbl.layoutIfNeeded()
            width = lbl.textWidth()
        }
        Log.debug("width: \(width)")
        return CGSize(width: width, height: 23.5)
    }
}

// MARK: - Raw textview delegate

extension KVEditBodyContentCell: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.editTVDelegate?.getVC().clearEditing()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let txt = textView.text ?? ""
        Log.debug("text changed: \(txt)")
        guard let editTVDelegate = self.editTVDelegate, let request = self.editTVDelegate?.getRequest(), let body = request.body else { return }
        let selected = body.selected
        switch selected {
        case 0:
            body.json = txt
        case 1:
            body.xml = txt
        case 2:
            body.raw = txt
        default:
            break
        }
        self.updateTextViewText(textView, text: txt)
        request.body = body
        editTVDelegate.didRequestChange(request, callback: { status in editTVDelegate.getVC().updateDoneButton(status) })
        self.delegate?.refreshCell(indexPath: IndexPath(row: self.tag, section: 0), cell: self)
    }
}

// MARK: - Body field table view

class FileCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

protocol KVEditBodyFieldTableViewCellDelegate: AnyObject {
    func updateState(_ data: ERequestData, row: Int)
}

class KVEditBodyFieldTableViewCell: UITableViewCell, UITextFieldDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var keyTextField: JVTextField!
    @IBOutlet weak var valueTextField: JVTextField!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var fieldTypeView: UIView!
    @IBOutlet weak var fieldTypeBtn: UIButton!
    @IBOutlet weak var imageFileView: UIImageView!
    @IBOutlet weak var fileCollectionView: UICollectionView!
    @IBOutlet weak var borderView: UIView!
    @IBOutlet var keyTextFieldHeight: NSLayoutConstraint!
    weak var delegate: KVEditBodyFieldTableViewCellDelegate?
    weak var editTVDelegate: KVEditTableViewDelegate?
    var isValueTextFieldActive = false
    var selectedType: RequestBodyType = .form
    var isKeyTextFieldActive = false
    private let nc = NotificationCenter.default
    var selectedFieldFormat: RequestBodyFormFieldFormatType = .text
    private let app = App.shared
    private let localdb = CoreDataService.shared
    private let utils = JVUtils.shared
    var reqDataId = ""  // Will be empty if there are no fields added

    override func awakeFromNib() {
        super.awakeFromNib()
        self.bootstrap()
        self.renderTheme()
        self.initEvents()
        self.fileCollectionView.reloadData()
        self.updateUI()
    }
    
    func bootstrap() {
        self.keyTextField.delegate = self
        self.valueTextField.delegate = self
        self.keyTextField.isColor = false
        self.valueTextField.isColor = false
        self.imageFileView.isHidden = true
        self.fileCollectionView.delegate = self
        self.fileCollectionView.dataSource = self
    }
    
    func renderTheme() {
        //self.fieldTypeView.backgroundColor = App.Color.requestMethodBg
    }
    
    func initEvents() {
        let btnTap = UITapGestureRecognizer(target: self, action: #selector(self.fieldTypeViewDidTap(_:)))
        btnTap.cancelsTouchesInView = false
        self.fieldTypeView.addGestureRecognizer(btnTap)
        let cvTap = UITapGestureRecognizer(target: self, action: #selector(self.presentDocPicker))
        cvTap.cancelsTouchesInView = false
        self.imageFileView.addGestureRecognizer(cvTap)
        self.keyTextField.addTarget(self, action: #selector(self.updateState(_:)), for: .editingChanged)
        self.valueTextField.addTarget(self, action: #selector(self.updateState(_:)), for: .editingChanged)
        self.initCollectionViewEvents()
    }
    
    func initCollectionViewEvents() {
        let cvTap = UITapGestureRecognizer(target: self, action: #selector(self.presentDocPicker))
        cvTap.cancelsTouchesInView = false
        self.fileCollectionView.removeGestureRecognizer(cvTap)
        self.fileCollectionView.addGestureRecognizer(cvTap)
    }
    
    func updateUI() {
        if self.selectedType == .form {
            self.keyTextField.placeholder = "form name"
            self.valueTextField.placeholder = "form value"
            self.fileCollectionView.isHidden = false
            self.fieldTypeView.isHidden = false
            self.fileCollectionView.reloadData()
        } else if self.selectedType == .multipart {
            self.keyTextField.placeholder = "part name"
            self.valueTextField.placeholder = "part value"
            self.fileCollectionView.isHidden = true
            self.fieldTypeView.isHidden = true
            self.selectedFieldFormat = .text
        }
    }
    
    @objc func fieldTypeViewDidTap(_ recog: UITapGestureRecognizer) {
        Log.debug("field type view did tap")
        guard let editTVDelegate = self.editTVDelegate else { return }
        editTVDelegate.getVC().endEditing()
        let data = editTVDelegate.getRequest()
        guard let ctx = data.managedObjectContext else { return }
        editTVDelegate.getVC().addRequestBodyToState()
        let reqData = self.localdb.getRequestData(id: self.reqDataId, ctx: ctx)
        self.nc.post(name: .optionScreenShouldPresent, object: self,
                     userInfo: [Const.optionTypeKey: OptionPickerType.requestBodyFormField.rawValue,
                                Const.modelIndexKey: self.tag,
                                Const.optionSelectedIndexKey: self.selectedFieldFormat.rawValue,
                                Const.optionDataKey: RequestBodyFormFieldFormatType.allCases,
                                Const.optionModelKey: reqData as Any])
    }
    
    @objc func presentDocPicker() {
        guard let editTVDelegate = self.editTVDelegate else { return }
        let data = editTVDelegate.getRequest()
        guard let ctx = data.managedObjectContext else { return }
        DocumentPickerState.modelIndex = self.tag
        let reqId = data.getId()
        if let elem = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: .form, ctx: ctx) {
            DocumentPickerState.reqDataId = elem.getId()
            if let image = elem.image {
                DocumentPickerState.isCameraMode = image.isCameraMode
                self.nc.post(Notification(name: .imagePickerShouldPresent))
                return
            }
            if let files = elem.files, files.count > 0 {
                self.nc.post(Notification(name: .documentPickerShouldPresent))
                return
            }
        }
        self.nc.post(Notification(name: .documentPickerMenuShouldPresent))
    }
    
    @objc func updateState(_ textField: UITextField) {
        guard let editTVDelegate = self.editTVDelegate else { return }
        let data = editTVDelegate.getRequest()
        guard let ctx = data.managedObjectContext else { return }
        if let req = self.localdb.getRequestData(id: self.reqDataId, ctx: ctx) {
            if textField == self.keyTextField {
                req.key = textField.text
            } else if textField == self.valueTextField {
                req.value = textField.text
            }
            self.delegate?.updateState(req, row: self.tag)
        }
    }
    
    // MARK: - Delegate text field
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        Log.debug("text field did begin editing")
        self.editTVDelegate?.getVC().clearEditing()
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if self.selectedFieldFormat == .file && textField == self.valueTextField {
            self.presentDocPicker()
            return false
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        Log.debug("textfield did end editing")
        self.updateState(textField)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        UI.endEditing()
        return false
    }
    
    // MARK: - Delegate collection view
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.selectedFieldFormat == .file {
            if let data = self.editTVDelegate?.getRequest(), let ctx = data.managedObjectContext {
                return self.localdb.getFilesCount(self.reqDataId, type: selectedType == .form ? .form : .multipart, ctx: ctx)
            }
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        Log.debug("file collection view cell")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "fileCell", for: indexPath) as! FileCollectionViewCell
        var name = ""
        if let data = self.editTVDelegate?.getRequest(), let reqId = data.id, let ctx = data.managedObjectContext,
            let form = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: self.selectedType == .form ? .form : .multipart, ctx: ctx),
            let formId = form.id, let file = self.localdb.getFile(at: indexPath.row, reqDataId: formId, ctx: ctx) {
            name = file.name ?? ""
        }
        cell.nameLabel.text = name
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = 50
        if let cell = collectionView.cellForItem(at: indexPath) as? FileCollectionViewCell {
            width = cell.nameLabel.textWidth()
        } else {
            var name = ""
            if let data = self.editTVDelegate?.getRequest(), let reqId = data.id, let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(at: self.tag, reqId: reqId, type: self.selectedType == .form ? .form : .multipart, ctx: ctx),
                let formId = form.id, let file = self.localdb.getFile(at: indexPath.row, reqDataId: formId, ctx: ctx) {
                name = file.name ?? ""
                let lbl = UILabel(frame: CGRect(x: 0, y: 0, width: .greatestFiniteMagnitude, height: 19.5))
                lbl.text = name
                lbl.layoutIfNeeded()
                width = lbl.textWidth()
            }
        }
        Log.debug("width: \(width)")
        return CGSize(width: width, height: 23.5)
    }
}

class KVEditBodyFieldTableView: UITableView, UITableViewDelegate, UITableViewDataSource, KVEditBodyFieldTableViewCellDelegate {
    private let cellId = "editBodyTableViewCell"
    var isCellRegistered = false
    private let nc = NotificationCenter.default
    var selectedType: RequestBodyType = .json
    private let app = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    private let utils = JVUtils.shared
    weak var editTVDelegate: KVEditTableViewDelegate?
    
    deinit {
        Log.debug("KVBodyFieldTableView deinit")
        self.nc.removeObserver(self)
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        Log.debug("kvbodyfieldtableview init")
        self.bootstrap()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        Log.debug("kvbodyfieldtableview init coder")
        self.bootstrap()
        self.initEvents()
    }
    
    func bootstrap() {
        self.delegate = self
        self.dataSource = self
        self.estimatedRowHeight = 44
        self.rowHeight = UITableView.automaticDimension
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.requestBodyFieldDidChange(_:)), name: .requestBodyFormFieldTypeDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.imageAttachmentDidReceive(_:)), name: .documentPickerImageIsAvailable, object: nil)
        self.nc.addObserver(self, selector: #selector(self.documentAttachmentDidReceive(_:)), name: .documentPickerFileIsAvailable, object: nil)
    }
    
    @objc func requestBodyFieldDidChange(_ notif: Notification) {
        if let info = notif.userInfo as? [String: Any], let idx = info[Const.optionSelectedIndexKey] as? Int,
            let reqData = info[Const.optionModelKey] as? ERequestData {
            if let request = self.editTVDelegate?.getRequest() {
                self.editTVDelegate?.didRequestChange(request, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
            }
            DispatchQueue.main.async {
                reqData.fieldFormat = idx.toInt64()
                self.reloadData()
            }
        }
    }
        
    @objc func imageAttachmentDidReceive(_ notif: Notification) {
        Log.debug("KVBodyFieldTableView imageAttachmentDidReceive notification")
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if let data = self.editTVDelegate?.getRequest(), let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(id: DocumentPickerState.reqDataId, ctx: ctx) {
                form.type = RequestDataType.form.rawValue.toInt64()
                if let image = DocumentPickerState.image {
                    if let imageData = DocumentPickerState.imageType == ImageType.png.rawValue ? image.pngData() : image.jpegData(compressionQuality: 1.0) {
                        let eimage = self.localdb.createImage(data: imageData, wsId: data.getWsId(), name: DocumentPickerState.imageName, type: DocumentPickerState.imageType, ctx: ctx)
                        eimage?.requestData = form
                        eimage?.isCameraMode = DocumentPickerState.isCameraMode
                        if let files = form.files?.allObjects as? [EFile] {  // remove files if selected previously
                            files.forEach { file in
                                self.localdbSvc.markEntityForDelete(file: file, ctx: ctx)
                                self.editTVDelegate?.getRequestTracker().trackDeletedEntity(file)
                            }
                        }
                        self.editTVDelegate?.didRequestChange(data, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
                    }
                }
                self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                DocumentPickerState.clear()
            }
        }
    }
    
    @objc func documentAttachmentDidReceive(_ notif: Notification) {
        Log.debug("KVBodyFieldTableView documentAttachmentDidReceive notification")
        if self.selectedType == .form {
            let row = DocumentPickerState.modelIndex
            if let data = self.editTVDelegate?.getRequest(), let ctx = data.managedObjectContext,
                let form = self.localdb.getRequestData(id: DocumentPickerState.reqDataId, ctx: ctx) {
                let wsId = data.getWsId()
                form.type = RequestDataType.form.rawValue.toInt64()
                form.fieldFormat = RequestBodyFormFieldFormatType.file.rawValue.toInt64()
                form.files = NSSet()  // clear the set, but it does not delete the data
                DocumentPickerState.docs.forEach { element in
                    self.app.getDataForURL(element) { result in
                        switch result {
                        case .success(let x):
                            Log.debug("body form field creating file attachment")
                            let name = self.app.getFileName(element)
                            if let file = self.localdb.createFile(data: x, wsId: wsId, name: name, path: element,
                                                                  type: self.selectedType == .form ? .form : .multipart, checkExists: true, ctx: ctx) {
                                ctx.performAndWait {
                                    file.requestData = form
                                    if let image = form.image {  // remove image if present as file is picked
                                        // TODO: ck mark image for delete
                                        // self.db.markForDelete(image: form.image, ctx: form.image?.managedObjectContext)
                                        self.localdbSvc.markEntityForDelete(image: image, ctx: ctx)
                                        self.editTVDelegate?.getRequestTracker().trackDeletedEntity(image)
                                    }
                                }
                                DispatchQueue.main.async {
                                    self.editTVDelegate?.didRequestChange(data, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
                                    self.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                                    DocumentPickerState.clear()
                                }
                            }
                        case .failure(let error):
                            Log.debug("Error: \(error)")
                            if let vc = self.editTVDelegate?.getVC() { self.app.viewError(error, vc: vc) }
                        }
                    }
                }
            }
        }
    }
    
    func addFields() {
        if let request = self.editTVDelegate?.getRequest(), let body = request.body, let ctx = request.managedObjectContext {
            if body.selected == RequestBodyType.form.rawValue {
                if let data = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: request.getWsId(), type: .form, fieldFormat: .text, ctx: ctx) {
                    body.addToForm(data)
                    self.editTVDelegate?.didRequestChange(request, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
                }
            } else if body.selected == RequestBodyType.multipart.rawValue {
                if let data = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: request.getWsId(), type: .multipart, fieldFormat: .text, ctx: ctx) {
                    body.addToMultipart(data)
                    self.editTVDelegate?.didRequestChange(request, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
                }
            }
        }
        self.reloadData()
        self.editTVDelegate?.getVC().bodyKVTableViewManager.reloadData()
        self.editTVDelegate?.getVC().reloadData()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if self.selectedType == .form || self.selectedType == .multipart {
            return 2
        }
        return 1
    }
        
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let data = self.editTVDelegate?.getRequest(), let reqId = data.id, let ctx = data.managedObjectContext else { return 0 }
        if section == 1 {  // title
            return 1
        }
        var num = 0
        if self.selectedType == .form {
            num = self.localdb.getRequestDataCount(reqId: reqId, type: .form, ctx: ctx)
        } else if self.selectedType == .multipart {
            num = self.localdb.getRequestDataCount(reqId: reqId, type: .multipart, ctx: ctx)
        } else if self.selectedType == .binary {
            num = 1
        }
        return num
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {  // title
            let cell = tableView.dequeueReusableCell(withIdentifier: "editBodyFieldTitleCell", for: indexPath) as! KVEditHeaderCell
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellId, for: indexPath) as! KVEditBodyFieldTableViewCell
        if cell.editTVDelegate == nil { cell.editTVDelegate = self.editTVDelegate }
        let row = indexPath.row
        cell.tag = row
        cell.delegate = self
        cell.keyTextField.text = ""
        cell.valueTextField.text = ""
        cell.imageFileView.image = nil
        self.hideImageAttachment(cell: cell)
        self.hideFileAttachment(cell: cell)

        var elem: ERequestData?
        var reqBodyData: ERequestBodyData?
        cell.selectedType = self.selectedType
        if let data = self.editTVDelegate?.getRequest(), let ctx = data.managedObjectContext, let reqId = data.id {
            if self.selectedType == .form {
                elem = self.localdb.getRequestData(at: row, reqId: reqId, type: .form, ctx: ctx)
                reqBodyData = elem?.form
            } else if self.selectedType == .multipart {
                elem = self.localdb.getRequestData(at: row, reqId: reqId, type: .multipart, ctx: ctx)
                reqBodyData = elem?.multipart
            } else if self.selectedType == .binary {
                elem = self.localdb.getRequestData(at: row, reqId: reqId, type: .multipart, ctx: ctx)
                reqBodyData = elem?.binary
            }
        }
        if let x = elem, let body = reqBodyData {
            cell.reqDataId = x.id ?? ""
            cell.keyTextField.text = x.key
            cell.valueTextField.text = x.value
            cell.selectedType = RequestBodyType(rawValue: body.selected.toInt()) ?? RequestBodyType.json
            cell.selectedFieldFormat = RequestBodyFormFieldFormatType(rawValue: x.fieldFormat.toInt()) ?? RequestBodyFormFieldFormatType.text
            cell.updateUI()
            if cell.selectedFieldFormat == .text {
                cell.fieldTypeBtn.setImage(UIImage(named: "text"), for: .normal)
                self.hideImageAttachment(cell: cell)
                self.hideFileAttachment(cell: cell)
            } else if cell.selectedFieldFormat == .file {
                cell.fieldTypeBtn.setImage(UIImage(named: "file"), for: .normal)
                if let image = x.image, let imgData = image.data {
                    cell.imageFileView.image = UIImage(data: imgData)
                    self.displayImageAttachment(cell: cell)
                } else {
                    self.hideImageAttachment(cell: cell)
                    if let xs = x.files, xs.count > 0 {
                        cell.initCollectionViewEvents()
                        cell.fileCollectionView.layoutIfNeeded()
                        cell.fileCollectionView.reloadData()
                        self.displayFileAttachment(cell: cell)
                    } else {
                        self.hideFileAttachment(cell: cell)
                    }
                }
            }
        } else {
            cell.updateUI()
        }
        self.updateCellPlaceholder(cell)
        return cell
    }
    
    func updateCellPlaceholder(_ cell: KVEditBodyFieldTableViewCell) {
        if cell.selectedFieldFormat == .file {
            cell.valueTextField.placeholder = "select files"
            cell.valueTextField.text = ""
        } else {
            cell.valueTextField.placeholder = {
                if cell.selectedType == .form { return "form value" }
                if cell.selectedType == .multipart { return  "part value"}
                return "select file"
            }()
        }
    }
    
    func displayImageAttachment(cell: KVEditBodyFieldTableViewCell) {
        cell.imageFileView.isHidden = false
        cell.fileCollectionView.isHidden = true
        cell.valueTextField.isHidden = true
        self.updateCellPlaceholder(cell)
    }
    
    func hideImageAttachment(cell: KVEditBodyFieldTableViewCell) {
        cell.imageFileView.image = nil
        cell.imageFileView.isHidden = true
        cell.valueTextField.isHidden = false
        self.updateCellPlaceholder(cell)
    }
    
    func displayFileAttachment(cell: KVEditBodyFieldTableViewCell) {
        cell.fileCollectionView.isHidden = false
        cell.imageFileView.isHidden = true
        cell.valueTextField.isHidden = true
        self.updateCellPlaceholder(cell)
    }
    
    func hideFileAttachment(cell: KVEditBodyFieldTableViewCell) {
        cell.fileCollectionView.isHidden = true
        cell.valueTextField.isHidden = false
        self.updateCellPlaceholder(cell)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 { return 44 }
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (self.selectedType == .form || self.selectedType == .multipart) && indexPath.section == 1 {  // title
            self.addFields()
        }
    }
    
    // Swipe to delete
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            guard let data = self.editTVDelegate?.getRequest(), let ctx = data.managedObjectContext else { completion(false); return }
            var shouldReload = false
            if let cell = tableView.cellForRow(at: indexPath) as? KVEditBodyFieldTableViewCell  {
                if !cell.reqDataId.isEmpty {
                    if let elem = self.localdb.getRequestData(id: cell.reqDataId, ctx: ctx) {
//                        if let xs = elem?.files?.allObjects as? [EFile] {
//                            xs.forEach { file in self.app.addEditRequestDeleteObject(file) }
//                        }
                        // TODO: ck: mark request data for delete
                        // self.db.markEntityForDelete(reqData: elem, ctx: ctx)
                        self.localdbSvc.markEntityForDelete(reqData: elem, ctx: ctx)
                        self.editTVDelegate?.getRequestTracker().trackDeletedEntity(elem)
                    }
                    shouldReload = true
                }
            }
            if shouldReload {
                self.reloadAllTableViews()
            }
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            if let body = self.editTVDelegate?.getRequest().body {
                if self.selectedType == .form {
                    if let form = body.form, form.count <= 1 {
                        return false
                    }
                } else if self.selectedType == .multipart {
                    if let multipart = body.multipart, multipart.count <= 1 {
                        return false
                    }
                }
            }
            return true
        }
        return false
    }
    
    func reloadAllTableViews() {
        self.reloadData()
        self.editTVDelegate?.getVC().reloadData()
        self.editTVDelegate?.getVC().bodyKVTableViewManager.reloadData()
    }
    
    // MARK: - Delegate
    
    func updateState(_ data: ERequestData, row: Int) {
        guard let request = self.editTVDelegate?.getRequest() else { return }
        self.editTVDelegate?.getVC().addRequestBodyToState()
        request.body!.selected = self.selectedType.rawValue.toInt64()
        if self.selectedType == .form {
            if request.body!.form == nil { request.body!.form = NSSet() }
            request.body!.addToForm(data)
            self.editTVDelegate?.didRequestChange(request, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
        } else if self.selectedType == .multipart {
            if request.body!.multipart == nil { request.body!.multipart = NSSet() }
            request.body!.addToMultipart(data)
            self.editTVDelegate?.didRequestChange(request, callback: { status in self.editTVDelegate?.getVC().updateDoneButton(status) })
        }
    }
}

// MARK: - Table view manager

class KVEditTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    weak var delegate: KVEditTableViewDelegate?
    var height: CGFloat = 44
    var editingIndexPath: IndexPath?
    var tableViewType: KVTableViewType = .header
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    private let utils = JVUtils.shared
    private let app = App.shared
    private let nc = NotificationCenter.default
    
    deinit {
        Log.debug("kvTableViewManager deinit")
    }
    
    override init() {
        super.init()
        Log.debug("kvTableViewManger init")
    }
    
    func destroy() {
        self.delegate = nil
        self.nc.removeObserver(self)
    }
    
    func bootstrap() {
        self.kvTableView?.estimatedRowHeight = 44
        self.kvTableView?.rowHeight = UITableView.automaticDimension
        self.kvTableView?.allowsMultipleSelectionDuringEditing = false
        self.nc.addObserver(self, selector: #selector(self.imageAttachmentDidReceive(_:)), name: .documentPickerImageIsAvailable, object: nil)
        self.nc.addObserver(self, selector: #selector(self.documentAttachmentDidReceive(_:)), name: .documentPickerFileIsAvailable, object: nil)
    }
    
    func addRequestDataToModel() {
        guard let delegate = self.delegate, let ctx = self.delegate?.getRequest().managedObjectContext else { return }
        let data = delegate.getRequest()
        var x: ERequestData?
        switch self.tableViewType {
        case .header:
            if data.headers == nil { data.headers = NSSet() }
            x = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: data.getWsId(), type: .header, fieldFormat: .text, ctx: ctx)
            if let y = x {
                data.addToHeaders(y)
                self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
            }
        case .params:
            if data.params == nil { data.params = NSSet() }
            x = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: data.getWsId(), type: .param, fieldFormat: .text, ctx: ctx)
            if let y = x {
                data.addToParams(y)
                self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
            }
        case .body:
            if data.body == nil || data.body!.markForDelete { delegate.getVC().addRequestBodyToState() }
            if data.body == nil { return }
            if data.body!.selected == RequestBodyType.form.rawValue {
                if data.body!.form == nil { data.body!.form = NSSet() }
                x = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: data.getWsId(), type: .form, fieldFormat: .text, ctx: ctx)
                if let y = x {
                    data.body!.addToForm(y)
                    self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                }
            } else if data.body!.selected == RequestBodyType.multipart.rawValue {
                if data.body!.multipart == nil { data.body!.multipart = NSSet() }
                x = self.localdb.createRequestData(id: self.localdb.requestDataId(), wsId: data.getWsId(), type: .multipart, fieldFormat: .text, ctx: ctx)
                if let y = x {
                    data.body!.addToMultipart(y)
                    self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                }
            }
        }
    }
    
    func removeRequestDataFromModel(_ id: String, type: RequestCellType) {
        guard let delegate = self.delegate, let ctx = self.delegate?.getRequest().managedObjectContext else { return }
        let data = delegate.getRequest()
        if type == .body {
            guard let body = self.localdb.getRequestBodyData(id: id, ctx: ctx) else { return }
            // TODO: ck: mark body for delete
            // self.db.markEntityForDelete(body: body, ctx: ctx)
            // delete body
            self.localdbSvc.markEntityForDelete(reqBodyData: body, ctx: ctx)
            self.delegate?.getRequestTracker().trackDeletedEntity(body)
        } else if type == .header {
            guard let elem = self.localdb.getRequestData(id: id, ctx: ctx) else { return }
            // TODO: ck: mark request data for delete
            // delete header
            self.localdbSvc.markEntityForDelete(reqData: elem, ctx: ctx)
            self.delegate?.getRequestTracker().trackDeletedEntity(elem)
        } else if type == .param {
            guard let elem = self.localdb.getRequestData(id: id, ctx: ctx) else { return }
            // TODO: ck: mark request data for delete
            // delete param
            self.localdbSvc.markEntityForDelete(reqData: elem, ctx: ctx)
            self.delegate?.getRequestTracker().trackDeletedEntity(elem)
        }
        self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
    }
    
    @objc func imageAttachmentDidReceive(_ notif: Notification) {
        Log.debug("image attachment did receive")
        if AppState.binaryAttachmentInfo.isSame() { return }
        AppState.binaryAttachmentInfo.copyFromState()
        guard let image = DocumentPickerState.image, let imageData = DocumentPickerState.imageType == ImageType.png.rawValue ? image.pngData() : image.jpegData(compressionQuality: 1.0) else { return }
        guard let data = self.delegate?.getRequest(), let body = data.body, let ctx = data.managedObjectContext else { return }
        if body.selected == RequestBodyType.binary.rawValue {
            Log.debug("binary field - image attachment")
            if let binary = body.binary {
                if binary.image?.data != imageData {
                    let eimage = self.localdb.createImage(data: imageData, wsId: data.getWsId(), name: DocumentPickerState.imageName, type: DocumentPickerState.imageType, ctx: ctx)
                    eimage?.requestData = binary
                    eimage?.isCameraMode = DocumentPickerState.isCameraMode
                    if let xs = binary.files?.allObjects as? [EFile] {  // binary contains image data, so we remove any files it has
                        xs.forEach { file in
                            // TODO: ck: mark file for delete
                            // self.db.markEntityForDelete(file: file, ctx: ctx)
                            self.localdbSvc.markEntityForDelete(file: file, ctx: ctx)
                            self.delegate?.getRequestTracker().trackDeletedEntity(file)
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.delegate?.getVC().bodyKVTableViewManager.reloadData()
                    self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                }
            }
            DocumentPickerState.clear()
        }
        
    }
    
    @objc func documentAttachmentDidReceive(_ notif: Notification) {
        Log.debug("doc attachment did receive")
        if AppState.binaryAttachmentInfo.isSame() { return }  // We are getting multiple notifications. So this prevents processing the same file again.
        AppState.binaryAttachmentInfo.copyFromState()
        guard let data = self.delegate?.getRequest(), let body = data.body, let ctx = data.managedObjectContext else { return }
        if body.selected == RequestBodyType.binary.rawValue {
            Log.debug("binary field - doc attachment")
            if let binary = body.binary {
                if DocumentPickerState.docs.isEmpty { return }
                let fileURL = DocumentPickerState.docs[0]
                self.app.getDataForURL(fileURL) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let fileData):
                            Log.debug("bin: file read")
                            if let xs = binary.files?.allObjects as? [EFile] {  // updated files picked, remove existing ones
                                xs.forEach { file in
                                    // TODO: ck: mark file for delete
                                    // self.db.markEntityForDelete(file: file, ctx: ctx)
                                    self.localdbSvc.markEntityForDelete(file: file, ctx: ctx)
                                    self.delegate?.getRequestTracker().trackDeletedEntity(file)
                                }
                            }
                            let name = self.app.getFileName(fileURL)
                            if let file = self.localdb.createFile(data: fileData, wsId: data.getWsId(), name: name, path: fileURL,
                                                                  type: .binary, checkExists: true, ctx: ctx) {
                                file.requestData = binary
                                if let img = binary.image {  // remove image if present as file is picked
                                    // TODO: ck: mark image for delete
                                    // self.db.markForDelete(image: img, ctx: ctx)
                                    self.localdbSvc.markEntityForDelete(image: img, ctx: ctx)
                                    self.delegate?.getRequestTracker().trackDeletedEntity(img)
                                }
                                Log.debug("bin: entity deleted")
                                DispatchQueue.main.async {
                                    self.delegate?.getVC().bodyKVTableViewManager.reloadData()
                                    Log.debug("bin: tv reloaded")
                                    self.delegate?.didRequestChange(data, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                                }
                                DocumentPickerState.clear()
                            }
                        case .failure(let error):
                            Log.debug("Error: \(error)")
                            if let vc = self.delegate?.getVC() {
                                UI.viewToast(self.app.getErrorMessage(for: error), vc: vc)
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    /// Returns the raw textview cell height
    func getRowTextViewCellHeight() -> CGFloat {
        if let cell = self.kvTableView?.cellForRow(at: IndexPath(row: 0, section: 0)) as? KVEditBodyContentCell {
            height = cell.frame.size.height + 8
        }
        Log.debug("raw text cell height: \(height)")
        return height
    }
    
    func getHeight() -> CGFloat {
        var height: CGFloat = 44
        var count = 0
        guard let request = self.delegate?.getRequest(), let vc = self.delegate?.getVC(), let ctx = request.managedObjectContext else { return height }
        switch self.tableViewType {
        case .header:
            count = self.localdb.getRequestDataCount(reqId: request.getId(), type: .header, ctx: ctx)
            if count == 0 {
                height = 48
            } else {
                height = CGFloat(Double(count) * 92.5 + 50)
            }
        case .params:
            count = self.localdb.getRequestDataCount(reqId: request.getId(), type: .param, ctx: ctx)
            if count == 0 {
                height = 48
            } else {
                height = CGFloat(Double(count) * 92.5 + 50)
            }
        case .body:
            if let body = request.body, !body.markForDelete {
                if body.selected == RequestBodyType.json.rawValue ||
                   body.selected == RequestBodyType.xml.rawValue ||
                   body.selected == RequestBodyType.raw.rawValue {
                    height = self.getRowTextViewCellHeight()
                } else if body.selected == RequestBodyType.form.rawValue {
                    height = vc.bodyFormCellHeight()
                    Log.debug("form cell height: \(height)")
                } else if body.selected == RequestBodyType.multipart.rawValue {
                    height = vc.bodyFormCellHeight()
                    Log.debug("multipart cell height: \(height)")
                } else if body.selected == RequestBodyType.binary.rawValue {
                    height = 60  // TODO: remove
                }
            } else {
                height = 44
            }
        }
        Log.debug("kvtableview getHeight: \(height) for type: \(self.tableViewType)")
        return height
    }
    
    func getContentCellId() -> String {
        switch self.tableViewType {
        case .header:
            fallthrough
        case .params:
            return "kvEditContentCell"
        case .body:
            return "editBodyContentCell"
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let request = self.delegate?.getRequest(), let ctx = request.managedObjectContext else { return 0 }
        if section == 0 {
            switch self.tableViewType {
            case .header:
                return self.localdb.getRequestDataCount(reqId: request.getId(), type: .header, ctx: ctx)
            case .params:
                return self.localdb.getRequestDataCount(reqId: request.getId(), type: .param, ctx: ctx)
            case .body:
                if request.body == nil { return 0 }
                if request.body!.markForDelete { Log.debug("body num row: \(0)"); return 0 }
                Log.debug("body num row: \(1)")
                return 1
            }
        }
        // section 1 (header)
        if self.tableViewType == .body && request.body != nil {
            if request.body!.markForDelete { return 1 }
            Log.debug("body title num row: \(0)");
            return 0
        }
        Log.debug("body title num row: \(1)");
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if self.tableViewType == .body {
                Log.debug("cell for row: bodyContentCell")
                let cell = tableView.dequeueReusableCell(withIdentifier: "editBodyContentCell", for: indexPath) as! KVEditBodyContentCell
                if cell.editTVDelegate == nil { cell.editTVDelegate = self.delegate }
                let row = indexPath.row
                cell.tag = row
                cell.delegate = self
                self.hideDeleteRowView(cell: cell)
                let selectedIdx: Int = {
                    if let data = self.delegate?.getRequest(), let body = data.body { return Int(body.selected) }
                    return 0
                }()
                switch selectedIdx {
                case RequestBodyType.json.rawValue:
                    cell.updateTextViewText(cell.rawTextView, text: self.delegate?.getRequest().body?.json ?? "")
                    cell.hideFormFields()
                case RequestBodyType.xml.rawValue:
                    cell.updateTextViewText(cell.rawTextView, text: self.delegate?.getRequest().body?.xml ?? "")
                    cell.hideFormFields()
                case RequestBodyType.raw.rawValue:
                    cell.updateTextViewText(cell.rawTextView, text: self.delegate?.getRequest().body?.raw ?? "")
                    cell.hideFormFields()
                case RequestBodyType.form.rawValue:
                    cell.displayFormFields()
                case RequestBodyType.multipart.rawValue:
                    cell.displayFormFields()
                case RequestBodyType.binary.rawValue:
                    cell.displayBinaryField()
                default:
                    break
                }
                if let request = self.delegate?.getRequest(), let body = request.body {
                    if body.markForDelete { cell.isHidden = true }
                    cell.bodyDataId = body.getId()
                    cell.updateState(body)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "kvEditContentCell", for: indexPath) as! KVEditContentCell
                if cell.editTVDelegate == nil { cell.editTVDelegate = self.delegate }
                let row = indexPath.row
                cell.tag = row
                cell.delegate = self
                self.hideDeleteRowView(cell: cell)
                cell.keyTextField.text = ""
                cell.valueTextField.text = ""
                cell.reqDataId = ""
                switch self.tableViewType {
                case .header:
                    if let data = self.delegate?.getRequest(), let reqId = data.id, let ctx = data.managedObjectContext {
                        let xs = self.localdb.getHeadersRequestData(reqId, ctx: ctx)
                        if xs.count > row {
                            let x = xs[row]
                            cell.keyTextField.text = x.key
                            cell.valueTextField.text = x.value
                            cell.reqDataId = x.id ?? ""
                            cell.type = .header
                        }
                    }
                case .params:
                    if let data = self.delegate?.getRequest(), let reqId = data.id, let ctx = data.managedObjectContext {
                        let xs = self.localdb.getParamsRequestData(reqId, ctx: ctx)
                        if xs.count > row {
                            let x = xs[row]
                            cell.keyTextField.text = x.key
                            cell.valueTextField.text = x.value
                            cell.reqDataId = x.id ?? ""
                            cell.type = .param
                        }
                    }
                default:
                    break
                }
                return cell
            }
        }
        Log.debug("cell for row: kvEditTitleCell")
        var title: String = ""
        var titleCellId: String = ""
        if self.tableViewType == .header {
            title = "  add header"
            titleCellId = "kvEditHeaderTitleCell"
        } else if self.tableViewType == .params {
            title = "  add params"
            titleCellId = "kvEditParamsTitleCell"
        } else if self.tableViewType == .body {
            title = "  add body"
            titleCellId = "editBodyTitleCell"
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: titleCellId, for: indexPath) as! KVEditHeaderCell
        cell.headerTitleBtn.setTitle(title, for: .normal)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("kvTableView row did select")
        self.delegate?.getVC().clearEditing()
        if let vc = self.delegate?.getVC() {
            vc.clearEditing()
            if vc.isEndEditing {
                UI.endEditing()
                return
            }
        }
        if indexPath.section == 1 {  // header
            self.addRequestDataToModel()
            self.disableEditing(indexPath: indexPath)
            self.reloadData()
            self.delegate?.reloadData()
        }
        if let data = self.delegate?.getRequest(), let body = data.body, body.selected == RequestBodyType.binary.rawValue {
            Log.debug("binary option - reloading data")
            self.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.tableViewType == .body {
            if let data = self.delegate?.getRequest(), let body = data.body, let vc = self.delegate?.getVC() {
                if indexPath.section == 1 { return 0 }  // title is hidden when body content is present
                if body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue {
                    return vc.bodyFormCellHeight()
                }
            }
        }
        if indexPath.section == 1 { return 44 }  // Prevents the collapse warning
        return UITableView.automaticDimension
    }
    
    func previewActions(forCellAt indexPath: IndexPath) {
        guard let tv = self.kvTableView else { return }
        tv.reloadData()
        guard let cell: KVEditContentCellType = tv.cellForRow(at: indexPath) as? KVEditContentCellType else { return }
        cell.getDeleteView().transform = CGAffineTransform.identity
        if let _ = cell as? KVEditBodyContentCell {
            if let data = self.delegate?.getRequest(), let body = data.body, let type = RequestBodyType(rawValue: body.selected.toInt()), type == .binary {
                cell.getDeleteView().transform = CGAffineTransform.identity.translatedBy(x: 0, y: -21)  // Update the delete view size to align to cell center for binary
            }
        }
        UIView.animate(withDuration: 0.3, animations: {
            cell.getContainerView().transform = CGAffineTransform.identity.translatedBy(x: -64, y: 0)
        }, completion: nil)
    }
    
    func hideDeleteRowView(cell: KVEditContentCellType) {
        cell.getContainerView().transform = CGAffineTransform.identity
        cell.getDeleteView().isHidden = true
    }
    
    func hideActions(forCellAt indexPath: IndexPath, completion: ((Bool) -> Void)? = nil) {
        Log.debug("hide actions")
        var cell: KVEditContentCellType!
        if let aCell = self.kvTableView?.cellForRow(at: indexPath) as? KVEditContentCell {
            cell = aCell
        } else if let aCell = self.kvTableView?.cellForRow(at: indexPath) as? KVEditBodyContentCell {
            cell = aCell
        }
        if cell == nil {
            if let cb = completion { cb(false) }
            return
        }
        cell.isEditingActive = false
        cell.editingIndexPath = nil
        UIView.animate(withDuration: 0.3, animations: {
            self.hideDeleteRowView(cell: cell)
            self.editingIndexPath = nil
        }, completion: completion)
    }
}

extension KVEditTableViewManager: KVEditContentCellDelegate {
    func enableEditing(indexPath: IndexPath) {
        if self.editingIndexPath != nil {
            self.hideActions(forCellAt: self.editingIndexPath!) { _ in
                self.editingIndexPath = indexPath
                self.previewActions(forCellAt: indexPath)
            }
        } else {
            self.editingIndexPath = indexPath
            self.previewActions(forCellAt: indexPath)
        }
    }
    
    func disableEditing(indexPath: IndexPath) {
        self.hideActions(forCellAt: indexPath)
    }
    
    func clearEditing(completion: ((Bool) -> Void)? = nil) {
        if let indexPath = self.editingIndexPath {
            self.hideActions(forCellAt: indexPath, completion: completion)
        } else {
            if let cb = completion { cb(true) }
        }
    }
    
    func deleteRow(_ reqDataId: String, type: RequestCellType) {
        self.removeRequestDataFromModel(reqDataId, type: type)
        self.reloadData()
        self.delegate?.reloadData()
    }
    
    func dataDidChange(key: String, value: String, reqDataId: String, row: Int) {
        if let req = self.delegate?.getRequest(), let ctx = req.managedObjectContext {
            if self.tableViewType == .header {
                if let x = self.localdb.getRequestData(id: reqDataId, ctx: ctx) {
                    x.key = key
                    x.value = value
                    Log.debug("header updated: \(x)")
                    self.delegate?.didRequestChange(req, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                }
            } else if self.tableViewType == .params {
                if let x = self.localdb.getRequestData(id: reqDataId, ctx: ctx) {
                    x.key = key
                    x.value = value
                    self.delegate?.didRequestChange(req, callback: { status in self.delegate?.getVC().updateDoneButton(status) })
                }
            }
        }
    }
    
    /// Refreshes the cell and scroll to the end of the growing text view cell.
    func refreshCell(indexPath: IndexPath, cell: KVEditContentCellType) {
        Log.debug("refresh cell")
        UIView.setAnimationsEnabled(false)
        self.kvTableView?.beginUpdates()
        if let aCell = cell as? KVEditBodyContentCell {
            aCell.rawTextView.scrollRangeToVisible(NSMakeRange(aCell.rawTextView.text.count - 1, 0))
        }
        self.kvTableView?.endUpdates()
        UIView.setAnimationsEnabled(true)
        self.kvTableView?.scrollToRow(at: indexPath, at: .bottom, animated: false)
        let bodySpacerIdx = IndexPath(row: RequestVC.CellId.spacerAfterBody.rawValue, section: 0)
        UIView.setAnimationsEnabled(false)
        if let vc = self.delegate?.getVC() {
            vc.tableView.beginUpdates()
            vc.tableView.endUpdates()
            UIView.setAnimationsEnabled(true)
            vc.tableView.scrollToRow(at: bodySpacerIdx, at: .bottom, animated: false)
        }
    }
}

