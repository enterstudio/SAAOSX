//
//  CatalogueController.swift
//  CDKOraccControllers
//
//  Created by Chaitanya Kanchan on 23/02/2018.
//

import CDKSwiftOracc

public enum CatalogueSource: String {
    case sqlite = "Local Database", online = "Online", bookmarks = "Bookmarks", local, search
}

/// Defines an interface for objects that can supply Oracc Catalogue data to view controllers and other interested parties
public protocol CatalogueProvider: AnyObject {
    var name: String { get }
    var count: Int { get }
    var texts: [OraccCatalogEntry] { get }
    var source: CatalogueSource { get }

    func text(at row: Int) -> OraccCatalogEntry?
    func search(_ string: String) -> [OraccCatalogEntry]
}

public class Catalogue: CatalogueProvider {
    public func search(_ string: String) -> [OraccCatalogEntry] {
        return texts.filter {$0.description.lowercased().contains(string.lowercased())}
    }

    public var count: Int {
        return texts.count
    }

    public func text(at row: Int) -> OraccCatalogEntry? {
        return texts[row]
    }

    public let catalogue: TextSet
    public let texts: [OraccCatalogEntry]
    public let source: CatalogueSource

    public lazy var name = { return self.catalogue.title }()
    public init(catalogue: TextSet, sorted: [OraccCatalogEntry], source: CatalogueSource) {
        self.catalogue = catalogue
        self.texts = sorted
        self.source = source
    }
}
