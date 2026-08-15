import Foundation

enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}

enum QueryKeyword {
    static let calculatorPrefix = "="
    static let fileOpen = "open"
    static let fileFind = "find"

    static let reserved: Set<String> = [calculatorPrefix, fileOpen, fileFind]
    static let reservedWebProhibited: Set<String> = [fileOpen, fileFind, calculatorPrefix]
}

struct QueryParser: Sendable {
    private let webKeywords: [String]

    init(webKeywords: [String] = []) {
        self.webKeywords = webKeywords
    }

    func parse(_ rawText: String) -> ParsedQuery {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = TextNormalizer.normalize(rawText)
        let terms = normalized.isEmpty ? [] : normalized.split(separator: " ").map(String.init)

        if trimmed.isEmpty {
            return ParsedQuery(rawText: rawText, normalizedText: "", mode: .recent, keyword: nil, searchTerms: [])
        }

        if normalized.hasPrefix(QueryKeyword.calculatorPrefix) {
            let expression = String(normalized.dropFirst(QueryKeyword.calculatorPrefix.count)).trimmingCharacters(in: .whitespaces)
            return ParsedQuery(rawText: rawText, normalizedText: expression, mode: .calculator, keyword: nil, searchTerms: [expression])
        }

        if let first = terms.first {
            if first == QueryKeyword.fileOpen {
                let rest = terms.dropFirst().joined(separator: " ")
                return ParsedQuery(
                    rawText: rawText, normalizedText: rest, mode: .fileOpen,
                    keyword: first, searchTerms: Array(terms.dropFirst())
                )
            }
            if first == QueryKeyword.fileFind {
                let rest = terms.dropFirst().joined(separator: " ")
                return ParsedQuery(
                    rawText: rawText, normalizedText: rest, mode: .fileFind,
                    keyword: first, searchTerms: Array(terms.dropFirst())
                )
            }
            if webKeywords.contains(first) {
                return ParsedQuery(
                    rawText: rawText, normalizedText: terms.dropFirst().joined(separator: " "),
                    mode: .webSearch, keyword: first, searchTerms: Array(terms.dropFirst())
                )
            }
        }

        let isExplicitScheme = normalized.hasPrefix("http://") || normalized.hasPrefix("https://")
        if isExplicitScheme {
            if URLPolicy.finalURL(from: rawText) != nil {
                return ParsedQuery(rawText: rawText, normalizedText: normalized, mode: .url, keyword: nil, searchTerms: [normalized])
            }
        } else if terms.count == 1, URLPolicy.isBareAddress(normalized) {
            return ParsedQuery(rawText: rawText, normalizedText: normalized, mode: .url, keyword: nil, searchTerms: [normalized])
        }

        if CalculatorRecognizer.isImplicitCalculation(normalized) {
            return ParsedQuery(rawText: rawText, normalizedText: normalized, mode: .calculator, keyword: nil, searchTerms: [normalized])
        }

        return ParsedQuery(rawText: rawText, normalizedText: normalized, mode: .search, keyword: nil, searchTerms: terms)
    }
}