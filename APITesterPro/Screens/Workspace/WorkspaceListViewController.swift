//
//  WorkspaceListViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 02/12/19.
//  Copyright © 2019 Jaseem V V. All rights reserved.
//

import UIKit
import CoreData

extension Notification.Name {
    static let workspaceVCShouldPresent = Notification.Name("workspace-vc-should-present")
    static let workspaceDidChange = Notification.Name("workspace-did-change")
    static let workspaceWillClose = Notification.Name("workspace-will-close")
}

class WorkspaceListViewController: APITesterProViewController {
    static weak var shared: WorkspaceListViewController?
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    @IBOutlet weak var navBarView: UIView!
    @IBOutlet weak var navBarTitleLabel: UILabel!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils = EAUtils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private lazy var db = { CoreDataService.shared }()
    private lazy var dbSvc = { PersistenceService.shared }()
    private lazy var ck = { EACloudKit.shared }()
    private var ckFrc: NSFetchedResultsController<EWorkspace>!
    private var localFrc: NSFetchedResultsController<EWorkspace>!
    private var wsSelected: EWorkspace!
    
    deinit {
        self.nc.post(name: .workspaceWillClose, object: self)
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WorkspaceListViewController.shared = self
        AppState.setCurrentScreen(.workspaceList)
        self.navigationItem.title = "Workspaces"
        self.reloadData()
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initData()
        self.initUI()
        self.initEvents()
    }

