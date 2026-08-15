import Foundation

enum ProviderID {
    static let application = "application"
    static let file = "file"
    static let web = "web"
    static let calculator = "calculator"
    static let command = "command"
    static let recent = "recent"
}

enum RankingEngine {
    static let providerPriors: [String: Double] = [
        ProviderID.application: 1.0,
        ProviderID.command: 0.9,
        ProviderID.web: 0.8,
        ProviderID.calculator: 0.7,
        ProviderID.file: 0.6,
    ]

    private struct Working {
        let result: SearchResult
        let fuzzy: FuzzyMatcher.FuzzyResult
        let finalScore: Double
        let group: Int
    }

    static func rank(
        candidates: [SearchResult],
        query: ParsedQuery,
        learning: SelectionLearning,
        weights: RankingWeights = .standard,
        providerPriors: [String: Double] = RankingEngine.providerPriors,
        limit: Int,
        now: Date = Date()
    ) -> [SearchResult] {
        guard !candidates.isEmpty else { return [] }

        var byEntity: [String: Working] = [:]
        var insertionOrder: [String] = []

        for candidate in candidates {
            let fuzzy = computeFuzzy(candidate: candidate, query: query)
            guard fuzzy.matched else { continue }
            let aggregate = learning.aggregate(
                for: CandidateKey(providerID: candidate.providerID, candidateID: candidate.candidateID),
                query: query.normalizedText
            )
            let prior = providerPriors[candidate.providerID] ?? 0.5
            let finalScore = weights.lexical * fuzzy.score
                + weights.exactQueryAffinity * aggregate.exactQueryAffinity
                + weights.globalUsage * aggregate.globalUsage
                + weights.providerPrior * prior
            let group = fuzzy.exact ? 2 : 1
            let candidateWorking = Working(result: candidate, fuzzy: fuzzy, finalScore: finalScore, group: group)

            if let existing = byEntity[candidate.entityKey] {
                let priorityOrder = Array(providerPriors.keys)
                let winner = existing.finalScore >= finalScore ? existing : candidateWorking
                let mergedResult = winner.result.mergeActions(with: candidate, providerPriority: priorityOrder)
                byEntity[candidate.entityKey] = Working(
                    result: mergedResult,
                    fuzzy: winner.fuzzy,
                    finalScore: max(existing.finalScore, finalScore),
                    group: winner.group
                )
            } else {
                byEntity[candidate.entityKey] = candidateWorking
                insertionOrder.append(candidate.entityKey)
            }
        }

        let sorted = byEntity.values.sorted { lhs, rhs in
            compare(lhs, rhs, learning: learning)
        }
        return sorted.prefix(limit).map { $0.result }
    }

    private static func computeFuzzy(candidate: SearchResult, query: ParsedQuery) -> FuzzyMatcher.FuzzyResult {
        FuzzyMatcher.match(
            queryTerms: query.searchTerms,
            title: candidate.title,
            aliases: candidate.aliases,
            path: candidate.matchText
        )
    }

    private static func compare(_ lhs: Working, _ rhs: Working, learning: SelectionLearning) -> Bool {
        if lhs.group != rhs.group { return lhs.group > rhs.group }
        if !FuzzyMatcher.nearlyEqual(lhs.finalScore, rhs.finalScore) {
            return lhs.finalScore > rhs.finalScore
        }
        if !FuzzyMatcher.nearlyEqual(lhs.fuzzy.score, rhs.fuzzy.score) {
            return lhs.fuzzy.score > rhs.fuzzy.score
        }
        let lhsKey = CandidateKey(providerID: lhs.result.providerID, candidateID: lhs.result.candidateID)
        let rhsKey = CandidateKey(providerID: rhs.result.providerID, candidateID: rhs.result.candidateID)
        let lhsDate = learning.lastSelectedAt[lhsKey]
        let rhsDate = learning.lastSelectedAt[rhsKey]
        if let lhsDate, let rhsDate, lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        if lhs.result.title.count != rhs.result.title.count {
            return lhs.result.title.count < rhs.result.title.count
        }
        let titleOrder = lhs.result.title.localizedCompare(rhs.result.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }
        if lhs.result.providerID != rhs.result.providerID {
            return lhs.result.providerID < rhs.result.providerID
        }
        return lhs.result.candidateID < rhs.result.candidateID
    }
}