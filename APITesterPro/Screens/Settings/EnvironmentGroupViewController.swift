//
//  EnvironmentGroupViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 19/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class EnvGroupCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
}

class EnvironmentGroupViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    private let app = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    private var frc: NSFetchedResultsController<EEnv>!
    private var workspace: EWorkspace?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.envGroup)
        self.updateData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initData()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        self.tableView.backgroundColor = App.Color.tableViewBg
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.navigationItem.title = "Environments"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    func initData() {
        guard self.frc == nil else { return }
        if self.workspace == nil { self.workspace = self.app.getSelectedWorkspace() }
        guard let wsId = self.workspace?.getId() else { return }
        if let _frc = self.localdb.getFetchResultsController(obj: EEnv.self, predicate: NSPredicate(format: "wsId == %@ AND markForDelete == %hhd", wsId, false), ctx: self.localdb.mainMOC) as? NSFetchedResultsController<EEnv> {
            self.frc = _frc
            self.frc.delegate = self
            try? self.frc.performFetch()
            self.tableView.reloadData()
        }
    }

    func updateData() {
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.tableView.reloadData()
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envEditVC.rawValue) as? EnvironmentEditViewController {
            vc.mode = .addEnv
            self.present(vc, animated: true, completion: nil)
        }
    }
}

extension EnvironmentGroupViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.frc == nil { return 0 }
        return self.frc.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "envGroupCell", for: indexPath) as! EnvGroupCell
        cell.nameLabel.text = self.frc.object(at: indexPath).getName()
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let env = self.frc.object(at: indexPath)
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envVarVC.rawValue) as? EnvironmentVariableTableViewController {
            vc.env = env
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
            Log.debug("edit row: \(indexPath)")
            let env = self.frc.object(at: indexPath)
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envEditVC.rawValue) as? EnvironmentEditViewController {
                vc.env = env
                vc.mode = .editEnv
                self.navigationController?.present(vc, animated: true, completion: nil)
                completion(true)
            } else {
                completion(false)
            }
        }
        edit.backgroundColor = App.Color.lightPurple
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let env = self.frc.object(at: indexPath)
            self.localdbSvc.deleteEntity(env: env)
            self.localdb.saveMainContext()
            // TODO: delete data marked for delete env
            // self.db.deleteDataMarkedForDelete(env, ctx: self.localDB.mainMOC)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete, edit])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
}

extension EnvironmentGroupViewController: NSFetchedResultsControllerDelegate {
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("env list frc did change")
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
