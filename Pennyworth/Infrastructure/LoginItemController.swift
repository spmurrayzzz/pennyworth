import AppKit
import ServiceManagement

@MainActor
final class LoginItemController {
    static let shared = LoginItemController()

    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    var isRegistered: Bool {
        status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {}
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {}
        }
    }
}