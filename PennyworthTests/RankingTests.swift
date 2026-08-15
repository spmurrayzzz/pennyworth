import XCTest
@testable import Pennyworth

final class RankingTests: XCTestCase {
    private func appResult(_ name: String, path: String = "/Applications/Fake.app") -> SearchResult {
        SearchResult(
            providerID: "application",
            candidateID: name,
            entityKey: name,
            kind: .application,
            title: name,
            subtitle: path,
            matchText: "\(name) \(path)",
            aliases: [],
            targetValue: path,
            icon: .symbol("questionmark"),
            accessoryText: nil,
            realized: true
        )
    }

    private func rank(_ candidates: [SearchResult], query: String, learning: SelectionLearning = .empty) -> [SearchResult] {
        let parsed = QueryParser(webKeywords: []).parse(query)
        return RankingEngine.rank(
            candidates: candidates,
            query: parsed,
            learning: learning,
            limit: 20,
            now: Date()
        )
    }

    func testExactMatchAtRankOne() {
        let candidates = [
            appResult("System Settings"),
            appResult("Settings"),
            appResult("Terminal"),
        ]
        let ranked = rank(candidates, query: "system settings")
        XCTAssertEqual(ranked.first?.title, "System Settings")
    }

    func testEmptyCandidatesDoNotFetch() {
        XCTAssertTrue(rank([], query: "anything").isEmpty)
    }

    func testUnrelatedCandidatesFiltered() {
        let ranked = rank([appResult("Finder"), appResult("Terminal")], query: "asdfzz")
        XCTAssertTrue(ranked.isEmpty)
    }

    func testShorterExactBuilderWinsOnTie() {
        let ranked = rank([
            appResult("Terminal"),
            appResult("Terminal Automation"),
            appResult("Terminal Tools"),
        ], query: "terminal")
        XCTAssertEqual(ranked.first?.title, "Terminal")
    }

    func testExactMatchGroupIsProtectedFromLearnedBonus() {
        let other = appResult("Safari")
        let exactMatch = appResult("Safari Technology Preview")
        var learning = SelectionLearning()
        let otherKey = CandidateKey(providerID: "application", candidateID: "Safari")
        learning.globalUsageCounts[otherKey] = 20
        learning.lastSelectedAt[otherKey] = Date()
        let ranked = rank([other, exactMatch], query: "safari technology preview", learning: learning)
        XCTAssertEqual(ranked.first?.title, "Safari Technology Preview")
    }

    func testLearnedSelectionRaisesCandidateWithinGroup() {
        let short = appResult("Bramble")
        let longer = appResult("Brambles")
        var learning = SelectionLearning()
        let key = CandidateKey(providerID: "application", candidateID: "Brambles")
        learning.globalUsageCounts[key] = 10
        learning.lastSelectedAt[key] = Date()
        let without = rank([short, longer], query: "bram")
        XCTAssertEqual(without.first?.title, "Bramble", "ties favor the shorter title")
        let withLearning = rank([short, longer], query: "bram", learning: learning)
        XCTAssertEqual(withLearning.first?.title, "Brambles", "usage lifts the correct pair within the same group")
    }

    func testStableOrderingOnTies() {
        let first = rank([appResult("Zebra"), appResult("Amber")], query: "a")
        let second = rank([appResult("Zebra"), appResult("Amber")], query: "a")
        XCTAssertEqual(first.map(\.title), second.map(\.title))
    }
}