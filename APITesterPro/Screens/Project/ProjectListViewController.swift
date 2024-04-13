//
//  ProjectListViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 09/12/19.
//  Copyright © 2019 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension Notification.Name {
    static let navigatedBackToProjectList = Notification.Name("did-navigate-back-to-project-list-vc")
}

class ProjectListViewController: APITesterProViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var workspaceBtn: UIButton!
    @IBOutlet weak var helpTextLabel: UILabel!
    private var workspace: EWorkspace! {
        didSet {
            self.container = self.localdb.getContainer(self.workspace.managedObjectContext!)
            self.reloadData()
        }
    }
    private var container: CoreDataContainer = .local
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: EAUtils = EAUtils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    private var localFrc: NSFetchedResultsController<EProject>!
    private var ckFrc: NSFetchedResultsController<EProject>!
    private let cellReuseId = "projectCell"
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.projectList)
        self.navigationItem.title = "Projects"
        self.navigationItem.leftBarButtonItem = self.addSettingsBarButton()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
        self.workspace = self.app.getSelectedWorkspace()
        self.updateWorkspaceTypeIcon()
        self.updateWorkspaceTitle(self.workspace.name ?? "")
        if !isRunningTests {
            self.reloadData()
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("project view did load")
        if !isRunningTests {
            self.app.bootstrap()
            self.initData()
            self.initUI()
            self.initEvent()
        }
    }
    
    func initUI() {
        Log.debug("init UI")
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.app.updateNavigationControllerBackground(self.navigationController)
        // workspace type button configuration
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.buttonSize = .small
            config.imagePadding = 4
            config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .medium)
            self.workspaceBtn.configuration = config
            self.workspaceBtn.imageView?.contentMode = .scaleAspectFit
        } else {
            self.workspaceBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        }
        self.updateWorkspaceTypeIcon()
    }
    
    func initEvent() {
        self.nc.addObserver(self, selector: #selector(self.databaseWillUpdate(_:)), name: .databaseWillUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.databaseDidUpdate(_:)), name: .databaseDidUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidSync(_:)), name: .workspaceDidSync, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidChange(_:)), name: .workspaceDidChange, object: nil)
        self.nc.addObserver(self, selector: #selector(self.orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    func getFRCPredicate(_ wsId: String) -> NSPredicate {
        return NSPredicate(format: "workspace.id == %@ AND name != %@ AND markForDelete == %hdd", wsId, "", false)
    }
    
    func initData() {
        self.workspace = self.app.getSelectedWorkspace()
        guard let wsId = self.workspace.id else { return }
        let predicate = self.getFRCPredicate(wsId)
        self.ckFrc = self.localdb.getFetchResultsController(obj: EProject.self, predicate: predicate, ctx: self.localdb.ckMainMOC) as? NSFetchedResultsController<EProject>
        self.localFrc = self.localdb.getFetchResultsController(obj: EProject.self, predicate: predicate, ctx: self.localdb.localMainMOC) as? NSFetchedResultsController<EProject>
        self.ckFrc.delegate = self
        self.localFrc.delegate = self
        self.reloadData()
    }
    
    func updateData() {
        if self.container == .cloud {
            if self.ckFrc == nil { return }
            self.ckFrc.delegate = nil
            try? self.ckFrc.performFetch()
            self.ckFrc.delegate = self
        } else {
            if self.localFrc == nil { return }
            self.localFrc.delegate = nil
            try? self.localFrc.performFetch()
            self.localFrc.delegate = self
        }
        self.checkHelpShouldDisplay()
        self.tableView.reloadData()
    }
    
    @objc func databaseWillUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            if self.container == .cloud {
                self.ckFrc.delegate = nil
            } else {
                self.localFrc.delegate = nil
            }
        }
    }
    
    @objc func databaseDidUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            if self.container == .cloud {
                self.ckFrc.delegate = self
            } else {
                self.localFrc.delegate = self
            }
            self.reloadData()
        }
    }
    
    func checkHelpShouldDisplay() {
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        let count = frc!.numberOfRows(in: 0)
        if count == 0 {
            self.displayHelpText()
        } else {
            self.hideHelpText()
        }
    }
    
    func reloadData() {
        let frc = container == .cloud ? self.ckFrc : self.localFrc
        if frc == nil { return }
        do {
            try frc!.performFetch()
            self.checkHelpShouldDisplay()
            self.updateWorkspaceTypeIcon()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    func displayHelpText() {
        if !self.helpTextLabel.isHidden { return }
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = false
        }
    }
    
    func hideHelpText() {
        if self.helpTextLabel.isHidden { return }
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = true
        }
    }
    
    func updateWorkspaceTitle(_ name: String) {
        DispatchQueue.main.async {
            self.workspaceBtn.titleLabel?.font = App.Font.font15
            self.workspaceBtn.titleLabel?.numberOfLines = 1
            self.workspaceBtn.titleLabel?.lineBreakMode = .byTruncatingTail
            self.workspaceBtn.titleLabel?.adjustsFontSizeToFitWidth = true
            self.workspaceBtn.titleLabel?.baselineAdjustment = UIBaselineAdjustment.none
            self.workspaceBtn.setTitle(name, for: .normal)
            // The above doesn't do label truncation. So we need to truncate manually based on width.
            let width = self.view.frame.width / 2 - (self.workspaceBtn.imageView!.frame.width + 32)
            var txt = UI.truncatedTextToFitWidth(for: name, width: width, height: 44, font: App.Font.font15)
            if txt.count < name.count {
                txt = "\(txt.takeFrom(start: 0, end: txt.count - 3))..."
            }
            self.workspaceBtn.setTitle(txt, for: .normal)
        }
    }
    
    func updateWorkspaceTypeIcon() {
        let imageName: String = {
            if self.workspace.isSyncEnabled {
                return "icloud"
            }
            let orientation = UI.getInterfaceOrientation()
            if (orientation == .landscapeLeft || orientation == .landscapeRight) {
                if (UI.getDeviceType() == .phone) {
                    return "iphone.landscape"
                }
                return "ipad.landscape"
            }
            if (UI.getDeviceType() == .phone) {
                return "iphone"
            }
            return "ipad"
        }()
        self.workspaceBtn.setImage(UIImage(systemName: imageName), for: .normal)
        
    }
    
    func updateListingWorkspace(_ ws: EWorkspace) {
        if self.workspace == ws { return }
        self.workspace = ws
        guard let wsId = ws.id, let ctx = self.workspace.managedObjectContext else { return }
        let predicate = self.getFRCPredicate(wsId)
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        if let _frc = self.localdb.updateFetchResultsController(frc as! NSFetchedResultsController<NSFetchRequestResult>, predicate: predicate, ctx: ctx) as? NSFetchedResultsController<EProject> {
            if self.container == .cloud {
                self.ckFrc = _frc
                self.ckFrc.delegate = self
            } else {
                self.localFrc = _frc
                self.localFrc.delegate = self
            }
        }
        self.reloadData()
        
    }
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(named: "settings"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
    }
    
    @objc func workspaceDidSync(_ notif: Notification) {
        DispatchQueue.main.async {
            self.workspace = self.app.getSelectedWorkspace()
            self.updateWorkspaceTitle(self.workspace.name ?? "")
            self.updateWorkspaceTypeIcon()
        }
    }
    
    @objc func settingsButtonDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
        UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.settingsVC.rawValue)
    }
    
    func addProject(name: String, desc: String) {
        if let ctx = self.workspace.managedObjectContext {
            let wsId = self.workspace.getId()
            let order = self.localdb.getOrderOfLastProject(wsId: wsId, ctx: ctx).inc()
            if let proj = self.localdb.createProject(id: self.localdb.projectId(), wsId: wsId, name: name, desc: desc, ws: self.workspace, ctx: ctx) {
                proj.order = order
                proj.workspace = self.workspace
                self.localdb.saveMainContext()
            }
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        let editor = WebCodeEditorViewController()
        // self.viewPopup() // TODO: test
        self.navigationController!.pushViewController(editor, animated: true)
    }
    
    @IBAction func workspaceDidTap(_ sender: Any) {
        Log.debug("workspace did tap")
        if let vc = UIStoryboard.workspaceListVC {
            self.navigationController!.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func workspaceDidChange(_ notif: Notification) {
        Log.debug("workspace did change notif")
        if let info = notif.userInfo, let ws = info["workspace"] as? EWorkspace {
            self.app.setSelectedWorkspace(ws)
            self.updateListingWorkspace(ws)
            self.updateWorkspaceTypeIcon()
            self.updateWorkspaceTitle(ws.getName())
        }
    }
    
    @objc func orientationDidChange() {
        Log.debug("orientation changed")
        self.updateWorkspaceTypeIcon()
        self.updateWorkspaceTitle(self.workspace.getName())
    }
    
    @IBSegueAction func workspaceSegue(_ coder: NSCoder) -> WorkspaceListViewController? {
        let ws = WorkspaceListViewController(coder: coder)
        return ws
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            AppState.setCurrentScreen(.projectList)
            self.addProject(name: model.name, desc: model.desc)
        }, validateHandler: { model in
            return !model.name.isEmpty
        }))
    }
    
    func didPopupModelChange(_ model: PopupModel, proj: EProject) -> Bool {
        var didChange = true
        proj.managedObjectContext?.performAndWait {
            if model.name.isEmpty {
                didChange = false
            } else {
                didChange = false
                if proj.name != model.name {
                    didChange = true
                }
                if proj.desc != model.desc {
                    didChange = true
                }
            }
        }
        return didChange
    }
    
    func viewEditPopup(_ proj: EProject) {
        self.app.viewPopupScreen(self, model: PopupModel(title: "Edit Project", name: proj.getName(), desc: proj.desc ?? "", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            var didChange = false
            if proj.name != model.name {
                proj.name = model.name
                didChange = true
            }
            if proj.desc != model.desc {
                proj.desc = model.desc
                didChange = true
            }
            if didChange {
                self.localdb.saveMainContext()
                self.updateData()
            }
        }, validateHandler: { model in
            return self.didPopupModelChange(model, proj: proj)
        }))
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Project", style: .default, handler: { action in
            Log.debug("new project did tap")
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
}

class ProjectCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var borderView: UIView!
    
    func hideBottomBorder() {
        self.borderView.isHidden = true
    }
    
    func displayBottomBorder() {
        self.borderView.isHidden = false
    }
}

extension ProjectListViewController: UITableViewDelegate, UITableViewDataSource {
    func getDesc(proj: EProject) -> String {
        return proj.desc ?? ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        if frc == nil { return 0 }
        return frc!.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! ProjectCell
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        let proj = frc!.object(at: indexPath)
        cell.nameLbl.text = proj.name
        let desc = self.getDesc(proj: proj)
        cell.descLbl.text = desc
        self.hideHelpText()
        if desc.isEmpty {
            cell.descLbl.isHidden = true
        } else {
            cell.descLbl.isHidden = false
        }
        cell.displayBottomBorder()
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        let proj = frc!.object(at: indexPath)
        AppState.currentProject = proj  // TODO: remove AppState.currentProject
        DispatchQueue.main.async {
            if let vc = UIStoryboard.requestListVC {
                vc.project = proj
                self.navigationController!.pushViewController(vc, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
            Log.debug("edit row: \(indexPath)")
            let proj = frc!.object(at: indexPath)
            self.viewEditPopup(proj)
            completion(true)
        }
        edit.backgroundColor = App.Color.lightPurple
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let proj = frc!.object(at: indexPath)
            self.localdbSvc.deleteEntity(proj: proj)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete, edit])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let frc = self.container == .cloud ? self.ckFrc : self.localFrc
        let proj = frc!.object(at: indexPath)
        let name = proj.name ?? ""
        let desc = self.getDesc(proj: proj)
        let widthOffset: CGFloat = 46 + 16  // The label view starts with 45 padding on leading and 16 trailing
        let w = tableView.frame.width - widthOffset
        let h1 = UILabel.textHeight(text: name, font: App.Font.font17, width: w)
        let h2 = UILabel.textHeight(text: desc, font: App.Font.font15, width: w)
        Log.debug("row: \(indexPath.row) -> \(h1 + h2 + 32)")
        return max(h1 + h2 + 32, 46)
    }
}

extension ProjectListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("projects list frc did change")
        if AppState.currentScreen != .projectList { return }
        DispatchQueue.main.async {
            if self.navigationController?.topViewController == self {
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
}
