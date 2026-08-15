import Foundation

struct SelectionEvent: Codable, Equatable, Sendable {
    var providerID: String
    var candidateID: String
    var queryMode: String
    var normalizedQuery: String
    var actionID: String
    var selectedAt: Date
}