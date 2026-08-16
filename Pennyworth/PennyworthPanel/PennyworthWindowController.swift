import AppKit
import QuickLookUI

@MainActor
final class PennyworthWindowController: NSWindowController, NSWindowDelegate {
    private let panel: PennyworthPanel
    private let pennyworthViewController: PennyworthViewController
    private var foregroundApplication: NSRunningApplication?

    init(content: PennyworthViewController) {
        self.pennyworthViewController = content
        let window = PennyworthPanel()
        window.contentViewController = content
        self.panel = window
        super.init(window: window)
        window.delegate = self
    }

    func setDismissHandler(_ handler: @escaping (Bool) -> Void) {
        pennyworthViewController.onRequestDismiss = handler
    }

    required init?(coder: NSCoder) {
        fatalError("unsupported")
    }

    var isShown: Bool {
        panel.isVisible
    }

    func show() {
        guard !isShown else { return }
        foregroundApplication = NSWorkspace.shared.frontmostApplication
        positionOnPointerScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        pennyworthViewController.beginNewQuery()
    }

    func hide(restoringForegroundApplication: Bool = true) {
        guard isShown else { return }
        panel.orderOut(nil)
        panel.resignKey()
        if restoringForegroundApplication {
            foregroundApplication?.activate(options: [.activateAllWindows])
        }
        foregroundApplication = nil
    }

    func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    private func positionOnPointerScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let frame = NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        if let panel = QLPreviewPanel.shared(), panel.isVisible, panel == NSApp.keyWindow {
            return
        }
        if panel.isVisible {
            hide(restoringForegroundApplication: false)
        }
    }
}