//
//  SettingsTableViewController.swift
//  Restor
//
//  Created by jsloop on 18/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class SettingsTableViewController: RestorTableViewController {
    private let app = App.shared
    @IBOutlet weak var saveHistorySwitch: UISwitch!
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    
    enum CellId: Int {
        case spacerAfterTop
        case workspaceGroup
        case spacerAfterWorkspace
        case toolsTitle
        case base64
        case spacerAfterTools
        case saveHistory
        case spacerAfterSaveHistory
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.settings)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("settings tv view did load")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.tableView.backgroundColor = App.Color.tableViewBg
        self.navigationItem.title = "Settings"
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
    }
    
    func initEvents() {
        self.saveHistorySwitch.addTarget(self, action: #selector(self.saveHistorySwitchDidChange(_:)), for: .valueChanged)
    }
    
    @objc func saveHistorySwitchDidChange(_ sender: UISwitch) {
        Log.debug("save history switch did change")
        let ws = self.app.getSelectedWorkspace()
        ws.saveResponse = self.saveHistorySwitch.isOn
        self.localDB.saveMainContext()
        self.db.saveWorkspaceToCloud(ws)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == CellId.workspaceGroup.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.environmentGroupVC.rawValue)
        } else if indexPath.row == CellId.base64.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.base64VC.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.row {
        case CellId.spacerAfterTop.rawValue:
            return 36
        case CellId.workspaceGroup.rawValue:
            return 44
        case CellId.spacerAfterWorkspace.rawValue:
            return 24
        case CellId.toolsTitle.rawValue:
            return 24
        case CellId.base64.rawValue:
            return 44
        case CellId.spacerAfterTools.rawValue:
            return 24
        case CellId.saveHistory.rawValue:
            return 44
        case CellId.spacerAfterSaveHistory.rawValue:
            return 24
        default:
            break
        }
        return UITableView.automaticDimension
    }
}
