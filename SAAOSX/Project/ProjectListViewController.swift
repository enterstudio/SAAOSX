//
//  ProjectListViewController.swift
//  SAAOSX
//
//  Created by Chaitanya Kanchan on 14/01/2018.
//  Copyright © 2018 Chaitanya Kanchan. All rights reserved.
//

import Cocoa
import CDKSwiftOracc
import CDKOraccInterface

class ProjectListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, BookmarkDisplaying {

    func refreshTableView() {
        self.catalogueEntryView.reloadData()
    }

    @IBOutlet weak var catalogueEntryView: NSTableView!

    lazy var projectList: [CDKOraccProject] = {
        if let result = try? oracc.getOraccProjects() {
            return result
        } else {
            return []
        }
    }()

    lazy var windowController: ProjectListWindowController = {
        return self.view.window?.windowController as! ProjectListWindowController
    }()

    lazy var infoSidebar: InfoSideBarViewController = {
        let split = self.parent! as! NSSplitViewController
        return split.children.last! as! InfoSideBarViewController
    }()

    var catalogueProvider: CatalogueProvider? {
        didSet {
            DispatchQueue.main.async {
                if let source = self.catalogueProvider?.source {
                    switch source {
                    case .search:
                        self.windowController.setConnectionStatus(to: self.catalogueProvider?.name ?? "Search Results")
                    case .sqlite, .online, .bookmarks, .local:
                        self.windowController.setConnectionStatus(to: "\(source.rawValue) \(self.catalogueProvider?.name ?? "")")
                    }
                } else {
                    self.windowController.setConnectionStatus(to: "disconnected")
                }
            }
        }
    }

    var selectedText: OraccCatalogEntry?

