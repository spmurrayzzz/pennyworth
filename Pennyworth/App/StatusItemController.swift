import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var loginMenuItem: NSMenuItem?

    private var onOpenPennyworth: () -> Void
    private var onOpenSettings: () -> Void
    private var onQuit: () -> Void

    init(onOpenPennyworth: @escaping () -> Void, onOpenSettings: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onOpenPennyworth = onOpenPennyworth
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        super.init()
        configure()
    }

    func setOpenHandlers(onOpenPennyworth: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onOpenPennyworth = onOpenPennyworth
        self.onOpenSettings = onOpenSettings
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = Self.makeStatusIcon()
        }

        menu.delegate = self

        let openItem = NSMenuItem(title: "Open Pennyworth", action: #selector(openPennyworth), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LoginItemController.shared.isRegistered ? .on : .off
        loginMenuItem = launchItem
        menu.addItem(launchItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Pennyworth", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openPennyworth() {
        onOpenPennyworth()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func quit() {
        onQuit()
    }

    @objc private func toggleLaunchAtLogin() {
        let wantsEnabled = (loginMenuItem?.state != .on)
        LoginItemController.shared.setEnabled(wantsEnabled)
        loginMenuItem?.state = wantsEnabled ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginMenuItem?.state = LoginItemController.shared.isRegistered ? .on : .off
    }

    private static func makeStatusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let path = NSBezierPath()
            path.windingRule = .evenOdd
            path.move(to: NSPoint(x: 7, y: 16.5))
            path.line(to: NSPoint(x: 11, y: 16.5))
            path.line(to: NSPoint(x: 11.8, y: 13.8))
            path.line(to: NSPoint(x: 10.2, y: 11.2))
            path.line(to: NSPoint(x: 12.8, y: 3.8))
            path.line(to: NSPoint(x: 9, y: 0.7))
            path.line(to: NSPoint(x: 5.2, y: 3.8))
            path.line(to: NSPoint(x: 7.8, y: 11.2))
            path.line(to: NSPoint(x: 6.2, y: 13.8))
            path.close()
            path.move(to: NSPoint(x: 6.6, y: 7.3))
            path.line(to: NSPoint(x: 11.7, y: 5.75))
            path.line(to: NSPoint(x: 12.1, y: 4.5))
            path.line(to: NSPoint(x: 6.15, y: 6.25))
            path.close()
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
