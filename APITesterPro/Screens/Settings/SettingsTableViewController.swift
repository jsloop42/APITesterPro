//
//  SettingsTableViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 18/03/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import StoreKit
import MessageUI

class SettingsTableViewController: APITesterProTableViewController {
    private let app = App.shared
    @IBOutlet weak var saveHistorySwitch: UISwitch!
    @IBOutlet weak var syncWorkspaceSwitch: UISwitch!
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    private lazy var workspace = { self.app.getSelectedWorkspace() }()
    @IBOutlet weak var aboutTitle: UILabel!
    private lazy var utils = { EAUtils.shared }()
    private var indicatorView: UIView?
    private var exportFileURL: URL?
    
    enum CellId: Int {
        case spacerAfterTop
        case workspaceGroup
        case spacerAfterWorkspace
        case syncWorkspace
        case saveHistory
        case spacerAfterSaveHistory
        case toolsTitle
        case base64
        case spacerAfterTools
        case importData
        case exportData
        case spaceAfterExportData
        case rate
        case feedback
        case share
        case spacerAfterShare
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
        self.saveHistorySwitch.isOn = self.workspace.saveResponse
        self.syncWorkspaceSwitch.isOn = self.workspace.isSyncEnabled
        self.updateAbout()
    }
    
    func updateAbout() {
        let name = Const.appName
        let version = self.utils.appVersion() ?? ""
        self.aboutTitle.text = version.isEmpty ? "\(name)" : "\(name) v\(version)"
    }
    
