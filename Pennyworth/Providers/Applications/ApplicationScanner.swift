import AppKit
import Foundation

struct ApplicationRecord: Identifiable, Sendable, Equatable {
    let bundleURL: URL
    let bundleIdentifier: String
    let displayName: String
    let bundleName: String
    let version: String?
    let modificationDate: Date?
    let aliases: [String]

    var id: String { bundleIdentifier }
}

@MainActor
enum ApplicationScanner {
    static let standardRoots: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }()

    static func scanStandardRoots() -> [ApplicationRecord] {
        var records: [ApplicationRecord] = []
        for root in standardRoots {
            scanDirectory(root, into: &records)
        }
        return records
    }

    private static func scanDirectory(_ root: URL, into records: inout [ApplicationRecord]) {
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "app" {
                if let record = readRecord(url: url) {
                    records.append(record)
                }
                enumerator.skipDescendants()
            }
        }
    }

    static func readRecord(url: URL) -> ApplicationRecord? {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return nil }
        let infoURL = url.appendingPathComponent("Contents/Info.plist")
        let properties = NSDictionary(contentsOf: infoURL) as? [String: Any] ?? [:]

        let bundleIdentifier = properties["CFBundleIdentifier"] as? String
        let bundleName = (properties["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
        let displayName = firstNonEmpty(
            properties["CFBundleDisplayName"] as? String,
            bundleName
        )
        let executableName = properties["CFBundleExecutable"] as? String
        let version = properties["CFBundleShortVersionString"] as? String

        var aliases: [String] = []
        if let executableName, executableName != displayName, executableName != bundleName {
            aliases.append(executableName)
        }
        if bundleIdentifier != nil {
            aliases.append(url.deletingPathExtension().lastPathComponent)
        }

        let standardized = url.standardizedFileURL
        let attrs = try? manager.attributesOfItem(atPath: url.path)
        let modificationDate = (attrs?[.modificationDate] as? Date)

        return ApplicationRecord(
            bundleURL: standardized,
            bundleIdentifier: bundleIdentifier ?? standardized.path,
            displayName: displayName,
            bundleName: bundleName,
            version: version,
            modificationDate: modificationDate,
            aliases: aliases
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String {
        for value in values {
            if let value, !value.isEmpty {
                return value
            }
        }
        return ""
    }
}