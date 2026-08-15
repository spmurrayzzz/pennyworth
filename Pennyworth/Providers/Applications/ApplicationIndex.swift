import AppKit
import Foundation

@MainActor
final class ApplicationIndex: NSObject, NSMetadataQueryDelegate {
    private var records: [String: ApplicationRecord] = [:]
    private var spotlightQuery: NSMetadataQuery?

    var onCatalogChange: (() -> Void)?

    var catalogSize: Int {
        records.count
    }

    var snapshot: [ApplicationRecord] {
        Array(records.values).sorted { lhs, rhs in
            if lhs.displayName != rhs.displayName {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.bundleURL.lastPathComponent < rhs.bundleURL.lastPathComponent
        }
    }

    func start() {
        refreshStandardRoots()
        startSpotlight()
    }

    func refreshStandardRoots() {
        let scanned = ApplicationScanner.scanStandardRoots()
        for record in scanned {
            upsert(record)
        }
    }

    private func startSpotlight() {
        guard spotlightQuery == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemContentTypeTree == 'com.apple.application-bundle'")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.notificationBatchingInterval = 0.4
        query.delegate = self
        spotlightQuery = query
        query.start()

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStandardRoots()
            }
        }
    }

    private func upsert(_ incoming: ApplicationRecord) {
        if let existing = records[incoming.bundleIdentifier] {
            let preferred = NSWorkspace.shared.urlForApplication(withBundleIdentifier: incoming.bundleIdentifier)
            let incomingIsPreferred = preferred.map { $0.standardizedFileURL == incoming.bundleURL } ?? false
            let existingIsPreferred = preferred.map { $0.standardizedFileURL == existing.bundleURL } ?? false
            if incomingIsPreferred && !existingIsPreferred {
                records[incoming.bundleIdentifier] = incoming
            }
            return
        }
        records[incoming.bundleIdentifier] = incoming
    }

    // MARK: - NSMetadataQueryDelegate

    nonisolated func metadataQuery(_ query: NSMetadataQuery, replacementValueForAttribute attrName: String, value attrValue: Any) -> Any {
        if attrName == NSMetadataItemPathKey, let path = attrValue as? String {
            return URL(fileURLWithPath: path)
        }
        return attrValue
    }

    nonisolated func metadataQuery(_ query: NSMetadataQuery, didFinishGathering resultIDsAny: [Any]) {
        let paths = Self.collectPaths(from: query)
        Task { @MainActor [weak self] in
            self?.ingest(paths: paths)
        }
    }

    nonisolated func metadataQuery(_ query: NSMetadataQuery, didUpdate resultIDsAny: [Any]) {
        let paths = Self.collectPaths(from: query)
        Task { @MainActor [weak self] in
            self?.ingest(paths: paths)
        }
    }

    private nonisolated static func collectPaths(from query: NSMetadataQuery) -> [String] {
        query.results.compactMap { item -> String? in
            guard let item = item as? NSMetadataItem else { return nil }
            guard let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL else { return nil }
            return url.standardizedFileURL.path
        }
    }

    private func ingest(paths: [String]) {
        var changed = false
        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard url.isFileURL else { continue }
            guard let record = ApplicationScanner.readRecord(url: url) else { continue }
            if records[record.bundleIdentifier] == nil {
                records[record.bundleIdentifier] = record
                changed = true
            }
        }
        if changed {
            onCatalogChange?()
        }
    }
}