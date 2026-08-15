import XCTest
@testable import Pennyworth

final class CalculatorTests: XCTestCase {
    func testPrecedence() {
        let result = ExpressionParser.parse("2 + 3 * 2")
        XCTAssertEqual(try result.get(), .arithmetic(8))
    }

    func testRightAssociativePower() {
        let result = ExpressionParser.parse("2^3^2")
        XCTAssertEqual(try result.get(), .arithmetic(512))
    }

    func testUnaryMinusBindsLooserThanPower() {
        let result = ExpressionParser.parse("-2^2")
        XCTAssertEqual(try result.get(), .arithmetic(-4))
    }

    func testParentheses() {
        XCTAssertEqual(try ExpressionParser.parse("(2 + 3) * 2").get(), .arithmetic(10))
    }

    func testRemainder() {
        XCTAssertEqual(try ExpressionParser.parse("17 % 5").get(), .arithmetic(2))
    }

    func testConstants() {
        XCTAssertEqual(try ExpressionParser.parse("pi").get(), .arithmetic(Double.pi))
    }

    func testFunctions() {
        XCTAssertEqual(try ExpressionParser.parse("sqrt(144)").get(), .arithmetic(12))
        XCTAssertEqual(try ExpressionParser.parse("abs(-5)").get(), .arithmetic(5))
        XCTAssertEqual(try ExpressionParser.parse("sin(0)").get(), .arithmetic(0))
        XCTAssertEqual(try ExpressionParser.parse("log(100)").get(), .arithmetic(2))
        XCTAssertEqual(try ExpressionParser.parse("ln(1)").get(), .arithmetic(0))
    }

    func testDivisionByZeroIsNotFinite() {
        guard let calc = try? ExpressionParser.parse("1 / 0").get(), case .arithmetic(let value) = calc else {
            XCTFail("expected arithmetic")
            return
        }
        XCTAssertFalse(value.isFinite)
    }

    func testLengthConversion() throws {
        let result = try ExpressionParser.parse("10 km to mi").get()
        guard case .conversion(_, let sourceUnit, _, let target, _, _) = result else {
            XCTFail("expected conversion")
            return
        }
        XCTAssertEqual(sourceUnit, "km")
        XCTAssertEqual(target, 6.2137, accuracy: 0.01)
    }

    func testTemperatureConversion() throws {
        let result = try ExpressionParser.parse("72 f to c").get()
        guard case .conversion(_, _, _, let target, _, _) = result else {
            XCTFail("expected conversion")
            return
        }
        XCTAssertEqual(target, 22.222, accuracy: 0.01)
    }

    func testVolumeConversion() throws {
        let result = try ExpressionParser.parse("1 gal to l").get()
        guard case .conversion(let source, _, _, let target, _, _) = result else {
            XCTFail("expected conversion")
            return
        }
        XCTAssertEqual(source, 1)
        XCTAssertEqual(target, 3.78541, accuracy: 0.001)
    }

    func testCurrencyPrefixIgnored() {
        XCTAssertEqual(try ExpressionParser.parse("$10 + $5").get(), .arithmetic(15))
    }

    func testUnknownFunctionFails() {
        XCTAssertTrue(ExpressionParser.parse("foo(3)").isFailure)
    }

    func testConversionWithInKeyword() {
        let result = ExpressionParser.parse("10 km in mi")
        XCTAssertTrue(result.isConversion)
    }

    func testFormatter() {
        XCTAssertEqual(CalculationFormatter.format(42.0), "42")
        XCTAssertEqual(CalculationFormatter.format(0.5), "0.5")
        XCTAssertEqual(CalculationFormatter.format(3.14), "3.14")
    }
}

private extension Result<Calculation, ExpressionParser.ParseError> {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }

    var isConversion: Bool {
        if case .success(.conversion) = self { return true }
        return false
    }
}