import Foundation

enum ResultKind: String, Codable, Hashable, Sendable {
    case application
    case file
    case url
    case calculation
    case command
}

enum IconSource: Hashable, Sendable {
    case application(URL)
    case file(URL)
    case symbol(String)
}

struct SearchResult: Identifiable, Equatable, Sendable {
    var id: String { "\(providerID)|\(candidateID)" }

    let providerID: String
    let candidateID: String
    let entityKey: String
    let kind: ResultKind
    let title: String
    let subtitle: String
    let matchText: String
    let aliases: [String]
    let targetValue: String
    let icon: IconSource
    let accessoryText: String?

    let realized: Bool

    func mergeActions(with other: SearchResult, providerPriority: [String]) -> SearchResult {
        let lhsRank = providerPriority.firstIndex(of: providerID) ?? .max
        let rhsRank = providerPriority.firstIndex(of: other.providerID) ?? .max
        var winner = lhsRank <= rhsRank ? self : other
        let loser = lhsRank <= rhsRank ? other : self
        if winner.accessoryText == nil {
            winner = SearchResult(
                providerID: winner.providerID,
                candidateID: winner.candidateID,
                entityKey: winner.entityKey,
                kind: winner.kind,
                title: winner.title,
                subtitle: winner.subtitle,
                matchText: winner.matchText,
                aliases: winner.aliases,
                targetValue: winner.targetValue,
                icon: winner.icon,
                accessoryText: loser.accessoryText,
                realized: winner.realized
            )
        }
        return winner
    }

    func withRealized(_ flag: Bool) -> SearchResult {
        SearchResult(
            providerID: providerID,
            candidateID: candidateID,
            entityKey: entityKey,
            kind: kind,
            title: title,
            subtitle: subtitle,
            matchText: matchText,
            aliases: aliases,
            targetValue: targetValue,
            icon: icon,
            accessoryText: accessoryText,
            realized: flag
        )
    }
}