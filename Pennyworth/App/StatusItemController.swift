import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
        let dimension: CGFloat = 18
        let image = NSImage(size: NSSize(width: dimension, height: dimension))
        image.lockFocus()

        let background = NSBezierPath(
            roundedRect: NSRect(x: 0, y: 0, width: dimension, height: dimension),
            xRadius: 4.5,
            yRadius: 4.5
        )
        NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.92, alpha: 1).setFill()
        background.fill()

        NSColor.white.set()
        let centerX = dimension * 0.47
        let centerY = dimension * 0.58
        let radius = dimension * 0.21
        let circle = NSBezierPath(
            ovalIn: NSRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2)
        )
        circle.lineWidth = dimension * 0.07
        circle.stroke()

        let handle = NSBezierPath()
        handle.move(to: NSPoint(x: centerX - radius * 0.35, y: centerY - radius * 0.35))
        handle.line(to: NSPoint(x: centerX + radius * 0.75, y: centerY - radius * 0.95))
        handle.lineWidth = dimension * 0.1
        handle.lineCapStyle = .round
        handle.stroke()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}