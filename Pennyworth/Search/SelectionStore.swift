import Foundation

@MainActor
final class SelectionStore {
    private let database: DatabaseStore
    private var events: [SelectionEvent] = []

    init(database: DatabaseStore) {
        self.database = database
    }

    var learning: SelectionLearning {
        buildLearning(events: events, now: Date())
    }

    func load() async {
        events = await database.loadSelectionEvents()
        pruneIfDue()
    }

    func record(_ event: SelectionEvent) {
        events.append(event)
        let stored = event
        Task { await database.insertSelectionEvent(stored) }
    }

    func reset() {
        events.removeAll()
        Task { await database.resetLearnedRanking() }
    }

    private func pruneIfDue() {
        let key = "lastSelectionPrune"
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: key) as? Date,
            Calendar.current.isDate(last, inSameDayAs: Date())
        {
            return
        }
        defaults.set(Date(), forKey: key)
        let now = Date()
        events = events.filter { event in
            now.timeIntervalSince(event.selectedAt) <= 28 * 24 * 3600
        }
        Task { await database.pruneSelections(now: Date()) }
    }

    private func buildLearning(events: [SelectionEvent], now: Date) -> SelectionLearning {
        var learning = SelectionLearning()
        for event in events {
            let age = now.timeIntervalSince(event.selectedAt) / 86400
            guard age >= 0, age <= 28 else { continue }
            let key = CandidateKey(providerID: event.providerID, candidateID: event.candidateID)
            if !event.normalizedQuery.isEmpty, event.queryMode != QueryMode.recent.rawValue {
                let queryKey = QueryCandidateKey(
                    providerID: event.providerID,
                    candidateID: event.candidateID,
                    normalizedQuery: event.normalizedQuery
                )
                learning.exactQueryCounts[queryKey, default: 0] += exp(-age / 28)
            }
            learning.globalUsageCounts[key, default: 0] += exp(-age / 14)
            if let previous = learning.lastSelectedAt[key], previous > event.selectedAt {
                continue
            }
            learning.lastSelectedAt[key] = event.selectedAt
        }
        return learning
    }
}