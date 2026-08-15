import AppKit
import Foundation

@MainActor
final class SearchCoordinator {
    private let applicationProvider: ApplicationProvider
    private let fileProvider: FileProvider
    private let webProvider: WebProvider
    private let calculatorProvider: CalculatorProvider
    private let commandProvider: CommandProvider
    private let applicationIndex: ApplicationIndex
    private let selectionStore: SelectionStore
    private let webRegistry: WebSearchRegistry

    private var generation = 0
    private var activeTask: Task<Void, Never>?
    private(set) var lastParsed: ParsedQuery?

    var onResults: (([SearchResult]) -> Void)?

    init(
        applicationProvider: ApplicationProvider,
        fileProvider: FileProvider,
        webProvider: WebProvider,
        calculatorProvider: CalculatorProvider,
        commandProvider: CommandProvider,
        applicationIndex: ApplicationIndex,
        selectionStore: SelectionStore,
        webRegistry: WebSearchRegistry
    ) {
        self.applicationProvider = applicationProvider
        self.fileProvider = fileProvider
        self.webProvider = webProvider
        self.calculatorProvider = calculatorProvider
        self.commandProvider = commandProvider
        self.applicationIndex = applicationIndex
        self.selectionStore = selectionStore
        self.webRegistry = webRegistry
    }

    /// Submit a query update. Old generations are cancelled and their results dropped.
    func update(query: String, limit: Int) {
        generation += 1
        let targetGeneration = generation
        activeTask?.cancel()

        activeTask = Task { [weak self] in
            guard let self else { return }
            let results = await run(query: query, limit: limit)
            guard !Task.isCancelled, targetGeneration == self.generation else { return }
            self.onResults?(results)
        }
    }

    func cancelActive() {
        activeTask?.cancel()
    }

    private func run(query: String, limit: Int) async -> [SearchResult] {
        let parser = QueryParser(webKeywords: webRegistry.keywords)
        let parsed = parser.parse(query)
        lastParsed = parsed

        switch parsed.mode {
        case .recent:
            return await recentResults(limit: limit)
        case .calculator:
            return await calculatorProvider.search(parsed, limit: limit)
        case .webSearch, .url:
            return await webProvider.search(parsed, limit: limit)
        case .fileOpen, .fileFind:
            return await fileProvider.search(parsed, limit: limit)
        case .search:
            return await defaultResults(parsed, limit: limit)
        }
    }

    private func defaultResults(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        var collected: [[SearchResult]] = []
        do {
            try await withThrowingTaskGroup(of: [SearchResult].self) { group in
                group.addTask {
                    if Task.isCancelled { return [] }
                    return await self.applicationProvider.search(parsed, limit: limit)
                }
                group.addTask {
                    if Task.isCancelled { return [] }
                    return await self.commandProvider.search(parsed, limit: limit)
                }
                for try await batch in group {
                    guard !Task.isCancelled else {
                        group.cancelAll()
                        break
                    }
                    collected.append(batch)
                }
            }
        } catch {}

        guard !Task.isCancelled else { return [] }

        var ranked = RankingEngine.rank(
            candidates: collected.flatMap { $0 },
            query: parsed,
            learning: selectionStore.learning,
            limit: limit,
            now: Date()
        )

        if let fallback = webFallback(parsed) {
            ranked.append(fallback)
        }
        return ranked
    }

    private func webFallback(_ parsed: ParsedQuery) -> SearchResult? {
        guard !parsed.searchTerms.isEmpty else { return nil }
        guard let defaultSearch = webRegistry.defaultSearch() else { return nil }
        guard let url = TemplateURLGenerator.generateURL(template: defaultSearch.urlTemplate, query: parsed.normalizedText) else {
            return nil
        }
        return webProvider.webSearchResult(defaultSearch, query: parsed.normalizedText, url: url)
    }

    private func recentResults(limit: Int) async -> [SearchResult] {
        let learning = selectionStore.learning
        let now = Date()

        var candidates: [(result: SearchResult, selectedAt: Date?, usage: Double)] = []
        for record in applicationIndex.snapshot {
            let key = CandidateKey(providerID: ProviderID.application, candidateID: record.bundleIdentifier)
            let aggregate = learning.aggregate(for: key, query: "")
            let usage = learning.globalUsageCounts[key] ?? 0
            guard aggregate.lastSelectedAt != nil else { continue }
            candidates.append((
                applicationProvider.makeSearchResult(record),
                aggregate.lastSelectedAt,
                usage
            ))
        }

        candidates.sort { lhs, rhs in
            score(date: lhs.selectedAt, now: now, usage: lhs.usage) > score(date: rhs.selectedAt, now: now, usage: rhs.usage)
        }

        let applicationResults = candidates.prefix(6).map { $0.result }
        let commandResults = commandProvider.catalog.map { command in
            commandProvider.makeCommandResult(command)
        }
        return applicationResults + commandResults
    }

    private func score(date: Date?, now: Date, usage: Double) -> Double {
        guard let date else { return 0 }
        let age = max(0, now.timeIntervalSince(date) / 86400)
        let recency = exp(-age / 7)
        let frequency = min(1, log2(1 + usage) / 5)
        return 0.65 * recency + 0.35 * frequency
    }
}