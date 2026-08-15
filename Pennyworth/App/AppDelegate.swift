import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appController = AppController()
        appController.activate()
        controller = appController

        if ProcessInfo.processInfo.environment["PENNYWORTH_SMOKE_PANEL"] == "1" {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                appController.togglePennyworth()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}