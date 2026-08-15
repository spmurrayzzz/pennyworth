import AppKit
import Foundation

@MainActor
final class WebSearchRegistry {
    private let database: DatabaseStore
    private(set) var searches: [WebSearch] = []
    var onChange: (() -> Void)?

    init(database: DatabaseStore) {
        self.database = database
    }

    func loadSelectionIfNeeded() {
        Task {
            let stored = await database.loadWebSearches()
            if stored.isEmpty {
                let bundled = Self.loadBundledSearches()
                await database.replaceAllWebSearches(bundled)
                searches = bundled
            } else {
                searches = stored
            }
        }
    }

    var keywords: [String] {
        searches.filter(\.isEnabled).map(\.keyword)
    }

    func defaultSearch() -> WebSearch? {
        searches.filter(\.isEnabled).min { $0.sortOrder < $1.sortOrder }
    }

    func search(keyword: String) -> WebSearch? {
        searches.first { $0.keyword == keyword }
    }

    func search(id: String) -> WebSearch? {
        searches.first { $0.id == id }
    }

    func save(_ search: WebSearch) {
        var prepared = search
        prepared.name = prepared.name.trimmingCharacters(in: .whitespacesAndNewlines)
        prepared.keyword = prepared.keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        prepared.urlTemplate = prepared.urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = searches.firstIndex(where: { $0.id == prepared.id }) {
            searches[existing] = prepared
        } else {
            searches.append(prepared)
        }
        renumber()
        let stored = prepared
        Task { await database.saveWebSearch(stored) }
    }

    func delete(id: String) {
        searches.removeAll { $0.id == id }
        renumber()
        Task { await database.deleteWebSearch(id: id) }
    }

    private func renumber() {
        searches.sort { $0.sortOrder < $1.sortOrder }
        for index in searches.indices {
            searches[index].sortOrder = index
        }
    }

    private static func loadBundledSearches() -> [WebSearch] {
        guard let url = Bundle.main.url(forResource: "DefaultWebSearches", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let items = try? JSONDecoder().decode([BundledWebSearch].self, from: data)
        else { return [] }
        return items.enumerated().map { index, item in
            WebSearch(
                id: UUID().uuidString.lowercased(),
                name: item.name,
                keyword: item.keyword,
                urlTemplate: item.urlTemplate,
                isEnabled: item.isEnabled,
                sortOrder: index,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
}

private struct BundledWebSearch: Decodable {
    let name: String
    let keyword: String
    let urlTemplate: String
    let isEnabled: Bool
    let sortOrder: Int
}

enum WebSearchValidation {
    static func validate(_ search: WebSearch) -> String? {
        if search.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is required."
        }
        let keyword = search.keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty {
            return "A keyword is required."
        }
        if QueryKeyword.reservedWebProhibited.contains(keyword) {
            return "This keyword is reserved. Choose another."
        }
        return nil
    }
}