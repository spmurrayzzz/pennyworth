import Foundation

struct WebSearch: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var keyword: String
    var urlTemplate: String
    var isEnabled: Bool
    var sortOrder: Int
    var createdAt: Date?
    var updatedAt: Date?

    static func make(name: String, keyword: String, urlTemplate: String, isEnabled: Bool = true, sortOrder: Int) -> WebSearch {
        WebSearch(
            id: UUID().uuidString.lowercased(),
            name: name,
            keyword: keyword,
            urlTemplate: urlTemplate,
            isEnabled: isEnabled,
            sortOrder: sortOrder,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}