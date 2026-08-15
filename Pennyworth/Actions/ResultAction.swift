import Foundation

enum ResultActionID: String, Hashable, Sendable, CaseIterable {
    case open
    case reveal
    case preview
    case copy
    case openWith
}

enum ActionCloseBehavior: Sendable {
    case close
    case keepOpen
}

struct AvailableAction: Identifiable, Hashable, Sendable {
    let id: ResultActionID
    let title: String
    let closeBehavior: ActionCloseBehavior
}

enum ActionCatalog {
    static func actions(for kind: ResultKind) -> [AvailableAction] {
        switch kind {
        case .application:
            return [
                AvailableAction(id: .open, title: "Open", closeBehavior: .close),
                AvailableAction(id: .reveal, title: "Reveal in Finder", closeBehavior: .close),
                AvailableAction(id: .copy, title: "Copy Path", closeBehavior: .close),
            ]
        case .command:
            return [
                AvailableAction(id: .open, title: "Open", closeBehavior: .close),
                AvailableAction(id: .reveal, title: "Reveal in Finder", closeBehavior: .close),
                AvailableAction(id: .copy, title: "Copy Path", closeBehavior: .close),
            ]
        case .file:
            return [
                AvailableAction(id: .open, title: "Open", closeBehavior: .close),
                AvailableAction(id: .preview, title: "Quick Look", closeBehavior: .keepOpen),
                AvailableAction(id: .reveal, title: "Reveal in Finder", closeBehavior: .close),
                AvailableAction(id: .openWith, title: "Open With…", closeBehavior: .keepOpen),
                AvailableAction(id: .copy, title: "Copy Path", closeBehavior: .close),
            ]
        case .url:
            return [
                AvailableAction(id: .open, title: "Open in Browser", closeBehavior: .close),
                AvailableAction(id: .copy, title: "Copy URL", closeBehavior: .close),
            ]
        case .calculation:
            return [
                AvailableAction(id: .open, title: "Copy Result", closeBehavior: .close),
            ]
        }
    }

    static func primaryAction(for kind: ResultKind) -> ResultActionID {
        switch kind {
        case .calculation: .open
        default: .open
        }
    }

    static func copiesOnCommandC(_ kind: ResultKind) -> Bool {
        true
    }
}