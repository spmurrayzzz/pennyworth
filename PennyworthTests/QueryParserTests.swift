import XCTest
@testable import Pennyworth

final class QueryParserTests: XCTestCase {
    private var parser: QueryParser {
        QueryParser(webKeywords: ["g", "ddg", "wiki", "yt"])
    }

    func testEmptyQueryIsRecent() {
        let parsed = parser.parse("  ")
        XCTAssertEqual(parsed.mode, .recent)
    }

    func testForcedCalculatorPrefix() {
        let parsed = parser.parse("= 2 + 3")
        XCTAssertEqual(parsed.mode, .calculator)
        XCTAssertEqual(parsed.normalizedText, "2 + 3")
    }

    func testOpenKeyword() {
        XCTAssertEqual(parser.parse("open notes").mode, .fileOpen)
        XCTAssertEqual(parser.parse("open notes").searchTerms, ["notes"])
    }

    func testFindKeyword() {
        XCTAssertEqual(parser.parse("find receipt").mode, .fileFind)
    }

    func testKeywordOnlyMatchesAtTokenBoundary() {
        XCTAssertNotEqual(parser.parse("openly").mode, .fileOpen)
        XCTAssertNotEqual(parser.parse("opening").mode, .fileOpen)
    }

    func testWebKeyword() {
        let parsed = parser.parse("g swift concurrency")
        XCTAssertEqual(parsed.mode, .webSearch)
        XCTAssertEqual(parsed.keyword, "g")
        XCTAssertEqual(parsed.normalizedText, "swift concurrency")
    }

    func testWebKeywordReservedRejected() {
        let parsed = parser.parse("open youtube")
        XCTAssertEqual(parsed.mode, .fileOpen)
    }

    func testDirectURL() {
        XCTAssertEqual(parser.parse("https://example.com").mode, .url)
        XCTAssertEqual(parser.parse("example.com").mode, .url)
        XCTAssertEqual(parser.parse("http://localhost:8080/x").mode, .url)
    }

    func testNonURLTextIsSearch() {
        XCTAssertEqual(parser.parse("hello world foo").mode, .search)
        XCTAssertEqual(parser.parse("midnight sun").mode, .search)
    }

    func testImplicitCalculation() {
        XCTAssertEqual(parser.parse("2 + 2").mode, .calculator)
        XCTAssertEqual(parser.parse("10 km to mi").mode, .calculator)
        XCTAssertEqual(parser.parse("sqrt(144)").mode, .search, "function without number is not a calculation")
    }

    func testNormalizationCollapsesWhitespace() {
        XCTAssertEqual(TextNormalizer.normalize("  a\t b  "), "a b")
    }

    func testNormalizationFoldsDiacriticsAndCase() {
        XCTAssertEqual(TextNormalizer.normalize("CAFÉ "), "cafe")
        XCTAssertEqual(TextNormalizer.normalize("Été "), "ete")
    }

    func testReservedKeywords() {
        XCTAssertTrue(QueryKeyword.reserved.contains("open"))
        XCTAssertTrue(QueryKeyword.reserved.contains("find"))
        XCTAssertTrue(QueryKeyword.reserved.contains("="))
    }
}