    func initEvents() {
        self.saveHistorySwitch.addTarget(self, action: #selector(self.saveHistorySwitchDidChange(_:)), for: .valueChanged)
        self.syncWorkspaceSwitch.addTarget(self, action: #selector(self.syncWorkspaceSwitchDidChange(_:)), for: .valueChanged)
    }
    
    func rateApp() {
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        } else if let url = URL(string: "itms-apps://itunes.apple.com/app/" + Const.appId) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Const.feedbackEmail])
            mail.setSubject("API Tester Pro Feedback")
            if let version = self.utils.appVersion() {
                mail.setMessageBody("<br /><p>App version: v\(version)</p>", isHTML: true)
            }
            self.present(mail, animated: true)
        } else {
            UI.viewToast("Unable to compose e-mail. Please send your feedback to \(Const.feedbackEmail).", vc: self)
        }
    }
    
    func shareLink() {
        if let url = URL(string: Const.appURL), let image = UIImage(named: "api-tester-pro-icon") {
            let objectsToShare: [Any] = [Const.shareText, url, image]
            let activityVC = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            if UIDevice.current.userInterfaceIdiom == .pad {
                if let popup = activityVC.popoverPresentationController {
                    popup.sourceView = self.view
                    popup.sourceRect = CGRect(x: self.view.frame.size.width / 2, y: self.view.frame.size.height / 4, width: 0, height: 0)
                }
            }
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    @objc func syncWorkspaceSwitchDidChange(_ sender: UISwitch) {
        Log.debug("sync workspace switch did change")
        self.workspace.isSyncEnabled = self.syncWorkspaceSwitch.isOn
        self.localDB.saveMainContext()
        self.db.saveWorkspaceToCloud(self.workspace)
        if self.workspace.isSyncEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {  // sync any pending changes
                self.db.syncToCloud()
            }
        }
    }
    
    @objc func saveHistorySwitchDidChange(_ sender: UISwitch) {
        Log.debug("save history switch did change")
        self.workspace.saveResponse = self.saveHistorySwitch.isOn
        self.localDB.saveMainContext()
        self.db.saveWorkspaceToCloud(self.workspace)
    }
    
    func showLoadingIndicator() {
        if self.indicatorView == nil { self.indicatorView = UIView() }
        UI.showCustomActivityIndicator(self.indicatorView!, mainView: self.view, shouldDisableInteraction: true)
    }
    
    func hideLoadingIndicator() {
        if let indicatorView = self.indicatorView {
            UI.removeCustomActivityIndicator(indicatorView)
            self.indicatorView = nil
        }
    }
    
    func writeJSONToTempFile(json: String, ws: EWorkspace) {
        self.exportFileURL = EAFileManager.getTemporaryURL(ws.getName() + ".json")
        if self.exportFileURL != nil {
            EAFileManager.createFileIfNotExists(self.exportFileURL!)
            let fm = EAFileManager(url: self.exportFileURL!)
            fm.openFile(for: FileIOMode.write)
            fm.write(json)
            fm.close()
        }
    }
    
    func exportCurrentWorkspace() {
        self.showLoadingIndicator()
        let ws = self.app.getSelectedWorkspace()
        let wsDict = ws.toDictionary()
        if let data = try? JSONSerialization.data(withJSONObject: wsDict, options: .fragmentsAllowed), let json = String(data: data, encoding: .utf8) {
            self.writeJSONToTempFile(json: json, ws: ws)
            if let url = self.exportFileURL {
                UI.displayDocumentPickerForExport(url: url, delegate: self, tvVc: self, vc: nil)
            }
        }
    }
    
    func importWorkspace(_ url: URL) {
        DispatchQueue.main.async { self.showLoadingIndicator() }
        let fm = EAFileManager(url: url)
        if EAFileManager.startAccessingSecurityScopedResource(url: url) {
            fm.openFile(for: FileIOMode.read)
            fm.readToEOF { result in
                do {
                    switch result {
                    case .success(let data):
                        if let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                            DispatchQueue.main.async {
                                if let _ = EWorkspace.fromDictionary(dict) {
                                    self.hideLoadingIndicator()
                                    UI.viewToast("Workspace imported successfully", hideSec: 2, vc: self, completion: nil)
                                }
                            }
                        }
                    case .failure(let err):
                        DispatchQueue.main.async { self.hideLoadingIndicator() }
                        Log.error(err)
                    }
                    fm.close()
                    EAFileManager.stopAccessingSecurityScopedResource(url: url)
                } catch let err {
                    fm.close()
                    EAFileManager.stopAccessingSecurityScopedResource(url: url)
                    DispatchQueue.main.async { self.hideLoadingIndicator() }
                    Log.error(err)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == CellId.workspaceGroup.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.environmentGroupVC.rawValue)
        } else if indexPath.row == CellId.base64.rawValue {
            UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.base64VC.rawValue)
        } else if indexPath.row == CellId.importData.rawValue {
            self.exportFileURL = nil  // clear the variable so the document picker delegate can run the import block
            UI.displayDocumentPickerForImport(delegate: self, tvVc: self, vc: nil)
        } else if indexPath.row == CellId.exportData.rawValue {
            UI.viewActionSheet(
                vc: self, message: "This will export current workspace data which can be saved to a file", cancelText: "Cancel",
                otherButtonText: "Continue", cancelStyle: UIAlertAction.Style.destructive, otherStyle: UIAlertAction.Style.default,
                cancelCallback: {
                    Log.debug("cancel callback")
                },
                otherCallback: {
                    Log.debug("continue to export")
                    self.exportCurrentWorkspace()
                }
            )
        } else if indexPath.row == CellId.rate.rawValue {
            self.rateApp()
        } else if indexPath.row == CellId.feedback.rawValue {
            self.sendFeedback()
        } else if indexPath.row == CellId.share.rawValue {
            self.shareLink()
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
        case CellId.syncWorkspace.rawValue:
            return 44
        case CellId.saveHistory.rawValue:
            return 44
        case CellId.spacerAfterSaveHistory.rawValue:
            return 24
        case CellId.toolsTitle.rawValue:
            return 24
        case CellId.base64.rawValue:
            return 44
        case CellId.spacerAfterTools.rawValue:
            return 24
        case CellId.importData.rawValue:
            return 44
        case CellId.exportData.rawValue:
            return 44
        case CellId.spaceAfterExportData.rawValue:
            return 24
        case CellId.rate.rawValue:
            return 44
        case CellId.feedback.rawValue:
            return 44
        case CellId.share.rawValue:
            return 44
        case CellId.spacerAfterShare.rawValue:
            return 50
        default:
            break
        }
        return UITableView.automaticDimension
    }
}

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}

extension SettingsTableViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let fileUrl = urls.first else {
            Log.debug("No document selected for export")
            return
        }
        if self.exportFileURL == nil {  // opened for importing
            Log.debug("file opened for import")
            self.importWorkspace(fileUrl)
        } else {
            if #available(iOS 14.0, *) {
                // ignore
            } else {
                // iOS 12 and 13 we need to copy the contents of the temp file and delete it
                if let url = self.exportFileURL {
                    if EAFileManager.copy(source: url, destination: fileUrl) {
                        _ = EAFileManager.delete(url: url)
                        self.exportFileURL = nil
                    } else {
                        UI.displayToast("Error writing to the selected file")
                    }
                }
            }
        }
        self.hideLoadingIndicator()
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        if let url = self.exportFileURL {
            _ = EAFileManager.delete(url: url)  // remove stale export file
            self.exportFileURL = nil
            Log.debug("File deleted")
        }
        self.hideLoadingIndicator()
    }
}
