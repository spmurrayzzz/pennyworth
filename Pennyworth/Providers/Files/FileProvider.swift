import AppKit
import Foundation

@MainActor
final class FileProvider: SearchProvider {
    private let service: FileMetadataService
    private let workspace: NSWorkspace
    private var resourceCache: [String: FileResourceInfo] = [:]

    struct FileResourceInfo: Sendable {
        let exists: Bool
        let isHidden: Bool
        let isPackage: Bool
        let isApplicationBundle: Bool
    }

    init(service: FileMetadataService, workspace: NSWorkspace = .shared) {
        self.service = service
        self.workspace = workspace
        observeWorkspaceChanges()
    }

    var providerID: String {
        ProviderID.file
    }

    func supports(mode: QueryMode) -> Bool {
        mode == .fileOpen || mode == .fileFind
    }

    func search(_ parsed: ParsedQuery, limit: Int) async -> [SearchResult] {
        let terms = parsed.searchTerms
        guard !terms.isEmpty else { return [] }

        try? await Task.sleep(for: .milliseconds(75))
        guard !Task.isCancelled else { return [] }

        service.start(terms: terms, generation: 0)
        let results = await collect(terms: terms, limit: limit)
        service.stop()
        return results
    }

    private func collect(terms: [String], limit: Int) async -> [SearchResult] {
        let started = Date()
        var lastCount = -1
        var settledSince = Date()
        let quietWindow: TimeInterval = 0.12

        while !Task.isCancelled {
            let snapshot = service.snapshot()
            let candidates = snapshot.compactMap { metadata -> FileCandidate? in
                guard qualifies(metadata) else { return nil }
                return FileCandidate(metadata: metadata)
            }
            let results = selectBest(candidates, terms: terms, limit: limit)

            if service.isGatheringComplete {
                return results
            }
            let grew = results.count != lastCount
            lastCount = results.count
            if grew {
                settledSince = Date()
            }
            if !results.isEmpty,
                Date().timeIntervalSince(settledSince) >= quietWindow,
                results.count >= min(limit, 5)
            {
                return results
            }
            if Date().timeIntervalSince(started) > 4.0 {
                return results
            }
            try? await Task.sleep(for: .milliseconds(55))
        }
        return []
    }

    private func selectBest(_ candidates: [FileCandidate], terms: [String], limit: Int) -> [SearchResult] {
        struct Scored {
            let result: SearchResult
            let score: Double
        }
        var scored: [Scored] = []
        for candidate in candidates {
            let fuzzy = FuzzyMatcher.match(
                queryTerms: terms,
                title: candidate.displayName,
                aliases: [candidate.fileName],
                path: candidate.path
            )
            guard fuzzy.matched else { continue }
            scored.append(Scored(result: makeResult(candidate), score: fuzzy.score))
        }
        scored.sort { $0.score > $1.score }
        return scored.prefix(limit).map { $0.result }
    }

    private func makeResult(_ candidate: FileCandidate) -> SearchResult {
        SearchResult(
            providerID: ProviderID.file,
            candidateID: candidate.identity,
            entityKey: candidate.identity,
            kind: .file,
            title: candidate.displayName,
            subtitle: candidate.path,
            matchText: "\(candidate.displayName) \(candidate.path)",
            aliases: [candidate.fileName],
            targetValue: candidate.url.path,
            icon: .file(candidate.url),
            accessoryText: nil,
            realized: true
        )
    }

    private func qualifies(_ metadata: FileMetadata) -> Bool {
        let info = resourceInfo(for: metadata.url)
        guard info.exists else { return false }
        if info.isApplicationBundle || info.isPackage {
            return false
        }
        return !hasPackageAncestor(metadata.url)
    }

    private func hasPackageAncestor(_ url: URL) -> Bool {
        var parent = url.deletingLastPathComponent()
        for _ in 0..<10 {
            let info = resourceInfo(for: parent)
            if !info.exists {
                return false
            }
            if info.isApplicationBundle || info.isPackage {
                return true
            }
            let grandparent = parent.deletingLastPathComponent()
            if grandparent.path == parent.path {
                return false
            }
            parent = grandparent
        }
        return false
    }

    private func resourceInfo(for url: URL) -> FileResourceInfo {
        let path = url.path
        if let cached = resourceCache[path] {
            return cached
        }
        let values = try? url.resourceValues(forKeys: [
            .isHiddenKey,
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
        ])
        let info = FileResourceInfo(
            exists: values != nil,
            isHidden: values?.isHidden ?? false,
            isPackage: values?.isPackage ?? false,
            isApplicationBundle: url.pathExtension == "app"
        )
        if resourceCache.count >= 30_000 {
            resourceCache.removeAll(keepingCapacity: true)
        }
        resourceCache[path] = info
        return info
    }

    private func observeWorkspaceChanges() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.resourceCache.removeAll(keepingCapacity: true)
            }
        }
    }
}

private struct FileCandidate {
    let metadata: FileMetadata
    let displayName: String
    let fileName: String
    let path: String
    let url: URL

    init(metadata: FileMetadata) {
        self.metadata = metadata
        self.displayName = metadata.displayName
        self.fileName = metadata.fileName
        self.url = metadata.url.standardizedFileURL
        self.path = self.url.path
    }

    var identity: String {
        url.standardizedFileURL.path
    }
}