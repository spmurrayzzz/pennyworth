import Foundation

struct RankingWeights: Equatable, Sendable {
    var lexical: Double
    var exactQueryAffinity: Double
    var globalUsage: Double
    var providerPrior: Double

    static let standard = RankingWeights(
        lexical: 0.68,
        exactQueryAffinity: 0.18,
        globalUsage: 0.09,
        providerPrior: 0.05
    )
}

struct CandidateKey: Hashable, Sendable {
    let providerID: String
    let candidateID: String
}

struct QueryCandidateKey: Hashable, Sendable {
    let providerID: String
    let candidateID: String
    let normalizedQuery: String
}

struct SelectionAggregate {
    let exactQueryAffinity: Double
    let globalUsage: Double
    let lastSelectedAt: Date?
}

struct SelectionLearning: Sendable {
    var exactQueryCounts: [QueryCandidateKey: Double] = [:]
    var globalUsageCounts: [CandidateKey: Double] = [:]
    var lastSelectedAt: [CandidateKey: Date] = [:]

    static let empty = SelectionLearning()

    func aggregate(for key: CandidateKey, query: String) -> SelectionAggregate {
        let exactKey = QueryCandidateKey(providerID: key.providerID, candidateID: key.candidateID, normalizedQuery: query)
        let effective = exactQueryCounts[exactKey] ?? 0
        let usage = globalUsageCounts[key] ?? 0
        return SelectionAggregate(
            exactQueryAffinity: min(1, log2(1 + effective) / 3),
            globalUsage: min(1, log2(1 + usage) / 5),
            lastSelectedAt: lastSelectedAt[key]
        )
    }
}

enum LearningNorm {
    static func queryAffinity(effectiveCount: Double) -> Double {
        min(1, log2(1 + effectiveCount) / 3)
    }

    static func globalUsage(effectiveCount: Double) -> Double {
        min(1, log2(1 + effectiveCount) / 5)
    }
}