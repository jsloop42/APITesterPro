//
//  App.swift
//  APITesterPro
//
//  Created by Jaseem V V on 23/01/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CloudKit

struct EditRequestInfo: Hashable {
    var id: String
    var moID: NSManagedObjectID
    var recordType: RecordType
    var isDelete: Bool = false
}

class App {
    static let shared: App = App()
    var popupBottomContraints: NSLayoutConstraint?
    // private var dbSvc = PersistenceService.shared
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var ckSvc = { CloudSyncService.shared }()
    private let utils = EAUtils.shared
    private let nc = NotificationCenter.default
    private var appLaunched = false
    
    enum Screen {
        case workspaceList
        case projectList
        case requestList
        case editRequest
        case request
        case settings
        case envGroup
        case envVar
        case requestMethodList
        case requestBodyTypeList  // json, xml ..
        case requestBodyFormTypeList  // text, file
        case popup
    }
    
    func bootstrap() {
        self.initDB()
        self.initState()
    }
    
    func initDB() {
        
    }
    
    func initState() {
        _ = self.getSelectedWorkspace()
    }
    
    func initUI(_ vc: UINavigationController) {
        self.updateViewBackground(vc.view)
        self.updateNavigationControllerBackground(vc)
    }
    
    // MARK: - App lifecycle events
    
    private func didFinishLaunchingImpl(window: UIWindow) {
        if !self.appLaunched {
            //self.localdb.bootstrap()
            self.ckSvc.bootstrap()
            self.initUI(window.rootViewController as! UINavigationController)
            self.appLaunched = true
        }
    }
    
    @available(iOS 13.0, *)
    func didFinishLaunching(scene: UIScene, window: UIWindow) {
        Log.debug("did finish launching")
        self.didFinishLaunchingImpl(window: window)
    }
    
    @available(iOS 10.0, *)
    func didFinishLaunching(app: UIApplication, window: UIWindow) {
        Log.debug("did finish launching")
        self.didFinishLaunchingImpl(window: window)
    }
    
