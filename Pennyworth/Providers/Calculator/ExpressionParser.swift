import Foundation

enum Calculation: Equatable, Sendable {
    case arithmetic(Double)
    case conversion(source: Double, sourceUnit: String, sourceSymbol: String, target: Double, targetUnit: String, targetSymbol: String)
}

enum ExpressionParser {
    enum ParseError: Error {
        case unexpectedEnd
        case unexpectedToken
        case unknownFunction(String)
        case unknownUnit(String)
        case notRecognized
        case tooDeep
    }

    static let constants: Set<String> = ["pi", "e", "tau"]
    static let functions: Set<String> = ["sqrt", "abs", "sin", "cos", "tan", "log", "ln", "asin", "acos", "atan", "exp", "round", "floor", "ceil"]
    static let conversionKeywords: Set<String> = ["to", "in", "as", "into"]

    static func isConstant(_ word: String) -> Bool { constants.contains(word) }
    static func isFunction(_ word: String) -> Bool { functions.contains(word) }

    static func parse(_ text: String) -> Result<Calculation, ParseError> {
        if let conversion = tryConvert(text) {
            return .success(conversion)
        }
        let tokens = ExpressionLexer.tokenize(text)
        guard !tokens.isEmpty else { return .failure(.notRecognized) }

        do {
            var reader = TokenReader(tokens: tokens)
            let node = try parseExpression(&reader, maxDepth: 32)
            guard reader.isAtEnd else { return .failure(.unexpectedToken) }
            let value = evaluate(node)
            return .success(.arithmetic(value))
        } catch let error as ParseError {
            return .failure(error)
        } catch {
            return .failure(.notRecognized)
        }
    }

    static func tryConvert(_ text: String) -> Calculation? {
        let tokens = ExpressionLexer.tokenize(text)
        guard tokens.count >= 4 && tokens.count <= 5 else { return nil }

        var numbers: [Double] = []
        var words: [String] = []
        for token in tokens {
            switch token {
            case .number(let value): numbers.append(value)
            case .word(let word): words.append(word)
            case .op(.subtract):
                guard numbers.count == 1 else { return nil }
            case .op: return nil
            default: return nil
            }
        }
        guard numbers.count == 1, words.count >= 2 else { return nil }
        let source = numbers[0]
        let separatorIndex = words.firstIndex { conversionKeywords.contains($0) }
        guard let separatorIndex, separatorIndex > 0, separatorIndex < words.count - 1 else { return nil }
        let sourceUnitWord = words[separatorIndex - 1]
        let targetUnitWord = words[separatorIndex + 1]
        guard let sourceUnit = UnitConverter.unit(forAlias: sourceUnitWord),
              let targetUnit = UnitConverter.unit(forAlias: targetUnitWord)
        else { return nil }
        let measurement = Measurement(value: source, unit: sourceUnit)
        let converted = measurement.converted(to: targetUnit)
        return .conversion(
            source: source,
            sourceUnit: sourceUnitWord,
            sourceSymbol: sourceUnit.symbol,
            target: converted.value,
            targetUnit: targetUnitWord,
            targetSymbol: targetUnit.symbol
        )
    }

    private static func evaluate(_ node: ExprNode) -> Double {
        switch node {
        case .number(let value):
            return value
        case .constant(let name):
            switch name {
            case "pi": return Double.pi
            case "tau": return Double.pi * 2
            case "e": return M_E
            default: return 0
            }
        case .unary(.subtract, let child):
            return -evaluate(child)
        case .unary(_, let child):
            return evaluate(child)
        case .binary(let op, let lhs, let rhs):
            let left = evaluate(lhs)
            let right = evaluate(rhs)
            switch op {
            case .add: return left + right
            case .subtract: return left - right
            case .multiply: return left * right
            case .divide:
                guard right != 0 else { return .nan }
                return left / right
            case .remainder:
                guard right != 0 else { return .nan }
                return left.truncatingRemainder(dividingBy: right)
            case .power: return pow(left, right)
            }
        case .function(let name, let argument):
            let value = evaluate(argument)
            switch name {
            case "sqrt": return value < 0 ? Double.nan : value.squareRoot()
            case "abs": return abs(value)
            case "sin": return sin(value)
            case "cos": return cos(value)
            case "tan": return tan(value)
            case "asin": return asin(value)
            case "acos": return acos(value)
            case "atan": return atan(value)
            case "log": return log10(value)
            case "ln": return log(value)
            case "exp": return exp(value)
            case "round": return value.rounded()
            case "floor": return value.rounded(.down)
            case "ceil": return value.rounded(.up)
            default: return Double.nan
            }
        }
    }
}

