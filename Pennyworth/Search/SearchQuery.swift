import Foundation

enum QueryMode: String, Codable, Hashable, Sendable {
    case recent
    case search
    case fileOpen
    case fileFind
    case webSearch
    case url
    case calculator
}

struct ParsedQuery: Equatable, Sendable {
    let rawText: String
    let normalizedText: String
    let mode: QueryMode
    let keyword: String?
    let searchTerms: [String]
}

struct SearchQuery: Sendable {
    let generation: Int
    let parsed: ParsedQuery
    let limit: Int
}