    func willEnterForground() {
        do {
            self.nc.addObserver(self, selector: #selector(self.reachabilityDidChange(_:)), name: .reachabilityDidChange, object: EAReachability.shared)
            try EAReachability.shared.startNotifier()
        } catch let error {
            Log.error("Error starting reachability notifier: \(error)")
        }
    }
    
    func didEnterBackground() {
        self.nc.removeObserver(self, name: .reachabilityDidChange, object: EAReachability.shared)
        EAReachability.shared.stopNotifier()
        self.saveState()
    }
    
    @objc func reachabilityDidChange(_ notif: Notification) {
        Log.debug("reachability did change: \(notif)")
        if let reachability = notif.object as? EAReachability {
            Log.debug("network status: \(reachability.connection.description)")
            if reachability.connection == .unavailable {
                self.nc.post(name: .offline, object: self)
            } else {
                self.nc.post(name: .online, object: self)
            }
        }
    }
    
    /// Invoked before application termination to perform save state, clean up.
    func saveState() {
        //self.localdb.saveBackgroundContext(isForce: true)
        self.localdb.saveMainContext()
    }

    func addWorkspace(_ ws: EWorkspace) {
        AppState.workspaces.append(ws)
    }
    
    func addProject(_ project: EProject) {
        // TODO
        //AppState.workspaces[AppState.selectedWorkspace].projects.append(project)
    }
    
    /// Present the option picker view as a modal with the given data
    /// 
    /// - Parameters:
    ///   - project: Optional project which is required if type is requestMethod
    func presentOptionPicker(type: OptionPickerType, title: String, modelIndex: Int, selectedIndex: Int, data: [String], model: Any? = nil,
                             modelxs: [Any]? = [], project: EProject? = nil, storyboard: UIStoryboard?, navVC: UINavigationController?) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.pickerType = type
            vc.modelIndex = modelIndex
            vc.selectedIndex = selectedIndex
            vc.data = data
            vc.name = title
            vc.model = model
            vc.modelxs = modelxs ?? []
            vc.project = project
            navVC?.present(vc, animated: true, completion: nil)
        }
    }
    
    /// Draws a bottom border to the given text field
    func updateTextFieldWithBottomBorder(_ tf: EATextField) {
        tf.borderStyle = .none
        if #available(iOS 13.0, *) {
            tf.tintColor = .secondaryLabel
        } else {
            tf.tintColor = .lightGray
        }
    }
    
    /// Fixes appearance of a translucent background during transition
    func updateNavigationControllerBackground(_ navVC: UINavigationController?) {
        if #available(iOS 13.0, *) {
            navVC?.view.backgroundColor = UIColor.systemBackground
        } else {
            navVC?.view.backgroundColor = UIColor.white
        }
    }
    
    func updateWindowBackground(_ window: UIWindow?) {
        window?.backgroundColor = UIColor.clear
    }
    
    func updateViewBackground(_ view: UIView?) {
        if #available(iOS 13.0, *) {
            view?.backgroundColor = UIColor.systemBackground
        } else {
            view?.backgroundColor = UIColor.white
        }
    }
    
    func viewError(_ error: Error, vc: UIViewController) {
        UI.viewToast(self.getErrorMessage(for: error), vc: vc)
    }
    
    func getDataForURL(_ url: URL, completion: EADataResultCallback? = nil) {
        //if EAFileManager.isFileExists(at: url) {  // since the app is sandboxed, this check will not work.
            let fm = EAFileManager(url: url)
            fm.readToEOF(completion: completion)
        //} else {
         //   if let cb = completion { cb(.failure(AppError.fileNotFound)) }
        //}
    }
    
    func getFileName(_ url: URL) -> String {
        return url.lastPathComponent
    }
    
    /// Return a request name based on the current project's request count.
    func getNewRequestName() -> String {
        if let proj = AppState.currentProject {
            let idx = proj.requests?.count ?? 0
            return idx == 0 ? "Request" : "Request (\(idx + 1))"
        }
        return "Request"
    }
    
    /// Return a request name and index based on the current project's request count.
    func getNewRequestNameWithIndex() -> (String, Int) {
        if let proj = AppState.currentProject {
            let idx = proj.requests?.count ?? 0
            return (idx == 0 ? "Request" : "Request (\(idx + 1))", idx)
        }
        return ("Request", 0)
    }
    
    /// Returns an error message that can be displayed to the user for the given error type.
    func getErrorMessage(for error: Error) -> String {
        if let err = error as? AppError {
            switch err {
            case .fileNotFound:
                return "The file is not found"
            case .fileOpen:
                return "Unable to open the file. Please try again."
            case .fileRead:
                return "Unable to read the file. Please try again."
            case .fileWrite:
                return "Unable to write to the file. Please try again."
            default:
                break
            }
        }
        return "Application encountered an error"
    }
    
    /// Display popup view controller with the given model
    func viewPopupScreen(_ vc: UIViewController, model: PopupModel, completion: (() -> Void)? = nil) {
        let screen = vc.storyboard!.instantiateViewController(withIdentifier: StoryboardId.popupVC.rawValue) as! PopupViewController
        screen.model = model
        vc.present(screen, animated: true, completion: completion)
    }
    
    /// Returns the current workspace
    func getSelectedWorkspace() -> EWorkspace {
        // if AppState.currentWorkspace != nil { return AppState.currentWorkspace! }
        let wsId = self.utils.getValue(Const.selectedWorkspaceIdKey) as? String ?? ""
        let container = self.utils.getValue(Const.selectedWorkspaceContainerKey) as? String ?? CoreDataContainer.cloud.rawValue
        Log.debug("ws: selected container: \(container)")
        if !wsId.isEmpty, let ws = self.localdb.getWorkspace(id: wsId, ctx: container == CoreDataContainer.cloud.rawValue ? self.localdb.ckMainMOC : self.localdb.localMainMOC) {
            AppState.currentWorkspace = ws
            return ws
        }
        let ws = self.localdb.getDefaultWorkspace()
        Log.debug("ws: \(ws)")
        self.saveSelectedWorkspaceId(ws.getId())
        self.saveSelectedWorkspaceContainer(self.localdb.getContainer(ws.managedObjectContext!))
        return ws
    }
    
    func setSelectedWorkspace(_ ws: EWorkspace) {
        AppState.currentWorkspace = ws
        if let wsId = ws.id {
            self.saveSelectedWorkspaceId(wsId)
            self.saveSelectedWorkspaceContainer(self.localdb.getContainer(ws.managedObjectContext!))
        }
    }
    
    func saveSelectedWorkspaceId(_ id: String) {
        self.utils.setValue(key: Const.selectedWorkspaceIdKey, value: id)
    }
    
    func saveSelectedWorkspaceContainer(_ container: CoreDataContainer) {
        self.utils.setValue(key: Const.selectedWorkspaceContainerKey, value: container.rawValue)
    }
    
    func didReceiveMemoryWarning() {
        Log.debug("app: did receive memory warning")
        // TODO: ck: fix me
        // self.dbSvc.clearCache()
    }
    
    func getImageType(_ url: URL) -> ImageType? {
        let name = url.lastPathComponent
        if let ext = name.components(separatedBy: ".").last {
            return ImageType(rawValue: ext)
        }
        return .jpeg  // default photo extension
    }
    
    /// Get text for displaying in name, value cells. If the text value is not present, a space character will be returned so that cells gets displayed with
    /// proper dimension.
    func getKVText(_ text: String?) -> String {
        if text == nil { return " " }
        return text!.isEmpty ? " " : text!
    }
    
    func getStatusCodeViewColor(_ statusCode: Int) -> UIColor {
        var color: UIColor!
        if statusCode > 0 {
            if (200..<299) ~= statusCode {
                color = UIColor(named: "http-status-200")
            } else if (300..<399) ~= statusCode {
                color = UIColor(named: "http-status-300")
            } else if (400..<500) ~= statusCode {
                color = UIColor(named: "http-status-400")
            } else if (500..<600) ~= statusCode {
                color = UIColor(named: "http-status-500")
            }
        } else if statusCode <= -1 {  // error
            color = UIColor(named: "http-status-error")
        } else {
            color = UIColor(named: "http-status-none")
        }
        return color!
    }

    // MARK: - Theme
    public struct Color {
        //public static let lightGreen = UIColor(red: 196/255, green: 223/255, blue: 168/255, alpha: 1.0)
        public static let lightGreen = UIColor(red: 120/255, green: 184/255, blue: 86/255, alpha: 1.0)
        public static let darkGreen = UIColor(red: 91/255, green: 171/255, blue: 60/255, alpha: 1.0)
        public static let darkGrey = UIColor(red: 75/255, green: 74/255, blue: 75/255, alpha: 1.0)
        public static let lightGrey = UIColor(red: 209/255, green: 209/255, blue: 208/255, alpha: 1.0)
        public static let lightGrey1 = UIColor(red: 241/255, green: 241/255, blue: 246/255, alpha: 1.0)
        public static let lightGrey2 = UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 0.8)
        public static let lightPurple = UIColor(red: 119/255, green: 123/255, blue: 246/255, alpha: 1.0)  // purple like
        
        public static var activityIndicatorBg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return Color.darkGrey
                    } else {
                        return Color.lightGrey2
                    }
                }
            } else {
                return Color.lightGrey2
            }
        }()
        public static var activityIndicator: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return Color.lightGrey2
                    } else {
                        return Color.darkGrey
                    }
                }
            } else {
                return Color.darkGrey
            }
        }()
        public static var requestMethodBg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return Color.darkGreen
                    } else {
                        return Color.lightGreen
                    }
                }
            } else {
                return Color.lightGreen
            }
        }()
        public static var requestEditDoneBtnDisabled: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.darkGray
                    } else {
                        return Color.lightGrey
                    }
                }
            } else {
                return Color.lightGrey
            }
        }()
        public static var tableViewBg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.systemBackground
                    } else {
                        return Color.lightGrey1
                    }
                }
            } else {
                return Color.lightGrey1
            }
        }()
        public static var labelTitleFg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor.secondaryLabel
            }
            return UIColor(red: 96/255, green: 97/255, blue: 101/255, alpha: 1.0)
        }()
        public static var textViewFg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor.black
                    }
                }
            }
            return UIColor.black
        }()
        public static var navBarBg: UIColor = {
            let light = UIColor(red: 246/255, green: 247/255, blue: 248/255, alpha: 1.0)
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 39/255, green: 40/255, blue: 42/255, alpha: 1.0)
                    } else {
                        return light
                    }
                }
            }
            return light
        }()
    }
    
    public struct Font {
        static let monospace13: UIFont = {
            if #available(iOS 13, *) {
                return UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            }
            return UIFont(name: "Menlo-Regular", size: 13)!
        }()
        static let monospace14: UIFont = {
            if #available(iOS 13, *) {
                return UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
            }
            return UIFont(name: "Menlo-Regular", size: 14)!
        }()
        static let font17 = UIFont.systemFont(ofSize: 17)
        static let font16 = UIFont.systemFont(ofSize: 16)
        static let font15 = UIFont.systemFont(ofSize: 15)
    }
}

