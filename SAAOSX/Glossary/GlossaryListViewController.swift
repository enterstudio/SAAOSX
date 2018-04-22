//
//  GlossaryListViewController.swift
//  SAAOSX
//
//  Created by Chaitanya Kanchan on 20/01/2018.
//  Copyright © 2018 Chaitanya Kanchan. All rights reserved.
//

import Cocoa
import CDKSwiftOracc

class GlossaryListViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    @IBOutlet weak var glossaryTableView: NSTableView!
    var filteredGlossary: [(Int, String, String)] = []
    var searchBarIsEmpty: Bool = true
    var definitionViewController: GlossaryEntryViewController?
    

    func numberOfRows(in tableView: NSTableView) -> Int {
        if !searchBarIsEmpty {
            return filteredGlossary.count
        }
        return glossaryController.glossaryCount
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let view = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else {return nil}
        
        let citationForm: String
        let guideWord: String

        if !searchBarIsEmpty {
            let (_, cf, gw) = filteredGlossary[row]
            citationForm = cf
            guideWord = gw
        } else {
            guard let (cf, gw) = glossaryController.labelsForRow(row: row + 1) else {return nil}
            citationForm = cf
            guideWord = gw
        }

        

        

        guard let tableColumn = tableColumn else {return nil}
        switch tableColumn.identifier.rawValue {
        case "CitationForm":
            view.textField?.stringValue = citationForm
        case "GuideWord":
            view.textField?.stringValue = guideWord
        default:
            break
        }
        
        return view
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let glossaryEntry: GlossaryEntry
        
        if !searchBarIsEmpty {
            let rowID = filteredGlossary[glossaryTableView.selectedRow].0
            guard let ge = glossaryController.entryForRow(row: rowID) else {return}
            glossaryEntry = ge
        } else {
            guard let ge = glossaryController.entryForRow(row: glossaryTableView.selectedRow + 1) else { return }
            glossaryEntry = ge
        }
        
        if let definitionViewController = definitionViewController {
            definitionViewController.glossaryEntry = glossaryEntry
        }
    }
    
    
    // MARK :- Search functions
    func filterContentForSearchText(_ searchText: String) {
        filteredGlossary = glossaryController.searchDatabase(searchText.lowercased())
    }
    
    @IBAction func search(_ sender: NSSearchField) {
        if !sender.stringValue.isEmpty {
            searchBarIsEmpty = false
            filterContentForSearchText(sender.stringValue)
            glossaryTableView.reloadData()
        } else {
            searchBarIsEmpty = true
            glossaryTableView.reloadData()
        }
    }
    
    
}
