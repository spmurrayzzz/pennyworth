import XCTest
@testable import Pennyworth

final class TemplateURLTests: XCTestCase {
    func testValidTemplatesPass() throws {
        XCTAssertNoThrow(try TemplateURLGenerator.validate(template: "https://google.com/search?q={query}"))
        XCTAssertNoThrow(try TemplateURLGenerator.validate(template: "https://example.com/"))
    }

    func testHTTPRequiresExplicitAllowance() {
        XCTAssertThrowsError(try TemplateURLGenerator.validate(template: "http://example.com/"))
        XCTAssertNoThrow(try TemplateURLGenerator.validate(template: "http://example.com/", allowHTTP: true))
    }

    func testMultiplePlaceholdersRejected() {
        XCTAssertThrowsError(try TemplateURLGenerator.validate(template: "https://x.com/{query}?a={query}"))
    }

    func testPlaceholderInHostRejected() {
        XCTAssertThrowsError(try TemplateURLGenerator.validate(template: "https://{query}.example.com/"))
    }

    func testSchemePlaceholderRejected() {
        XCTAssertThrowsError(try TemplateURLGenerator.validate(template: "{query}://example.com/"))
    }

    func testCredentialsRejected() {
        XCTAssertThrowsError(try TemplateURLGenerator.validate(template: "https://{query}@example.com/"))
    }

    func testGenerateGoogle() throws {
        let url = try XCTUnwrap(TemplateURLGenerator.generateURL(template: "https://www.google.com/search?q={query}", query: "swift pennyworth"))
        XCTAssertEqual(url.absoluteString, "https://www.google.com/search?q=swift%20pennyworth")
    }

    func testGeneratePathPlaceholder() throws {
        let url = try XCTUnwrap(TemplateURLGenerator.generateURL(template: "https://example.com/wiki/{query}", query: "macOS 26"))
        XCTAssertEqual(url.absoluteString, "https://example.com/wiki/macOS%2026")
    }

    func testGeneratedURLFinalValidation() {
        XCTAssertNil(TemplateURLGenerator.generateURL(template: "ftp://{query}.example.com", query: "x"))
    }

    func testFragmentPlaceholder() throws {
        let url = try XCTUnwrap(TemplateURLGenerator.generateURL(template: "https://example.com/app#{query}", query: "home"))
        XCTAssertEqual(url.absoluteString, "https://example.com/app#home")
    }
}