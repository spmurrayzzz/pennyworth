import Foundation

@MainActor
protocol SearchProvider: AnyObject {
    var providerID: String { get }
    func supports(mode: QueryMode) -> Bool
    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult]
}