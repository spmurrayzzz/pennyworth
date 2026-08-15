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
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Pennyworth")
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
}