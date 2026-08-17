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
        content.onResultsVisibilityChange = { [weak self] visible in
            self?.resizeForResults(visible)
        }
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
        pennyworthViewController.beginNewQuery()
        positionOnPointerScreen()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
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

    private func resizeForResults(_ visible: Bool) {
        let height: CGFloat = visible ? 372 : 86
        let currentFrame = panel.frame
        guard currentFrame.height != height else { return }
        let frame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - height,
            width: currentFrame.width,
            height: height
        )
        panel.setFrame(frame, display: true)
    }

    private func positionOnPointerScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        let topInset = visible.height * 0.14
        let frame = NSRect(
            x: visible.midX - size.width / 2,
            y: visible.maxY - topInset - size.height,
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