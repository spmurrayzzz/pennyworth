import Foundation

struct SystemCommand: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let detail: String
    let bundleURL: URL
    let bundleIdentifier: String
    let aliases: [String]

    var entityKey: String {
        bundleIdentifier
    }
}

@MainActor
final class CommandProvider: SearchProvider {
    static let supportedSpecs: [CommandSpec] = [
        CommandSpec(
            id: "system-settings",
            title: "System Settings",
            detail: "Open System Settings",
            path: "/System/Applications/System Settings.app",
            aliases: ["open system settings", "settings", "preferences"],
            fallbackBundleID: "com.apple.systempreferences"
        ),
        CommandSpec(
            id: "activity-monitor",
            title: "Activity Monitor",
            detail: "Open Activity Monitor",
            path: "/System/Applications/Utilities/Activity Monitor.app",
            aliases: ["open activity monitor", "activity monitor"],
            fallbackBundleID: "com.apple.ActivityMonitor"
        ),
        CommandSpec(
            id: "start-screen-saver",
            title: "Start Screen Saver",
            detail: "Start the screen saver",
            path: "/System/Library/CoreServices/ScreenSaverEngine.app",
            aliases: ["start screen saver", "screen saver", "screen saver engine"],
            fallbackBundleID: "com.apple.screensaver"
        ),
    ]

    private var commands: [SystemCommand] = []

    var catalog: [SystemCommand] {
        commands
    }

    func refreshAvailability() {
        var refreshed: [SystemCommand] = []
        for spec in Self.supportedSpecs {
            let url = URL(fileURLWithPath: spec.path)
            guard FileManager.default.fileExists(atPath: spec.path) else { continue }
            let bundleID: String
            if let plist = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")),
                let identifier = plist["CFBundleIdentifier"] as? String
            {
                bundleID = identifier
            } else {
                bundleID = spec.fallbackBundleID
            }
            refreshed.append(SystemCommand(
                id: spec.id,
                title: spec.title,
                detail: spec.detail,
                bundleURL: url.standardizedFileURL,
                bundleIdentifier: bundleID,
                aliases: spec.aliases
            ))
        }
        commands = refreshed
    }

    var providerID: String {
        ProviderID.command
    }

    func supports(mode: QueryMode) -> Bool {
        mode == .search || mode == .recent
    }

    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        guard parsed.mode == .search else { return [] }
        if parsed.searchTerms.isEmpty { return [] }
        return commands.map { command in
            makeCommandResult(command)
        }
    }

    func makeCommandResult(_ command: SystemCommand) -> SearchResult {
        SearchResult(
            providerID: ProviderID.command,
            candidateID: "\(command.id)|\(command.bundleIdentifier)",
            entityKey: command.entityKey,
            kind: .command,
            title: command.title,
            subtitle: command.detail,
            matchText: [command.title, command.detail].joined(separator: " "),
            aliases: command.aliases,
            targetValue: command.bundleURL.path,
            icon: .application(command.bundleURL),
            accessoryText: nil,
            realized: true
        )
    }
}

struct CommandSpec {
    let id: String
    let title: String
    let detail: String
    let path: String
    let aliases: [String]
    let fallbackBundleID: String
}