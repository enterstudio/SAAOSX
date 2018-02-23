//
//  ProjectListViewController.swift
//  SAAOSX
//
//  Created by Chaitanya Kanchan on 14/01/2018.
//  Copyright © 2018 Chaitanya Kanchan. All rights reserved.
//

import Cocoa
import OraccJSONtoSwift
import SQLite

class ProjectListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var catalogueEntryView: NSTableView!
    
    lazy var projectList: [OraccProjectEntry] = {
        if let result = try? oracc.getOraccProjects() { return result
        } else {
            return []
        }
    }()
    
    lazy var windowController: ProjectListWindowController = {
        return self.view.window?.windowController as! ProjectListWindowController
    }()
    
    lazy var infoSidebar: InfoSideBarViewController = {
        let split = self.parent! as! NSSplitViewController
        return split.childViewControllers.last! as! InfoSideBarViewController
    }()
    
    
    var catalogueProvider: CatalogueProvider?
    var selectedText: OraccCatalogEntry? = nil
    var showingPins: Bool = false

    
    override func viewDidAppear() {
        pinnedTextController.tableViews.add(self)
        catalogueEntryView.doubleAction = #selector(doubleClickLoadText(_:))
        
        // If the window is being duplicated, then use a previously existing catalogue to save memory.
        guard self.catalogueProvider == nil else {
            windowController.setTitle(catalogueProvider?.name ?? "SAAoSX")
            windowController.setConnectionStatus(to: "connected")
            catalogueEntryView.reloadData()
            return
        }
        
        // Otherwise load a default catalogue
        loadCatalogue("saa01")
        windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")

    }
    
    override func viewWillDisappear() {
        pinnedTextController.tableViews.remove(self)
    }

    
    func loadCatalogue(_ s: String) {
        self.windowController.loadingIndicator.startAnimation(nil)
        
        if s == "pins" {
            self.showingPins = true
            self.catalogueProvider = pinnedTextController
            self.catalogueEntryView.reloadData()
            self.windowController.loadingIndicator.stopAnimation(nil)
            self.windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.searchBarIsEmpty = true
            self.selectedText = nil
            self.filteredTexts = []
            
            guard let cat = self.projectList.first(where: {$0.pathname.contains(s)})
                else {
                    DispatchQueue.main.async {
                        self.windowController.setConnectionStatus(to: "disconnected")
                        self.windowController.pinnedToggle.state = .on
                        self.loadCatalogue("pins")
                    }
                    return
            }
            
            do {
                let catalogue = try self.oracc.loadCatalogue(cat)
                var texts = Array(catalogue.members.values)
                texts.sort{$0.displayName < $1.displayName}
                let controller = CatalogueController(catalogue: catalogue, sorted: texts, source: .interface)
                self.catalogueProvider = controller
                DispatchQueue.main.async {
                    self.catalogueEntryView.reloadData()
                    self.windowController.loadingIndicator.stopAnimation(nil)
                    self.windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")
                    self.windowController.setConnectionStatus(to: "connected")
                    self.showingPins = false
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    self.loadCatalogue("pins")
                    self.windowController.setConnectionStatus(to: "disconnected")
                    self.showingPins = true
                    self.windowController.pinnedToggle.state = .on
                }
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if !searchBarIsEmpty {
            return filteredTexts.count
        }
        return catalogueProvider?.texts.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let vw = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }
        
        let text: OraccCatalogEntry
        if !searchBarIsEmpty {
            text = filteredTexts[row]
        } else {
            guard let txt = catalogueProvider?.texts[row] else { return nil }
            text = txt
        }
        
        if tableColumn?.identifier.rawValue == "saaNumber" {
            vw.textField?.stringValue = text.displayName
        } else if tableColumn?.identifier.rawValue == "title"{
            vw.textField?.stringValue = text.title
        } else if tableColumn?.identifier.rawValue == "sender" {
            vw.textField?.stringValue = text.ancientAuthor ?? "(unassigned)"
        }
        
        if let pinned = pinnedTextController.contains(textID: text.id) {
            if pinned {
                vw.textField?.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            } else {
                vw.textField?.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            }
        }
        return vw
    }
    
    public func setCatalogueProvider(_ provider: CatalogueProvider) {
        self.catalogueProvider = provider
        catalogueEntryView.reloadData()
    }
    
    
    func loadTextWindow(withText textEdition: OraccTextEdition, catalogueEntry: OraccCatalogEntry) {
        guard let window = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("textWindow")) as? TextWindowController else { return }
        guard let textView = window.contentViewController as? TextViewController else { return }
        
        window.window?.title = "\(catalogueEntry.displayName): \(catalogueEntry.title)"
        
        let stringContainer = TextEditionStringContainer(textEdition)
        textView.catalogueEntry = catalogueEntry
        textView.stringContainer = stringContainer
        textView.catalogueController = catalogueProvider
        window.textViewController = [textView]
        
        window.showWindow(self)

    }
    
    func loadSplitTextWindow(withText textEdition: OraccTextEdition, catalogueEntry: OraccCatalogEntry){
        
        guard let window = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("SplitTextWindow")) as? TextWindowController else { return }
        guard let splitTextViewController = window.contentViewController as? NSSplitViewController else { return }
        
        let stringContainer = TextEditionStringContainer(textEdition)
        guard let controllers = splitTextViewController.childViewControllers as? [TextViewController] else {return}
        controllers.forEach{
            $0.stringContainer = stringContainer
            $0.catalogueEntry = catalogueEntry
            $0.catalogueController = catalogueProvider
            $0.splitViewController = splitTextViewController
            window.textViewController.append($0)
        }
        

        
        window.contentViewController = splitTextViewController
        window.window?.title = "\(catalogueEntry.displayName): \(catalogueEntry.title)"
        window.window?.setFrame(NSRect(x: 640, y: 640, width: 1000, height: 800), display: false)
        window.catalogueSearch.stringValue = catalogueEntry.title
        window.catalogueSearch.delegate = window
        window.showWindow(self)
    }
    
    func callLoadTextWindow(_ textEntry: OraccCatalogEntry){
        if self.showingPins {
            if let stringContainer = pinnedTextController.getTextStrings(textEntry.id) {
                guard let window = self.storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("textWindow")) as? TextWindowController else {return}
                guard let textView = window.contentViewController as? TextViewController else {return}
                
                window.window?.title = "\(textEntry.displayName): \(textEntry.title)"
                
                textView.catalogueEntry = textEntry
                textView.stringContainer = stringContainer
                textView.catalogueController = pinnedTextController
                window.textViewController = [textView]
                
                window.showWindow(self)
                self.windowController.loadingIndicator.stopAnimation(nil)
                return
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            if let textEdition = try? self.oracc.loadText(textEntry) {
                DispatchQueue.main.async {
                    switch UserDefaults.standard.integer(forKey: PreferenceKey.textWindowNumber.rawValue) {
                    case 0:
                        self.loadTextWindow(withText: textEdition, catalogueEntry: textEntry)
                    case 1:
                        self.loadSplitTextWindow(withText: textEdition, catalogueEntry: textEntry)
                    default:
                        print("Colossal error")
                    }
                    self.windowController.loadingIndicator.stopAnimation(nil)
                }
            } else {
                DispatchQueue.main.async {
                    self.windowController.loadingIndicator.stopAnimation(nil)
                    let alert = NSAlert()
                    alert.messageText = "No text available"
                    alert.informativeText = "Edition for \(textEntry.title) not available"
                    alert.addButton(withTitle: "OK")
                    alert.addButton(withTitle: "Try online")
                    alert.alertStyle = .warning
                    let response = alert.runModal()
                    if response == NSApplication.ModalResponse.alertSecondButtonReturn {
                        self.viewOnline(self)
                    }
                }
            }
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if !searchBarIsEmpty {
            selectedText = filteredTexts[catalogueEntryView.selectedRow]
        } else {
            guard let txt = catalogueProvider?.texts[catalogueEntryView.selectedRow] else { return  }
            selectedText = txt
        }
        
        if let selectedText = selectedText {
            infoSidebar.setLabels(selectedText)
        }
    }
    
    
    @objc func doubleClickLoadText(_ sender: Any){
        if let text = selectedText {
            windowController.loadingIndicator.startAnimation(nil)
            callLoadTextWindow(text)
        }
    }
    
    

    // MARK :- Search functions
    var filteredTexts: [OraccCatalogEntry] = []
    var searchBarIsEmpty: Bool = true
    
    
    func filterContentForSearchText(_ searchText: String){
        guard let texts = catalogueProvider?.texts else { return }
        filteredTexts = texts.filter {
            $0.description.lowercased().contains(searchText.lowercased())
        }
    }
    
    @IBAction func search(_ sender: NSSearchFieldCell) {
        if !sender.stringValue.isEmpty {
            searchBarIsEmpty = false
            filterContentForSearchText(sender.stringValue)
            catalogueEntryView.reloadData()
        } else {
            searchBarIsEmpty = true
            catalogueEntryView.reloadData()
        }
    }
    
    @IBAction func viewOnline(_ sender: Any) {
        if let text = selectedText {
            var baseURL = URL(string: "http://oracc.org")!
            
            if text.project.contains("Geography of Knowledge"){
                baseURL.appendPathComponent("cams/gkab")
            } else {
            baseURL.appendPathComponent(text.project)
            }
            baseURL.appendPathComponent(text.id)
            NSWorkspace.shared.open(baseURL)
        }
    }

    @IBAction func newProjectListWindow(_ sender: Any) {
        guard let newWindow = storyboard?.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("ProjectListWindow")) as? ProjectListWindowController else {return}
        newWindow.projectViewController.catalogueProvider = self.catalogueProvider
        newWindow.showWindow(nil)
    }
    
    @IBAction func newDocument(_ sender: Any){
        newProjectListWindow(self)
    }

    @IBAction func glossary(_ sender: Any) {
        GlossaryWindowController.new(self)

    }
}