    func initUI() {
        self.tableView.register(EmptyMessageCell.self, forCellReuseIdentifier: TableCellId.emptyMessageCell.rawValue)
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.navBarView.backgroundColor = App.Color.navBarBg
        self.navBarTitleLabel.backgroundColor = App.Color.navBarBg
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.databaseWillUpdate(_:)), name: .databaseWillUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.databaseDidUpdate(_:)), name: .databaseDidUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidSync(_:)), name: .workspaceDidSync, object: nil)
    }
    
    func initData() {
        // local workspace
        if self.localFrc == nil {
            if let _frc = self.db.getFetchResultsController(obj: EWorkspace.self, predicate: NSPredicate(format: "name != %@", ""), ctx: self.db.localMainMOC) as? NSFetchedResultsController<EWorkspace> {
                self.localFrc = _frc
                self.localFrc.delegate = self
            }
        }
        // iCloud workspace
        if self.ckFrc == nil {
            if let _frc = self.db.getFetchResultsController(obj: EWorkspace.self, predicate: NSPredicate(format: "name != %@", ""), ctx: self.db.ckMainMOC) as? NSFetchedResultsController<EWorkspace> {
                self.ckFrc = _frc
                self.ckFrc.delegate = self
            }
        }
        self.reloadData()
    }
    
    func updateData() {
        // ck frc
        if self.ckFrc == nil { return }
        self.ckFrc.delegate = nil
        try? self.ckFrc.performFetch()
        self.ckFrc.delegate = self
        // local frc
        if self.localFrc == nil { return }
        self.localFrc.delegate = nil
        try? self.localFrc.performFetch()
        self.localFrc.delegate = self
        self.tableView.reloadData()
    }
    
    func postWorkspaceWillCloseEvent() {
        self.nc.post(name: .workspaceWillClose, object: self)
    }
    
    func close() {
        self.postWorkspaceWillCloseEvent()
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func workspaceDidSync(_ notif: Notification) {
        DispatchQueue.main.async { self.reloadData() }
    }
    
    @objc func databaseWillUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            self.ckFrc.delegate = nil
            self.localFrc.delegate = nil
        }
    }
    
    @objc func databaseDidUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            self.ckFrc.delegate = self
            self.localFrc.delegate = self
            self.reloadData()
        }
    }
    
    func reloadData() {
        self.wsSelected = self.app.getSelectedWorkspace()
        do {
            var shouldReload = false
            if self.ckFrc != nil {
                shouldReload = true
                try self.ckFrc.performFetch()
            }
            if self.localFrc != nil {
                shouldReload = true
                try self.localFrc.performFetch()
            }
            if shouldReload {
                self.tableView.reloadData()
            }
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    @IBAction func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        //self.viewAlert(vc: self, storyboard: self.storyboard!)
        self.viewPopup()
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings button did tap")
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Workspace", iCloudSyncFieldEnabled: true, shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            AppState.setCurrentScreen(.workspaceList)
            self.addWorkspace(name: model.name, desc: model.desc, isSyncEnabled: model.iCloudSyncFieldEnabled)
        }, validateHandler: { model in
            return !model.name.isEmpty
        }))
    }
    
    func didPopupModelChange(_ model: PopupModel, ws: EWorkspace) -> Bool {
        var didChange = true
        ws.managedObjectContext?.performAndWait {
            if model.name.isEmpty {
                didChange = false
            } else {
                didChange = false
                if ws.name != model.name {
                    didChange = true
                }
                if ws.desc != model.desc {
                    didChange = true
                }
            }
        }
        return didChange
    }
    
    func viewEditPopup(_ ws: EWorkspace) {
        self.app.viewPopupScreen(self, model: PopupModel(title: "Edit Workspace", name: ws.getName(), desc: ws.desc ?? "", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            var didChange = false
            if ws.name != model.name {
                ws.name = model.name
                didChange = true
            }
            if ws.desc != model.desc {
                ws.desc = model.desc
                didChange = true
            }
            if didChange {
                self.db.saveMainContext()
                self.updateData()
            }
        }, validateHandler: { model in
            return self.didPopupModelChange(model, ws: ws)
        }))
    }
    
    func displayAddButton() {
        self.addBtn.isEnabled = true
    }
    
    func hideAddButton() {
        self.addBtn.isEnabled = false
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Workspace", style: .default, handler: { action in
            Log.debug("new workspace did tap")
            self.viewPopup()
        }))
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        vc.present(alert, animated: true, completion: nil)
    }
    
    func addWorkspace(name: String, desc: String, isSyncEnabled: Bool) {
        self.dbSvc.createWorkspace(name: name, desc: desc, isSyncEnabled: isSyncEnabled)
        self.reloadData()
        if isSyncEnabled {
            self.checkIfiCloudEnabled()
        }
    }
    
    func checkIfiCloudEnabled() {
        Task {
            let iCloudAvailable = try? await self.ck.isiCloudAvailable() 
            if !(iCloudAvailable ?? false) {
                DispatchQueue.main.async {
                    UI.viewToast("iCloud account not available. Sync will continue once account is available.", hideSec: 3.5, vc: self)
                }
            }
        }
    }
}

class WorkspaceCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var bottomBorder: UIView!
    
    func hideBottomBorder() {
        self.bottomBorder.isHidden = true
    }
    
    func displayBottomBorder() {
        self.bottomBorder.isHidden = false
    }
}

