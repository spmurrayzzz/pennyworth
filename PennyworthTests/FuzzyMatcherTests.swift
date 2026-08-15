import XCTest
@testable import Pennyworth

final class FuzzyMatcherTests: XCTestCase {
    private func score(_ query: String, _ target: String) -> Double {
        FuzzyMatcher.singleScore(TextNormalizer.normalize(query), target: TextNormalizer.normalize(target))
    }

    func testExactMatchIsHighest() {
        XCTAssertEqual(score("terminal", "terminal"), 1.0, accuracy: 1e-6)
    }

    func testExactBeatsPrefix() {
        XCTAssertGreaterThan(score("terminal", "terminal"), score("term", "terminal"))
    }

    func testPrefixBeatsSubsequence() {
        XCTAssertGreaterThan(score("term", "terminal"), score("trmn", "terminal"))
    }

    func testConsecutiveBeatsGappy() {
        XCTAssertGreaterThan(score("alpha", "alphabet"), score("aepht", "alphabet"))
    }

    func testWordBoundaryBeatsMidword() {
        let docs = score("vs", "Visual Studio")
        let plain = score("vs", "vasudevan")
        XCTAssertGreaterThan(docs, plain)
    }

    func testUnmatchedCandidateRejected() {
        let result = FuzzyMatcher.match(queryTerms: ["xyz"], title: "Terminal", aliases: [], path: "/Applications/Terminal.app")
        XCTAssertFalse(result.matched)
    }

    func testHiddenPrefixReasonablyMatched() {
        XCTAssertGreaterThan(FuzzyMatcher.match(queryTerms: ["cal"], title: "Calculator", aliases: [], path: "/x").score, 0.5)
    }

    func testInitialLetters() {
        XCTAssertGreaterThan(score("vs", "Visual Studio"), score("vsd", "Visual Studio"))
    }

    func testAliasOnlyMatch() {
        let result = FuzzyMatcher.match(
            queryTerms: ["gcc"],
            title: "Terminal",
            aliases: ["gcc"],
            path: "/System/Library/Terminal.app"
        )
        XCTAssertTrue(result.matched)
    }

    func testExactFlag() {
        let result = FuzzyMatcher.match(queryTerms: ["find slider"], title: "find slider", aliases: [], path: "")
        XCTAssertTrue(result.exact)
    }
}