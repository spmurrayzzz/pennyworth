import AppKit
import Foundation
import Observation
@preconcurrency import KeyboardShortcuts

@MainActor
@Observable
final class SettingsModel {
    private let database: DatabaseStore
    private let selectionStore: SelectionStore
    private let webRegistry: WebSearchRegistry

    var resultLimit: Int
    var launchAtLogin: Bool
    var searches: [WebSearch]
    var defaultSearchID: String?
    var selection: WebSearch?

    var isAddSheetPresented = false
    var draftName = ""
    var draftKeyword = ""
    var draftTemplate = ""

    init(database: DatabaseStore, selectionStore: SelectionStore, webRegistry: WebSearchRegistry) {
        self.database = database
        self.selectionStore = selectionStore
        self.webRegistry = webRegistry
        resultLimit = AppSettings.resultLimit
        launchAtLogin = LoginItemController.shared.isRegistered
        searches = webRegistry.searches
        defaultSearchID = AppSettings.defaultWebSearchID
    }

    func updateResultLimit(_ newValue: Int) {
        AppSettings.resultLimit = newValue
    }

    func updateLaunchAtLogin(_ newValue: Bool) {
        LoginItemController.shared.setEnabled(newValue)
        launchAtLogin = LoginItemController.shared.isRegistered
    }

    func resetLearnedRanking() {
        selectionStore.reset()
    }

    func updateSearch(_ search: WebSearch) {
        guard WebSearchValidation.validate(search) == nil else { return }
        webRegistry.save(search)
        refreshSearches()
    }

    func makeDefault(of search: WebSearch) {
        AppSettings.defaultWebSearchID = search.id
        defaultSearchID = search.id
    }

    func reorder(fromOffsets: IndexSet, toOffset: Int) {
        searches.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for index in searches.indices {
            var refreshed = searches[index]
            refreshed.sortOrder = index
            webRegistry.save(refreshed)
        }
        refreshSearches()
    }

    var webSearchList: [WebSearch] {
        searches
    }

    func deleteSearch(id: String) {
        webRegistry.delete(id: id)
        refreshSearches()
        if defaultSearchID != nil {
            defaultSearchID = AppSettings.defaultWebSearchID
        }
    }

    func deleteSelected() {
        if let selection {
            deleteSearch(id: selection.id)
        }
        selection = nil
    }

    func promptAddSearch() {
        draftName = ""
        draftKeyword = ""
        draftTemplate = "https://"
        isAddSheetPresented = true
    }

    func addSearch() {
        let keyword = draftKeyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = draftTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSearch = WebSearch(
            id: UUID().uuidString.lowercased(),
            name: name,
            keyword: keyword,
            urlTemplate: template,
            isEnabled: true,
            sortOrder: searches.count,
            createdAt: Date(),
            updatedAt: Date()
        )
        guard WebSearchValidation.validate(newSearch) == nil else { return }
        webRegistry.save(newSearch)
        refreshSearches()
        isAddSheetPresented = false
    }

    private func refreshSearches() {
        searches = webRegistry.searches
    }
}