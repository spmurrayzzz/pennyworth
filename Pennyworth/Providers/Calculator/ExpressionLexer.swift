import Foundation

enum BinaryOp: String, Hashable, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case remainder = "%"
    case power = "^"

    var precedence: Int {
        switch self {
        case .add, .subtract: 1
        case .multiply, .divide, .remainder: 2
        case .power: 3
        }
    }
}

enum Token: Equatable, Sendable {
    case number(Double)
    case op(BinaryOp)
    case word(String)
    case leftParen
    case rightParen

    var isNumber: Bool {
        if case .number = self { return true }
        return false
    }

    var isOperator: Bool {
        if case .op = self { return true }
        return false
    }
}

enum ExpressionLexer {
    private static var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    private static func isDecimalSeparator(_ character: Character) -> Bool {
        if character == "." { return true }
        if character == "," && decimalSeparator == "," { return true }
        return false
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(text)
        var index = 0
        let count = characters.count

        while index < count {
            let character = characters[index]

            switch character {
            case " ", "\t", "\n", "\r":
                index += 1
                continue
            case "(":
                tokens.append(.leftParen)
                index += 1
                continue
            case ")":
                tokens.append(.rightParen)
                index += 1
                continue
            case "+", "−":
                tokens.append(.op(.add))
                index += 1
                continue
            case "-":
                tokens.append(.op(.subtract))
                index += 1
                continue
            case "*", "×":
                tokens.append(.op(.multiply))
                index += 1
                continue
            case "/", "÷":
                tokens.append(.op(.divide))
                index += 1
                continue
            case "%":
                tokens.append(.op(.remainder))
                index += 1
                continue
            case "^":
                tokens.append(.op(.power))
                index += 1
                continue
            default:
                break
            }

            if isDecimalSeparator(character) || character.isNumber {
                let (token, newIndex) = parseNumber(from: characters, from: index)
                tokens.append(token)
                index = newIndex
                continue
            }

            if character.isLetter || character == "_" {
                var word = ""
                while index < count {
                    let current = characters[index]
                    if current.isLetter || current.isNumber || current == "_" {
                        word.append(current)
                        index += 1
                    } else {
                        break
                    }
                }
                tokens.append(.word(word.lowercased()))
                continue
            }

            index += 1
        }
        return tokens
    }

    private static func parseNumber(from characters: [Character], from start: Int) -> (Token, Int) {
        var index = start
        let count = characters.count
        var integer = ""
        var fraction = ""
        var exponent = ""
        var hasSeparator = false

        while index < count, characters[index].isNumber {
            integer.append(characters[index])
            index += 1
        }

        if index < count, isDecimalSeparator(characters[index]),
            index + 1 < count, characters[index + 1].isNumber
        {
            hasSeparator = true
            index += 1
            while index < count, characters[index].isNumber {
                fraction.append(characters[index])
                index += 1
            }
        }

        if index < count, characters[index] == "e" || characters[index] == "E" {
            var probe = index + 1
            if probe < count, characters[probe] == "+" || characters[probe] == "-" {
                probe += 1
            }
            if probe < count, characters[probe].isNumber {
                while probe < count, characters[probe].isNumber {
                    exponent.append(characters[probe])
                    probe += 1
                }
                index = probe
            }
        }

        func value() -> Double {
            guard !integer.isEmpty else { return 0 }
            var decimalText = integer
            if hasSeparator {
                decimalText += "."
                decimalText += fraction.isEmpty ? "0" : fraction
            }
            if !exponent.isEmpty {
                decimalText += "e"
                decimalText += exponent
            }
            return Double(decimalText.components(separatedBy: CharacterSet(charactersIn: ",")).joined()) ?? 0
        }

        return (.number(value()), index)
    }
}

private extension Character {
    var isNumberValue: Bool { isNumber }
    var isSeparatorValue: Bool { self == "." }
}