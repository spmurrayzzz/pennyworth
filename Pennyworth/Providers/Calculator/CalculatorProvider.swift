import AppKit
import Foundation

enum CalculatorRecognizer {
    static func isImplicitCalculation(_ normalized: String) -> Bool {
        guard !normalized.isEmpty else { return false }
        let cleaned = stripCurrencyPrefix(normalized)
        let tokens = ExpressionLexer.tokenize(cleaned)
        guard tokens.contains(where: { $0.isNumber }) else { return false }
        if tokens.contains(where: { $0.isOperator }) {
            return true
        }
        if ExpressionParser.tryConvert(cleaned) != nil {
            return true
        }
        return false
    }

    static func stripCurrencyPrefix(_ text: String) -> String {
        guard let first = text.first else { return text }
        if first.isLetter || first.isNumber || first == "." || first == "-" || first == "+" || first == "(" || first == "−" {
            return text
        }
        return String(text.dropFirst())
    }
}

@MainActor
final class CalculatorProvider: SearchProvider {
    var providerID: String {
        ProviderID.calculator
    }

    func supports(mode: QueryMode) -> Bool {
        mode == .calculator
    }

    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        let expression = CalculatorRecognizer.stripCurrencyPrefix(parsed.normalizedText)
        guard !expression.isEmpty else { return [] }

        let parsedCalculation = ExpressionParser.parse(expression)
        let result = makeResult(from: parsedCalculation, expression: expression)
        return [result]
    }

    private func makeResult(from calculation: Result<Calculation, ExpressionParser.ParseError>, expression: String) -> SearchResult {
        switch calculation {
        case .success(let value):
            switch value {
            case .arithmetic(let numeric):
                guard numeric.isFinite else {
                    return errorResult(expression: expression, message: "Division by zero or a non-finite result.")
                }
                let formatted = CalculationFormatter.format(numeric)
                return SearchResult(
                    providerID: "calculator",
                    candidateID: formatted,
                    entityKey: "calculation",
                    kind: .calculation,
                    title: formatted,
                    subtitle: "\(expression) =",
                    matchText: formatted,
                    aliases: [],
                    targetValue: formatted,
                    icon: .symbol("function"),
                    accessoryText: formatted,
                    realized: true
                )
            case .conversion(let source, let sourceUnit, let sourceSymbol, let target, let targetUnit, let targetSymbol):
                let formattedSource = CalculationFormatter.format(source) + " " + sourceSymbol
                let formattedTarget = CalculationFormatter.format(target) + " " + targetSymbol
                return SearchResult(
                    providerID: "calculator",
                    candidateID: "conversion:\(sourceUnit):\(targetUnit)",
                    entityKey: "conversion",
                    kind: .calculation,
                    title: "\(formattedSource) = \(formattedTarget)",
                    subtitle: "\(source) \(sourceUnit) -> \(target) \(targetUnit)",
                    matchText: formattedTarget,
                    aliases: [],
                    targetValue: formattedTarget,
                    icon: .symbol("arrow.triangle.2.circlepath"),
                    accessoryText: nil,
                    realized: true
                )
            }
        case .failure(.unknownUnit):
            return errorResult(expression: expression, message: "Unsupported units in this conversion.")
        case .failure(let error):
            return errorResult(expression: expression, message: errorMessage(error))
        }
    }

    private func errorResult(expression: String, message: String) -> SearchResult {
        SearchResult(
            providerID: "calculator",
            candidateID: "error",
            entityKey: "calculator-error",
            kind: .calculation,
            title: "Error",
            subtitle: message,
            matchText: "",
            aliases: [],
            targetValue: "",
            icon: .symbol("exclamationmark.triangle"),
            accessoryText: nil,
            realized: true
        )
    }

    private func errorMessage(_ error: ExpressionParser.ParseError) -> String {
        switch error {
        case .unknownFunction: "Unknown function or unit."
        case .unexpectedToken, .unexpectedEnd: "The expression could not be parsed."
        case .tooDeep: "The expression is too complex."
        default: "The expression could not be evaluated."
        }
    }
}

enum CalculationFormatter {
    static func format(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e14 {
            return String(format: "%.0f", value.rounded())
        }
        if abs(value) >= 1e12 || (abs(value) < 1e-6 && value != 0) {
            return String(format: "%.6e", value)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}