extension WorkspaceListViewController: UITableViewDelegate, UITableViewDataSource {
    // One for iCloud and another for local workspaces listing
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? max(1, self.ckFrc.numberOfRows(in: 0)) : max(1, self.localFrc.numberOfRows(in: 0))
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "iCloud Workspaces" : "Local Workspaces"
    }
    
    func getWorkspace(indexPath: IndexPath) -> EWorkspace {
        if indexPath.section == 0 {
            return self.ckFrc.object(at: indexPath)
        }
        let idxPath = IndexPath(row: indexPath.row, section: 0)
        return self.localFrc.object(at: idxPath)
    }
    
    func getWorkspaceCount(indexPath: IndexPath) -> Int {
        if indexPath.section == 0 {
            return self.ckFrc.numberOfRows(in: 0)
        }
        return self.localFrc.numberOfRows(in: 0)
    }
    
    func sectionType(indexPath: IndexPath) -> String {
        return indexPath.section == 0 ? "iCloud" : "Local"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let wsCount = self.getWorkspaceCount(indexPath: indexPath)
        if wsCount > 0 {
            let cell = self.tableView.dequeueReusableCell(withIdentifier: TableCellId.workspaceCell.rawValue, for: indexPath) as! WorkspaceCell
            let ws = self.getWorkspace(indexPath: indexPath)
            cell.accessoryType = .none
            if ws.id == self.wsSelected.id && ws.isSyncEnabled == self.wsSelected.isSyncEnabled { cell.accessoryType = .checkmark }
            let name = ws.name ?? ""
            let desc = self.getDesc(ws: ws)
            cell.nameLbl.text = name
            cell.descLbl.text = desc
            if !desc.isEmpty {
                cell.descLbl.isHidden = false
            } else {
                cell.descLbl.isHidden = true
            }
            // cell.displayBottomBorder()
            return cell
        }
        let emptyMsgCell = self.tableView.dequeueReusableCell(withIdentifier: TableCellId.emptyMessageCell.rawValue, for: indexPath) as! EmptyMessageCell
        emptyMsgCell.updateMessage(self.sectionType(indexPath: indexPath) == "iCloud" ? "No iCloud workspaces found" : "No Local workspaces found")
        emptyMsgCell.isUserInteractionEnabled = false
        return emptyMsgCell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("workspace cell did select \(indexPath.row)")
        if self.getWorkspaceCount(indexPath: indexPath) > 0 {
            let ws = self.getWorkspace(indexPath: indexPath)
            self.app.setSelectedWorkspace(ws)
            self.nc.post(name: .workspaceDidChange, object: self, userInfo: ["workspace": ws])
            self.close()
        }
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if self.getWorkspaceCount(indexPath: indexPath) > 0 {
            let ws = self.getWorkspace(indexPath: indexPath)
            let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
                Log.debug("edit row: \(indexPath)")
                self.viewEditPopup(ws)
                completion(true)
            }
            edit.backgroundColor = App.Color.lightPurple
            let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
                Log.debug("delete row: \(indexPath)")
                if ws == self.wsSelected {  // Reset selection to the default workspace
                    let wss = self.db.getAllWorkspaces(offset: 0, limit: 1, isMarkForDelete: false, ctx: self.db.ckMainMOC)
                    self.wsSelected = !wss.isEmpty ? wss.first! : self.db.getDefaultWorkspace()
                    self.app.setSelectedWorkspace(self.wsSelected)
                }
                self.dbSvc.deleteEntity(ws: ws)
                self.updateData()
                completion(true)
            }
            let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete, edit])
            swipeActionConfig.performsFirstActionWithFullSwipe = false
            return swipeActionConfig
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.getWorkspaceCount(indexPath: indexPath) > 0 {
            let ws = self.getWorkspace(indexPath: indexPath)
            let name = ws.name ?? ""
            let desc = self.getDesc(ws: ws)
            
            var widthOffset: CGFloat = 45 + 16 // The label view starts with 45 padding on leading and 16 trailing
            if self.wsSelected.getId() == ws.getId() {
                widthOffset += 40  // account for accessary view tick mark
            }
            let w = tableView.frame.width - widthOffset  // padding of 32
            let h1 = UILabel.textHeight(text: name, font: App.Font.font17, width: w)
            let h2 = UILabel.textHeight(text: desc, font: App.Font.font15, width: w)
            Log.debug("row: \(indexPath.row) -> \(h1 + h2)")
            return max(h1 + h2 + 32, 46)
        }
        return UITableView.automaticDimension
    }
    
    func getDesc(ws: EWorkspace) -> String {
        return ws.desc ?? ""
    }
}

extension WorkspaceListViewController: NSFetchedResultsControllerDelegate {    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("workspace list frc did change object: \(anObject)")
        if AppState.currentScreen != .workspaceList { return }
        DispatchQueue.main.async {
            self.tableView.reloadData()
            switch type {
            case .insert:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
            default:
                break
            }
        }
    }
}