    override func viewDidAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshTableView), name: Bookmarks.Update, object: nil)
        catalogueEntryView.doubleAction = #selector(doubleClickLoadText(_:))

        // If the window is being duplicated, then use a previously existing catalogue to save memory.
        guard self.catalogueProvider == nil else {
            windowController.setTitle(catalogueProvider?.name ?? "SAAoSX")
            catalogueEntryView.reloadData()
            return
        }

        // Otherwise load a default catalogue
        loadCatalogue("sqlite")
        windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func loadCatalogue(_ catalogueStr: String) {
        self.windowController.loadingIndicator.startAnimation(nil)

        if catalogueStr == "pins" {
            self.catalogueProvider = bookmarks
            self.catalogueEntryView.reloadData()
            self.windowController.loadingIndicator.stopAnimation(nil)
            self.windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")
            return
        }

        if catalogueStr == "sqlite" {
            self.catalogueProvider = self.sqlite
            self.catalogueEntryView.reloadData()
            self.windowController.loadingIndicator.stopAnimation(nil)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.searchBarIsEmpty = true
            self.selectedText = nil
            self.filteredTexts = []

            guard let cat = self.projectList.first(where: {$0.pathname.contains(catalogueStr)})
                else {
                    DispatchQueue.main.async {
                        self.windowController.setConnectionStatus(to: "disconnected")
                        self.windowController.pinnedToggle.state = .on
                        self.loadCatalogue("saa01")
                    }
                    return
            }

            do {
                let catalogue = try self.oracc.loadCatalogue(cat)
                var texts = Array(catalogue.members.values)
                texts.sort {$0.displayName < $1.displayName}
                let controller = Catalogue(catalogue: catalogue, sorted: texts, source: .online)
                self.catalogueProvider = controller
                DispatchQueue.main.async {
                    self.catalogueEntryView.reloadData()
                    self.windowController.loadingIndicator.stopAnimation(nil)
                    self.windowController.setTitle(self.catalogueProvider?.name ?? "SAAoSX")
                    self.windowController.setConnectionStatus(to: "connected")
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    self.loadCatalogue("pins")
                    self.windowController.setConnectionStatus(to: "disconnected")
                    self.windowController.pinnedToggle.state = .on
                }
            }
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if !searchBarIsEmpty {
            return filteredTexts.count
        }
        return catalogueProvider?.count ?? 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let vw = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as? NSTableCellView else { return nil }

        let text: OraccCatalogEntry
        if !searchBarIsEmpty {
            text = filteredTexts[row]
        } else {
            guard let txt = catalogueProvider?.text(at: row) else { return nil }
            text = txt
        }

        if tableColumn?.identifier.rawValue == "saaNumber" {
            vw.textField?.stringValue = text.displayName
        } else if tableColumn?.identifier.rawValue == "title"{
            vw.textField?.stringValue = text.title
        } else if tableColumn?.identifier.rawValue == "sender" {
            vw.textField?.stringValue = text.ancientAuthor ?? "(unassigned)"
        }

        if let pinned = bookmarks.contains(textID: text.id.description) {
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

    func openTextWindow(_ textEntry: OraccCatalogEntry) {
        guard let catalogueSource = self.catalogueProvider?.source else { return }
        switch catalogueSource {
        case .bookmarks:
            if let stringContainer = bookmarks.getTextStrings(textEntry.id.description) {
                TextWindowController.new(textEntry, strings: stringContainer, catalogue: self.catalogueProvider)
                self.windowController.loadingIndicator.stopAnimation(nil)
                return
            }

        case .search:
            guard let sqlite = self.sqlite else {return}
            guard let catalogue = self.catalogueProvider as? Catalogue else {return}
            guard let textSearchCollection = catalogue.catalogue as? TextSearchCollection else { return }

            if let stringContainer = sqlite.getTextStrings(textEntry.id) {
                TextWindowController.new(textEntry, strings: stringContainer, catalogue: self.catalogueProvider, searchTerm: textSearchCollection.searchTerm)
                self.windowController.loadingIndicator.stopAnimation(nil)
                return
            }

        case .sqlite:
            guard let sqlite = self.sqlite else {return}
            if let stringContainer = sqlite.getTextStrings(textEntry.id) {
                TextWindowController.new(textEntry, strings: stringContainer, catalogue: self.catalogueProvider)
                self.windowController.loadingIndicator.stopAnimation(nil)
                return
            }

        case .online:
            DispatchQueue.global(qos: .userInitiated).async {
                if let textEdition = try? self.oracc.loadText(textEntry) {
                    let stringContainer = TextEditionStringContainer(textEdition)
                    DispatchQueue.main.async {
                        TextWindowController.new(textEntry, strings: stringContainer, catalogue: self.catalogueProvider)
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

        case .local:
            break
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if !searchBarIsEmpty {
            selectedText = filteredTexts[catalogueEntryView.selectedRow]
        } else {
            guard let txt = catalogueProvider?.text(at: catalogueEntryView.selectedRow) else { return  }
            selectedText = txt
        }

        if let selectedText = selectedText {
            infoSidebar.setLabels(selectedText)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            if let text = selectedText {
                windowController.loadingIndicator.startAnimation(nil)
                openTextWindow(text)
            }
        } else {
            super.keyDown(with: event)
        }
    }

    @objc func doubleClickLoadText(_ sender: Any) {
        if let text = selectedText {
            windowController.loadingIndicator.startAnimation(nil)
            openTextWindow(text)
        }
    }

    // MARK :- Search functions
    var filteredTexts: [OraccCatalogEntry] = []
    var searchBarIsEmpty: Bool = true

    func filterContentForSearchText(_ searchText: String) {
        filteredTexts = catalogueProvider?.search(searchText) ?? []
    }

    @IBAction func search(_ sender: NSSearchFieldCell) {
        search(sender.stringValue)
    }

    func search(_ str: String) {
        if !str.isEmpty {
            searchBarIsEmpty = false
            filterContentForSearchText(str)
            catalogueEntryView.reloadData()
        } else {
            searchBarIsEmpty = true
            catalogueEntryView.reloadData()
        }
    }

    @IBAction func viewOnline(_ sender: Any) {
        if let text = selectedText {
            var baseURL = URL(string: "http://oracc.org")!

            if text.project.contains("Geography of Knowledge") {
                baseURL.appendPathComponent("cams/gkab")
            } else {
            baseURL.appendPathComponent(text.project)
            }
            baseURL.appendPathComponent(text.id.description)
            NSWorkspace.shared.open(baseURL)
        }
    }

    @IBAction func newProjectListWindow(_ sender: Any) {
        ProjectListWindowController.new(catalogue: self.catalogueProvider)
    }

    @IBAction func newDocument(_ sender: Any) {
        newProjectListWindow(self)
    }

    @IBAction func glossary(_ sender: Any) {
        GlossaryWindowController.new(self)

    }
}
