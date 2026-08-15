import XCTest
@testable import Pennyworth

final class URLPolicyTests: XCTestCase {
    func testBareHostRecognition() {
        XCTAssertTrue(URLPolicy.isBareAddress("example.com"))
        XCTAssertTrue(URLPolicy.isBareAddress("local.example"))
        XCTAssertTrue(URLPolicy.isBareAddress("localhost"))
        XCTAssertTrue(URLPolicy.isBareAddress("192.168.1.1"))
        XCTAssertFalse(URLPolicy.isBareAddress("3.14"))
        XCTAssertFalse(URLPolicy.isBareAddress("hello world"))
        XCTAssertFalse(URLPolicy.isBareAddress("document"))
    }

    func testDomainValidation() {
        XCTAssertTrue(URLPolicy.isValidHostname("foo.example.com"))
        XCTAssertTrue(URLPolicy.isValidHostname("xn--bcher-kva.example"))
        XCTAssertFalse(URLPolicy.isValidHostname("-bad.example"))
        XCTAssertFalse(URLPolicy.isValidHostname("bad-.example"))
        XCTAssertFalse(URLPolicy.isValidHostname("exa mple.com"))
    }

    func testFinalURLValidation() {
        XCTAssertNotNil(URLPolicy.finalURL(from: "https://example.com"))
        XCTAssertNotNil(URLPolicy.finalURL(from: "example.com"))
        XCTAssertNotNil(URLPolicy.finalURL(from: "http://localhost:8000"))
        XCTAssertNil(URLPolicy.finalURL(from: "ftp://example.com"))
        XCTAssertNil(URLPolicy.finalURL(from: "https://user:pass@example.com"))
        XCTAssertNil(URLPolicy.finalURL(from: "https://example.com:99999"))
        XCTAssertNil(URLPolicy.finalURL(from: "javascript:alert(1)"))
        XCTAssertNil(URLPolicy.finalURL(from: "https://"))
    }

    func testQuerySpaceIsSearchImplicit() {
        XCTAssertNil(URLPolicy.finalURL(from: "open two spaces"))
    }
}