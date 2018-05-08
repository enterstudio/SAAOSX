//
//  MasterViewController.swift
//  SAAiOS
//
//  Created by Chaitanya Kanchan on 06/03/2018.
//  Copyright © 2018 Chaitanya Kanchan. All rights reserved.
//

import UIKit
import CDKSwiftOracc

enum Navigate {
    case left, right
}

class ProjectListViewController: UITableViewController {

    var detailViewController: TextEditionViewController? = nil
    var filteredTexts: [OraccCatalogEntry] = []
    lazy var catalogue: CatalogueProvider = {return sqlite}()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? TextEditionViewController
        }
        
        tableView.reloadData()
        
        
        if self.catalogue.source != .search {
        let glossaryButton = UIBarButtonItem(title: "Glossary", style: .plain, target: self, action: #selector(showGlossary))
        self.setToolbarItems([glossaryButton], animated: false)
        } else {
            self.title = catalogue.name
        }
        
        self.initialiseSearchControllers()
        
        
        
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    @objc func showGlossary(_ sender: Any?) {
        guard let glossaryController = storyboard?.instantiateViewController(withIdentifier: StoryboardIDs.Glossary) as? GlossaryTableViewController else {return}
        
        if let quickDefinition = sender as? UIBarButtonItem {
            if let text = quickDefinition.title {
                if text != "Glossary" {
                let cf = text.prefix(while: {$0 != ":"})
                if !cf.isEmpty {
                    glossaryController.searchController.isActive = true
                    glossaryController.searchController.searchBar.text = String(cf)
                    glossaryController.searchController.searchBar.selectedScopeButtonIndex = 0
                    glossaryController.updateSearchResults(for: glossaryController.searchController)
                    
                    }
                }
            }
        }
        
        self.navigationController?.pushViewController(glossaryController, animated: true)
    }


    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                guard let (catalogueEntry, textStrings) = getTextViewData(for: indexPath) else {return}
                let controller = (segue.destination as! UINavigationController).topViewController as! TextEditionViewController
                controller.textItem = catalogueEntry
                controller.textStrings = textStrings
                controller.catalogue = self.catalogue
                controller.parentController = self

                if catalogue.source == .search {
                    guard let catalogue = self.catalogue as? Catalogue else {return}
                    guard let textSearch = catalogue.catalogue as? TextSearchCollection else {return}
                    let searchTerm = textSearch.searchTerm
                    controller.searchTerm = searchTerm
                }

                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
                controller.becomeFirstResponder()
            }
        }
    }
    
    func getTextViewData(for indexPath: IndexPath) -> (OraccCatalogEntry, TextEditionStringContainer)? {
        let catalogueEntry: OraccCatalogEntry
        if isFiltering() {
            catalogueEntry = filteredTexts[indexPath.row]
        } else {
            catalogueEntry = catalogue.texts[indexPath.row]
        }
        
        guard let textStrings = sqlite.getTextStrings(catalogueEntry.id) else {return nil}
        
        return (catalogueEntry, textStrings)
        
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isFiltering() {
            return filteredTexts.count
        } else {
            return catalogue.texts.count
        }
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let textItem: OraccCatalogEntry
        
        if isFiltering() {
            textItem = filteredTexts[indexPath.row]
        } else {
            textItem = catalogue.texts[indexPath.row]
        }
        
        cell.textLabel?.text = textItem.displayName
        cell.detailTextLabel?.text = textItem.title
        return cell
    }
    
    
    func getIndexPath(_ direction: Navigate) -> IndexPath? {
        guard let selection = tableView.indexPathForSelectedRow else {return nil}
        switch direction {
        case .left:
            return IndexPath(row: selection.row - 1, section: selection.section)
            
        case .right:
            return IndexPath(row: selection.row + 1, section: selection.section)
        }
    }

    
    func navigate(_ direction: Navigate) {
        guard let newIndexPath = getIndexPath(direction) else {return}
        guard tableView.cellForRow(at: newIndexPath) != nil else {return}
        
        tableView.selectRow(at: newIndexPath, animated: false, scrollPosition: .middle)
    }
    
    // MARK: - Search controller configuration
    let searchController = UISearchController(searchResultsController: nil)
    func initialiseSearchControllers() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search texts"
        searchController.searchBar.addShortcuts()
        navigationItem.searchController = searchController
        definesPresentationContext = true
    }
    
    func searchBarIsEmpty() -> Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }
    
    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredTexts = catalogue.texts.filter {
            $0.description.lowercased().contains(searchText.lowercased()
            )}
        tableView.reloadData()
    }
    
    func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }
    
    
    override func encodeRestorableState(with coder: NSCoder) {
        if let indexPath = tableView.indexPathForSelectedRow {
            coder.encode(indexPath.section, forKey: "selectedSection")
            coder.encode(indexPath.row, forKey: "selectedRow")
        }
        
        super.encodeRestorableState(with: coder)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        defer {super.decodeRestorableState(with: coder)}
        let row = coder.decodeInteger(forKey: "selectedRow")
        let section = coder.decodeInteger(forKey: "selectedSection")
        let indexPath = IndexPath(row: row, section: section)
        self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
    }

}

extension ProjectListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
}