enum TableCellId: String {
    case workspaceCell
    case emptyMessageCell
}

enum StoryboardId: String {
    case base64VC
    case rootNav
    case editRequestVC
    case requestTabBar
    case requestVC
    case responseVC
    case environmentGroupVC
    case envEditVC
    case envVarVC
    case envPickerVC
    case importExportVC
    case optionsPickerNav
    case optionsPickerVC
    case popupVC
    case projectListVC
    case requestListVC
    case settingsVC
    case historyVC
    case workspaceListVC
}

/// The request option elements
enum RequestCellType: Int {
    case description
    case header
    case param
    case body
    case auth
    case option
}

enum RequestMethod: String, Codable {
    case get = "GET"
    case head = "HEAD"
    
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    
    case delete = "DELETE"
    
    case trace = "TRACE"
    case option = "OPTIONS"
}

enum RequestBodyType: Int {
    case json
    case xml
    case raw
    case form
    case multipart
    case binary
    
    static var allCases: [String] {
        return ["json", "xml", "raw", "form", "multipart", "binary"]
    }
    
    static func toString(_ type: Int) -> String {
        guard let _type = RequestBodyType(rawValue: type) else { return "" }
        switch _type {
        case .json:
            return "json"
        case .xml:
            return "xml"
        case .raw:
            return "raw"
        case .form:
            return "form"
        case .multipart:
            return "multipart"
        case .binary:
            return "binary"
        }
    }
}

