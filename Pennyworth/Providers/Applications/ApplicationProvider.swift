import AppKit
import Foundation

@MainActor
final class ApplicationProvider: SearchProvider {
    private let index: ApplicationIndex

    init(index: ApplicationIndex) {
        self.index = index
    }

    var providerID: String {
        ProviderID.application
    }

    func supports(mode: QueryMode) -> Bool {
        mode == .search
    }

    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        guard parsed.mode == .search else { return [] }
        if parsed.searchTerms.isEmpty { return [] }
        return index.snapshot.map { record in
            makeSearchResult(record)
        }
    }

    func makeSearchResult(_ record: ApplicationRecord) -> SearchResult {
        let subtitle = record.version.map { "\(record.bundleURL.path) · v\($0)" } ?? record.bundleURL.path
        return SearchResult(
            providerID: ProviderID.application,
            candidateID: record.bundleIdentifier,
            entityKey: record.bundleIdentifier,
            kind: .application,
            title: record.displayName,
            subtitle: subtitle,
            matchText: "\(record.displayName) \(record.bundleName) \(record.bundleURL.path)",
            aliases: record.aliases,
            targetValue: record.bundleURL.path,
            icon: .application(record.bundleURL),
            accessoryText: nil,
            realized: true
        )
    }
}