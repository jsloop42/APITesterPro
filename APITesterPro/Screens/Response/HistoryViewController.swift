//
//  HistoryTableViewController.swift
//  APITesterPro
//
//  Created by Jaseem V V on 26/06/20.
//  Copyright © 2020 Jaseem V V. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class HistoryCell: UITableViewCell {
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var pathLabel: UILabel!
    @IBOutlet weak var statusCodeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var bottomBorder: UIView!
    
    func hideBottomBorder() {
        self.bottomBorder.isHidden = true
    }
    
    func displayBottomBorder() {
        self.bottomBorder.isHidden = false
    }
}

class HistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    private let app = App.shared
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var localdbSvc = { PersistenceService.shared }()
    private var todayFrc: NSFetchedResultsController<EHistory>!
    private var pastFrc: NSFetchedResultsController<EHistory>!
    @IBOutlet weak var helpLabel: UILabel!
    var request: ERequest?
    var sectionTitle: [String] = ["Today", "Older"]
    
    enum Section: Int {
        case today
        case past
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.initData()
        self.initUI()
        self.initEvents()
    }
    
    func initData() {
        guard let ctx = self.request?.managedObjectContext else { return }
        if self.todayFrc == nil {
            if let _frc = self.localdb.getFetchResultsController(obj: EHistory.self, predicate: self.getTodayPredicate(), sortDesc: self.getSortDescriptors(),
                                                                 ctx: ctx) as? NSFetchedResultsController<EHistory> {
                self.todayFrc = _frc
                self.todayFrc.delegate = self
                try? self.todayFrc.performFetch()
            }
        }
        if self.pastFrc == nil {
            if let _frc = self.localdb.getFetchResultsController(obj: EHistory.self, predicate: self.getPastPredicate(), sortDesc: self.getSortDescriptors(),
                                                                 ctx: ctx) as? NSFetchedResultsController<EHistory> {
                self.pastFrc = _frc
                self.pastFrc.delegate = self
                try? self.pastFrc.performFetch()
            }
        }
        self.checkForEmptyMessageDisplay()
        self.tableView.reloadData()
    }
    
    func checkForEmptyMessageDisplay() {
        let len = self.todayFrc.numberOfRows(in: 0) + self.pastFrc.numberOfRows(in: 0)
        if len == 0 {
            self.displayHelpText()
        } else {
            self.hideHelpText()
        }
    }
    
    func displayHelpText() {
        UIView.animate(withDuration: 0.3) {
            self.helpLabel.isHidden = false
        }
    }
    
    func hideHelpText() {
        UIView.animate(withDuration: 0.3) {
            self.helpLabel.isHidden = true
        }
    }
    
    func getTodayPredicate() -> NSPredicate {
        guard let reqId = self.request?.getId() else { return NSPredicate(value: true) }
        return NSPredicate(format: "request.id == %@ AND created >= %@", reqId, Date().startOfDay as CVarArg)
        //return NSPredicate(format: "requestId == %@", reqId)
    }
    
    func getPastPredicate() -> NSPredicate {
        guard let reqId = self.request?.getId() else { return NSPredicate(value: true) }
        return NSPredicate(format: "request.id == %@ AND created < %@", reqId, Date().startOfDay as CVarArg)
    }
    
    func getSortDescriptors() -> [NSSortDescriptor] {
        return [NSSortDescriptor(key: SortOrder.created.rawValue, ascending: false)]
    }
    
    func updateData() {
        if self.todayFrc != nil {
            self.todayFrc.delegate = nil
            try? self.todayFrc.performFetch()
            self.todayFrc.delegate = self
        }
        if self.pastFrc != nil {
            self.pastFrc.delegate = nil
            try? self.pastFrc.performFetch()
            self.pastFrc.delegate = self
        }
        self.checkForEmptyMessageDisplay()
        self.tableView.reloadData()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = UITableView.automaticDimension
        self.tableView.rowHeight = 54
        self.navigationItem.title = "History"
    }
    
    func initEvents() {
        
    }
    
    @objc func segmentDidChange(_ sender: Any) {
        Log.debug("segment did change")
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == Section.today.rawValue {
            return self.todayFrc.numberOfRows(in: 0)
        }
        if section == Section.past.rawValue {
            return self.pastFrc.numberOfRows(in: 0)
        }
        return 0
    }
    
    func historyForRow(_ row: Int, isToday: Bool) -> EHistory {
        return isToday ? self.todayFrc.object(at: IndexPath(row: row, section: 0)) : self.pastFrc.object(at: IndexPath(row: row, section: 0))
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryCell
        let section = indexPath.section
        let row = indexPath.row
        let isToday = section == Section.today.rawValue
        let history = self.historyForRow(row, isToday: isToday)
        cell.methodLabel.text = history.method
        if let urlStr = history.url, let url = URL(string: urlStr) {
            let path = url.path
            cell.pathLabel.text = path.isEmpty ? "/" : path
        }
        cell.statusCodeLabel.text = history.statusCode > 0 ? "\(history.statusCode)" : ""
        cell.statusCodeLabel.textColor = self.app.getStatusCodeViewColor(history.statusCode.toInt())
        cell.dateLabel.text = history.created?.toLocalDate().fmt_dd_MMM_YYYY_HH_mm_ss
        let len = isToday ? self.todayFrc.numberOfRows(in: 0) : self.pastFrc.numberOfRows(in: 0)
        if row == len - 1 {
            cell.displayBottomBorder()
        } else {
            cell.hideBottomBorder()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = indexPath.section
        let row = indexPath.row
        let isToday = section == Section.today.rawValue
        let history = self.historyForRow(row, isToday: isToday)
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.responseVC.rawValue) as? ResponseTableViewController {
            vc.viewType = .historyResponse
            vc.data = ResponseData(history: history)
            vc.request = self.request
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func hasElements(inSection section: Int) -> Bool {
        if section == Section.today.rawValue {
            return self.todayFrc.numberOfRows(in: 0) > 0
        }
        if section == Section.past.rawValue {
            return self.pastFrc.numberOfRows(in: 0) > 0
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sectionTitle[section]
    }
    
//    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
//        let width = tableView.frame.width
//        let view = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 28))
//        view.backgroundColor = UIColor(named: "table-view-cell-bg")
//        let label = UILabel(frame: CGRect(x: 15, y: 4, width: width, height: 17))
//        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
//        label.text = self.sectionTitle[section]
//        view.addSubview(label)
//        return view
//    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.hasElements(inSection: section) {
            return 28
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let row = indexPath.row
            let section = indexPath.section
            let isToday = section == Section.today.rawValue
            let history = self.historyForRow(row, isToday: isToday)
            self.localdbSvc.deleteEntity(history: history)
            self.localdb.saveMainContext()
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
}

extension HistoryViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("history list frc did change")
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

