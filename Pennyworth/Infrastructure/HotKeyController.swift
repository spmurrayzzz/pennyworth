import AppKit
@preconcurrency import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePennyworth = Self("togglePennyworth", default: KeyboardShortcuts.Shortcut(KeyboardShortcuts.Key.space, modifiers: [.option]))
}

@MainActor
final class HotKeyController {
    private var onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        KeyboardShortcuts.onKeyUp(for: .togglePennyworth) { [weak self] in
            self?.onToggle()
        }
    }
}