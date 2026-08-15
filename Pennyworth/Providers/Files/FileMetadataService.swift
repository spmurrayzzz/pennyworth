import AppKit
import Foundation

struct FileMetadata: Identifiable, Equatable, Sendable {
    let url: URL
    let fileName: String
    let displayName: String
    let contentType: String?
    let modificationDate: Date?
    let lastUsedDate: Date?
    /// Document identifier from Spotlight metadata. Nil when the volume
    /// does not expose one; identity then falls back to the file path.
    let documentID: Int?

    var id: String {
        url.standardizedFileURL.path
    }
}

enum FileIdentity {
    /// Combines the volume UUID and document identifiers into a durable
    /// candidate identity that follows a same-volume rename. Falls back
    /// to the standardized path when either value is unavailable.
    static func identity(documentID: Int?, volumeUUID: String?, path: String) -> String {
        if let documentID, documentID > 0, let volumeUUID, !volumeUUID.isEmpty {
            return "v\(volumeUUID):d\(documentID)"
        }
        return path
    }
}

@MainActor
final class FileMetadataService: NSObject, NSMetadataQueryDelegate {
    private static let snapshotLimitExclusive = 6_000

    private var activeQuery: NSMetadataQuery?
    private(set) var activeGeneration = 0
    private var lastSnapshot: [FileMetadata] = []
    private(set) var isGatheringComplete = false

    var hasActiveQuery: Bool {
        activeQuery != nil
    }

    /// Builds a predicate from sanitized terms using LIKE[cd].
    static func buildPredicate(for terms: [String]) -> NSPredicate {
        let subPredicates = terms.map { term in
            let pattern = "*\(escapeTerm(term))*"
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@", pattern),
                NSPredicate(format: "kMDItemFSName LIKE[cd] %@", pattern),
            ])
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: subPredicates)
    }

    private static func escapeTerm(_ term: String) -> String {
        var escaped = ""
        for character in term {
            if character == "\\" || character == "*" || character == "?" {
                escaped.append("\\")
                escaped.append(character)
            } else {
                escaped.append(character)
            }
        }
        return escaped
    }

    func start(terms: [String], generation: Int) {
        stop()
        activeGeneration = generation
        isGatheringComplete = false
        lastSnapshot = []
        let query = NSMetadataQuery()
        query.predicate = Self.buildPredicate(for: terms)
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.notificationBatchingInterval = 0.15
        query.delegate = self
        activeQuery = query
        query.start()
    }

    func stop() {
        guard let query = activeQuery else { return }
        query.stop()
        activeQuery = nil
    }

    /// Copy the live results into bounded immutable values, pausing live updates.
    func snapshot() -> [FileMetadata] {
        guard let query = activeQuery else { return lastSnapshot }
        query.disableUpdates()
        defer {
            query.enableUpdates()
        }
        let items = query.results.compactMap { $0 as? NSMetadataItem }.prefix(Self.snapshotLimitExclusive)
        var snapshot: [FileMetadata] = []
        snapshot.reserveCapacity(items.count)
        for item in items {
            guard let url = pathURL(from: item) else { continue }
            let standardized = url.standardizedFileURL
            guard standardized.isFileURL else { continue }
            snapshot.append(makeMetadata(item, url: standardized))
        }
        lastSnapshot = snapshot
        return snapshot
    }

    private func makeMetadata(_ item: NSMetadataItem, url: URL) -> FileMetadata {
        let fileName = (item.value(forAttribute: NSMetadataItemFSNameKey) as? String) ?? url.lastPathComponent
        let displayName = (item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String) ?? fileName
        let contentType = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
        let modificationDate = item.value(forAttribute: NSMetadataItemFSContentChangeDateKey) as? Date
        let lastUsedDate = item.value(forAttribute: NSMetadataItemLastUsedDateKey) as? Date
        return FileMetadata(
            url: url,
            fileName: fileName,
            displayName: displayName,
            contentType: contentType,
            modificationDate: modificationDate,
            lastUsedDate: lastUsedDate,
            documentID: (item.value(forAttribute: "kMDItemDocumentIdentifier") as? NSNumber)?.intValue
        )
    }

    private func pathURL(from item: NSMetadataItem) -> URL? {
        if let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL {
            return url
        }
        if let path = item.value(forAttribute: NSMetadataItemPathKey) as? String {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    // MARK: - NSMetadataQueryDelegate

    nonisolated func metadataQuery(_ query: NSMetadataQuery, replacementValueForAttribute attribute: String, value attrValue: Any) -> Any {
        if attribute == NSMetadataItemPathKey, let path = attrValue as? String {
            return URL(fileURLWithPath: path)
        }
        return attrValue
    }

    nonisolated func metadataQuery(_ query: NSMetadataQuery, didFinishGathering resultIDs: [Any]) {
        MainActor.assumeIsolated {
            isGatheringComplete = true
        }
    }
}