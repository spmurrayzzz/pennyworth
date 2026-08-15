import AppKit
import Foundation

@MainActor
final class WebProvider: SearchProvider {
    private let registry: WebSearchRegistry

    init(registry: WebSearchRegistry) {
        self.registry = registry
    }

    var providerID: String {
        ProviderID.web
    }

    func supports(mode: QueryMode) -> Bool {
        mode == .webSearch || mode == .url
    }

    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        switch parsed.mode {
        case .url:
            guard let url = URLPolicy.finalURL(from: parsed.normalizedText) else { return [] }
            return [makeURLResult(url: url)]
        case .webSearch:
            guard let keyword = parsed.keyword, let webSearch = registry.search(keyword: keyword) else {
                return []
            }
            guard webSearch.isEnabled else { return [] }
            guard let url = TemplateURLGenerator.generateURL(template: webSearch.urlTemplate, query: parsed.normalizedText) else {
                return []
            }
            return [webSearchResult(webSearch, query: parsed.normalizedText, url: url)]
        default:
            return []
        }
    }

    func webSearchResult(_ webSearch: WebSearch, query: String, url: URL) -> SearchResult {
        let host = url.host?.lowercased() ?? "browser"
        let title: String
        if query.isEmpty {
            title = "Open \(webSearch.name)"
        } else {
            title = "Search \"\(query)\" in \(webSearch.name)"
        }
        return SearchResult(
            providerID: ProviderID.web,
            candidateID: webSearch.id,
            entityKey: "web:\(webSearch.id)",
            kind: .url,
            title: title,
            subtitle: host,
            matchText: "\(webSearch.name) \(host)",
            aliases: [webSearch.keyword],
            targetValue: url.absoluteString,
            icon: .symbol("magnifyingglass"),
            accessoryText: nil,
            realized: true
        )
    }

    private func makeURLResult(url: URL) -> SearchResult {
        let host = url.host?.lowercased() ?? "browser"
        return SearchResult(
            providerID: "web",
            candidateID: url.absoluteString,
            entityKey: "url:\(url.absoluteString)",
            kind: .url,
            title: url.absoluteString,
            subtitle: host,
            matchText: "\(url.absoluteString) \(host)",
            aliases: [],
            targetValue: url.absoluteString,
            icon: .symbol("safari"),
            accessoryText: nil,
            realized: true
        )
    }
}