import XCTest
@testable import Pennyworth

@MainActor
final class RegressionTests: XCTestCase {
    private func makeDatabase() async -> DatabaseStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pennyworth-gates-\(UUID().uuidString)")
        let store = DatabaseStore(url: directory.appendingPathComponent("test.sqlite3"))
        await store.open()
        return store
    }

    private func event(_ id: String, selectedAt: Date, query: String = "notes") -> SelectionEvent {
        SelectionEvent(
            providerID: ProviderID.application,
            candidateID: id,
            queryMode: QueryMode.search.rawValue,
            normalizedQuery: query,
            actionID: "default",
            selectedAt: selectedAt
        )
    }

    func testDatabasePrunesSelectionsOlderThan28Days() async {
        let database = await makeDatabase()
        let now = Date()
        await database.insertSelectionEvent(event("recent", selectedAt: now.addingTimeInterval(-3600)))
        await database.insertSelectionEvent(event("old", selectedAt: now.addingTimeInterval(-29 * 24 * 3600)))
        await database.pruneSelections(now: now)
        let remaining = await database.loadSelectionEvents()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.candidateID, "recent")
    }

    func testLearningIgnoresSelectionsOlderThan28Days() async throws {
        let database = await makeDatabase()
        let now = Date()
        await database.insertSelectionEvent(event("fresh", selectedAt: now.addingTimeInterval(-2 * 24 * 3600)))
        await database.insertSelectionEvent(event("stale", selectedAt: now.addingTimeInterval(-40 * 24 * 3600)))
        let store = SelectionStore(database: database)
        await store.load()
        let learning = store.learning
        let freshKey = CandidateKey(providerID: ProviderID.application, candidateID: "fresh")
        let staleKey = CandidateKey(providerID: ProviderID.application, candidateID: "stale")
        XCTAssertNotNil(learning.globalUsageCounts[freshKey])
        XCTAssertNil(learning.globalUsageCounts[staleKey])
        XCTAssertNotNil(learning.exactQueryCounts[QueryCandidateKey(
            providerID: ProviderID.application, candidateID: "fresh", normalizedQuery: "notes"
        )])
    }

    func testResetClearsLearnedRanking() async throws {
        let database = await makeDatabase()
        let now = Date()
        await database.insertSelectionEvent(event("fresh", selectedAt: now))
        await database.insertSelectionEvent(event("other", selectedAt: now.addingTimeInterval(-3600)))
        await database.resetLearnedRanking()
        let remaining = await database.loadSelectionEvents()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCommandsOpenOnlyFixedSystemPaths() {
        let specs = CommandProvider.supportedSpecs
        XCTAssertEqual(specs.map(\.path), [
            "/System/Applications/System Settings.app",
            "/System/Applications/Utilities/Activity Monitor.app",
            "/System/Library/CoreServices/ScreenSaverEngine.app",
        ])
        for spec in specs {
            XCTAssertTrue(spec.path.hasPrefix("/System/"), spec.path)
            XCTAssertFalse(spec.aliases.isEmpty)
        }
        let provider = CommandProvider()
        provider.refreshAvailability()
        var resolvedBundleIDs: [String] = []
        for spec in specs {
            let plistURL = URL(fileURLWithPath: spec.path).appendingPathComponent("Contents/Info.plist")
            if let plist = NSDictionary(contentsOf: plistURL),
                let identifier = plist["CFBundleIdentifier"] as? String
            {
                resolvedBundleIDs.append(identifier)
                XCTAssertEqual(spec.fallbackBundleID, identifier, spec.path)
            }
        }
        XCTAssertEqual(provider.catalog.map(\.bundleIdentifier).sorted(), resolvedBundleIDs.sorted())
    }

    func testWebResultShowsDestinationHost() async throws {
        let database = await makeDatabase()
        let registry = WebSearchRegistry(database: database)
        let provider = WebProvider(registry: registry)
        let search = WebSearch(
            id: "google",
            name: "Google",
            keyword: "g",
            urlTemplate: "https://www.google.com/search?q={query}",
            isEnabled: true,
            sortOrder: 0,
            createdAt: nil,
            updatedAt: nil
        )
        let result = provider.webSearchResult(
            search,
            query: "cat",
            url: URL(string: "https://www.google.com/search?q=cat")!
        )
        XCTAssertEqual(result.subtitle, "www.google.com")
    }

    func testQueryPipelineLatencyStaysBelowBudget() {
        let names = (0..<220).map { index in
            "ApplicationName" + String(format: "%02d", index)
        }
        let candidates: [SearchResult] = names.map { name in
            SearchResult(
                providerID: ProviderID.application,
                candidateID: name,
                entityKey: name,
                kind: .application,
                title: name,
                subtitle: "/Applications/\(name).app",
                matchText: name,
                aliases: [],
                targetValue: "/Applications/\(name).app",
                icon: .application(URL(fileURLWithPath: "/Applications/\(name).app")),
                accessoryText: nil,
                realized: true
            )
        }
        let queries = (0..<100).map { "app" + String(format: "%02d", $0 % 15) }
        var durations: [Duration] = []
        let clock = ContinuousClock()
        for query in queries {
            let parsed = QueryParser(webKeywords: []).parse(query)
            let start = clock.now
            _ = RankingEngine.rank(
                candidates: candidates,
                query: parsed,
                learning: .empty,
                limit: 10,
                now: Date()
            )
            durations.append(start.duration(to: clock.now))
        }
        durations.sort()
        let p95 = durations[Int(Double(durations.count) * 0.95)]
        let p95Seconds = Double(p95.components.attoseconds) / 1e18
        XCTAssertLessThan(p95Seconds, 0.05, "p95 query pipeline latency \(p95Seconds) exceeded 50ms")
    }
}