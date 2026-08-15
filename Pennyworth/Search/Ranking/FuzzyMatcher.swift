import Foundation

struct FuzzyMatcher {
    struct FuzzyResult: Equatable, Sendable {
        let score: Double
        let matched: Bool
        let exact: Bool
    }

    private static let matchScore = 12
    private static let boundaryScore = 14
    private static let firstScore = 14
    private static let consecutiveScore = 14
    private static let gapScore = 22

    static func nearlyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 1e-4) -> Bool {
        abs(lhs - rhs) < tolerance
    }

    private static let titleWeight = 1.0
    private static let aliasWeight = 0.6
    private static let pathWeight = 0.45

    static func match(queryTerms: [String], title: String, aliases: [String], path: String) -> FuzzyResult {
        guard !queryTerms.isEmpty else {
            return FuzzyResult(score: 0, matched: false, exact: false)
        }
        let normalizedTitle = TextNormalizer.normalize(title)
        let normalizedAliases = aliases.map(TextNormalizer.normalize)
        let normalizedPath = TextNormalizer.normalize(path)

        var normalizedScore = 1.0
        for term in queryTerms {
            let normalizedTerm = TextNormalizer.normalize(term)
            let termScore = bestTermScore(normalizedTerm, title: normalizedTitle, aliases: normalizedAliases, path: normalizedPath)
            if termScore < threshold(for: normalizedTerm) {
                return FuzzyResult(score: 0, matched: false, exact: false)
            }
            normalizedScore *= termScore
        }

        let exact = isExactQuery(queryTerms.map(TextNormalizer.normalize), title: normalizedTitle, aliases: normalizedAliases)
        return FuzzyResult(score: normalizedScore, matched: true, exact: exact)
    }

    private static func bestTermScore(_ term: String, title: String, aliases: [String], path: String) -> Double {
        var best = singleScore(term, target: title) * titleWeight
        for alias in aliases {
            best = max(best, singleScore(term, target: alias) * aliasWeight)
        }
        best = max(best, singleScore(term, target: path) * pathWeight)
        return min(max(best, 0), 1)
    }

    static func epsilonEquals(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.0001
    }

    static func singleScore(_ term: String, target: String) -> Double {
        guard !term.isEmpty, target.count >= term.count else { return 0 }
        let query = Array(term)
        let text = Array(target)
        let m = query.count
        let n = text.count
        let floor = Int.min / 4

        var previousRow = [Int](repeating: 0, count: n + 1)
        var newRow = [Int](repeating: floor, count: n + 1)

        var bestScore = floor
        var firstMatchPosition: Int?
        for i in 1...m {
            let queryChar = query[i - 1]
            var runningBest = floor
            let start = i
            for j in start...n {
                if previousRow[j - 1] > floor / 2 {
                    runningBest = max(runningBest, previousRow[j - 1])
                }
                if queryChar == text[j - 1] {
                    var bonus = 0
                    if j == 1 {
                        bonus += firstScore
                    } else if isWordBoundary(text, at: j - 1) {
                        bonus += boundaryScore
                    }
                    if i > 1, j > 1, query[i - 2] == text[j - 2] {
                        bonus += consecutiveScore
                    }
                    var best = floor
                    if previousRow[j - 1] > floor / 2 {
                        best = max(best, previousRow[j - 1])
                    }
                    if runningBest > floor / 2 {
                        best = max(best, runningBest - gapScore)
                    }
                    if best > floor / 2 {
                        newRow[j] = best + matchScore + bonus
                        if i == 1 && firstMatchPosition == nil {
                            firstMatchPosition = j - 1
                        }
                    }
                }
            }
            if i == m {
                for index in 0...n {
                    bestScore = max(bestScore, newRow[index])
                }
            }
            swap(&previousRow, &newRow)
            for index in 0..<newRow.count {
                newRow[index] = floor
            }
        }

        let maximum = Double(m) * Double(matchScore)
            + Double(firstScore)
            + Double(max(0, m - 1)) * Double(consecutiveScore)
        var normalized = Double(bestScore) / maximum
        if let firstMatchPosition {
            normalized -= Double(firstMatchPosition) * 0.01
        }
        let lengthPenalty = min(Double(max(0, n - m)) * 0.012, 0.1)
        normalized -= lengthPenalty
        return min(max(normalized, 0), 1)
    }

    private static func isWordBoundary(_ text: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = text[index - 1]
        return previous == " " || previous == "-" || previous == "_" || previous == "."
    }

    private static func threshold(for term: String) -> Double {
        let base = 0.28 + 0.04 * Double(max(0, term.count - 1))
        return min(max(base, 0.24), 0.5)
    }

    private static func isExactQuery(_ terms: [String], title: String, aliases: [String]) -> Bool {
        let joined = terms.joined(separator: " ")
        if title == joined { return true }
        return aliases.contains(joined)
    }
}