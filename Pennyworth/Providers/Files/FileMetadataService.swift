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

    /// A record is stale when its modification date is in the future
    /// past a small skew, which indicates corrupt or migrated metadata.
    func isStale(now: Date = Date()) -> Bool {
        guard let modificationDate else { return false }
        return modificationDate.timeIntervalSince(now) > 300
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

private final class SendableBox<Value>: @unchecked Sendable {
    var value: Value
    init(_ value: Value) {
        self.value = value
    }
}

/// Hosts the NSMetadataQuery on a dedicated thread with its own run loop.
/// The metadata service can stall indefinitely under a restricted
/// Spotlight config, so everything here runs off the main thread; the
/// main actor only reads cheap copies through the wrapper below.
final class MetadataQueryHost: NSObject, NSMetadataQueryDelegate, @unchecked Sendable {
    private static let snapshotLimitExclusive = 6_000

    private let lock = NSLock()
    private var activeQuery: NSMetadataQuery?
    private var gatheringComplete = false
    private var lastSnapshot: [FileMetadata] = []
    private var queryRunLoop: RunLoop?

    func start(terms: [String], generation: Int) {
        _ = generation
        performOnLoop { [weak self] in
            guard let self else { return }
            self.stopActiveQuery()
            let newQuery = NSMetadataQuery()
            newQuery.predicate = Self.buildPredicate(for: terms)
            newQuery.searchScopes = [NSMetadataQueryUserHomeScope]
            newQuery.notificationBatchingInterval = 0.15
            newQuery.delegate = self
            self.lock.lock()
            self.activeQuery = newQuery
            self.gatheringComplete = false
            self.lastSnapshot = []
            self.lock.unlock()
            newQuery.start()
        }
    }

    func stop() {
        performOnLoop { [weak self] in
            self?.stopActiveQuery()
        }
    }

    func snapshot() -> [FileMetadata] {
        let resultBox = SendableBox<[FileMetadata]>([])
        performOnLoop { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let collection = self.activeQuery
            self.lock.unlock()
            guard let collection else {
                self.lock.lock()
                resultBox.value = self.lastSnapshot
                self.lock.unlock()
                return
            }

            collection.disableUpdates()
            defer { collection.enableUpdates() }

            let items = collection.results.compactMap { $0 as? NSMetadataItem }
                .prefix(Self.snapshotLimitExclusive)
            var snapshot: [FileMetadata] = []
            snapshot.reserveCapacity(items.count)
            for item in items {
                guard let url = self.pathURL(from: item) else { continue }
                let standardized = url.standardizedFileURL
                guard standardized.isFileURL else { continue }
                snapshot.append(self.makeMetadata(from: item, url: standardized))
            }
            self.lock.lock()
            self.lastSnapshot = snapshot
            self.lock.unlock()
            resultBox.value = snapshot
        }
        return resultBox.value
    }

    var isGatheringComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return gatheringComplete
    }

    // MARK: - Query thread plumbing

    private func performOnLoop(_ body: @escaping @Sendable () -> Void) {
        let runLoop = ensureRunLoop()
        let done = DispatchSemaphore(value: 0)
        runLoop.perform(inModes: [.default]) {
            body()
            done.signal()
        }
        done.wait()
    }

    private func ensureRunLoop() -> RunLoop {
        lock.lock()
        if let existing = queryRunLoop {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.installQueryRunLoop(ready: ready)
            let dummy = Port()
            RunLoop.current.add(dummy, forMode: .default)
            while !Thread.current.isCancelled {
                RunLoop.current.run(mode: .default, before: .distantFuture)
            }
        }
        thread.name = "com.local.pennyworth.filemetadata"
        thread.qualityOfService = QualityOfService.userInitiated
        thread.start()
        ready.wait()

        lock.lock()
        let loop = queryRunLoop ?? RunLoop.main
        lock.unlock()
        return loop
    }

    private func installQueryRunLoop(ready: DispatchSemaphore) {
        lock.lock()
        queryRunLoop = RunLoop.current
        lock.unlock()
        ready.signal()
    }

    private func stopActiveQuery() {
        lock.lock()
        let current = activeQuery
        activeQuery = nil
        lock.unlock()
        current?.stop()
    }

    // MARK: - Snapshot conversion

    private func makeMetadata(from item: NSMetadataItem, url: URL) -> FileMetadata {
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

    static func buildPredicate(for terms: [String]) -> NSPredicate {
        // NSMetadataQuery rejects an AND compound that wraps a single
        // subpredicate, so with one term the OR compound is returned
        // directly; multiple terms are then AND-combined.
        let perTerm = terms.map { term in
            let pattern = "*\(escapeTerm(term))*"
            return NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "kMDItemDisplayName LIKE[cd] %@", pattern),
                NSPredicate(format: "kMDItemFSName LIKE[cd] %@", pattern),
            ])
        }
        if perTerm.count == 1 {
            return perTerm[0]
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: perTerm)
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

    // MARK: - NSMetadataQueryDelegate (runs on the query thread)

    func metadataQuery(_ query: NSMetadataQuery, replacementValueForAttribute attribute: String, value attrValue: Any) -> Any {
        if attribute == NSMetadataItemPathKey, let path = attrValue as? String {
            return URL(fileURLWithPath: path)
        }
        return attrValue
    }

    func metadataQuery(_ query: NSMetadataQuery, didFinishGathering resultIDs: [Any]) {
        lock.lock()
        gatheringComplete = true
        lock.unlock()
    }
}

@MainActor
final class FileMetadataService {
    private let host = MetadataQueryHost()

    var isGatheringComplete: Bool {
        host.isGatheringComplete
    }

    func start(terms: [String], generation: Int) {
        host.start(terms: terms, generation: generation)
    }

    func stop() {
        host.stop()
    }

    func snapshot() -> [FileMetadata] {
        host.snapshot()
    }
}