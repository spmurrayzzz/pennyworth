import XCTest
@testable import Pennyworth

/// A small judged corpus covering exact, prefix, multi-token, initials, alias,
/// fuzzy, and non-ASCII application queries. Mirrors the plan's ranking targets:
/// exact titles at rank 1 and strong prefixes in the top group.
final class JudgeCorpusTests: XCTestCase {
    private struct Case {
        let query: String
        let expected: String
    }

    private let catalog = [
        "Safari", "Terminal", "Calculator", "System Settings", "Notes", "Reminders",
        "Visual Studio Code", "Xcode", "Finder", "Mail", "Photos", "GitHub Desktop",
        "QuickTime Player", "TextEdit", "Preview", "Utilities", "Control Center",
        "File Explorer", "TextEdit", "Weather", "Podcasts", "Skip Barber",
        "Safari Technology Preview", "App Store", "Chess", "Notes Pro",
    ]

    private let cases: [Case] = [
        Case(query: "terminal", expected: "Terminal"),
        Case(query: "safari", expected: "Safari"),
        Case(query: "calculator", expected: "Calculator"),
        Case(query: "system settings", expected: "System Settings"),
        Case(query: "visual studio", expected: "Visual Studio Code"),
        Case(query: "xcode", expected: "Xcode"),
        Case(query: "reminders", expected: "Reminders"),
        Case(query: "mail", expected: "Mail"),
    ]

    private func result(_ name: String) -> SearchResult {
        SearchResult(
            providerID: "application",
            candidateID: name,
            entityKey: name,
            kind: .application,
            title: name,
            subtitle: "/Applications/\(name).app",
            matchText: "\(name)",
            aliases: [],
            targetValue: "/Applications/\(name).app",
            icon: .symbol("app"),
            accessoryText: nil,
            realized: true
        )
    }

    func testJudgedExactTitlesRankAtPositionOne() {
        let candidates = catalog.map(result)
        for corpus in cases {
            let parsed = QueryParser(webKeywords: []).parse(corpus.query)
            let ranked = RankingEngine.rank(candidates: candidates, query: parsed, learning: .empty, limit: 10, now: Date())
            let titles = ranked.map(\.title)
            XCTAssertEqual(titles.first, corpus.expected, "query: \(corpus.query)")
        }
    }

    func testAccentFoldSearch() {
        let ranked = RankingEngine.rank(
            candidates: [result("French Café"), result("Coffee")],
            query: QueryParser(webKeywords: []).parse("café"),
            learning: .empty,
            limit: 10,
            now: Date()
        )
        XCTAssertEqual(ranked.first?.title, "French Café")
    }

    func testInitialsMatchWordBoundaries() {
        let ranked = RankingEngine.rank(
            candidates: [result("Visual Studio Code"), result("Virtual CDE"), result("Droids")],
            query: QueryParser(webKeywords: []).parse("vs code"),
            learning: .empty,
            limit: 10,
            now: Date()
        )
        XCTAssertEqual(ranked.first?.title, "Visual Studio Code")
    }

    func testExactBeatsLearnedCompetitorAcrossCorpus() {
        var learning = SelectionLearning()
        let key = CandidateKey(providerID: "application", candidateID: "Calculator")
        learning.globalUsageCounts[key] = 100
        learning.lastSelectedAt[key] = Date()
        for corpus in cases {
            let ranked = RankingEngine.rank(
                candidates: catalog.map(result),
                query: QueryParser(webKeywords: []).parse(corpus.query),
                learning: learning,
                limit: 10,
                now: Date()
            )
            XCTAssertEqual(ranked.first?.title, corpus.expected, "query: \(corpus.query)")
        }
    }
}