/// Indicates to which model the `ERequestData` belongs to
enum RequestDataType: Int {
    case header
    case param
    case form
    case multipart
    case binary
}

/// Form fields under request body
enum RequestBodyFormFieldFormatType: Int {
    case text
    case file

    static var allCases: [String] {
        return ["Text", "File"]
    }
}

enum ImageType: String {
    case png
    case jpeg
    case jpg
    case heic
    case gif
    case tiff
    case webp
    case svg
}

enum AppError: Error {
    case entityGet
    case entityUpdate
    case entityDelete
    case error
    case extrapolate
    case fileOpen
    case fileRead
    case fileWrite
    case fileNotFound
    case notFound
    case create
    case read
    case write
    case update
    case delete
    case network
    case offline
    case server
    case fetch
    case invalidURL
}

extension CKRecord {
    func getWsId() -> String {
        return self["wsId"] ?? ""
    }
}

extension UIStoryboard {
    static var main: UIStoryboard { UIStoryboard(name: "Main", bundle: nil) }
    static var rootNav: APITesterProNavigationController? { self.main.instantiateViewController(withIdentifier: StoryboardId.rootNav.rawValue) as? APITesterProNavigationController }
    static var workspaceListVC: WorkspaceListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.workspaceListVC.rawValue) as? WorkspaceListViewController }
    static var projectListVC: ProjectListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.projectListVC.rawValue) as? ProjectListViewController }
    static var requestListVC: RequestListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.requestListVC.rawValue) as? RequestListViewController }
    static var requestTabBar: RequestTabBarController? { self.main.instantiateViewController(withIdentifier: StoryboardId.requestTabBar.rawValue) as? RequestTabBarController }
    static var editRequestVC: EditRequestTableViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.editRequestVC.rawValue) as? EditRequestTableViewController }
}