private indirect enum ExprNode {
    case number(Double)
    case constant(String)
    case unary(BinaryOp, ExprNode)
    case binary(BinaryOp, ExprNode, ExprNode)
    case function(String, ExprNode)
}

private struct TokenReader {
    let tokens: [Token]
    var index = 0

    var isAtEnd: Bool { index >= tokens.count }
    var current: Token { index < tokens.count ? tokens[index] : .rightParen }

    @discardableResult
    mutating func pop() -> Token {
        defer { index += 1 }
        return current
    }

    func peekOperator() -> BinaryOp? {
        guard !isAtEnd, case .op(let op) = current else { return nil }
        return op
    }
}

private func parseExpression(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    guard maxDepth > 0 else { throw ExpressionParser.ParseError.tooDeep }
    return try parseSum(&reader, maxDepth: maxDepth)
}

private func parseSum(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    var left = try parseProduct(&reader, maxDepth: maxDepth)
    while let op = reader.peekOperator(), op == .add || op == .subtract {
        reader.pop()
        let right = try parseProduct(&reader, maxDepth: maxDepth)
        left = .binary(op, left, right)
    }
    return left
}

private func parseProduct(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    var left = try parseUnary(&reader, maxDepth: maxDepth)
    while let op = reader.peekOperator(), op == .multiply || op == .divide || op == .remainder {
        reader.pop()
        let right = try parseUnary(&reader, maxDepth: maxDepth)
        left = .binary(op, left, right)
    }
    return left
}

private func parseUnary(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    if let op = reader.peekOperator(), op == .subtract || op == .add {
        reader.pop()
        let operand = try parseUnary(&reader, maxDepth: maxDepth)
        if op == .subtract {
            return .unary(.subtract, operand)
        }
        return operand
    }
    return try parsePower(&reader, maxDepth: maxDepth)
}

private func parsePower(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    let base = try parsePrimary(&reader, maxDepth: maxDepth)
    if reader.peekOperator() == .power {
        reader.pop()
        let exponent = try parseUnary(&reader, maxDepth: maxDepth)
        return .binary(.power, base, exponent)
    }
    return base
}

private func parsePrimary(_ reader: inout TokenReader, maxDepth: Int) throws -> ExprNode {
    switch reader.current {
    case .number(let value):
        reader.pop()
        return .number(value)
    case .leftParen:
        reader.pop()
        let expression = try parseExpression(&reader, maxDepth: maxDepth - 1)
        guard reader.current == .rightParen else {
            throw ExpressionParser.ParseError.unexpectedToken
        }
        reader.pop()
        return expression
    case .word(let word):
        if reader.index + 1 < reader.tokens.count, reader.tokens[reader.index + 1] == .leftParen {
            guard ExpressionParser.isFunction(word) else {
                throw ExpressionParser.ParseError.unknownFunction(word)
            }
            reader.pop()
            reader.pop()
            let argument = try parseExpression(&reader, maxDepth: maxDepth - 1)
            guard reader.current == .rightParen else {
                throw ExpressionParser.ParseError.unexpectedToken
            }
            reader.pop()
            return .function(word, argument)
        }
        if ExpressionParser.isConstant(word) {
            reader.pop()
            return .constant(word)
        }
        throw ExpressionParser.ParseError.unknownFunction(word)
    case .op:
        throw ExpressionParser.ParseError.unexpectedToken
    case .rightParen:
        throw ExpressionParser.ParseError.unexpectedToken
    }
}